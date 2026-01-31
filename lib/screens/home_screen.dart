import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'settings_screen.dart';
import 'account_page.dart';

class HomeScreen extends StatefulWidget {
  final String userId;

  const HomeScreen({super.key, required this.userId});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  DateTime _selectedDate = DateTime.now();
  double _totalAmount = 0;
  double _incomeAmount = 0;
  double _expenseAmount = 0;
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = true;

  // Ledger related
  List<Map<String, dynamic>> _ledgers = [];
  String? _selectedLedgerId;
  String? _currentUserId;
  bool _isLoadingLedgers = true;

  @override
  void initState() {
    super.initState();
    _currentUserId = widget.userId;
    _fetchLedgers();
  }

  Future<void> _fetchLedgers() async {
    try {
      if (_currentUserId == null) return;

      final supabase = Supabase.instance.client;

      final response = await supabase
          .from('Ledger')
          .select()
          .eq('userId', _currentUserId!);

      setState(() {
        _ledgers = List<Map<String, dynamic>>.from(response);
        _isLoadingLedgers = false;

        // Select the first ledger by default
        if (_ledgers.isNotEmpty && _selectedLedgerId == null) {
          _selectedLedgerId = _ledgers[0]['ledgerId'];
          _fetchTransactions();
        }
      });
    } catch (e) {
      print('Error fetching ledgers: $e');
      setState(() {
        _isLoadingLedgers = false;
      });
    }
  }

  Future<void> _fetchTransactions() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final supabase = Supabase.instance.client;

      // Fetch transactions for the selected month
      final startOfMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
      final endOfMonth = DateTime(
        _selectedDate.year,
        _selectedDate.month + 1,
        0,
      );

      final response = await supabase
          .from('Transaction')
          .select()
          .gte('date', startOfMonth.toIso8601String())
          .lte('date', endOfMonth.toIso8601String())
          .order('date', ascending: false);

      double income = 0;
      double expense = 0;

      for (var transaction in response) {
        final amount = double.tryParse(transaction['amount'].toString()) ?? 0;
        final type = transaction['type']?.toString().toLowerCase() ?? 'expense';

        if (type == 'income') {
          income += amount;
        } else {
          expense += amount;
        }
      }

      setState(() {
        _transactions = List<Map<String, dynamic>>.from(response);
        _incomeAmount = income;
        _expenseAmount = expense;
        _totalAmount = income - expense;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching transactions: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showDatePicker() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _fetchTransactions();
    }
  }

  String _getDayOfWeek(DateTime date) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[date.weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEFFD3),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFEFFD3),
        elevation: 0,
        title: Row(
          children: [
            // Ledger Dropdown
            _isLoadingLedgers
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFA7E399),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const SizedBox(
                      width: 100,
                      child: Text(
                        'Loading...',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                : DropdownButton<String>(
                    value: _selectedLedgerId,
                    items: _ledgers.map((ledger) {
                      final ledgerId = ledger['ledgerId'] as String;
                      final ledgerName = ledger['name'] as String;
                      return DropdownMenuItem<String>(
                        value: ledgerId,
                        child: Text(ledgerName),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedLedgerId = newValue;
                        });
                        _fetchTransactions();
                      }
                    },
                    underline: Container(),
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    dropdownColor: const Color(0xFFA7E399),
                    borderRadius: BorderRadius.circular(8),
                  ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Color(0xFF52C77A),
                    size: 18,
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Details',
                    style: TextStyle(
                      color: Color(0xFF52C77A),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {},
              child: const Icon(Icons.more_vert, color: Colors.black),
            ),
          ],
        ),
        titleSpacing: 16,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date and Summary Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFFFE5B4),
                          width: 2,
                        ),
                      ),
                      child: Column(
                        children: [
                          // Date Picker Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              GestureDetector(
                                onTap: _showDatePicker,
                                child: Row(
                                  children: [
                                    Text(
                                      '${_selectedDate.month} / ${_selectedDate.year}',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(
                                      Icons.arrow_drop_down,
                                      color: Colors.black,
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.visibility, color: Colors.black),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Summary Stats
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Column(
                                children: [
                                  Text(
                                    'RM${_totalAmount.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                  const Text(
                                    'Total',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFFBCBCBC),
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                children: [
                                  Text(
                                    'RM${_incomeAmount.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF52C77A),
                                    ),
                                  ),
                                  const Text(
                                    'Income',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFFBCBCBC),
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                children: [
                                  Text(
                                    'RM${_expenseAmount.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFE74C3C),
                                    ),
                                  ),
                                  const Text(
                                    'Expense',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFFBCBCBC),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Transactions List
                    _transactions.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Text(
                                'No transactions for this month',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _transactions.length,
                            itemBuilder: (context, index) {
                              final transaction = _transactions[index];
                              final amount =
                                  double.tryParse(
                                    transaction['amount'].toString(),
                                  ) ??
                                  0;
                              final type =
                                  transaction['type']
                                      ?.toString()
                                      .toLowerCase() ??
                                  'expense';
                              final category =
                                  transaction['category'] ?? 'Category';
                              final note = transaction['note'] ?? '';
                              final date = transaction['date'] != null
                                  ? DateTime.parse(transaction['date'])
                                  : DateTime.now();

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF9E6),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFFFFE5B4),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFC8A5D8),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.shopping_bag,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            category,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.black,
                                            ),
                                          ),
                                          if (note.isNotEmpty)
                                            Text(
                                              note,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFFBCBCBC),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '${type == 'income' ? '+' : '-'}RM${amount.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: type == 'income'
                                                ? const Color(0xFF52C77A)
                                                : const Color(0xFFE74C3C),
                                          ),
                                        ),
                                        Text(
                                          _getDayOfWeek(date),
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Color(0xFFBCBCBC),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        backgroundColor: const Color(0xFFFEFFD3),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Account',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.pets), label: 'Pet'),
          BottomNavigationBarItem(icon: Icon(Icons.savings), label: 'Saving'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Setting'),
        ],
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
          if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AccountPage(userId: _currentUserId!),
              ),
            );
          } else if (index == 4) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SettingsScreen(userId: _currentUserId!),
              ),
            );
          }
        },
      ),
    );
  }
}
