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

class HomeNavigation extends StatefulWidget {
  const HomeNavigation({super.key});

  @override
  State<HomeNavigation> createState() => _HomeNavigationState();
}

class _HomeNavigationState extends State<HomeNavigation> {
  int _selectedIndex = 0;
  String _accessToken = ""; // Initialize with empty string
  final _emailListKey = GlobalKey<EmailListScreenState>();

  // Use a scaffold key to access the drawer later
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _listenForAuthChanges(); // Add this
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Try to sync the Google user to our account system
    // This helps ensure we have account data saved
    syncCurrentUserToAccountSystem().then((_) {
      _getAccessToken();
    });
  }

  // Update the _getAccessToken method to use our new AuthService
  Future<void> _getAccessToken() async {
    try {
      print('DEBUG: Getting access token in HomeNavigation');

      // First try to get token from account repository
      final authService = AuthService();
      final token = await authService.getDefaultAccessToken();

      // If that fails, fall back to the original Google Sign-In method
      final finalToken = token ?? await getGoogleAccessToken();

      print(
        'DEBUG: Got token: ${finalToken != null ? "valid token" : "null token"}',
      );

      if (finalToken != null && mounted) {
        setState(() {
          _accessToken = finalToken;
        });
        print('DEBUG: Set access token in HomeNavigation');
      } else if (mounted) {
        // Only navigate to login if we're at home screen (not if we just opened app)
        // This prevents navigation loops
        final currentRoute = ModalRoute.of(context)?.settings.name;
        if (currentRoute != '/') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const AddEmailAccountsPage(),
            ),
          );
        }
      }
    } catch (e) {
      print('ERROR getting access token: $e');
    }
  }

  // Add a logout detection method:
  void _listenForAuthChanges() {
    Future.delayed(const Duration(seconds: 1), () async {
      final token = await getGoogleAccessToken();
      if (token == null && _accessToken.isNotEmpty && mounted) {
        // We had a token before but now it's gone - user logged out
        setState(() {
          _accessToken = "";
        });

        // Redirect to login
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AddEmailAccountsPage()),
          (route) => false,
        );
      }

      // Keep checking periodically
      if (mounted) {
        _listenForAuthChanges();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Create screens list inside build to use updated _accessToken
    final List<Widget> screens = [
      EmailListScreen(key: _emailListKey, accessToken: _accessToken),
      const VipScreen(),
      const Attachmentsscreen(),
      const UnsubscribeScreen(),
    ];

    return Scaffold(
      key: _scaffoldKey, // Need this to open drawer from swipe
      appBar: AppBar(
        title: const Text("Mail Merge", style: TextStyle(color: Colors.black)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        // Hamburger menu icon
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.black),
          onPressed: () {
            // Open the drawer when icon is tapped
            _scaffoldKey.currentState?.openDrawer();
          },
        ),
      ),
      drawer: AppSidebar(
        currentIndex: _selectedIndex,
        onNavigate: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
      // Add swipe to open drawer functionality
      body: GestureDetector(
        // Check if user swiped from left to right
        onHorizontalDragEnd: (details) {
          // If swipe is left to right (positive velocity)
          if (details.primaryVelocity! > 0) {
            // Open the drawer
            _scaffoldKey.currentState?.openDrawer();
          }
        },
        behavior: HitTestBehavior.translucent, // Don't block child widgets
        child: IndexedStack(index: _selectedIndex, children: screens),
      ),
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        selectedFontSize: 10,
        unselectedFontSize: 10,
        showUnselectedLabels: false,
        showSelectedLabels: false,
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
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
        onTap: _onItemTapped,
      ),
      floatingActionButton:
          _selectedIndex == 0
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

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }
}
