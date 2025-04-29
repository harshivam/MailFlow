import 'package:flutter/material.dart';
import 'package:mail_merge/features/email/screens/email_list_screen.dart';
import 'package:mail_merge/features/vip_inox/screens/VipScreen.dart';
import 'package:mail_merge/features/attachments_hub/screens/AttachmentsScreen.dart';
import 'package:mail_merge/features/unsubscribe_manager/screens/unsubscribe.dart';
import 'package:mail_merge/settings/settings_screen.dart';
import 'package:mail_merge/user/authentication/google_sign_in.dart';
import 'package:mail_merge/features/email/screens/compose_email_screen.dart';
import 'package:mail_merge/user/authentication/add_email_accounts.dart';

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

    // Add this authentication check
    _checkAuthentication();
  }

  Future<void> _checkAuthentication() async {
    final token = await getGoogleAccessToken();

    if (token == null && mounted) {
      // No user is signed in, navigate to add email accounts
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AddEmailAccountsPage()),
      );
    } else if (mounted) {
      // User is signed in, update token
      setState(() {
        _accessToken = token ?? "";
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
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.black),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
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
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          const BottomNavigationBarItem(icon: Icon(Icons.star), label: "VIP"),
          BottomNavigationBarItem(
            icon: Transform.scale(scale: 0.8, child: Icon(Icons.attach_file)),
            label: "Attachments",
          ),
          const BottomNavigationBarItem(
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
