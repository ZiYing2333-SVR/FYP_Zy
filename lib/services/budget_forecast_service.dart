import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';

/// Data model for overspend analysis
class OverspendAnalysis {
  final double currentMonthUsage;
  final double forecastedMonthUsage;
  final double budgetAmount;
  final double overspendPercentage; // How much over budget as percentage
  final double overspendAmount; // Actual RM amount over budget
  final String riskLevel; // 'low', 'medium', 'high', 'critical'
  final List<SpendingSuggestion> suggestions;
  final bool isMonthlyBudget;

  OverspendAnalysis({
    required this.currentMonthUsage,
    required this.forecastedMonthUsage,
    required this.budgetAmount,
    required this.overspendPercentage,
    required this.overspendAmount,
    required this.riskLevel,
    required this.suggestions,
    required this.isMonthlyBudget,
  });
}

/// Data model for spending suggestions
class SpendingSuggestion {
  final String title;
  final String description;
  final int priority; // 1-5, higher = more urgent
  final String category; // 'reduce', 'increase', 'monitor'

  SpendingSuggestion({
    required this.title,
    required this.description,
    required this.priority,
    required this.category,
  });
}

/// Data model for forecast results
class ForecastResult {
  final DateTime date;
  final double forecastedAmount;
  final double lowerBound;
  final double upperBound;
  final bool isAnomaly;
  final bool isLimitedData; // True when forecast is based on <3 months data
  final double mae; // Mean Absolute Error
  final bool hasSufficientData; // Whether model has >= 3 months data
  final String alertStatus; // 'normal', 'warning', 'critical'
  final String alertMessage; // Alert description

  ForecastResult({
    required this.date,
    required this.forecastedAmount,
    required this.lowerBound,
    required this.upperBound,
    this.isAnomaly = false,
    this.isLimitedData = false,
    this.mae = 0.0,
    this.hasSufficientData = true,
    this.alertStatus = 'normal',
    this.alertMessage = '',
  });
}

/// Data model for historical spending data
class HistoricalSpending {
  final DateTime date;
  final double amount;

  HistoricalSpending({required this.date, required this.amount});
}

/// Service for budget forecasting
/// Calls backend API which uses Facebook Prophet for forecasting
class BudgetForecastService {
  static const String _tag = '[BudgetForecastService]';
  static const int _minHistoricalMonths = 3;

  // Backend API configuration
  // For local development: http://localhost:8000
  // For production (Render/Railway): https://your-backend-url.com
  // Update the URL below based on your deployment
  static const String _backendUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue:
        'https://fyp-zy-6u7m.onrender.com', // Change this to your actual URL
  );
  static const String _forecastEndpoint = '/forecast';

  // API timeout
  static const Duration _timeout = Duration(seconds: 30);

  /// Extracts user ID from transaction ID
  /// Format: TRANSUID0001000001 -> UID0001
  String _extractUserIdFromTransaction(String transactionId) {
    final regex = RegExp(r'UID\d{4}');
    final match = regex.firstMatch(transactionId);
    return match?.group(0) ?? '';
  }

  /// Verifies if a budget is monthly only
  /// Returns true only for monthly cycle budgets
  bool _isMonthlyBudget(String? cycleType) {
    return cycleType != null && cycleType.toLowerCase() == 'month';
  }

  /// Generates spending suggestions based on overspend risk
  List<SpendingSuggestion> _generateSpendingSuggestions(
    double overspendPercentage,
    double currentMonthUsage,
    double budgetAmount,
    double forecastedAmount,
  ) {
    final suggestions = <SpendingSuggestion>[];

    if (overspendPercentage > 50) {
      // Critical overspend
      suggestions.addAll([
        SpendingSuggestion(
          title: 'URGENT: Reduce Spending Immediately',
          description:
              'You are on track to overspend by ${overspendPercentage.toStringAsFixed(1)}%. Stop all non-essential expenses now.',
          priority: 5,
          category: 'reduce',
        ),
        SpendingSuggestion(
          title: 'Review All Transactions',
          description:
              'Analyze recent transactions and cancel any subscriptions or recurring charges you can avoid.',
          priority: 5,
          category: 'reduce',
        ),
        SpendingSuggestion(
          title: 'Increase Budget Amount',
          description:
              'If expenses are justified, consider increasing your budget limit to RM${(forecastedAmount * 1.15).toStringAsFixed(2)}.',
          priority: 4,
          category: 'increase',
        ),
      ]);
    } else if (overspendPercentage > 20) {
      // High overspend risk
      suggestions.addAll([
        SpendingSuggestion(
          title: 'Limit Large Purchases',
          description:
              'Avoid making purchases over RM500 for the remainder of this month. Current projected overspend: ${overspendPercentage.toStringAsFixed(1)}%.',
          priority: 4,
          category: 'reduce',
        ),
        SpendingSuggestion(
          title: 'Delay Non-Essential Spending',
          description:
              'Post-pone shopping, dining out, and entertainment expenses until next month if possible.',
          priority: 4,
          category: 'reduce',
        ),
        SpendingSuggestion(
          title: 'Monitor Spending Closely',
          description:
              'Check your transactions daily to stay aware of your spending pace.',
          priority: 3,
          category: 'monitor',
        ),
      ]);
    } else if (overspendPercentage > 5) {
      // Moderate overspend risk
      suggestions.addAll([
        SpendingSuggestion(
          title: 'Careful Spending for Rest of Month',
          description:
              'You\'re projected to exceed budget slightly. Plan remaining purchases carefully.',
          priority: 3,
          category: 'reduce',
        ),
        SpendingSuggestion(
          title: 'Prioritize Necessary Expenses',
          description:
              'Focus on essential purchases only. ${overspendPercentage.toStringAsFixed(1)}% overspend is manageable with careful planning.',
          priority: 3,
          category: 'monitor',
        ),
      ]);
    } else {
      // On track or under budget
      suggestions.addAll([
        SpendingSuggestion(
          title: 'On Track with Budget',
          description:
              'Excellent! You\'re projected to stay within budget with room to spare.',
          priority: 1,
          category: 'monitor',
        ),
        SpendingSuggestion(
          title: 'Maintain Current Pace',
          description:
              'Continue spending at your current rate and you\'ll end the month under budget.',
          priority: 1,
          category: 'monitor',
        ),
      ]);
    }

    return suggestions;
  }

  /// Calculates detailed overspend analysis for a budget
  Future<OverspendAnalysis> calculateOverspendAnalysis(
    String userId,
    String budgetId,
    double budgetAmount,
    String? cycleType,
    String? accountId,
    String? categoryId,
    String? ledgerId,
    double? currentMonthUsage,
    double? forecastedAmount,
  ) async {
    try {
      // Check if this is a monthly budget
      final isMonthly = _isMonthlyBudget(cycleType);

      if (!isMonthly) {
        // Return neutral analysis for non-monthly budgets
        return OverspendAnalysis(
          currentMonthUsage: 0,
          forecastedMonthUsage: 0,
          budgetAmount: budgetAmount,
          overspendPercentage: 0,
          overspendAmount: 0,
          riskLevel: 'low',
          suggestions: [
            SpendingSuggestion(
              title: 'Budget Type Note',
              description:
                  'Forecasting only applies to monthly budgets. This budget uses $cycleType cycles.',
              priority: 1,
              category: 'monitor',
            ),
          ],
          isMonthlyBudget: false,
        );
      }

      // Get current month usage if not provided
      double currentUsage = currentMonthUsage ?? 0;
      if (currentUsage == 0) {
        final now = DateTime.now();
        final startOfMonth = DateTime(now.year, now.month, 1);

        List<dynamic> transactions = [];
        if (accountId != null) {
          transactions = await Supabase.instance.client
              .from('Transaction')
              .select()
              .eq('accountId', accountId)
              .gte('date', startOfMonth.toIso8601String());
        } else if (categoryId != null) {
          transactions = await Supabase.instance.client
              .from('Transaction')
              .select()
              .eq('categoryId', categoryId)
              .eq('type', 'expense')
              .gte('date', startOfMonth.toIso8601String());
        } else if (ledgerId != null) {
          transactions = await Supabase.instance.client
              .from('Transaction')
              .select()
              .eq('ledgerId', ledgerId)
              .eq('type', 'expense')
              .gte('date', startOfMonth.toIso8601String());
        }

        for (var transaction in transactions) {
          final amount = transaction['amount'];
          if (amount != null) {
            currentUsage += (amount as num).toDouble();
          }
        }
      }

      // Get forecasted amount if not provided
      double forecasted = forecastedAmount ?? 0;
      if (forecasted == 0) {
        final historicalData = await _fetchHistoricalData(
          userId,
          budgetId,
          accountId,
          categoryId,
          ledgerId,
          12,
        );

        if (historicalData.isNotEmpty) {
          final forecast = await _callForecastAPI(
            historicalData,
            1,
            budgetAmount,
          );
          if (forecast.isNotEmpty) {
            forecasted = forecast.first.forecastedAmount;
          }
        }
      }

      // Calculate overspend
      final double overspendAmount =
          (forecasted - budgetAmount).clamp(0.0, double.infinity) as double;
      final double overspendPercentage = budgetAmount > 0
          ? (overspendAmount / budgetAmount) * 100
          : 0.0;

      // Determine risk level
      String riskLevel;
      if (overspendPercentage > 50) {
        riskLevel = 'critical';
      } else if (overspendPercentage > 20) {
        riskLevel = 'high';
      } else if (overspendPercentage > 5) {
        riskLevel = 'medium';
      } else {
        riskLevel = 'low';
      }

      // Generate suggestions
      final suggestions = _generateSpendingSuggestions(
        overspendPercentage,
        currentUsage,
        budgetAmount,
        forecasted,
      );

      return OverspendAnalysis(
        currentMonthUsage: currentUsage,
        forecastedMonthUsage: forecasted,
        budgetAmount: budgetAmount,
        overspendPercentage: overspendPercentage,
        overspendAmount: overspendAmount,
        riskLevel: riskLevel,
        suggestions: suggestions,
        isMonthlyBudget: true,
      );
    } catch (e) {
      print('$_tag Error calculating overspend analysis: $e');
      return OverspendAnalysis(
        currentMonthUsage: 0,
        forecastedMonthUsage: 0,
        budgetAmount: budgetAmount,
        overspendPercentage: 0,
        overspendAmount: 0,
        riskLevel: 'low',
        suggestions: [
          SpendingSuggestion(
            title: 'Error',
            description: 'Could not calculate analysis: $e',
            priority: 1,
            category: 'monitor',
          ),
        ],
        isMonthlyBudget: _isMonthlyBudget(cycleType),
      );
    }
  }

  /// Fetches historical spending data for a budget
  Future<List<HistoricalSpending>> _fetchHistoricalData(
    String userId,
    String budgetId,
    String? accountId,
    String? categoryId,
    String? ledgerId,
    int months,
  ) async {
    try {
      final endDate = DateTime.now();
      final startDate = DateTime(
        endDate.year,
        endDate.month - months,
        endDate.day,
      );

      // Fetch transactions based on budget type
      List<dynamic> transactions = [];

      if (accountId != null) {
        transactions = await Supabase.instance.client
            .from('Transaction')
            .select()
            .eq('accountId', accountId)
            .gte('date', startDate.toIso8601String())
            .lte('date', endDate.toIso8601String())
            .order('date', ascending: true);
      } else if (categoryId != null) {
        transactions = await Supabase.instance.client
            .from('Transaction')
            .select()
            .eq('categoryId', categoryId)
            .eq('type', 'expense')
            .gte('date', startDate.toIso8601String())
            .lte('date', endDate.toIso8601String())
            .order('date', ascending: true);
      } else if (ledgerId != null) {
        transactions = await Supabase.instance.client
            .from('Transaction')
            .select()
            .eq('ledgerId', ledgerId)
            .eq('type', 'expense')
            .gte('date', startDate.toIso8601String())
            .lte('date', endDate.toIso8601String())
            .order('date', ascending: true);
      }

      // Aggregate transactions by date
      Map<String, double> dailySpending = {};
      for (var transaction in transactions) {
        final date = (transaction['date'] as String).split('T')[0];
        final amount = (transaction['amount'] ?? 0.0).toDouble();
        dailySpending[date] = (dailySpending[date] ?? 0.0) + amount;
      }

      // Convert to monthly aggregates (Prophet works better with monthly data)
      Map<String, double> monthlySpending = {};
      dailySpending.forEach((dateStr, amount) {
        final monthKey = dateStr.substring(0, 7); // YYYY-MM format
        monthlySpending[monthKey] = (monthlySpending[monthKey] ?? 0.0) + amount;
      });

      // Sort by date and convert to HistoricalSpending objects
      final sortedDates = monthlySpending.keys.toList()..sort();
      final historicalData = sortedDates.map((dateStr) {
        return HistoricalSpending(
          date: DateTime.parse('$dateStr-01'),
          amount: monthlySpending[dateStr] ?? 0.0,
        );
      }).toList();

      print('$_tag Fetched ${historicalData.length} months of historical data');
      return historicalData;
    } catch (e) {
      print('$_tag Error fetching historical data: $e');
      return [];
    }
  }

  /// Calls the backend forecasting API (uses Facebook Prophet)
  /// Returns forecast with predictions, confidence intervals, and alerts
  Future<List<ForecastResult>> _callForecastAPI(
    List<HistoricalSpending> historicalData,
    int forecastMonths,
    double budgetAmount,
  ) async {
    try {
      if (historicalData.isEmpty) {
        print('$_tag No historical data to forecast');
        return [];
      }

      // Prepare request payload for backend API
      final List<Map<String, dynamic>> histData = historicalData.map((h) {
        return {
          'date': h.date.toIso8601String().split('T')[0], // YYYY-MM-DD format
          'amount': h.amount,
        };
      }).toList();

      final requestBody = {
        'historical_data': histData,
        'forecast_periods': forecastMonths,
        'budget_amount': budgetAmount,
      };

      final apiUrl = '$_backendUrl$_forecastEndpoint';
      print('$_tag Calling backend API at $apiUrl');
      print('$_tag Request: ${jsonEncode(requestBody)}');

      // Make API request to backend
      final response = await http
          .post(
            Uri.parse(apiUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(_timeout);

      print('$_tag API Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final decodedResponse =
            jsonDecode(response.body) as Map<String, dynamic>;

        print('$_tag API Response: ${response.body}');

        // Parse forecast results from backend
        final List<dynamic> forecastList = decodedResponse['forecast'] ?? [];
        final mae = (decodedResponse['mae'] ?? 0.0).toDouble();
        final hasSufficientData =
            decodedResponse['has_sufficient_data'] ?? true;
        final alertStatus = decodedResponse['alert_status'] ?? 'normal';
        final alertMessage = decodedResponse['alert_message'] ?? '';

        if (forecastList.isEmpty) {
          print('$_tag No forecast data received');
          return [];
        }

        final results = forecastList.map((forecastItem) {
          final forecast = forecastItem as Map<String, dynamic>;

          final forecastedAmount = (forecast['predicted_amount'] ?? 0.0)
              .toDouble();
          final lowerBound = (forecast['lower_bound'] ?? 0.0).toDouble();
          final upperBound = (forecast['upper_bound'] ?? 0.0).toDouble();
          final isAnomaly = forecast['is_anomaly'] ?? false;

          return ForecastResult(
            date: DateTime.parse(forecast['date']),
            forecastedAmount: forecastedAmount,
            lowerBound: lowerBound,
            upperBound: upperBound,
            isAnomaly: isAnomaly,
            mae: mae,
            hasSufficientData: hasSufficientData,
            alertStatus: alertStatus,
            alertMessage: alertMessage,
          );
        }).toList();

        print('$_tag Successfully parsed ${results.length} forecast points');
        return results;
      } else {
        print('$_tag API Error: ${response.statusCode} - ${response.body}');
        throw Exception(
          'Backend API Error: ${response.statusCode} - ${response.body}',
        );
      }
    } on http.ClientException catch (e) {
      print('$_tag Network Error: $e');
      throw Exception(
        'Network Error: Could not connect to backend API at $_backendUrl. '
        'Make sure your backend is running.',
      );
    } catch (e) {
      print('$_tag Error calling backend API: $e');
      throw Exception('Backend API Error: $e');
    }
  }

  /// Determines if a budget is at high risk based on forecast
  /// High risk = predicted expenses exceed budget limit with high confidence
  Future<bool> checkHighRiskAlert(
    String userId,
    String budgetId,
    double budgetAmount,
    String? accountId,
    String? categoryId,
    String? ledgerId,
  ) async {
    try {
      // Fetch historical data (last 12 months)
      final historicalData = await _fetchHistoricalData(
        userId,
        budgetId,
        accountId,
        categoryId,
        ledgerId,
        12,
      );

      if (historicalData.isEmpty) {
        return false;
      }

      // Generate forecast via API
      final forecast = await _callForecastAPI(
        historicalData,
        3, // 3 month forecast
        budgetAmount,
      );

      if (forecast.isEmpty) {
        return false;
      }

      // Check if next month's forecast significantly exceeds budget
      final nextMonthForecast = forecast.first;

      // High risk if predicted amount exceeds 120% of budget
      final isHighRisk =
          nextMonthForecast.alertStatus == 'warning' ||
          nextMonthForecast.alertStatus == 'critical';

      print(
        '$_tag High Risk Check - '
        'Forecast: ${nextMonthForecast.forecastedAmount.toStringAsFixed(2)}, '
        'Budget: $budgetAmount, High Risk: $isHighRisk, '
        'Alert: ${nextMonthForecast.alertStatus}',
      );

      return isHighRisk;
    } catch (e) {
      print('$_tag Error checking high risk alert: $e');
      return false;
    }
  }

  /// Gets forecast results for display
  Future<List<ForecastResult>> getForecast(
    String userId,
    String budgetId,
    String? accountId,
    String? categoryId,
    String? ledgerId,
    int forecastMonths,
  ) async {
    try {
      // Fetch historical data (last 12 months)
      final historicalData = await _fetchHistoricalData(
        userId,
        budgetId,
        accountId,
        categoryId,
        ledgerId,
        12,
      );

      if (historicalData.isEmpty) {
        print('$_tag No historical data available for forecast');
        return [];
      }

      print('$_tag Fetched ${historicalData.length} months of history');

      // Call Forecast API for forecast
      final forecast = await _callForecastAPI(
        historicalData,
        forecastMonths,
        0, // Budget amount not needed for basic forecast
      );

      return forecast;
    } catch (e) {
      print('$_tag Error getting forecast: $e');
      // Return empty list on error - UI will show appropriate message
      return [];
    }
  }

  /// Gets historical data for comparison with forecast
  Future<List<HistoricalSpending>> getHistoricalData(
    String userId,
    String budgetId,
    String? accountId,
    String? categoryId,
    String? ledgerId,
  ) async {
    return await _fetchHistoricalData(
      userId,
      budgetId,
      accountId,
      categoryId,
      ledgerId,
      12,
    );
  }

  /// Calculates forecast accuracy (MAE) using past data
  /// Performs backtesting on historical data
  Future<double> calculateForecastAccuracy(
    String userId,
    String budgetId,
    String? accountId,
    String? categoryId,
    String? ledgerId,
  ) async {
    try {
      final historicalData = await _fetchHistoricalData(
        userId,
        budgetId,
        accountId,
        categoryId,
        ledgerId,
        24, // Get 24 months for backtesting
      );

      if (historicalData.length < _minHistoricalMonths * 2) {
        return -1; // Not enough data
      }

      // Split data: use first 12 months to predict last 12 months
      final trainingData = historicalData
          .take(historicalData.length ~/ 2)
          .toList();

      // Get forecast which includes MAE
      final forecast = await _callForecastAPI(trainingData, 12, 0);

      if (forecast.isEmpty) {
        return -1;
      }

      final mae = forecast.first.mae;
      print('$_tag Forecast Accuracy (MAE): ${mae.toStringAsFixed(2)}');

      return mae;
    } catch (e) {
      print('$_tag Error calculating forecast accuracy: $e');
      return -1;
    }
  }
}
