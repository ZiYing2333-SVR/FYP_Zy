import 'package:flutter/material.dart';
import '../services/ai_service.dart';
import 'package:intl/intl.dart';
import 'home_screen.dart';

class AutoExpenseConfirmation extends StatefulWidget {
  final String userId;
  final String? ledgerId;
  final String note;
  final Map<String, dynamic> aiResult;
  final List<Map<String, dynamic>> allCategories;

  const AutoExpenseConfirmation({
    super.key,
    required this.userId,
    this.ledgerId,
    required this.note,
    required this.aiResult,
    required this.allCategories,
  });

  @override
  State<AutoExpenseConfirmation> createState() =>
      _AutoExpenseConfirmationState();
}

class _AutoExpenseConfirmationState extends State<AutoExpenseConfirmation> {
  late String _selectedCategoryId;
  late String _selectedCategoryName;
  late double _selectedCategoryConfidence;
  late String _selectedAccountId;
  late String _transactionType;
  late double _amount;
  late DateTime _selectedDate;
  late TextEditingController _noteController;
  late String _currencySymbol;

  List<Map<String, dynamic>> _categoryScores = [];
  List<Map<String, dynamic>> _accounts = [];
  bool _isLoadingAccounts = true;
  bool _isSaving = false;

  /// Extract item description from note (removes amount part)
  /// Example: "breakfast bread 2.80" -> "breakfast bread"
  String _extractItemDescription(String note) {
    // Remove amount patterns: "RM2.80", "2.80", "RM 2.80", etc.
    String itemDescription = note
        .replaceAll(
          RegExp(r'\bRM\s*\d+(?:\.\d{1,2})?\b', caseSensitive: false),
          '',
        )
        .replaceAll(RegExp(r'\b\d+(?:\.\d{1,2})?\b'), '')
        .trim();
    return itemDescription.isNotEmpty ? itemDescription : note;
  }

  /// Helper function to parse hex color strings
  /// Handles both "#4CAF50" and "0xFF4CAF50" formats
  static Color _parseHexColor(String hexColor) {
    try {
      // Remove # if present
      String hex = hexColor.replaceFirst('#', '');

      // Pad with FF if not already present
      if (!hex.startsWith('0x') && !hex.startsWith('0X')) {
        hex = '0xFF$hex';
      }

      return Color(int.parse(hex));
    } catch (e) {
      // Return default color on error
      return const Color(0xFF000000);
    }
  }

  @override
  void initState() {
    super.initState();
    _transactionType = widget.aiResult['transactionType'] ?? 'expense';
    _amount = widget.aiResult['extractedAmount'] ?? 0.0;
    _selectedDate = DateTime.now();
    _selectedAccountId = '';
    _currencySymbol = 'RM';

    // Extract item description from the full note
    final itemDescription = _extractItemDescription(widget.note);
    _noteController = TextEditingController(text: itemDescription);

    // Parse category scores from AI result
    _parseAIResults();
    _fetchAccounts();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _parseAIResults() {
    // Get all category scores from AI result
    final allScores =
        widget.aiResult['allCategoryScores'] as List<dynamic>? ?? [];

    // Convert to mutable list with proper typing
    _categoryScores = allScores
        .map(
          (score) => {
            'category': score['category'] as String,
            'confidence': (score['confidence'] as num).toDouble(),
          },
        )
        .toList();

    // Sort by confidence descending
    _categoryScores.sort(
      (a, b) =>
          (b['confidence'] as double).compareTo(a['confidence'] as double),
    );

    // Select the top category (suggestion)
    if (_categoryScores.isNotEmpty) {
      _selectedCategoryName = _categoryScores[0]['category'] as String;
      _selectedCategoryConfidence = _categoryScores[0]['confidence'] as double;

      // Find category ID
      final categoryDetails = widget.allCategories.firstWhere(
        (cat) => (cat['name'] as String?) == _selectedCategoryName,
        orElse: () => <String, dynamic>{'categoryId': ''},
      );
      _selectedCategoryId = categoryDetails['categoryId'] as String? ?? '';
    } else {
      _selectedCategoryName = 'Others';
      _selectedCategoryConfidence = 0.0;
      _selectedCategoryId = '';
    }

    print(
      '📊 AI Result: Top category is "$_selectedCategoryName" with confidence ${(_selectedCategoryConfidence * 100).toStringAsFixed(1)}%',
    );
  }

  Future<void> _fetchAccounts() async {
    try {
      final accounts = await AIService.getAccounts(widget.userId);

      setState(() {
        _accounts = accounts;
        _isLoadingAccounts = false;

        // Auto-select first non-Savings account if available
        final nonSavingsAccounts = accounts
            .where((acc) => (acc['accountType'] as String?) != 'Savings')
            .toList();

        if (nonSavingsAccounts.isNotEmpty) {
          _selectedAccountId = nonSavingsAccounts[0]['accountId'] as String;

          // Set currency symbol from the default account
          final currencySymbol =
              (nonSavingsAccounts[0]['Currency'] as Map?)?['symbol'] as String?;
          if (currencySymbol != null && currencySymbol.isNotEmpty) {
            _currencySymbol = currencySymbol;
          }
        }
      });
    } catch (e) {
      print('Error fetching accounts: $e');
      setState(() => _isLoadingAccounts = false);
    }
  }

  void _showErrorDialog(String title, String message) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
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
                // Error icon
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.orange.withOpacity(0.2),
                  ),
                  child: const Icon(
                    Icons.warning,
                    color: Colors.orange,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 20),
                // Error title
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
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
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'OK',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
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
  }

  void _showAccountBottomSheet() {
    // Filter out Savings type accounts - display only
    print('📋 DEBUG: All _accounts (${_accounts.length}):');
    for (var acc in _accounts) {
      print('  - ${acc['accountName']} | accountType="${acc['accountType']}"');
    }

    final displayAccounts = _accounts
        .where((acc) => (acc['accountType'] as String?) != 'Savings')
        .toList();

    print(
      '📋 DEBUG: After filtering, displayAccounts (${displayAccounts.length}):',
    );
    for (var acc in displayAccounts) {
      print('  - ${acc['accountName']} | accountType="${acc['accountType']}"');
    }

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
                child: displayAccounts.isEmpty
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
                        itemCount: displayAccounts.length,
                        itemBuilder: (context, index) {
                          final account = displayAccounts[index];
                          final accountId = account['accountId'] as String;
                          final isSelected = accountId == _selectedAccountId;
                          final balance = account['balance'] as num?;
                          final hideBalance =
                              account['hideBalanceStatus'] as bool? ?? false;

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedAccountId = accountId;

                                // Update currency symbol when account changes
                                final currencySymbol =
                                    (account['Currency'] as Map?)?['symbol']
                                        as String?;
                                if (currencySymbol != null &&
                                    currencySymbol.isNotEmpty) {
                                  _currencySymbol = currencySymbol;
                                }
                              });
                              Navigator.pop(context);
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFFA7E399)
                                    : const Color(0xFFFFF9E6),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFFF39C12)
                                      : const Color(0xFFFFE5B4),
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
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            child: Image.network(
                                              AIService.getAccountIconUrl(
                                                account['iconImage'] as String,
                                              ),
                                              fit: BoxFit.contain,
                                              errorBuilder:
                                                  (context, error, stackTrace) {
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
                                          hideBalance
                                              ? '*****'
                                              : '${_currencySymbol}${balance?.toStringAsFixed(2) ?? '0.00'}',
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

  Future<void> _saveTransaction() async {
    if (_selectedAccountId.isEmpty) {
      _showErrorDialog(
        'No Account Selected',
        'Please select an account to save the transaction.',
      );
      return;
    }

    if (_amount <= 0) {
      _showErrorDialog(
        'Invalid Amount',
        'Please enter a valid amount greater than 0.',
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final success = await AIService.saveTransaction(
        accountId: _selectedAccountId,
        amount: _amount,
        type: _transactionType,
        transactionDate: _selectedDate,
        categoryId: _selectedCategoryId,
        note: _noteController.text,
        ledgerId: widget.ledgerId,
      );

      if (success) {
        if (mounted) {
          // Show success dialog with theme colors
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext dialogContext) {
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
                    border: Border.all(
                      color: const Color(0xFFFFE5B4),
                      width: 2,
                    ),
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
                        'Transaction Saved!',
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
                        'Your transaction has been successfully saved. You can now view it in your transaction history.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF666666),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(dialogContext); // Close dialog
                            // Clear the navigation stack and go back to HomeScreen
                            Navigator.of(context)
                              ..pop() // Close confirmation screen
                              ..pop() // Close categorization screen
                              ..pushReplacement(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      HomeScreen(userId: widget.userId),
                                ),
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
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('❌ Failed to save transaction')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isHighConfidence = _selectedCategoryConfidence >= 0.70;

    return Scaffold(
      backgroundColor: const Color(0xFFFEFFD3),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFEFFD3),
        elevation: 0,
        automaticallyImplyLeading: true,
        title: const Text(
          'Confirm Transaction',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
      body: _isLoadingAccounts
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // AI Confidence Indicator
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isHighConfidence
                          ? Colors.green.withOpacity(0.1)
                          : Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isHighConfidence
                            ? Colors.green.withOpacity(0.3)
                            : Colors.orange.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isHighConfidence ? Icons.check_circle : Icons.info,
                          color: isHighConfidence
                              ? Colors.green
                              : Colors.orange,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isHighConfidence
                                    ? 'High Confidence Match'
                                    : 'Low Confidence - Please Review',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isHighConfidence
                                      ? Colors.green[700]
                                      : Colors.orange[700],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${(_selectedCategoryConfidence * 100).toStringAsFixed(1)}% confidence',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Category Selection Section - Smart Display
                  const Text(
                    'Category',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSmartCategorySelector(),
                  const SizedBox(height: 24),

                  // Transaction Note Section (Editable)
                  const Text(
                    'Transaction Note',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.withOpacity(0.3)),
                    ),
                    child: TextField(
                      controller: _noteController,
                      decoration: InputDecoration(
                        hintText: 'Enter transaction description',
                        hintStyle: TextStyle(
                          color: Colors.black.withOpacity(0.5),
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(12),
                      ),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                      maxLines: 2,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Amount Section
                  const Text(
                    'Amount',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFA7E399),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            _currencySymbol,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              hintText: '0.00',
                              hintStyle: TextStyle(
                                color: Colors.black.withOpacity(0.5),
                                fontSize: 14,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 12,
                              ),
                            ),
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                            ),
                            onChanged: (value) {
                              setState(() {
                                _amount = double.tryParse(value) ?? 0.0;
                              });
                            },
                            controller: TextEditingController(
                              text: _amount > 0
                                  ? _amount.toStringAsFixed(2)
                                  : '',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Date Section
                  const Text(
                    'Date',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.withOpacity(0.3)),
                    ),
                    child: ListTile(
                      title: Text(
                        DateFormat('dd/MM/yyyy').format(_selectedDate),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black,
                        ),
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                          builder: (context, child) {
                            return Theme(
                              data: ThemeData.light().copyWith(
                                primaryColor: const Color(0xFFA7E399),
                                scaffoldBackgroundColor: const Color(
                                  0xFFFEFFD3,
                                ),
                                dialogBackgroundColor: const Color(0xFFFEFFD3),
                                colorScheme: const ColorScheme.light(
                                  primary: Color(0xFFA7E399),
                                  onPrimary: Colors.black,
                                  surface: Color(0xFFFEFFD3),
                                  onSurface: Colors.black87,
                                ),
                                textButtonTheme: TextButtonThemeData(
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFFA7E399),
                                  ),
                                ),
                              ),
                              child: child ?? Container(),
                            );
                          },
                        );
                        if (picked != null) {
                          setState(() => _selectedDate = picked);
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Account Selection Section
                  const Text(
                    'Account',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_accounts.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: const Text(
                        '❌ No accounts available. Please create an account first.',
                        style: TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    )
                  else
                    GestureDetector(
                      onTap: _showAccountBottomSheet,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.grey.withOpacity(0.3),
                          ),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            // Account Icon
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFFA7E399),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: _selectedAccountId.isNotEmpty
                                  ? (() {
                                      final account = _accounts.firstWhere(
                                        (acc) =>
                                            acc['accountId'] ==
                                            _selectedAccountId,
                                        orElse: () => <String, dynamic>{},
                                      );
                                      final iconImage =
                                          account['iconImage'] as String?;
                                      return iconImage != null &&
                                              iconImage.isNotEmpty
                                          ? ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: Image.network(
                                                AIService.getAccountIconUrl(
                                                  iconImage,
                                                ),
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
                                            );
                                    }())
                                  : Icon(
                                      Icons.account_balance_wallet,
                                      color: Colors.grey[600],
                                      size: 20,
                                    ),
                            ),
                            const SizedBox(width: 12),
                            // Account Details
                            Expanded(
                              child: _selectedAccountId.isNotEmpty
                                  ? (() {
                                      final account = _accounts.firstWhere(
                                        (acc) =>
                                            acc['accountId'] ==
                                            _selectedAccountId,
                                        orElse: () => <String, dynamic>{},
                                      );
                                      final hideBalance =
                                          account['hideBalanceStatus']
                                              as bool? ??
                                          false;
                                      return Column(
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
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            hideBalance
                                                ? '*****'
                                                : '$_currencySymbol${(account['balance'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      );
                                    }())
                                  : Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Text(
                                          'Select an account',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black,
                                          ),
                                        ),
                                        Text(
                                          'Choose account for transaction',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                            // Dropdown arrow
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 32),

                  // Confirm Button
                  Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFA7E399),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _isSaving ? null : _saveTransaction,
                      child: _isSaving
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
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  color: Colors.black,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Confirm & Save',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
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
  }

  Widget _buildCategoryCard(
    String categoryName,
    double confidence,
    bool isSelected,
  ) {
    // Find category details to get icon
    final categoryDetails = widget.allCategories.firstWhere(
      (cat) => (cat['name'] as String?) == categoryName,
      orElse: () => <String, dynamic>{'icon': null},
    );

    final iconPath = categoryDetails['icon'] as String?;
    final categoryIconUrl = iconPath != null && iconPath.isNotEmpty
        ? AIService.getCategoryIconUrl(iconPath)
        : null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFFA7E399).withOpacity(0.3)
            : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected
              ? const Color(0xFFA7E399)
              : Colors.grey.withOpacity(0.3),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          // Category icon from bucket
          if (categoryIconUrl != null && categoryIconUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                categoryIconUrl,
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: const Color(0xFFA7E399),
                    ),
                    child: const Icon(
                      Icons.category,
                      color: Colors.white,
                      size: 20,
                    ),
                  );
                },
              ),
            )
          else
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: const Color(0xFFA7E399),
              ),
              child: const Icon(Icons.category, color: Colors.white, size: 20),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  categoryName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${(confidence * 100).toStringAsFixed(1)}% match',
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                ),
              ],
            ),
          ),
          if (isSelected)
            Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Color(0xFFA7E399),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 16),
            ),
        ],
      ),
    );
  }

  Widget _buildSmartCategorySelector() {
    if (_categoryScores.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange.withOpacity(0.3)),
        ),
        child: const Text(
          '⚠️ No categories found.',
          style: TextStyle(color: Colors.orange, fontSize: 12),
        ),
      );
    }

    final topScore = _categoryScores.isNotEmpty
        ? (_categoryScores[0]['confidence'] as double)
        : 0.0;
    final hasHighConfidence = topScore >= 0.80;
    final topThree = _categoryScores.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: hasHighConfidence
                ? Colors.green.withOpacity(0.1)
                : Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: hasHighConfidence
                  ? Colors.green.withOpacity(0.3)
                  : Colors.orange.withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                hasHighConfidence ? Icons.check_circle : Icons.info,
                color: hasHighConfidence ? Colors.green : Colors.orange,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  hasHighConfidence
                      ? 'Strong Match (${(topScore * 100).toStringAsFixed(0)}%)'
                      : 'Weak Match (${(topScore * 100).toStringAsFixed(0)}%) - Choose below',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: hasHighConfidence
                        ? Colors.green[700]
                        : Colors.orange[700],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: topThree.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, index) {
            final category = topThree[index]['category'] as String;
            final confidence = topThree[index]['confidence'] as double;
            final isSelected = category == _selectedCategoryName;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedCategoryName = category;
                  _selectedCategoryConfidence = confidence;
                  final categoryDetails = widget.allCategories.firstWhere(
                    (cat) => (cat['name'] as String?) == category,
                    orElse: () => <String, dynamic>{'categoryId': ''},
                  );
                  _selectedCategoryId =
                      categoryDetails['categoryId'] as String? ?? '';
                });
              },
              child: _buildCategoryCard(category, confidence, isSelected),
            );
          },
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () => _showAllCategoriesDialog(),
          icon: const Icon(Icons.category),
          label: const Text('Browse All Categories'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            side: const BorderSide(color: Color(0xFFA7E399)),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }

  void _showAllCategoriesDialog() {
    // Separate categories by type
    final expenseCategories = widget.allCategories
        .where((cat) => (cat['type'] as String?) == 'expense')
        .toList();
    final incomeCategories = widget.allCategories
        .where((cat) => (cat['type'] as String?) == 'income')
        .toList();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFFFEFFD3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFA7E399),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: const Text(
                'All Categories',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  // Expense Categories Section
                  if (expenseCategories.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.shopping_cart,
                            color: Colors.orange,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Expense Categories',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...expenseCategories.map((category) {
                      final categoryName = category['name'] as String;
                      final categoryId = category['categoryId'] as String;
                      final iconPath = category['icon'] as String?;
                      final isSelected = categoryName == _selectedCategoryName;
                      final categoryIconUrl =
                          iconPath != null && iconPath.isNotEmpty
                          ? AIService.getCategoryIconUrl(iconPath)
                          : null;

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedCategoryName = categoryName;
                            _selectedCategoryId = categoryId;
                            _selectedCategoryConfidence = 0.0;
                          });
                          Navigator.pop(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFA7E399).withOpacity(0.3)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFFA7E399)
                                  : Colors.grey.withOpacity(0.2),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Category icon
                              if (categoryIconUrl != null &&
                                  categoryIconUrl.isNotEmpty)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.network(
                                    categoryIconUrl,
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          color: const Color(0xFFA7E399),
                                        ),
                                        child: const Icon(
                                          Icons.category,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      );
                                    },
                                  ),
                                )
                              else
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(6),
                                    color: const Color(0xFFA7E399),
                                  ),
                                  child: const Icon(
                                    Icons.category,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              const SizedBox(width: 12),
                              // Category name
                              Expanded(
                                child: Text(
                                  categoryName,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              // Checkmark for selected
                              if (isSelected)
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFA7E399),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                    const SizedBox(height: 8),
                  ],
                  // Income Categories Section
                  if (incomeCategories.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.trending_up,
                            color: const Color(0xFFA7E399),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Income Categories',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...incomeCategories.map((category) {
                      final categoryName = category['name'] as String;
                      final categoryId = category['categoryId'] as String;
                      final iconPath = category['icon'] as String?;
                      final isSelected = categoryName == _selectedCategoryName;
                      final categoryIconUrl =
                          iconPath != null && iconPath.isNotEmpty
                          ? AIService.getCategoryIconUrl(iconPath)
                          : null;

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedCategoryName = categoryName;
                            _selectedCategoryId = categoryId;
                            _selectedCategoryConfidence = 0.0;
                          });
                          Navigator.pop(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFA7E399).withOpacity(0.3)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFFA7E399)
                                  : Colors.grey.withOpacity(0.2),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Category icon
                              if (categoryIconUrl != null &&
                                  categoryIconUrl.isNotEmpty)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.network(
                                    categoryIconUrl,
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          color: const Color(0xFFA7E399),
                                        ),
                                        child: const Icon(
                                          Icons.category,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      );
                                    },
                                  ),
                                )
                              else
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(6),
                                    color: const Color(0xFFA7E399),
                                  ),
                                  child: const Icon(
                                    Icons.category,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              const SizedBox(width: 12),
                              // Category name
                              Expanded(
                                child: Text(
                                  categoryName,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              // Checkmark for selected
                              if (isSelected)
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFA7E399),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
