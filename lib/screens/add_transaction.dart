import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:collection/collection.dart';
import 'dart:io';

class AddTransaction extends StatefulWidget {
  final String userId;
  final String? ledgerId;

  const AddTransaction({Key? key, required this.userId, this.ledgerId})
    : super(key: key);

  @override
  State<AddTransaction> createState() => _AddTransactionState();
}

class _AddTransactionState extends State<AddTransaction> {
  List<Map<String, dynamic>> expenseCategories = [];
  List<Map<String, dynamic>> incomeCategories = [];
  bool _isLoading = true;

  String _amountText = '0';
  Map<String, dynamic>? _selectedCategory;
  String _selectedType = 'expense';
  DateTime _selectedDate = DateTime.now();
  final _noteController = TextEditingController();
  final _accountController = TextEditingController();
  XFile? _selectedImage;
  List<Map<String, dynamic>> _accounts = [];
  String? _selectedAccountId;
  String? _selectedFromAccountId;
  String? _selectedToAccountId;
  Map<String, dynamic>? _selectedAccount;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    _fetchAccounts();
  }

  @override
  void dispose() {
    _noteController.dispose();
    _accountController.dispose();
    super.dispose();
  }

  Future<void> _fetchCategories() async {
    try {
      // Fetch default expense categories
      final defaultExpenseResponse = await Supabase.instance.client
          .from('Category')
          .select()
          .eq('type', 'expense')
          .isFilter('userId', null)
          .order('categoryId');

      // Fetch user's custom expense categories
      final userExpenseResponse = await Supabase.instance.client
          .from('Category')
          .select()
          .eq('type', 'expense')
          .eq('userId', widget.userId)
          .order('categoryId');

      // Fetch default income categories
      final defaultIncomeResponse = await Supabase.instance.client
          .from('Category')
          .select()
          .eq('type', 'income')
          .isFilter('userId', null)
          .order('categoryId');

      // Fetch user's custom income categories
      final userIncomeResponse = await Supabase.instance.client
          .from('Category')
          .select()
          .eq('type', 'income')
          .eq('userId', widget.userId)
          .order('categoryId');

      setState(() {
        expenseCategories = <Map<String, dynamic>>[
          ...List<Map<String, dynamic>>.from(defaultExpenseResponse as List),
          ...List<Map<String, dynamic>>.from(userExpenseResponse as List),
        ];
        incomeCategories = <Map<String, dynamic>>[
          ...List<Map<String, dynamic>>.from(defaultIncomeResponse as List),
          ...List<Map<String, dynamic>>.from(userIncomeResponse as List),
        ];
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching categories: $e');
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading categories: $e')));
    }
  }

  Future<void> _fetchAccounts() async {
    try {
      final response = await Supabase.instance.client
          .from('Account')
          .select()
          .eq('userId', widget.userId)
          .order('accountId');

      setState(() {
        _accounts = List<Map<String, dynamic>>.from(response);
        // Don't auto-select account
      });
    } catch (e) {
      print('Error fetching accounts: $e');
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
      );
      if (image != null) {
        setState(() {
          _selectedImage = image;
        });
      }
    } catch (e) {
      print('Error picking image: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
    }
  }

  Future<void> _scanImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
      );
      if (image != null) {
        setState(() {
          _selectedImage = image;
        });
      }
    } catch (e) {
      print('Error scanning image: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error scanning image: $e')));
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _handleNumberInput(String value) {
    setState(() {
      if (value == 'C') {
        _amountText = '0';
      } else if (value == '<') {
        if (_amountText.length > 1) {
          _amountText = _amountText.substring(0, _amountText.length - 1);
        } else {
          _amountText = '0';
        }
      } else if (value == '.') {
        if (!_amountText.contains('.')) {
          _amountText += '.';
        }
      } else if (value == '✓') {
        // Save transaction
        _saveTransaction();
        return;
      } else {
        if (_amountText == '0' && value != '.') {
          _amountText = value;
        } else {
          _amountText += value;
        }
      }
    });
  }

  Future<void> _saveTransaction() async {
    // Original single transaction logic
    // Validate based on transaction type
    if (_selectedType == 'transfer') {
      if (_selectedFromAccountId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a from account')),
        );
        return;
      }

      if (_selectedToAccountId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a to account')),
        );
        return;
      }

      if (_selectedFromAccountId == _selectedToAccountId) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('From and To accounts cannot be the same'),
          ),
        );
        return;
      }
    } else {
      if (_selectedCategory == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a category')),
        );
        return;
      }

      if (_selectedAccountId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select an account')),
        );
        return;
      }
    }

    if (_amountText == '0' || _amountText.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter an amount')));
      return;
    }

    // Show preview dialog
    _showPreviewDialog();
  }

  Future<void> _showPreviewDialog() async {
    // Get from/to account details for transfer
    Map<String, dynamic>? fromAccount;
    Map<String, dynamic>? toAccount;

    if (_selectedType == 'transfer') {
      fromAccount = _accounts.firstWhereOrNull(
        (acc) => acc['accountId'] == _selectedFromAccountId,
      );
      toAccount = _accounts.firstWhereOrNull(
        (acc) => acc['accountId'] == _selectedToAccountId,
      );
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFFF9E6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          contentPadding: const EdgeInsets.all(24),
          title: const Text(
            'Transaction Preview',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFFF39C12),
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPreviewItem('Type', _selectedType.toUpperCase()),
                if (_selectedType == 'transfer') ...[
                  _buildPreviewItem(
                    'From Account',
                    fromAccount?['accountName'] ?? 'Unknown',
                  ),
                  _buildPreviewItem(
                    'To Account',
                    toAccount?['accountName'] ?? 'Unknown',
                  ),
                ] else ...[
                  _buildPreviewItem(
                    'Category',
                    _selectedCategory!['name'] ?? '',
                  ),
                  _buildPreviewItem(
                    'Account',
                    _selectedAccount!['accountName'] ?? '',
                  ),
                ],
                _buildPreviewItem('Amount', 'RM${_amountText}'),
                _buildPreviewItem(
                  'Date',
                  _selectedDate.toLocal().toString().split(' ')[0],
                ),
                if (_noteController.text.isNotEmpty)
                  _buildPreviewItem('Note', _noteController.text),
                if (_selectedImage != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Image:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 120,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(_selectedImage!.path),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Center(
                                  child: Icon(
                                    Icons.image,
                                    color: Colors.grey,
                                    size: 40,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _confirmSaveTransaction();
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPreviewItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(value),
        ],
      ),
    );
  }

  Future<void> _confirmSaveTransaction() async {
    try {
      String? imageUrl;

      // Upload image if selected
      if (_selectedImage != null) {
        final fileName = 'TXN${DateTime.now().millisecondsSinceEpoch}.jpg';
        final filePath = 'transaction_image/$fileName';

        final file = File(_selectedImage!.path);

        await Supabase.instance.client.storage
            .from('images')
            .upload(filePath, file);

        imageUrl = Supabase.instance.client.storage
            .from('images')
            .getPublicUrl(filePath);
      }

      final amount = double.parse(_amountText);

      if (_selectedType == 'transfer') {
        // For transfer, create a single record in Transfer table
        // Get the count of existing transfers for this user to generate sequence
        final existingTransfers = await Supabase.instance.client
            .from('Transfer')
            .select('transferId')
            .like('transferId', 'TRANSFER${widget.userId}%');

        final sequenceNumber = existingTransfers.length + 1;
        final formattedSequence = sequenceNumber.toString().padLeft(6, '0');
        final transferId = 'TRANSFER${widget.userId}$formattedSequence';

        // Save transfer record to Transfer table
        await Supabase.instance.client.from('Transfer').insert({
          'transferId': transferId,
          'fromAccountId': _selectedFromAccountId,
          'toAccountId': _selectedToAccountId,
          'amount': amount,
          'date': _selectedDate.toIso8601String(),
          'note': _noteController.text,
          'noteImage': imageUrl,
        });

        // Update both account balances
        if (_selectedFromAccountId != null) {
          final fromAccount = _accounts.firstWhereOrNull(
            (acc) => acc['accountId'] == _selectedFromAccountId,
          );
          final fromBalance = fromAccount?['balance'] ?? 0.0;
          final newFromBalance = fromBalance - amount;

          await Supabase.instance.client
              .from('Account')
              .update({'balance': newFromBalance})
              .eq('accountId', _selectedFromAccountId ?? '');
        }

        if (_selectedToAccountId != null) {
          final toAccount = _accounts.firstWhereOrNull(
            (acc) => acc['accountId'] == _selectedToAccountId,
          );
          final toBalance = toAccount?['balance'] ?? 0.0;
          final newToBalance = toBalance + amount;

          await Supabase.instance.client
              .from('Account')
              .update({'balance': newToBalance})
              .eq('accountId', _selectedToAccountId ?? '');
        }
      } else {
        // Original logic for expense/income transactions
        // Generate transaction ID: TRANS+userId+sequence
        final existingTransactions = await Supabase.instance.client
            .from('Transaction')
            .select('transactionId')
            .like('transactionId', 'TRANS${widget.userId}%');

        final sequenceNumber = existingTransactions.length + 1;
        final formattedSequence = sequenceNumber.toString().padLeft(6, '0');
        final transactionId = 'TRANS${widget.userId}$formattedSequence';

        // Save transaction to database
        await Supabase.instance.client.from('Transaction').insert({
          'transactionId': transactionId,
          'categoryId': _selectedCategory!['categoryId'],
          'accountId': _selectedAccountId,
          'amount': amount,
          'date': _selectedDate.toIso8601String(),
          'note': _noteController.text,
          'type': _selectedType,
          'ledgerId': widget.ledgerId,
          'image': imageUrl,
        });

        // Update account balance based on transaction type
        if (_selectedAccountId != null) {
          final currentBalance = _selectedAccount?['balance'] ?? 0.0;
          final newBalance = _selectedType == 'expense'
              ? currentBalance - amount
              : currentBalance + amount;

          await Supabase.instance.client
              .from('Account')
              .update({'balance': newBalance})
              .eq('accountId', _selectedAccountId ?? '');
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction saved successfully')),
      );

      Navigator.pop(context, true);
    } catch (e) {
      print('Error saving transaction: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving transaction: $e')));
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
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const SizedBox.shrink(),
      ),
      body: Column(
        children: [
          // Expense/Income/Transfer Toggle (Top Center - Larger)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedType = 'expense';
                      _selectedCategory = null;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _selectedType == 'expense'
                          ? const Color(0xFF90EE90)
                          : const Color(0xFFE8E8E8),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Expense',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedType = 'income';
                      _selectedCategory = null;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _selectedType == 'income'
                          ? const Color(0xFFB0E0E6)
                          : const Color(0xFFE8E8E8),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Income',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedType = 'transfer';
                      _selectedCategory = null;
                      _selectedFromAccountId = null;
                      _selectedToAccountId = null;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _selectedType == 'transfer'
                          ? const Color(0xFFA7E399)
                          : const Color(0xFFE8E8E8),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Transfer',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Categories Grid (Expense/Income) or Account Selection (Transfer) - Scrollable
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _selectedType == 'transfer'
                ? _buildTransferAccountSelection()
                : Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    child: GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 20,
                            childAspectRatio: 0.75,
                          ),
                      itemCount: _selectedType == 'expense'
                          ? expenseCategories.length
                          : incomeCategories.length,
                      itemBuilder: (context, index) {
                        final categories = _selectedType == 'expense'
                            ? expenseCategories
                            : incomeCategories;
                        final category = categories[index];
                        final isSelected =
                            _selectedCategory?['categoryId'] ==
                            category['categoryId'];

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedCategory = category;
                            });
                          },
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF90EE90)
                                      : const Color(0xFFB0E0E6),
                                  borderRadius: BorderRadius.circular(12),
                                  border: isSelected
                                      ? Border.all(
                                          color: Colors.black,
                                          width: 3,
                                        )
                                      : null,
                                ),
                                child:
                                    category['icon'] != null &&
                                        category['icon'].isNotEmpty
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.network(
                                          category['icon'],
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                                return Icon(
                                                  Icons.category,
                                                  color: Colors.grey[600],
                                                  size: 30,
                                                );
                                              },
                                        ),
                                      )
                                    : Icon(
                                        Icons.category,
                                        color: Colors.grey[600],
                                        size: 30,
                                      ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: 70,
                                child: Text(
                                  category['name'] ?? 'Unknown',
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
          ),
          // Icon Buttons Row (Notes, Account, Today, Image, Scanning)
          Container(
            color: const Color(0xFFFFF9E6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildNoteButton(),
                  if (_selectedType != 'transfer') _buildAccountButton(),
                  _buildDateButton(),
                  _buildImageButton(),
                  _buildIconButton(Icons.qr_code_scanner, 'Scanning', () {
                    _scanImage();
                  }),
                ],
              ),
            ),
          ),
          // Amount Display and Compact Keyboard Section
          Container(
            color: const Color(0xFFB0E0E6),
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Amount Display
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF90EE90),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _amountText,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 6),
                // Compact Numeric Keyboard
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF90EE90),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      // Row 1: 7, 8, 9, C
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildCompactKeyboardButton('7'),
                          _buildCompactKeyboardButton('8'),
                          _buildCompactKeyboardButton('9'),
                          _buildCompactKeyboardButton('C'),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Row 2: 4, 5, 6, *
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildCompactKeyboardButton('4'),
                          _buildCompactKeyboardButton('5'),
                          _buildCompactKeyboardButton('6'),
                          _buildCompactKeyboardButton('*'),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Row 3: 1, 2, 3, +
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildCompactKeyboardButton('1'),
                          _buildCompactKeyboardButton('2'),
                          _buildCompactKeyboardButton('3'),
                          _buildCompactKeyboardButton('+'),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Row 4: 0, ., <, ✓
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildCompactKeyboardButton('0', flex: 2),
                          _buildCompactKeyboardButton('.'),
                          _buildCompactKeyboardButton('<'),
                          _buildCompactKeyboardButton('✓'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3CD),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.black, size: 24),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteButton() {
    final hasNote = _noteController.text.isNotEmpty;
    final displayText = hasNote
        ? (_noteController.text.length > 15
              ? '${_noteController.text.substring(0, 15)}...'
              : _noteController.text)
        : 'Notes';

    return GestureDetector(
      onTap: () {
        _showNotesDialog();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 50,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3CD),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Icon(Icons.note, color: Colors.black, size: 24),
                  ),
                  if (_noteController.text.isNotEmpty)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 60,
              child: Text(
                displayText,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransferAccountSelection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // From Account Section
          const Text(
            'From Account',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _accounts.map((account) {
                final isSelected =
                    _selectedFromAccountId == account['accountId'];
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedFromAccountId = account['accountId'];
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF90EE90)
                          : Colors.white,
                      border: Border.all(
                        color: isSelected ? Colors.black : Colors.grey[300]!,
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: const Color(0xFFB0E0E6),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child:
                              account['iconImage'] != null &&
                                  account['iconImage'].toString().isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.network(
                                    account['iconImage'],
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Icon(
                                        Icons.account_balance_wallet,
                                        color: Colors.grey[600],
                                        size: 16,
                                      );
                                    },
                                  ),
                                )
                              : Icon(
                                  Icons.account_balance_wallet,
                                  color: Colors.grey[600],
                                  size: 16,
                                ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          account['accountName'] ?? 'Unknown',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),
          // To Account Section
          const Text(
            'To Account',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _accounts.map((account) {
                final isSelected = _selectedToAccountId == account['accountId'];
                final isFromAccount =
                    _selectedFromAccountId == account['accountId'];
                return GestureDetector(
                  onTap: isFromAccount
                      ? null
                      : () {
                          setState(() {
                            _selectedToAccountId = account['accountId'];
                          });
                        },
                  child: Opacity(
                    opacity: isFromAccount ? 0.5 : 1.0,
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFA7E399)
                            : Colors.white,
                        border: Border.all(
                          color: isSelected ? Colors.black : Colors.grey[300]!,
                          width: isSelected ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFFB0E0E6),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child:
                                account['iconImage'] != null &&
                                    account['iconImage'].toString().isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Image.network(
                                      account['iconImage'],
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                            return Icon(
                                              Icons.account_balance_wallet,
                                              color: Colors.grey[600],
                                              size: 16,
                                            );
                                          },
                                    ),
                                  )
                                : Icon(
                                    Icons.account_balance_wallet,
                                    color: Colors.grey[600],
                                    size: 16,
                                  ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            account['accountName'] ?? 'Unknown',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateButton() {
    final isToday =
        _selectedDate.year == DateTime.now().year &&
        _selectedDate.month == DateTime.now().month &&
        _selectedDate.day == DateTime.now().day;

    return GestureDetector(
      onTap: () {
        _selectDate();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 50,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3CD),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Icon(
                  Icons.calendar_today,
                  color: Colors.black,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isToday ? 'Today' : '${_selectedDate.day}/${_selectedDate.month}',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageButton() {
    return GestureDetector(
      onTap: () {
        _pickImage();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 50,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3CD),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _selectedImage != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.file(
                        File(_selectedImage!.path),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(Icons.image, color: Colors.black);
                        },
                      ),
                    )
                  : Icon(Icons.image, color: Colors.black, size: 24),
            ),
            const SizedBox(height: 4),
            Text(
              'Image',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountButton() {
    return GestureDetector(
      onTap: () {
        _showAccountDialog();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 50,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3CD),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _selectedAccount != null
                  ? (_selectedAccount!['iconImage'] != null &&
                            _selectedAccount!['iconImage'].toString().isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.network(
                              _selectedAccount!['iconImage'],
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  Icons.account_balance_wallet,
                                  color: Colors.black,
                                );
                              },
                            ),
                          )
                        : Icon(
                            Icons.account_balance_wallet,
                            color: Colors.black,
                          ))
                  : Icon(Icons.account_balance_wallet, color: Colors.black),
            ),
            const SizedBox(height: 4),
            Text(
              _selectedAccount != null
                  ? (_selectedAccount!['accountName'] ?? 'Account').split(
                      ' ',
                    )[0]
                  : 'Account',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactKeyboardButton(String label, {int flex = 1}) {
    bool isSpecial =
        label == 'C' ||
        label == '<' ||
        label == '✓' ||
        label == '.' ||
        label == '+' ||
        label == '*';

    return Expanded(
      flex: flex,
      child: GestureDetector(
        onTap: () => _handleNumberInput(label),
        child: Container(
          height: 34,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: Colors.grey[300] ?? Colors.grey,
              width: 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isSpecial && label != '✓'
                    ? const Color(0xFF90EE90)
                    : Colors.black,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showNotesDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFFF9E6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          contentPadding: const EdgeInsets.all(24),
          title: const Text(
            'Add Note',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFFF39C12),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _noteController,
                decoration: const InputDecoration(
                  hintText: 'e.g., Breakfast bread RM2.80',
                  hintStyle: TextStyle(color: Color(0xFF999999), fontSize: 12),
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Color(0xFFF39C12)),
              ),
            ),
            TextButton(
              onPressed: () {
                // Text is already saved in _noteController via controller property
                print('✓ Note saved: "${_noteController.text}"');
                Navigator.pop(context);
              },
              child: const Text(
                'Save',
                style: TextStyle(color: Color(0xFFA7E399)),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showAccountDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFFF9E6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          contentPadding: const EdgeInsets.all(24),
          title: const Text(
            'Account',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFFF39C12),
            ),
          ),
          content: SingleChildScrollView(
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _accounts.map((account) {
                final isSelected = _selectedAccountId == account['accountId'];
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedAccountId = account['accountId'];
                      _selectedAccount = account;
                    });
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: 140,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFA7E399)
                          : Colors.white,
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFF39C12)
                            : Colors.grey[300]!,
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Account Logo
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFFB0E0E6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child:
                              account['iconImage'] != null &&
                                  account['iconImage'].toString().isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    account['iconImage'],
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Icon(
                                        Icons.account_balance_wallet,
                                        color: Colors.grey[600],
                                        size: 24,
                                      );
                                    },
                                  ),
                                )
                              : Icon(
                                  Icons.account_balance_wallet,
                                  color: Colors.grey[600],
                                  size: 24,
                                ),
                        ),
                        const SizedBox(height: 8),
                        // Account Name
                        Text(
                          account['accountName'] ?? 'Unknown',
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Account Balance
                        Text(
                          'RM${account['balance']?.toString() ?? '0.00'}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  // Method to refund/reverse a transfer
  Future<void> refundTransfer(String transferId) async {
    try {
      // Fetch the transfer record
      final transferData = await Supabase.instance.client
          .from('Transfer')
          .select()
          .eq('transferId', transferId)
          .single();

      final fromAccountId = transferData['fromAccountId'];
      final toAccountId = transferData['toAccountId'];
      final amount = transferData['amount'];

      // Reverse the transfer: add amount back to source, deduct from destination
      if (fromAccountId != null) {
        final fromAccount = _accounts.firstWhereOrNull(
          (acc) => acc['accountId'] == fromAccountId,
        );
        final fromBalance = fromAccount?['balance'] ?? 0.0;
        final newFromBalance = fromBalance + amount; // Add back

        await Supabase.instance.client
            .from('Account')
            .update({'balance': newFromBalance})
            .eq('accountId', fromAccountId);
      }

      if (toAccountId != null) {
        final toAccount = _accounts.firstWhereOrNull(
          (acc) => acc['accountId'] == toAccountId,
        );
        final toBalance = toAccount?['balance'] ?? 0.0;
        final newToBalance = toBalance - amount; // Deduct

        await Supabase.instance.client
            .from('Account')
            .update({'balance': newToBalance})
            .eq('accountId', toAccountId);
      }

      // Delete the transfer record
      await Supabase.instance.client
          .from('Transfer')
          .delete()
          .eq('transferId', transferId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transfer refunded successfully')),
      );
    } catch (e) {
      print('Error refunding transfer: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error refunding transfer: $e')));
    }
  }
}
