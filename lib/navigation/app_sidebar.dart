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
          // Account header
          const AccountHeader(),

          // Inbox item
          _makeInboxItem(context),

          // Contacts item
          _makeContactsItem(context),

          const Divider(),

          // Settings item
          _makeSettingsItem(context),

          // Help item
          _makeHelpItem(context),
        ],
      ),
    );
  }

  // Inbox navigation item
  Widget _makeInboxItem(BuildContext context) {
    bool isSelected = currentIndex == 0;

    return ListTile(
      leading: Icon(Icons.inbox, color: isSelected ? Colors.blue : null),
      title: Text(
        'Inbox',
        style: TextStyle(
          color: isSelected ? Colors.blue : null,
          fontWeight: isSelected ? FontWeight.bold : null,
        ),
      ),
      tileColor: isSelected ? Colors.blue.withOpacity(0.1) : null,
      onTap: () {
        // Close drawer and navigate to inbox
        Navigator.pop(context);
        onNavigate(0);
      },
    );
  }

  // Contacts item
  Widget _makeContactsItem(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.contacts),
      title: const Text('Contacts'),
      onTap: () {
        // Close drawer and go to contacts
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ContactsScreen()),
        );
      },
    );
  }

  // Settings item
  Widget _makeSettingsItem(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.settings),
      title: const Text('Settings'),
      onTap: () {
        // Close drawer and go to settings
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SettingsScreen()),
        );
      },
    );
  }

  // Help and feedback item
  Widget _makeHelpItem(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.help_outline),
      title: const Text('Help & Feedback'),
      onTap: () {
        // Close drawer and show message
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Help & Feedback coming soon')),
        );
      },
    );
  }
}
