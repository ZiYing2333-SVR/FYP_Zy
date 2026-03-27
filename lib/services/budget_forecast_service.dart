import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';

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

/// Service for budget forecasting using Facebook Prophet algorithm via API
/// Communicates with Python FastAPI backend for accurate time-series forecasting
class BudgetForecastService {
  static const String _tag = '[BudgetForecastService]';
  static const int _minHistoricalMonths = 3;

  // Backend API configuration - CHANGE THIS for production
  //
  // LOCAL DEVELOPMENT (default):
  static const String _backendUrl = 'https://fyp-zy.onrender.com';
  //
  // CLOUD DEPLOYMENT (uncomment one):
  // static const String _backendUrl = 'https://your-app.up.railway.app';  // Railway (recommended)
  // static const String _backendUrl = 'https://your-app.onrender.com';     // Render
  // static const String _backendUrl = 'https://your-replit.replit.dev';    // Replit
  //
  // See RAILWAY_DEPLOYMENT_GUIDE.md for step-by-step cloud setup!
  static const Duration _timeout = Duration(seconds: 30);

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

  /// Calls the Prophet forecasting API
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

      // Prepare request payload
      final List<Map<String, dynamic>> histData = historicalData.map((h) {
        return {
          'date': h.date.toIso8601String().split('T')[0], // YYYY-MM-DD
          'amount': h.amount,
        };
      }).toList();

      final requestBody = {
        'historical_data': histData,
        'forecast_periods': forecastMonths,
        'budget_amount': budgetAmount,
      };

      print('$_tag Calling Prophet API at $_backendUrl/forecast');
      print('$_tag Request: ${jsonEncode(requestBody)}');

      // Make API request
      final response = await http
          .post(
            Uri.parse('$_backendUrl/forecast'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(_timeout);

      print('$_tag API Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final decodedResponse =
            jsonDecode(response.body) as Map<String, dynamic>;

        print('$_tag API Response: ${response.body}');

        // Parse forecast results
        final List<dynamic> forecastList = decodedResponse['forecast'] ?? [];
        final double mae = (decodedResponse['mae'] ?? 0.0).toDouble();
        final bool hasSufficientData =
            decodedResponse['has_sufficient_data'] ?? false;
        final String alertStatus = decodedResponse['alert_status'] ?? 'normal';
        final String alertMessage = decodedResponse['alert_message'] ?? '';

        final results = forecastList.asMap().entries.map((entry) {
          final index = entry.key;
          final forecast = entry.value as Map<String, dynamic>;

          return ForecastResult(
            date: DateTime.parse(forecast['date'] as String),
            forecastedAmount: (forecast['predicted_amount'] ?? 0.0).toDouble(),
            lowerBound: (forecast['lower_bound'] ?? 0.0).toDouble(),
            upperBound: (forecast['upper_bound'] ?? 0.0).toDouble(),
            isAnomaly: forecast['is_anomaly'] ?? false,
            mae: mae,
            hasSufficientData: hasSufficientData,
            // Only first forecast has alert status/message
            alertStatus: index == 0 ? alertStatus : 'normal',
            alertMessage: index == 0 ? alertMessage : '',
          );
        }).toList();

        print('$_tag Successfully parsed ${results.length} forecast points');
        return results;
      } else {
        print('$_tag API Error: ${response.statusCode} - ${response.body}');
        throw Exception(
          'Prophet API Error: ${response.statusCode} - ${response.body}',
        );
      }
    } on http.ClientException catch (e) {
      print('$_tag Network Error: $e');
      throw Exception(
        'Network Error: Could not connect to Prophet API at $_backendUrl. '
        'Make sure the backend is running.',
      );
    } catch (e) {
      print('$_tag Error calling forecast API: $e');
      throw Exception('Forecast API Error: $e');
    }
  }

  /// Checks backend health before making forecast
  Future<bool> _checkBackendHealth() async {
    try {
      final response = await http
          .get(Uri.parse('$_backendUrl/health'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      print('$_tag Backend health check failed: $e');
      return false;
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

      // Check backend health first
      final isHealthy = await _checkBackendHealth();
      if (!isHealthy) {
        throw Exception(
          'Prophet backend is not available. '
          'Please ensure the backend server is running at $_backendUrl',
        );
      }

      // Call Prophet API for forecast
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
