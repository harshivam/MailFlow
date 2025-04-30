import 'package:flutter/material.dart';
import 'package:mail_merge/features/email/screens/email_list_screen.dart';
import 'package:mail_merge/features/vip_inbox/screens/VipScreen.dart';
import 'package:mail_merge/features/attachments_hub/screens/AttachmentsScreen.dart';
import 'package:mail_merge/features/unsubscribe_manager/screens/unsubscribe.dart';
import 'package:mail_merge/user/authentication/add_email_accounts.dart';
import 'package:mail_merge/user/authentication/google_sign_in.dart';
import 'package:mail_merge/features/email/screens/compose_email_screen.dart';
import 'package:mail_merge/navigation/app_sidebar.dart';
import 'package:mail_merge/user/services/auth_service.dart';
import 'package:mail_merge/user/models/email_account.dart';
import 'package:mail_merge/user/repository/account_repository.dart';

class HomeNavigation extends StatefulWidget {
  const HomeNavigation({super.key});

  @override
  State<HomeNavigation> createState() => _HomeNavigationState();
}

class _HomeNavigationState extends State<HomeNavigation>
    with WidgetsBindingObserver {
  // Track the sidebar navigation selection
  int _sidebarIndex = 0;

  // Track the bottom navigation selection separately
  int _bottomNavIndex = 0;

  // New: Track if unified inbox is enabled
  bool _isUnifiedInboxEnabled = true;

  String _accessToken = "";
  String? _selectedAccountId; // Track the selected account
  final _emailListKey = GlobalKey<EmailListScreenState>();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isSyncingAccount = false;

  @override
  void initState() {
    super.initState();
    _loadDefaultAccount();
    _listenForAuthChanges();

    // Register for app lifecycle events to detect resume
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Add lifecycle method to detect app resume
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncSelectedAccountWithDefault();
    }
  }

  // New method to synchronize with default account
  Future<void> _syncSelectedAccountWithDefault() async {
    if (_isSyncingAccount) return;
    _isSyncingAccount = true;

    try {
      final accountRepo = AccountRepository();
      final accounts = await accountRepo.getAllAccounts();

      if (accounts.isNotEmpty) {
        final defaultAccount = accounts.firstWhere(
          (acc) => acc.isDefault,
          orElse: () => accounts.first,
        );

        if (defaultAccount.id != _selectedAccountId) {
          print('DEBUG: Syncing to default account: ${defaultAccount.email}');

          if (mounted) {
            setState(() {
              _selectedAccountId = defaultAccount.id;
            });

            // Update access token for the new account
            _getAccessToken();
          }
        }
      }
    } catch (e) {
      print('ERROR: Failed to sync with default account: $e');
    } finally {
      _isSyncingAccount = false;
    }
  }

  // Make sure selectedAccountId is set from default account
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Just load the default account first
    _loadDefaultAccount().then((_) {
      // Then get the token
      _getAccessToken();
    });
  }

  // Load the default account when app starts
  Future<void> _loadDefaultAccount() async {
    try {
      final accountRepo = AccountRepository();
      final accounts = await accountRepo.getAllAccounts();

      if (accounts.isNotEmpty) {
        // Find the default account
        final defaultAccount = accounts.firstWhere(
          (acc) => acc.isDefault,
          orElse: () => accounts.first,
        );

        // Store its ID for later use
        setState(() {
          _selectedAccountId = defaultAccount.id;
        });

        print(
          'DEBUG: Default account loaded: ${defaultAccount.email} (ID: ${defaultAccount.id})',
        );
      }
    } catch (e) {
      print('Error loading default account: $e');
    }
  }

  // Get access token for the selected account
  Future<void> _getAccessToken() async {
    try {
      // If we have a selected account, get token for that specific account
      if (_selectedAccountId != null) {
        final authService = AuthService();
        final accounts = await authService.getAllAccounts();
        final account = accounts.firstWhere(
          (acc) => acc.id == _selectedAccountId,
          orElse: () => accounts.first,
        );

        if (mounted) {
          setState(() {
            _accessToken = account.accessToken;
          });
          print('DEBUG: Got token for account: ${account.email}');
        }
      } else {
        // Fall back to default Google token
        final token = await getGoogleAccessToken();
        if (token != null && mounted) {
          setState(() {
            _accessToken = token;
          });
        }
      }
    } catch (e) {
      print('Error getting access token: $e');
    }
  }

  // Handle when user changes account in sidebar header
  void _handleAccountChanged(String accountId) {
    print('DEBUG: Account changed to ID: $accountId');
    setState(() {
      _selectedAccountId = accountId;
    });

    // Refresh token for the new account
    _getAccessToken();
  }

  // Listen for auth state changes
  void _listenForAuthChanges() {
    print('Setting up auth changes listener');

    Future.delayed(Duration.zero, () async {
      final accounts = await AccountRepository().getAllAccounts();
      if (accounts.isEmpty && mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AddEmailAccountsPage()),
          (route) => false,
        );
      }
    });
  }

  // New: Method to handle unified inbox toggle
  void _handleUnifiedInboxToggled(bool isEnabled) {
    setState(() {
      _isUnifiedInboxEnabled = isEnabled;
    });
    // Show feedback to user
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isEnabled ? 'Showing emails from all accounts' : 'Showing emails from selected account only'
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Create screens based on unified inbox toggle
    Widget currentScreen;

    // Get the main screen based on unified inbox toggle
    if (_isUnifiedInboxEnabled) {
      // Unified Inbox - shows all emails (no accountId)
      currentScreen = EmailListScreen(
        key: GlobalKey<EmailListScreenState>(),
        accessToken: _accessToken,
        // Don't pass accountId for unified inbox
      );
    } else {
      // Account-specific Inbox - filter by selected account
      currentScreen = EmailListScreen(
        key: GlobalKey<EmailListScreenState>(),
        accessToken: _accessToken,
        accountId: _selectedAccountId, // Pass selected account ID for filtering
      );
    }

    // Bottom navigation screens
    final List<Widget> bottomNavScreens = [
      // Inbox screen (unified or account-specific based on toggle)
      currentScreen,

      // VIP screen - also respects the unified inbox toggle
      _isUnifiedInboxEnabled
          ? const VipScreen() // Unified VIP view
          : VipScreen(accountId: _selectedAccountId ?? ''), // Account-specific view

      // Attachments screen
      const Attachmentsscreen(),

      // Unsubscribe screen
      const UnsubscribeScreen(),
    ];

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text("Mail Flow", style: TextStyle(color: Colors.black)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.black),
          onPressed: () {
            // Open the drawer when icon is tapped
            _scaffoldKey.currentState?.openDrawer();
          },
        ),
      ),
      drawer: AppSidebar(
        currentIndex: _sidebarIndex,
        onNavigate: (index) {
          setState(() {
            _sidebarIndex = index;
            _bottomNavIndex = 0;
          });
        },
        onAccountChanged: _handleAccountChanged,
        selectedAccountId: _selectedAccountId ?? '',
        isUnifiedInboxEnabled: _isUnifiedInboxEnabled, // Pass the toggle state
        onUnifiedInboxToggled: _handleUnifiedInboxToggled, // Pass the toggle callback
      ),
      // Add swipe to open drawer functionality
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity! > 0) {
            _scaffoldKey.currentState?.openDrawer();
          }
        },
        behavior: HitTestBehavior.translucent,
        // Show screen based on bottom navigation selection
        child: bottomNavScreens[_bottomNavIndex],
      ),
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        selectedFontSize: 10,
        unselectedFontSize: 10,
        showUnselectedLabels: false,
        showSelectedLabels: false,
        type: BottomNavigationBarType.fixed,
        currentIndex: _bottomNavIndex,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.inbox), label: "Inbox"),
          BottomNavigationBarItem(icon: Icon(Icons.star), label: "VIP"),
          BottomNavigationBarItem(
            icon: Icon(Icons.attach_file),
            label: "Attachments",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.unsubscribe),
            label: "Unsubscribe",
          ),
        ],
        onTap: _onBottomNavTapped,
      ),
      floatingActionButton:
          _bottomNavIndex == 0
              ? FloatingActionButton(
                child: const Icon(Icons.edit),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ComposeEmailScreen(),
                    ),
                  );
                },
              )
              : null,
    );
  }

  // Handle bottom navigation bar taps
  void _onBottomNavTapped(int index) {
    setState(() {
      _bottomNavIndex = index;
    });
  }
}
