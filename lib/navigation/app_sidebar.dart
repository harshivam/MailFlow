import 'package:flutter/material.dart';
import 'package:mail_merge/navigation/widgets/account_header.dart';
import 'package:mail_merge/settings/settings_screen.dart';
import 'package:mail_merge/features/vip_inbox/screens/contacts_screen.dart';

class AppSidebar extends StatelessWidget {
  // Current selected index in the navigation
  final int currentIndex;

  // Callback function when navigation changes
  final Function(int) onNavigate;

  // Callback for when account is changed in the header
  final Function(String)? onAccountChanged;

  // Selected account ID
  final String selectedAccountId;

  // New: Is unified inbox enabled?
  final bool isUnifiedInboxEnabled;

  // New: Callback for toggling unified inbox
  final Function(bool) onUnifiedInboxToggled;

  const AppSidebar({
    super.key,
    required this.currentIndex,
    required this.onNavigate,
    this.onAccountChanged,
    required this.selectedAccountId,
    required this.isUnifiedInboxEnabled,
    required this.onUnifiedInboxToggled,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Account header with callback for account changes
          AccountHeader(
            onAccountChanged: onAccountChanged,
            selectedAccountId: selectedAccountId,
          ),

          // Toggleable Inbox Item - now the only inbox item
          _makeToggleableInboxItem(context),

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

  // New: Toggleable inbox item with switch
  Widget _makeToggleableInboxItem(BuildContext context) {
    // Always selected when currentIndex is 0
    bool isSelected = currentIndex == 0;

    return Container(
      color: isSelected ? Colors.blue.withOpacity(0.1) : null,
      child: ListTile(
        leading: Icon(
          isUnifiedInboxEnabled ? Icons.all_inbox : Icons.inbox,
          color: isSelected ? Colors.blue : null,
        ),
        // Remove the dense and visualDensity properties to get default alignment
        title: Row(
          children: [
            Text(
              'Inbox',
              style: TextStyle(
                color: isSelected ? Colors.blue : null,
                fontWeight: isSelected ? FontWeight.bold : null,
              ),
            ),
            const Spacer(),
            // Show indicator of what mode we're in
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color:
                    isUnifiedInboxEnabled
                        ? Colors.blue.withOpacity(0.2)
                        : Colors.grey.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                isUnifiedInboxEnabled
                    ? 'Unified View'
                    : 'Unified View', // Fixed the text here
                style: TextStyle(
                  fontSize: 10,
                  color: isUnifiedInboxEnabled ? Colors.blue : Colors.grey[700],
                ),
              ),
            ),
          ],
        ),
        // Move the switch to trailing instead of using subtitle
        trailing: Switch(
          value: isUnifiedInboxEnabled,
          activeColor: Colors.blue,
          onChanged: (value) {
            // Call the toggle callback
            onUnifiedInboxToggled(value);
            // No need to navigate - we stay on inbox
          },
        ),
        // Remove subtitle since we moved the switch to trailing
        subtitle: null,
        onTap: () {
          // Close drawer and navigate to inbox (index 0)
          Navigator.pop(context);
          onNavigate(0);
        },
        isThreeLine: false,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
    );
  }

  // Contacts item - unchanged
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

  // Settings item - unchanged
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

  // Help and feedback item - unchanged
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
