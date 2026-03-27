import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

/// Data models for Intelligent Savings Goal Assistant

class GoalFeasibilityResult {
  final bool success;
  final bool isFeasible;
  final double monthlySavings;
  final List<double> cumulativeSavingsTimeline;
  final String analysis;
  final List<String> suggestions;
  final String confidenceLevel; // 'low', 'medium', 'high'

  GoalFeasibilityResult({
    required this.success,
    required this.isFeasible,
    required this.monthlySavings,
    required this.cumulativeSavingsTimeline,
    required this.analysis,
    required this.suggestions,
    required this.confidenceLevel,
  });

  factory GoalFeasibilityResult.fromJson(Map<String, dynamic> json) {
    return GoalFeasibilityResult(
      success: json['success'] ?? false,
      isFeasible: json['is_feasible'] ?? false,
      monthlySavings: (json['monthly_savings'] ?? 0).toDouble(),
      cumulativeSavingsTimeline: List<double>.from(
        (json['cumulative_savings_timeline'] as List?)?.map(
              (x) => (x as num).toDouble(),
            ) ??
            [],
      ),
      analysis: json['analysis'] ?? '',
      suggestions: List<String>.from(json['suggestions'] ?? []),
      confidenceLevel: json['confidence_level'] ?? 'medium',
    );
  }
}

class SmartRecommendation {
  final bool success;
  final List<String> recommendations;
  final List<String> priorityActions;
  final List<Map<String, dynamic>> estimatedImpact;

  SmartRecommendation({
    required this.success,
    required this.recommendations,
    required this.priorityActions,
    required this.estimatedImpact,
  });

  factory SmartRecommendation.fromJson(Map<String, dynamic> json) {
    return SmartRecommendation(
      success: json['success'] ?? false,
      recommendations: List<String>.from(json['recommendations'] ?? []),
      priorityActions: List<String>.from(json['priority_actions'] ?? []),
      estimatedImpact: List<Map<String, dynamic>>.from(
        (json['estimated_impact'] as List?)?.cast<Map<String, dynamic>>() ?? [],
      ),
    );
  }
}

class ScenarioResult {
  final String description;
  final int newTimelineMonths;
  final double newMonthlySavings;
  final double totalSavingsVariation;

  ScenarioResult({
    required this.description,
    required this.newTimelineMonths,
    required this.newMonthlySavings,
    required this.totalSavingsVariation,
  });

  factory ScenarioResult.fromJson(Map<String, dynamic> json) {
    return ScenarioResult(
      description: json['description'] ?? '',
      newTimelineMonths: json['new_timeline_months'] ?? 0,
      newMonthlySavings: (json['new_monthly_savings'] ?? 0).toDouble(),
      totalSavingsVariation: (json['total_savings_variation'] ?? 0).toDouble(),
    );
  }
}

class NaturalLanguageReport {
  final bool success;
  final String executiveSummary;
  final String financialAnalysis;
  final String goalFeasibilityAnalysis;
  final String personalizedRecommendations;
  final List<String> actionItems;
  final List<String> warningSignals;

  NaturalLanguageReport({
    required this.success,
    required this.executiveSummary,
    required this.financialAnalysis,
    required this.goalFeasibilityAnalysis,
    required this.personalizedRecommendations,
    required this.actionItems,
    required this.warningSignals,
  });

  factory NaturalLanguageReport.fromJson(Map<String, dynamic> json) {
    return NaturalLanguageReport(
      success: json['success'] ?? false,
      executiveSummary: json['executive_summary'] ?? '',
      financialAnalysis: json['financial_analysis'] ?? '',
      goalFeasibilityAnalysis: json['goal_feasibility_analysis'] ?? '',
      personalizedRecommendations: json['personalized_recommendations'] ?? '',
      actionItems: List<String>.from(json['action_items'] ?? []),
      warningSignals: List<String>.from(json['warning_signals'] ?? []),
    );
  }
}

/// Intelligent Savings Goal Assistant Service
/// Provides AI-powered analysis for savings goals using Google Gemini
class IntelligentSavingsGoalAssistant {
  static const String _tag = '[IntelligentSavingsGoalAssistant]';

  // Backend API configuration
  static const String _backendUrl = 'https://fyp-zy.onrender.com';
  // For local development, uncomment:
  // static const String _backendUrl = 'http://localhost:8000';

  static const Duration _timeout = Duration(seconds: 30);

  /// 1️⃣ ANALYZE GOAL FEASIBILITY
  /// Checks if a savings goal is realistic and provides AI analysis
  static Future<GoalFeasibilityResult> analyzeGoalFeasibility({
    required double monthlyIncome,
    required double monthlyExpenses,
    required double goalAmount,
    required int timelineMonths,
  }) async {
    try {
      final url = Uri.parse('$_backendUrl/savings-goal/feasibility');

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'monthly_income': monthlyIncome,
              'monthly_expenses': monthlyExpenses,
              'goal_amount': goalAmount,
              'timeline_months': timelineMonths,
            }),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return GoalFeasibilityResult.fromJson(json);
      } else {
        print('$_tag Feasibility analysis error: ${response.statusCode}');
        return GoalFeasibilityResult(
          success: false,
          isFeasible: false,
          monthlySavings: monthlyIncome - monthlyExpenses,
          cumulativeSavingsTimeline: [],
          analysis: 'Error analyzing goal feasibility',
          suggestions: [],
          confidenceLevel: 'low',
        );
      }
    } catch (e) {
      print('$_tag Error in analyzeGoalFeasibility: $e');
      rethrow;
    }
  }

  /// 2️⃣ GET SMART RECOMMENDATIONS
  /// Provides AI-powered personalized recommendations to reach goal faster
  static Future<SmartRecommendation> getSmartRecommendations({
    required double monthlyIncome,
    required double monthlyExpenses,
    required double goalAmount,
    required int timelineMonths,
    double currentSavings = 0.0,
    Map<String, double>? spendingBreakdown,
  }) async {
    try {
      final url = Uri.parse('$_backendUrl/savings-goal/recommendations');

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'monthly_income': monthlyIncome,
              'monthly_expenses': monthlyExpenses,
              'goal_amount': goalAmount,
              'timeline_months': timelineMonths,
              'current_savings': currentSavings,
              'spending_breakdown': spendingBreakdown ?? {},
            }),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return SmartRecommendation.fromJson(json);
      } else {
        print('$_tag Recommendations error: ${response.statusCode}');
        return SmartRecommendation(
          success: false,
          recommendations: [],
          priorityActions: [],
          estimatedImpact: [],
        );
      }
    } catch (e) {
      print('$_tag Error in getSmartRecommendations: $e');
      rethrow;
    }
  }

  /// 3️⃣ SIMULATE SCENARIOS
  /// Shows impact of different expense reduction scenarios on timeline
  static Future<List<ScenarioResult>> simulateScenarios({
    required double monthlyIncome,
    required double monthlyExpenses,
    required double goalAmount,
    required int timelineMonths,
    List<double>? expenseReductionPercentages,
  }) async {
    try {
      final url = Uri.parse('$_backendUrl/savings-goal/scenarios');

      // Default scenarios if not provided
      final scenarios = expenseReductionPercentages != null
          ? expenseReductionPercentages
                .map((pct) => {'expense_reduction': pct})
                .toList()
          : [
              {'expense_reduction': 0.05}, // 5% reduction
              {'expense_reduction': 0.10}, // 10% reduction
              {'expense_reduction': 0.15}, // 15% reduction
              {'expense_reduction': 0.20}, // 20% reduction
            ];

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'monthly_income': monthlyIncome,
              'monthly_expenses': monthlyExpenses,
              'goal_amount': goalAmount,
              'base_timeline_months': timelineMonths,
              'scenarios': scenarios,
            }),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return (json as List)
            .map((item) => ScenarioResult.fromJson(item))
            .toList();
      } else {
        print('$_tag Scenario simulation error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('$_tag Error in simulateScenarios: $e');
      rethrow;
    }
  }

  /// 4️⃣ GENERATE NATURAL LANGUAGE REPORT
  /// Creates a friendly, comprehensive savings goal report
  static Future<NaturalLanguageReport> generateNaturalLanguageReport({
    required double monthlyIncome,
    required double predictedMonthlyExpense,
    required double goalAmount,
    required int timelineMonths,
    required List<double> cumulativeSavingsTimeline,
    Map<String, double>? actualSpendingPatterns,
  }) async {
    try {
      final url = Uri.parse('$_backendUrl/savings-goal/report');

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'monthly_income': monthlyIncome,
              'predicted_monthly_expense': predictedMonthlyExpense,
              'goal_amount': goalAmount,
              'timeline_months': timelineMonths,
              'cumulative_savings': cumulativeSavingsTimeline,
              'actual_spending_patterns': actualSpendingPatterns ?? {},
            }),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return NaturalLanguageReport.fromJson(json);
      } else {
        print('$_tag Report generation error: ${response.statusCode}');
        return NaturalLanguageReport(
          success: false,
          executiveSummary: 'Error generating report',
          financialAnalysis: '',
          goalFeasibilityAnalysis: '',
          personalizedRecommendations: '',
          actionItems: [],
          warningSignals: [],
        );
      }
    } catch (e) {
      print('$_tag Error in generateNaturalLanguageReport: $e');
      rethrow;
    }
  }

  /// Helper: Calculate basic savings metrics
  static Map<String, dynamic> calculateSavingsMetrics({
    required double monthlyIncome,
    required double monthlyExpenses,
    required double goalAmount,
    required int timelineMonths,
  }) {
    final monthlySavings = monthlyIncome - monthlyExpenses;
    final timelineNeeded = monthlySavings > 0
        ? (goalAmount / monthlySavings).ceil()
        : double.infinity;
    final isFeasible = timelineNeeded <= timelineMonths && monthlySavings > 0;

    return {
      'monthly_savings': monthlySavings,
      'timeline_needed': timelineNeeded,
      'is_feasible': isFeasible,
      'monthly_rate': (monthlySavings / goalAmount * 100).clamp(0, 100),
    };
  }

  /// Helper: Format currency for display
  static String formatCurrency(double amount) {
    return 'RM${amount.toStringAsFixed(2)}';
  }

  /// Helper: Generate chart data for cumulative savings visualization
  static List<Map<String, dynamic>> generateChartData(
    List<double> cumulativeSavings,
  ) {
    return List.generate(
      cumulativeSavings.length,
      (index) => {
        'month': index + 1,
        'cumulative_savings': cumulativeSavings[index],
      },
    );
  }
}
