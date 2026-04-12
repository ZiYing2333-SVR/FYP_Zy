import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:collection/collection.dart';
import 'dart:io';
import '../services/budget_alert_service.dart';
import '../services/alert_status_service.dart';

import '../Challenge/challenge_tracking_service.dart';
import '../Missions/mission_service.dart';
import '../OCR/models.dart';
import '../OCR/receipt_error_dialog.dart';
import '../OCR/receipt_ocr_service.dart';

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
  String? _currentOperation; // Tracks + or *
  double _previousNumber = 0;
  bool _isNewNumber = true; // Flag to track if we're starting a new number
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

  /// Update budget alert flags ONLY for budgets related to this transaction
  /// This prevents showing alerts for unrelated budget categories
  /// ALSO notify AlertStatusService to update bottom bar and settings page badges
  Future<void> _updateBudgetAlertFlags() async {
    try {
      final categoryId = _selectedCategory?['categoryId'];
      final accountId = _selectedAccountId;
      final ledgerId = widget.ledgerId;

      print(
        '[AddTransaction] Updating budgets for: categoryId=$categoryId, accountId=$accountId, ledgerId=$ledgerId',
      );

      // Get ALL budgets for this user first
      final allBudgets = await Supabase.instance.client
          .from('Budget')
          .select()
          .eq('userId', widget.userId);

      if (allBudgets.isEmpty) {
        print('[AddTransaction] No budgets found for this user');
        return;
      }

      // Filter to ONLY include budgets that are actually related to this transaction
      final relatedBudgets = <Map<String, dynamic>>[];
      for (var budget in allBudgets) {
        final budgetType = budget['type'] ?? '';
        bool isRelated = false;

        // Check if budget is related based on its type
        if (budgetType == 'category') {
          // Category budget: only include if expense has matching categoryId
          isRelated = budget['categoryId'] == categoryId && categoryId != null;
        } else if (budgetType == 'ledger') {
          // Ledger budget: only include if expense has matching ledgerId
          isRelated = budget['ledgerId'] == ledgerId && ledgerId != null;
        } else if (budgetType == 'account') {
          // Account budget: only include if expense has matching accountId
          isRelated = budget['accountId'] == accountId && accountId != null;
        }

        if (isRelated) {
          relatedBudgets.add(budget);
          print(
            '[AddTransaction] Budget ${budget['budgetId']} ($budgetType) is related to this expense',
          );
        }
      }

      if (relatedBudgets.isEmpty) {
        print(
          '[AddTransaction] No related budgets found for this expense - no alert',
        );
        return;
      }

      print('[AddTransaction] Found ${relatedBudgets.length} related budgets');

      final alertService = BudgetAlertService();
      bool hasCautionAlert = false;
      bool hasExceedAlert = false;

      // Check each related budget and update flags
      for (var budget in relatedBudgets) {
        final budgetId = budget['budgetId'];
        final budgetType = budget['type'] ?? '';
        final budgetAmount = (budget['amount'] ?? 0).toDouble();
        final cycleType = (budget['cycleType'] ?? 'month').toLowerCase();

        if (budgetAmount <= 0) continue;

        // Calculate date range based on cycle type
        final now = DateTime.now();
        final DateTime startDate;

        switch (cycleType) {
          case 'day':
            startDate = DateTime(now.year, now.month, now.day);
            break;
          case 'week':
            startDate = now.subtract(Duration(days: now.weekday - 1));
            break;
          case 'month':
            startDate = DateTime(now.year, now.month, 1);
            break;
          case 'year':
            startDate = DateTime(now.year, 1, 1);
            break;
          default:
            startDate = DateTime(now.year, now.month, 1);
        }

        // Fetch transactions for this specific budget based on its type
        List<dynamic> transactions = [];

        if (budgetType == 'account') {
          final budgetAccountId = budget['accountId'];
          transactions = await Supabase.instance.client
              .from('Transaction')
              .select()
              .eq('accountId', budgetAccountId)
              .eq('type', 'expense')
              .gte('date', startDate.toIso8601String());
        } else if (budgetType == 'category') {
          final budgetCategoryId = budget['categoryId'];
          transactions = await Supabase.instance.client
              .from('Transaction')
              .select()
              .eq('categoryId', budgetCategoryId)
              .eq('type', 'expense')
              .gte('date', startDate.toIso8601String());
        } else if (budgetType == 'ledger') {
          final budgetLedgerId = budget['ledgerId'];
          transactions = await Supabase.instance.client
              .from('Transaction')
              .select()
              .eq('ledgerId', budgetLedgerId)
              .eq('type', 'expense')
              .gte('date', startDate.toIso8601String());
        }

        // Calculate total spent
        double totalSpent = 0;
        for (var transaction in transactions) {
          final amount = ((transaction['amount'] ?? 0) as num).toDouble();
          final isRefund = transaction['refund'] == true;

          if (isRefund) {
            totalSpent -= amount;
          } else {
            totalSpent += amount;
          }
        }

        totalSpent = totalSpent < 0 ? 0 : totalSpent;
        final usagePercentage = (totalSpent / budgetAmount) * 100;

        print(
          '[AddTransaction] Related Budget $budgetId ($budgetType): $totalSpent / $budgetAmount = ${usagePercentage.toStringAsFixed(1)}%',
        );

        // Update alert flags using the service
        await alertService.updateAlertFlags(budgetId, usagePercentage);

        // Track if we have caution or exceed alerts
        if (usagePercentage >= 100) {
          hasExceedAlert = true;
        } else if (usagePercentage >= 70) {
          hasCautionAlert = true;
        }
      }

      print('[AddTransaction] Budget alert flags updated for related budgets');
      print(
        '[AddTransaction] Alert status summary - Caution: $hasCautionAlert, Exceed: $hasExceedAlert',
      );

      // ✅ Broadcast real-time updates to all pages (bottom bar, settings page) via AlertStatusService
      AlertStatusService().updateCautionAlertStatus(hasCautionAlert);
      AlertStatusService().updateHighRiskAlertStatus(hasExceedAlert);

      print('[AddTransaction] AlertStatusService notified of alert changes');
    } catch (e) {
      print('Error updating budget alert flags: $e');
    }
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
      _showErrorDialog('Error loading categories: $e');
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
      _showErrorDialog('Error picking image: $e');
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
      _showErrorDialog('Error scanning image: $e');
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
        _currentOperation = null;
        _previousNumber = 0;
        _isNewNumber = true;
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
      } else if (value == '+' || value == '*') {
        // Handle operation: + or *
        final currentNum = double.tryParse(_amountText) ?? 0;

        // If there was a previous operation, calculate the result first
        if (_currentOperation != null) {
          final result = _calculateResult(
            _previousNumber,
            currentNum,
            _currentOperation!,
          );
          _amountText = _formatNumber(result);
          _previousNumber = result;
        } else {
          _previousNumber = currentNum;
        }

        _currentOperation = value;
        _isNewNumber = true;
      } else if (value == '✓') {
        // Complete the operation if there's a pending one
        if (_currentOperation != null) {
          final currentNum = double.tryParse(_amountText) ?? 0;
          final result = _calculateResult(
            _previousNumber,
            currentNum,
            _currentOperation!,
          );
          _amountText = _formatNumber(result);
          _currentOperation = null;
          _previousNumber = 0;
          _isNewNumber = true;
        }
        // Save transaction
        _saveTransaction();
        return;
      } else {
        // Regular number input
        if (_isNewNumber) {
          _amountText = value;
          _isNewNumber = false;
        } else {
          if (_amountText == '0' && value != '.') {
            _amountText = value;
          } else {
            _amountText += value;
          }
        }
      }
    });
  }

  double _calculateResult(double num1, double num2, String operation) {
    if (operation == '+') {
      return num1 + num2;
    } else if (operation == '*') {
      return num1 * num2;
    }
    return num2;
  }

  String _formatNumber(double num) {
    // Format the number, remove unnecessary trailing zeros and decimal point
    final result = num.toStringAsFixed(2);
    final formatted = double.parse(result).toString();
    // If result is a whole number, return without decimal
    if (formatted.endsWith('.0')) {
      return formatted.substring(0, formatted.length - 2);
    }
    return formatted;
  }

  /// Show styled error dialog with error colors (red theme)
  void _showErrorDialog(String message) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: true,
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
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFFFCDD2),
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Color(0xFFE53935),
                    size: 32,
                  ),
                ),
                const SizedBox(height: 20),
                // Error title
                const Text(
                  'Validation Error',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE53935),
                  ),
                ),
                const SizedBox(height: 12),
                // Error message
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF666666),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                // Got it button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE53935),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    child: const Text('Got it'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveTransaction() async {
    // Original single transaction logic
    // Validate based on transaction type
    if (_selectedType == 'transfer') {
      if (_selectedFromAccountId == null) {
        _showErrorDialog('Please select a from account');
        return;
      }

      if (_selectedToAccountId == null) {
        _showErrorDialog('Please select a to account');
        return;
      }

      if (_selectedFromAccountId == _selectedToAccountId) {
        _showErrorDialog('From and To accounts cannot be the same');
        return;
      }
    } else {
      if (_selectedCategory == null) {
        _showErrorDialog('Please select a category');
        return;
      }

      if (_selectedAccountId == null) {
        _showErrorDialog('Please select an account');
        return;
      }
    }

    if (_amountText == '0' || _amountText.isEmpty) {
      _showErrorDialog('Please enter an amount');
      return;
    }

    // Show preview dialog
    _showPreviewDialog();
  }

  Future<void> _showPreviewDialog() async {
    // Get from/to account details for transfer
    Map<String, dynamic>? fromAccount;
    Map<String, dynamic>? toAccount;
    String categoryName = '';
    String accountName = '';

    if (_selectedType == 'transfer') {
      fromAccount = _accounts.firstWhereOrNull(
        (acc) => acc['accountId'] == _selectedFromAccountId,
      );
      toAccount = _accounts.firstWhereOrNull(
        (acc) => acc['accountId'] == _selectedToAccountId,
      );
    } else {
      categoryName = _selectedCategory!['name'] ?? '';
      accountName = _selectedAccount!['accountName'] ?? '';
    }

    showDialog(
      context: context,
      builder: (context) {
        return _TransactionTicketDialog(
          selectedType: _selectedType,
          amount: _amountText,
          selectedDate: _selectedDate,
          categoryName: categoryName,
          accountName: accountName,
          fromAccountName: fromAccount?['accountName'] ?? 'Unknown',
          toAccountName: toAccount?['accountName'] ?? 'Unknown',
          noteText: _noteController.text,
          selectedImage: _selectedImage,
          onConfirm: () {
            Navigator.pop(context);
            _confirmSaveTransaction();
          },
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
        // Use timestamp-based ID to prevent race condition duplicates
        // ✅ Millisecond precision ensures uniqueness even with concurrent requests
        final transferId =
            'TRANSFER${widget.userId}${DateTime.now().millisecondsSinceEpoch}';

        // Save transfer record to Transfer table
        await Supabase.instance.client.from('Transfer').insert({
          'transferId': transferId,
          'fromAccountId': _selectedFromAccountId,
          'toAccountId': _selectedToAccountId,
          'amount': amount,
          'date': _selectedDate.toIso8601String(),
          'note': _noteController.text,
          'noteImage': imageUrl,
          'ledgerId': widget.ledgerId,
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
        // Generate transaction ID using UUID to prevent race condition duplicates
        // ✅ UUID ensures globally unique IDs even with concurrent requests
        final transactionId =
            'TRANS${widget.userId}${DateTime.now().millisecondsSinceEpoch}';

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

      // Update budget alert flags if this is an expense transaction
      if (_selectedType == 'expense') {
        await _updateBudgetAlertFlags();
      }

      /// ✅ Mark LogExpense mission complete
      await MissionService.completeMission(
        userId: widget.userId,
        missionId: 'M003',
      );

      /// ✅ Recalculate preset challenge progress
      await ChallengeTrackingService().updateUserChallenges(widget.userId);

      if (mounted) {
        // Show success dialog - keep AddTransaction screen open until user confirms
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
                    Text(
                      _selectedType == 'transfer'
                          ? 'Transfer Successful!'
                          : '${_selectedType == 'expense' ? 'Expense' : 'Income'} Added Successfully!',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFF39C12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Success message
                    Text(
                      _selectedType == 'transfer'
                          ? 'RM${amount.toStringAsFixed(2)} has been transferred successfully.'
                          : 'RM${amount.toStringAsFixed(2)} has been recorded successfully.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
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
                          ); // Close AddTransaction and return to home
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
      }
    } catch (e) {
      print('Error saving transaction: $e');
      if (mounted) {
        _showErrorDialog('Error saving transaction: $e');
      }
    }
  }

  Future<void> _handleScanReceipt() async {
    try {
      final picker = ImagePicker();

      final image = await showModalBottomSheet<XFile?>(
        context: context,
        builder: (context) {
          return SafeArea(
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text('Take Photo'),
                  onTap: () async {
                    final img = await picker.pickImage(
                      source: ImageSource.camera,
                    );
                    Navigator.pop(context, img);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Choose from Gallery'),
                  onTap: () async {
                    final img = await picker.pickImage(
                      source: ImageSource.gallery,
                    );
                    Navigator.pop(context, img);
                  },
                ),
              ],
            ),
          );
        },
      );

      if (image == null) return;

      /// SAVE IMAGE FOR UPLOAD
      setState(() {
        _selectedImage = image;
      });

      /// OCR
      final parsed = await ReceiptOCRService.extract(image);

      _applyParsedReceipt(parsed);

      /// AUTO FILL UI
      _applyParsedReceipt(parsed);
    } catch (e) {
      print("Scan Error: $e");
      if (!mounted) return;
      _showScanError();
    }
  }

  void _applyParsedReceipt(ParsedReceipt parsed) {
    setState(() {
      /// 1️⃣ Amount
      _amountText = parsed.amount;

      /// 2️⃣ Date
      if (parsed.date != null) {
        try {
          if (parsed.date!.contains('-')) {
            _selectedDate = DateTime.parse(parsed.date!); // yyyy-MM-dd
          } else {
            _selectedDate = DateFormat('dd/MM/yyyy').parse(parsed.date!);
          }
        } catch (_) {}
      }

      /// 3️⃣ Category (IMPORTANT 🔥)
      final categories = _selectedType == 'expense'
          ? expenseCategories
          : incomeCategories;

      if (parsed.categoryId != null) {
        final categories = _selectedType == 'expense'
            ? expenseCategories
            : incomeCategories;

        final match = categories.firstWhere(
          (c) => c['categoryId'] == parsed.categoryId,
          orElse: () => {},
        );

        if (match.isNotEmpty) {
          _selectedCategory = match;
        }
      }
    });
  }

  void _showScanError() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ReceiptErrorDialog(
        onRetry: () {
          _handleScanReceipt();
        },
      ),
    );
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
                          ? const Color(0xFF90EE90)
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
                            childAspectRatio: 0.85,
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
                                      : const Color(0xFFFFF9E6),
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
                              const SizedBox(height: 6),
                              Flexible(
                                child: SizedBox(
                                  width: 70,
                                  child: Text(
                                    category['name'] ?? 'Unknown',
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
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
                  _buildIconButton(Icons.qr_code_scanner, 'Scan', () {
                    _handleScanReceipt();
                  }),
                ],
              ),
            ),
          ),
          // Amount Display and Compact Keyboard Section
          Flexible(
            child: SingleChildScrollView(
              child: Container(
                color: const Color(0xFFFFF9E6),
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
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // From Account Field
            const Text(
              'From Account',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => _showAccountPickerModal(
                'Select From Account',
                'from',
                _selectedFromAccountId,
                (accountId) {
                  setState(() {
                    _selectedFromAccountId = accountId;
                  });
                  Navigator.pop(context);
                },
              ),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _selectedFromAccountId != null
                        ? Colors.green.shade300
                        : Colors.grey.shade300,
                    width: _selectedFromAccountId != null ? 2 : 1,
                  ),
                  boxShadow: _selectedFromAccountId != null
                      ? [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.1),
                            blurRadius: 8,
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  children: [
                    if (_selectedFromAccountId != null) ...[
                      ..._buildAccountDisplayItem(
                        _accounts.firstWhere(
                          (acc) => acc['accountId'] == _selectedFromAccountId,
                          orElse: () => {},
                        ),
                      ),
                    ] else
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tap to select',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const Spacer(),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Colors.grey.shade400,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // To Account Field
            const Text(
              'To Account',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => _showAccountPickerModal(
                'Select To Account',
                'to',
                _selectedToAccountId,
                (accountId) {
                  setState(() {
                    _selectedToAccountId = accountId;
                  });
                  Navigator.pop(context);
                },
              ),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _selectedToAccountId != null
                        ? Colors.green.shade300
                        : Colors.grey.shade300,
                    width: _selectedToAccountId != null ? 2 : 1,
                  ),
                  boxShadow: _selectedToAccountId != null
                      ? [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.1),
                            blurRadius: 8,
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  children: [
                    if (_selectedToAccountId != null) ...[
                      ..._buildAccountDisplayItem(
                        _accounts.firstWhere(
                          (acc) => acc['accountId'] == _selectedToAccountId,
                          orElse: () => {},
                        ),
                      ),
                    ] else
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tap to select',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const Spacer(),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Colors.grey.shade400,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildAccountDisplayItem(Map<String, dynamic> account) {
    if (account.isEmpty) return [];

    return [
      Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFFFFF9E6),
          borderRadius: BorderRadius.circular(8),
        ),
        child:
            account['iconImage'] != null &&
                account['iconImage'].toString().isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  account['iconImage'],
                  fit: BoxFit.contain,
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
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              account['accountName'] ?? 'Unknown',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              account['hideBalanceStatus'] == false
                  ? 'RM${account['balance']?.toStringAsFixed(2) ?? '0.00'}'
                  : '*****',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    ];
  }

  void _showAccountPickerModal(
    String title,
    String type,
    String? selectedAccountId,
    Function(String) onSelect,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.4,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFFFFF9E6),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Account Cards Grid
              Expanded(
                child: _accounts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.account_balance_wallet,
                              size: 48,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No accounts available',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 2.0,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                        itemCount: _accounts.length,
                        itemBuilder: (context, index) {
                          final account = _accounts[index];
                          final accountId = account['accountId'] as String;
                          final isSelected = accountId == selectedAccountId;
                          final isFromAccount =
                              type == 'to' &&
                              accountId == _selectedFromAccountId;

                          return GestureDetector(
                            onTap: isFromAccount
                                ? null
                                : () => onSelect(accountId),
                            child: Opacity(
                              opacity: isFromAccount ? 0.5 : 1.0,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFFA7E399)
                                      : (isFromAccount
                                            ? Colors.grey.shade100
                                            : const Color(0xFFFFF9E6)),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFFF39C12)
                                        : (isFromAccount
                                              ? Colors.grey.shade400
                                              : const Color(0xFFFFE5B4)),
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                padding: const EdgeInsets.all(10),
                                child: Row(
                                  children: [
                                    // Account Icon
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFF9E6),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child:
                                          account['iconImage'] != null &&
                                              account['iconImage']
                                                  .toString()
                                                  .isNotEmpty
                                          ? ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: Image.network(
                                                account['iconImage'],
                                                fit: BoxFit.contain,
                                                errorBuilder:
                                                    (
                                                      context,
                                                      error,
                                                      stackTrace,
                                                    ) {
                                                      return Icon(
                                                        Icons
                                                            .account_balance_wallet,
                                                        color: Colors.grey[600],
                                                        size: 20,
                                                      );
                                                    },
                                              ),
                                            )
                                          : Icon(
                                              Icons.account_balance_wallet,
                                              color: Colors.grey[600],
                                              size: 20,
                                            ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Account Details
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          // Account Name
                                          Text(
                                            account['accountName'] ?? 'Unknown',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          // Account Balance
                                          Text(
                                            account['hideBalanceStatus'] ==
                                                    false
                                                ? 'RM${account['balance']?.toStringAsFixed(2) ?? '0.00'}'
                                                : '*****',
                                            style: TextStyle(
                                              fontSize: 9,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Check mark for selected
                                    if (isSelected) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        width: 20,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          color: Colors.green,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.check,
                                          color: Colors.white,
                                          size: 12,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
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
                              fit: BoxFit.contain,
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
        return Dialog(
          backgroundColor: const Color(0xFFFFF9E6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Add Note',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFF39C12),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _noteController,
                    decoration: const InputDecoration(
                      hintText: 'e.g., Breakfast bread RM2.80',
                      hintStyle: TextStyle(
                        color: Color(0xFF999999),
                        fontSize: 12,
                      ),
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 4,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: Color(0xFFF39C12)),
                        ),
                      ),
                      const SizedBox(width: 12),
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
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showAccountDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.4,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFFFFF9E6),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Select Account',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Account Cards Grid
              Expanded(
                child: _accounts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.account_balance_wallet,
                              size: 48,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No accounts available',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 2.0,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                        itemCount: _accounts.length,
                        itemBuilder: (context, index) {
                          final account = _accounts[index];
                          final accountId = account['accountId'] as String;
                          final isSelected = accountId == _selectedAccountId;
                          final isSavingsAccount =
                              account['accountType'] == 'Savings';

                          return GestureDetector(
                            onTap: isSavingsAccount
                                ? null
                                : () {
                                    setState(() {
                                      _selectedAccountId = accountId;
                                      _selectedAccount = account;
                                    });
                                    Navigator.pop(context);
                                  },
                            child: Opacity(
                              opacity: isSavingsAccount ? 0.5 : 1.0,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFFA7E399)
                                      : (isSavingsAccount
                                            ? Colors.grey.shade100
                                            : const Color(0xFFFFF9E6)),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFFF39C12)
                                        : (isSavingsAccount
                                              ? Colors.grey.shade400
                                              : const Color(0xFFFFE5B4)),
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                padding: const EdgeInsets.all(10),
                                child: Row(
                                  children: [
                                    // Account Icon
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFF9E6),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child:
                                          account['iconImage'] != null &&
                                              account['iconImage']
                                                  .toString()
                                                  .isNotEmpty
                                          ? ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: Image.network(
                                                account['iconImage'],
                                                fit: BoxFit.contain,
                                                errorBuilder:
                                                    (
                                                      context,
                                                      error,
                                                      stackTrace,
                                                    ) {
                                                      return Icon(
                                                        Icons
                                                            .account_balance_wallet,
                                                        color: Colors.grey[600],
                                                        size: 20,
                                                      );
                                                    },
                                              ),
                                            )
                                          : Icon(
                                              Icons.account_balance_wallet,
                                              color: Colors.grey[600],
                                              size: 20,
                                            ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Account Details
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            account['accountName'] ?? 'Unknown',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            account['hideBalanceStatus'] ==
                                                    false
                                                ? 'RM${account['balance']?.toStringAsFixed(2) ?? '0.00'}'
                                                : '*****',
                                            style: TextStyle(
                                              fontSize: 9,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Check mark for selected
                                    if (isSelected) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        width: 20,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          color: Colors.green,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.check,
                                          color: Colors.white,
                                          size: 12,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
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

// Ticket-shaped transaction preview dialog with animation
class _TransactionTicketDialog extends StatefulWidget {
  final String selectedType;
  final String amount;
  final DateTime selectedDate;
  final String categoryName;
  final String accountName;
  final String fromAccountName;
  final String toAccountName;
  final String noteText;
  final XFile? selectedImage;
  final VoidCallback onConfirm;

  const _TransactionTicketDialog({
    required this.selectedType,
    required this.amount,
    required this.selectedDate,
    required this.categoryName,
    required this.accountName,
    required this.fromAccountName,
    required this.toAccountName,
    required this.noteText,
    required this.selectedImage,
    required this.onConfirm,
  });

  @override
  State<_TransactionTicketDialog> createState() =>
      _TransactionTicketDialogState();
}

class _TransactionTicketDialogState extends State<_TransactionTicketDialog>
    with TickerProviderStateMixin {
  late AnimationController _checkmarkController;
  late Animation<double> _scaleAnimation;
  bool _isConfirmed = false;

  @override
  void initState() {
    super.initState();
    _checkmarkController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _checkmarkController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _checkmarkController.dispose();
    super.dispose();
  }

  void _handleConfirm() async {
    if (_isConfirmed) return;

    setState(() {
      _isConfirmed = true;
    });

    _checkmarkController.forward();

    await Future.delayed(const Duration(milliseconds: 1500));

    widget.onConfirm();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 8,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF9E6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFFE5B4), width: 2),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with checkmark animation
              Container(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    if (!_isConfirmed)
                      Text(
                        widget.selectedType.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFF39C12),
                        ),
                      )
                    else
                      ScaleTransition(
                        scale: _scaleAnimation,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFA7E399),
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 48,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Ticket body with dashed divider
              // Dashed divider
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: CustomPaint(
                  size: const Size(double.infinity, 2),
                  painter: DashedLinePainter(),
                ),
              ),

              // Transaction details
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow(
                      'Date',
                      widget.selectedDate.toLocal().toString().split(' ')[0],
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      'Time',
                      '${widget.selectedDate.hour.toString().padLeft(2, '0')}:${widget.selectedDate.minute.toString().padLeft(2, '0')}',
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      'Amount',
                      'RM${widget.amount}',
                      isHighlight: true,
                    ),
                    const SizedBox(height: 16),
                    // Dashed divider
                    CustomPaint(
                      size: const Size(double.infinity, 2),
                      painter: DashedLinePainter(),
                    ),
                    const SizedBox(height: 16),
                    if (widget.selectedType == 'transfer') ...[
                      _buildDetailRow('From', widget.fromAccountName),
                      const SizedBox(height: 12),
                      _buildDetailRow('To', widget.toAccountName),
                    ] else ...[
                      _buildDetailRow('Category', widget.categoryName),
                      const SizedBox(height: 12),
                      _buildDetailRow('Account', widget.accountName),
                    ],
                    if (widget.noteText.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      // Dashed divider
                      CustomPaint(
                        size: const Size(double.infinity, 2),
                        painter: DashedLinePainter(),
                      ),
                      const SizedBox(height: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Note',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFAA8866),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.noteText,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (widget.selectedImage != null) ...[
                      const SizedBox(height: 16),
                      // Dashed divider
                      CustomPaint(
                        size: const Size(double.infinity, 2),
                        painter: DashedLinePainter(),
                      ),
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(widget.selectedImage!.path),
                          height: 100,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 100,
                              color: Colors.grey[200],
                              child: const Icon(Icons.image),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Action buttons
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isConfirmed
                            ? null
                            : () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[300],
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isConfirmed ? null : _handleConfirm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFA7E399),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: _isConfirmed
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
                            : const Text(
                                'Confirm',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    bool isHighlight = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Color(0xFFAA8866),
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontSize: isHighlight ? 16 : 14,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
              color: isHighlight ? const Color(0xFFA7E399) : Colors.black87,
            ),
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// Custom painter for dashed lines
class DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFFE5B4)
      ..strokeWidth = 2;

    double x = 0;
    final dashWidth = 8;
    final dashSpace = 4;

    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + dashWidth, 0), paint);
      x += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(DashedLinePainter oldDelegate) => false;
}
