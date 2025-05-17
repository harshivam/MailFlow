import 'package:flutter/material.dart';
import 'package:mail_merge/firstScreen.dart';
import 'package:mail_merge/user/authentication/add_email_accounts.dart';
import 'package:mail_merge/utils/app_preferences.dart';
import 'package:mail_merge/navigation/home_navigation.dart';
import 'package:mail_merge/user/repository/account_repository.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Check both login state and active account
  final hasSession = await AppPreferences.hasActiveSession();
  final accountRepo = AccountRepository();
  final defaultAccount = await accountRepo.getDefaultAccount();

  // Only consider logged in if we have both session and active account
  final isLoggedIn = hasSession && defaultAccount != null;
  final isFirstLaunch = !hasSession && defaultAccount == null;

  runApp(MyApp(
    isFirstLaunch: isFirstLaunch,
    isLoggedIn: isLoggedIn,
  ));
}

class MyApp extends StatelessWidget {
  final bool isFirstLaunch;
  final bool isLoggedIn;

  const MyApp({
    super.key,
    required this.isFirstLaunch,
    required this.isLoggedIn,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mail Merge',
      debugShowCheckedModeBanner: false,
      // Add the navigator key here
      navigatorKey: navigatorKey,
      theme: ThemeData(primarySwatch: Colors.blue),
      home:
          isFirstLaunch
              ? const Firstscreen()
              : isLoggedIn
              ? const HomeNavigation()
              : const AddEmailAccountsPage(),
    );
  }
}
