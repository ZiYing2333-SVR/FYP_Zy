import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class ExpenseTrendsPage extends StatefulWidget {
  final String userId;

  const ExpenseTrendsPage({Key? key, required this.userId}) : super(key: key);

  @override
  State<ExpenseTrendsPage> createState() => _ExpenseTrendsPageState();
}

class _ExpenseTrendsPageState extends State<ExpenseTrendsPage> {
  final supabase = Supabase.instance.client;

  DateTime selectedDate = DateTime.now();
  String selectedType = "day"; // day, month, year

  List<FlSpot> incomeSpots = [];
  List<FlSpot> expenseSpots = [];
  List<Map<String, dynamic>> transactions = [];

  double maxY = 0;

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    DateTime start;
    DateTime end;

    if (selectedType == "day") {
      start = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
      end = start.add(const Duration(days: 1));
    } else if (selectedType == "month") {
      start = DateTime(selectedDate.year, selectedDate.month, 1);
      end = DateTime(selectedDate.year, selectedDate.month + 1, 1);
    } else {
      start = DateTime(selectedDate.year, 1, 1);
      end = DateTime(selectedDate.year + 1, 1, 1);
    }

    final response = await supabase
        .from('Transaction')
        .select('*, Category(name, icon), Account(iconImage)')
        .gte('date', start.toIso8601String())
        .lt('date', end.toIso8601String())
        .order('date', ascending: false);

    Map<int, double> incomeMap = {};
    Map<int, double> expenseMap = {};
    List<Map<String, dynamic>> transactionList = [];

    for (var item in response) {
      DateTime date = DateTime.parse(item['date']);
      double amount = (item['amount'] as num).toDouble();
      String type = item['type'];
      bool isRefunded = item['refund'] == true;

      // Add all transactions to list (including refunded)
      transactionList.add(item);

      // Only include non-refunded transactions in chart calculations
      if (!isRefunded) {
        int key;

        if (selectedType == "day") {
          key = date.hour;
        } else if (selectedType == "month") {
          key = date.day;
        } else {
          key = date.month;
        }

        if (type == "income") {
          incomeMap[key] = (incomeMap[key] ?? 0) + amount;
        } else {
          expenseMap[key] = (expenseMap[key] ?? 0) + amount;
        }
      }
    }

    List<FlSpot> tempIncome = [];
    List<FlSpot> tempExpense = [];

    int maxX = selectedType == "day"
        ? 23
        : selectedType == "month"
        ? DateUtils.getDaysInMonth(selectedDate.year, selectedDate.month)
        : 12;

    maxY = 0;

    for (int i = 0; i <= maxX; i++) {
      double income = incomeMap[i] ?? 0;
      double expense = expenseMap[i] ?? 0;

      tempIncome.add(FlSpot(i.toDouble(), income));
      tempExpense.add(FlSpot(i.toDouble(), expense));

      if (income > maxY) maxY = income;
      if (expense > maxY) maxY = expense;
    }

    setState(() {
      incomeSpots = tempIncome;
      expenseSpots = tempExpense;
      maxY = maxY == 0 ? 10 : maxY;
      transactions = transactionList;
    });
  }

  Widget buildChart() {
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: null,
          verticalInterval: null,
          getDrawingHorizontalLine: (value) {
            return FlLine(color: Colors.grey[300]!, strokeWidth: 0.5);
          },
          getDrawingVerticalLine: (value) {
            return FlLine(color: Colors.grey[200]!, strokeWidth: 0.5);
          },
        ),
        titlesData: FlTitlesData(
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: selectedType == "day"
                  ? 3
                  : selectedType == "month"
                  ? 5
                  : 1,
              getTitlesWidget: (value, meta) {
                if (selectedType == "day") {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      '${value.toInt()}h',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  );
                } else if (selectedType == "month") {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      '${value.toInt()}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  );
                } else {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      DateFormat.MMM().format(DateTime(0, value.toInt())),
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  );
                }
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            bottom: BorderSide(color: Colors.grey[300]!, width: 1),
            left: BorderSide(color: Colors.grey[300]!, width: 1),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: incomeSpots,
            isCurved: false,
            color: const Color(0xFF4CAF50),
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 2,
                  color: const Color(0xFF4CAF50),
                  strokeWidth: 1,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(show: false),
          ),
          LineChartBarData(
            spots: expenseSpots,
            isCurved: false,
            color: const Color(0xFFF44336),
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 2,
                  color: const Color(0xFFF44336),
                  strokeWidth: 1,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(show: false),
          ),
        ],
      ),
    );
  }

  Future<void> pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFF39C12),
              onPrimary: Colors.white,
              surface: Color(0xFFFFF9E6),
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => selectedDate = picked);
      fetchData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF9E6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFEFFD3),
        elevation: 0,
        title: const Text(
          'Expense Trends',
          style: TextStyle(
            color: Colors.black,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Date Picker Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: pickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEFFD3),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFF39C12),
                      width: 2,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Selected Date: ${selectedDate.toLocal().toString().split(' ')[0]}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const Icon(
                        Icons.calendar_today,
                        color: Color(0xFFF39C12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Filter buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildFilterButton('Today', 'day'),
                  _buildFilterButton('This Month', 'month'),
                  _buildFilterButton('This Year', 'year'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Chart Container
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                height: 300,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: buildChart(),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Legend
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: Color(0xFF4CAF50),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Income',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF44336),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Expense',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Transactions List - Grouped by Date
            if (transactions.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: Text(
                    'No transactions',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ),
              )
            else
              ..._buildGroupedTransactionsByDate(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterButton(String label, String value) {
    bool isSelected = selectedType == value;
    return GestureDetector(
      onTap: () {
        setState(() => selectedType = value);
        fetchData();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFC8E6C9) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF4CAF50) : Colors.grey[300]!,
            width: 2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black87 : Colors.grey[600],
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  List<Widget> _buildGroupedTransactionsByDate() {
    // Group transactions by date
    Map<String, List<Map<String, dynamic>>> groupedByDate = {};
    for (var transaction in transactions) {
      final date = transaction['date'] != null
          ? DateTime.parse(transaction['date'])
          : DateTime.now();
      final dateKey =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      if (!groupedByDate.containsKey(dateKey)) {
        groupedByDate[dateKey] = [];
      }
      groupedByDate[dateKey]!.add(transaction);
    }

    // Sort dates in descending order (latest first)
    final sortedDates = groupedByDate.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return sortedDates.map((dateKey) {
      final dateTransactions = groupedByDate[dateKey]!;
      final date = DateTime.parse(dateTransactions[0]['date']);

      // Calculate daily income and expense separately (excluding refunded transactions)
      double dayIncome = 0;
      double dayExpense = 0;
      for (var txn in dateTransactions) {
        final amount = double.tryParse(txn['amount'].toString()) ?? 0;
        final type = txn['type']?.toString().toLowerCase() ?? 'expense';
        final isRefunded = txn['refund'] == true;
        if (!isRefunded) {
          if (type == 'income') {
            dayIncome += amount;
          } else {
            dayExpense += amount;
          }
        }
      }

      return Container(
        margin: const EdgeInsets.only(top: 8, bottom: 8, left: 16, right: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF9E6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFFE5B4), width: 1),
        ),
        child: Column(
          children: [
            // Date Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('EEEE, d MMM yyyy').format(date),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (dayIncome > 0)
                        Text(
                          '+RM${dayIncome.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF52C77A),
                          ),
                        ),
                      if (dayExpense > 0)
                        Text(
                          '-RM${dayExpense.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 12,
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
              final isLastItem = txnIndex == dateTransactions.length - 1;

              return Column(
                children: [
                  _buildSingleTransactionItem(transaction),
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
    }).toList();
  }

  Widget _buildSingleTransactionItem(Map<String, dynamic> transaction) {
    DateTime date = DateTime.parse(transaction['date']);
    double amount = (transaction['amount'] as num).toDouble();
    String type = transaction['type'];
    String categoryName = transaction['Category']?['name'] ?? 'Other';
    String categoryIcon = transaction['Category']?['icon'] ?? 'shopping_bag';
    String displayNote = transaction['note'] ?? '';
    bool isRefunded = transaction['refund'] == true;
    final accountData = transaction['Account'] ?? {};
    final accountLogo = accountData['iconImage'] ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Category Icon
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF9E6),
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
                if (displayNote.isNotEmpty)
                  Text(
                    displayNote,
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
                  // Account Icon
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
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
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
              // Refund Badge
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
    );
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
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
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
}
