import 'package:flutter/material.dart';
import 'package:mail_merge/navigation/home_navigation.dart';
import 'package:mail_merge/user/models/email_account.dart';
import 'package:mail_merge/user/services/auth_service.dart';

class AddEmailAccountsScreen extends StatelessWidget {
  const AddEmailAccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    
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
                MaterialPageRoute(builder: (context) => const HomeNavigation()),
              );
            },
            child: const Text(
              "Skip",
              style: TextStyle(color: Colors.blue, fontSize: 16),
            ),
          ),
          const SizedBox(width: 16),
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
            
            // Gmail option
            _buildEmailOption(
              context,
              icon: Icons.email,
              color: Colors.red,
              label: "Gmail",
              onTap: () async {
                final account = await authService.signInWithProvider(
                  AccountProvider.gmail,
                  context,
                );
                
                if (account != null && context.mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const HomeNavigation(),
                    ),
                  );
                }
              },
            ),
            
            const Divider(),
            
            // Outlook option
            _buildEmailOption(
              context,
              icon: Icons.email,
              color: Colors.blue,
              label: "Outlook",
              onTap: () async {
                final account = await authService.signInWithProvider(
                  AccountProvider.outlook,
                  context,
                );
                
                if (account != null && context.mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const HomeNavigation(),
                    ),
                  );
                }
              },
            ),
            
            const Divider(),
            
            // Rediffmail option
            _buildEmailOption(
              context,
              icon: Icons.email,
              color: Colors.purple,
              label: "Rediffmail",
              onTap: () async {
                final account = await authService.signInWithProvider(
                  AccountProvider.rediffmail,
                  context,
                );
                
                if (account != null && context.mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const HomeNavigation(),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
      
      // Footer note
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
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        label,
        style: const TextStyle(fontSize: 16, color: Colors.black),
      ),
      onTap: onTap,
    );
  }
}