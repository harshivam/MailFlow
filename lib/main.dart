import 'package:flutter/material.dart';
import 'package:mail_merge/navigation/home_navigation.dart';
import 'package:mail_merge/user/authentication/google_sign_in.dart';
import 'package:mail_merge/login/login_page.dart';
import 'package:mail_merge/user/authentication/add_email_accounts.dart';
import 'package:mail_merge/user/repository/account_repository.dart';

// Add this global navigator key
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // Make sure this is added
      title: 'MailFlow',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const AuthCheckScreen(),
    );
  }
}

class AuthCheckScreen extends StatefulWidget {
  const AuthCheckScreen({super.key});

  @override
  State<AuthCheckScreen> createState() => _AuthCheckScreenState();
}

class _AuthCheckScreenState extends State<AuthCheckScreen> {
  bool _isLoading = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    try {
      // Ensure we have access to secure storage content
      await Future.delayed(const Duration(milliseconds: 100));

      // Print debug info to trace the issue
      print('DEBUG: Checking login status on app startup');

      // First check the account repository (more reliable for persistence)
      final accountRepository = AccountRepository();
      final accounts = await accountRepository.getAllAccounts();

      print('DEBUG: Found ${accounts.length} accounts in repository');

      // If we have accounts stored, the user is logged in
      final hasAccounts = accounts.isNotEmpty;

      if (hasAccounts) {
        print('DEBUG: User has accounts, logging in directly');
        if (mounted) {
          setState(() {
            _isLoggedIn = true;
            _isLoading = false;
          });
        }
        return;
      }

      // Only if no accounts found, try Google Sign-In
      final user = await getCurrentUser();
      print(
        'DEBUG: Google Sign-In check returned: ${user != null ? user.email : "null"}',
      );

      if (user != null) {
        // We have a Google user but no accounts - sync it
        print('DEBUG: Syncing Google user to account system');
        await syncCurrentUserToAccountSystem();

        // Check again after syncing
        final accountsAfterSync = await accountRepository.getAllAccounts();
        print('DEBUG: After sync, found ${accountsAfterSync.length} accounts');

        if (mounted) {
          setState(() {
            _isLoggedIn = true;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoggedIn = false;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error checking login status: $e');
      if (mounted) {
        setState(() {
          _isLoggedIn = false;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_isLoggedIn) {
      return const HomeNavigation();
    } else {
      return const AddEmailAccountsPage();
    }
  }
}
