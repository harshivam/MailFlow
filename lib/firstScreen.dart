import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:mail_merge/login/login_page.dart';
import 'package:mail_merge/login/sign_up.dart';

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
            _buildButtons(),
          ],
        ),
      ),
    );
  }

  // gradient
  Widget _buildBackground({required Widget child}) {
    return Container(
      decoration: const BoxDecoration(color: Colors.white),
      child: Center(child: child),
    );
  }

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

  /// title and subtitle text
  Widget _buildTitle() {
    return Column(
      children: const [
        Text(
          "Mail Merge",
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

  /// Login & Sign Up buttons
  Widget _buildButtons() {
    return Column(
      children: [
        SizedBox(
          width: 250,
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 13, 110, 255),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
              );
            },
            child: const Text(
              "LOGIN",
              style: TextStyle(fontSize: 18, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 15),
        SizedBox(
          width: 250,
          height: 50,
          child: Material(
            elevation: 4, // Adds shadow effect
            borderRadius: BorderRadius.circular(25), // Same as button shape
            shadowColor: Colors.grey.withOpacity(0.5), // Soft shadow
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.transparent,
                side: const BorderSide(
                  color: Colors.grey,
                  width: 1,
                ), // Subtle grey border
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SignUp()),
                );
              },
              child: const Text(
                "SIGN UP",
                style: TextStyle(fontSize: 18, color: Colors.black),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
