import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'forgot_password_page2.dart';
import 'first_register_page.dart';

class ForgotPasswordPage1 extends StatefulWidget {
  const ForgotPasswordPage1({super.key});

  @override
  State<ForgotPasswordPage1> createState() => _ForgotPasswordPage1State();
}

class _ForgotPasswordPage1State extends State<ForgotPasswordPage1> {
  final _emailPhoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _errorMessage = '';
  bool _isLoading = false;

  bool _isValidEmail(String input) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(input);
  }

  bool _isValidPhoneNumber(String input) {
    // Phone number should contain only digits and be at least 10 characters
    final phoneRegex = RegExp(r'^[0-9]{10,}$');
    return phoneRegex.hasMatch(input);
  }

  bool _isValidInput(String input) {
    return _isValidEmail(input) || _isValidPhoneNumber(input);
  }

  Future<Map<String, dynamic>?> _verifyEmailOrPhone(String input) async {
    try {
      final supabase = Supabase.instance.client;

      // Query the User table to find matching email or phoneNumber
      final response = await supabase
          .from('User')
          .select()
          .or('email.eq.$input,phoneNumber.eq.$input')
          .maybeSingle();

      return response;
    } catch (e) {
      print('Error verifying email/phone: $e');
      throw Exception('Error verifying email/phone: $e');
    }
  }

  @override
  void dispose() {
    _emailPhoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEFFD3), // Light yellow background
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              // Back button
              SizedBox(height: MediaQuery.of(context).size.height * 0.04),
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back, size: 28),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Logo
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Image.asset(
                  'assets/images/pawbudget_Tlogo.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 20),
              // Forgot Password Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF9E6),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFFE5B4), width: 2),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Forgot Password Title
                      Center(
                        child: const Text(
                          'Forgot Password',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFF39C12), // Orange
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Email/Phone Number Field
                      TextFormField(
                        controller: _emailPhoneController,
                        decoration: InputDecoration(
                          hintText: 'Email/Phone Number',
                          hintStyle: const TextStyle(
                            color: Color(0xFFBCBCBC),
                            fontSize: 14,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: Color(0xFFE8D5F2),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: Color(0xFFE8D5F2),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: Color(0xFFBCBCBC),
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        validator: (value) {
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      // Error Message Display
                      if (_errorMessage.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _errorMessage,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFFE74C3C), // Red color
                                  fontWeight: FontWeight.w500,
                                ),
                                softWrap: true,
                                maxLines: null,
                              ),
                              // Show "Go to Register Page" only when user is not found
                              if (_errorMessage ==
                                  'The phone number or email has not been registered yet.')
                                Column(
                                  children: [
                                    const SizedBox(height: 12),
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const FirstRegisterPage(),
                                          ),
                                        );
                                      },
                                      child: const Text(
                                        'Go to Register Page',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF52C77A), // Green
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 24),
                      // Next Button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isLoading
                              ? null
                              : () async {
                                  // Validate form first
                                  if (!_formKey.currentState!.validate()) {
                                    setState(() {
                                      _errorMessage = '';
                                    });
                                    return;
                                  }

                                  final input = _emailPhoneController.text
                                      .trim();

                                  setState(() {
                                    _isLoading = true;
                                    _errorMessage = '';
                                  });

                                  // Validate input format
                                  if (!_isValidInput(input)) {
                                    setState(() {
                                      _isLoading = false;
                                      _errorMessage =
                                          'Please enter a valid email or phone number (10+ digits)';
                                    });
                                    return;
                                  }

                                  try {
                                    final user = await _verifyEmailOrPhone(
                                      input,
                                    );

                                    if (mounted) {
                                      if (user != null) {
                                        // Navigate to second page with user data
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                ForgotPasswordPage2(
                                                  userId: user['userId'],
                                                  oldPassword: user['password'],
                                                ),
                                          ),
                                        );
                                      } else {
                                        // Show error message
                                        setState(() {
                                          _errorMessage =
                                              'The phone number or email has not been registered yet.';
                                        });
                                      }
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      setState(() {
                                        _errorMessage =
                                            'An error occurred. Please try again.';
                                      });
                                    }
                                  } finally {
                                    if (mounted) {
                                      setState(() {
                                        _isLoading = false;
                                      });
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFA7E399), // Green
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: const Color(0xFFCCCCCC),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Text('Next'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: MediaQuery.of(context).size.height * 0.05),
            ],
          ),
        ),
      ),
    );
  }
}
