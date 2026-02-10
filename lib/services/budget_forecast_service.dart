import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';

/// Data model for forecast results
class ForecastResult {
  final DateTime date;
  final double forecastedAmount;
  final double lowerBound;
  final double upperBound;
  final bool isAnomaly;
  final bool isLimitedData; // True when forecast is based on <3 months data

  ForecastResult({
    required this.date,
    required this.forecastedAmount,
    required this.lowerBound,
    required this.upperBound,
    this.isAnomaly = false,
    this.isLimitedData = false,
  });
}

/// Data model for historical spending data
class HistoricalSpending {
  final DateTime date;
  final double amount;

  HistoricalSpending({required this.date, required this.amount});
}

/// Service for budget forecasting using Facebook Prophet algorithm
/// This service analyzes historical spending patterns and forecasts future expenses
class BudgetForecastService {
  static const String _tag = '[BudgetForecastService]';
  static const int _minHistoricalMonths = 3; // Minimum months of data needed
  static const double _anomalyThreshold =
      2.0; // Z-score threshold for anomalies

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

  /// Implements a simplified Facebook Prophet-like algorithm
  /// Uses trend analysis and seasonality detection for forecasting
  List<ForecastResult> _forecastWithProphet(
    List<HistoricalSpending> historicalData,
    int forecastMonths, {
    double budgetAmount = 0,
  }) {
    if (historicalData.length < _minHistoricalMonths) {
      print('$_tag Insufficient historical data for forecasting');
      return [];
    }

    final results = <ForecastResult>[];
    final amounts = historicalData.map((h) => h.amount).toList();

    // Calculate trend using linear regression
    final trend = _calculateTrend(amounts);

    // Calculate seasonality (month-over-month variation)
    final seasonality = _calculateSeasonality(amounts);

    // Calculate statistics for anomaly detection
    final mean = amounts.reduce((a, b) => a + b) / amounts.length;
    final stdDev = _calculateStdDev(amounts, mean);

    // Generate forecasts for future months
    final lastDate = historicalData.last.date;

    // Extract trend values with null safety
    final trendSlope = (trend['slope'] ?? 0.0);
    final trendIntercept = (trend['intercept'] ?? 0.0);

    for (int i = 1; i <= forecastMonths; i++) {
      final forecastDate = DateTime(lastDate.year, lastDate.month + i, 1);

      // Calculate base forecast using trend
      final trendValue =
          trendSlope * (historicalData.length + i) + trendIntercept;

      // Apply seasonality factor
      final seasonalFactor = seasonality[(forecastDate.month - 1) % 12] ?? 1.0;
      final forecastedAmount = max(0.0, trendValue * seasonalFactor);

      // Calculate confidence bounds (95% confidence interval)
      final margin = 1.96 * stdDev;
      final lowerBound = max(0.0, forecastedAmount - margin);
      final upperBound = forecastedAmount + margin;

      // Determine if forecast is anomalous (significantly different from historical pattern)
      final isAnomaly =
          (forecastedAmount - mean).abs() > (_anomalyThreshold * stdDev);

      results.add(
        ForecastResult(
          date: forecastDate,
          forecastedAmount: forecastedAmount.toDouble(),
          lowerBound: lowerBound.toDouble(),
          upperBound: upperBound.toDouble(),
          isAnomaly: isAnomaly,
        ),
      );
    }

    return results;
  }

  /// Generates forecast using limited transaction data (<3 months)
  /// Analyzes recent transactions and provides basic pattern insights
  List<ForecastResult> _forecastWithLimitedData(
    List<HistoricalSpending> historicalData,
    int forecastMonths,
  ) {
    if (historicalData.isEmpty) {
      return [];
    }

    final results = <ForecastResult>[];
    final amounts = historicalData.map((h) => h.amount).toList();

    // Calculate average spending
    final mean = amounts.reduce((a, b) => a + b) / amounts.length;

    // Calculate trend if we have at least 2 data points
    late double trendSlope;
    late double trendIntercept;

    if (amounts.length >= 2) {
      final trend = _calculateTrend(amounts);
      trendSlope = (trend['slope'] ?? 0.0);
      trendIntercept = (trend['intercept'] ?? 0.0);
    } else {
      trendSlope = 0.0;
      trendIntercept = mean;
    }

    // Calculate standard deviation for confidence bounds
    final stdDev = _calculateStdDev(amounts, mean);

    // Generate forecast for future months using available trend
    final lastDate = historicalData.last.date;

    for (int i = 1; i <= forecastMonths; i++) {
      final forecastDate = DateTime(lastDate.year, lastDate.month + i, 1);

      // Use simple average with trend adjustment (conservative approach for limited data)
      final trendValue =
          trendSlope * (historicalData.length + i) + trendIntercept;
      final forecastedAmount = max(0.0, trendValue);

      // Wider confidence bounds for limited data (1.96 * stdDev * 1.5 for less certainty)
      final margin = 1.96 * stdDev * 1.5;
      final lowerBound = max(0.0, forecastedAmount - margin);
      final upperBound = forecastedAmount + margin;

      // Mark as potential anomaly if significantly different from mean
      final isAnomaly =
          (forecastedAmount - mean).abs() > (_anomalyThreshold * stdDev);

      results.add(
        ForecastResult(
          date: forecastDate,
          forecastedAmount: forecastedAmount.toDouble(),
          lowerBound: lowerBound.toDouble(),
          upperBound: upperBound.toDouble(),
          isAnomaly: isAnomaly,
          isLimitedData: true, // Mark as limited data forecast
        ),
      );
    }

    return results;
  }

  /// Calculates trend using simple linear regression
  Map<String, double> _calculateTrend(List<double> amounts) {
    final n = amounts.length;
    double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;

    for (int i = 0; i < n; i++) {
      sumX += i;
      sumY += amounts[i];
      sumXY += i * amounts[i];
      sumX2 += i * i;
    }

    final slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
    final intercept = (sumY - slope * sumX) / n;

    return {'slope': slope, 'intercept': intercept};
  }

  /// Calculates seasonality factors for each month
  Map<int, double> _calculateSeasonality(List<double> amounts) {
    if (amounts.length < 12) {
      // Not enough data for full seasonality, return neutral factors
      return {for (int i = 0; i < 12; i++) i: 1.0};
    }

    // Group by month and calculate average for each month
    Map<int, List<double>> monthlyAmounts = {};
    for (int i = 0; i < amounts.length; i++) {
      final monthIndex = i % 12;
      monthlyAmounts.putIfAbsent(monthIndex, () => []).add(amounts[i]);
    }

    // Calculate seasonality factor as ratio of monthly average to overall average
    double overallAverage = amounts.reduce((a, b) => a + b) / amounts.length;

    final seasonality = <int, double>{};
    monthlyAmounts.forEach((month, values) {
      final monthAverage = values.reduce((a, b) => a + b) / values.length;
      seasonality[month] = monthAverage / overallAverage;
    });

    return seasonality;
  }

  /// Calculates standard deviation
  double _calculateStdDev(List<double> amounts, double mean) {
    final variance =
        amounts.fold(0.0, (sum, value) {
          return sum + pow(value - mean, 2).toDouble();
        }) /
        amounts.length;
    return sqrt(variance);
  }

  /// Calculates Mean Absolute Error (MAE) between predicted and actual values
  double _calculateMAE(List<double> actual, List<double> predicted) {
    if (actual.length != predicted.length) return -1;

    double total = 0;
    for (int i = 0; i < actual.length; i++) {
      total += (actual[i] - predicted[i]).abs();
    }
    return total / actual.length;
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

      // Generate forecast (uses fallback for <3 months data)
      final forecast = historicalData.length < _minHistoricalMonths
          ? _forecastWithLimitedData(historicalData, 3)
          : _forecastWithProphet(historicalData, 3, budgetAmount: budgetAmount);

      if (forecast.isEmpty) {
        return false;
      }

      // Check if next month's forecast significantly exceeds budget
      final nextMonthForecast = forecast.first;

      // High risk if:
      // 1. Forecasted amount exceeds budget
      // 2. Upper confidence bound significantly exceeds budget (>120%)
      final exceedsBasicBudget =
          nextMonthForecast.forecastedAmount > budgetAmount;
      final exceedsWithMargin =
          nextMonthForecast.upperBound > (budgetAmount * 1.2);

      // For limited data forecasts, be more conservative - require higher confidence
      final isHighRisk = nextMonthForecast.isLimitedData
          ? exceedsBasicBudget &&
                exceedsWithMargin &&
                nextMonthForecast.forecastedAmount > (budgetAmount * 1.5)
          : exceedsBasicBudget && exceedsWithMargin;

      print(
        '$_tag High Risk Check - Forecast: ${nextMonthForecast.forecastedAmount.toStringAsFixed(2)}, '
        'Budget: $budgetAmount, High Risk: $isHighRisk, Limited Data: ${nextMonthForecast.isLimitedData}',
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

      if (historicalData.length < _minHistoricalMonths) {
        print('$_tag Insufficient monthly data, using limited data fallback');
        // Use fallback forecast with available data
        final limitedForecast = _forecastWithLimitedData(
          historicalData,
          forecastMonths,
        );
        return limitedForecast;
      }

      // Generate forecast
      final forecast = _forecastWithProphet(historicalData, forecastMonths);

      return forecast;
    } catch (e) {
      print('$_tag Error getting forecast: $e');
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
      final testingData = historicalData
          .skip(historicalData.length ~/ 2)
          .toList();

      // Forecast on testing period
      final forecasts = _forecastWithProphet(trainingData, testingData.length);

      if (forecasts.length != testingData.length) {
        return -1;
      }

      // Calculate MAE
      final actualAmounts = testingData.map((h) => h.amount).toList();
      final forecastedAmounts = forecasts
          .map((f) => f.forecastedAmount)
          .toList();

      final mae = _calculateMAE(actualAmounts, forecastedAmounts);
      print('$_tag Forecast Accuracy (MAE): ${mae.toStringAsFixed(2)}');

      return mae;
    } catch (e) {
      print('$_tag Error calculating forecast accuracy: $e');
      return -1;
    }
  }
}
