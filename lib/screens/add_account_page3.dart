import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/bank_icon_helper.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'account_page.dart';

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
                  currency['currencyId'].toString().toLowerCase().contains(
                    query.toLowerCase(),
                  ) ||
                  currency['name'].toString().toLowerCase().contains(
                    query.toLowerCase(),
                  ) ||
                  currency['country'].toString().toLowerCase().contains(
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
                                    currency['country'] ?? '',
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
  final String bankImage;
  final String? userId;

  const AddAccountPage3({
    super.key,
    required this.accountType,
    required this.bankName,
    required this.bankImage,
    this.userId,
  });

  @override
  State<AddAccountPage3> createState() => _AddAccountPage3State();
}

class _AddAccountPage3State extends State<AddAccountPage3> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _balanceController;

  String? _selectedCurrency;
  bool _countInAsset = true;
  bool _hideBalance = false;
  File? _customIcon;
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
    _uploadedIconPath = widget.bankImage;
    _loadCurrencies();
  }

  Future<void> _loadCurrencies() async {
    try {
      // Fetch all currencies from the Currency table
      final currenciesData = await Supabase.instance.client
          .from('Currency')
          .select();

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
        _selectedCurrency =
            defaultCurrency ??
            (_currencies.isNotEmpty ? _currencies[0]['currencyId'] : 'MYR');
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
    super.dispose();
  }

  Future<void> _pickIcon() async {
    if (widget.bankImage.isNotEmpty) {
      // If bank is pre-selected, don't allow icon change
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bank icon cannot be changed for pre-selected banks'),
        ),
      );
      return;
    }

    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        setState(() {
          _customIcon = File(pickedFile.path);
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

  Future<String?> _uploadIconToSupabase(File iconFile) async {
    try {
      final fileName =
          'icon_${const Uuid().v4()}_${DateTime.now().millisecondsSinceEpoch}.png';
      final filePath = 'iconImage/$fileName';

      final bytes = await iconFile.readAsBytes();

      await Supabase.instance.client.storage
          .from('profile_image')
          .uploadBinary(
            filePath,
            bytes,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );

      // Construct public URL using the provided endpoint
      final publicUrl =
          'https://drohtvfhklvqoeokopey.storage.supabase.co/storage/v1/object/public/profile_image/$filePath';

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
      // If custom icon is selected, upload it
      if (_customIcon != null && widget.bankImage.isEmpty) {
        _uploadedIconPath = await _uploadIconToSupabase(_customIcon!);
        if (_uploadedIconPath == null) {
          setState(() {
            _isLoading = false;
          });
          return;
        }
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created successfully'),
            duration: Duration(seconds: 2),
          ),
        );

        // Navigate to Account Page
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => AccountPage(userId: userId)),
          (route) => route.isFirst,
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
    final isCustomAccount = widget.bankImage.isEmpty;

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
                                  _selectedCurrency ?? 'Select Currency',
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
                        textAlign: TextAlign.right,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          prefix: Text('RM'),
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
    if (_customIcon != null) {
      // Display custom picked icon
      if (kIsWeb) {
        // On web, show placeholder since we can't display File directly
        return const Icon(Icons.image, color: Colors.grey, size: 32);
      } else {
        // On mobile, use Image.file
        return Image.file(_customIcon!, fit: BoxFit.contain);
      }
    } else if (_uploadedIconPath != null && _uploadedIconPath!.isNotEmpty) {
      // Display bank logo or previously uploaded icon
      if (_uploadedIconPath!.startsWith('AccountLogo/')) {
        // Bank logo - use Supabase URL
        final supabaseUrl = BankIconHelper.getBankIconUrl(_uploadedIconPath!);
        return Image.network(
          supabaseUrl,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(Icons.account_balance_wallet, color: Colors.grey);
          },
        );
      } else if (_uploadedIconPath!.startsWith('http')) {
        // Network URL
        return Image.network(
          _uploadedIconPath!,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(Icons.account_balance_wallet, color: Colors.grey);
          },
        );
      } else {
        // Asset path
        return Image.asset(
          _uploadedIconPath!,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(Icons.account_balance_wallet, color: Colors.grey);
          },
        );
      }
    } else {
      // Placeholder
      return const Icon(
        Icons.add_photo_alternate,
        color: Colors.grey,
        size: 32,
      );
    }
  }
}
