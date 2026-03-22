import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'first_register_page.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEFFD3), // Light yellow background
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SizedBox(height: MediaQuery.of(context).size.height * 0.08),
              // Logo and App Name
              Column(
                children: [
                  // Logo Image
                  Container(
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Image.asset(
                      'assets/images/pawbudget_Tlogo.png', // Your logo path
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // App Title
                  // RichText(
                  //   text: const TextSpan(
                  //     children: [
                  //       TextSpan(
                  //         text: 'Paw',
                  //         style: TextStyle(
                  //           fontSize: 36,
                  //           fontWeight: FontWeight.bold,
                  //           color: Color(0xFFF39C12), // Orange
                  //         ),
                  //       ),
                  //       TextSpan(
                  //         text: 'Budget',
                  //         style: TextStyle(
                  //           fontSize: 36,
                  //           fontWeight: FontWeight.bold,
                  //           color: Color(0xFF52C77A), // Green
                  //         ),
                  //       ),
                  //     ],
                  //   ),
                  // ),
                ],
              ),
              SizedBox(height: MediaQuery.of(context).size.height * 0.15),
              // Buttons
              Column(
                children: [
                  // Login with FaceID Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // TODO: Implement FaceID login
                      },
                      icon: const Icon(Icons.face),
                      label: const Text('Login With FaceID'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFA7E399), // Green
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Login with Email/Phone Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoginScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.email),
                      label: const Text('Login With Email\nPhone Number'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF39C12), // Orange
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Sign Up Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Didn't have an account? ",
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF7F8C8D),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const FirstRegisterPage(),
                            ),
                          );
                        },
                        child: const Text(
                          'Sign Up',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF52C77A), // Green
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // Terms and Privacy
              Padding(
                padding: const EdgeInsets.only(bottom: 20.0),
                child: Column(
                  children: [
                    const Text(
                      'By continue you agree to our',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Color(0xFF95A5A6)),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: () {
                            // TODO: Navigate to Terms
                          },
                          child: const Text(
                            'Terms',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF52C77A),
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                        const Text(
                          ' & ',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF95A5A6),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            // TODO: Navigate to Privacy Policy
                          },
                          child: const Text(
                            'Privacy Policy',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF52C77A),
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
