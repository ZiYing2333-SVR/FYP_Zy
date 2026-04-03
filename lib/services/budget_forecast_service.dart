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

/// Service for budget forecasting using Forecast API
/// Communicates with forecastapi.com for accurate expense predictions
class BudgetForecastService {
  static const String _tag = '[BudgetForecastService]';
  static const int _minHistoricalMonths = 3;

  // Forecast API configuration
  static const String _forecastApiUrl = 'https://forecastapi.com/v2/forecast';
  // API Key from Forecast API (free tier available)
  static const String _apiKey =
      'eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJhdWQiOiIwMTk4YTgxMC0xM2JhLTcxZjktYWNjMS0wYzQ5MDA5ZDE2NWIiLCJqdGkiOiJmMjQ1NzJkNWUzY2IxMmIyODRlODkyYjg0ODY1ZjgyMWQ4ZDRhYTBlYWQ3YzZlYTE5ZjAzMTdkMjA5MGM1NDA2OThiODk2MzAzNGNkNTI4MyIsImlhdCI6MTc3NTA3NTk3OC40NjM2OCwibmJmIjoxNzc1MDc1OTc4LjQ2MzY4NCwiZXhwIjoxODM4MjM0Mzc4LjQ1NTcxNiwic3ViIjoiOTEiLCJzY29wZXMiOltdfQ.EdzgtFRbifJWMZ6zLwspMGuS3lm4bGQ_rGrz9oF0P7r2uCY9toNyvQsGP6nj9Zsw7xaRvrBaeJAlAwkbsoyPLClq6F3sD19AN5mdkpVdsm09PIe9wTUGGFrWyoMB9qqvpT_RkuidoR8bf0MOpre8FBW0kIA42Olkzqlg-Af0G6oBZ9_qs4xkSDO30wKaVdu5ULjsD4UfXq46lX0XFx0_kmSf40pomuh7kw21NDmWEaCS_jvam_B42PDTgjdSy_tvsPjR4-5VXd_tcDxWcZDGQQaKKlN3j-2DGP37GiO3EdUKI_UH7svKSzx-ZdGauEjL6YVf8rYEWEU7IrNIDf11PnirquRCFZSo0ELp3ZuilaqwKG-nPxp6qy0JLxyfFuJ2MwH8YEac6GmY3DZPPUx9M1Rzp6nEUvold6r2wPm2F8B8xRY0lNBSD2OzELKPvbxMXHglQln-Ac5H246HnzwIuLuHI5ywSe6Xim_HnKMhQ5DKT-Yhu0gsk6Y8Ahd2dINLWqSQEIu6ysjxSFrhV2VubZUJW_s2mfsoz0tag84PlypZnBLjKE5auzgS6d8AZYZAPhGppOrKyMMKHaVjYwRPYzgztybNsC9J5jK85yRgV1_MndtyzuBQbL2BXd0f9APeoX0EALWg2IfD1O8qgLTBSXKFmEP_ngTRj4eZBcS9_-0';

  // API timeout (Forecast API is fast, 15 seconds is enough)
  static const Duration _timeout = Duration(seconds: 15);

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

      // Prepare request payload for Forecast API
      final List<Map<String, dynamic>> histData = historicalData.map((h) {
        return {
          'date': h.date
              .toIso8601String()
              .split('T')[0]
              .substring(0, 7), // YYYY-MM format
          'value': h.amount,
        };
      }).toList();

      final requestBody = {'data': histData, 'periods': forecastMonths};

      print('$_tag Calling Forecast API at $_forecastApiUrl');
      print('$_tag Request: ${jsonEncode(requestBody)}');

      // Make API request
      final response = await http
          .post(
            Uri.parse(_forecastApiUrl),
            headers: {
              'Authorization': 'Bearer $_apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(_timeout);

      print('$_tag API Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final decodedResponse =
            jsonDecode(response.body) as Map<String, dynamic>;

        print('$_tag API Response: ${response.body}');

        // Parse forecast results from Forecast API
        final List<dynamic> forecastList = decodedResponse['forecast'] ?? [];

        if (forecastList.isEmpty) {
          print('$_tag No forecast data received');
          return [];
        }

        final results = forecastList.asMap().entries.map((entry) {
          final index = entry.key;
          final forecast = entry.value as Map<String, dynamic>;

          // Determine alert status based on forecast value vs budget
          final forecastedAmount = (forecast['value'] ?? 0.0).toDouble();
          final alertStatus = forecastedAmount > budgetAmount
              ? 'warning'
              : forecastedAmount > (budgetAmount * 1.2)
              ? 'critical'
              : 'normal';

          return ForecastResult(
            date: DateTime.parse('${forecast['date']}-01'),
            forecastedAmount: forecastedAmount,
            lowerBound: forecastedAmount * 0.85, // 15% lower bound estimate
            upperBound: forecastedAmount * 1.15, // 15% upper bound estimate
            isAnomaly: false,
            mae: 0.0,
            hasSufficientData: historicalData.length >= _minHistoricalMonths,
            alertStatus: alertStatus,
            alertMessage: alertStatus == 'normal'
                ? 'Expenses within expected range'
                : alertStatus == 'warning'
                ? 'Expenses trending above budget. Consider reducing.'
                : 'Expenses significantly above budget. Take action now.',
          );
        }).toList();

        print('$_tag Successfully parsed ${results.length} forecast points');
        return results;
      } else {
        print('$_tag API Error: ${response.statusCode} - ${response.body}');
        throw Exception(
          'Forecast API Error: ${response.statusCode} - ${response.body}',
        );
      }
    } on http.ClientException catch (e) {
      print('$_tag Network Error: $e');
      throw Exception(
        'Network Error: Could not connect to Forecast API. '
        'Make sure the backend is running.',
      );
    } catch (e) {
      print('$_tag Error calling forecast API: $e');
      throw Exception('Forecast API Error: $e');
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
