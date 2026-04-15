import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/bank_icon_helper.dart';
import 'dart:typed_data';
import 'account_manager.dart';
import 'account_page.dart';

class EditAccountPage extends StatefulWidget {
  final Map<String, dynamic> account;
  final String userId;
  final String
  source; // 'detail' for account_detail_screen, 'manager' for account_manager

  const EditAccountPage({
    super.key,
    required this.account,
    required this.userId,
    this.source = 'detail', // default to detail
  });

  @override
  State<EditAccountPage> createState() => _EditAccountPageState();
}

class _EditAccountPageState extends State<EditAccountPage> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _balanceController;

  String? _selectedCurrency;
  bool _countInAsset = true;
  bool _hideBalance = false;
  Uint8List? _customIconBytes;
  String? _uploadedIconPath;
  bool _isLoading = false;
  List<Map<String, dynamic>> _currencies = [];
  bool _isCurrenciesLoading = true;
  List<String> _accountCategories = [];
  bool _isCategoriesLoading = true;

  late Map<String, dynamic> _originalAccount;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _originalAccount = Map<String, dynamic>.from(widget.account);

    _nameController = TextEditingController(
      text: widget.account['accountName'] ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.account['notes'] ?? '',
    );
    final balanceValue = widget.account['balance'] ?? 0.0;
    double balanceDouble = (balanceValue is int)
        ? balanceValue.toDouble()
        : (balanceValue as double);
    _balanceController = TextEditingController(text: balanceDouble.toString());

    _selectedCurrency = widget.account['currencyId'] ?? 'MYR';
    _countInAsset = widget.account['assetStatus'] ?? true;
    _hideBalance = widget.account['hideBalanceStatus'] ?? false;
    _uploadedIconPath = widget.account['iconImage'];

    _loadCurrencies();
    _loadAccountCategories();
  }

  Future<void> _loadCurrencies() async {
    try {
      final currenciesData = await Supabase.instance.client
          .from('Currency')
          .select('currencyId, name, code, symbol');

      setState(() {
        _currencies = List<Map<String, dynamic>>.from(currenciesData);
        _isCurrenciesLoading = false;
      });
    } catch (e) {
      print('Error loading currencies: $e');
      setState(() {
        _isCurrenciesLoading = false;
      });
    }
  }

  Future<void> _loadAccountCategories() async {
    try {
      final accountId = widget.account['accountId'];

      // Get all group accounts for this account with their category names
      final groupAccountsData = await Supabase.instance.client
          .from('GroupAccount')
          .select('accountCategoryId')
          .eq('accountId', accountId);

      if (groupAccountsData.isEmpty) {
        setState(() {
          _accountCategories = [];
          _isCategoriesLoading = false;
        });
        return;
      }

      // Extract unique accountCategoryIds
      final categoryIds = <String>{};
      for (var item in groupAccountsData) {
        categoryIds.add(item['accountCategoryId'] as String);
      }

      // Fetch category names for all these ids
      final categoriesData = await Supabase.instance.client
          .from('AccountCategory')
          .select('accountCategoryId, name')
          .inFilter('accountCategoryId', categoryIds.toList());

      // Sort by name for consistent display
      categoriesData.sort(
        (a, b) => (a['name'] as String).compareTo(b['name'] as String),
      );

      setState(() {
        _accountCategories = List<String>.from(
          categoriesData.map((c) => c['name'] as String),
        );
        _isCategoriesLoading = false;
      });
    } catch (e) {
      print('Error loading account categories: $e');
      setState(() {
        _accountCategories = [];
        _isCategoriesLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  String _getCurrencyCode(String? currencyId) {
    if (currencyId == null) return 'Select';
    try {
      final currency = _currencies.firstWhere(
        (c) => c['currencyId'] == currencyId,
      );
      return currency['code'] ?? currencyId;
    } catch (e) {
      return currencyId;
    }
  }

  String _getCurrencySymbol(String? currencyId) {
    if (currencyId == null) return '';
    try {
      final currency = _currencies.firstWhere(
        (c) => c['currencyId'] == currencyId,
      );
      return currency['symbol'] ?? currency['code'] ?? currencyId;
    } catch (e) {
      return '';
    }
  }

  bool _hasChanges() {
    return _nameController.text != (_originalAccount['accountName'] ?? '') ||
        _descriptionController.text != (_originalAccount['notes'] ?? '') ||
        double.tryParse(_balanceController.text) !=
            (_originalAccount['balance'] ?? 0.0) ||
        _selectedCurrency != _originalAccount['currencyId'] ||
        _countInAsset != (_originalAccount['assetStatus'] ?? true) ||
        _hideBalance != (_originalAccount['hideBalanceStatus'] ?? false) ||
        _customIconBytes != null;
  }

  bool _isRestrictedAccountType() {
    final accountType = widget.account['accountType'] ?? '';
    final restrictedTypes = ['Debit Card', 'Credit Card', 'E-Wallet'];
    return restrictedTypes.contains(accountType);
  }

  Future<void> _pickIcon() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _customIconBytes = bytes;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
      }
    }
  }

  Future<String?> _uploadIconToSupabase(Uint8List iconBytes) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'icon_${widget.userId}_$timestamp.jpg';
      final filePath = 'bank_icon/Customization/$fileName';

      await Supabase.instance.client.storage
          .from('images')
          .uploadBinary(
            filePath,
            iconBytes,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );

      final publicUrl = Supabase.instance.client.storage
          .from('images')
          .getPublicUrl(filePath);

      return publicUrl;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error uploading icon: $e')));
      }
      return null;
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

  void _showEmptyNameError() {
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
              border: Border.all(color: const Color(0xFFFFCDD2), width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Error icon
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red[100],
                  ),
                  child: Icon(
                    Icons.error_outline,
                    color: Colors.red[700],
                    size: 32,
                  ),
                ),
                const SizedBox(height: 20),
                // Error title
                const Text(
                  'Missing Field',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFF39C12),
                  ),
                ),
                const SizedBox(height: 12),
                // Error message
                const Text(
                  'Please enter an account name before saving.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF666666),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                // OK button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFA7E399),
                      foregroundColor: Colors.black,
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
        );
      },
    );
  }

  Future<void> _saveChanges() async {
    if (_nameController.text.isEmpty) {
      _showEmptyNameError();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String? iconPath = _uploadedIconPath;

      if (_customIconBytes != null) {
        // Delete old icon if exists
        if (_uploadedIconPath != null && _uploadedIconPath!.isNotEmpty) {
          await _deleteOldIcon(_uploadedIconPath!);
        }

        // Upload new icon
        iconPath = await _uploadIconToSupabase(_customIconBytes!);
        if (iconPath == null) {
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }

      final balance = double.tryParse(_balanceController.text) ?? 0.0;

      await Supabase.instance.client
          .from('Account')
          .update({
            'accountName': _nameController.text,
            'notes': _descriptionController.text,
            'balance': balance,
            'currencyId': _selectedCurrency,
            'assetStatus': _countInAsset,
            'hideBalanceStatus': _hideBalance,
            'iconImage': iconPath,
          })
          .eq('accountId', widget.account['accountId']);

      if (mounted) {
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
                      'Account Updated Successfully!',
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
                      'Your account has been updated successfully.',
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
                          if (widget.source == 'manager') {
                            // Return to account manager
                            Navigator.pop(context, true);
                          } else {
                            // Return to account detail screen
                            Navigator.pop(context, true);
                          }
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
                        child: Text(
                          widget.source == 'manager'
                              ? 'Back to Account Manager'
                              : 'Back to Account Details',
                          textAlign: TextAlign.center,
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating account: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteAccount() async {
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
                // Delete title
                const Text(
                  'Delete Account',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFF39C12),
                  ),
                ),
                const SizedBox(height: 12),
                // Delete message
                Text(
                  'Are you sure you want to delete "${_nameController.text}"? This action cannot be undone.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF666666),
                  ),
                ),
                const SizedBox(height: 24),
                // Action buttons
                Row(
                  children: [
                    // Cancel button
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[300],
                          foregroundColor: Colors.black87,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Delete button
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          try {
                            await Supabase.instance.client
                                .from('Account')
                                .delete()
                                .eq('accountId', widget.account['accountId']);

                            if (mounted) {
                              _showDeleteSuccessDialog();
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error deleting account: $e'),
                                ),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF6B6B),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
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

  void _showCancelConfirmation() {
    if (!_hasChanges()) {
      Navigator.pop(context);
      return;
    }

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
                  onPressed: () => Navigator.pop(context),
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
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
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
    );
  }

  void _showDeleteSuccessDialog() {
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
                'Account Deleted Successfully!',
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
                'Your account has been deleted successfully.',
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
                    // Navigate back based on source
                    if (widget.source == 'detail') {
                      // From detail: navigate back to account page with refresh flag
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              AccountPage(userId: widget.userId),
                        ),
                        (route) => false,
                      );
                    } else {
                      // From manager: pop back to manager with refresh flag
                      Navigator.pop(context, true); // true = refresh
                    }
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
                  child: widget.source == 'detail'
                      ? const Text(
                          'Back to Account Page',
                          textAlign: TextAlign.center,
                        )
                      : const Text('OK', textAlign: TextAlign.center),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconImage(String imagePath) {
    // For bank logos (AccountLogo/), use Supabase network URL
    if (imagePath.startsWith('AccountLogo/')) {
      final supabaseUrl = BankIconHelper.getBankIconUrl(imagePath);
      return Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Image.network(
          supabaseUrl,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.account_balance_wallet),
            );
          },
        ),
      );
    } else if (imagePath.startsWith('assets/')) {
      final assetPath = imagePath.replaceFirst('assets/', '');
      return Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Image.asset(
          assetPath,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.account_balance_wallet),
            );
          },
        ),
      );
    } else {
      return Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Image.network(
          imagePath,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.account_balance_wallet),
            );
          },
        ),
      );
    }
  }

  void _openCurrencySelection() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CurrencySelectionPage(
          currencies: _currencies,
          selectedCurrencyId: _selectedCurrency,
          onCurrencySelected: (currencyId) {
            setState(() {
              _selectedCurrency = currencyId;
            });
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _showCancelConfirmation();
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFEFFD3),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.04,
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: _showCancelConfirmation,
                            child: const Icon(Icons.close, size: 28),
                          ),
                          const Text(
                            'Edit Account',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 28),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Icon
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFA7E399),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Icon',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            GestureDetector(
                              onTap: _isRestrictedAccountType()
                                  ? null
                                  : _pickIcon,
                              child: Opacity(
                                opacity: _isRestrictedAccountType() ? 0.5 : 1.0,
                                child: _customIconBytes != null
                                    ? Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Image.memory(
                                          _customIconBytes!,
                                          fit: BoxFit.contain,
                                        ),
                                      )
                                    : _uploadedIconPath != null &&
                                          _uploadedIconPath!.isNotEmpty
                                    ? _buildIconImage(_uploadedIconPath!)
                                    : Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[300],
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.account_balance_wallet,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Name
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFA7E399),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Name',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            SizedBox(
                              width: 150,
                              child: TextField(
                                controller: _nameController,
                                textAlign: TextAlign.right,
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Description
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFA7E399),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Description',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            SizedBox(
                              width: 150,
                              child: TextField(
                                controller: _descriptionController,
                                textAlign: TextAlign.right,
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Currency
                      GestureDetector(
                        onTap: _isCurrenciesLoading
                            ? null
                            : _openCurrencySelection,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFA7E399),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Currency',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              Text(
                                _getCurrencyCode(_selectedCurrency),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Balance
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFA7E399),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Balance',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            SizedBox(
                              width: 150,
                              child: TextField(
                                controller: _balanceController,
                                textAlign: TextAlign.right,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                      signed: false,
                                    ),
                                decoration: InputDecoration(
                                  prefix: Text(
                                    _getCurrencySymbol(_selectedCurrency),
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Group
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFA7E399),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Group',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            if (_isCategoriesLoading)
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            else if (_accountCategories.isEmpty)
                              const Text(
                                'None',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              )
                            else
                              Expanded(
                                child: Text(
                                  _accountCategories.join('\n'),
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Count in Asset Toggle
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Count in Asset',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          Switch(
                            value: _countInAsset,
                            onChanged: (value) {
                              setState(() {
                                _countInAsset = value;
                              });
                            },
                            activeColor: Colors.green,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Hide Balance Toggle
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Hide Balance',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          Switch(
                            value: _hideBalance,
                            onChanged: (value) {
                              setState(() {
                                _hideBalance = value;
                              });
                            },
                            activeColor: Colors.green,
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // Save Button
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFED4E),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _saveChanges,
                            child: const Center(
                              child: Text(
                                'Save',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Delete Button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton(
                          onPressed: _deleteAccount,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red.shade600,
                            side: BorderSide(
                              color: Colors.red.shade600,
                              width: 2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          child: const Text('Delete Account'),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

class CurrencySelectionPage extends StatefulWidget {
  final List<Map<String, dynamic>> currencies;
  final String? selectedCurrencyId;
  final Function(String) onCurrencySelected;

  const CurrencySelectionPage({
    super.key,
    required this.currencies,
    this.selectedCurrencyId,
    required this.onCurrencySelected,
  });

  @override
  State<CurrencySelectionPage> createState() => _CurrencySelectionPageState();
}

class _CurrencySelectionPageState extends State<CurrencySelectionPage> {
  late TextEditingController _searchController;
  late List<Map<String, dynamic>> _filteredCurrencies;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _filteredCurrencies = widget.currencies;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterCurrencies(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredCurrencies = widget.currencies;
      } else {
        _filteredCurrencies = widget.currencies
            .where(
              (currency) =>
                  currency['name'].toString().toLowerCase().contains(
                    query.toLowerCase(),
                  ) ||
                  (currency['code'] ?? '').toString().toLowerCase().contains(
                    query.toLowerCase(),
                  ),
            )
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEFFD3),
      body: Column(
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.04),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.arrow_back, size: 28),
                ),
                const Text(
                  'Select Currency',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 28),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: TextField(
              controller: _searchController,
              onChanged: _filterCurrencies,
              decoration: InputDecoration(
                hintText: 'Search currency...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              itemCount: _filteredCurrencies.length,
              itemBuilder: (context, index) {
                final currency = _filteredCurrencies[index];
                final isSelected =
                    currency['currencyId'] == widget.selectedCurrencyId;
                return GestureDetector(
                  onTap: () =>
                      widget.onCurrencySelected(currency['currencyId']),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.green.shade100 : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? Colors.green : Colors.grey.shade300,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currency['name'],
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              currency['code'] ?? '',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        if (isSelected)
                          const Icon(Icons.check_circle, color: Colors.green),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
