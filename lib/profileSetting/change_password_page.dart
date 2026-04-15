import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'profile_settings_screen.dart';

class ChangePasswordPage extends StatefulWidget {
  final String userId;
  final String oldPassword;

  const ChangePasswordPage({
    super.key,
    required this.userId,
    required this.oldPassword,
  });

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  String _errorMessage = '';
  bool _isLoading = false;
  String _maskedContact = '';
  late Future<Map<String, dynamic>> _userDataFuture;

  @override
  void initState() {
    super.initState();
    _userDataFuture = _fetchUserData();
  }

  Future<Map<String, dynamic>> _fetchUserData() async {
    try {
      final response = await Supabase.instance.client
          .from('User')
          .select()
          .eq('userId', widget.userId)
          .single();

      // Get phone number and email
      final phoneNumber = response['phoneNumber'] as String? ?? '';
      final email = response['email'] as String? ?? '';

      // Display phone if available, otherwise email
      if (phoneNumber.isNotEmpty) {
        _maskedContact = _maskPhoneNumber(phoneNumber);
      } else if (email.isNotEmpty) {
        _maskedContact = _maskEmail(email);
      }

      return response;
    } catch (e) {
      print('Error fetching user data: $e');
      return {};
    }
  }

  String _maskPhoneNumber(String phoneNumber) {
    // Show only last 4 digits: 0123456789 -> ******6789
    if (phoneNumber.length <= 4) {
      return phoneNumber;
    }
    final lastFour = phoneNumber.substring(phoneNumber.length - 4);
    final maskedPart = '*' * (phoneNumber.length - 4);
    return '$maskedPart$lastFour';
  }

  String _maskEmail(String email) {
    // Show last 3 characters before @: iuawd12@gmail.com -> ****d12@gmail.com
    if (!email.contains('@')) {
      return email;
    }

    final parts = email.split('@');
    final localPart = parts[0];
    final domain = parts[1];

    if (localPart.length <= 3) {
      return '$localPart@$domain';
    }

    final lastThree = localPart.substring(localPart.length - 3);
    final maskedPart = '*' * (localPart.length - 3);
    return '$maskedPart$lastThree@$domain';
  }

  Future<void> _updatePassword(String newPassword) async {
    try {
      final supabase = Supabase.instance.client;

      // Update the password in the User table
      await supabase
          .from('User')
          .update({'password': newPassword})
          .eq('userId', widget.userId);

      print('Password updated successfully for user: ${widget.userId}');
    } catch (e) {
      print('Error updating password: $e');
      throw Exception('Error updating password: $e');
    }
  }

  void _showCancelConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: const Color(0xFFFFF9E6),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF9E6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFFFE5B4), width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title
              const Text(
                'Cancel Change Password?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFF39C12),
                ),
              ),
              const SizedBox(height: 12),
              // Description
              const Text(
                'Are you sure you want to cancel the change password action?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF666666),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              // No Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFA7E399),
                    foregroundColor: Colors.black87,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'No',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Yes Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                    side: BorderSide(color: Colors.grey[300]!, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Yes',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).then((result) {
      if (result == true) {
        Navigator.pop(context);
      }
    });
  }

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEFFD3), // Light yellow background
      body: FutureBuilder<Map<String, dynamic>>(
        future: _userDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  // Back button
                  SizedBox(height: MediaQuery.of(context).size.height * 0.04),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _showCancelConfirmationDialog,
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
                  // Change Password Card
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
                          // Change Password Title
                          Center(
                            child: const Text(
                              'Change Password',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFF39C12), // Orange
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Masked Contact Field (Disabled)
                          TextFormField(
                            initialValue: _maskedContact,
                            enabled: false,
                            decoration: InputDecoration(
                              hintText: 'Registered Contact',
                              hintStyle: const TextStyle(
                                color: Color(0xFFBCBCBC),
                                fontSize: 14,
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF5F5F5),
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
                              disabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE8D5F2),
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF666666),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // New Password Field
                          TextFormField(
                            controller: _newPasswordController,
                            obscureText: _obscureNewPassword,
                            decoration: InputDecoration(
                              hintText: 'New Password',
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
                              suffixIcon: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _obscureNewPassword = !_obscureNewPassword;
                                  });
                                },
                                child: Icon(
                                  _obscureNewPassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: const Color(0xFFBCBCBC),
                                ),
                              ),
                            ),
                            validator: (value) {
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          // Confirm New Password Field
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirmPassword,
                            decoration: InputDecoration(
                              hintText: 'Confirm New Password',
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
                              suffixIcon: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _obscureConfirmPassword =
                                        !_obscureConfirmPassword;
                                  });
                                },
                                child: Icon(
                                  _obscureConfirmPassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: const Color(0xFFBCBCBC),
                                ),
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
                              child: Text(
                                _errorMessage,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFFE74C3C), // Red color
                                  fontWeight: FontWeight.w500,
                                ),
                                softWrap: true,
                                maxLines: null,
                              ),
                            ),
                          const SizedBox(height: 24),
                          // Change Password Button
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _isLoading
                                  ? null
                                  : () async {
                                      final newPassword =
                                          _newPasswordController.text;
                                      final confirmPassword =
                                          _confirmPasswordController.text;
                                      final oldPassword = widget.oldPassword;

                                      // Priority-based validation checking
                                      // 1. Check if new password is empty
                                      if (newPassword.isEmpty) {
                                        setState(() {
                                          _errorMessage =
                                              'Please enter a new password';
                                        });
                                        return;
                                      }

                                      // 2. Check if new password is at least 6 characters
                                      if (newPassword.length < 6) {
                                        setState(() {
                                          _errorMessage =
                                              'Password must be at least 6 characters';
                                        });
                                        return;
                                      }

                                      // 3. Check if confirm password is empty
                                      if (confirmPassword.isEmpty) {
                                        setState(() {
                                          _errorMessage =
                                              'Please confirm your new password';
                                        });
                                        return;
                                      }

                                      // 4. Check if confirm password is at least 6 characters
                                      if (confirmPassword.length < 6) {
                                        setState(() {
                                          _errorMessage =
                                              'Password must be at least 6 characters';
                                        });
                                        return;
                                      }

                                      // 5. Check if passwords match
                                      if (newPassword != confirmPassword) {
                                        setState(() {
                                          _errorMessage =
                                              'Passwords do not match';
                                        });
                                        return;
                                      }

                                      // 6. Check if new password is same as old password
                                      if (newPassword == oldPassword) {
                                        setState(() {
                                          _errorMessage =
                                              'New password cannot be the same as the old one';
                                        });
                                        return;
                                      }

                                      setState(() {
                                        _isLoading = true;
                                        _errorMessage = '';
                                      });

                                      try {
                                        await _updatePassword(newPassword);

                                        if (mounted) {
                                          // Show success dialog with theme colors
                                          showDialog(
                                            context: context,
                                            barrierDismissible: false,
                                            builder: (BuildContext context) {
                                              return Dialog(
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                backgroundColor: const Color(
                                                  0xFFFFF9E6,
                                                ),
                                                child: Container(
                                                  padding: const EdgeInsets.all(
                                                    24,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                      0xFFFFF9E6,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          20,
                                                        ),
                                                    border: Border.all(
                                                      color: const Color(
                                                        0xFFFFE5B4,
                                                      ),
                                                      width: 2,
                                                    ),
                                                  ),
                                                  child: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      // Success icon
                                                      Container(
                                                        width: 60,
                                                        height: 60,
                                                        decoration:
                                                            BoxDecoration(
                                                              shape: BoxShape
                                                                  .circle,
                                                              color:
                                                                  const Color(
                                                                    0xFFA7E399,
                                                                  ),
                                                            ),
                                                        child: const Icon(
                                                          Icons.check,
                                                          color: Colors.white,
                                                          size: 32,
                                                        ),
                                                      ),
                                                      const SizedBox(
                                                        height: 20,
                                                      ),
                                                      // Success title
                                                      const Text(
                                                        'Password Changed Successfully!',
                                                        textAlign:
                                                            TextAlign.center,
                                                        style: TextStyle(
                                                          fontSize: 20,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: Color(
                                                            0xFFF39C12,
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(
                                                        height: 12,
                                                      ),
                                                      // Success message
                                                      const Text(
                                                        'Your password has been changed successfully.',
                                                        textAlign:
                                                            TextAlign.center,
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          color: Color(
                                                            0xFF666666,
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(
                                                        height: 24,
                                                      ),
                                                      // OK button
                                                      SizedBox(
                                                        width: double.infinity,
                                                        height: 48,
                                                        child: ElevatedButton(
                                                          onPressed: () {
                                                            Navigator.pop(
                                                              context,
                                                            ); // Close dialog
                                                            Navigator.pushAndRemoveUntil(
                                                              context,
                                                              MaterialPageRoute(
                                                                builder: (context) =>
                                                                    ProfileSettingsScreen(
                                                                      userId: widget
                                                                          .userId,
                                                                    ),
                                                              ),
                                                              (route) => false,
                                                            );
                                                          },
                                                          style: ElevatedButton.styleFrom(
                                                            backgroundColor:
                                                                const Color(
                                                                  0xFFA7E399,
                                                                ),
                                                            foregroundColor:
                                                                Colors.white,
                                                            shape: RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    10,
                                                                  ),
                                                            ),
                                                            textStyle:
                                                                const TextStyle(
                                                                  fontSize: 16,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                ),
                                                          ),
                                                          child: const Text(
                                                            'OK',
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            },
                                          );
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
                                backgroundColor: const Color(0xFFA7E399),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: const Color(
                                  0xFFCCCCCC,
                                ),
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
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                  : const Text('Change Password'),
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
          );
        },
      ),
    );
  }
}
