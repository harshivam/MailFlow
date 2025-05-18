import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:mail_merge/navigation/home_navigation.dart'; // Changed from home.dart
import 'package:mail_merge/user/authentication/add_email_accounts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mail_merge/user/models/email_account.dart';
import 'package:mail_merge/user/repository/account_repository.dart';
import 'package:mail_merge/utils/app_preferences.dart'; // Add this import
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
// Import the correct Windows WebView package
import 'package:desktop_webview_auth/desktop_webview_auth.dart';
import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:webview_flutter/webview_flutter.dart';

// Google OAuth configuration
// Use the Web Client ID you created in Google Cloud Console
final _webClientId =
    "180540721054-uqm5mqv50klcpmpufsskh3vkp2rb0dbh.apps.googleusercontent.com";
final _redirectUri = "http://localhost";

// Initialize GoogleSignIn with required Gmail API scopes
final GoogleSignIn _googleSignIn = GoogleSignIn(
  scopes: <String>[
    'email',
    'https://www.googleapis.com/auth/gmail.readonly', // Read Gmail messages
    'https://www.googleapis.com/auth/gmail.modify', // Modify but not delete messages
    'https://www.googleapis.com/auth/gmail.send', // Send emails
    'https://www.googleapis.com/auth/gmail.labels', // Manage labels
  ],
);



/// Handles the Google Sign-In process and user authentication
/// Returns void and navigates to Home screen on success
Future<void> signInWithGoogle(BuildContext context) async {
  try {
    // Check internet connection first
    final hasInternet = await checkInternetConnection(context);
    if (!hasInternet) return;

    // Special handling for Windows platform
    if (!kIsWeb && Platform.isWindows) {
      await _signInWithGoogleOnWindows(context);
      return;
    }

    // Initiate Google Sign-In flow
    final GoogleSignInAccount? account = await _googleSignIn.signIn();

    if (account == null) {
      // User aborted the sign-in process
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Login cancelled by user')));
      return;
    }

    // Get authentication tokens
    final GoogleSignInAuthentication auth = await account.authentication;
    final accessToken = auth.accessToken;
    final idToken = auth.idToken;

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Login successful: ${account.email}')),
    );

    // Debug logging
    print('Access Token: $accessToken');
    print('ID Token: $idToken');

    // Sync user data with local account system
    await syncCurrentUserToAccountSystem();

    if (account != null) {
      final emailAccount = EmailAccount(
        id: account.id,
        email: account.email,
        displayName: account.displayName ?? account.email,
        provider: AccountProvider.gmail,
        accessToken: auth.accessToken ?? '',
        refreshToken: auth.idToken ?? '',
        tokenExpiry: DateTime.now().add(const Duration(hours: 1)),
        photoUrl: account.photoUrl,
        isDefault: true,
      );

      // Store account in repository
      final accountRepo = AccountRepository();
      await accountRepo.addAccount(emailAccount);
      await accountRepo.setDefaultAccount(emailAccount.id);

      // Set login state
      await AppPreferences.setUserLoggedIn();

      if (context.mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeNavigation()),
        );
      }
    }
  } catch (error) {
    // Improve error handling
    String errorMessage = 'Login failed';

    if (error.toString().contains('network_error') ||
        error.toString().contains('Failed host lookup')) {
      errorMessage =
          'No internet connection. Please check your network settings.';
    } else {
      errorMessage = 'Login failed: $error';
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
      );
    }
    print('Sign-in error: $error');
  }
}

/// Fetches the most recent emails from Gmail API
/// [context] - BuildContext for showing messages
/// [accessToken] - Valid Gmail API access token
Future<void> fetchEmails(BuildContext context, String accessToken) async {
  try {
    // Request most recent 5 messages
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

      // Handle empty inbox
      if (messages == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No emails found')));
        return;
      }

      // Fetch detailed information for each message
      print('Fetched Emails:');
      for (var message in messages) {
        String messageId = message['id'];
        await fetchEmailDetails(context, accessToken, messageId);
      }
    } else {
      // Handle API errors
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

/// Retrieves detailed information for a specific email message
/// [messageId] - Unique identifier for the Gmail message
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

/// Retrieves a valid Google access token, either from storage or by refreshing
/// Returns null if unable to get a valid token
Future<String?> getGoogleAccessToken() async {
  try {
    print('DEBUG: getGoogleAccessToken called');

    // Check for stored token in account repository
    final accountRepository = AccountRepository();
    final defaultAccount = await accountRepository.getDefaultAccount();

    if (defaultAccount != null &&
        defaultAccount.provider == AccountProvider.gmail &&
        defaultAccount.accessToken.isNotEmpty) {
      // Validate token expiration
      final now = DateTime.now();
      if (now.isBefore(defaultAccount.tokenExpiry)) {
        print('DEBUG: Using stored token for ${defaultAccount.email}');
        return defaultAccount.accessToken;
      }
      print('DEBUG: Token expired, trying to refresh');
    }

    // Attempt silent sign-in for token refresh
    final GoogleSignInAccount? account = await _googleSignIn.signInSilently();
    print(
      'DEBUG: signInSilently returned: ${account != null ? account.email : "null"}',
    );

    if (account != null) {
      final GoogleSignInAuthentication auth = await account.authentication;
      print('DEBUG: Got access token for ${account.email}');

      // Update stored tokens
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

/// Performs complete sign-out, clearing all cached data and tokens
Future<void> signOut(BuildContext? context) async {
  try {
    // Clear stored preferences
    await AppPreferences.clearSession();

    // Clear account repository
    final accountRepo = AccountRepository();
    await accountRepo.deleteAllAccounts();

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

/// Retrieves the current signed-in Google user
Future<GoogleSignInAccount?> getCurrentUser() async {
  try {
    return _googleSignIn.currentUser ?? await _googleSignIn.signInSilently();
  } catch (e) {
    print('Error getting current user: $e');
    return null;
  }
}

/// Synchronizes the current Google user's data with the local account system
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

// Add this helper method at the top of the file
Future<bool> checkInternetConnection(BuildContext context) async {
  final connectivityResult = await Connectivity().checkConnectivity();
  final hasInternet = connectivityResult != ConnectivityResult.none;

  if (!hasInternet && context.mounted) {
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

  return hasInternet;
}

/// Windows-specific Google Sign-In implementation using WebView
Future<void> _signInWithGoogleOnWindows(BuildContext context) async {
  try {
    // Show a loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    // Check if WebView is available on the system
    if (!await WebviewWindow.isWebviewAvailable()) {
      Navigator.of(context).pop(); // Close loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'WebView is not available on this system. Please install WebView2 Runtime.',
          ),
        ),
      );
      return;
    }

    // Close loading dialog before launching WebView
    Navigator.of(context).pop();

    // OAuth 2.0 scopes for Gmail access
    final List<String> scopes = [
      'email',
      'https://www.googleapis.com/auth/gmail.readonly',
      'https://www.googleapis.com/auth/gmail.modify',
      'https://www.googleapis.com/auth/gmail.send',
      'https://www.googleapis.com/auth/gmail.labels',
    ];

    // Build the OAuth URL with your web client ID
    final scopesString = Uri.encodeComponent(scopes.join(' '));
    final authUrl =
        'https://accounts.google.com/o/oauth2/auth'
        '?client_id=$_webClientId'
        '&redirect_uri=${Uri.encodeComponent(_redirectUri)}'
        '&response_type=token'
        '&scope=$scopesString'
        '&prompt=select_account';

    // Create and launch webview window
    final webview = await WebviewWindow.create(
      configuration: const CreateConfiguration(
        title: "Google Sign In",
        windowWidth: 800,
        windowHeight: 1000,
      ),
    );

    // Register URL handler to capture OAuth redirect
    webview.addOnUrlRequestCallback((url) {
      if (url.startsWith(_redirectUri)) {
        // Extract token from URL fragment
        final uri = Uri.parse(url);
        final fragment = uri.fragment;
        if (fragment.isNotEmpty) {
          final params = Uri.splitQueryString(fragment);
          final accessToken = params['access_token'];
          final idToken = params['id_token'];
          final expiresIn = params['expires_in'];

          if (accessToken != null && context.mounted) {
            // Close the webview once we have the token
            webview.close();

            // Process the token
            _processGoogleTokenOnWindows(
              context: context,
              accessToken: accessToken,
              idToken: idToken,
              expiresIn: expiresIn,
            );
          }
        }
        // Handled the URL
      }
      // Not handled
    });

    // Launch the webview with Google OAuth URL
    webview.launch(authUrl);
  } catch (e) {
    print('Error with WebView window: $e');
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error launching sign-in: $e')));
    }
  }
}

/// Process the authentication token from WebView
Future<void> _processGoogleTokenOnWindows({
  required BuildContext context,
  required String accessToken,
  String? idToken,
  String? expiresIn,
}) async {
  try {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    // Fetch user information using the access token
    final userInfo = await _getUserInfoWithToken(accessToken);

    if (context.mounted) Navigator.of(context).pop(); // Close loading dialog

    if (userInfo != null) {
      // Calculate token expiry
      final int expirySeconds = int.tryParse(expiresIn ?? '3600') ?? 3600;
      final tokenExpiry = DateTime.now().add(Duration(seconds: expirySeconds));

      // Create an EmailAccount from the obtained info
      final emailAccount = EmailAccount(
        id:
            userInfo['id'] ??
            userInfo['sub'] ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        email: userInfo['email'] ?? '',
        displayName: userInfo['name'] ?? userInfo['email'] ?? 'Gmail User',
        provider: AccountProvider.gmail,
        accessToken: accessToken,
        refreshToken: idToken ?? '',
        tokenExpiry: tokenExpiry,
        photoUrl: userInfo['picture'],
        isDefault: true,
      );

      // Store account in repository
      final accountRepo = AccountRepository();
      await accountRepo.addAccount(emailAccount);
      await accountRepo.setDefaultAccount(emailAccount.id);

      // Set login state
      await AppPreferences.setUserLoggedIn();

      // Navigate to home screen
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login successful: ${userInfo['email']}')),
        );

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeNavigation()),
        );
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to get user information'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  } catch (e) {
    print('Error processing Google token on Windows: $e');
    if (context.mounted) {
      Navigator.of(context).pop(); // Close loading dialog if open
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error signing in: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

// Helper function to get user info with token
Future<Map<String, dynamic>?> _getUserInfoWithToken(String accessToken) async {
  try {
    final response = await http.get(
      Uri.parse('https://www.googleapis.com/oauth2/v3/userinfo'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      print(
        'Failed to get user info: ${response.statusCode}, ${response.body}',
      );
      return null;
    }
  } catch (e) {
    print('Error getting user info: $e');
    return null;
  }
}
