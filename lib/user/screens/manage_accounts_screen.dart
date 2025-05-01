import 'package:flutter/material.dart';
import 'package:mail_merge/user/models/email_account.dart';
import 'package:mail_merge/user/services/auth_service.dart';
import 'package:mail_merge/user/screens/add_email_accounts_screen.dart';
import 'package:mail_merge/user/authentication/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mail_merge/core/services/event_bus.dart';

class ManageAccountsScreen extends StatefulWidget {
  const ManageAccountsScreen({super.key});

  @override
  State<ManageAccountsScreen> createState() => _ManageAccountsScreenState();
}

class _ManageAccountsScreenState extends State<ManageAccountsScreen> {
  final AuthService _authService = AuthService();
  List<EmailAccount> _accounts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    setState(() => _isLoading = true);

    try {
      final accounts = await _authService.getAllAccounts();
      setState(() {
        _accounts = accounts;
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
        title: const Text('Manage Accounts'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAccounts),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  Expanded(
                    child:
                        _accounts.isEmpty
                            ? _buildEmptyState()
                            : _buildAccountsList(),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => const AddEmailAccountsScreen(),
                          ),
                        );

                        if (result == true) {
                          _loadAccounts();
                        }
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add Account'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                      ),
                    ),
                  ),
                ],
              ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.account_circle, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'No Email Accounts',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add an email account to get started',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildAccountsList() {
    return ListView.builder(
      itemCount: _accounts.length,
      itemBuilder: (context, index) {
        final account = _accounts[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          elevation: 0, // Remove shadow
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey[300]!, width: 0.5), // Add thin light grey outline
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundImage:
                  account.photoUrl != null
                      ? NetworkImage(account.photoUrl!)
                      : null,
              backgroundColor: Colors.grey[300],
              child:
                  account.photoUrl == null
                      ? Text(
                        account.displayName[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                      : null,
            ),
            title: Text(account.displayName),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(account.email),
                Text(
                  account.provider.displayName,
                  style: TextStyle(
                    color: _getProviderColor(account.provider),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (account.isDefault)
                  const Padding(
                    padding: EdgeInsets.only(right: 8.0),
                    child: Chip(
                      label: Text('Default', style: TextStyle(fontSize: 12)),
                      backgroundColor: Colors.blue,
                      labelStyle: TextStyle(color: Colors.white),
                      padding: EdgeInsets.all(0),
                    ),
                  )
                else
                  TextButton(
                    onPressed: () async {
                      await _authService.setDefaultAccount(account.id);
                      _loadAccounts();
                    },
                    child: const Text('Set Default'),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(60, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _confirmDeleteAccount(account),
                ),
              ],
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }

  Color _getProviderColor(AccountProvider provider) {
    switch (provider) {
      case AccountProvider.gmail:
        return Colors.red;
      case AccountProvider.outlook:
        return Colors.blue;
      case AccountProvider.rediffmail:
        return Colors.purple;
    }
  }

  Future<void> _confirmDeleteAccount(EmailAccount account) async {
    // Check if this is the only account
    final isOnlyAccount = _accounts.length == 1;

    if (isOnlyAccount) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Sign Out'),
              content: const Text(
                'This is your only account. Removing it will sign you out completely. Continue?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('CANCEL'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text(
                    'SIGN OUT',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
      );

      if (confirmed == true) {
        try {
          // Use the signOut method instead of just removeAccount
          // This ensures all account data is properly cleaned up
          await signOut(context);

          // No need to navigate - signOut already handles this
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Error signing out: $e')));
          }
        }
      }
    } else {
      // Regular confirmation for non-last accounts
      final confirmed = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Remove Account'),
              content: Text(
                'Are you sure you want to remove ${account.displayName} (${account.email})?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('CANCEL'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text(
                    'REMOVE',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
      );

      if (confirmed == true) {
        try {
          await _authService.removeAccount(account.id);

          // Also clear email cache for this account to prevent stale data
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('cached_emails');
          await prefs.remove('cached_vip_emails');
          await prefs.remove('cached_vip_emails_by_contact');
          await prefs.remove('cached_vip_contacts');

          // Notify listeners that an account was removed
          _notifyAccountRemoved();

          _loadAccounts(); // Refresh the list

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Account ${account.email} removed')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error removing account: $e')),
            );
          }
        }
      }
    }
  }

  void _notifyAccountRemoved() {
    // Fire an event to notify that an account was removed
    eventBus.fire(AccountRemovedEvent(''));
  }
}
