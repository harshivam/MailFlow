import 'package:flutter/material.dart';
import 'package:mail_merge/user/models/email_account.dart';
import 'package:mail_merge/user/repository/account_repository.dart';
import 'package:mail_merge/user/services/providers/gmail_auth_service.dart';
import 'package:mail_merge/user/services/providers/outlook_auth_service.dart';
import 'package:mail_merge/user/services/providers/rediffmail_auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class EmailAuthService {
  Future<EmailAccount?> signIn(BuildContext context);
  Future<void> signOut();
  Future<bool> isTokenValid(String accessToken);
  Future<String?> refreshToken(String accountId);
}

class AuthService {
  final GmailAuthService _gmailAuthService = GmailAuthService();
  final OutlookAuthService _outlookAuthService = OutlookAuthService();
  final RediffmailAuthService _rediffmailAuthService = RediffmailAuthService();
  final AccountRepository _accountRepository = AccountRepository();

  // Get auth service based on provider
  EmailAuthService _getProviderService(AccountProvider provider) {
    switch (provider) {
      case AccountProvider.gmail:
        return _gmailAuthService;
      case AccountProvider.outlook:
        return _outlookAuthService;
      case AccountProvider.rediffmail:
        return _rediffmailAuthService;
    }
  }

  // Sign in with a specific provider
  Future<EmailAccount?> signInWithProvider(
    AccountProvider provider,
    BuildContext context,
  ) async {
    final service = _getProviderService(provider);
    final account = await service.signIn(context);

    if (account != null) {
      // Make this account default if there are no other accounts
      final accounts = await _accountRepository.getAllAccounts();
      if (accounts.isEmpty) {
        await _accountRepository.addAccount(account.copyWith(isDefault: true));
      } else {
        await _accountRepository.addAccount(account);
      }
    }

    return account;
  }

  // Get all accounts
  Future<List<EmailAccount>> getAllAccounts() {
    return _accountRepository.getAllAccounts();
  }

  // Get default account
  Future<EmailAccount?> getDefaultAccount() {
    return _accountRepository.getDefaultAccount();
  }

  // Set default account
  Future<void> setDefaultAccount(String accountId) {
    return _accountRepository.setDefaultAccount(accountId);
  }

  // Remove an account
  Future<void> removeAccount(String accountId) async {
    // Get the account details first
    final accounts = await _accountRepository.getAllAccounts();

    // Extra check: if there are no accounts, just return
    if (accounts.isEmpty) return;

    final isLastAccount = accounts.length <= 1;

    final accountToRemove = accounts.firstWhere(
      (acc) => acc.id == accountId,
      orElse: () => throw Exception('Account not found'),
    );

    // Sign out from the provider
    final service = _getProviderService(accountToRemove.provider);
    await service.signOut();

    // Remove from storage
    await _accountRepository.deleteAccount(accountId);

    // If this is the last/only account, do a complete cleanup
    if (isLastAccount) {
      // Clear all cached data
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cached_emails');
      await prefs.remove('cached_vip_emails');
      await prefs.remove('cached_vip_emails_by_contact');
      await prefs.remove('cached_vip_contacts');

      // Additional cleanup as needed for your app
      // This ensures a clean slate when the user logs out completely
    }
  }

  // Sign out from all accounts
  Future<void> signOutAll() async {
    final accounts = await _accountRepository.getAllAccounts();

    // Sign out from each account
    for (final account in accounts) {
      final service = _getProviderService(account.provider);
      await service.signOut();
    }

    // Clear cached data
    // This would be implemented according to your caching strategy
  }

  // Get a valid access token for an account
  Future<String?> getAccessToken(String accountId) async {
    final accounts = await _accountRepository.getAllAccounts();
    final account = accounts.firstWhere(
      (acc) => acc.id == accountId,
      orElse: () => throw Exception('Account not found'),
    );

    // Check if token is expired
    if (DateTime.now().isAfter(account.tokenExpiry)) {
      // Try to refresh the token
      return await _getProviderService(
        account.provider,
      ).refreshToken(accountId);
    }

    return account.accessToken;
  }

  // Get a valid access token for the default account
  Future<String?> getDefaultAccessToken() async {
    final defaultAccount = await _accountRepository.getDefaultAccount();
    if (defaultAccount == null) return null;

    return await getAccessToken(defaultAccount.id);
  }
}
