import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mail_merge/user/models/email_account.dart';
import 'package:mail_merge/user/repository/account_repository.dart';
import 'package:mail_merge/user/services/auth_service.dart';
import 'package:http/http.dart' as http;

class GmailAuthService implements EmailAuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: <String>[
      'email',
      'https://www.googleapis.com/auth/gmail.readonly',
      'https://www.googleapis.com/auth/gmail.modify',
      'https://www.googleapis.com/auth/gmail.send',
      'https://www.googleapis.com/auth/gmail.labels',
    ],
  );
  
  final AccountRepository _repository = AccountRepository();
  
  @override
  Future<EmailAccount?> signIn(BuildContext context) async {
    try {
      // Force account selection every time by signing out first
      await _googleSignIn.signOut();
      final GoogleSignInAccount? account = await _googleSignIn.signIn();

      if (account == null) {
        // User canceled the sign-in
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login cancelled by user')),
        );
        return null;
      }

      final GoogleSignInAuthentication auth = await account.authentication;
      
      // Calculate token expiry (typically 1 hour for Google)
      final tokenExpiry = DateTime.now().add(const Duration(hours: 1));
      
      // Create email account model
      return EmailAccount(
        email: account.email,
        displayName: account.displayName ?? account.email,
        provider: AccountProvider.gmail,
        accessToken: auth.accessToken ?? '',
        refreshToken: auth.idToken ?? '', // Using idToken as refreshToken for now
        tokenExpiry: tokenExpiry,
        photoUrl: account.photoUrl,
      );
    } catch (e) {
      print('Error signing in with Google: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing in: $e')),
      );
      return null;
    }
  }
  
  @override
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      print('Error signing out from Google: $e');
    }
  }
  
  @override
  Future<bool> isTokenValid(String accessToken) async {
    try {
      final response = await http.get(
        Uri.parse('https://www.googleapis.com/oauth2/v3/tokeninfo?access_token=$accessToken'),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error checking token validity: $e');
      return false;
    }
  }
  
  @override
  Future<String?> refreshToken(String accountId) async {
    try {
      // For Google Sign-In in Flutter, we need to re-authenticate to get a new token
      final currentUser = await _googleSignIn.signInSilently();
      if (currentUser == null) return null;
      
      final auth = await currentUser.authentication;
      final accessToken = auth.accessToken;
      
      if (accessToken != null) {
        // Update the stored token
        await _repository.updateAccountTokens(
          accountId: accountId,
          accessToken: accessToken,
          refreshToken: auth.idToken ?? '',
          tokenExpiry: DateTime.now().add(const Duration(hours: 1)),
        );
      }
      
      return accessToken;
    } catch (e) {
      print('Error refreshing token: $e');
      return null;
    }
  }
}