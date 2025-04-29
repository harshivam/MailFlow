import 'package:flutter/material.dart';
import 'package:mail_merge/features/email/screens/email_list_screen.dart';
import 'package:mail_merge/features/vip_inbox/screens/VipScreen.dart';
import 'package:mail_merge/features/attachments_hub/screens/AttachmentsScreen.dart';
import 'package:mail_merge/features/unsubscribe_manager/screens/unsubscribe.dart';
import 'package:mail_merge/user/authentication/add_email_accounts.dart';
import 'package:mail_merge/user/authentication/google_sign_in.dart';
import 'package:mail_merge/features/email/screens/compose_email_screen.dart';
import 'package:mail_merge/navigation/app_sidebar.dart';
import 'package:mail_merge/user/services/auth_service.dart'; // Import the sidebar

class HomeNavigation extends StatefulWidget {
  const HomeNavigation({super.key});

  @override
  State<HomeNavigation> createState() => _HomeNavigationState();
}

class _HomeNavigationState extends State<HomeNavigation> {
  int _selectedIndex = 0;
  String _accessToken = ""; // Initialize with empty string
  final _emailListKey = GlobalKey<EmailListScreenState>();

  @override
  void initState() {
    super.initState();
    _getAccessToken(); // Get token when app starts
    _listenForAuthChanges(); // Add this
  }

  // Update the _getAccessToken method to use our new AuthService

  Future<void> _getAccessToken() async {
    try {
      // Use the original getGoogleAccessToken for now to maintain compatibility
      final token = await getGoogleAccessToken();
      
      if (token != null && mounted) {
        setState(() {
          _accessToken = token;
        });
      } else {
        // Handle null token case - maybe user needs to login
        if (mounted) {
          Navigator.pushReplacement(
            context, 
            MaterialPageRoute(builder: (context) => const AddEmailAccountsPage())
          );
        }
      }
    } catch (e) {
      print('Error getting access token: $e');
      // Handle error appropriately
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
      appBar: AppBar(
        title: const Text("Mail Merge", style: TextStyle(color: Colors.black)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        // Add hamburger menu icon
        leading: Builder(
          builder:
              (context) => IconButton(
                icon: const Icon(Icons.menu, color: Colors.black),
                onPressed: () {
                  Scaffold.of(context).openDrawer();
                },
              ),
        ),
      ),
      // Use the modular sidebar
      drawer: AppSidebar(
        currentIndex: _selectedIndex,
        onNavigate: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
      body: IndexedStack(index: _selectedIndex, children: screens),
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
