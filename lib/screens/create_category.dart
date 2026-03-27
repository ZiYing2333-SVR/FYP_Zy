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
  final _typeController = TextEditingController();
  final _subcategories = <TextEditingController>[];

  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  String? _uploadedImageUrl;
  bool _isSaving = false;
  String _selectedType = 'expense';

  final ImagePicker _imagePicker = ImagePicker();

  @override
  void dispose() {
    _nameController.dispose();
    _typeController.dispose();
    for (var controller in _subcategories) {
      controller.dispose();
    }
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error uploading image: $e')));
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
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a category name')),
      );
      return;
    }

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
        'name': _nameController.text,
        'icon': _uploadedImageUrl,
        'type': _selectedType,
        'userId': widget.userId,
      });

      // Save subcategories if any
      for (var i = 0; i < _subcategories.length; i++) {
        if (_subcategories[i].text.isNotEmpty) {
          final subCategoryId =
              '${categoryId}_SUB${(i + 1).toString().padLeft(2, '0')}';

          await Supabase.instance.client.from('Subcategory').insert({
            'subCategoryId': subCategoryId,
            'name': _subcategories[i].text,
            'categoryId': categoryId,
          });
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Category created successfully')),
      );

      Navigator.pop(context, true);
    } catch (e) {
      print('Error saving category: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving category: $e')));
    } finally {
      setState(() => _isSaving = false);
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
                  // Name Field
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
                        Expanded(
                          child: TextField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              hintText: 'Name',
                              border: InputBorder.none,
                              hintStyle: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            // TODO: Handle custom bank/category
                          },
                          child: const Text(
                            'Add Custom',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Type Field (Currency style)
                  GestureDetector(
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        builder: (context) => Container(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Select Type',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ListTile(
                                title: const Text('Expense'),
                                onTap: () {
                                  setState(() => _selectedType = 'expense');
                                  Navigator.pop(context);
                                },
                              ),
                              ListTile(
                                title: const Text('Income'),
                                onTap: () {
                                  setState(() => _selectedType = 'income');
                                  Navigator.pop(context);
                                },
                              ),
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
                  // Subcategory Field
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
                          'Subcategory',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _subcategories.add(TextEditingController());
                            });
                          },
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFFC8E6C9),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.black, width: 2),
                            ),
                            child: const Icon(Icons.add, color: Colors.black),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Subcategory List
                  ..._subcategories.asMap().entries.map((entry) {
                    final index = entry.key;
                    final controller = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
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
                          children: [
                            Expanded(
                              child: TextField(
                                controller: controller,
                                decoration: InputDecoration(
                                  hintText: 'Subcategory ${index + 1}',
                                  border: InputBorder.none,
                                  hintStyle: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                  ),
                                ),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _subcategories.removeAt(index);
                                });
                              },
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFCDD2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.red,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
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
