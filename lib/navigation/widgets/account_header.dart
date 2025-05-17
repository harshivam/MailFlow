import 'package:flutter/material.dart';
import 'package:mail_merge/user/models/email_account.dart';
import 'package:mail_merge/user/repository/account_repository.dart';
import 'package:mail_merge/user/services/auth_service.dart';
import 'package:mail_merge/settings/settings_screen.dart';
import 'package:mail_merge/user/authentication/add_email_accounts.dart';

class AccountHeader extends StatelessWidget {
  // Callback for when account is changed
  final Function(String)? onAccountChanged;

  // Added parameter to track the currently selected account
  final String? selectedAccountId;

  const AccountHeader({
    super.key,
    this.onAccountChanged,
    this.selectedAccountId, // New parameter
  });

  @override
  Widget build(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return Material(
      color: Colors.blue,
      child: InkWell(
        onTap: () {
          // Go to settings when tapping the header
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SettingsScreen()),
          );
        },
        child: Container(
          height: 225,
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

              // Show sign in prompt if no accounts
              if (accounts.isEmpty) {
                return _buildSignInUI(context);
              }

              // Find the account to display - either the selected account or the default
              EmailAccount currentAccount;

              if (selectedAccountId != null) {
                // Try to find the selected account
                try {
                  currentAccount = accounts.firstWhere(
                    (acc) => acc.id == selectedAccountId,
                  );
                } catch (e) {
                  // Fall back to default or first account if selected not found
                  currentAccount = accounts.firstWhere(
                    (acc) => acc.isDefault,
                    orElse: () => accounts.first,
                  );
                }
              } else {
                // No selected ID, use default or first account
                currentAccount = accounts.firstWhere(
                  (acc) => acc.isDefault,
                  orElse: () => accounts.first,
                );
              }

              // Show account info with the determined current account
              return _buildAccountUI(context, accounts, currentAccount);
            },
          ),
        ),
      ),
    );
  }

  // Simple UI for when user is not signed in
  Widget _buildSignInUI(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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

  // UI for when user has account(s)
  Widget _buildAccountUI(
    BuildContext context,
    List<EmailAccount> accounts,
    EmailAccount currentAccount,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Profile picture
        CircleAvatar(
          backgroundImage:
              currentAccount.photoUrl != null
                  ? NetworkImage(currentAccount.photoUrl!)
                  : null,
          backgroundColor: Colors.grey[300],
          foregroundColor: Colors.white,
          radius: 30,
          child:
              currentAccount.photoUrl == null
                  ? Text(
                    currentAccount.displayName.isNotEmpty
                        ? currentAccount.displayName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                  : null,
        ),
        const SizedBox(height: 10),

        // Name
        Text(
          currentAccount.displayName,
          style: const TextStyle(color: Colors.white, fontSize: 18),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),

        // Email - with dropdown if multiple accounts
        accounts.length > 1
            ? _showAccountSelector(context, accounts, currentAccount)
            : _showSingleAccount(context, currentAccount),
      ],
    );
  }

  // For single account case
  Widget _showSingleAccount(BuildContext context, EmailAccount account) {
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
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // For multiple accounts case
  Widget _showAccountSelector(
    BuildContext context,
    List<EmailAccount> accounts,
    EmailAccount currentAccount,
  ) {
    return PopupMenuButton<EmailAccount>(
      onSelected: (account) {
        // Switch to selected account
        AuthService().setDefaultAccount(account.id).then((_) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Switched to ${account.email}')),
          );

          // Call the callback with the new account ID
          if (onAccountChanged != null) {
            onAccountChanged!(account.id);
          }
        });
      },
      offset: const Offset(0, 36),
      itemBuilder: (context) {
        // Create menu items for other accounts
        return accounts.where((acc) => acc.id != currentAccount.id).map((
          account,
        ) {
          return PopupMenuItem<EmailAccount>(
            value: account,
            height: 56,
            child: Row(
              children: [
                // Account avatar
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

                // Account details
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
          );
        }).toList();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            Expanded(
              child: Text(
                currentAccount.email,
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
}
