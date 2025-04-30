import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mail_merge/user/authentication/google_sign_in.dart';
import 'package:mail_merge/settings/settings_screen.dart';
import 'package:mail_merge/user/authentication/add_email_accounts.dart';
import 'package:mail_merge/features/vip_inbox/screens/contacts_screen.dart';
import 'package:mail_merge/user/models/email_account.dart';
import 'package:mail_merge/user/repository/account_repository.dart';
import 'package:mail_merge/user/services/auth_service.dart';

class AppSidebar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onNavigate;

  const AppSidebar({
    super.key,
    required this.currentIndex,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Drawer header with user info
          _buildDrawerHeader(context),

          // Main navigation item - only keeping Inbox
          _buildNavigationItem(
            context,
            index: 0,
            icon: Icons.inbox,
            title: 'Inbox',
          ),

          // Contacts option
          ListTile(
            leading: const Icon(Icons.contacts),
            title: const Text('Contacts'),
            onTap: () {
              Navigator.pop(context); // Close drawer first
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ContactsScreen()),
              );
            },
          ),

          const Divider(),

          // Settings and other options
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () {
              Navigator.pop(context); // Close drawer first
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),

          // Help & Feedback
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Help & Feedback'),
            onTap: () {
              Navigator.pop(context); // Close drawer
              // Implement help & feedback functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Help & Feedback coming soon')),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Close drawer first, then navigate to settings
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SettingsScreen()),
        );
      },
      child: DrawerHeader(
        decoration: const BoxDecoration(color: Colors.blue),
        child: FutureBuilder<List<EmailAccount>>(
          future: AccountRepository().getAllAccounts(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            }

            final accounts = snapshot.data ?? [];
            if (accounts.isEmpty) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.account_circle,
                    size: 60,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Not signed in',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context); // Close drawer
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AddEmailAccountsPage(),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Sign in'),
                  ),
                ],
              );
            }

            // Find the default account
            final defaultAccount = accounts.firstWhere(
              (acc) => acc.isDefault,
              orElse: () => accounts.first,
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Show current account
                CircleAvatar(
                  backgroundImage: defaultAccount.photoUrl != null
                      ? NetworkImage(defaultAccount.photoUrl!)
                      : null,
                  backgroundColor: Colors.grey[300],
                  foregroundColor: Colors.white,
                  radius: 30,
                  child: defaultAccount.photoUrl == null
                      ? Text(
                          defaultAccount.displayName.isNotEmpty
                              ? defaultAccount.displayName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 8),
                Text(
                  defaultAccount.displayName,
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        defaultAccount.email,
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (accounts.length > 1)
                      PopupMenuButton<EmailAccount>(
                        icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                        onSelected: (selectedAccount) {
                          // Set as default and refresh
                          final authService = AuthService();
                          authService.setDefaultAccount(selectedAccount.id).then((_) {
                            // Close and reopen drawer to refresh
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Switched to ${selectedAccount.email}')),
                            );
                          });
                        },
                        itemBuilder: (context) => accounts
                            .where((acc) => acc.id != defaultAccount.id)
                            .map((account) => PopupMenuItem<EmailAccount>(
                                  value: account,
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 15,
                                        backgroundColor: Colors.grey[300],
                                        backgroundImage: account.photoUrl != null
                                            ? NetworkImage(account.photoUrl!)
                                            : null,
                                        child: account.photoUrl == null
                                            ? Text(
                                                account.displayName.isNotEmpty
                                                    ? account.displayName[0].toUpperCase()
                                                    : '?',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              )
                                            : null,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(account.displayName),
                                            Text(
                                              account.email,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[700],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ))
                            .toList(),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildNavigationItem(
    BuildContext context, {
    required int index,
    required IconData icon,
    required String title,
  }) {
    final isSelected = currentIndex == index;

    return ListTile(
      leading: Icon(icon, color: isSelected ? Colors.blue : null),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? Colors.blue : null,
          fontWeight: isSelected ? FontWeight.bold : null,
        ),
      ),
      tileColor: isSelected ? Colors.blue.withOpacity(0.1) : null,
      onTap: () {
        Navigator.pop(context); // Close drawer
        onNavigate(index);
      },
    );
  }
}
