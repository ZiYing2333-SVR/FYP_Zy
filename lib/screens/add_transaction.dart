import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddTransaction extends StatefulWidget {
  final String userId;

  const AddTransaction({Key? key, required this.userId}) : super(key: key);

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

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  @override
  void dispose() {
    _noteController.dispose();
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
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a category')));
      return;
    }

    if (_amountText == '0' || _amountText.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter an amount')));
      return;
    }

    try {
      // Generate transaction ID
      final transactionId =
          'TXN${DateTime.now().millisecondsSinceEpoch}${widget.userId}';

      await Supabase.instance.client.from('Transaction').insert({
        'transactionId': transactionId,
        'categoryId': _selectedCategory!['categoryId'],
        'amount': double.parse(_amountText),
        'date': _selectedDate.toIso8601String(),
        'note': _noteController.text,
        'type': _selectedType,
        'userId': widget.userId,
      });

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
          // Expense/Income Toggle (Top Center)
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
                      horizontal: 16,
                      vertical: 8,
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
                        fontSize: 12,
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
                      horizontal: 16,
                      vertical: 8,
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
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Categories Grid (Scrollable - takes more space)
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
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
          // Amount Display and Keyboard Section (1/3 size at bottom)
          Container(
            color: const Color(0xFFB0E0E6),
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Amount Display
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF90EE90),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _amountText,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 8),
                // Numeric Keyboard (Fixed at bottom)
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
                          _buildKeyboardButton('7'),
                          _buildKeyboardButton('8'),
                          _buildKeyboardButton('9'),
                          _buildKeyboardButton('C'),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Row 2: 4, 5, 6, *
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildKeyboardButton('4'),
                          _buildKeyboardButton('5'),
                          _buildKeyboardButton('6'),
                          _buildKeyboardButton('*'),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Row 3: 1, 2, 3, +
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildKeyboardButton('1'),
                          _buildKeyboardButton('2'),
                          _buildKeyboardButton('3'),
                          _buildKeyboardButton('+'),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Row 4: 0, ., <, ✓
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildKeyboardButton('0', flex: 2),
                          _buildKeyboardButton('.'),
                          _buildKeyboardButton('<'),
                          _buildKeyboardButton('✓'),
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

  Widget _buildKeyboardButton(String label, {int flex = 1}) {
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
          height: 35,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: isSpecial ? Colors.white : Colors.white,
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
                fontSize: label == '✓' ? 18 : 14,
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
}
