import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'settings_screen.dart';
import 'account_page.dart';
import 'add_transaction.dart';
import 'transaction_detail_screen.dart';
import 'savings_page.dart';

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
  bool _showAmounts = true;

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
          .select('*, Category(name, icon), Account(accountName, iconImage)')
          .eq('ledgerId', _selectedLedgerId ?? '')
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

  String _getMonthName(int month) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
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

  Widget _buildCategoryImage(String? iconUrl) {
    // If iconUrl is a URL (starts with http), display it as an image
    if (iconUrl != null &&
        iconUrl.isNotEmpty &&
        (iconUrl.startsWith('http') || iconUrl.startsWith('/'))) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          iconUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: Icon(Icons.shopping_bag, color: Colors.white, size: 20),
            );
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            );
          },
        ),
      );
    }
    // Otherwise, treat it as an icon name
    return Center(
      child: Icon(
        _getIconData(iconUrl ?? 'shopping_bag'),
        color: Colors.white,
        size: 20,
      ),
    );
  }

  Widget _buildGroupedTransactionsList() {
    // Group transactions by date
    Map<String, List<Map<String, dynamic>>> groupedByDate = {};
    for (var transaction in _transactions) {
      final date = transaction['date'] != null
          ? DateTime.parse(transaction['date'])
          : DateTime.now();
      final dateKey = '${date.year}-${date.month}-${date.day}';
      if (!groupedByDate.containsKey(dateKey)) {
        groupedByDate[dateKey] = [];
      }
      groupedByDate[dateKey]!.add(transaction);
    }

    // Sort dates in descending order
    final sortedDates = groupedByDate.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sortedDates.length,
      itemBuilder: (context, index) {
        final dateKey = sortedDates[index];
        final dateTransactions = groupedByDate[dateKey]!;
        final date = DateTime.parse(dateTransactions[0]['date']);

        // Calculate daily income and expense separately
        double dayIncome = 0;
        double dayExpense = 0;
        for (var txn in dateTransactions) {
          final amount = double.tryParse(txn['amount'].toString()) ?? 0;
          final type = txn['type']?.toString().toLowerCase() ?? 'expense';
          if (type == 'income') {
            dayIncome += amount;
          } else {
            dayExpense += amount;
          }
        }

        return Container(
          margin: const EdgeInsets.only(top: 12, bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF9E6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFFE5B4), width: 1),
          ),
          child: Column(
            children: [
              // Date Header
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFAE6),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(11),
                    topRight: Radius.circular(11),
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: const Color(0xFFFFE5B4),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_getDayOfWeek(date)}, ${date.day.toString().padLeft(2, '0')} ${_getMonthName(date.month)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    Row(
                      children: [
                        if (dayIncome > 0)
                          Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: Text(
                              'IN RM${dayIncome.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF52C77A),
                              ),
                            ),
                          ),
                        if (dayExpense > 0)
                          Text(
                            'OUT RM${dayExpense.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFE74C3C),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              // Transaction Items
              ...dateTransactions.asMap().entries.map((entry) {
                final txnIndex = entry.key;
                final transaction = entry.value;
                final amount =
                    double.tryParse(transaction['amount'].toString()) ?? 0;
                final type =
                    transaction['type']?.toString().toLowerCase() ?? 'expense';
                final categoryData = transaction['Category'] ?? {};
                final categoryName = categoryData['name'] ?? 'Category';
                final categoryIcon = categoryData['icon'] ?? 'shopping_bag';
                final accountData = transaction['Account'] ?? {};
                final accountLogo = accountData['iconImage'] ?? '';
                final note = transaction['note'] ?? '';
                final isRefunded = transaction['refund'] == true;
                final isLastItem = txnIndex == dateTransactions.length - 1;

                return Column(
                  children: [
                    GestureDetector(
                      onTap: () async {
                        final transactionId =
                            transaction['transactionId'] as String;
                        print(
                          'Opening transaction detail for ID: $transactionId',
                        );
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TransactionDetailScreen(
                              transactionId: transactionId,
                              userId: _currentUserId,
                            ),
                          ),
                        );
                        // Refresh transactions if a transaction was deleted or refunded
                        if (result == true) {
                          _fetchTransactions();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Category Icon
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: const Color(0xFFC8A5D8),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: _buildCategoryImage(categoryIcon),
                            ),
                            const SizedBox(width: 12),
                            // Category Name and Note
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    categoryName,
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
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Right side: Amount, Account Icon, and Refund Badge
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Amount
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
                                    const SizedBox(width: 8),
                                    // Account Icon in small circle
                                    if (accountLogo.isNotEmpty)
                                      Container(
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: const Color(0xFFFFE5B4),
                                            width: 1,
                                          ),
                                        ),
                                        child: ClipOval(
                                          child: Image.network(
                                            accountLogo,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                                  return Container(
                                                    decoration: BoxDecoration(
                                                      color: Colors.grey[300],
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: const Icon(
                                                      Icons.account_balance,
                                                      size: 12,
                                                    ),
                                                  );
                                                },
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                // Refund Badge below amount and account icon
                                if (isRefunded)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFE5B4),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'REFUNDED',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFE74C3C),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Divider between transactions (but not after last one)
                    if (!isLastItem)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Divider(
                          color: const Color(0xFFFFE5B4),
                          height: 1,
                          thickness: 1,
                        ),
                      ),
                  ],
                );
              }).toList(),
            ],
          ),
        );
      },
    );
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
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _showAmounts = !_showAmounts;
                                  });
                                },
                                child: Icon(
                                  _showAmounts
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  color: Colors.black,
                                ),
                              ),
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
                                    _showAmounts
                                        ? 'RM${_totalAmount.toStringAsFixed(2)}'
                                        : '****',
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
                                    _showAmounts
                                        ? 'RM${_incomeAmount.toStringAsFixed(2)}'
                                        : '****',
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
                                    _showAmounts
                                        ? 'RM${_expenseAmount.toStringAsFixed(2)}'
                                        : '****',
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
                        : _buildGroupedTransactionsList(),
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
            icon: Icon(Icons.account_balance_wallet),
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
          } else if (index == 3) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SavingsPage(userId: _currentUserId!),
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
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: FloatingActionButton(
          backgroundColor: const Color(0xFF90EE90),
          onPressed: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AddTransaction(
                  userId: _currentUserId!,
                  ledgerId: _selectedLedgerId,
                ),
              ),
            );
            // Refresh transactions if a new one was added
            if (result == true) {
              await _fetchTransactions();
            }
          },
          child: const Icon(Icons.add, color: Colors.black, size: 30),
        ),
      ),
    );
  }
}
