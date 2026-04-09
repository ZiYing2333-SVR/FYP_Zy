import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;

class ExpenseTrendsPage extends StatefulWidget {
  final String userId;

  const ExpenseTrendsPage({Key? key, required this.userId}) : super(key: key);

  @override
  State<ExpenseTrendsPage> createState() => _ExpenseTrendsPageState();
}

class _ExpenseTrendsPageState extends State<ExpenseTrendsPage> {
  int _selectedIndex = 4;
  String _selectedFilter = 'month';
  late DateTime _selectedDate;

  List<Map<String, dynamic>> _trendData = [];
  double _totalIncome = 0;
  double _totalExpense = 0;
  bool _isLoading = true;
  String _currencySymbol = '\$';
  bool _hasBudgetCaution = false;
  bool _hasBudgetAlert = false;
  bool _alertsShownThisSession = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _fetchCurrencySymbol();
    _fetchTrendData();
    _initializeAlerts();
  }

  Future<void> _initializeAlerts() async {
    await _checkBudgetAlerts();
    await _checkBudgetCaution();

    if (mounted && !_alertsShownThisSession) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _alertsShownThisSession = true;
          if (_hasBudgetCaution) {
            _showCautionAlertDialog();
          } else if (_hasBudgetAlert) {
            _showAlertDialog();
          }
        }
      });
    }
  }

  Future<void> _fetchCurrencySymbol() async {
    try {
      // Fetch user's currency from UserCurrency table
      final userCurrency = await Supabase.instance.client
          .from('UserCurrency')
          .select('currencyId')
          .eq('userId', widget.userId)
          .maybeSingle();

      if (userCurrency != null) {
        final currencyId = userCurrency['currencyId'];

        // Fetch currency symbol from Currency table
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
      // Keep default currency symbol
    }
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

      // Calculate date range based on selected filter and selected date
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
        case 'week':
          final weekStart = _selectedDate.subtract(
            Duration(days: _selectedDate.weekday - 1),
          );
          startDate = DateTime(weekStart.year, weekStart.month, weekStart.day);
          endDate = startDate.add(const Duration(days: 7));
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

      // Fetch all transactions for these ledgers
      List<dynamic> allTransactions = [];
      for (String ledgerId in ledgerIds) {
        final transactions = await Supabase.instance.client
            .from('Transaction')
            .select()
            .eq('ledgerId', ledgerId)
            .gte('date', startDate.toIso8601String())
            .lt('date', endDate.toIso8601String());

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

  double _getMaxValue() {
    double maxValue = 0;
    for (var data in _trendData) {
      maxValue = math.max(maxValue, data['income'] as double);
      maxValue = math.max(maxValue, data['expense'] as double);
    }
    return maxValue > 0 ? maxValue : 100;
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

  Future<void> _checkBudgetAlerts() async {
    try {
      final budgets = await Supabase.instance.client
          .from('Budget')
          .select()
          .eq('userId', widget.userId);

      bool hasAlert = false;
      for (var budget in budgets) {
        final isAlert = budget['isAlert'] ?? false;
        if (isAlert) {
          hasAlert = true;
          break;
        }
      }

      setState(() {
        _hasBudgetAlert = hasAlert;
      });
    } catch (e) {
      print('Error checking budget alerts: $e');
    }
  }

  Future<void> _checkBudgetCaution() async {
    try {
      final budgets = await Supabase.instance.client
          .from('Budget')
          .select()
          .eq('userId', widget.userId);

      bool hasCaution = false;
      for (var budget in budgets) {
        final isWarning = budget['isWarning'] ?? false;
        if (isWarning) {
          hasCaution = true;
          break;
        }
      }

      setState(() {
        _hasBudgetCaution = hasCaution;
      });
    } catch (e) {
      print('Error checking budget caution: $e');
    }
  }

  void _showCautionAlertDialog() {
    bool checkboxValue = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.orange.shade700,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Budget Caution',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Your budget spending is over 70%. Please monitor your expenses to avoid exceeding your budget.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Checkbox(
                            value: checkboxValue,
                            onChanged: (newValue) {
                              setDialogState(() {
                                checkboxValue = newValue ?? false;
                              });
                            },
                            activeColor: Colors.orange.shade700,
                          ),
                          const Expanded(
                            child: Text(
                              'I understand, don\'t show this again',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey[300],
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Close',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: checkboxValue
                                  ? () {
                                      Navigator.pop(context);
                                    }
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange.shade700,
                                disabledBackgroundColor: Colors.grey[400],
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Confirm',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAlertDialog() {
    bool checkboxValue = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFE5E5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.error_rounded,
                          color: Color(0xFFE53935),
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Budget Alert',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Your budget has been exceeded! Please review your expenses immediately.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Checkbox(
                            value: checkboxValue,
                            onChanged: (newValue) {
                              setDialogState(() {
                                checkboxValue = newValue ?? false;
                              });
                            },
                            activeColor: const Color(0xFFE53935),
                          ),
                          const Expanded(
                            child: Text(
                              'I understand, don\'t show this again',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey[300],
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Close',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: checkboxValue
                                  ? () {
                                      Navigator.pop(context);
                                    }
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE53935),
                                disabledBackgroundColor: Colors.grey[400],
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Confirm',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<Widget> _buildNavBadges() {
    // Position badge only on Settings icon (index 4)
    final badges = <Widget>[];
    const badgeSize = 20.0;
    const badgeTopOffset = 8.0;
    const badgeRightOffset = 12.0;

    if (!(_hasBudgetCaution || _hasBudgetAlert)) {
      return badges;
    }

    // Show isAlert (YELLOW) badge
    if (_hasBudgetAlert) {
      badges.add(
        Positioned(
          right: badgeRightOffset,
          top: badgeTopOffset,
          child: Container(
            width: badgeSize,
            height: badgeSize,
            decoration: BoxDecoration(
              color: Colors.orange.shade700, // YELLOW for isAlert
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(Icons.warning_rounded, color: Colors.white, size: 12),
            ),
          ),
        ),
      );
    }

    // Show isWarning (RED) badge
    if (_hasBudgetCaution) {
      badges.add(
        Positioned(
          right: badgeRightOffset,
          top: badgeTopOffset,
          child: Container(
            width: badgeSize,
            height: badgeSize,
            decoration: const BoxDecoration(
              color: Color(0xFFE53935), // RED for isWarning
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text(
                '!',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return badges;
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
                        _buildFilterButton('Today', 'day'),
                        _buildFilterButton('This Month', 'month'),
                        _buildFilterButton('This Year', 'year'),
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
                                  '$_currencySymbol${_totalIncome.toStringAsFixed(2)}',
                                  const Color(0xFF4CAF50),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildSummaryItem(
                                  'Expense',
                                  '$_currencySymbol${_totalExpense.toStringAsFixed(2)}',
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
                                  '${(_totalIncome - _totalExpense) >= 0 ? '+' : ''}$_currencySymbol${(_totalIncome - _totalExpense).toStringAsFixed(2)}',
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
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Income vs Expense Trends',
                                  style: TextStyle(
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
                                    // Chart with fixed y-axis
                                    Expanded(
                                      child: Row(
                                        children: [
                                          // Y-axis label and values column
                                          Column(
                                            children: [
                                              // Label above axis
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
                                              // Y-axis values
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
                                                            _getMaxValue(),
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
                                                            _getMaxValue() *
                                                                0.75,
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
                                                            _getMaxValue() *
                                                                0.5,
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
                                                            _getMaxValue() *
                                                                0.25,
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
                                                          'Date',
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
                                                              String date =
                                                                  _trendData[index]['date'];
                                                              // Show MM/DD format
                                                              String
                                                              formattedDate =
                                                                  date.substring(
                                                                    5,
                                                                    10,
                                                                  );
                                                              return Transform.rotate(
                                                                angle: -0.5,
                                                                child: Padding(
                                                                  padding:
                                                                      const EdgeInsets.only(
                                                                        top: 12,
                                                                      ),
                                                                  child: Text(
                                                                    formattedDate,
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
                                                        curveSmoothness: 0.3,
                                                        color: const Color(
                                                          0xFF4CAF50,
                                                        ),
                                                        barWidth: 3,
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
                                                                  radius: 3,
                                                                  color: const Color(
                                                                    0xFF4CAF50,
                                                                  ),
                                                                  strokeWidth:
                                                                      1.5,
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
                                                                    0.15,
                                                                  ),
                                                            ),
                                                      ),
                                                      LineChartBarData(
                                                        spots:
                                                            _getExpenseSpots(),
                                                        isCurved: true,
                                                        curveSmoothness: 0.3,
                                                        color: const Color(
                                                          0xFFF44336,
                                                        ),
                                                        barWidth: 3,
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
                                                                  radius: 3,
                                                                  color: const Color(
                                                                    0xFFF44336,
                                                                  ),
                                                                  strokeWidth:
                                                                      1.5,
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
                                                                    0.15,
                                                                  ),
                                                            ),
                                                      ),
                                                    ],
                                                    minX: 0,
                                                    maxX:
                                                        (_trendData.length - 1)
                                                            .toDouble(),
                                                    minY: 0,
                                                    maxY: _getMaxValue() * 1.1,
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
                                _buildDailyDetailItem(data, _currencySymbol),
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
          // Build badges for multiple nav icons
          ..._buildNavBadges(),
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

  Widget _buildDailyDetailItem(
    Map<String, dynamic> data,
    String currencySymbol,
  ) {
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
                '$currencySymbol${income.toStringAsFixed(2)}',
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
                '$currencySymbol${expense.toStringAsFixed(2)}',
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
                  '${net >= 0 ? '+' : ''}$currencySymbol${net.toStringAsFixed(2)}',
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
