import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'change_password_page.dart';
import 'settings_screen.dart';

import '../FacialRecognition/set_up_face_page.dart';

class ProfileSettingsScreen extends StatefulWidget {
  final String userId;

  const ProfileSettingsScreen({Key? key, required this.userId})
    : super(key: key);

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  late Future<Map<String, dynamic>> _userDataFuture;

  // Text controllers for editing
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _birthdayController = TextEditingController();

  // Store initial values to track changes
  String _initialNickname = '';
  String _initialPhone = '';
  String _initialEmail = '';
  String _initialBirthday = '';
  String? _initialProfileImageUrl;

  bool _isEditingNickname = false;
  bool _isEditingPhone = false;
  bool _isEditingEmail = false;
  bool _isEditingBirthday = false;
  bool _isSaving = false;
  String _oldPassword = '';

  XFile? _selectedImage;
  String? _profileImageUrl;

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

      // Initialize text controllers with fetched data
      _nicknameController.text = response['nickname'] ?? 'nickname';
      _phoneController.text = response['phoneNumber'] ?? '';
      _emailController.text = response['email'] ?? '';
      _birthdayController.text = response['birthday'] ?? '';
      _profileImageUrl = response['profileImage'];
      _oldPassword = response['password'] ?? '';

      // Store initial values for change detection
      _initialNickname = _nicknameController.text;
      _initialPhone = _phoneController.text;
      _initialEmail = _emailController.text;
      _initialBirthday = _birthdayController.text;
      _initialProfileImageUrl = _profileImageUrl;

      return response;
    } catch (e) {
      print('Error fetching user data: $e');
      return {};
    }
  }

  bool _hasUnsavedChanges() {
    return _nicknameController.text != _initialNickname ||
        _phoneController.text != _initialPhone ||
        _emailController.text != _initialEmail ||
        _birthdayController.text != _initialBirthday ||
        _selectedImage != null ||
        _profileImageUrl != _initialProfileImageUrl;
  }

  void _showDiscardChangesDialog() {
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
                'Discard Changes?',
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
                'You have unsaved changes. Are you sure you want to discard them?',
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
                    'Keep Editing',
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
                    'Discard Changes',
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
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => SettingsScreen(userId: widget.userId),
          ),
          (route) => false,
        );
      }
    });
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
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
              // Success icon
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFA7E399),
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 32),
              ),
              const SizedBox(height: 20),
              // Success title
              const Text(
                'Profile Updated Successfully!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFF39C12),
                ),
              ),
              const SizedBox(height: 12),
              // Success message
              const Text(
                'Your profile has been updated successfully.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Color(0xFF666666)),
              ),
              const SizedBox(height: 24),
              // OK button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            SettingsScreen(userId: widget.userId),
                      ),
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFA7E399),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Text('OK'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveUserData() async {
    setState(() => _isSaving = true);
    try {
      // Validate email if it's not empty
      final emailValue = _emailController.text.trim();
      if (emailValue.isNotEmpty && !emailValue.contains('@')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a valid email address'),
            backgroundColor: Color(0xFFE74C3C),
          ),
        );
        setState(() => _isSaving = false);
        return;
      }

      String? newImageUrl = _profileImageUrl;

      // Step 1: Upload image to Supabase if a new image was selected
      if (_selectedImage != null) {
        // Delete old image if it exists
        await _deleteOldProfileImage();

        // Upload new image
        final String fileName =
            '${widget.userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final String filePath = 'profile_images/$fileName';
        final fileBytes = await _selectedImage!.readAsBytes();

        await Supabase.instance.client.storage
            .from('images')
            .uploadBinary(
              filePath,
              fileBytes,
              fileOptions: const FileOptions(
                cacheControl: '3600',
                upsert: true,
              ),
            );

        newImageUrl = Supabase.instance.client.storage
            .from('images')
            .getPublicUrl(filePath);
      }

      // Step 2: Update all user data in Supabase
      final birthday = _birthdayController.text.isEmpty
          ? null
          : _birthdayController.text;

      final updateData = {
        'nickname': _nicknameController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        'email': emailValue.isEmpty ? null : emailValue,
        'birthday': birthday,
        'updatedAt': DateTime.now().toString(),
      };

      // Add image URL if it was updated
      if (_selectedImage != null) {
        updateData['profileImage'] = newImageUrl;
      }

      await Supabase.instance.client
          .from('User')
          .update(updateData)
          .eq('userId', widget.userId);

      // Update initial values after successful save
      _initialNickname = _nicknameController.text;
      _initialPhone = _phoneController.text;
      _initialEmail = _emailController.text;
      _initialBirthday = _birthdayController.text;
      _initialProfileImageUrl = newImageUrl;
      _profileImageUrl = newImageUrl;
      _selectedImage = null;

      // Clear edit states
      setState(() {
        _isEditingNickname = false;
        _isEditingPhone = false;
        _isEditingEmail = false;
        _isEditingBirthday = false;
      });

      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      print('Error saving user data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error saving profile: $e',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            backgroundColor: const Color(0xFFE74C3C),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: source);

      if (image != null) {
        setState(() {
          _selectedImage = image;
        });
        // Image is only saved to UI, will be uploaded to Supabase when user clicks Save
      }
    } catch (e) {
      print('Error picking image: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
    }
  }

  Future<void> _deleteOldProfileImage() async {
    if (_profileImageUrl == null || _profileImageUrl!.isEmpty) {
      print('No old profile image to delete');
      return;
    }

    try {
      print('Starting deletion of old profile image: $_profileImageUrl');

      // Extract file path from URL
      // URL format: https://xxxx.supabase.co/storage/v1/object/public/images/profile_images/userId_timestamp.jpg
      // We need to extract: profile_images/userId_timestamp.jpg

      // Simple approach: split by '/images/' and get the part after it
      if (!_profileImageUrl!.contains('/images/')) {
        print('URL does not contain /images/');
        return;
      }

      final filePath = _profileImageUrl!.split('/images/').last;
      print('Extracted file path: $filePath');

      if (filePath.isEmpty) {
        print('File path is empty');
        return;
      }

      print('Attempting to delete file from bucket: $filePath');

      // Delete old image from Supabase Storage
      // The filePath should be: profile_images/userId_timestamp.jpg
      final response = await Supabase.instance.client.storage
          .from('images')
          .remove([filePath]);

      print('Delete response: $response');
      print('Old profile image deleted successfully: $filePath');
    } catch (e) {
      print('Error deleting old profile image: $e');
      print('Stack trace: ${e.toString()}');
      // Don't throw error, just continue with upload
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: const Color(0xFFFFF9E6),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 20),
                child: Text(
                  'Select Image Source',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Color(0xFFA7E399)),
                title: const Text('Take a Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.image, color: Color(0xFFA7E399)),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.close, color: Colors.grey),
                title: const Text('Cancel'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _selectBirthday() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _birthdayController.text.isNotEmpty
          ? DateTime.parse(_birthdayController.text)
          : DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFA7E399),
              onPrimary: Colors.black,
              secondary: Color(0xFFFFE5B4),
              surface: Color(0xFFFFF9E6),
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _birthdayController.text =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> handleFaceIdClick(BuildContext context, String userId) async {
    final supabase = Supabase.instance.client;

    try {
      /// ==============================
      /// 1️⃣ Check if Face ID exists
      /// ==============================
      final record = await supabase
          .from('FaceAuth')
          .select()
          .eq('userId', userId)
          .maybeSingle();

      bool hasFaceId = record != null;

      /// ==============================
      /// 2️⃣ Ask for password
      /// ==============================
      bool isVerified = await showPasswordDialog(context, userId);

      if (!isVerified) return;

      /// ==============================
      /// 3️⃣ Navigate
      /// ==============================
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SetUpFacePage(
            isUpdate: hasFaceId, // ✅ TRUE = change, FALSE = setup
            userId: userId,
          ),
        ),
      );
    } catch (e) {
      debugPrint("FaceID Click Error: $e");

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Something went wrong")));
    }
  }

  Future<bool> showPasswordDialog(
    BuildContext parentContext,
    String userId,
  ) async {
    int attempts = 0;
    final controller = TextEditingController();
    final supabase = Supabase.instance.client;

    return await showDialog<bool>(
          context: parentContext,
          barrierDismissible: false,
          builder: (dialogContext) {
            int attempts = 0; // stays inside dialog

            return StatefulBuilder(
              builder: (context, setState) {
                return AlertDialog(
                  backgroundColor: const Color(0xFFFFF9E6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),

                  title: const Text(
                    "Enter Password",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),

                  content: TextField(
                    controller: controller,
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: "Password",
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  actions: [
                    /// CANCEL
                    TextButton(
                      onPressed: () {
                        Navigator.pop(dialogContext, false);
                      },
                      child: const Text("Cancel"),
                    ),

                    /// CONFIRM
                    ElevatedButton(
                      onPressed: () async {
                        String password = controller.text;

                        final res = await supabase
                            .from('User')
                            .select()
                            .eq('userId', userId)
                            .eq('password', password)
                            .limit(1)
                            .maybeSingle();

                        if (res != null) {
                          Navigator.pop(dialogContext, true);
                        } else {
                          attempts++;

                          if (attempts >= 3) {
                            Navigator.pop(dialogContext, false);

                            /// 🔥 SAFE WAY (NO CRASH)
                            if (parentContext.mounted) {
                              showDialog(
                                context: parentContext,
                                builder: (_) => Dialog(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF9E6),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.error,
                                          color: Colors.red,
                                        ),

                                        const SizedBox(height: 10),

                                        const Text(
                                          "Too many attempts",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),

                                        const SizedBox(height: 10),

                                        const Text(
                                          "Please change your password.",
                                          textAlign: TextAlign.center,
                                        ),

                                        const SizedBox(height: 20),

                                        ElevatedButton(
                                          onPressed: () {
                                            Navigator.pop(parentContext);
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(
                                              0xFFC8E6C9,
                                            ),
                                          ),
                                          child: const Text(
                                            "OK",
                                            style: TextStyle(
                                              color: Colors.black,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }
                          } else {
                            ScaffoldMessenger.of(parentContext).showSnackBar(
                              SnackBar(
                                content: Text(
                                  "Wrong password (${attempts}/3)",
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC8E6C9),
                      ),
                      child: const Text(
                        "Confirm",
                        style: TextStyle(color: Colors.black),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ) ??
        false;
  }

  void showErrorDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF9E6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 60),

                const SizedBox(height: 12),

                const Text(
                  "Too many attempts",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 8),

                const Text(
                  "Please change your password.",
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC8E6C9), // 🟢 green
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: const Text(
                      "OK",
                      style: TextStyle(color: Colors.black),
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

  @override
  void dispose() {
    _nicknameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _birthdayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF9E6),
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _userDataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            return GestureDetector(
              onTapDown: (_) {
                // Reset all editing states when tapped outside
                setState(() {
                  _isEditingNickname = false;
                  _isEditingPhone = false;
                  _isEditingEmail = false;
                  _isEditingBirthday = false;
                });
              },
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with back button
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: () {
                              if (_hasUnsavedChanges()) {
                                _showDiscardChangesDialog();
                              } else {
                                Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        SettingsScreen(userId: widget.userId),
                                  ),
                                  (route) => false,
                                );
                              }
                            },
                            child: const Text(
                              '✕',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          const Text(
                            'Profile Setting',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(width: 28),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Avatar Section
                    Center(
                      child: Stack(
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE85B8A),
                              shape: BoxShape.circle,
                            ),
                            child: _isSaving
                                ? const Center(
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                    ),
                                  )
                                : _selectedImage != null
                                ? FutureBuilder<List<int>>(
                                    future: _selectedImage!.readAsBytes(),
                                    builder: (context, snapshot) {
                                      if (snapshot.hasData) {
                                        return ClipOval(
                                          child: Image.memory(
                                            Uint8List.fromList(snapshot.data!),
                                            fit: BoxFit.cover,
                                          ),
                                        );
                                      }
                                      return Center(
                                        child: Icon(
                                          Icons.person,
                                          size: 60,
                                          color: Colors.white,
                                        ),
                                      );
                                    },
                                  )
                                : _profileImageUrl != null &&
                                      _profileImageUrl!.isNotEmpty
                                ? ClipOval(
                                    child: Image.network(
                                      _profileImageUrl!,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : Center(
                                    child: Icon(
                                      Icons.person,
                                      size: 60,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: _isSaving ? null : _showImageSourceDialog,
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.grey,
                                    width: 1,
                                  ),
                                ),
                                child: Icon(
                                  Icons.edit,
                                  size: 18,
                                  color: _isSaving ? Colors.grey : Colors.black,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Nickname Field
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Nickname:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: _isEditingNickname
                                        ? const Color(0x99C8E6C9)
                                        : const Color.fromARGB(
                                            255,
                                            250,
                                            220,
                                            143,
                                          ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: _isEditingNickname
                                      ? TextField(
                                          controller: _nicknameController,
                                          decoration: const InputDecoration(
                                            border: InputBorder.none,
                                            isDense: true,
                                          ),
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black,
                                          ),
                                        )
                                      : Text(
                                          _nicknameController.text,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              GestureDetector(
                                onTap: () {
                                  setState(
                                    () => _isEditingNickname =
                                        !_isEditingNickname,
                                  );
                                },
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: _isEditingNickname
                                        ? const Color(0x99C8E6C9)
                                        : const Color.fromARGB(
                                            255,
                                            250,
                                            220,
                                            143,
                                          ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.edit,
                                    size: 20,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Phone Number Field
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Phone Number:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: _isEditingPhone
                                        ? const Color(0x99C8E6C9)
                                        : const Color.fromARGB(
                                            255,
                                            250,
                                            220,
                                            143,
                                          ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: _isEditingPhone
                                      ? TextField(
                                          controller: _phoneController,
                                          decoration: const InputDecoration(
                                            border: InputBorder.none,
                                            isDense: true,
                                            hintText: 'Phone Number',
                                          ),
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black,
                                          ),
                                        )
                                      : Text(
                                          _phoneController.text.isNotEmpty
                                              ? _phoneController.text
                                              : 'Phone Number',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              GestureDetector(
                                onTap: () {
                                  setState(
                                    () => _isEditingPhone = !_isEditingPhone,
                                  );
                                },
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: _isEditingPhone
                                        ? const Color(0x99C8E6C9)
                                        : const Color.fromARGB(
                                            255,
                                            250,
                                            220,
                                            143,
                                          ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.edit,
                                    size: 20,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Email Field
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Email:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: _isEditingEmail
                                        ? const Color(0x99C8E6C9)
                                        : const Color.fromARGB(
                                            255,
                                            250,
                                            220,
                                            143,
                                          ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: _isEditingEmail
                                      ? TextField(
                                          controller: _emailController,
                                          decoration: const InputDecoration(
                                            border: InputBorder.none,
                                            isDense: true,
                                            hintText: 'Email',
                                          ),
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black,
                                          ),
                                        )
                                      : Text(
                                          _emailController.text.isNotEmpty
                                              ? _emailController.text
                                              : 'Email',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              GestureDetector(
                                onTap: () {
                                  setState(
                                    () => _isEditingEmail = !_isEditingEmail,
                                  );
                                },
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: _isEditingEmail
                                        ? const Color(0x99C8E6C9)
                                        : const Color.fromARGB(
                                            255,
                                            250,
                                            220,
                                            143,
                                          ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.edit,
                                    size: 20,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Birthday Field
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Birthday:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: _isEditingBirthday
                                        ? const Color(0x99C8E6C9)
                                        : const Color.fromARGB(
                                            255,
                                            250,
                                            220,
                                            143,
                                          ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: _isEditingBirthday
                                      ? GestureDetector(
                                          onTap: _selectBirthday,
                                          child: Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: const Color(0xFF9B7BB7),
                                                width: 2,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                  _birthdayController
                                                          .text
                                                          .isNotEmpty
                                                      ? _birthdayController.text
                                                      : 'Tap to select date',
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.black,
                                                  ),
                                                ),
                                                const Icon(
                                                  Icons.calendar_today,
                                                  color: Color(0xFF9B7BB7),
                                                ),
                                              ],
                                            ),
                                          ),
                                        )
                                      : Text(
                                          _birthdayController.text.isNotEmpty
                                              ? _birthdayController.text
                                              : 'Unknown',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              if (!_isEditingBirthday)
                                GestureDetector(
                                  onTap: () {
                                    setState(
                                      () => _isEditingBirthday =
                                          !_isEditingBirthday,
                                    );
                                  },
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: const Color.fromARGB(
                                        255,
                                        250,
                                        220,
                                        143,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.edit,
                                      size: 20,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Account Section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: const Text(
                        'Privacy Setting',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Face ID
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: GestureDetector(
                        onTap: () async {
                          print("Tapped");
                          await handleFaceIdClick(context, widget.userId);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFC8E6C9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              Text(
                                'Face ID',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                color: Colors.black,
                                size: 24,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Change Password
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChangePasswordPage(
                                userId: widget.userId,
                                oldPassword: _oldPassword,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFC8E6C9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              Text(
                                'Change Password',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                color: Colors.black,
                                size: 24,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Save Button
                    Center(
                      child: GestureDetector(
                        onTap: _isSaving ? null : _saveUserData,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 40,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD966),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Save',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
