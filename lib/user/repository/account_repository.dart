import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mail_merge/user/models/email_account.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AccountRepository {
  static const String _accountsKey = 'email_accounts';
  static const _storage = FlutterSecureStorage();

  // Get all accounts
  Future<List<EmailAccount>> getAllAccounts() async {
    try {
      final accountsJson = await _storage.read(key: _accountsKey);
      if (accountsJson == null) return [];

      final List<dynamic> accountsList = jsonDecode(accountsJson);
      return accountsList.map((acc) => EmailAccount.fromJson(acc)).toList();
    } catch (e) {
      print('Error loading accounts: $e');
      return [];
    }
  }

  // Save all accounts
  Future<void> saveAccounts(List<EmailAccount> accounts) async {
    try {
      final accountsJson = jsonEncode(
        accounts.map((acc) => acc.toJson()).toList(),
      );
      await _storage.write(key: _accountsKey, value: accountsJson);
    } catch (e) {
      print('Error saving accounts: $e');
    }
  }

  // Add a new account
  Future<void> addAccount(EmailAccount account) async {
    final accounts = await getAllAccounts();

    // Remove existing account with same email if exists
    accounts.removeWhere(
      (acc) =>
          acc.email.toLowerCase() == account.email.toLowerCase() &&
          acc.provider == account.provider,
    );

    // If this is the first account or marked as default, ensure it's the only default
    if (account.isDefault || accounts.isEmpty) {
      final updatedAccounts =
          accounts.map((acc) => acc.copyWith(isDefault: false)).toList();
      accounts.clear();
      accounts.addAll(updatedAccounts);

      // Add the new account as default if it's the first one
      if (accounts.isEmpty) {
        accounts.add(account.copyWith(isDefault: true));
      } else {
        accounts.add(account);
      }
    } else {
      accounts.add(account);
    }

    await saveAccounts(accounts);
  }

  // Get default account
  Future<EmailAccount?> getDefaultAccount() async {
    final accounts = await getAllAccounts();
    if (accounts.isEmpty) return null;

    // Find the default account
    final defaultAccount = accounts.firstWhere(
      (acc) => acc.isDefault,
      orElse: () => accounts.first, // If no default, use the first one
    );

    return defaultAccount;
  }

  // Set default account
  Future<void> setDefaultAccount(String accountId) async {
    final accounts = await getAllAccounts();
    if (accounts.isEmpty) return;

    final updatedAccounts =
        accounts.map((acc) {
          return acc.copyWith(isDefault: acc.id == accountId);
        }).toList();

    await saveAccounts(updatedAccounts);
  }

  // Delete an account
  Future<void> deleteAccount(String accountId) async {
    final accounts = await getAllAccounts();
    final wasDefault = accounts.any(
      (acc) => acc.id == accountId && acc.isDefault,
    );

    accounts.removeWhere((acc) => acc.id == accountId);

    // If we removed the default account and there are other accounts left,
    // make the first one the default
    if (wasDefault && accounts.isNotEmpty) {
      accounts[0] = accounts[0].copyWith(isDefault: true);
    }

    await saveAccounts(accounts);
  }

  // Delete all accounts
  Future<void> deleteAllAccounts() async {
    // Implementation to clear all stored accounts
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) => key.startsWith('account_'));

    for (var key in keys) {
      await prefs.remove(key);
    }

    // Clear default account
    await prefs.remove('default_account_id');
  }

  // Update token information for an account
  Future<void> updateAccountTokens({
    required String accountId,
    required String accessToken,
    required String refreshToken,
    required DateTime tokenExpiry,
  }) async {
    final accounts = await getAllAccounts();
    final index = accounts.indexWhere((acc) => acc.id == accountId);

    if (index >= 0) {
      accounts[index] = accounts[index].copyWith(
        accessToken: accessToken,
        refreshToken: refreshToken,
        tokenExpiry: tokenExpiry,
      );

      await saveAccounts(accounts);
    }
  }

  Future<EmailAccount> getAccountById(String id) async {
    final accounts = await getAllAccounts();
    final account = accounts.firstWhere(
      (account) => account.id == id,
      orElse: () => throw Exception('Account not found with ID: $id'),
    );
    return account;
  }
}
