import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/ai_service.dart';
import '../utils/transaction_parser.dart';
import 'auto_expense_confirmation_screen.dart';
import 'confirm_bulk_transactions.dart';
import 'home_screen.dart';

class AutoExpenseCategorization extends StatefulWidget {
  final String userId;
  final String? ledgerId;

  const AutoExpenseCategorization({
    super.key,
    required this.userId,
    this.ledgerId,
  });

  @override
  State<AutoExpenseCategorization> createState() =>
      _AutoExpenseCategorizationState();
}

class _AutoExpenseCategorizationState extends State<AutoExpenseCategorization>
    with WidgetsBindingObserver {
  late TextEditingController _noteController;
  bool _isAnalyzing = false;
  List<Map<String, dynamic>> _categories = [];
  bool _isLoadingCategories = true;
  List<Map<String, dynamic>> _accounts = [];

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController();
    WidgetsBinding.instance.addObserver(this);
    _fetchCategories();
    _fetchAccounts();
  }

  @override
  void dispose() {
    _noteController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Refresh categories when screen comes to focus
  /// This ensures newly added categories are available
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchCategories();
    }
  }

  Future<void> _fetchCategories() async {
    try {
      final categories = await AIService.getCategories(widget.userId);
      setState(() {
        _categories = categories;
        _isLoadingCategories = false;
      });
    } catch (e) {
      print('Error fetching categories: $e');
      setState(() => _isLoadingCategories = false);
    }
  }

  Future<void> _fetchAccounts() async {
    try {
      final response = await Supabase.instance.client
          .from('Account')
          .select()
          .eq('userId', widget.userId);

      setState(() {
        // Filter out Savings type accounts
        _accounts = (response as List)
            .map((acc) => Map<String, dynamic>.from(acc as Map))
            .where((acc) => (acc['accountType'] as String?) != 'Savings')
            .toList();
      });
    } catch (e) {
      print('Error fetching accounts: $e');
    }
  }

  Future<void> _analyzeNote() async {
    if (_noteController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a transaction note')),
      );
      return;
    }

    final noteText = _noteController.text.trim();

    // **NEW: Check if bulk format (semicolon in note)**
    print('\n🔍 === AI CATEGORIZATION SCREEN ===');
    print('Note text: "$noteText"');
    print('Contains semicolon: ${noteText.contains(";")}');

    final isBulk = TransactionParser.isBulkFormat(noteText);

    if (isBulk) {
      print('✓ BULK FORMAT DETECTED in AI flow - Routing to bulk handler');
      _handleBulkInAIFlow(noteText);
      return;
    }

    print('✗ Single transaction format - Using AI analysis');

    setState(() => _isAnalyzing = true);

    try {
      final result = await AIService.analyzeTransactionNote(
        noteText,
        _categories,
      );

      if (result['success'] == true) {
        // Navigate to confirmation screen with AI result
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AutoExpenseConfirmation(
                userId: widget.userId,
                ledgerId: widget.ledgerId,
                note: noteText,
                aiResult: result,
                allCategories: _categories,
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['error'] ?? 'Analysis failed')),
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
        setState(() => _isAnalyzing = false);
      }
    }
  }

  /// Handle bulk transactions in AI flow
  void _handleBulkInAIFlow(String noteText) {
    print('\n📊 === BULK TRANSACTION IN AI FLOW ===');
    print('Raw input: "$noteText"');

    // Parse bulk format
    final parsedTransactions = TransactionParser.parseBulk(noteText);
    print('Parsed ${parsedTransactions.length} transactions');

    // Validate
    final validationError = TransactionParser.validateTransactions(
      parsedTransactions,
    );
    if (validationError != null) {
      print('❌ Validation error: $validationError');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Invalid bulk format!',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(validationError),
              const SizedBox(height: 8),
              const Text(
                'Format: "note, amount; note, amount"',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }

    print('✓ All transactions valid - Routing to bulk confirmation');

    // Navigate to bulk confirmation screen with AI service for categorization
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => ConfirmBulkTransactionsScreen(
              userId: widget.userId,
              ledgerId: widget.ledgerId,
              parsedTransactions: parsedTransactions,
              selectedType: 'expense', // AI flow is for expenses
              selectedAccountId: null, // User selects on confirmation screen
              selectedFromAccountId: null,
              selectedToAccountId: null,
              accounts: _accounts,
              categories: _categories,
            ),
          ),
        )
        .then((result) {
          if (result == true) {
            // Success - navigate back to home page to show updated transactions
            print('\n✓ Bulk transactions saved successfully');
            Navigator.of(context)
              ..pop() // Close AI categorization screen
              ..pushReplacement(
                MaterialPageRoute(
                  builder: (context) => HomeScreen(userId: widget.userId),
                ),
              );
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEFFD3),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFEFFD3),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Icon(Icons.close, color: Colors.black, size: 24),
            ),
            const Text(
              'Auto Expense Categorization',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(width: 24),
          ],
        ),
      ),
      body: _isLoadingCategories
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),
                  // Title
                  const Text(
                    'Enter Transaction Note',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Format guide
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF1976D2),
                        width: 0.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Format Guide:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1976D2),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '📌 Single: "breakfast bread 2.80"',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF333333),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '📌 Bulk (use ;): "bread, 2.80; coffee, 5.50; lunch, 12.00"',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF1976D2),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Input Field
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFA7E399),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _noteController,
                      minLines: 4,
                      maxLines: 6,
                      decoration: InputDecoration(
                        hintText:
                            'Single: "breakfast bread 2.80" or Bulk: "bread, 2.80; coffee, 5.50"',
                        hintStyle: TextStyle(
                          color: Colors.black.withOpacity(0.5),
                          fontSize: 13,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(16),
                      ),
                      style: const TextStyle(color: Colors.black, fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Analyze Button
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
                      onPressed: _isAnalyzing ? null : _analyzeNote,
                      child: _isAnalyzing
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
                                  'Analyze & Categorize',
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
                  const SizedBox(height: 24),
                  // Info Section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'How it works:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildInfoItem(
                          '1',
                          'Enter transaction details (e.g., "Breakfast bread RM2.80")',
                        ),
                        const SizedBox(height: 8),
                        _buildInfoItem(
                          '2',
                          'AI analyzes the note using natural language processing',
                        ),
                        const SizedBox(height: 8),
                        _buildInfoItem(
                          '3',
                          'System suggests the appropriate expense category',
                        ),
                        const SizedBox(height: 8),
                        _buildInfoItem(
                          '4',
                          'You can confirm or adjust the suggestion',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoItem(String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: const Color(0xFFA7E399),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black87,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
