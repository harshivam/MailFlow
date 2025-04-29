import 'package:flutter/material.dart';
import 'package:mail_merge/navigation/home_navigation.dart';
import 'package:mail_merge/user/authentication/google_sign_in.dart';
import 'package:mail_merge/login/login_page.dart';
import 'package:mail_merge/user/authentication/add_email_accounts.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mail Flow',
      debugShowCheckedModeBanner: false, // Remove debug banner
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
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
    final user = await getCurrentUser();
    if (mounted) {
      setState(() {
        _isLoggedIn = user != null;
        _isLoading = false;
      });
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
