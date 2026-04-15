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
  List<Map<String, dynamic>> _monthlyBudgets = [];
  bool _isLoading = true;
  String? _selectedBudgetId;
  Map<String, dynamic>? _selectedBudget;
  List<ForecastResult>? _forecastResults;
  List<HistoricalSpending>? _historicalData;
  OverspendAnalysis? _overspendAnalysis;
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

      // Filter only monthly budgets for forecasting
      final allBudgets = List<Map<String, dynamic>>.from(response);
      final monthlyBudgets = allBudgets
          .where(
            (b) => (b['cycleType'] ?? '').toString().toLowerCase() == 'month',
          )
          .toList();

      // Fetch related names (Category, Account, Ledger) for better display
      for (var budget in monthlyBudgets) {
        String displayName = 'Unknown Budget';

        // Try to fetch category name
        if (budget['categoryId'] != null) {
          try {
            final categoryRes = await Supabase.instance.client
                .from('Category')
                .select('name')
                .eq('categoryId', budget['categoryId'])
                .single();
            displayName = categoryRes['name'] ?? 'Unknown';
          } catch (e) {
            print('Error fetching category: $e');
          }
        }
        // If no category, try account
        else if (budget['accountId'] != null) {
          try {
            final accountRes = await Supabase.instance.client
                .from('Account')
                .select('accountName')
                .eq('accountId', budget['accountId'])
                .single();
            displayName = accountRes['accountName'] ?? 'Unknown';
          } catch (e) {
            print('Error fetching account: $e');
          }
        }
        // If no category or account, try ledger
        else if (budget['ledgerId'] != null) {
          try {
            final ledgerRes = await Supabase.instance.client
                .from('Ledger')
                .select('name')
                .eq('ledgerId', budget['ledgerId'])
                .single();
            displayName = ledgerRes['name'] ?? 'Unknown';
          } catch (e) {
            print('Error fetching ledger: $e');
          }
        }

        // Store the display name in the budget map
        budget['displayName'] = displayName;
      }

      setState(() {
        _budgets = allBudgets;
        _monthlyBudgets = monthlyBudgets;
        if (_monthlyBudgets.isNotEmpty) {
          _selectedBudgetId = _monthlyBudgets[0]['budgetId'];
          _selectedBudget = _monthlyBudgets[0];
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

      // Calculate overspend analysis
      final overspendAnalysis = await _forecastService
          .calculateOverspendAnalysis(
            widget.userId,
            _selectedBudget!['budgetId'],
            (_selectedBudget!['amount'] ?? 0).toDouble(),
            _selectedBudget!['cycleType'],
            _selectedBudget!['accountId'],
            _selectedBudget!['categoryId'],
            _selectedBudget!['ledgerId'],
            null, // Will be calculated
            forecast.isNotEmpty ? forecast.first.forecastedAmount : null,
          );

      setState(() {
        _forecastResults = forecast;
        _historicalData = historical;
        _overspendAnalysis = overspendAnalysis;
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
          : _monthlyBudgets.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.calendar_month,
                    size: 64,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No Monthly Budgets Found',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Forecasting is available only for monthly budgets.',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create a monthly budget to get started with forecasting.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Note about monthly budgets
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8DC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFFFE4B5),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Color(0xFFA37F20),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Forecasting is available only for monthly budgets.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Budget Selector
                  _buildBudgetSelector(),
                  const SizedBox(height: 24),

                  if (_showForecast && _overspendAnalysis != null) ...[
                    // Visual Dashboard
                    _buildSpendingVisualization(),
                    const SizedBox(height: 24),

                    // Overspend Analysis Card
                    _buildOverspendAnalysisCard(),
                    const SizedBox(height: 24),

                    // Spending Suggestions
                    _buildSpendingSuggestionsSection(),
                    const SizedBox(height: 24),

                    // Alert (Display based on forecast - normal, warning, or critical)
                    if (_forecastResults!.isNotEmpty) _buildHighRiskAlert(),
                    if (_forecastResults!.isNotEmpty)
                      const SizedBox(height: 16),

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
    // Budget Selector: Let users choose which budget to analyze
    // This helps track multiple budget categories separately
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Monthly Budget',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Choose a budget to view its spending forecast and analysis',
          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF9E6),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFFFE5B4), width: 2),
          ),
          child: DropdownButton<String>(
            value: _selectedBudgetId,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            items: _monthlyBudgets.map((budget) {
              final displayName = budget['displayName'] ?? 'Unknown Budget';
              final isSelected = budget['budgetId'] == _selectedBudgetId;
              return DropdownMenuItem<String>(
                value: budget['budgetId'],
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFA7E399).withOpacity(0.2)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.wallet,
                        size: 18,
                        color: isSelected
                            ? const Color(0xFFA7E399)
                            : Colors.grey[600],
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          displayName,
                          softWrap: true,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isSelected
                                ? const Color(0xFFA7E399)
                                : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedBudgetId = value;
                  _selectedBudget = _monthlyBudgets.firstWhere(
                    (b) => b['budgetId'] == value,
                  );
                  _forecastResults = null;
                  _historicalData = null;
                  _overspendAnalysis = null;
                });
                _loadForecast();
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSpendingVisualization() {
    if (_overspendAnalysis == null) {
      return const SizedBox.shrink();
    }

    final analysis = _overspendAnalysis!;
    final budgetPercent = (analysis.budgetAmount / analysis.budgetAmount).clamp(
      0.0,
      1.0,
    );
    final currentPercent = (analysis.currentMonthUsage / analysis.budgetAmount)
        .clamp(0.0, 1.0);
    final forecastPercent =
        (analysis.forecastedMonthUsage / analysis.budgetAmount).clamp(0.0, 1.0);

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
            'Spending Pattern Dashboard',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Visual overview of your spending compared to budget limit',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
              const SizedBox(height: 4),
              Text(
                '📅 THIS MONTH ONLY (resets on 1st of each month)',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.orange[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Budget Limit Line - Shows your total budget amount
          Text(
            'Budget Limit: RM${analysis.budgetAmount.toStringAsFixed(2)}',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          Text(
            'The maximum amount you set for this budget',
            style: TextStyle(fontSize: 10, color: Colors.grey[500]),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: budgetPercent,
              minHeight: 6,
              backgroundColor: Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
          ),
          const SizedBox(height: 12),
          // Current Month Spending - What you've already spent this month
          Text(
            'Current Month: RM${analysis.currentMonthUsage.toStringAsFixed(2)}',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          Text(
            'Amount you have spent so far IN THIS MONTH',
            style: TextStyle(fontSize: 10, color: Colors.grey[500]),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: currentPercent,
              minHeight: 8,
              backgroundColor: Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
            ),
          ),
          const SizedBox(height: 12),
          // Forecasted Spending - AI prediction of total spending by month end
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This Month Forecast: RM${analysis.forecastedMonthUsage.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    Text(
                      'AI prediction: Your total spending by end of THIS MONTH ONLY',
                      style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Based on your historical spending patterns, NOT just multiplying current spending',
                        softWrap: true,
                        style: TextStyle(fontSize: 9, color: Colors.blue[700]),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: analysis.riskLevel == 'critical'
                      ? Colors.red.shade100
                      : analysis.riskLevel == 'high'
                      ? Colors.orange.shade100
                      : analysis.riskLevel == 'medium'
                      ? Colors.yellow.shade100
                      : Colors.green.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Tooltip(
                  message: analysis.riskLevel == 'critical'
                      ? 'High chance of exceeding budget'
                      : analysis.riskLevel == 'high'
                      ? 'Warning: You may exceed budget'
                      : analysis.riskLevel == 'medium'
                      ? 'Moderate risk of overspending'
                      : 'On track with budget',
                  child: Text(
                    analysis.riskLevel.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: analysis.riskLevel == 'critical'
                          ? Colors.red.shade700
                          : analysis.riskLevel == 'high'
                          ? Colors.orange.shade700
                          : analysis.riskLevel == 'medium'
                          ? Colors.yellow.shade700
                          : Colors.green.shade700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: forecastPercent,
              minHeight: 8,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                analysis.riskLevel == 'critical'
                    ? Colors.red
                    : analysis.riskLevel == 'high'
                    ? Colors.orange
                    : analysis.riskLevel == 'medium'
                    ? Colors.yellow.shade600
                    : Colors.green,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverspendAnalysisCard() {
    // Overspend Analysis: Shows if you're likely to exceed budget and by how much
    // This helps you understand your financial risk for the current cycle
    if (_overspendAnalysis == null) {
      return const SizedBox.shrink();
    }

    final analysis = _overspendAnalysis!;
    final isOverspending = analysis.overspendPercentage > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isOverspending ? Colors.red.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOverspending ? Colors.red.shade200 : Colors.green.shade200,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Overspend Analysis',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Will you exceed your MONTHLY budget this month?',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isOverspending
                      ? Colors.red.shade600
                      : Colors.green.shade600,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Tooltip(
                  message: analysis.overspendPercentage > 0
                      ? 'How much over budget you will go (%)'
                      : 'You are on track! 0% means no overspending projected',
                  child: Text(
                    '${analysis.overspendPercentage.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Important note about monthly budgets
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.blue[200] ?? Colors.blue,
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: Colors.blue[700], size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "📅 Note: This is a MONTHLY budget. It resets on the 1st of each month. Your spending from previous months does not affect THIS month's analysis.",
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.blue[700],
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (isOverspending)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Warning: You will likely overspend by RM${analysis.overspendAmount.toStringAsFixed(2)} this month',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Consider reducing spending to stay within your RM${analysis.budgetAmount.toStringAsFixed(2)} budget',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.red.shade600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '✓ You are on track to stay within budget this month! 🎉',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '0% overspend = No overspending is predicted for THIS MONTH',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.green.shade600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Budget Limit',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                  Text(
                    'Max allowed for this month',
                    style: TextStyle(fontSize: 9, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'RM${analysis.budgetAmount.toStringAsFixed(2)}',
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
                    'Projected Spending',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'RM${analysis.forecastedMonthUsage.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isOverspending
                          ? Colors.red.shade600
                          : Colors.black,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpendingSuggestionsSection() {
    // Smart Suggestions: AI-generated tips to help reduce spending
    // Red badges = high priority, Orange = medium priority, Blue = general tips
    if (_overspendAnalysis == null || _overspendAnalysis!.suggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    final suggestions = _overspendAnalysis!.suggestions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Smart Spending Suggestions',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Personalized tips to help you stay within budget (sorted by priority)',
          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
        ),
        const SizedBox(height: 12),
        ...suggestions.map((suggestion) {
          final color = suggestion.priority >= 4
              ? Colors.red.shade50
              : suggestion.priority >= 3
              ? Colors.orange.shade50
              : Colors.blue.shade50;

          final borderColor = suggestion.priority >= 4
              ? Colors.red.shade200
              : suggestion.priority >= 3
              ? Colors.orange.shade200
              : Colors.blue.shade200;

          final iconColor = suggestion.priority >= 4
              ? Colors.red.shade600
              : suggestion.priority >= 3
              ? Colors.orange.shade600
              : Colors.blue.shade600;

          final priorityLabel = suggestion.priority >= 4
              ? 'HIGH PRIORITY'
              : suggestion.priority >= 3
              ? 'MEDIUM PRIORITY'
              : 'TIP';

          return Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      suggestion.priority >= 4
                          ? Icons.priority_high
                          : suggestion.priority >= 3
                          ? Icons.warning_rounded
                          : Icons.lightbulb_rounded,
                      color: iconColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            suggestion.title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            priorityLabel,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: iconColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  suggestion.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildHighRiskAlert() {
    if (_forecastResults == null || _forecastResults!.isEmpty) {
      return const SizedBox.shrink();
    }

    final forecast = _forecastResults![0];
    final alertStatus = forecast.alertStatus;
    final alertMessage = forecast.alertMessage;

    if (alertStatus == 'normal') {
      // Show green success alert
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F8E9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF7CB342), width: 2),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF7CB342),
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'On Track',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF7CB342),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    alertMessage,
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else if (alertStatus == 'warning') {
      // Show orange warning alert
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF39C12), width: 2),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.warning_rounded,
              color: Color(0xFFF39C12),
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Budget Warning',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFF39C12),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    alertMessage,
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      // Critical alert
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEBEE),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE53935), width: 2),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_rounded, color: Color(0xFFE53935), size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Critical Alert',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFE53935),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    alertMessage,
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildForecastSummary() {
    // Next Month Forecast: Shows predicted spending for the upcoming month
    // Based on your historical spending patterns
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
          Column(
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
              const SizedBox(height: 2),
              Text(
                'AI prediction of how much you will spend next month',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.amber[200] ?? Colors.amber,
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📊 How the forecast is calculated:',
                      softWrap: true,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber[900],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '• Uses your spending pattern from past 12 months\n'
                      '• NOT just a linear calculation based on current spending\n'
                      '• Example: If you spent RM584 in first week but historically spend less in later weeks, forecast will reflect that\n'
                      '• Updates as you spend more and new data comes in',
                      softWrap: true,
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.amber[800],
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
                      softWrap: true,
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
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Including remaining days in month',
                      softWrap: true,
                      style: TextStyle(fontSize: 9, color: Colors.blue[700]),
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
    // Forecast Details: Shows detailed forecast for next 3 months
    // Includes confidence levels and prediction ranges
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
        const SizedBox(height: 4),
        Text(
          'Monthly predictions including confidence level and expected range',
          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
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
                    Tooltip(
                      message:
                          'How accurate this prediction is likely to be. Higher = more accurate.',
                      child: Text(
                        'Confidence: ${((1 - (forecast.upperBound - forecast.lowerBound) / (2 * forecast.forecastedAmount)) * 100).toStringAsFixed(0)}%',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
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
                    Tooltip(
                      message: 'Expected minimum to maximum spending range',
                      child: Text(
                        'Range: RM${forecast.lowerBound.toStringAsFixed(2)} - RM${forecast.upperBound.toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
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
    // Historical Data: Shows your spending history over the past 12 months
    // Used to calculate accurate forecasts
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
          Column(
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
              const SizedBox(height: 2),
              Text(
                'Your past spending patterns used to calculate forecasts',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.green[200] ?? Colors.green,
                    width: 1,
                  ),
                ),
                child: Text(
                  '✓ More historical data = More accurate forecasts. The algorithm analyzes patterns across these months to predict future spending.',
                  softWrap: true,
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.green[700],
                    height: 1.4,
                  ),
                ),
              ),
            ],
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
              softWrap: true,
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
              Column(
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
                  const SizedBox(height: 2),
                  Text(
                    'How accurate our predictions have been historically',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                ],
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
                    Tooltip(
                      message:
                          'Average difference between predicted and actual spending. Lower is better.',
                      child: Text(
                        'Mean Absolute Error (MAE)',
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
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
                      softWrap: true,
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '💡 Tip: Use this as a safety margin when planning your budget',
                      softWrap: true,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.blue[600],
                        fontWeight: FontWeight.w500,
                      ),
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
