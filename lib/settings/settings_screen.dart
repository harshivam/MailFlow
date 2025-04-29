import 'package:flutter/material.dart';
import 'package:mail_merge/user/authentication/google_sign_in.dart';
import 'package:mail_merge/user/authentication/add_email_accounts.dart';
import 'package:mail_merge/user/screens/manage_accounts_screen.dart';
import 'package:mail_merge/user/services/auth_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  List<Map<String, dynamic>> _accounts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Sync the current Google user before loading accounts
    syncCurrentUserToAccountSystem().then((_) => _loadAccounts());
  }

  Future<void> _loadAccounts() async {
    setState(() => _isLoading = true);

    try {
      final authService = AuthService();
      final accounts = await authService.getAllAccounts();
      
      setState(() {
        _accounts = accounts.map((account) => {
          "id": account.id,
          "name": account.displayName,
          "email": account.email,
          "photoUrl": account.photoUrl ?? "https://via.placeholder.com/150",
          "provider": account.provider.displayName,
          "isDefault": account.isDefault,
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading accounts: $e');
      setState(() => _isLoading = false);
    }
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

          // Show accounts or loading indicator
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_accounts.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text("No accounts signed in"),
            )
          else
            ..._accounts
                .map(
                  (account) => ListTile(
                    leading: CircleAvatar(
                      backgroundImage: NetworkImage(account["photoUrl"]),
                      backgroundColor: Colors.grey[300],
                    ),
                    title: Row(
                      children: [
                        Text(account["name"]),
                        if (account["isDefault"])
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'Default',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(account["email"]),
                        Text(
                          account["provider"],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    isThreeLine: true,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ManageAccountsScreen(),
                        ),
                      ).then((_) => _loadAccounts());
                    },
                  ),
                )
                .toList(),

          // Add account button
          ListTile(
            leading: const Icon(Icons.add_circle_outline, color: Colors.blue),
            title: const Text(
              "Add email account",
              style: TextStyle(color: Colors.blue),
            ),
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AddEmailAccountsPage(),
                ),
              );

              // If account was added, reload the list
              if (result == true) {
                _loadAccounts();
              }
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

                // No need for manual navigation since signOut handles it
                // Just reload accounts if somehow we're still on this screen
                _loadAccounts();
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
