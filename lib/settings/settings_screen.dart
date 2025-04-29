import 'package:flutter/material.dart';
import 'package:mail_merge/user/authentication/google_sign_in.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
              "ACCOUNT",
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          // Logout option
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("Log out"),
            onTap: () async {
              // Show confirmation dialog
              final shouldLogout = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("Log out"),
                  content: const Text("Are you sure you want to log out?"),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text("CANCEL"),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text("LOG OUT", style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
              
              if (shouldLogout == true) {
                await signOut(); // Call sign out function
                
                // Show confirmation and return to home
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Logged out successfully")),
                  );
                  Navigator.pop(context); // Go back to home screen
                }
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