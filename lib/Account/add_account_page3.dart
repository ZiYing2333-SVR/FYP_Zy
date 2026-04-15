import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/bank_icon_helper.dart';

import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'account_manager.dart';

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
          // Header
          SizedBox(height: MediaQuery.of(context).size.height * 0.06),
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

          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _filterCurrencies,
                decoration: InputDecoration(
                  hintText: 'Search currency...',
                  border: InputBorder.none,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            _filterCurrencies('');
                          },
                          child: const Icon(Icons.close),
                        )
                      : null,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Currency List
          Expanded(
            child: _filteredCurrencies.isEmpty
                ? Center(
                    child: Text(
                      'No currencies found',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  )
                : ListView.builder(
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
                            color: isSelected
                                ? Colors.green.shade100
                                : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.green
                                  : Colors.grey.shade300,
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
                                const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 24,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class AddAccountPage3 extends StatefulWidget {
  final String accountType;
  final String bankName;
  final String? bankImage;
  final String? userId;

  const AddAccountPage3({
    super.key,
    required this.accountType,
    required this.bankName,
    this.bankImage,
    this.userId,
  });

  @override
  State<AddAccountPage3> createState() => _AddAccountPage3State();
}

class _AddAccountPage3State extends State<AddAccountPage3> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _balanceController;
  late FocusNode _balanceFocusNode;

  String? _selectedCurrency;
  String? _defaultCurrency;
  bool _countInAsset = true;
  bool _hideBalance = false;
  Uint8List? _customIconBytes;
  String? _uploadedIconPath;
  bool _isLoading = false;
  List<Map<String, dynamic>> _currencies = [];
  bool _isCurrenciesLoading = true;

  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.bankName);
    _descriptionController = TextEditingController();
    _balanceController = TextEditingController(text: '0');
    _uploadedIconPath = widget.bankImage ?? '';

    // Initialize balance focus node with listeners
    _balanceFocusNode = FocusNode();
    _balanceFocusNode.addListener(_handleBalanceFocus);

    _loadCurrencies();
  }

  Future<void> _loadCurrencies() async {
    try {
      // Fetch all currencies from the Currency table
      final currenciesData = await Supabase.instance.client
          .from('Currency')
          .select('currencyId, name, code, symbol');

      // Fetch user's default currency from UserCurrency table
      String? defaultCurrency;
      if (widget.userId != null && widget.userId!.isNotEmpty) {
        try {
          final userCurrencyData = await Supabase.instance.client
              .from('UserCurrency')
              .select()
              .eq('userId', widget.userId!)
              .single();

          defaultCurrency = userCurrencyData['currencyId'];
        } catch (e) {
          // No user currency set, will use first currency as default
          print('No default currency found: $e');
        }
      }

      setState(() {
        _currencies = List<Map<String, dynamic>>.from(currenciesData);
        // Set default to user's currency or first currency in list
        _defaultCurrency =
            defaultCurrency ??
            (_currencies.isNotEmpty ? _currencies[0]['currencyId'] : 'MYR');
        _selectedCurrency = _defaultCurrency;
        _isCurrenciesLoading = false;
      });
    } catch (e) {
      print('Error loading currencies: $e');
      setState(() {
        _isCurrenciesLoading = false;
        _selectedCurrency = 'MYR'; // Fallback
      });
    }
  }

  Future<String> _generateAccountId() async {
    try {
      final userId = widget.userId;
      if (userId == null || userId.isEmpty) {
        return 'ACC0001';
      }

      // Query all accounts for this user to get the next sequence number
      final existingAccounts = await Supabase.instance.client
          .from('Account')
          .select('accountId')
          .ilike('accountId', '$userId%');

      // Parse the sequence number from existing account IDs
      int maxSequence = 0;
      for (var account in existingAccounts) {
        final accountId = account['accountId'] as String;
        // Format: USERID+ACC+0001
        if (accountId.contains('ACC')) {
          try {
            final sequencePart = accountId.split('ACC').last;
            final sequence = int.parse(sequencePart);
            if (sequence > maxSequence) {
              maxSequence = sequence;
            }
          } catch (e) {
            print('Error parsing account ID: $e');
          }
        }
      }

      // Generate new account ID
      final newSequence = maxSequence + 1;
      final sequenceStr = newSequence.toString().padLeft(4, '0');
      return '${userId}ACC$sequenceStr';
    } catch (e) {
      print('Error generating account ID: $e');
      return 'ACC${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  String _getCurrencyCode(String? currencyId) {
    if (currencyId == null) return 'Select Currency';
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

  String _getBalancePrefix() {
    // Always show the symbol
    return _getCurrencySymbol(_selectedCurrency);
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
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _balanceController.dispose();
    _balanceFocusNode.removeListener(_handleBalanceFocus);
    _balanceFocusNode.dispose();
    super.dispose();
  }

  void _handleBalanceFocus() {
    if (_balanceFocusNode.hasFocus) {
      // On focus: clear if value is "0"
      if (_balanceController.text == '0') {
        _balanceController.clear();
      }
    } else {
      // On unfocus: restore to "0" if empty
      if (_balanceController.text.isEmpty) {
        _balanceController.text = '0';
      }
    }
  }

  String _removeLeadingZeros(String value) {
    // Remove leading zeros but keep at least one digit
    if (value.isEmpty) return '0';
    final intValue = int.tryParse(value) ?? 0;
    return intValue.toString();
  }

  Future<void> _pickIcon() async {
    // Check if this is a regular bank (not customize)
    final isRegularBank =
        widget.bankName != 'Add Custom Bank' &&
        widget.bankImage != null &&
        (widget.bankImage?.isNotEmpty ?? false);

    if (isRegularBank) {
      // If bank is pre-selected, don't allow icon change
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bank icon cannot be changed for pre-selected banks'),
        ),
      );
      return;
    }

    // For customize banks, allow image upload to Customization folder
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        requestFullMetadata: true,
      );

      if (pickedFile != null) {
        // Validate file extension
        final allowedExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp'];
        final fileName = pickedFile.name.toLowerCase();
        final fileExtension = fileName.contains('.')
            ? fileName.split('.').last
            : '';

        print('📸 Image file: $fileName, Extension: $fileExtension');

        if (!allowedExtensions.contains(fileExtension)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Please upload an image file (jpg, jpeg, png, gif, webp)',
                ),
              ),
            );
          }
          return;
        }

        // Read bytes and store for preview - will upload when saving account
        if (mounted) {
          final bytes = await pickedFile.readAsBytes();
          setState(() {
            _customIconBytes = bytes;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Icon selected. Click Save to upload and create account.',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
      }
    }
  }

  Future<String?> _uploadIconToSupabase() async {
    try {
      // Use stored bytes instead of File
      if (_customIconBytes == null) {
        print('❌ No icon bytes to upload');
        return null;
      }

      final fileName =
          'icon_${const Uuid().v4()}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      // Upload custom bank icons to Customization folder
      final filePath = 'bank_icon/Customization/$fileName';

      print('📤 Uploading to Supabase: bucket=images, path=$filePath');

      // Step 1: Upload image to Supabase Storage
      await Supabase.instance.client.storage
          .from('images')
          .uploadBinary(
            filePath,
            _customIconBytes!,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );

      // Step 2: Get public URL from storage using the correct format
      // URL format: https://{projectId}.supabase.co/storage/v1/object/public/{bucket}/{path}
      final projectId = 'drohtvfhklvqoeokopey';
      final publicUrl =
          'https://$projectId.supabase.co/storage/v1/object/public/images/$filePath';

      // Ensure the URL format is correct for public access
      print('📍 Generated URL: $publicUrl');
      print('✅ Custom icon uploaded successfully');
      return publicUrl;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error uploading icon: $e')));
      }
      print('❌ Upload error: $e');
      return null;
    }
  }

  Future<void> _confirmAndSave() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter account name')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Check if this is a regular bank or custom bank
      final isRegularBank =
          widget.bankName != 'Add Custom Bank' &&
          widget.bankImage != null &&
          (widget.bankImage?.isNotEmpty ?? false);

      // If custom bank and custom icon is selected, upload it to Customization folder
      if (!isRegularBank && _customIconBytes != null) {
        _uploadedIconPath = await _uploadIconToSupabase();
        if (_uploadedIconPath == null) {
          setState(() {
            _isLoading = false;
          });
          return;
        }
      } else if (isRegularBank) {
        // For regular banks, keep the original bank icon URL
        _uploadedIconPath = widget.bankImage ?? '';
      } else {
        // For custom bank with no image selected
        _uploadedIconPath = null;
      }

      // Get user ID from parameter
      final userId = widget.userId;
      if (userId == null || userId.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('User ID not provided')));
        }
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Generate sequential account ID
      final accountId = await _generateAccountId();

      // Parse balance
      final balance = double.tryParse(_balanceController.text) ?? 0.0;

      // Insert into Supabase
      await Supabase.instance.client.from('Account').insert({
        'accountId': accountId,
        'accountName': _nameController.text,
        'accountType': widget.accountType,
        'balance': balance,
        'assetStatus': _countInAsset,
        'hideBalanceStatus': _hideBalance,
        'notes': _descriptionController.text,
        'iconImage': _uploadedIconPath,
        'chartColor': '#4CAF50',
        'currencyId': _selectedCurrency,
        'ledgerId': null,
        'accountCategoryId': null,
        'userId': userId,
      });

      if (mounted) {
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
                      'Account Created Successfully!',
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
                      'Your new account has been created successfully. Your account list will now be displayed.',
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
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  AccountManager(userId: userId),
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
                        child: const Text('View My Accounts'),
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
        ).showSnackBar(SnackBar(content: Text('Error creating account: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCustomAccount = widget.bankImage?.isEmpty ?? true;

    return Scaffold(
      backgroundColor: const Color(0xFFFEFFD3),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              // Header
              SizedBox(height: MediaQuery.of(context).size.height * 0.06),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back, size: 28),
                  ),
                  const Text(
                    'Add Account',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 28),
                ],
              ),
              const SizedBox(height: 30),

              // Icon Section
              GestureDetector(
                onTap: isCustomAccount ? _pickIcon : null,
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
                        'Icon',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.white,
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: _buildIconDisplay(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Name Field
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

              // Description Field
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFA7E399),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    hintText: 'Description',
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
              const SizedBox(height: 16),

              // Currency Field
              GestureDetector(
                onTap: _isCurrenciesLoading ? null : _openCurrencySelection,
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
                      _isCurrenciesLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Row(
                              children: [
                                Text(
                                  _getCurrencyCode(_selectedCurrency),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                  color: Colors.black87,
                                ),
                              ],
                            ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Balance Field
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
                      width: 120,
                      child: TextField(
                        controller: _balanceController,
                        focusNode: _balanceFocusNode,
                        textAlign: TextAlign.right,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(15),
                        ],
                        onChanged: (value) {
                          // Remove leading zeros when user types
                          if (value.isNotEmpty && value != '0') {
                            final cleanedValue = _removeLeadingZeros(value);
                            if (cleanedValue != value) {
                              _balanceController.text = cleanedValue;
                              // Move cursor to end
                              _balanceController.selection =
                                  TextSelection.fromPosition(
                                    TextPosition(offset: cleanedValue.length),
                                  );
                            }
                          }
                        },
                        decoration: InputDecoration(
                          prefix: Text(_getBalancePrefix()),
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
              const SizedBox(height: 20),

              // Count in Asset Toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Count in Asset',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
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
              const SizedBox(height: 12),

              // Hide Balance Toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Hide Balance',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
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
              const SizedBox(height: 30),

              // Confirm Button
              GestureDetector(
                onTap: _isLoading ? null : _confirmAndSave,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 48,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD966),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Confirm',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconDisplay() {
    // Show preview of selected image bytes (before upload)
    if (_customIconBytes != null) {
      return Image.memory(_customIconBytes!, fit: BoxFit.contain);
    } else if (_uploadedIconPath != null && _uploadedIconPath!.isNotEmpty) {
      // Display bank logo or previously uploaded icon
      if (_uploadedIconPath!.startsWith('http')) {
        // Network URL
        return Image.network(
          _uploadedIconPath!,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(Icons.account_balance_wallet, color: Colors.grey);
          },
        );
      } else {
        // Bank logo - use Supabase URL
        final supabaseUrl = BankIconHelper.getBankIconUrl(_uploadedIconPath!);
        return Image.network(
          supabaseUrl,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(Icons.account_balance_wallet, color: Colors.grey);
          },
        );
      }
    } else {
      // No icon selected
      return const Icon(Icons.image, color: Colors.grey, size: 32);
    }
  }
}
