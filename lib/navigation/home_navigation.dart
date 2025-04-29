import 'package:flutter/material.dart';
import 'package:mail_merge/features/email/screens/email_list_screen.dart';
import 'package:mail_merge/features/vip_inox/screens/VipScreen.dart';
import 'package:mail_merge/features/attachments_hub/screens/AttachmentsScreen.dart';
import 'package:mail_merge/features/unsubscribe_manager/screens/unsubscribe.dart';
import 'package:mail_merge/user/authentication/google_sign_in.dart';
import 'package:mail_merge/features/email/screens/compose_email_screen.dart';
import 'package:mail_merge/navigation/app_sidebar.dart'; // Import the sidebar

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
  }

  // Update the _getAccessToken method to trigger fetchEmails via setState
  Future<void> _getAccessToken() async {
    final token = await getGoogleAccessToken();
    if (token != null && mounted) {
      setState(() {
        _accessToken = token;
      });
    }
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: () async {
              // First check if we have a token
              final token = await getGoogleAccessToken();

              if (mounted) {
                setState(() {
                  _accessToken =
                      token ?? ""; // Update token (might be null if logged out)
                });

                // If we're on the home tab and have a valid token
                if (_selectedIndex == 0 && token != null) {
                  _emailListKey.currentState
                      ?.fetchEmails(); // Directly call refresh
                }
              }
            },
          ),
        ],
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
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
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
