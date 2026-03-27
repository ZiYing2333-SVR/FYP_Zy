import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:collection/collection.dart';
import '../utils/transaction_parser.dart';
import '../services/ai_service.dart';
import 'home_screen.dart';

class ConfirmBulkTransactionsScreen extends StatefulWidget {
  final String userId;
  final String? ledgerId;
  final List<ParsedTransaction> parsedTransactions;
  final String selectedType;
  final String? selectedAccountId;
  final String? selectedFromAccountId;
  final String? selectedToAccountId;
  final List<Map<String, dynamic>> accounts;
  final List<Map<String, dynamic>> categories;

  const ConfirmBulkTransactionsScreen({
    Key? key,
    required this.userId,
    this.ledgerId,
    required this.parsedTransactions,
    required this.selectedType,
    this.selectedAccountId,
    this.selectedFromAccountId,
    this.selectedToAccountId,
    required this.accounts,
    required this.categories,
  }) : super(key: key);

  @override
  State<ConfirmBulkTransactionsScreen> createState() =>
      _ConfirmBulkTransactionsScreenState();
}

class _ConfirmBulkTransactionsScreenState
    extends State<ConfirmBulkTransactionsScreen> {
  late List<Map<String, dynamic>> _editableTransactions;
  int _currentIndex = 0;
  bool _isSaving = false;
  bool _isLoadingCategories = true;

  @override
  void initState() {
    super.initState();
    _initializeAndCategorizeTransactions();
  }

  Future<void> _initializeAndCategorizeTransactions() async {
    print(
      '\n📊 === INITIALIZING BULK TRANSACTIONS WITH AUTO-CATEGORIZATION ===',
    );
    print('Total transactions to process: ${widget.parsedTransactions.length}');

    // Convert ParsedTransaction to editable map format
    _editableTransactions = widget.parsedTransactions.map((t) {
      return {
        'originalNote': t.note,
        'note': t.note,
        'amount': t.amount,
        'categoryId': null,
        'categoryName': 'Select Category',
        'suggestedCategory': '',
        'confidence': 0.0,
        'date': DateTime.now(),
        'accountId': widget.selectedAccountId,
      };
    }).toList();

    // Auto-categorize each transaction
    for (int i = 0; i < _editableTransactions.length; i++) {
      final transaction = _editableTransactions[i];
      final note = transaction['note'] as String;

      print(
        '\n🔍 Analyzing transaction ${i + 1}/${_editableTransactions.length}: "$note"',
      );

      try {
        // Call AI service to categorize
        final result = await AIService.analyzeTransactionNote(
          note,
          widget.categories,
        );

        if (result['success'] == true) {
          final suggestedCategoryName = result['suggestedCategory'] as String?;
          final confidence = result['confidence'] as double? ?? 0.0;

          // Find matching category ID
          final matchingCategory = widget.categories.firstWhereOrNull(
            (cat) =>
                (cat['name'] as String?)?.toLowerCase() ==
                suggestedCategoryName?.toLowerCase(),
          );

          if (matchingCategory != null) {
            print(
              '✓ Auto-categorized: "$suggestedCategoryName" (${(confidence * 100).toStringAsFixed(0)}% confidence)',
            );

            setState(() {
              _editableTransactions[i] = {
                ..._editableTransactions[i],
                'categoryId': matchingCategory['categoryId'],
                'categoryName': suggestedCategoryName,
                'suggestedCategory': suggestedCategoryName,
                'confidence': confidence,
              };
            });
          } else {
            print(
              '⚠️ Suggested category "$suggestedCategoryName" not found in database',
            );
          }
        } else {
          print('⚠️ Categorization failed: ${result['error']}');
        }
      } catch (e) {
        print('❌ Error categorizing transaction: $e');
      }
    }

    print('\n✓ Auto-categorization complete for all transactions\n');

    if (mounted) {
      setState(() => _isLoadingCategories = false);
    }
  }

  void _previousRecord() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
    }
  }

  void _nextRecord() {
    if (_currentIndex < _editableTransactions.length - 1) {
      setState(() => _currentIndex++);
    }
  }

  void _updateCurrentRecord(Map<String, dynamic> updates) {
    setState(() {
      _editableTransactions[_currentIndex].addAll(updates);
    });
  }

  Future<void> _saveBulkTransactions() async {
    // Validate all transactions
    for (final t in _editableTransactions) {
      if (t['note'].toString().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All notes must be filled')),
        );
        return;
      }

      if (t['amount'] <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All amounts must be greater than 0')),
        );
        return;
      }

      if (widget.selectedType != 'transfer' &&
          (t['categoryId'] == null || t['categoryId'].toString().isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All transactions must have a category'),
          ),
        );
        return;
      }

      if (t['accountId'] == null || t['accountId'].toString().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All transactions must have an account selected'),
          ),
        );
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      if (widget.selectedType == 'transfer') {
        await _saveBulkTransfers();
      } else {
        await _saveBulkExpenseIncome();
      }

      // Show success dialog
      if (mounted) {
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
                    // Success icon
                    Container(
                      width: 60,
                      height: 60,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFA7E399),
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
                      'Transactions Saved!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFF39C12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Success message
                    Text(
                      '${_editableTransactions.length} transaction${_editableTransactions.length > 1 ? 's have' : ' has'} been successfully saved. You can now view ${_editableTransactions.length > 1 ? 'them' : 'it'} in your transaction history.',
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
                          Navigator.pop(dialogContext); // Close dialog
                          // Navigate back to HomeScreen
                          Navigator.of(context)
                            ..pop() // Close bulk confirmation screen
                            ..pop() // Close AI categorization screen
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
    } catch (e) {
      print('Error saving bulk transactions: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving transactions: $e')));
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _saveBulkExpenseIncome() async {
    for (final t in _editableTransactions) {
      // Generate transaction ID
      final existingTransactions = await Supabase.instance.client
          .from('Transaction')
          .select('transactionId')
          .like('transactionId', 'TRANS${widget.userId}%');

      final sequenceNumber = existingTransactions.length + 1;
      final formattedSequence = sequenceNumber.toString().padLeft(6, '0');
      final transactionId = 'TRANS${widget.userId}$formattedSequence';

      // Save transaction
      await Supabase.instance.client.from('Transaction').insert({
        'transactionId': transactionId,
        'categoryId': t['categoryId'],
        'accountId': t['accountId'],
        'amount': t['amount'] as double,
        'date': t['date'].toIso8601String(),
        'note': t['note'] as String,
        'type': widget.selectedType,
        'ledgerId': widget.ledgerId,
        'image': null,
      });

      // Update account balance
      final accountId = t['accountId'] as String?;
      if (accountId != null) {
        final account = widget.accounts.firstWhereOrNull(
          (acc) => acc['accountId'] == accountId,
        );

        if (account != null) {
          final currentBalance = account['balance'] ?? 0.0;
          final newBalance = widget.selectedType == 'expense'
              ? currentBalance - (t['amount'] as double)
              : currentBalance + (t['amount'] as double);

          await Supabase.instance.client
              .from('Account')
              .update({'balance': newBalance})
              .eq('accountId', accountId ?? '');
        }
      }
    }
  }

  Future<void> _saveBulkTransfers() async {
    for (final t in _editableTransactions) {
      // Generate transfer ID
      final existingTransfers = await Supabase.instance.client
          .from('Transfer')
          .select('transferId')
          .like('transferId', 'TRANSFER${widget.userId}%');

      final sequenceNumber = existingTransfers.length + 1;
      final formattedSequence = sequenceNumber.toString().padLeft(6, '0');
      final transferId = 'TRANSFER${widget.userId}$formattedSequence';

      // Save transfer
      await Supabase.instance.client.from('Transfer').insert({
        'transferId': transferId,
        'fromAccountId': widget.selectedFromAccountId,
        'toAccountId': widget.selectedToAccountId,
        'amount': t['amount'] as double,
        'date': t['date'].toIso8601String(),
        'note': t['note'] as String,
        'noteImage': null,
      });

      // Update account balances
      if (widget.selectedFromAccountId != null) {
        final fromAccount = widget.accounts.firstWhereOrNull(
          (acc) => acc['accountId'] == widget.selectedFromAccountId,
        );
        final fromBalance = fromAccount?['balance'] ?? 0.0;
        final newFromBalance = fromBalance - (t['amount'] as double);

        await Supabase.instance.client
            .from('Account')
            .update({'balance': newFromBalance})
            .eq('accountId', widget.selectedFromAccountId ?? '');
      }

      if (widget.selectedToAccountId != null) {
        final toAccount = widget.accounts.firstWhereOrNull(
          (acc) => acc['accountId'] == widget.selectedToAccountId,
        );
        final toBalance = toAccount?['balance'] ?? 0.0;
        final newToBalance = toBalance + (t['amount'] as double);

        await Supabase.instance.client
            .from('Account')
            .update({'balance': newToBalance})
            .eq('accountId', widget.selectedToAccountId ?? '');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = _editableTransactions[_currentIndex];
    final totalCount = _editableTransactions.length;
    final isFirstRecord = _currentIndex == 0;
    final isLastRecord = _currentIndex == totalCount - 1;
    final confidence = current['confidence'] as double? ?? 0.0;
    final isHighConfidence = confidence >= 0.70;

    print('\n📄 === BULK CONFIRMATION SCREEN ===');
    print('Current page: ${_currentIndex + 1} of $totalCount');
    print('---');

    return Scaffold(
      backgroundColor: const Color(0xFFFEFFD3),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFEFFD3),
        elevation: 0,
        automaticallyImplyLeading: true,
        title: Text(
          'Confirm Transactions (${_currentIndex + 1}/$totalCount)',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
      body: _isLoadingCategories
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Auto-categorizing transactions...'),
                ],
              ),
            )
          : _isSaving
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Progress indicator
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF39C12).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFF39C12).withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Transaction ${_currentIndex + 1} of $totalCount',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFF39C12),
                          ),
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: (_currentIndex + 1) / totalCount,
                          minHeight: 6,
                          backgroundColor: Colors.grey[300],
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFFA7E399),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // AI Confidence Indicator (only for expense/income with category)
                  if (widget.selectedType != 'transfer') ...[
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
                                  '${(confidence * 100).toStringAsFixed(1)}% confidence',
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
                  ],

                  // Account Section (only for expense/income)
                  if (widget.selectedType != 'transfer') ...[
                    const Text(
                      'Account',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildAccountSelector(current),
                    const SizedBox(height: 24),
                  ],

                  // Category Selection Section
                  if (widget.selectedType != 'transfer') ...[
                    const Text(
                      'Category',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildSmartCategorySelector(current),
                    const SizedBox(height: 24),
                  ],

                  // Transaction Note Section
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
                      controller: TextEditingController(
                        text: current['note'] as String,
                      ),
                      onChanged: (value) =>
                          _updateCurrentRecord({'note': value}),
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
                          child: const Text(
                            'RM',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: TextEditingController(
                              text: (current['amount'] as double).toString(),
                            ),
                            onChanged: (value) {
                              final amount = double.tryParse(value);
                              if (amount != null && amount > 0) {
                                _updateCurrentRecord({'amount': amount});
                              }
                            },
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              hintText: '0.00',
                              hintStyle: TextStyle(
                                color: Colors.black.withOpacity(0.3),
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 16,
                              ),
                            ),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                            textAlign: TextAlign.right,
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
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: current['date'] as DateTime,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        _updateCurrentRecord({'date': picked});
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${(current['date'] as DateTime).year}-${(current['date'] as DateTime).month.toString().padLeft(2, '0')}-${(current['date'] as DateTime).day.toString().padLeft(2, '0')}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                          const Icon(
                            Icons.calendar_today,
                            color: Color(0xFFF39C12),
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Navigation buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (!isFirstRecord)
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _previousRecord,
                            icon: const Icon(Icons.arrow_back),
                            label: const Text('Previous'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              backgroundColor: const Color(0xFFCCCCCC),
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      if (!isFirstRecord) const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: isLastRecord
                              ? _saveBulkTransactions
                              : _nextRecord,
                          icon: Icon(
                            isLastRecord
                                ? Icons.check_circle
                                : Icons.arrow_forward,
                          ),
                          label: Text(isLastRecord ? 'Confirm All' : 'Next'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            backgroundColor: isLastRecord
                                ? const Color(0xFFA7E399)
                                : const Color(0xFFF39C12),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }

  Widget _buildSmartCategorySelector(Map<String, dynamic> current) {
    final categoryScores = _getCategoryScores(current);

    if (categoryScores.isEmpty) {
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

    final topScore = categoryScores.isNotEmpty
        ? (categoryScores[0]['confidence'] as double)
        : 0.0;
    final hasHighConfidence = topScore >= 0.80;
    final topThree = categoryScores.take(3).toList();
    final selectedCategoryName = current['categoryName'] as String?;

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
            final isSelected = category == selectedCategoryName;
            return GestureDetector(
              onTap: () {
                if (category != selectedCategoryName) {
                  final matchingCategory = widget.categories.firstWhereOrNull(
                    (cat) =>
                        (cat['name'] as String?)?.toLowerCase() ==
                        category.toLowerCase(),
                  );
                  _updateCurrentRecord({
                    'categoryId': matchingCategory?['categoryId'],
                    'categoryName': category,
                  });
                }
              },
              child: _buildCategoryCard(category, confidence, isSelected),
            );
          },
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () => _showAllCategoriesDialog(current),
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

  IconData _getIconData(String iconName) {
    final iconMap = {
      'shopping_bag': Icons.shopping_bag,
      'restaurant': Icons.restaurant,
      'local_taxi': Icons.local_taxi,
      'local_gas_station': Icons.local_gas_station,
      'movie': Icons.movie,
      'shopping_cart': Icons.shopping_cart,
      'health_and_safety': Icons.health_and_safety,
      'school': Icons.school,
      'airplane': Icons.flight,
      'home': Icons.home,
      'phone': Icons.phone,
      'electric_bolt': Icons.electric_bolt,
      'water': Icons.water,
      'sports_bar': Icons.sports_bar,
      'entertainment': Icons.theaters,
      'fitness_center': Icons.fitness_center,
      'book': Icons.book,
      'pets': Icons.pets,
      'card_giftcard': Icons.card_giftcard,
      'savings': Icons.savings,
      'trending_up': Icons.trending_up,
      'currency_pound': Icons.currency_pound,
    };
    return iconMap[iconName] ?? Icons.shopping_bag;
  }

  Widget _buildCategoryImage(String? iconPath) {
    if (iconPath != null && iconPath.isNotEmpty) {
      final categoryIconUrl = AIService.getCategoryIconUrl(iconPath);
      if (categoryIconUrl.isNotEmpty) {
        return ClipRRect(
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
                  size: 18,
                ),
              );
            },
          ),
        );
      }
    }
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: const Color(0xFFA7E399),
      ),
      child: const Icon(Icons.category, color: Colors.white, size: 18),
    );
  }

  Widget _buildAccountIcon(String? iconImage) {
    if (iconImage == null || iconImage.isEmpty) {
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey[300],
        ),
        child: Icon(Icons.account_balance, size: 16, color: Colors.grey[600]),
      );
    }

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey[300]!, width: 1),
      ),
      child: ClipOval(
        child: Image.network(
          iconImage,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.grey[300],
              child: Icon(
                Icons.account_balance,
                size: 16,
                color: Colors.grey[600],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAccountSelector(Map<String, dynamic> current) {
    final selectedAccountId = current['accountId'] as String?;
    final selectedAccount = widget.accounts.firstWhereOrNull(
      (acc) => acc['accountId'] == selectedAccountId,
    );

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButton<String?>(
        isExpanded: true,
        value: selectedAccountId,
        hint: const Padding(
          padding: EdgeInsets.only(left: 12),
          child: Text('Select Account'),
        ),
        underline: const SizedBox.shrink(),
        items: widget.accounts.map((acc) {
          final accId = acc['accountId'] as String?;
          final accName = acc['accountName'] as String? ?? 'Unknown';
          final iconImage = acc['iconImage'] as String? ?? '';

          return DropdownMenuItem<String?>(
            value: accId,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  _buildAccountIcon(iconImage),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      accName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
        onChanged: (accountId) {
          if (accountId != null) {
            _updateCurrentRecord({'accountId': accountId});
          }
        },
      ),
    );
  }

  List<Map<String, dynamic>> _getCategoryScores(
    Map<String, dynamic> transaction,
  ) {
    final suggestedCategory = transaction['suggestedCategory'] as String? ?? '';
    final confidence = transaction['confidence'] as double? ?? 0.0;

    if (suggestedCategory.isEmpty) {
      return widget.categories
          .map((cat) => {'category': cat['name'] as String, 'confidence': 0.0})
          .toList();
    }

    // Sort categories by confidence
    final scores = widget.categories.map((cat) {
      final catName = cat['name'] as String;
      final conf = catName.toLowerCase() == suggestedCategory.toLowerCase()
          ? confidence
          : 0.0;
      return {'category': catName, 'confidence': conf};
    }).toList();

    scores.sort(
      (a, b) =>
          (b['confidence'] as double).compareTo(a['confidence'] as double),
    );

    return scores;
  }

  Widget _buildCategoryCard(
    String category,
    double confidence,
    bool isSelected,
  ) {
    // Find category icon
    final categoryData = widget.categories.firstWhereOrNull(
      (cat) =>
          (cat['name'] as String?)?.toLowerCase() == category.toLowerCase(),
    );
    final iconPath = categoryData?['icon'] as String? ?? '';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFFA7E399).withOpacity(0.2)
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
          // Category Icon
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(6),
            ),
            child: _buildCategoryImage(iconPath),
          ),
          const SizedBox(width: 12),
          if (isSelected)
            Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFA7E399),
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 16),
            ),
          if (isSelected) const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                if (confidence > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${(confidence * 100).toStringAsFixed(0)}% match',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAllCategoriesDialog(Map<String, dynamic> current) {
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
                'Select Category',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: widget.categories.length,
                itemBuilder: (_, index) {
                  final category = widget.categories[index];
                  final catName = category['name'] as String;
                  final isSelected = catName == current['categoryName'];

                  return ListTile(
                    title: Text(catName),
                    trailing: isSelected
                        ? const Icon(Icons.check, color: Color(0xFFA7E399))
                        : null,
                    onTap: () {
                      _updateCurrentRecord({
                        'categoryId': category['categoryId'],
                        'categoryName': catName,
                      });
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
