import 'package:flutter/material.dart';
import 'package:mail_merge/user/models/email_account.dart';
import 'package:mail_merge/user/repository/account_repository.dart';
import 'package:mail_merge/user/services/auth_service.dart';
import 'package:mail_merge/settings/settings_screen.dart';
import 'package:mail_merge/user/authentication/add_email_accounts.dart';

class AccountHeader extends StatelessWidget {
  const AccountHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return Material(
      color: Colors.blue,
      child: InkWell(
        onTap: () => _navigateToSettings(context),
        child: Container(
          height: 220,
          padding: EdgeInsets.fromLTRB(
            16.0,
            statusBarHeight + 26.0,
            16.0,
            24.0,
          ),
          child: FutureBuilder<List<EmailAccount>>(
            future: AccountRepository().getAllAccounts(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              }

              final accounts = snapshot.data ?? [];
              return accounts.isEmpty
                  ? _buildSignInPrompt(context)
                  : _buildAccountInfo(context, accounts);
            },
          ),
        ),
      ),
    );
  }

  // Navigate to settings screen
  void _navigateToSettings(BuildContext context) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }

  // Build the sign-in prompt when no accounts are present
  Widget _buildSignInPrompt(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.account_circle, size: 60, color: Colors.white),
        const SizedBox(height: 8),
        const Text(
          'Not signed in',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
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

  // Build the account information display
  Widget _buildAccountInfo(BuildContext context, List<EmailAccount> accounts) {
    // Find the default account
    final defaultAccount = accounts.firstWhere(
      (acc) => acc.isDefault,
      orElse: () => accounts.first,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Avatar
        _buildAvatar(defaultAccount),

        const SizedBox(height: 10),

        // Display name
        Text(
          defaultAccount.displayName,
          style: const TextStyle(color: Colors.white, fontSize: 18),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),

        const SizedBox(height: 4),

        // Email with selector or settings
        accounts.length > 1
            ? _buildMultiAccountSelector(context, accounts, defaultAccount)
            : _buildSingleAccountInfo(context, defaultAccount),
      ],
    );
  }

  // Build avatar with circular image or initial
  Widget _buildAvatar(EmailAccount account) {
    return CircleAvatar(
      backgroundImage:
          account.photoUrl != null ? NetworkImage(account.photoUrl!) : null,
      backgroundColor: Colors.grey[300],
      foregroundColor: Colors.white,
      radius: 30,
      child:
          account.photoUrl == null
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
    );
  }

  // Build multi-account selector with dropdown
  Widget _buildMultiAccountSelector(
    BuildContext context,
    List<EmailAccount> accounts,
    EmailAccount defaultAccount,
  ) {
    return PopupMenuButton<EmailAccount>(
      onSelected: (selectedAccount) => _switchAccount(context, selectedAccount),
      itemBuilder:
          (context) => _buildAccountMenuItems(accounts, defaultAccount),
      offset: const Offset(0, 36),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            Expanded(
              child: Text(
                defaultAccount.email,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.arrow_drop_down, color: Colors.white),
          ],
        ),
      ),
    );
  }

  // Build single account info with settings icon
  Widget _buildSingleAccountInfo(BuildContext context, EmailAccount account) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              account.email,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 24,
            height: 20,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              child: const Icon(Icons.settings, color: Colors.white, size: 20),
              onTap: () => _navigateToSettings(context),
            ),
          ),
        ],
      ),
    );
  }

  // Build menu items for account selection
  List<PopupMenuItem<EmailAccount>> _buildAccountMenuItems(
    List<EmailAccount> accounts,
    EmailAccount defaultAccount,
  ) {
    return accounts
        .where((acc) => acc.id != defaultAccount.id)
        .map(
          (account) => PopupMenuItem<EmailAccount>(
            value: account,
            height: 56,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 15,
                  backgroundColor: Colors.grey[300],
                  backgroundImage:
                      account.photoUrl != null
                          ? NetworkImage(account.photoUrl!)
                          : null,
                  child:
                      account.photoUrl == null
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        account.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        account.email,
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        )
        .toList();
  }

  // Switch to selected account
  void _switchAccount(BuildContext context, EmailAccount selectedAccount) {
    final authService = AuthService();
    authService.setDefaultAccount(selectedAccount.id).then((_) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Switched to ${selectedAccount.email}')),
      );
    });
  }
}
