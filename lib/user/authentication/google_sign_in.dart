import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:mail_merge/home.dart'; // Add this import

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

// Add this new function to get the access token

Future<String?> getGoogleAccessToken() async {
  try {
    final GoogleSignInAccount? account = await _googleSignIn.signInSilently();
    if (account != null) {
      final GoogleSignInAuthentication auth = await account.authentication;
      return auth.accessToken;
    } else {
      return null;
    }
  } catch (error) {
    print('Error getting access token: $error');
    return null;
  }
}