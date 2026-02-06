import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';

class IncomePieChartPage extends StatefulWidget {
  final String userId;

  const IncomePieChartPage({Key? key, required this.userId}) : super(key: key);

  @override
  State<IncomePieChartPage> createState() => _IncomePieChartPageState();
}

class _IncomePieChartPageState extends State<IncomePieChartPage> {
  int _selectedIndex = 4;
  String _selectedFilter = 'month';

  Map<String, double> _incomeByCategory = {};
  double _totalIncome = 0;
  bool _isLoading = true;

  final Map<String, Color> _categoryColors = {
    'Salary': const Color(0xFF4CAF50),
    'Bonus': const Color(0xFF2196F3),
    'Freelance': const Color(0xFFFF9800),
    'Investment': const Color(0xFFE91E63),
    'Gift': const Color(0xFF9C27B0),
    'Refund': const Color(0xFFF44336),
    'Interest': const Color(0xFF00BCD4),
    'Others': const Color(0xFF607D8B),
  };

  @override
  void initState() {
    super.initState();
    _fetchIncomeData();
  }

  Future<void> _fetchIncomeData() async {
    try {
      // Get all ledgers for the current user
      final ledgers = await Supabase.instance.client
          .from('Ledger')
          .select()
          .eq('userId', widget.userId);

      if (ledgers.isEmpty) {
        setState(() {
          _isLoading = false;
          _incomeByCategory = {};
          _totalIncome = 0;
        });
        return;
      }

      final ledgerIds = List<String>.from(
        ledgers.map((l) => l['ledgerId'] as String),
      );

      // Calculate date range based on selected filter
      final now = DateTime.now();
      final DateTime startDate;

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

      // Fetch all income transactions for these ledgers
      List<dynamic> allTransactions = [];
      for (String ledgerId in ledgerIds) {
        final transactions = await Supabase.instance.client
            .from('Transaction')
            .select('*, Category(name)')
            .eq('ledgerId', ledgerId)
            .eq('type', 'income')
            .gte('date', startDate.toIso8601String());

        allTransactions.addAll(transactions);
      }

      // Group by category and sum amounts
      Map<String, double> income = {};
      double total = 0;

      for (var transaction in allTransactions) {
        String categoryName = transaction['Category']?['name'] ?? 'Others';
        double amount = (transaction['amount'] as num).toDouble();

        income[categoryName] = (income[categoryName] ?? 0) + amount;
        total += amount;
      }

      setState(() {
        _incomeByCategory = income;
        _totalIncome = total;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching income data: $e');
      setState(() => _isLoading = false);
    }
  }

  Color _getColorForCategory(String category) {
    return _categoryColors[category] ??
        Color((category.hashCode & 0xFFFFFF) | 0xFF000000);
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
          'Income Pie Chart',
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
                  // Pie Chart
                  if (_incomeByCategory.isNotEmpty)
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
                            SizedBox(
                              height: 250,
                              child: PieChart(
                                PieChartData(
                                  sections: _buildPieChartSections(),
                                  centerSpaceRadius: 70,
                                  sectionsSpace: 2,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Total: \$${_totalIncome.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Text(
                        'No income data for this period',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                    ),
                  const SizedBox(height: 20),
                  // Category List
                  if (_incomeByCategory.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          ..._incomeByCategory.entries
                              .toList()
                              .asMap()
                              .entries
                              .map((entry) {
                                int index = entry.key;
                                String category = entry.value.key;
                                double amount = entry.value.value;

                                return Column(
                                  children: [
                                    _buildCategoryItem(
                                      category,
                                      amount,
                                      _getColorForCategory(category),
                                    ),
                                    if (index <
                                        _incomeByCategory.entries.length - 1)
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
                              })
                              .toList(),
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
        await _fetchIncomeData();
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

  List<PieChartSectionData> _buildPieChartSections() {
    final entries = _incomeByCategory.entries.toList();

    return entries.map((entry) {
      String category = entry.key;
      double amount = entry.value;
      double percentage = (_totalIncome > 0)
          ? (amount / _totalIncome) * 100
          : 0;

      return PieChartSectionData(
        color: _getColorForCategory(category),
        value: amount,
        title: '${percentage.toStringAsFixed(0)}%',
        radius: 60,
        titleStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      );
    }).toList();
  }

  Widget _buildCategoryItem(String category, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              category,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
          Text(
            '\$${amount.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
