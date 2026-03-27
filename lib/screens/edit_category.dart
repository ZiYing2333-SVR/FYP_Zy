import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';

class EditCategory extends StatefulWidget {
  final String categoryId;
  final Map<String, dynamic> category;
  final String userId;

  const EditCategory({
    Key? key,
    required this.categoryId,
    required this.category,
    required this.userId,
  }) : super(key: key);

  @override
  State<EditCategory> createState() => _EditCategoryState();
}

class _EditCategoryState extends State<EditCategory> {
  late TextEditingController _nameController;
  bool _isDefaultCategory = false;
  bool _isLoading = false;
  late Map<String, dynamic> _originalCategory;
  Uint8List? _selectedIconBytes;
  String? _newIconUrl;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _originalCategory = Map<String, dynamic>.from(widget.category);
    _nameController = TextEditingController(
      text: widget.category['name'] ?? '',
    );
    _checkIfDefaultCategory();
  }

  void _checkIfDefaultCategory() {
    // Default category pattern: CAT+UID0000+sequence
    final categoryId = widget.categoryId;
    _isDefaultCategory = categoryId.contains('UID0000');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool _hasChanges() {
    return _nameController.text != (_originalCategory['name'] ?? '') ||
        _selectedIconBytes != null;
  }

  Future<void> _pickIcon() async {
    final pickedFile = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _selectedIconBytes = bytes;
      });
    }
  }

  Future<String> _uploadIconToStorage(Uint8List iconBytes) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'customizeIcon_${widget.userId}_$timestamp.jpg';
      final path = 'category_icon/customizeIcon/$fileName';

      await Supabase.instance.client.storage
          .from('images')
          .uploadBinary(path, iconBytes);

      final publicUrl = Supabase.instance.client.storage
          .from('images')
          .getPublicUrl(path);

      return publicUrl;
    } catch (e) {
      print('Error uploading icon: $e');
      rethrow;
    }
  }

  Future<void> _deleteOldIcon(String iconUrl) async {
    try {
      // Extract the path from the URL
      final uri = Uri.parse(iconUrl);
      final pathSegments = uri.pathSegments;
      final pathIndex = pathSegments.indexOf('images');
      if (pathIndex != -1) {
        final filePath = pathSegments.sublist(pathIndex + 1).join('/');
        await Supabase.instance.client.storage.from('images').remove([
          filePath,
        ]);
      }
    } catch (e) {
      print('Error deleting old icon: $e');
      // Don't throw, as this is not critical
    }
  }

  Future<void> _saveCategory() async {
    if (!_hasChanges()) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No changes made')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Handle icon upload
      if (_selectedIconBytes != null) {
        // Upload new icon
        _newIconUrl = await _uploadIconToStorage(_selectedIconBytes!);

        // Delete old icon if exists
        final oldIconUrl = _originalCategory['icon'];
        if (oldIconUrl != null && oldIconUrl.isNotEmpty) {
          await _deleteOldIcon(oldIconUrl);
        }
      }

      // Prepare update data with proper typing
      final Map<String, dynamic> updateData = {'name': _nameController.text};

      // Add new icon URL if available
      if (_newIconUrl != null && _newIconUrl!.isNotEmpty) {
        updateData['icon'] = _newIconUrl!;
      }

      // Update category in database
      await Supabase.instance.client
          .from('Category')
          .update(updateData)
          .eq('categoryId', widget.categoryId);

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
                    'Category Updated Successfully!',
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
                    'Your category has been updated successfully.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Color(0xFF666666)),
                  ),
                  const SizedBox(height: 24),
                  // Continue button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context); // Close dialog
                        Navigator.pop(
                          context,
                          true,
                        ); // Return to category manager with refresh signal
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFA7E399),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      child: const Text('Done'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating category: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteCategory() async {
    // Show confirmation dialog
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
                // Warning icon
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red[100],
                  ),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.red[700],
                    size: 32,
                  ),
                ),
                const SizedBox(height: 20),
                // Confirmation title
                const Text(
                  'Delete Category?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 12),
                // Confirmation message
                Text(
                  'Are you sure you want to delete "${_nameController.text}"? This action cannot be undone.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF666666),
                  ),
                ),
                const SizedBox(height: 24),
                // Cancel and Delete buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFBCBCBC),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _confirmDelete(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[600],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        child: const Text('Delete'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext dialogContext) async {
    Navigator.pop(dialogContext); // Close confirmation dialog

    setState(() {
      _isLoading = true;
    });

    try {
      // Delete icon from storage if exists
      final iconUrl = _originalCategory['icon'];
      if (iconUrl != null && iconUrl.isNotEmpty) {
        await _deleteOldIcon(iconUrl);
      }

      // Delete category from database
      await Supabase.instance.client
          .from('Category')
          .delete()
          .eq('categoryId', widget.categoryId);

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
                    'Category Deleted Successfully!',
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
                    'Your category has been deleted successfully.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Color(0xFF666666)),
                  ),
                  const SizedBox(height: 24),
                  // Continue button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context); // Close dialog
                        Navigator.pop(
                          context,
                          true,
                        ); // Return to category manager with refresh signal
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFA7E399),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      child: const Text('Done'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting category: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF9E6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF9E6),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isDefaultCategory ? 'View Category' : 'Edit Category',
          style: const TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category Icon
              Center(
                child: Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: const Color(0xFFB0E0E6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _selectedIconBytes != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.memory(
                                _selectedIconBytes!,
                                fit: BoxFit.cover,
                              ),
                            )
                          : (widget.category['icon'] != null &&
                                    widget.category['icon'].isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      widget.category['icon'],
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                            return Icon(
                                              Icons.category,
                                              color: Colors.grey[600],
                                              size: 50,
                                            );
                                          },
                                    ),
                                  )
                                : Icon(
                                    Icons.category,
                                    color: Colors.grey[600],
                                    size: 50,
                                  )),
                    ),
                    // Change icon button (only for user categories)
                    if (!_isDefaultCategory)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _pickIcon,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFFA7E399),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // Info message for default categories
              if (_isDefaultCategory)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange[300]!, width: 1),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info, color: Colors.orange[700]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'This is a default category and cannot be edited.',
                          style: TextStyle(
                            color: Colors.orange[700],
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              // Category Name Field
              const Text(
                'Category Name',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                enabled: !_isDefaultCategory,
                decoration: InputDecoration(
                  hintText: 'Enter category name',
                  filled: true,
                  fillColor: _isDefaultCategory
                      ? Colors.grey[200]
                      : Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE8D5F2)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE8D5F2)),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE8D5F2)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              // Save Button (only for user categories)
              if (!_isDefaultCategory)
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveCategory,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFA7E399),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          disabledBackgroundColor: const Color(0xFFD3F8D3),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.black,
                                  ),
                                ),
                              )
                            : const Text('Save Changes'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Delete Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _deleteCategory,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[600],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        child: const Text('Delete Category'),
                      ),
                    ),
                  ],
                )
              else
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFBCBCBC),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    child: const Text('Back'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
