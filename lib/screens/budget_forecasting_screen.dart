import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/budget_forecast_service.dart';
import 'package:intl/intl.dart';

class BudgetForecastingScreen extends StatefulWidget {
  final String userId;
  final String? ledgerId;

  const BudgetForecastingScreen({
    super.key,
    required this.userId,
    this.ledgerId,
  });

  @override
  State<BudgetForecastingScreen> createState() =>
      _BudgetForecastingScreenState();
}

class _BudgetForecastingScreenState extends State<BudgetForecastingScreen> {
  final _forecastService = BudgetForecastService();
  List<Map<String, dynamic>> _budgets = [];
  bool _isLoading = true;
  String? _selectedBudgetId;
  Map<String, dynamic>? _selectedBudget;
  List<ForecastResult>? _forecastResults;
  List<HistoricalSpending>? _historicalData;
  bool _showForecast = false;

  @override
  void initState() {
    super.initState();
    _fetchBudgets();
  }

  Future<void> _fetchBudgets() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final response = await Supabase.instance.client
          .from('Budget')
          .select()
          .eq('userId', widget.userId)
          .order('budgetId', ascending: false);

      setState(() {
        _budgets = List<Map<String, dynamic>>.from(response);
        if (_budgets.isNotEmpty) {
          _selectedBudgetId = _budgets[0]['budgetId'];
          _selectedBudget = _budgets[0];
          _loadForecast();
        }
      });
    } catch (e) {
      print('Error fetching budgets: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading budgets: $e')));
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadForecast() async {
    if (_selectedBudget == null) return;

    try {
      setState(() {
        _showForecast = false;
      });

      final forecast = await _forecastService.getForecast(
        widget.userId,
        _selectedBudget!['budgetId'],
        _selectedBudget!['accountId'],
        _selectedBudget!['categoryId'],
        _selectedBudget!['ledgerId'],
        3, // Forecast next 3 months
      );

      final historical = await _forecastService.getHistoricalData(
        widget.userId,
        _selectedBudget!['budgetId'],
        _selectedBudget!['accountId'],
        _selectedBudget!['categoryId'],
        _selectedBudget!['ledgerId'],
      );

      setState(() {
        _forecastResults = forecast;
        _historicalData = historical;
        _showForecast = true;
      });
    } catch (e) {
      print('Error loading forecast: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading forecast: $e')));
    }
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
              'Budget Forecasting',
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _budgets.isEmpty
          ? const Center(
              child: Text('No budgets found. Create one to get started!'),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Budget Selector
                  _buildBudgetSelector(),
                  const SizedBox(height: 24),

                  if (_showForecast && _forecastResults != null) ...[
                    // High Risk Alert (Display only when high risk)
                    FutureBuilder<bool>(
                      future: _checkHighRisk(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const SizedBox.shrink();
                        }

                        if (snapshot.data == true) {
                          return _buildHighRiskAlert();
                        }
                        return const SizedBox.shrink();
                      },
                    ),

                    // Forecast Summary
                    _buildForecastSummary(),
                    const SizedBox(height: 24),

                    // Forecast Details
                    _buildForecastDetails(),
                    const SizedBox(height: 24),

                    // Historical Data
                    _buildHistoricalDataSection(),
                    const SizedBox(height: 24),

                    // Accuracy Metrics
                    _buildAccuracyMetrics(),
                  ] else if (!_showForecast)
                    const Center(child: CircularProgressIndicator()),
                ],
              ),
            ),
    );
  }

  Widget _buildBudgetSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Budget',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300] ?? Colors.grey),
          ),
          child: DropdownButton<String>(
            value: _selectedBudgetId,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            items: _budgets.map((budget) {
              final name = budget['id'] ?? budget['budgetId'] ?? 'Unknown';
              final type = budget['type'] ?? '';
              return DropdownMenuItem<String>(
                value: budget['budgetId'],
                child: Text('$name ($type)'),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedBudgetId = value;
                  _selectedBudget = _budgets.firstWhere(
                    (b) => b['budgetId'] == value,
                  );
                  _forecastResults = null;
                  _historicalData = null;
                });
                _loadForecast();
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHighRiskAlert() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE53935), width: 2),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_rounded, color: Color(0xFFE53935), size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'High Risk Alert',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE53935),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Forecasted expenses may exceed your budget next month',
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForecastSummary() {
    if (_forecastResults == null || _forecastResults!.isEmpty) {
      return const SizedBox.shrink();
    }

    final nextMonth = _forecastResults![0];
    final budgetAmount = (_selectedBudget!['amount'] ?? 0).toDouble();
    final exceedsPercentage = (nextMonth.forecastedAmount / budgetAmount * 100)
        .toStringAsFixed(1);

    return Container(
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
            'Next Month Forecast',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          if (nextMonth.isLimitedData) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Color(0xFFFFF3CD),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Color(0xFFFFEC99), width: 1),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Color(0xFF856404),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Based on limited available data. More historical data will improve accuracy.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF856404),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Forecasted Amount',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'RM${nextMonth.forecastedAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Budget Limit',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'RM${budgetAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Expected Usage',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
                Text(
                  '$exceedsPercentage%',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: nextMonth.forecastedAmount > budgetAmount
                        ? const Color(0xFFE53935)
                        : Colors.green,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForecastDetails() {
    if (_forecastResults == null || _forecastResults!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Forecast Details (3 Months)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 12),
        ..._forecastResults!.map((forecast) {
          final dateFormat = DateFormat('MMM yyyy');
          return Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200] ?? Colors.grey),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateFormat.format(forecast.date),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Confidence: ${((1 - (forecast.upperBound - forecast.lowerBound) / (2 * forecast.forecastedAmount)) * 100).toStringAsFixed(0)}%',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'RM${forecast.forecastedAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Range: RM${forecast.lowerBound.toStringAsFixed(2)} - RM${forecast.upperBound.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildHistoricalDataSection() {
    if (_historicalData == null || _historicalData!.isEmpty) {
      return const SizedBox.shrink();
    }

    final avgHistorical =
        _historicalData!.fold(0.0, (sum, h) => sum + h.amount) /
        _historicalData!.length;

    return Container(
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
            'Historical Data (12 Months)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Average Monthly Spending',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'RM${avgHistorical.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Total Data Points',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_historicalData!.length} months',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccuracyMetrics() {
    return FutureBuilder<double>(
      future: _forecastService.calculateForecastAccuracy(
        widget.userId,
        _selectedBudget!['budgetId'],
        _selectedBudget!['accountId'],
        _selectedBudget!['categoryId'],
        _selectedBudget!['ledgerId'],
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || snapshot.data == null || snapshot.data! < 0) {
          // Check if we're using limited data forecast
          final isLimitedData =
              _forecastResults != null &&
              _forecastResults!.isNotEmpty &&
              _forecastResults![0].isLimitedData;

          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              isLimitedData
                  ? 'Forecast based on limited available data. Accuracy will improve with more history.'
                  : 'Not enough historical data to calculate accuracy',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          );
        }

        final mae = snapshot.data!;

        return Container(
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
                'Forecast Accuracy',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mean Absolute Error (MAE)',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'RM${mae.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'The forecast typically deviates by RM${mae.toStringAsFixed(2)} from actual spending',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<bool> _checkHighRisk() async {
    if (_selectedBudget == null) return false;

    return await _forecastService.checkHighRiskAlert(
      widget.userId,
      _selectedBudget!['budgetId'],
      (_selectedBudget!['amount'] ?? 0).toDouble(),
      _selectedBudget!['accountId'],
      _selectedBudget!['categoryId'],
      _selectedBudget!['ledgerId'],
    );
  }
}
