import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;

class ExpenseTrendReportPage2 extends StatefulWidget {
  final String userId;

  const ExpenseTrendReportPage2({Key? key, required this.userId})
    : super(key: key);

  @override
  State<ExpenseTrendReportPage2> createState() =>
      _ExpenseTrendReportPage2State();
}

class _ExpenseTrendReportPage2State extends State<ExpenseTrendReportPage2> {
  String _selectedFilter = 'month';
  late DateTime _selectedDate;

  List<Map<String, dynamic>> _trendData = [];
  double _maxAmount = 100;
  bool _isLoading = true;
  String _currencySymbol = '\$';

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _fetchCurrencySymbol();
    _fetchTrendData();
  }

  Future<void> _fetchCurrencySymbol() async {
    try {
      final userCurrency = await Supabase.instance.client
          .from('UserCurrency')
          .select('currencyId')
          .eq('userId', widget.userId)
          .maybeSingle();

      if (userCurrency != null) {
        final currencyId = userCurrency['currencyId'];

        final currency = await Supabase.instance.client
            .from('Currency')
            .select('symbol')
            .eq('currencyId', currencyId)
            .maybeSingle();

        if (currency != null) {
          setState(() {
            _currencySymbol = currency['symbol'] ?? '\$';
          });
        }
      }
    } catch (e) {
      print('Error fetching currency symbol: $e');
    }
  }

  Future<void> _fetchTrendData() async {
    try {
      final ledgers = await Supabase.instance.client
          .from('Ledger')
          .select()
          .eq('userId', widget.userId);

      if (ledgers.isEmpty) {
        setState(() {
          _isLoading = false;
          _trendData = [];
          _maxAmount = 100;
        });
        return;
      }

      final ledgerIds = List<String>.from(
        ledgers.map((l) => l['ledgerId'] as String),
      );

      final DateTime startDate;
      final DateTime endDate;

      switch (_selectedFilter) {
        case 'day':
          startDate = DateTime(
            _selectedDate.year,
            _selectedDate.month,
            _selectedDate.day,
          );
          endDate = startDate.add(const Duration(days: 1));
          break;
        case 'month':
          startDate = DateTime(_selectedDate.year, _selectedDate.month, 1);
          endDate = DateTime(_selectedDate.year, _selectedDate.month + 1, 1);
          break;
        case 'year':
          startDate = DateTime(_selectedDate.year, 1, 1);
          endDate = DateTime(_selectedDate.year + 1, 1, 1);
          break;
        default:
          startDate = DateTime(_selectedDate.year, _selectedDate.month, 1);
          endDate = DateTime(_selectedDate.year, _selectedDate.month + 1, 1);
      }

      List<dynamic> allTransactions = [];
      for (String ledgerId in ledgerIds) {
        final transactions = await Supabase.instance.client
            .from('Transaction')
            .select()
            .eq('ledgerId', ledgerId)
            .eq('refund', false)
            .gte('date', startDate.toIso8601String())
            .lt('date', endDate.toIso8601String());

        allTransactions.addAll(transactions);
      }

      // Process data based on filter type
      Map<String, Map<String, double>> dataMap = {};
      double maxAmount = 0;

      for (var transaction in allTransactions) {
        String dateStr = transaction['date'].toString();
        double amount = (transaction['amount'] as num).toDouble();
        String type = transaction['type'] ?? '';

        // Determine grouping key based on filter type
        String groupKey;
        if (_selectedFilter == 'day') {
          // For day view, group by time (hour:minute)
          DateTime dateTime = DateTime.parse(dateStr);
          groupKey = DateFormat('HH:mm').format(dateTime);
        } else if (_selectedFilter == 'month') {
          // For month view, group by day
          groupKey = dateStr.split('T')[0];
        } else {
          // For year view, group by month
          groupKey = dateStr.substring(0, 7); // YYYY-MM
        }

        if (!dataMap.containsKey(groupKey)) {
          dataMap[groupKey] = {'income': 0.0, 'expense': 0.0};
        }

        if (type == 'income') {
          dataMap[groupKey]!['income'] =
              (dataMap[groupKey]!['income'] ?? 0.0) + amount;
        } else if (type == 'expense') {
          dataMap[groupKey]!['expense'] =
              (dataMap[groupKey]!['expense'] ?? 0.0) + amount;
        }

        // Update max amount
        maxAmount = math.max(maxAmount, amount);
        maxAmount = math.max(maxAmount, dataMap[groupKey]!['income'] ?? 0);
        maxAmount = math.max(maxAmount, dataMap[groupKey]!['expense'] ?? 0);
      }

      // Convert to sorted list
      List<String> sortedKeys = dataMap.keys.toList();
      sortedKeys.sort();

      List<Map<String, dynamic>> trendData = [];
      for (String key in sortedKeys) {
        double income = dataMap[key]!['income'] ?? 0.0;
        double expense = dataMap[key]!['expense'] ?? 0.0;

        trendData.add({'key': key, 'income': income, 'expense': expense});
      }

      setState(() {
        _trendData = trendData;
        _maxAmount = _getRoundedMaxValue(maxAmount);
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

  String _formatDate(String dateStr) {
    if (_selectedFilter == 'day') {
      return dateStr; // Time format (HH:mm)
    } else if (_selectedFilter == 'month') {
      // Format as DD for day of month
      return dateStr.split('-')[2];
    } else {
      // Format as MMM for month
      String monthStr = dateStr.substring(5, 7);
      DateTime monthDate = DateTime(2024, int.parse(monthStr), 1);
      return DateFormat('MMM').format(monthDate);
    }
  }

  String _formatYAxisValue(double value) {
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}k';
    } else if (value >= 100) {
      return '${value.toInt()}';
    } else {
      return '${value.toStringAsFixed(0)}';
    }
  }

  double _getRoundedMaxValue(double maxValue) {
    if (maxValue == 0) return 100;

    // Round up to nearest nice number
    if (maxValue <= 100) {
      return (((maxValue / 50).ceil()) * 50).toDouble();
    } else if (maxValue <= 1000) {
      return (((maxValue / 100).ceil()) * 100).toDouble();
    } else if (maxValue <= 10000) {
      return (((maxValue / 1000).ceil()) * 1000).toDouble();
    } else {
      return (((maxValue / 5000).ceil()) * 5000).toDouble();
    }
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
          'Expense Trend Report',
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
                  // Date Picker Button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GestureDetector(
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
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
                        if (picked != null && picked != _selectedDate) {
                          setState(() {
                            _selectedDate = picked;
                            _isLoading = true;
                          });
                          await _fetchTrendData();
                        }
                      },
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
                              'Selected Date: ${_selectedDate.toLocal().toString().split(' ')[0]}',
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
                        _buildFilterButton('Day', 'day'),
                        _buildFilterButton('Month', 'month'),
                        _buildFilterButton('Year', 'year'),
                      ],
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
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Income vs Expense Trend',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 35),
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: SizedBox(
                                height: 380,
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          // Y-axis label and values column
                                          Column(
                                            children: [
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  bottom: 12,
                                                ),
                                                child: Text(
                                                  'Amount ($_currencySymbol)',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey[600],
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                child: SizedBox(
                                                  width: 60,
                                                  child: Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.end,
                                                    children: [
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets.only(
                                                              right: 8,
                                                            ),
                                                        child: Text(
                                                          _formatYAxisValue(
                                                            _maxAmount,
                                                          ),
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            color: Colors
                                                                .grey[600],
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                        ),
                                                      ),
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets.only(
                                                              right: 8,
                                                            ),
                                                        child: Text(
                                                          _formatYAxisValue(
                                                            _maxAmount * 0.75,
                                                          ),
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            color: Colors
                                                                .grey[600],
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                        ),
                                                      ),
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets.only(
                                                              right: 8,
                                                            ),
                                                        child: Text(
                                                          _formatYAxisValue(
                                                            _maxAmount * 0.5,
                                                          ),
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            color: Colors
                                                                .grey[600],
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                        ),
                                                      ),
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets.only(
                                                              right: 8,
                                                            ),
                                                        child: Text(
                                                          _formatYAxisValue(
                                                            _maxAmount * 0.25,
                                                          ),
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            color: Colors
                                                                .grey[600],
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                        ),
                                                      ),
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets.only(
                                                              right: 8,
                                                            ),
                                                        child: Text(
                                                          '0',
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            color: Colors
                                                                .grey[600],
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(width: 8),
                                          // Scrollable chart
                                          Expanded(
                                            child: SingleChildScrollView(
                                              scrollDirection: Axis.horizontal,
                                              child: SizedBox(
                                                width: _trendData.length > 10
                                                    ? _trendData.length * 60.0
                                                    : MediaQuery.of(
                                                            context,
                                                          ).size.width -
                                                          150,
                                                child: LineChart(
                                                  LineChartData(
                                                    gridData: FlGridData(
                                                      show: true,
                                                      drawVerticalLine: true,
                                                      horizontalInterval: null,
                                                      verticalInterval: null,
                                                      getDrawingHorizontalLine:
                                                          (value) {
                                                            return FlLine(
                                                              color: Colors
                                                                  .grey[300]!,
                                                              strokeWidth: 0.5,
                                                            );
                                                          },
                                                      getDrawingVerticalLine:
                                                          (value) {
                                                            return FlLine(
                                                              color: Colors
                                                                  .grey[200]!,
                                                              strokeWidth: 0.5,
                                                            );
                                                          },
                                                    ),
                                                    titlesData: FlTitlesData(
                                                      topTitles: AxisTitles(
                                                        sideTitles: SideTitles(
                                                          showTitles: false,
                                                        ),
                                                        axisNameSize: 30,
                                                      ),
                                                      rightTitles: AxisTitles(
                                                        sideTitles: SideTitles(
                                                          showTitles: false,
                                                        ),
                                                      ),
                                                      bottomTitles: AxisTitles(
                                                        axisNameWidget: Text(
                                                          _selectedFilter ==
                                                                  'day'
                                                              ? 'Time'
                                                              : _selectedFilter ==
                                                                    'month'
                                                              ? 'Date'
                                                              : 'Month',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: Colors
                                                                .grey[600],
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                        ),
                                                        axisNameSize: 20,
                                                        sideTitles: SideTitles(
                                                          showTitles: true,
                                                          interval:
                                                              (_trendData
                                                                      .length >
                                                                  15)
                                                              ? 4
                                                              : (_trendData
                                                                        .length >
                                                                    10)
                                                              ? 3
                                                              : (_trendData
                                                                        .length >
                                                                    7)
                                                              ? 2
                                                              : 1,
                                                          reservedSize: 50,
                                                          getTitlesWidget: (value, meta) {
                                                            int index = value
                                                                .toInt();
                                                            if (index >= 0 &&
                                                                index <
                                                                    _trendData
                                                                        .length) {
                                                              String dateStr =
                                                                  _trendData[index]['key'];
                                                              String formatted =
                                                                  _formatDate(
                                                                    dateStr,
                                                                  );
                                                              return Transform.rotate(
                                                                angle: -0.5,
                                                                child: Padding(
                                                                  padding:
                                                                      const EdgeInsets.only(
                                                                        top: 12,
                                                                      ),
                                                                  child: Text(
                                                                    formatted,
                                                                    style: TextStyle(
                                                                      fontSize:
                                                                          11,
                                                                      color: Colors
                                                                          .grey[600],
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w500,
                                                                    ),
                                                                  ),
                                                                ),
                                                              );
                                                            }
                                                            return const Text(
                                                              '',
                                                            );
                                                          },
                                                        ),
                                                      ),
                                                      leftTitles: AxisTitles(
                                                        sideTitles: SideTitles(
                                                          showTitles: false,
                                                        ),
                                                      ),
                                                    ),
                                                    borderData: FlBorderData(
                                                      show: true,
                                                      border: Border(
                                                        bottom: BorderSide(
                                                          color:
                                                              Colors.grey[300]!,
                                                          width: 1,
                                                        ),
                                                        left: BorderSide(
                                                          color:
                                                              Colors.grey[300]!,
                                                          width: 1,
                                                        ),
                                                      ),
                                                    ),
                                                    lineBarsData: [
                                                      LineChartBarData(
                                                        spots:
                                                            _getIncomeSpots(),
                                                        isCurved: true,
                                                        curveSmoothness: 0.2,
                                                        color: const Color(
                                                          0xFF4CAF50,
                                                        ),
                                                        barWidth: 2.5,
                                                        isStrokeCapRound: true,
                                                        dotData: FlDotData(
                                                          show: true,
                                                          getDotPainter:
                                                              (
                                                                spot,
                                                                percent,
                                                                barData,
                                                                index,
                                                              ) {
                                                                return FlDotCirclePainter(
                                                                  radius: 2.5,
                                                                  color: const Color(
                                                                    0xFF4CAF50,
                                                                  ),
                                                                  strokeWidth:
                                                                      1,
                                                                  strokeColor:
                                                                      Colors
                                                                          .white,
                                                                );
                                                              },
                                                        ),
                                                        belowBarData:
                                                            BarAreaData(
                                                              show: true,
                                                              color:
                                                                  const Color(
                                                                    0xFF4CAF50,
                                                                  ).withOpacity(
                                                                    0.12,
                                                                  ),
                                                              cutOffY: 0,
                                                              applyCutOffY:
                                                                  true,
                                                            ),
                                                      ),
                                                      LineChartBarData(
                                                        spots:
                                                            _getExpenseSpots(),
                                                        isCurved: true,
                                                        curveSmoothness: 0.2,
                                                        color: const Color(
                                                          0xFFF44336,
                                                        ),
                                                        barWidth: 2.5,
                                                        isStrokeCapRound: true,
                                                        dotData: FlDotData(
                                                          show: true,
                                                          getDotPainter:
                                                              (
                                                                spot,
                                                                percent,
                                                                barData,
                                                                index,
                                                              ) {
                                                                return FlDotCirclePainter(
                                                                  radius: 2.5,
                                                                  color: const Color(
                                                                    0xFFF44336,
                                                                  ),
                                                                  strokeWidth:
                                                                      1,
                                                                  strokeColor:
                                                                      Colors
                                                                          .white,
                                                                );
                                                              },
                                                        ),
                                                        belowBarData:
                                                            BarAreaData(
                                                              show: true,
                                                              color:
                                                                  const Color(
                                                                    0xFFF44336,
                                                                  ).withOpacity(
                                                                    0.12,
                                                                  ),
                                                              cutOffY: 0,
                                                              applyCutOffY:
                                                                  true,
                                                            ),
                                                      ),
                                                    ],
                                                    minX: 0,
                                                    maxX:
                                                        (_trendData.length - 1)
                                                            .toDouble(),
                                                    minY: 0,
                                                    maxY: _maxAmount,
                                                  ),
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
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 14,
                                        height: 14,
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
                                        width: 14,
                                        height: 14,
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
                  const SizedBox(height: 30),
                ],
              ),
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
}
