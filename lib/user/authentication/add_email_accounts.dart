import 'package:flutter/material.dart';
import 'package:mail_merge/home.dart';
import 'package:mail_merge/navigation/home_navigation.dart';
import 'package:mail_merge/user/authentication/google_sign_in.dart';
import 'package:mail_merge/user/models/email_account.dart';
import 'package:mail_merge/user/services/auth_service.dart';
import 'package:mail_merge/user/services/providers/outlook_auth_service.dart';
import 'package:mail_merge/user/repository/account_repository.dart'; // Add this import

class AddEmailAccountsPage extends StatelessWidget {
  const AddEmailAccountsPage({super.key});

  // Add this method for Outlook sign-in
  Future<void> signInWithOutlook(BuildContext context) async {
    final authService = OutlookAuthService();
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Center(child: CircularProgressIndicator());
        },
      );

      final account = await authService.signIn(context);

      // Close loading dialog if it's still shown
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (account != null && context.mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully logged in to Outlook'),
            duration: Duration(seconds: 2),
          ),
        );

        // Important: Make sure the account is properly stored before navigation
        final accountRepo = AccountRepository();
        await accountRepo.addAccount(account);

        // Navigate to HomeNavigation and remove all previous routes
        if (context.mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const HomeNavigation()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      print('Error in Outlook sign-in: $e');
      if (context.mounted) {
        // Close loading dialog if there's an error
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing in with Outlook: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Add Email Accounts",
          style: TextStyle(color: Colors.black),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const Home()),
              );
            },
            child: const Text(
              "Skip",
              style: TextStyle(color: Colors.blue, fontSize: 16),
            ),
          ),
          SizedBox(width: 16),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Choose an email service:",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 20),
            _buildEmailOption(
              context,
              icon: Icons.email,
              color: Colors.red,
              label: "Gmail",
              onTap: () {
                signInWithGoogle(context);
              },
            ),
            const Divider(),
            // Update only the Outlook option, leaving Gmail as is
            _buildEmailOption(
              context,
              icon: Icons.email,
              color: Colors.blue,
              label: "Outlook",
              onTap: () => signInWithOutlook(context),
            ),
            const Divider(),
            _buildEmailOption(
              context,
              icon: Icons.email,
              color: Colors.purple,
              label: "Yahoo",
            ),
            const Divider(),
            _buildEmailOption(
              context,
              icon: Icons.more_horiz,
              color: Colors.grey,
              label: "Other",
            ),
          ],
        ),
      ),
      // Add a persistent footer note as an additional reminder
      persistentFooterButtons: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "You can manage your email accounts anytime from Settings → Accounts",
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmailOption(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String label,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        label,
        style: const TextStyle(fontSize: 16, color: Colors.black),
      ),
      onTap:
          onTap ??
          () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const Home()),
            );
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text("$label selected")));
          },
    );
  }
}
