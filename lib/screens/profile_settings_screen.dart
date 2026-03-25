import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';

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

  bool _isEditingNickname = false;
  bool _isEditingPhone = false;
  bool _isEditingEmail = false;
  bool _isEditingBirthday = false;
  bool _isSaving = false;
  bool _isUploadingImage = false;

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

      return response;
    } catch (e) {
      print('Error fetching user data: $e');
      return {};
    }
  }

  Future<void> _saveUserData() async {
    setState(() => _isSaving = true);
    try {
      final birthday = _birthdayController.text.isEmpty
          ? null
          : _birthdayController.text;

      await Supabase.instance.client
          .from('User')
          .update({
            'nickname': _nicknameController.text,
            'phoneNumber': _phoneController.text,
            'email': _emailController.text,
            'birthday': birthday,
            'updatedAt': DateTime.now().toString(),
          })
          .eq('userId', widget.userId);

      // Clear edit states
      setState(() {
        _isEditingNickname = false;
        _isEditingPhone = false;
        _isEditingEmail = false;
        _isEditingBirthday = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
    } catch (e) {
      print('Error saving user data: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving profile: $e')));
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
        await _uploadProfileImage();
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

  Future<void> _uploadProfileImage() async {
    if (_selectedImage == null) return;

    setState(() => _isUploadingImage = true);
    try {
      // Step 0: Delete old profile image if exists
      await _deleteOldProfileImage();

      // Use the userId that was passed to this page
      final String fileName =
          '${widget.userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String filePath = 'profile_images/$fileName';

      // Read file bytes
      final fileBytes = await _selectedImage!.readAsBytes();

      // Step 1: Upload new image to Supabase Storage
      await Supabase.instance.client.storage
          .from('images')
          .uploadBinary(
            filePath,
            fileBytes,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );

      // Step 2: Get public URL from storage
      final String publicUrl = Supabase.instance.client.storage
          .from('images')
          .getPublicUrl(filePath);

      // Step 3: Store new image URL in User table
      // This links the image to the user via userId
      await Supabase.instance.client
          .from('User')
          .update({
            'profileImage': publicUrl,
            'updatedAt': DateTime.now().toString(),
          })
          .eq('userId', widget.userId);

      setState(() {
        _profileImageUrl = publicUrl;
        _selectedImage = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile picture updated successfully')),
      );
    } catch (e) {
      print('Error uploading image: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error uploading image: $e')));
    } finally {
      setState(() => _isUploadingImage = false);
    }
  }

  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Image Source'),
          content: const Text('Choose where to get your profile picture from'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
              child: const Text('Take a Photo'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
              child: const Text('Choose from Gallery'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
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
    );

    if (picked != null) {
      setState(() {
        _birthdayController.text =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> handleFaceIdClick(
      BuildContext context,
      String userId,
      ) async {

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
      bool isVerified =
      await showPasswordDialog(context, userId);

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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Something went wrong"),
        ),
      );
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

                                    const Icon(Icons.error, color: Colors.red),

                                    const SizedBox(height: 10),

                                    const Text(
                                      "Too many attempts",
                                      style: TextStyle(fontWeight: FontWeight.bold),
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
                                        backgroundColor: const Color(0xFFC8E6C9),
                                      ),
                                      child: const Text(
                                        "OK",
                                        style: TextStyle(color: Colors.black),
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
    ) ?? false;
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

                const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 60,
                ),

                const SizedBox(height: 12),

                const Text(
                  "Too many attempts",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
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

            return SingleChildScrollView(
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
                          onTap: () => Navigator.pop(context, true),
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
                          child: _isUploadingImage
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
                            onTap: _isUploadingImage
                                ? null
                                : _showImageSourceDialog,
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
                                color: _isUploadingImage
                                    ? Colors.grey
                                    : Colors.black,
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
                                  color: const Color(0xFFC8E6C9),
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
                                  () =>
                                      _isEditingNickname = !_isEditingNickname,
                                );
                              },
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFC8E6C9),
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
                                  color: const Color(0xFFC8E6C9),
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
                                  color: const Color(0xFFC8E6C9),
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
                                  color: const Color(0xFFC8E6C9),
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
                                  color: const Color(0xFFC8E6C9),
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
                                  color: const Color(0xFFC8E6C9),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: _isEditingBirthday
                                    ? GestureDetector(
                                        onTap: _selectBirthday,
                                        child: Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: const Color(0xFF9B7BB7),
                                              width: 2,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
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
                                    color: const Color(0xFFC8E6C9),
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
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFC8E6C9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Account',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
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
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFC8E6C9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Change Password',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            color: Colors.black,
                            size: 24,
                          ),
                        ],
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
            );
          },
        ),
      ),
    );
  }
}
