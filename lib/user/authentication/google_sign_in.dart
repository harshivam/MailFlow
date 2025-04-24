import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

final GoogleSignIn _googleSignIn = GoogleSignIn(
  scopes: <String>['email', 'https://www.googleapis.com/auth/gmail.readonly'],
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
  } catch (error) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Login failed: $error')));
    print('Sign-in error: $error');
  }
}
