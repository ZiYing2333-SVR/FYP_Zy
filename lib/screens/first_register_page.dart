import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'second_register_page.dart';
import 'login_screen.dart';

class FirstRegisterPage extends StatefulWidget {
  const FirstRegisterPage({super.key});

  @override
  State<FirstRegisterPage> createState() => _FirstRegisterPageState();
}

class _FirstRegisterPageState extends State<FirstRegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  String _errorMessage = '';

  // Validation methods
  bool _isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }

  bool _isValidPhoneNumber(String phone) {
    // Remove any spaces or hyphens
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    // Check if it's between 10-15 digits
    return cleanPhone.length >= 10 && cleanPhone.length <= 15;
  }

  String? _validateInput(String value) {
    if (value.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your email or phone number';
      });
      return '';
    }

    // Check if it's an email
    if (value.contains('@')) {
      if (_isValidEmail(value)) {
        setState(() {
          _errorMessage = '';
        });
        return null;
      } else {
        setState(() {
          _errorMessage =
              'Invalid email format. Use: example@domain.com';
        });
        return '';
      }
    }
    // Check if it's a phone number
    else {
      if (_isValidPhoneNumber(value)) {
        setState(() {
          _errorMessage = '';
        });
        return null;
      } else {
        setState(() {
          _errorMessage =
              'Invalid phone format. Use: 10-15 digits (e.g., 0123456789)';
        });
        return '';
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<bool> _checkIfUserExists(String input) async {
    try {
      final supabase = Supabase.instance.client;
      
      if (input.contains('@')) {
        // Check if email exists
        print('Checking email: $input');
        final response = await supabase
            .from('User')
            .select()
            .eq('email', input)
            .maybeSingle();
        
        print('Email check response: $response');
        if (response != null) {
          return true;
        }
      } else {
        // Check if phone exists
        print('Checking phone: $input');
        final response = await supabase
            .from('User')
            .select()
            .eq('phoneNumber', input)
            .maybeSingle();
        
        print('Phone check response: $response');
        if (response != null) {
          return true;
        }
      }
      return false;
    } catch (e) {
      print('Error checking user: $e');
      return false;
    }
  }

  void _showExistsDialog(String input) {
    final isEmail = input.contains('@');
    final fieldType = isEmail ? 'Email' : 'Phone number';
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Account Already Exists'),
          content: Text(
            '$fieldType already exists in our system. Please login to your account.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LoginScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFA7E399),
              ),
              child: const Text('Go to Login'),
            ),
          ],
        );
      },
    );
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
              // Back button and logo area
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
              // PawBudget Text
              RichText(
                text: const TextSpan(
                  children: [
                    TextSpan(
                      text: 'Paw',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFF39C12), // Orange
                      ),
                    ),
                    TextSpan(
                      text: 'Budget',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF52C77A), // Green
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              // Register Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF9E6),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFFFE5B4),
                    width: 2,
                  ),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Register Title
                      Center(
                        child: const Text(
                          'Register',
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
                        controller: _emailController,
                        onChanged: (value) {
                          _validateInput(value);
                        },
                        decoration: InputDecoration(
                          hintText: 'Email/Phone Number',
                          hintStyle: const TextStyle(
                            color: Color(0xFFC8A5D8),
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
                          if (value?.isEmpty ?? true) {
                            return 'required';
                          }
                          return _validateInput(value!);
                        },
                      ),
                      // Error Message Display
                      if (_errorMessage.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12.0),
                          child: Text(
                            _errorMessage,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFE74C3C), // Red color
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),
                      // Next Button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () async {
                            final input = _emailController.text;
                            if (input.isEmpty) {
                              setState(() {
                                _errorMessage =
                                    'Please enter your email or phone number';
                              });
                              return;
                            }

                            // Validate email or phone
                            if (input.contains('@')) {
                              if (!_isValidEmail(input)) {
                                setState(() {
                                  _errorMessage =
                                      'Invalid email format. Use: example@domain.com';
                                });
                                return;
                              }
                            } else {
                              if (!_isValidPhoneNumber(input)) {
                                setState(() {
                                  _errorMessage =
                                      'Invalid phone format. Use: 10-15 digits (e.g., 0123456789)';
                                });
                                return;
                              }
                            }

                            // Check if user already exists in Supabase
                            bool userExists = await _checkIfUserExists(input);
                            if (userExists) {
                              _showExistsDialog(input);
                              return;
                            }

                            // If valid and doesn't exist, navigate to next page
                            setState(() {
                              _errorMessage = '';
                            });
                            if (mounted) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      SecondRegisterPage(email: input),
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFA7E399), // Green
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          child: const Text('Next'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: MediaQuery.of(context).size.height * 0.1),
            ],
          ),
        ),
      ),
    );
  }
}
