import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:mail_merge/user/authentication/add_email_accounts.dart'; // Add this import
import 'package:mail_merge/utils/app_preferences.dart'; // Import AppPreferences

class Firstscreen extends StatefulWidget {
  const Firstscreen({super.key});

  @override
  State<Firstscreen> createState() => _FirstscreenState();
}

class _FirstscreenState extends State<Firstscreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBackground(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildIllustration(),
            const SizedBox(height: 20),
            _buildTitle(),
            const SizedBox(height: 30),
            _buildContinueButton(),
          ],
        ),
      ),
    );
  }

  // Background color container
  Widget _buildBackground({required Widget child}) {
    return Container(
      decoration: const BoxDecoration(color: Colors.white),
      child: Center(child: child),
    );
  }

  // Lottie animation
  Widget _buildIllustration() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40.0),
      child: Lottie.asset(
        'assets/lottie/mail.json',
        width: 300,
        height: 300,
        fit: BoxFit.cover,
      ),
    );
  }

  // App title and subtitle
  Widget _buildTitle() {
    return Column(
      children: const [
        Text(
          "Mail Flow",
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.black26,
          ),
        ),
        SizedBox(height: 10),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 40.0),
          child: Text(
            "Tired of constantly switching email accounts? Let us make it seamless for you!",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Color.fromARGB(179, 0, 0, 0)),
          ),
        ),
      ],
    );
  }

  // Continue button
  Widget _buildContinueButton() {
    return SizedBox(
      width: 250,
      height: 50,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color.fromARGB(255, 13, 110, 255),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
        ),
        onPressed: () async {
          // Use the correct method from AppPreferences
          await AppPreferences.setFirstLaunchComplete();

          if (context.mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => const AddEmailAccountsPage(),
              ),
            );
          }
        },
        child: const Text(
          "CONTINUE",
          style: TextStyle(fontSize: 18, color: Colors.white),
        ),
      ),
    );
  }
}
