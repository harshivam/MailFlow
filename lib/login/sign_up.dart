import 'package:flutter/material.dart';
import 'package:mail_merge/login/login_page.dart';
import 'package:lottie/lottie.dart';

class SignUp extends StatefulWidget {
  const SignUp({super.key});

  @override
  State<SignUp> createState() => _SignUpState();
}

class _SignUpState extends State<SignUp> {
  bool _showConfetti = false; // State variable to control confetti display

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(color: Colors.white),
          if (_showConfetti)
            _buildConfettiAnimation(), // Show confetti when true
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [_buildIllustration()],
                ),
                const Text(
                  "Welcome 📧",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 10),

                // Name Field
                TextField(
                  decoration: InputDecoration(
                    labelText: "Name",
                    labelStyle: const TextStyle(color: Colors.grey),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.person, color: Colors.grey),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.2),
                  ),
                  style: const TextStyle(color: Colors.black),
                ),
                const SizedBox(height: 16),

                // Email Field
                TextField(
                  decoration: InputDecoration(
                    labelText: "Email",
                    labelStyle: const TextStyle(color: Colors.grey),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.email, color: Colors.grey),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.2),
                  ),
                  style: const TextStyle(color: Colors.black),
                ),
                const SizedBox(height: 16),

                // Password Field
                TextField(
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: "Password",
                    labelStyle: const TextStyle(color: Colors.grey),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.lock, color: Colors.grey),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.2),
                  ),
                  style: const TextStyle(color: Colors.black),
                ),
                const SizedBox(height: 30),

                // Buttons: Sign Up & Login
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _showConfetti = true; // Trigger confetti animation
                          });

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                "Successfully Signed Up! Click on Login.",
                              ),
                              duration: Duration(seconds: 2),
                            ),
                          );

                          Future.delayed(const Duration(seconds: 2), () {
                            setState(() {
                              _showConfetti =
                                  false; // Hide confetti after 2 seconds
                            });
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text(
                          "Sign Up",
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LoginPage(),
                            ),
                          ); // Navigate back to login screen
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          backgroundColor: Colors.grey[800],
                          foregroundColor: Colors.white,
                        ),
                        child: const Text(
                          "Login",
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Already have an account? Login
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context); // Navigate back to login
                  },
                  child: const Text(
                    "Already have an account? Sign in",
                    style: TextStyle(color: Colors.blue, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfettiAnimation() {
    return Positioned.fill(
      child: Center(
        child: Lottie.asset(
          'assets/lottie/confetti.json',
          width: 600,
          height: 600,
          repeat: false,
        ),
      ),
    );
  }
}

Widget _buildIllustration() {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 40.0),
    child: Lottie.asset(
      'assets/lottie/Signup.json',
      width: 300,
      height: 300,
      fit: BoxFit.cover,
    ),
  );
}
