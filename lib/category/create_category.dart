import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';

class CreateCategory extends StatefulWidget {
  final String userId;

  const CreateCategory({Key? key, required this.userId}) : super(key: key);

  @override
  State<CreateCategory> createState() => _CreateCategoryState();
}

class _CreateCategoryState extends State<CreateCategory> {
  final _nameController = TextEditingController();

  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  String? _uploadedImageUrl;
  bool _isSaving = false;
  String _selectedType = 'expense';
  String? _nameError;

  final ImagePicker _imagePicker = ImagePicker();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
      );

      if (pickedFile != null) {
        final imageBytes = await pickedFile.readAsBytes();
        setState(() {
          _selectedImageBytes = imageBytes;
          _selectedImageName = pickedFile.name;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error picking image: $e',
            style: const TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          backgroundColor: const Color(0xFFFFEBEE),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<String?> _uploadImageToSupabase() async {
    if (_selectedImageBytes == null) return null;

    try {
      final fileName =
          'customizeIcon_${DateTime.now().millisecondsSinceEpoch}_$_selectedImageName';
      final filePath = 'category_icon/customizeIcon/$fileName';

      await Supabase.instance.client.storage
          .from('images')
          .uploadBinary(
            filePath,
            _selectedImageBytes!,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );

      final publicUrl = Supabase.instance.client.storage
          .from('images')
          .getPublicUrl(filePath);
      return publicUrl;
    } catch (e) {
      print('Error uploading image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error uploading image: $e',
            style: const TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          backgroundColor: const Color(0xFFFFEBEE),
          duration: const Duration(seconds: 3),
        ),
      );
      return null;
    }
  }

  Future<String> _generateCategoryId() async {
    try {
      final response = await Supabase.instance.client
          .from('Category')
          .select('categoryId')
          .ilike('categoryId', 'CAT${widget.userId}%')
          .order('categoryId', ascending: false)
          .limit(1);

      int nextSequence = 1;
      if (response.isNotEmpty) {
        final lastCategoryId = response[0]['categoryId'] as String;
        final sequencePart = lastCategoryId.replaceFirst(
          'CAT${widget.userId}',
          '',
        );
        final currentSequence = int.tryParse(sequencePart) ?? 0;
        nextSequence = currentSequence + 1;
      }

      final sequenceStr = nextSequence.toString().padLeft(4, '0');
      return 'CAT${widget.userId}$sequenceStr';
    } catch (e) {
      print('Error generating categoryId: $e');
      rethrow;
    }
  }

  Future<void> _saveCategory() async {
    // Validation - Check if category name is empty
    if (_nameController.text.trim().isEmpty) {
      setState(() {
        _nameError = 'Please enter a category name';
      });
      return;
    }

    // Clear error if validation passed
    setState(() {
      _nameError = null;
    });

    setState(() => _isSaving = true);

    try {
      // Upload image if selected
      if (_selectedImageBytes != null) {
        _uploadedImageUrl = await _uploadImageToSupabase();
      }

      // Generate categoryId
      final categoryId = await _generateCategoryId();

      // Save category to database
      await Supabase.instance.client.from('Category').insert({
        'categoryId': categoryId,
        'name': _nameController.text.trim(),
        'icon': _uploadedImageUrl,
        'type': _selectedType,
        'userId': widget.userId,
      });

      if (!mounted) return;

      // Show success dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
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
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Success title
                  const Text(
                    'Category Created Successfully!',
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
                    'Your new category has been created successfully.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF666666),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Done button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context); // Close dialog
                        Navigator.pop(
                          context,
                          true,
                        ); // Return to category manager
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFA7E399),
                        foregroundColor: Colors.black87,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Done',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      print('Error saving category: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error saving category: $e',
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            backgroundColor: const Color(0xFFFFEBEE),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF9E6),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFFF9E6),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              padding: const EdgeInsets.only(top: 20, bottom: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close, color: Colors.black),
                    ),
                  ),
                  const Text(
                    'Add Category',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Icon Upload Field
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFFC8E6C9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Icon',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          if (_selectedImageBytes != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(
                                width: 50,
                                height: 50,
                                child: Image.memory(
                                  _selectedImageBytes!,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            )
                          else
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.image,
                                color: Colors.grey,
                                size: 30,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Category Name Field
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 80,
                        decoration: BoxDecoration(
                          color: const Color(0xFFC8E6C9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Category Name',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            Expanded(
                              child: TextField(
                                controller: _nameController,
                                textAlign: TextAlign.right,
                                onChanged: (value) {
                                  if (_nameError != null) {
                                    setState(() {
                                      _nameError = null;
                                    });
                                  }
                                },
                                decoration: const InputDecoration(
                                  hintText: 'Enter name',
                                  border: InputBorder.none,
                                  hintStyle: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey,
                                  ),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                ),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_nameError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _nameError!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Type Field (Currency style)
                  GestureDetector(
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: const Color(0xFFFFF9E6),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(20),
                            topRight: Radius.circular(20),
                          ),
                        ),
                        builder: (context) => Container(
                          padding: const EdgeInsets.all(24),
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFF9E6),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(20),
                              topRight: Radius.circular(20),
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Select Type',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 20),
                              // Expense Option
                              GestureDetector(
                                onTap: () {
                                  setState(() => _selectedType = 'expense');
                                  Navigator.pop(context);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFC8E6C9),
                                    borderRadius: BorderRadius.circular(12),
                                    border: _selectedType == 'expense'
                                        ? Border.all(
                                            color: const Color(0xFFA7E399),
                                            width: 2,
                                          )
                                        : null,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Expense',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black,
                                        ),
                                      ),
                                      if (_selectedType == 'expense')
                                        const Icon(
                                          Icons.check_circle,
                                          color: Color(0xFFA7E399),
                                          size: 24,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Income Option
                              GestureDetector(
                                onTap: () {
                                  setState(() => _selectedType = 'income');
                                  Navigator.pop(context);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFC8E6C9),
                                    borderRadius: BorderRadius.circular(12),
                                    border: _selectedType == 'income'
                                        ? Border.all(
                                            color: const Color(0xFFA7E399),
                                            width: 2,
                                          )
                                        : null,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Income',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black,
                                        ),
                                      ),
                                      if (_selectedType == 'income')
                                        const Icon(
                                          Icons.check_circle,
                                          color: Color(0xFFA7E399),
                                          size: 24,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      );
                    },
                    child: Container(
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFFC8E6C9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Type',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                _selectedType == 'expense'
                                    ? 'Expense'
                                    : 'Income',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.chevron_right,
                                color: Colors.black,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Save Button
                  ElevatedButton(
                    onPressed: _isSaving ? null : _saveCategory,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD700),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      disabledBackgroundColor: Colors.grey,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.black),
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
