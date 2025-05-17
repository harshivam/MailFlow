import 'package:flutter/material.dart';
import 'package:mail_merge/user/models/email_account.dart';
import 'package:mail_merge/user/repository/account_repository.dart';
import 'package:mail_merge/user/services/auth_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:aad_oauth/aad_oauth.dart';
import 'package:aad_oauth/model/config.dart';
import 'package:mail_merge/main.dart'; // Add this import
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:mail_merge/utils/app_preferences.dart';

class OutlookAuthService implements EmailAuthService {
  final String clientId = '7d5e7647-1194-4da1-b42b-23870b41bea6';
  final String redirectUri =
      'msauth://com.example.mail_merge/554f1e2c784e5fd10b2f78d7d34422e0b2fc02fb';
  final String tenant = 'common';

  late final AadOAuth oauth;
  final _storage = const FlutterSecureStorage();

  OutlookAuthService() {
    final config = Config(
      tenant: tenant,
      clientId: clientId,
      scope:
          'https://graph.microsoft.com/Mail.Read https://graph.microsoft.com/Mail.Send offline_access User.Read',
      redirectUri: redirectUri,
      navigatorKey: navigatorKey, // Use the global navigator key
      loader: const Center(child: CircularProgressIndicator()),
      webUseRedirect: true,
    );
    oauth = AadOAuth(config);
  }

  @override
  Future<EmailAccount?> signIn(BuildContext context) async {
    try {
      // Check internet connection first
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No internet connection. Please check your network settings.',
              ),
              duration: Duration(seconds: 3),
              backgroundColor: Colors.red,
            ),
          );
        }
        return null;
      }

      print('Starting Outlook sign-in process...'); // Debug log

      if (!context.mounted) {
        print('Context is not mounted'); // Debug log
        return null;
      }

      print('Initiating OAuth login...'); // Debug log
      await oauth.login();

      print('OAuth login completed, getting access token...'); // Debug log
      final accessToken = await oauth.getAccessToken();

      if (accessToken != null) {
        print('Access token received, fetching user info...'); // Debug log
        final userInfo = await _getUserInfo(accessToken);

        if (userInfo != null) {
          final account = EmailAccount(
            id: userInfo['id'],
            email: userInfo['userPrincipalName'],
            displayName: userInfo['displayName'],
            provider: AccountProvider.outlook,
            accessToken: accessToken,
            refreshToken: '', // Not needed for Outlook
            tokenExpiry: DateTime.now().add(const Duration(hours: 1)),
            photoUrl: null,
          );

          // Store the access token securely
          await _storage.write(
            key: 'outlook_access_token_${account.id}',
            value: accessToken,
          );

          // Store account
          final accountRepo = AccountRepository();
          await accountRepo.addAccount(account);
          await accountRepo.setDefaultAccount(account.id);

          // Set login state
          await AppPreferences.setUserLoggedIn();

          return account;
        }
      }
      return null;
    } catch (e) {
      print('Outlook sign in error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().contains('network_error')
                  ? 'No internet connection. Please check your network settings.'
                  : 'Outlook sign-in error: $e',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }

  Future<Map<String, dynamic>?> _getUserInfo(String accessToken) async {
    try {
      final response = await http.get(
        Uri.parse('https://graph.microsoft.com/v1.0/me'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      print('Error getting user info: $e');
    }
    return null;
  }

  @override
  Future<void> signOut() async {
    await oauth.logout();
    final accounts = await _storage.readAll();
    for (var entry in accounts.entries) {
      if (entry.key.startsWith('outlook_')) {
        await _storage.delete(key: entry.key);
      }
    }
  }

  @override
  Future<bool> isTokenValid(String accessToken) async {
    try {
      final response = await http.get(
        Uri.parse('https://graph.microsoft.com/v1.0/me'),
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<String?> refreshToken(String accountId) async {
    try {
      // Re-authenticate to refresh the token
      await oauth.login();
      final newAccessToken = await oauth.getAccessToken();
      if (newAccessToken != null) {
        await _storage.write(
          key: 'outlook_access_token_$accountId',
          value: newAccessToken,
        );
        return newAccessToken;
      }
    } catch (e) {
      print('Error refreshing token: $e');
    }
    return null;
  }
}
