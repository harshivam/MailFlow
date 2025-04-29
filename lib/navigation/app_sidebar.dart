import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mail_merge/user/authentication/google_sign_in.dart';
import 'package:mail_merge/settings/settings_screen.dart';
import 'package:mail_merge/user/authentication/add_email_accounts.dart';
import 'package:mail_merge/features/vip_inbox/screens/contacts_screen.dart';

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
        child: FutureBuilder<GoogleSignInAccount?>(
          future: getCurrentUser(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            }

            final user = snapshot.data;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (user != null) ...[
                  CircleAvatar(
                    backgroundImage: NetworkImage(
                      user.photoUrl ?? 'https://via.placeholder.com/150',
                    ),
                    radius: 30,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    user.displayName ?? 'User',
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  Text(
                    user.email,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ] else ...[
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
