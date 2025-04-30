import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:mail_merge/home.dart'; // Add this import
import 'package:mail_merge/user/authentication/add_email_accounts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mail_merge/user/models/email_account.dart';
import 'package:mail_merge/user/repository/account_repository.dart';

final GoogleSignIn _googleSignIn = GoogleSignIn(
  scopes: <String>[
    'email',
    'https://www.googleapis.com/auth/gmail.readonly',
    'https://www.googleapis.com/auth/gmail.modify',
    'https://www.googleapis.com/auth/gmail.send',
    'https://www.googleapis.com/auth/gmail.labels',
  ],
);

Future<void> signInWithGoogle(BuildContext context) async {
  try {
    final GoogleSignInAccount? account = await _googleSignIn.signIn();

    if (account == null) {
      // User canceled the sign-in
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Login cancelled by user')));
      return;
    }

    final GoogleSignInAuthentication auth = await account.authentication;

    final accessToken = auth.accessToken;
    final idToken = auth.idToken;

    // Show snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Login successful: ${account.email}')),
    );

    print('Access Token: $accessToken');
    print('ID Token: $idToken');

    // Add this line right before you navigate to Home
    await syncCurrentUserToAccountSystem();

    // Navigate to Home screen after successful sign-in
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const Home()),
    );
  } catch (error) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Login failed: $error')));
    print('Sign-in error: $error');
  }
}

Future<void> fetchEmails(BuildContext context, String accessToken) async {
  try {
    final response = await http.get(
      Uri.parse(
        'https://gmail.googleapis.com/gmail/v1/users/me/messages?maxResults=5',
      ),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      var data = json.decode(response.body);
      var messages = data['messages'];

      if (messages == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No emails found')));
        return;
      }

      print('Fetched Emails:');
      for (var message in messages) {
        String messageId = message['id'];

        // Fetch details like Subject + Snippet
        await fetchEmailDetails(context, accessToken, messageId);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to fetch emails: ${response.statusCode}'),
        ),
      );
      print('Failed to fetch emails: ${response.body}');
    }
  } catch (error) {
    print('Error fetching emails: $error');
  }
}

Future<void> fetchEmailDetails(
  BuildContext context,
  String accessToken,
  String messageId,
) async {
  final response = await http.get(
    Uri.parse(
      'https://gmail.googleapis.com/gmail/v1/users/me/messages/$messageId',
    ),
    headers: {
      'Authorization': 'Bearer $accessToken',
      'Accept': 'application/json',
    },
  );

  if (response.statusCode == 200) {
    var emailData = json.decode(response.body);

    String snippet = emailData['snippet'] ?? '';
    List headers = emailData['payload']['headers'];

    String subject = 'No Subject';
    for (var header in headers) {
      if (header['name'] == 'Subject') {
        subject = header['value'];
        break;
      }
    }

    print('Subject: $subject');
    print('Snippet: $snippet');
    print('----------------------------------');
  } else {
    print('Failed to fetch email details: ${response.statusCode}');
  }
}

Future<String?> getGoogleAccessToken() async {
  try {
    print('DEBUG: getGoogleAccessToken called');
    
    // First check if we have tokens stored in the account repository
    final accountRepository = AccountRepository();
    final defaultAccount = await accountRepository.getDefaultAccount();
    
    if (defaultAccount != null && 
        defaultAccount.provider == AccountProvider.gmail &&
        defaultAccount.accessToken.isNotEmpty) {
      // Check if token has expired
      final now = DateTime.now();
      if (now.isBefore(defaultAccount.tokenExpiry)) {
        print('DEBUG: Using stored token for ${defaultAccount.email}');
        return defaultAccount.accessToken;
      }
      
      // Token expired, try to refresh with Google Sign-In
      print('DEBUG: Token expired, trying to refresh');
    }
    
    // If no stored token or it expired, try to get from Google Sign-In
    final GoogleSignInAccount? account = await _googleSignIn.signInSilently();
    print('DEBUG: signInSilently returned: ${account != null ? account.email : "null"}');
    
    if (account != null) {
      final GoogleSignInAuthentication auth = await account.authentication;
      print('DEBUG: Got access token for ${account.email}');
      
      // Update the stored token
      if (defaultAccount != null) {
        await accountRepository.updateAccountTokens(
          accountId: defaultAccount.id,
          accessToken: auth.accessToken ?? '',
          refreshToken: auth.idToken ?? '',
          tokenExpiry: DateTime.now().add(const Duration(hours: 1)),
        );
      }
      
      return auth.accessToken;
    }
    
    print('DEBUG: No Google account, returning null token');
    return null;
  } catch (error) {
    print('ERROR getting access token: $error');
    return null;
  }
}

Future<void> signOut(BuildContext? context) async {
  try {
    // Clear ALL cached data thoroughly
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cached_emails');
    await prefs.remove('cached_vip_emails');
    await prefs.remove('cached_vip_emails_by_contact');
    await prefs.remove('cached_vip_contacts');

    // Also clear the account repository (secure storage)
    final accountRepository = AccountRepository();
    final accounts = await accountRepository.getAllAccounts();
    for (final account in accounts) {
      await accountRepository.deleteAccount(account.id);
    }

    // Then sign out from Google
    await _googleSignIn.signOut();
    print('User signed out and cache cleared');

    // Navigate to login screen if context is provided
    if (context != null && context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const AddEmailAccountsPage()),
        (route) => false, // Remove all previous routes
      );
    }
  } catch (e) {
    print('Error signing out: $e');
  }
}

Future<GoogleSignInAccount?> getCurrentUser() async {
  try {
    return _googleSignIn.currentUser ?? await _googleSignIn.signInSilently();
  } catch (e) {
    print('Error getting current user: $e');
    return null;
  }
}

Future<void> syncCurrentUserToAccountSystem() async {
  try {
    final GoogleSignInAccount? googleUser = await getCurrentUser();
    if (googleUser == null) return;

    // Get authentication data
    final GoogleSignInAuthentication auth = await googleUser.authentication;

    // Create email account object
    final emailAccount = EmailAccount(
      email: googleUser.email,
      displayName: googleUser.displayName ?? googleUser.email,
      provider: AccountProvider.gmail,
      accessToken: auth.accessToken ?? '',
      refreshToken: auth.idToken ?? '',
      tokenExpiry: DateTime.now().add(const Duration(hours: 1)),
      photoUrl: googleUser.photoUrl,
      isDefault: true,
    );

    // Add to account repository
    final accountRepository = AccountRepository();
    await accountRepository.addAccount(emailAccount);

    print('Current Google user synced to account system: ${googleUser.email}');
  } catch (e) {
    print('Error syncing current user to account system: $e');
  }
}
