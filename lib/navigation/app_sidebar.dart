import 'package:flutter/material.dart';
import 'package:mail_merge/navigation/widgets/account_header.dart';
import 'package:mail_merge/settings/settings_screen.dart';
import 'package:mail_merge/features/vip_inbox/screens/contacts_screen.dart';
import 'package:mail_merge/features/filters/models/custom_filter.dart';
import 'package:mail_merge/features/filters/repository/filter_repository.dart';
import 'package:mail_merge/features/filters/widgets/add_filter_dialog.dart';

class AppSidebar extends StatefulWidget {
  // Current selected index in the navigation
  final int currentIndex;

  // Callback function when navigation changes
  final Function(int) onNavigate;

  // Callback for when account is changed in the header
  final Function(String)? onAccountChanged;

  // Selected account ID
  final String selectedAccountId;

  // Is unified inbox enabled?
  final bool isUnifiedInboxEnabled;

  // Callback for toggling unified inbox
  final Function(bool) onUnifiedInboxToggled;

  // Add this line - callback for filter selection
  final Function(String) onFilterSelected;

  const AppSidebar({
    super.key,
    required this.currentIndex,
    required this.onNavigate,
    this.onAccountChanged,
    required this.selectedAccountId,
    required this.isUnifiedInboxEnabled,
    required this.onUnifiedInboxToggled,
    required this.onFilterSelected, // Add this parameter
  });

  @override
  State<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends State<AppSidebar> {
  final FilterRepository _filterRepository = FilterRepository();
  List<CustomFilter> _filters = [];
  bool _isLoadingFilters = false;

  @override
  void initState() {
    super.initState();
    _loadCustomFilters(); // Add this line
    // Your existing code...
  }

  // Add a method to load custom filters
  Future<void> _loadCustomFilters() async {
    setState(() {
      _isLoadingFilters = true;
    });

    try {
      final filters = await _filterRepository.getAllFilters();
      setState(() {
        _filters = filters;
        _isLoadingFilters = false;
      });
    } catch (e) {
      print('Error loading custom filters: $e');
      setState(() {
        _isLoadingFilters = false;
      });
    }
  }

  // Add a method to show the add filter dialog
  void _showAddFilterDialog() async {
    final result = await showDialog<CustomFilter>(
      context: context,
      builder: (context) => const AddFilterDialog(),
    );

    if (result != null) {
      await _filterRepository.saveFilter(result);
      _loadCustomFilters();
    }
  }

  // Add a method to show the edit filter dialog
  void _showEditFilterDialog(CustomFilter filter) async {
    final result = await showDialog<CustomFilter>(
      context: context,
      builder: (context) => AddFilterDialog(existingFilter: filter),
    );

    if (result != null) {
      await _filterRepository.saveFilter(result);
      _loadCustomFilters();
    }
  }

  // Add a method to delete filter
  Future<void> _deleteFilter(CustomFilter filter) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Filter'),
            content: Text('Are you sure you want to delete "${filter.name}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('CANCEL'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('DELETE'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      await _filterRepository.deleteFilter(filter.id);
      _loadCustomFilters();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Account header with callback for account changes
          AccountHeader(
            onAccountChanged: widget.onAccountChanged,
            selectedAccountId: widget.selectedAccountId,
          ),

          // Toggleable Inbox Item - now the only inbox item
          _makeToggleableInboxItem(context),

          // Contacts item
          _makeContactsItem(context),

          const Divider(),

          // Add Custom Filters Section here
          _buildFiltersSection(context),
          
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
    bool isSelected = widget.currentIndex == 0;

    return Container(
      color: isSelected ? Colors.blue.withOpacity(0.1) : null,
      child: ListTile(
        leading: Icon(
          widget.isUnifiedInboxEnabled ? Icons.all_inbox : Icons.inbox,
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
                    widget.isUnifiedInboxEnabled
                        ? Colors.blue.withOpacity(0.2)
                        : Colors.grey.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                widget.isUnifiedInboxEnabled
                    ? 'Unified View'
                    : 'Unified View', // Fixed the text here
                style: TextStyle(
                  fontSize: 10,
                  color:
                      widget.isUnifiedInboxEnabled
                          ? Colors.blue
                          : Colors.grey[700],
                ),
              ),
            ),
          ],
        ),
        // Move the switch to trailing instead of using subtitle
        trailing: Switch(
          value: widget.isUnifiedInboxEnabled,
          activeColor: Colors.blue,
          onChanged: (value) {
            // Call the toggle callback
            widget.onUnifiedInboxToggled(value);
            // No need to navigate - we stay on inbox
          },
        ),
        // Remove subtitle since we moved the switch to trailing
        subtitle: null,
        onTap: () {
          // Close drawer and navigate to inbox (index 0)
          Navigator.pop(context);
          widget.onNavigate(0);
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

  // Custom filters section
  Widget _buildFiltersSection(BuildContext context) {
    return Column(
      children: [
        // Add Custom Filter item
        ListTile(
          leading: const Icon(Icons.add),
          title: const Text('Add Custom Filter'),
          onTap: _showAddFilterDialog,
        ),

        // Divider if there are any filters
        

        // Filters list
        if (_isLoadingFilters)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else
          ..._filters
              .map(
                (filter) => Padding(
                  padding: const EdgeInsets.fromLTRB(29,0,8,0),
                  child: ListTile(
                    leading: Icon(filter.icon, color: filter.color),
                    title: Text(filter.name),
                    onTap: () {
                      Navigator.of(context).pop(); // Close drawer
                      widget.onFilterSelected(filter.keyword);
                    },
                    trailing: PopupMenuButton<String>(
                      itemBuilder:
                          (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Edit'),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                          ],
                      onSelected: (value) {
                        if (value == 'edit') {
                          _showEditFilterDialog(filter);
                        } else if (value == 'delete') {
                          _deleteFilter(filter);
                        }
                      },
                    ),
                  ),
                ),
              )
              .toList(),
      ],
    );
  }
}
