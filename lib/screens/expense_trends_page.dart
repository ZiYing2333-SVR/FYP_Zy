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
  int _selectedIndex = 4;
  String _selectedFilter = 'month';

  List<Map<String, dynamic>> _trendData = [];
  double _totalIncome = 0;
  double _totalExpense = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTrendData();
  }

  Future<void> _fetchTrendData() async {
    try {
      // Get all ledgers for the current user
      final ledgers = await Supabase.instance.client
          .from('Ledger')
          .select()
          .eq('userId', widget.userId);

      if (ledgers.isEmpty) {
        setState(() {
          _isLoading = false;
          _trendData = [];
          _totalIncome = 0;
          _totalExpense = 0;
        });
        return;
      }

      final ledgerIds = List<String>.from(
        ledgers.map((l) => l['ledgerId'] as String),
      );

      // Calculate date range based on selected filter
      final now = DateTime.now();
      final DateTime startDate;
      final DateTime endDate = now;

      switch (_selectedFilter) {
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

      // Fetch all transactions for these ledgers
      List<dynamic> allTransactions = [];
      for (String ledgerId in ledgerIds) {
        final transactions = await Supabase.instance.client
            .from('Transaction')
            .select()
            .eq('ledgerId', ledgerId)
            .gte('date', startDate.toIso8601String())
            .lte('date', endDate.toIso8601String());

        allTransactions.addAll(transactions);
      }

      // Group by date and calculate daily totals
      Map<String, Map<String, double>> dailyData = {};
      double totalIncome = 0;
      double totalExpense = 0;

      for (var transaction in allTransactions) {
        String dateStr = transaction['date'].toString().split('T')[0];
        double amount = (transaction['amount'] as num).toDouble();
        String type = transaction['type'] ?? '';

        if (!dailyData.containsKey(dateStr)) {
          dailyData[dateStr] = {'income': 0, 'expense': 0};
        }

        if (type == 'income') {
          dailyData[dateStr]!['income'] =
              (dailyData[dateStr]!['income'] ?? 0) + amount;
          totalIncome += amount;
        } else if (type == 'expense') {
          dailyData[dateStr]!['expense'] =
              (dailyData[dateStr]!['expense'] ?? 0) + amount;
          totalExpense += amount;
        }
      }

      // Convert to sorted list
      List<String> sortedDates = dailyData.keys.toList();
      sortedDates.sort();

      List<Map<String, dynamic>> trendData = [];
      for (String date in sortedDates) {
        double income = dailyData[date]!['income'] ?? 0;
        double expense = dailyData[date]!['expense'] ?? 0;
        double net = income - expense;

        trendData.add({
          'date': date,
          'income': income,
          'expense': expense,
          'net': net,
        });
      }

      setState(() {
        _trendData = trendData;
        _totalIncome = totalIncome;
        _totalExpense = totalExpense;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching trend data: $e');
      setState(() => _isLoading = false);
    }
  }

  List<FlSpot> _getIncomeSpots() {
    return _trendData.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value['income']);
    }).toList();
  }

  List<FlSpot> _getExpenseSpots() {
    return _trendData.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value['expense']);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF9E6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFEFFD3),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  // Filter buttons
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildFilterButton('Day', 'day'),
                        _buildFilterButton('Week', 'week'),
                        _buildFilterButton('Month', 'month'),
                        _buildFilterButton('Year', 'year'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Total Summary
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Period Summary',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildSummaryItem(
                                  'Income',
                                  '\$${_totalIncome.toStringAsFixed(2)}',
                                  const Color(0xFF4CAF50),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildSummaryItem(
                                  'Expense',
                                  '\$${_totalExpense.toStringAsFixed(2)}',
                                  const Color(0xFFF44336),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: (_totalIncome - _totalExpense) >= 0
                                  ? const Color(0xFFC8E6C9)
                                  : const Color(0xFFFFCDD2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Net',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                                ),
                                Text(
                                  '${(_totalIncome - _totalExpense) >= 0 ? '+' : ''}\$${(_totalIncome - _totalExpense).toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: (_totalIncome - _totalExpense) >= 0
                                        ? const Color(0xFF388E3C)
                                        : const Color(0xFFC62828),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Line Chart
                  if (_trendData.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
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
                        child: Column(
                          children: [
                            const Text(
                              'Expense Trend Line',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 300,
                              child: LineChart(
                                LineChartData(
                                  gridData: FlGridData(show: true),
                                  titlesData: FlTitlesData(
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        getTitlesWidget: (value, meta) {
                                          int index = value.toInt();
                                          if (index >= 0 &&
                                              index < _trendData.length) {
                                            String date =
                                                _trendData[index]['date'];
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                top: 8,
                                              ),
                                              child: Text(
                                                date.substring(5),
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            );
                                          }
                                          return const Text('');
                                        },
                                      ),
                                    ),
                                    leftTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        getTitlesWidget: (value, meta) {
                                          return Text(
                                            '\$${value.toInt()}',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  borderData: FlBorderData(show: true),
                                  lineBarsData: [
                                    LineChartBarData(
                                      spots: _getIncomeSpots(),
                                      isCurved: true,
                                      color: const Color(0xFF4CAF50),
                                      barWidth: 2,
                                      dotData: FlDotData(show: true),
                                      belowBarData: BarAreaData(show: false),
                                    ),
                                    LineChartBarData(
                                      spots: _getExpenseSpots(),
                                      isCurved: true,
                                      color: const Color(0xFFF44336),
                                      barWidth: 2,
                                      dotData: FlDotData(show: true),
                                      belowBarData: BarAreaData(show: false),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
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
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 24),
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
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Text(
                        'No transaction data for this period',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                    ),
                  const SizedBox(height: 20),
                  // Daily Details
                  if (_trendData.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Daily Details',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ..._trendData.asMap().entries.map((entry) {
                            int index = entry.key;
                            Map<String, dynamic> data = entry.value;

                            return Column(
                              children: [
                                _buildDailyDetailItem(data),
                                if (index < _trendData.length - 1)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    child: Divider(
                                      color: Colors.grey[300],
                                      height: 1,
                                    ),
                                  ),
                              ],
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
      bottomNavigationBar: Stack(
        children: [
          BottomNavigationBar(
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
              BottomNavigationBarItem(
                icon: Icon(Icons.savings),
                label: 'Saving',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.settings),
                label: 'Setting',
              ),
            ],
            onTap: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String label, String value) {
    bool isSelected = _selectedFilter == value;
    return GestureDetector(
      onTap: () async {
        setState(() {
          _selectedFilter = value;
          _isLoading = true;
        });
        await _fetchTrendData();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String amount, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 2),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(
            amount,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyDetailItem(Map<String, dynamic> data) {
    DateTime date = DateTime.parse(data['date']);
    String formattedDate = DateFormat('MMM dd, yyyy').format(date);
    double income = data['income'];
    double expense = data['expense'];
    double net = data['net'];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formattedDate,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Income',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
              Text(
                '\$${income.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF4CAF50),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Expense',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
              Text(
                '\$${expense.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFFF44336),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  '${net >= 0 ? '+' : ''}\$${net.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: net >= 0
                        ? const Color(0xFF388E3C)
                        : const Color(0xFFC62828),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
