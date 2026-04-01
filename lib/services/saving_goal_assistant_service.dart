import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:math';

class SavingGoalAssistantService {
  /// Fetches user's income and expense data for analysis
  static Future<Map<String, dynamic>> getUserFinancialData(
    String userId,
  ) async {
    try {
      // Fetch all accounts for the user
      final accounts = await Supabase.instance.client
          .from('Account')
          .select()
          .eq('userId', userId);

      if (accounts.isEmpty) {
        return {
          'success': true,
          'monthlyData': {'monthlyIncome': {}, 'monthlyExpense': {}},
          'incomeTransactions': [],
          'expenseTransactions': [],
          'accounts': accounts,
        };
      }

      // Extract account IDs
      final accountIds = (accounts as List)
          .map((acc) => acc['accountId'] as String)
          .toList();

      // Fetch all transactions for the user's accounts in the last 12 months
      final today = DateTime.now();
      final oneYearAgo = today.subtract(const Duration(days: 365));
      final dateString = DateFormat('yyyy-MM-dd').format(oneYearAgo);

      // Fetch transactions with account linking
      final transactions = await Supabase.instance.client
          .from('Transaction')
          .select()
          .gte('date', dateString);

      // Filter transactions by account IDs (client-side filtering)
      final accountTransactions = (transactions as List)
          .where((txn) => accountIds.contains(txn['accountId'] as String?))
          .toList();

      // Categorize transactions as income or expenses
      final incomeTransactions = <Map<String, dynamic>>[];
      final expenseTransactions = <Map<String, dynamic>>[];

      for (final txn in accountTransactions) {
        final amount = (txn['amount'] ?? 0).toDouble();
        if (amount > 0) {
          incomeTransactions.add(txn);
        } else {
          expenseTransactions.add(txn);
        }
      }

      // Calculate monthly income and expense trends
      final monthlyData = _calculateMonthlyTrends(
        incomeTransactions,
        expenseTransactions,
      );

      return {
        'success': true,
        'monthlyData': monthlyData,
        'incomeTransactions': incomeTransactions,
        'expenseTransactions': expenseTransactions,
        'accounts': accounts,
      };
    } catch (e) {
      print('Error fetching financial data: $e');
      return {'success': false, 'error': 'Failed to fetch financial data: $e'};
    }
  }

  /// Calculates monthly income and expense trends
  static Map<String, dynamic> _calculateMonthlyTrends(
    List<dynamic> incomeTransactions,
    List<dynamic> expenseTransactions,
  ) {
    final monthlyIncome = <String, double>{};
    final monthlyExpense = <String, double>{};

    // Process income transactions
    for (final txn in incomeTransactions) {
      var date = txn['date'];
      final amount = (txn['amount'] ?? 0).toDouble().abs();
      if (date != null) {
        try {
          String dateStr;
          if (date is DateTime) {
            dateStr = DateFormat('yyyy-MM-dd').format(date);
          } else if (date is String) {
            dateStr = date;
          } else {
            dateStr = date.toString();
            if (dateStr.contains('T')) {
              dateStr = dateStr.split('T')[0];
            }
          }
          if (dateStr.length >= 7) {
            final month = dateStr.substring(0, 7);
            monthlyIncome[month] = (monthlyIncome[month] ?? 0) + amount;
          }
        } catch (e) {
          print(
            '[SavingGoalAssistant] Warning: Failed to parse income date "$date": $e',
          );
        }
      }
    }

    // Process expense transactions
    for (final txn in expenseTransactions) {
      var date = txn['date'];
      final amount = (txn['amount'] ?? 0).toDouble().abs();
      if (date != null) {
        try {
          String dateStr;
          if (date is DateTime) {
            dateStr = DateFormat('yyyy-MM-dd').format(date);
          } else if (date is String) {
            dateStr = date;
          } else {
            dateStr = date.toString();
            if (dateStr.contains('T')) {
              dateStr = dateStr.split('T')[0];
            }
          }
          if (dateStr.length >= 7) {
            final month = dateStr.substring(0, 7);
            monthlyExpense[month] = (monthlyExpense[month] ?? 0) + amount;
          }
        } catch (e) {
          print(
            '[SavingGoalAssistant] Warning: Failed to parse expense date "$date": $e',
          );
        }
      }
    }

    return {'monthlyIncome': monthlyIncome, 'monthlyExpense': monthlyExpense};
  }

  /// Forecasts future income and expenses using time series analysis
  static Map<String, dynamic> forecastFutureExpenses(
    Map<String, dynamic> monthlyData,
    int forecastMonths,
  ) {
    final monthlyIncome =
        (monthlyData['monthlyIncome'] as Map<String, dynamic>?)
            ?.cast<String, double>() ??
        {};
    final monthlyExpense =
        (monthlyData['monthlyExpense'] as Map<String, dynamic>?)
            ?.cast<String, double>() ??
        {};

    // Calculate average income and expense
    final avgIncome = monthlyIncome.values.isNotEmpty
        ? monthlyIncome.values.reduce((a, b) => a + b) / monthlyIncome.length
        : 0;
    final avgExpense = monthlyExpense.values.isNotEmpty
        ? monthlyExpense.values.reduce((a, b) => a + b) / monthlyExpense.length
        : 0;

    // Use exponential smoothing for trend prediction (or use average if data is limited)
    final predictedIncome = monthlyIncome.isNotEmpty
        ? _exponentialSmoothing(monthlyIncome.values.toList())
        : avgIncome;
    final predictedExpense = monthlyExpense.isNotEmpty
        ? _exponentialSmoothing(monthlyExpense.values.toList())
        : avgExpense;

    // Add seasonal adjustment
    final seasonalIncome =
        predictedIncome *
        (1 + _getSeasonalityFactor(DateTime.now().month, true));
    final seasonalExpense =
        predictedExpense *
        (1 + _getSeasonalityFactor(DateTime.now().month, false));

    // Check if we have limited data
    bool hasLimitedData = monthlyIncome.isEmpty || monthlyExpense.isEmpty;

    return {
      'success': true,
      'predictedMonthlyIncome': seasonalIncome,
      'predictedMonthlyExpense': seasonalExpense,
      'historicalAvgIncome': avgIncome,
      'historicalAvgExpense': avgExpense,
      'hasLimitedData': hasLimitedData,
      'incomeDataPoints': monthlyIncome.length,
      'expenseDataPoints': monthlyExpense.length,
    };
  }

  /// Exponential smoothing for trend analysis
  static double _exponentialSmoothing(List<double> values) {
    if (values.isEmpty) return 0;
    if (values.length == 1) return values[0];

    double smoothed = values[0];
    const alpha = 0.3; // Smoothing factor

    for (int i = 1; i < values.length; i++) {
      smoothed = alpha * values[i] + (1 - alpha) * smoothed;
    }

    return smoothed;
  }

  /// Gets seasonality factor based on month
  static double _getSeasonalityFactor(int month, bool isIncome) {
    // Example seasonal patterns (can be adjusted based on actual data)
    if (isIncome) {
      // Higher income in certain months (e.g., bonus months: 12, 6)
      if (month == 12 || month == 6) return 0.1;
      if (month == 1 || month == 7) return 0.05;
      return 0;
    } else {
      // Higher expenses in certain months (e.g., holiday shopping: 12, year-end: 11)
      if (month == 12) return 0.15;
      if (month == 11) return 0.1;
      if (month == 1) return 0.05;
      return 0;
    }
  }

  /// Analyzes saving goal feasibility
  static Map<String, dynamic> analyzeSavingGoalFeasibility({
    required double targetAmount,
    required DateTime startDate,
    required DateTime endDate,
    required double predictedMonthlyIncome,
    required double predictedMonthlyExpense,
  }) {
    // Calculate monthly savings
    final monthlyNetIncome = predictedMonthlyIncome - predictedMonthlyExpense;
    final totalMonths = _calculateMonths(startDate, endDate);

    if (totalMonths <= 0) {
      return {
        'success': false,
        'feasible': false,
        'error': 'End date must be after start date',
      };
    }

    final projectedTotalSavings = monthlyNetIncome * totalMonths;
    final isFeasible = projectedTotalSavings >= targetAmount;

    // Generate suggestions
    List<String> suggestions = [];

    if (!isFeasible) {
      final shortfall = targetAmount - projectedTotalSavings;
      suggestions.add(
        'Your goal is ambitious. At the current projected monthly savings of RM${monthlyNetIncome.toStringAsFixed(2)}, '
        'you would save RM${projectedTotalSavings.toStringAsFixed(2)} in $totalMonths months.',
      );
      suggestions.add(
        'You need additional RM${shortfall.toStringAsFixed(2)} to reach your goal.',
      );

      // Suggest extending timeline
      if (monthlyNetIncome > 0) {
        final requiredMonths = (targetAmount / monthlyNetIncome).ceil();
        final requiredEndDate = startDate.add(
          Duration(days: requiredMonths * 30),
        );
        suggestions.add(
          'Consider extending the timeline to ${DateFormat('yyyy-MM-dd').format(requiredEndDate)} to reach your goal.',
        );
      }

      // Suggest reducing target
      final achievableTarget = projectedTotalSavings;
      suggestions.add(
        'Or adjust your target amount to RM${achievableTarget.toStringAsFixed(2)} to achieve the goal by your desired date.',
      );

      // Suggest reducing expenses
      suggestions.add(
        'Review your expense categories to identify areas where you can reduce spending.',
      );
    } else {
      suggestions.add(
        'Great! Your goal is achievable. At your current projected monthly savings of RM${monthlyNetIncome.toStringAsFixed(2)}, '
        'you will save RM${projectedTotalSavings.toStringAsFixed(2)} in $totalMonths months.',
      );
      suggestions.add(
        'You will exceed your goal by RM${(projectedTotalSavings - targetAmount).toStringAsFixed(2)}.',
      );
      suggestions.add(
        'Keep your monthly expenses under control and maintain consistent savings habits.',
      );
    }

    return {
      'success': true,
      'feasible': isFeasible,
      'targetAmount': targetAmount,
      'projectedTotalSavings': projectedTotalSavings,
      'monthlyNetIncome': monthlyNetIncome,
      'monthlyIncome': predictedMonthlyIncome,
      'monthlyExpense': predictedMonthlyExpense,
      'totalMonths': totalMonths,
      'suggestions': suggestions,
    };
  }

  /// Calculates the number of months between two dates
  static int _calculateMonths(DateTime start, DateTime end) {
    return (end.year - start.year) * 12 + (end.month - start.month);
  }

  /// Suggests appropriate source and destination accounts
  static Map<String, dynamic> suggestAccounts(
    List<Map<String, dynamic>> accounts,
    List<Map<String, dynamic>> incomeTransactions,
    List<Map<String, dynamic>> expenseTransactions,
  ) {
    // Source account: typically the account with highest income/balance
    // Destination account: typically a savings account
    String? suggestedSourceAccountId;
    String? suggestedDestAccountId;
    String? suggestedSourceAccountName;
    String? suggestedDestAccountName;

    if (accounts.isEmpty) {
      return {'success': false, 'error': 'No accounts available'};
    }

    // Find source account (highest balance or income)
    Map<String, dynamic>? sourceAccount = accounts[0];
    double maxBalance = (sourceAccount['balance'] ?? 0).toDouble();

    for (final account in accounts) {
      final balance = (account['balance'] ?? 0).toDouble();
      if (balance > maxBalance) {
        sourceAccount = account;
        maxBalance = balance;
      }
    }

    suggestedSourceAccountId = sourceAccount?['accountId'] as String?;
    suggestedSourceAccountName = sourceAccount?['accountName'] as String?;

    // Find destination account (typically a savings account)
    Map<String, dynamic>? destAccount;

    // Look for savings account
    for (final account in accounts) {
      final type = account['accountType']?.toString().toLowerCase() ?? '';
      if (type.contains('sav') || type.contains('invest')) {
        destAccount = account;
        break;
      }
    }

    // If no savings account, use the first account that's not the source
    destAccount ??= accounts.firstWhere(
      (acc) => acc['accountId'] != suggestedSourceAccountId,
      orElse: () => accounts[0],
    );

    suggestedDestAccountId = destAccount['accountId'] as String?;
    suggestedDestAccountName = destAccount['accountName'] as String?;

    return {
      'success': true,
      'suggestedSourceAccountId': suggestedSourceAccountId,
      'suggestedSourceAccountName': suggestedSourceAccountName,
      'suggestedDestAccountId': suggestedDestAccountId,
      'suggestedDestAccountName': suggestedDestAccountName,
    };
  }

  /// Generates a saving plan with recommendations
  static Map<String, dynamic> generateSavingPlan({
    required String savingGoalName,
    required double targetAmount,
    required DateTime startDate,
    required DateTime endDate,
    required double monthlyIncome,
    required double monthlyExpense,
    required double monthlyNetSavings,
  }) {
    final totalMonths = _calculateMonths(startDate, endDate);
    final projectedSavings = monthlyNetSavings * totalMonths;

    // Create milestone plan
    final List<Map<String, dynamic>> milestones = [];
    final monthlyTarget = targetAmount / max(totalMonths, 1);

    DateTime currentDate = startDate;
    for (int i = 0; i < totalMonths; i++) {
      final cumulativeSavings = monthlyTarget * (i + 1);
      milestones.add({
        'month': i + 1,
        'date': DateFormat('yyyy-MM-dd').format(currentDate),
        'targetAmount': monthlyTarget,
        'cumulativeTarget': cumulativeSavings,
        'percentage': min(
          (cumulativeSavings / targetAmount) * 100,
          100,
        ).toStringAsFixed(1),
      });
      currentDate = DateTime(currentDate.year, currentDate.month + 1, 1);
    }

    return {
      'success': true,
      'savingGoalName': savingGoalName,
      'targetAmount': targetAmount,
      'startDate': DateFormat('yyyy-MM-dd').format(startDate),
      'endDate': DateFormat('yyyy-MM-dd').format(endDate),
      'totalMonths': totalMonths,
      'monthlyIncome': monthlyIncome,
      'monthlyExpense': monthlyExpense,
      'monthlyNetSavings': monthlyNetSavings,
      'projectedSavings': projectedSavings,
      'willAchieveGoal': projectedSavings >= targetAmount,
      'surplus': projectedSavings - targetAmount,
      'milestones': milestones,
      'plan': {
        'step1':
            'Set up automatic transfers of RM${monthlyNetSavings.toStringAsFixed(2)} monthly.',
        'step2':
            'Monitor your spending to maintain the projected expense level.',
        'step3':
            'Track progress monthly. You need to save RM${monthlyTarget.toStringAsFixed(2)} per month.',
        'step4':
            'Adjust the plan if your income or expenses change significantly.',
      },
    };
  }

  /// Generates the final report
  static String generateReport(
    Map<String, dynamic> plan,
    Map<String, dynamic> feasibility,
  ) {
    final buffer = StringBuffer();

    buffer.writeln('📊 SAVING GOAL PLAN REPORT');
    buffer.writeln('═' * 50);
    buffer.writeln('');

    buffer.writeln('GOAL DETAILS:');
    buffer.writeln('• Name: ${plan['savingGoalName']}');
    buffer.writeln(
      '• Target Amount: RM${(plan['targetAmount'] ?? 0).toStringAsFixed(2)}',
    );
    buffer.writeln('• Duration: ${plan['startDate']} to ${plan['endDate']}');
    buffer.writeln('• Total Months: ${plan['totalMonths']}');
    buffer.writeln('');

    buffer.writeln('FINANCIAL PROJECTION:');
    buffer.writeln(
      '• Monthly Income: RM${(plan['monthlyIncome'] ?? 0).toStringAsFixed(2)}',
    );
    buffer.writeln(
      '• Monthly Expense: RM${(plan['monthlyExpense'] ?? 0).toStringAsFixed(2)}',
    );
    buffer.writeln(
      '• Monthly Net Savings: RM${(plan['monthlyNetSavings'] ?? 0).toStringAsFixed(2)}',
    );
    buffer.writeln(
      '• Projected Total Savings: RM${(plan['projectedSavings'] ?? 0).toStringAsFixed(2)}',
    );
    buffer.writeln('');

    buffer.writeln('FEASIBILITY ANALYSIS:');
    if (plan['willAchieveGoal'] == true) {
      buffer.writeln('✓ GOAL IS ACHIEVABLE');
      buffer.writeln(
        '• Surplus: RM${(plan['surplus'] ?? 0).toStringAsFixed(2)}',
      );
    } else {
      buffer.writeln('✗ GOAL NEEDS ADJUSTMENT');
      buffer.writeln(
        '• Shortfall: RM${((plan['targetAmount'] ?? 0) - (plan['projectedSavings'] ?? 0)).toStringAsFixed(2)}',
      );
    }
    buffer.writeln('');

    if (feasibility['suggestions'] != null) {
      buffer.writeln('RECOMMENDATIONS:');
      for (final suggestion in feasibility['suggestions']) {
        buffer.writeln('• $suggestion');
      }
      buffer.writeln('');
    }

    buffer.writeln('ACTION PLAN:');
    if (plan['plan'] != null) {
      final steps = plan['plan'] as Map<String, dynamic>;
      steps.forEach((key, value) {
        buffer.writeln('• $value');
      });
    }

    return buffer.toString();
  }
}
