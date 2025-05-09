import 'package:flutter/material.dart';
import 'package:mail_merge/user/authentication/google_sign_in.dart';
import 'package:mail_merge/user/screens/manage_accounts_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Keep syncing user for proper functionality
    syncCurrentUserToAccountSystem();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings", style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: ListView(
        children: [
          // Account section
          const Padding(
            padding: EdgeInsets.only(left: 16, top: 16, bottom: 8),
            child: Text(
              "ACCOUNTS",
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Replace multiple account items with a single Manage Accounts button
          ListTile(
            leading: const Icon(Icons.account_circle, color: Colors.blue),
            title: const Text("Manage Accounts"),
            subtitle: const Text("Add, remove, or set default email accounts"),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ManageAccountsScreen(),
                ),
              );
            },
          ),

          const Divider(),

          // Logout option
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("Log out"),
            onTap: () async {
              // Show confirmation dialog
              final shouldLogout = await showDialog<bool>(
                context: context,
                builder:
                    (context) => AlertDialog(
                      title: const Text("Log out"),
                      content: const Text("Are you sure you want to log out?"),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text("CANCEL"),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text(
                            "LOG OUT",
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
              );

              if (shouldLogout == true) {
                await signOut(context); // Pass context to handle navigation
              }
            },
          ),

          const Divider(),

          // App section
          const Padding(
            padding: EdgeInsets.only(left: 16, top: 16, bottom: 8),
            child: Text(
              "APP",
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // App version
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text("App version"),
            subtitle: Text("1.0.0"),
          ),
        ],
      ),
    );
  }
}
