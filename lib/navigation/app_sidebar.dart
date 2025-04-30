import 'package:flutter/material.dart';
import 'package:mail_merge/navigation/widgets/account_header.dart';
import 'package:mail_merge/settings/settings_screen.dart';
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
          // Extracted to a separate widget
          const AccountHeader(),

          // Main navigation item - only keeping Inbox
          _buildNavigationItem(
            context,
            index: 0,
            icon: Icons.inbox,
            title: 'Inbox',
          ),

          // Contacts option
          _buildNavigationTile(
            context: context,
            icon: Icons.contacts,
            title: 'Contacts',
            onTap: () => _navigateTo(context, const ContactsScreen()),
          ),

          const Divider(),

          // Settings and other options
          _buildNavigationTile(
            context: context,
            icon: Icons.settings,
            title: 'Settings',
            onTap: () => _navigateTo(context, const SettingsScreen()),
          ),

          // Help & Feedback
          _buildNavigationTile(
            context: context,
            icon: Icons.help_outline,
            title: 'Help & Feedback',
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Help & Feedback coming soon')),
              );
            },
          ),
        ],
      ),
    );
  }

  // Navigate to screen and close drawer
  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
  }

  // Build a navigation tile with consistent styling
  Widget _buildNavigationTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(leading: Icon(icon), title: Text(title), onTap: onTap);
  }

  // Build the main navigation items with selection state
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
        Navigator.pop(context);
        onNavigate(index);
      },
    );
  }
}
