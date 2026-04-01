import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'package:intl/intl.dart';

/// Data models for Intelligent Savings Goal Assistant

// ==================== INCOME CHECK RESULT (Recent 3 months) ====================
class IncomeCheckResult {
  final bool hasRecentIncome; // Has any salary income in past 3 months
  final String? salaryCategoryId; // ID of the salary category to use

  IncomeCheckResult({required this.hasRecentIncome, this.salaryCategoryId});
}

// ==================== INCOME VALIDATION RESULT ====================
class IncomeValidationResult {
  final bool success;
  final bool hasConsistentIncome; // Has at least 3 months of salary income
  final double averageMonthlyIncome;
  final List<String> salaryMonths; // Months with salary income (YYYY-MM)
  final int consistentMonthsCount;
  final String message;
  final String? salaryCategoryId; // ID of the salary category to use

  IncomeValidationResult({
    required this.success,
    required this.hasConsistentIncome,
    required this.averageMonthlyIncome,
    required this.salaryMonths,
    required this.consistentMonthsCount,
    required this.message,
    this.salaryCategoryId,
  });
}

// ==================== SAVINGS SUGGESTION RESULT ====================
class SavingsSuggestionResult {
  final bool success;
  final double suggestedMonthlySavings; // Recommended 20% of salary
  final double requiredMonthlySavings; // Actual amount needed to reach target
  final double targetAmount;
  final int timelineMonths;
  final DateTime targetDate;
  final double averageMonthlyIncome;
  final String analysis;
  final bool isFeasible;
  final String feasibilityMessage;

  SavingsSuggestionResult({
    required this.success,
    required this.suggestedMonthlySavings,
    required this.requiredMonthlySavings,
    required this.targetAmount,
    required this.timelineMonths,
    required this.targetDate,
    required this.averageMonthlyIncome,
    required this.analysis,
    required this.isFeasible,
    required this.feasibilityMessage,
  });
}

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

// ==================== FORECAST API MODELS ====================
class ForecastResult {
  final bool success;
  final List<double> forecast; // Predicted spending values
  final String period; // e.g., "month", "week"
  final int periodsAhead; // Number of periods forecasted
  final double confidence; // Confidence level (0-1)

  ForecastResult({
    required this.success,
    required this.forecast,
    required this.period,
    required this.periodsAhead,
    required this.confidence,
  });

  factory ForecastResult.fromJson(Map<String, dynamic> json) {
    List<double> forecastValues = [];
    if (json['forecast'] is List) {
      forecastValues = List<double>.from(
        (json['forecast'] as List).map((x) => (x as num).toDouble()),
      );
    }

    return ForecastResult(
      success: json['success'] ?? false,
      forecast: forecastValues,
      period: json['period'] ?? 'month',
      periodsAhead: json['periods_ahead'] ?? 1,
      confidence: (json['confidence'] ?? 0).toDouble(),
    );
  }
}

class SpendingSuggestion {
  final bool success;
  final String suggestion;
  final String severity; // 'low', 'medium', 'high'
  final double trendChange; // Percentage change from average
  final List<String> actionItems;
  final String confidenceLevel;

  SpendingSuggestion({
    required this.success,
    required this.suggestion,
    required this.severity,
    required this.trendChange,
    required this.actionItems,
    required this.confidenceLevel,
  });

  factory SpendingSuggestion.fromJson(Map<String, dynamic> json) {
    return SpendingSuggestion(
      success: json['success'] ?? false,
      suggestion: json['suggestion'] ?? '',
      severity: json['severity'] ?? 'medium',
      trendChange: (json['trend_change'] ?? 0).toDouble(),
      actionItems: List<String>.from(json['action_items'] ?? []),
      confidenceLevel: json['confidence_level'] ?? 'medium',
    );
  }
}

class CategorySpendingAdvice {
  final bool success;
  final String categoryName;
  final double percentOfTotal;
  final String advice;
  final List<String> savingtips;
  final bool isConcerning;

  CategorySpendingAdvice({
    required this.success,
    required this.categoryName,
    required this.percentOfTotal,
    required this.advice,
    required this.savingtips,
    required this.isConcerning,
  });

  factory CategorySpendingAdvice.fromJson(Map<String, dynamic> json) {
    return CategorySpendingAdvice(
      success: json['success'] ?? false,
      categoryName: json['category_name'] ?? '',
      percentOfTotal: (json['percent_of_total'] ?? 0).toDouble(),
      advice: json['advice'] ?? '',
      savingtips: List<String>.from(json['saving_tips'] ?? []),
      isConcerning: json['is_concerning'] ?? false,
    );
  }
}

// ==================== FORECAST-AWARE SAVINGS ANALYSIS ====================
class ForecastAwareSavingsAnalysis {
  final bool success;
  final double monthlyIncome;
  final double predictedMonthlyExpense;
  final double expenseRatio; // Percentage of income spent (0-100)
  final double availableForSavings; // Remaining after expenses
  final double originalSavingsTarget; // Original 20% goal
  final double adjustedSavingsTarget; // Recommended savings if >80% expenses
  final String riskLevel; // 'low', 'medium', 'high'
  final String analysis;
  final bool isSavingsGoalFeasible; // Can achieve 20% savings with forecast?
  final List<String> urgentActions; // What to do now
  final List<String> categoryReductionSuggestions; // Reduce X by Y%
  final int recommendedExpenseReductionPercent; // How much to reduce
  final String scenario; // "optimistic", "realistic", "pessimistic"
  final List<Map<String, dynamic>>
  alternativeScenarios; // Different goals possible

  ForecastAwareSavingsAnalysis({
    required this.success,
    required this.monthlyIncome,
    required this.predictedMonthlyExpense,
    required this.expenseRatio,
    required this.availableForSavings,
    required this.originalSavingsTarget,
    required this.adjustedSavingsTarget,
    required this.riskLevel,
    required this.analysis,
    required this.isSavingsGoalFeasible,
    required this.urgentActions,
    required this.categoryReductionSuggestions,
    required this.recommendedExpenseReductionPercent,
    required this.scenario,
    required this.alternativeScenarios,
  });

  factory ForecastAwareSavingsAnalysis.fromJson(Map<String, dynamic> json) {
    return ForecastAwareSavingsAnalysis(
      success: json['success'] ?? false,
      monthlyIncome: (json['monthly_income'] ?? 0).toDouble(),
      predictedMonthlyExpense: (json['predicted_monthly_expense'] ?? 0)
          .toDouble(),
      expenseRatio: (json['expense_ratio'] ?? 0).toDouble(),
      availableForSavings: (json['available_for_savings'] ?? 0).toDouble(),
      originalSavingsTarget: (json['original_savings_target'] ?? 0).toDouble(),
      adjustedSavingsTarget: (json['adjusted_savings_target'] ?? 0).toDouble(),
      riskLevel: json['risk_level'] ?? 'medium',
      analysis: json['analysis'] ?? '',
      isSavingsGoalFeasible: json['is_savings_goal_feasible'] ?? false,
      urgentActions: List<String>.from(json['urgent_actions'] ?? []),
      categoryReductionSuggestions: List<String>.from(
        json['category_reduction_suggestions'] ?? [],
      ),
      recommendedExpenseReductionPercent:
          json['recommended_expense_reduction_percent'] ?? 0,
      scenario: json['scenario'] ?? 'realistic',
      alternativeScenarios: List<Map<String, dynamic>>.from(
        (json['alternative_scenarios'] as List?)
                ?.cast<Map<String, dynamic>>() ??
            [],
      ),
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
/// Enhanced with income validation based on salary category transactions
class IntelligentSavingsGoalAssistant {
  static const String _tag = '[IntelligentSavingsGoalAssistant]';

  // Backend API configuration
  static const String _backendUrl = 'https://fyp-zy.onrender.com';
  // For local development, uncomment:
  // static const String _backendUrl = 'http://localhost:8000';

  static const Duration _timeout = Duration(seconds: 30);
  static const int _minConsistentMonths =
      3; // Minimum months for consistent income

  /// =========== INCOME VALIDATION & ANALYSIS ===========

  /// Check income in PAST 3 MONTHS ONLY
  /// Returns true if user has any income in the last 3 months
  /// Used to determine if income selection dialog should be shown
  ///
  /// Query Flow (SMART APPROACH):
  /// 1. Query Transaction table for type='income' in past 90 days
  /// 2. Get distinct categoryIds from those income transactions
  /// 3. Go to Category table and search those categoryIds for name ILIKE '%salary%' (case-insensitive)
  /// 4. Return true if salary category found with recent transactions
  static Future<IncomeCheckResult> checkRecentIncomeExists(
    String userId,
  ) async {
    try {
      final today = DateTime.now();
      final threeMonthsAgo = today.subtract(const Duration(days: 90));
      final dateString = DateFormat('yyyy-MM-dd').format(threeMonthsAgo);

      print(
        '$_tag [checkRecentIncomeExists] Step 1: Query Transaction table for type=income from $dateString to now',
      );

      // 1. Get all income transactions from past 3 months
      final incomeTransactions = await Supabase.instance.client
          .from('Transaction')
          .select('categoryId, amount, date')
          .eq('type', 'income') // CRITICAL: type must be 'income'
          .gte('date', dateString); // CRITICAL: past 90 days only

      print(
        '$_tag [checkRecentIncomeExists] Found ${incomeTransactions.length} income transactions in past 3 months',
      );

      if (incomeTransactions.isEmpty) {
        print(
          '$_tag [checkRecentIncomeExists] ⚠️ No income transactions found in past 3 months',
        );
        return IncomeCheckResult(
          hasRecentIncome: false,
          salaryCategoryId: null,
        );
      }

      // 2. Extract distinct categoryIds from income transactions
      final distinctCategoryIds = <String>{};
      for (final txn in incomeTransactions) {
        final catId = txn['categoryId'];
        final amount = (txn['amount'] ?? 0).toDouble().abs();

        if (catId != null && amount > 0) {
          distinctCategoryIds.add(catId as String);
        }
      }

      print(
        '$_tag [checkRecentIncomeExists] Step 2: Found ${distinctCategoryIds.length} distinct income category IDs: $distinctCategoryIds',
      );

      if (distinctCategoryIds.isEmpty) {
        print(
          '$_tag [checkRecentIncomeExists] ⚠️ No valid income categories found (all amounts were 0)',
        );
        return IncomeCheckResult(
          hasRecentIncome: false,
          salaryCategoryId: null,
        );
      }

      // 3. Go to Category table and find which of these categoryIds has name ILIKE '%salary%'
      print(
        '$_tag [checkRecentIncomeExists] Step 3: Searching Category table for salary category among: $distinctCategoryIds',
      );

      final salaryCategories = await Supabase.instance.client
          .from('Category')
          .select()
          .inFilter('categoryId', distinctCategoryIds.toList())
          .ilike('name', '%salary%'); // Case-insensitive search for "salary"

      print(
        '$_tag [checkRecentIncomeExists] Found ${salaryCategories.length} salary categories matching pattern "%salary%"',
      );

      if (salaryCategories.isNotEmpty) {
        final salaryCategoryId = salaryCategories[0]['categoryId'] as String;
        final categoryName = salaryCategories[0]['name'] as String;

        print(
          '$_tag [checkRecentIncomeExists] ✅ Found SALARY category: "$categoryName" (id=$salaryCategoryId)',
        );

        return IncomeCheckResult(
          hasRecentIncome: true,
          salaryCategoryId: salaryCategoryId,
        );
      }

      // No salary category found, but income transactions exist
      print(
        '$_tag [checkRecentIncomeExists] ⚠️ No salary category found, but ${distinctCategoryIds.length} income categories exist',
      );

      // Get the category names for debugging
      final allIncomeCategoriesUsed = await Supabase.instance.client
          .from('Category')
          .select()
          .inFilter('categoryId', distinctCategoryIds.toList());

      for (final cat in allIncomeCategoriesUsed) {
        print(
          '$_tag [checkRecentIncomeExists] Available income category: "${cat['name']}" (id=${cat['categoryId']})',
        );
      }

      // Use first income category as fallback
      if (allIncomeCategoriesUsed.isNotEmpty) {
        final fallbackCategoryId =
            allIncomeCategoriesUsed[0]['categoryId'] as String;
        print(
          '$_tag [checkRecentIncomeExists] Using fallback category: ${allIncomeCategoriesUsed[0]['name']} (id=$fallbackCategoryId)',
        );

        return IncomeCheckResult(
          hasRecentIncome: true,
          salaryCategoryId: fallbackCategoryId,
        );
      }

      return IncomeCheckResult(hasRecentIncome: false, salaryCategoryId: null);
    } catch (e) {
      print('$_tag ❌ Error checking recent income: $e');
      return IncomeCheckResult(hasRecentIncome: false, salaryCategoryId: null);
    }
  }

  /// 0️⃣ VALIDATE CONSISTENT INCOME
  /// Checks if user has at least 3 consecutive months of salary income from 12-month history
  /// Uses the SMART APPROACH: Find salary category from actual income transactions (past 12 months)
  /// This ensures we find the actual salary category being used, not just any category named "salary"
  static Future<IncomeValidationResult> validateConsistentIncome(
    String userId,
  ) async {
    try {
      final today = DateTime.now();
      final oneYearAgo = today.subtract(const Duration(days: 365));
      final dateString = DateFormat('yyyy-MM-dd').format(oneYearAgo);

      print(
        '$_tag [validateConsistentIncome] Step 1: Query Transaction table for type=income from $dateString to now',
      );

      // 1. Get all income transactions from past 12 months
      final incomeTransactions = await Supabase.instance.client
          .from('Transaction')
          .select('categoryId, amount, date')
          .eq('type', 'income')
          .gte('date', dateString);

      print(
        '$_tag [validateConsistentIncome] Found ${incomeTransactions.length} income transactions in past 12 months',
      );

      if (incomeTransactions.isEmpty) {
        return IncomeValidationResult(
          success: true,
          hasConsistentIncome: false,
          averageMonthlyIncome: 0,
          salaryMonths: [],
          consistentMonthsCount: 0,
          message:
              'No income transactions found in the past 12 months. Please record your income first.',
          salaryCategoryId: null,
        );
      }

      // 2. Extract distinct categoryIds from income transactions
      final distinctCategoryIds = <String>{};
      for (final txn in incomeTransactions) {
        final catId = txn['categoryId'];
        final amount = (txn['amount'] ?? 0).toDouble().abs();

        if (catId != null && amount > 0) {
          distinctCategoryIds.add(catId as String);
        }
      }

      print(
        '$_tag [validateConsistentIncome] Step 2: Found ${distinctCategoryIds.length} distinct income category IDs',
      );

      if (distinctCategoryIds.isEmpty) {
        return IncomeValidationResult(
          success: true,
          hasConsistentIncome: false,
          averageMonthlyIncome: 0,
          salaryMonths: [],
          consistentMonthsCount: 0,
          message:
              'No valid income categories found (all amounts were 0). Please record your income first.',
          salaryCategoryId: null,
        );
      }

      // 3. Go to Category table and find which of these categoryIds has name ILIKE '%salary%'
      print(
        '$_tag [validateConsistentIncome] Step 3: Searching Category table for salary category',
      );

      final salaryCategories = await Supabase.instance.client
          .from('Category')
          .select()
          .inFilter('categoryId', distinctCategoryIds.toList())
          .ilike('name', '%salary%');

      print(
        '$_tag [validateConsistentIncome] Found ${salaryCategories.length} salary categories matching pattern "%salary%"',
      );

      // If no salary category found, try using any income category as fallback
      String? salaryCategoryId;
      if (salaryCategories.isNotEmpty) {
        salaryCategoryId = salaryCategories[0]['categoryId'] as String;
        print(
          '$_tag [validateConsistentIncome] ✅ Using salary category: "${salaryCategories[0]['name']}" (id=$salaryCategoryId)',
        );
      } else {
        // Fallback: use first income category
        final allIncomCategories = await Supabase.instance.client
            .from('Category')
            .select()
            .inFilter('categoryId', distinctCategoryIds.toList());

        if (allIncomCategories.isNotEmpty) {
          salaryCategoryId = allIncomCategories[0]['categoryId'] as String;
          print(
            '$_tag [validateConsistentIncome] No salary category found, using fallback: "${allIncomCategories[0]['name']}" (id=$salaryCategoryId)',
          );
        } else {
          return IncomeValidationResult(
            success: true,
            hasConsistentIncome: false,
            averageMonthlyIncome: 0,
            salaryMonths: [],
            consistentMonthsCount: 0,
            message:
                'No salary income category found. Please record your monthly salary first.',
            salaryCategoryId: null,
          );
        }
      }

      // 4. Now fetch all transactions for this salary category (already have them from step 1)
      // Filter the incomeTransactions we already fetched to only include the salary category
      print(
        '$_tag [validateConsistentIncome] Step 4: Grouping salary transactions by month',
      );

      final salaryTransactions = incomeTransactions
          .where((txn) => txn['categoryId'] == salaryCategoryId)
          .toList();

      print(
        '$_tag [validateConsistentIncome] Found ${salaryTransactions.length} salary transactions for categoryId=$salaryCategoryId',
      );

      if (salaryTransactions.isEmpty) {
        return IncomeValidationResult(
          success: true,
          hasConsistentIncome: false,
          averageMonthlyIncome: 0,
          salaryMonths: [],
          consistentMonthsCount: 0,
          message:
              'No salary income records found. Please record your monthly salary in the transaction page.',
          salaryCategoryId: salaryCategoryId,
        );
      }

      // 5. Group transactions by month and calculate monthly income
      final monthlyIncomeSalary = <String, double>{};
      for (final txn in salaryTransactions) {
        var date = txn['date'];
        final amount = (txn['amount'] ?? 0).toDouble().abs();

        if (date != null && amount > 0) {
          // Parse date - handle both DateTime and String types
          String dateStr;
          try {
            if (date is DateTime) {
              dateStr = DateFormat('yyyy-MM-dd').format(date);
            } else if (date is String) {
              dateStr = date;
            } else {
              // Fallback: convert to string first
              dateStr = date.toString();
              // If in ISO format like "2026-01-15T00:00:00", just take the date part
              if (dateStr.contains('T')) {
                dateStr = dateStr.split('T')[0];
              }
            }

            // Extract YYYY-MM from the date string (first 7 chars)
            if (dateStr.length >= 7) {
              final month = dateStr.substring(0, 7);
              monthlyIncomeSalary[month] =
                  (monthlyIncomeSalary[month] ?? 0) + amount;
            }
          } catch (e) {
            print(
              '$_tag [validateConsistentIncome] Warning: Failed to parse date "$date": $e',
            );
          }
        }
      }

      if (monthlyIncomeSalary.isEmpty) {
        return IncomeValidationResult(
          success: true,
          hasConsistentIncome: false,
          averageMonthlyIncome: 0,
          salaryMonths: [],
          consistentMonthsCount: 0,
          message:
              'No valid salary income records found. Please ensure income amounts are positive.',
          salaryCategoryId: salaryCategoryId,
        );
      }

      // 6. Check for consistency (at least 3 consecutive months)
      final sortedMonths = monthlyIncomeSalary.keys.toList()..sort();
      print(
        '$_tag [validateConsistentIncome] Salary months found: $sortedMonths',
      );

      final consistentMonths = _findConsecutiveMonths(sortedMonths);

      final hasConsistent = consistentMonths.length >= _minConsistentMonths;
      final avgIncome = monthlyIncomeSalary.values.isNotEmpty
          ? (monthlyIncomeSalary.values.reduce((a, b) => a + b) /
                    monthlyIncomeSalary.length)
                .toDouble()
          : 0.0;

      print(
        '$_tag [validateConsistentIncome] Consistent months: ${consistentMonths.length}, Average income: RM${avgIncome.toStringAsFixed(2)}/month',
      );

      return IncomeValidationResult(
        success: true,
        hasConsistentIncome: hasConsistent,
        averageMonthlyIncome: avgIncome,
        salaryMonths: sortedMonths,
        consistentMonthsCount: consistentMonths.length,
        message: hasConsistent
            ? 'Great! You have $_minConsistentMonths+ months of consistent income (RM${avgIncome.toStringAsFixed(2)}/month).'
            : 'You need to record at least $_minConsistentMonths months of consistent salary income before we can provide savings suggestions.',
        salaryCategoryId: salaryCategoryId,
      );
    } catch (e) {
      print('$_tag Error validating income: $e');
      return IncomeValidationResult(
        success: false,
        hasConsistentIncome: false,
        averageMonthlyIncome: 0,
        salaryMonths: [],
        consistentMonthsCount: 0,
        message: 'Error validating income: $e',
        salaryCategoryId: null,
      );
    }
  }

  /// 0️⃣ GENERATE SAVINGS SUGGESTION
  /// Calculates the monthly savings needed to reach goal by target date
  /// Returns feasibility assessment based on average monthly income and expenses
  ///
  /// Flow:
  /// 1. Validates consistent income (3+ consecutive months from 12-month history)
  /// 2. Fetches salary transactions from Category table (case-insensitive match for "Salary")
  /// 3. Calculates monthly savings needed: targetAmount ÷ timelineMonths
  /// 4. Assesses feasibility: suggestedMonthlySavings ≤ (monthlyIncome - monthlyExpenses)
  ///
  /// Tables Used:
  /// - Category: to find salary category (userId + type='income' + name like 'Salary')
  /// - Transaction: to fetch income and expense transactions with dates
  static Future<SavingsSuggestionResult> generateSavingsSuggestion({
    required String userId,
    required double targetAmount,
    required DateTime targetDate,
  }) async {
    try {
      // 1. Validate consistent income (requires 3+ consecutive months from past 12 months)
      final incomeValidation = await validateConsistentIncome(userId);

      if (!incomeValidation.success) {
        return SavingsSuggestionResult(
          success: false,
          suggestedMonthlySavings: 0,
          requiredMonthlySavings: 0,
          targetAmount: targetAmount,
          timelineMonths: 0,
          targetDate: targetDate,
          averageMonthlyIncome: 0,
          analysis: 'Failed to validate income',
          isFeasible: false,
          feasibilityMessage: incomeValidation.message,
        );
      }

      if (!incomeValidation.hasConsistentIncome) {
        return SavingsSuggestionResult(
          success: true,
          suggestedMonthlySavings: 0,
          requiredMonthlySavings: 0,
          targetAmount: targetAmount,
          timelineMonths: 0,
          targetDate: targetDate,
          averageMonthlyIncome: 0,
          analysis: 'Cannot provide suggestion without consistent income data',
          isFeasible: false,
          feasibilityMessage: incomeValidation.message,
        );
      }

      // 2. Calculate timeline (months from now to target date)
      final today = DateTime.now();
      final timelineMonths = _calculateMonthsBetween(today, targetDate);

      if (timelineMonths <= 0) {
        return SavingsSuggestionResult(
          success: false,
          suggestedMonthlySavings: 0,
          requiredMonthlySavings: 0,
          targetAmount: targetAmount,
          timelineMonths: 0,
          targetDate: targetDate,
          averageMonthlyIncome: incomeValidation.averageMonthlyIncome,
          analysis: 'Invalid target date',
          isFeasible: false,
          feasibilityMessage:
              'Target date must be in the future. Please select a date after today.',
        );
      }

      // 3. Calculate the RECOMMENDED savings (20% of monthly salary)
      final recommendedMonthlySavings =
          incomeValidation.averageMonthlyIncome * 0.20; // 20% of salary

      // 4. Calculate the REQUIRED monthly savings to reach the goal
      // IMPORTANT: Round up to 2 decimals to ensure we HIT the target amount exactly
      // Example: RM1000 / 12 months = RM83.33, but 83.33*12 = 999.96 (doesn't hit target!)
      // Solution: Round to RM83.34, so 83.34*12 = 1000.08 ✓ (hits and slightly exceeds target)
      final requiredMonthlySavings = _ceilToTwoDecimals(
        targetAmount / timelineMonths,
      );

      // 5. Get user's average monthly expenses to assess feasibility
      final expenses = await _getAverageMonthlyExpenses(
        userId,
      ); // Returns average or 0
      final monthlyNetIncome =
          (incomeValidation.averageMonthlyIncome - expenses).toDouble();

      // 6. Determine feasibility - Three stages
      // Stage 1: ACHIEVABLE - Required savings <= 20% of salary (recommended rate)
      // Stage 2: CHALLENGING - Required > 20% but <= net income (possible but tight)
      // Stage 3: IMPOSSIBLE - Required > net income (cannot afford)

      String feasibilityStage = 'achievable';
      String feasibilityMessage = '';
      bool isFeasible = false;

      if (requiredMonthlySavings <= recommendedMonthlySavings) {
        // STAGE 1: ACHIEVABLE
        feasibilityStage = 'achievable';
        isFeasible = true;
        feasibilityMessage =
            'Your goal requires RM${requiredMonthlySavings.toStringAsFixed(2)}/month, '
            'which is ${(requiredMonthlySavings / incomeValidation.averageMonthlyIncome * 100).toStringAsFixed(1)}% of your monthly income. '
            'This is comfortable and within the recommended 20% saving rate.';
      } else if (requiredMonthlySavings <= monthlyNetIncome) {
        // STAGE 2: CHALLENGING
        feasibilityStage = 'challenging';
        isFeasible = false;
        feasibilityMessage =
            'Your goal requires RM${requiredMonthlySavings.toStringAsFixed(2)}/month, '
            'which is ${(requiredMonthlySavings / incomeValidation.averageMonthlyIncome * 100).toStringAsFixed(1)}% of your monthly income. '
            'This exceeds the recommended 20% rate (RM${recommendedMonthlySavings.toStringAsFixed(2)}/month) but is within your net income capability. '
            'You can achieve this by cutting expenses or extending the timeline.';
      } else {
        // STAGE 3: IMPOSSIBLE
        feasibilityStage = 'impossible';
        isFeasible = false;
        feasibilityMessage =
            'Your goal requires RM${requiredMonthlySavings.toStringAsFixed(2)}/month, '
            'but your available monthly savings is only RM${monthlyNetIncome.toStringAsFixed(2)} (income RM${incomeValidation.averageMonthlyIncome.toStringAsFixed(2)} - expenses RM${expenses.toStringAsFixed(2)}). '
            'This goal cannot be achieved with your current financial situation. '
            'Please extend the timeline, reduce the goal amount, or increase your income.';
      }

      return SavingsSuggestionResult(
        success: true,
        suggestedMonthlySavings:
            recommendedMonthlySavings, // Recommended 20% of salary
        requiredMonthlySavings: requiredMonthlySavings, // Actual amount needed
        targetAmount: targetAmount,
        timelineMonths: timelineMonths,
        targetDate: targetDate,
        averageMonthlyIncome: incomeValidation.averageMonthlyIncome,
        analysis:
            'Based on your consistent monthly income of RM${incomeValidation.averageMonthlyIncome.toStringAsFixed(2)}, '
            'we recommend saving 20% (RM${recommendedMonthlySavings.toStringAsFixed(2)}/month). '
            'Your goal requires RM${requiredMonthlySavings.toStringAsFixed(2)}/month (${(requiredMonthlySavings / incomeValidation.averageMonthlyIncome * 100).toStringAsFixed(1)}% of income) to reach RM${targetAmount.toStringAsFixed(2)} by ${DateFormat('MMM yyyy').format(targetDate)}. '
            'Status: ${feasibilityStage.toUpperCase()}',
        isFeasible: isFeasible,
        feasibilityMessage: feasibilityMessage,
      );
    } catch (e) {
      print('$_tag Error generating savings suggestion: $e');
      return SavingsSuggestionResult(
        success: false,
        suggestedMonthlySavings: 0,
        requiredMonthlySavings: 0,
        targetAmount: targetAmount,
        timelineMonths: 0,
        targetDate: targetDate,
        averageMonthlyIncome: 0,
        analysis: 'Error generating suggestion',
        isFeasible: false,
        feasibilityMessage: 'Error: $e',
      );
    }
  }

  /// =========== EXISTING ANALYSIS METHODS (Unchanged) ===========

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
          //monthlySavings: monthlyIncome - monthlyExpenses,
          monthlySavings: goalAmount / timelineMonths,
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

  /// Helper: Round up to 2 decimal places to ensure hitting target amount
  /// Example: 83.3333 becomes 83.34, so 83.34 * 12 = 1000.08 (hits target)
  static double _ceilToTwoDecimals(double value) {
    return (value * 100).ceil() / 100;
  }

  /// Helper: Calculate basic savings metrics
  // static Map<String, dynamic> calculateSavingsMetrics({
  //   required double monthlyIncome,
  //   required double monthlyExpenses,
  //   required double goalAmount,
  //   required int timelineMonths,
  // }) {
  //   final monthlySavings = monthlyIncome - monthlyExpenses;
  //   final timelineNeeded = monthlySavings > 0
  //       ? (goalAmount / monthlySavings).ceil()
  //       : double.infinity;
  //   final isFeasible = timelineNeeded <= timelineMonths && monthlySavings > 0;
  //
  //   return {
  //     'monthly_savings': monthlySavings,
  //     'timeline_needed': timelineNeeded,
  //     'is_feasible': isFeasible,
  //     'monthly_rate': (monthlySavings / goalAmount * 100).clamp(0, 100),
  //   };
  // }
  static Map<String, dynamic> calculateSavingsMetrics({
    required double monthlyIncome,
    required double monthlyExpenses,
    required double goalAmount,
    required int timelineMonths,
  }) {
    // 1. Calculate what is actually NEEDED to reach the goal
    // IMPORTANT: Round up to 2 decimals to ensure we HIT the target
    // Example: RM1000 / 12 months = RM83.33, but 83.33*12 = 999.96
    // Solution: Use RM83.34, so 83.34*12 = 1000.08 ✓
    final requiredMonthlySavings = _ceilToTwoDecimals(
      goalAmount / timelineMonths,
    );

    // 2. Calculate what the user is CAPABLE of saving
    final potentialMonthlySavings = monthlyIncome - monthlyExpenses;

    // 3. Check if it exceeds the limit (Total Income)
    final exceedsIncome = requiredMonthlySavings > monthlyIncome;

    // 4. Determine feasibility (Can they afford it within their budget?)
    final isFeasible = requiredMonthlySavings <= potentialMonthlySavings;

    return {
      'monthly_savings':
          requiredMonthlySavings, // Show what is needed, not what is left
      'potential_savings': potentialMonthlySavings,
      'is_feasible': isFeasible,
      'exceeds_income': exceedsIncome,
      'monthly_rate': (requiredMonthlySavings / monthlyIncome * 100).clamp(
        0,
        100,
      ),
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

  /// =========== HELPER METHODS FOR INCOME VALIDATION ===========

  /// Find consecutive months from a sorted list
  /// Returns the longest sequence of consecutive months
  static List<String> _findConsecutiveMonths(List<String> sortedMonths) {
    if (sortedMonths.isEmpty) return [];

    List<String> longestSequence = [];
    List<String> currentSequence = [sortedMonths[0]];

    for (int i = 1; i < sortedMonths.length; i++) {
      final previousMonth = sortedMonths[i - 1];
      final currentMonth = sortedMonths[i];

      // Parse YYYY-MM format
      final prevDate = DateTime.parse('$previousMonth-01');
      final currDate = DateTime.parse('$currentMonth-01');

      // Check if consecutive (within 1 month difference)
      final monthDiff =
          (currDate.year - prevDate.year) * 12 +
          (currDate.month - prevDate.month);

      if (monthDiff == 1) {
        currentSequence.add(currentMonth);
      } else {
        // Sequence broken, check if it's the longest
        if (currentSequence.length > longestSequence.length) {
          longestSequence = currentSequence;
        }
        currentSequence = [currentMonth];
      }
    }

    // Check final sequence
    if (currentSequence.length > longestSequence.length) {
      longestSequence = currentSequence;
    }

    return longestSequence;
  }

  /// Calculate months between two dates
  static int _calculateMonthsBetween(DateTime start, DateTime end) {
    return (end.year - start.year) * 12 + (end.month - start.month);
  }

  /// Get average monthly expenses for a user
  /// Returns 0 if no expense data available
  /// Calculate average monthly expenses for past 3 months
  /// Queries Transaction table for type='expense' records from last 90 days
  static Future<double> _getAverageMonthlyExpenses(String userId) async {
    try {
      final today = DateTime.now();
      final threeMonthsAgo = today.subtract(const Duration(days: 90));
      final dateString = DateFormat('yyyy-MM-dd').format(threeMonthsAgo);

      // Fetch expense transactions from last 3 months
      // Queries: Transaction table where type='expense' and date >= 90 days ago
      // Transaction table schema: transactionId, amount, type, date, categoryId, ledgerId, accountId, etc.
      final transactions = await Supabase.instance.client
          .from('Transaction')
          .select()
          .eq('type', 'expense')
          .gte('date', dateString);

      if (transactions.isEmpty) {
        return 0;
      }

      // Group by month and calculate monthly totals
      final monthlyExpenses = <String, double>{};
      for (final txn in transactions) {
        var date = txn['date'];
        final amount = (txn['amount'] ?? 0).toDouble().abs(); // Absolute value

        if (date != null && amount > 0) {
          // Parse date - handle both DateTime and String types
          String dateStr;
          try {
            if (date is DateTime) {
              dateStr = DateFormat('yyyy-MM-dd').format(date);
            } else if (date is String) {
              dateStr = date;
            } else {
              // Fallback: convert to string first
              dateStr = date.toString();
              // If in ISO format like "2026-01-15T00:00:00", just take the date part
              if (dateStr.contains('T')) {
                dateStr = dateStr.split('T')[0];
              }
            }

            // Extract YYYY-MM from the date string (first 7 chars)
            if (dateStr.length >= 7) {
              final month = dateStr.substring(0, 7);
              monthlyExpenses[month] = (monthlyExpenses[month] ?? 0) + amount;
            }
          } catch (e) {
            print(
              '$_tag [_getAverageMonthlyExpenses] Warning: Failed to parse date "$date": $e',
            );
          }
        }
      }

      // Return average of monthly expenses
      if (monthlyExpenses.isEmpty) {
        return 0;
      }

      return monthlyExpenses.values.reduce((a, b) => a + b) /
          monthlyExpenses.length;
    } catch (e) {
      print('$_tag Error getting average expenses: $e');
      return 0;
    }
  }

  /// =========== INTELLIGENT SAVINGS + FORECAST INTEGRATION ===========

  /// MAIN METHOD: Analyze savings goal feasibility using predicted expenses
  /// This is the CORE method that integrates forecasting with savings goals
  ///
  /// Logic:
  /// 1. Get user's monthly income (from salary category)
  /// 2. Get spending forecast for next month (using Prophet)
  /// 3. Calculate expense ratio: (predicted expenses / income) * 100
  /// 4. If ratio > 80%, predict that 20% savings goal is at risk
  /// 5. Provide adjusted recommendations to either:
  ///    - Reduce expenses by X%
  ///    - Lower savings target temporarily
  ///    - Extend timeline
  /// 6. Give category-specific reduction suggestions
  ///
  /// Returns: ForecastAwareSavingsAnalysis with risk assessment and actions
  static Future<ForecastAwareSavingsAnalysis>
  analyzeSavingsGoalWithExpenseForecast(
    String userId, {
    double savingsTargetPercent = 0.20, // Default 20% of income
    double riskThreshold = 0.80, // Alert if expenses > 80% of income
  }) async {
    try {
      print(
        '$_tag [analyzeSavingsGoalWithExpenseForecast] Starting forecast-aware savings analysis',
      );

      // Step 1: Get user's average monthly income
      print('$_tag Step 1: Retrieving user income...');
      final incomeResult = await validateConsistentIncome(userId);

      if (!incomeResult.success || !incomeResult.hasConsistentIncome) {
        print('$_tag ❌ No consistent income found');
        return ForecastAwareSavingsAnalysis(
          success: false,
          monthlyIncome: 0,
          predictedMonthlyExpense: 0,
          expenseRatio: 0,
          availableForSavings: 0,
          originalSavingsTarget: 0,
          adjustedSavingsTarget: 0,
          riskLevel: 'high',
          analysis:
              'Cannot analyze: No consistent income found. Please record your salary first.',
          isSavingsGoalFeasible: false,
          urgentActions: [
            'Record your monthly salary to enable savings analysis',
          ],
          categoryReductionSuggestions: [],
          recommendedExpenseReductionPercent: 0,
          scenario: 'realistic',
          alternativeScenarios: [],
        );
      }

      final monthlyIncome = incomeResult.averageMonthlyIncome;
      print('$_tag Monthly income: RM${monthlyIncome.toStringAsFixed(2)}');

      // Step 2: Get spending forecast for next month
      print('$_tag Step 2: Getting spending forecast...');
      final forecast = await getSpendingForecast(
        userId,
        periodsAhead: 1,
        period: 'month',
      );

      double predictedExpense = 0;
      if (forecast.success && forecast.forecast.isNotEmpty) {
        predictedExpense = forecast.forecast.first;
        print(
          '$_tag Predicted expense: RM${predictedExpense.toStringAsFixed(2)}',
        );
      } else {
        // Fallback: use average monthly expenses
        predictedExpense = await _getAverageMonthlyExpenses(userId);
        print(
          '$_tag Using average expense (forecast unavailable): RM${predictedExpense.toStringAsFixed(2)}',
        );
      }

      // Step 3: Calculate expense ratio and savings available
      final expenseRatio = (predictedExpense / monthlyIncome)
          .clamp(0, 1)
          .toDouble();
      final expensePercentage = (expenseRatio * 100).toDouble();
      final availableForSavings = (monthlyIncome - predictedExpense).toDouble();
      final originalSavingsTarget = (monthlyIncome * savingsTargetPercent)
          .toDouble();

      print(
        '$_tag Expense ratio: ${expensePercentage.toStringAsFixed(1)}% of income',
      );
      print(
        '$_tag Available for savings: RM${availableForSavings.toStringAsFixed(2)}',
      );

      // Step 4: Determine risk level and adjusted savings
      final riskLevelStr = _determineRiskLevel(
        expensePercentage,
        riskThreshold * 100,
      );
      final isGoalFeasible = expensePercentage <= (80); // 20% for savings
      final adjustedSavingsTarget =
          (availableForSavings > 0 ? availableForSavings : 0).toDouble();

      print('$_tag Risk level: $riskLevelStr');
      print('$_tag Goal feasible: $isGoalFeasible');

      // Step 5: Get category spending advice for targeted reductions
      print('$_tag Step 3: Analyzing spending by category...');
      final categoryAdvice = await getCategorySpendingAdvice(
        userId,
        lookbackMonths: 3,
      );

      // Step 6: Generate reduction suggestions
      final reductionSuggestions = <String>[];
      var recommendedReduction = 0;

      if (!isGoalFeasible) {
        // Calculate how much to reduce to hit 20% savings target
        final neededReduction = predictedExpense - (monthlyIncome * 0.80);
        recommendedReduction =
            ((neededReduction / predictedExpense * 100).clamp(0, 100)).toInt();

        print(
          '$_tag Need to reduce by: RM${neededReduction.toStringAsFixed(2)} (${recommendedReduction}%)',
        );

        // Add category-specific suggestions from highest spending categories
        for (final advice in categoryAdvice.take(3)) {
          if (advice.isConcerning) {
            final categoryReduction =
                ((advice.percentOfTotal * recommendedReduction / 100).clamp(
                  0,
                  100,
                )).toInt();
            reductionSuggestions.add(
              'Reduce ${advice.categoryName} by ${categoryReduction}% (currently ${advice.percentOfTotal.toStringAsFixed(1)}%)',
            );
          }
        }
      } else {
        // Expenses are under 80%, suggest optimizing top categories
        for (final advice in categoryAdvice.take(2)) {
          reductionSuggestions.add(
            'Optimize ${advice.categoryName} (${advice.percentOfTotal.toStringAsFixed(1)}%): ${advice.advice}',
          );
        }
      }

      // Step 7: Generate urgent actions
      final urgentActions = _generateUrgentSavingsActions(
        expensePercentage,
        riskLevelStr,
        availableForSavings,
        monthlyIncome,
      );

      // Step 8: Calculate alternative scenarios
      final alternativeScenarios = _generateAlternativeSavingsScenarios(
        monthlyIncome,
        predictedExpense,
        originalSavingsTarget,
      );

      // Step 9: Generate comprehensive analysis text
      final analysisText = _generateSavingsForecastAnalysis(
        monthlyIncome,
        predictedExpense,
        expensePercentage,
        isGoalFeasible,
        riskLevelStr,
        originalSavingsTarget,
        adjustedSavingsTarget,
      );

      print('$_tag ✅ Analysis complete');

      return ForecastAwareSavingsAnalysis(
        success: true,
        monthlyIncome: monthlyIncome,
        predictedMonthlyExpense: predictedExpense,
        expenseRatio: expenseRatio,
        availableForSavings: (availableForSavings > 0
            ? availableForSavings
            : 0),
        originalSavingsTarget: originalSavingsTarget,
        adjustedSavingsTarget: adjustedSavingsTarget,
        riskLevel: riskLevelStr,
        analysis: analysisText,
        isSavingsGoalFeasible: isGoalFeasible,
        urgentActions: urgentActions,
        categoryReductionSuggestions: reductionSuggestions,
        recommendedExpenseReductionPercent: recommendedReduction,
        scenario: isGoalFeasible ? 'optimistic' : 'realistic',
        alternativeScenarios: alternativeScenarios,
      );
    } catch (e) {
      print('$_tag ❌ Error in analyzeSavingsGoalWithExpenseForecast: $e');
      return ForecastAwareSavingsAnalysis(
        success: false,
        monthlyIncome: 0,
        predictedMonthlyExpense: 0,
        expenseRatio: 0,
        availableForSavings: 0,
        originalSavingsTarget: 0,
        adjustedSavingsTarget: 0,
        riskLevel: 'high',
        analysis: 'Error analyzing savings goal: $e',
        isSavingsGoalFeasible: false,
        urgentActions: [],
        categoryReductionSuggestions: [],
        recommendedExpenseReductionPercent: 0,
        scenario: 'realistic',
        alternativeScenarios: [],
      );
    }
  }

  /// =========== FORECAST API INTEGRATION ===========

  /// Get spending forecast for next N periods using Forecast API (Prophet)
  /// Collects transaction data from past 12 months and sends to forecast backend
  /// Returns predicted spending values for future months
  static Future<ForecastResult> getSpendingForecast(
    String userId, {
    int periodsAhead = 1,
    String period = 'month',
  }) async {
    try {
      print(
        '$_tag [getSpendingForecast] Fetching spending forecast for $periodsAhead $period(s) ahead',
      );

      // Step 1: Fetch past 12 months of expense data
      final today = DateTime.now();
      final oneYearAgo = today.subtract(const Duration(days: 365));
      final dateString = DateFormat('yyyy-MM-dd').format(oneYearAgo);

      print(
        '$_tag [getSpendingForecast] Step 1: Querying expenses from past year',
      );

      final transactions = await Supabase.instance.client
          .from('Transaction')
          .select('amount, date')
          .eq('type', 'expense')
          .gte('date', dateString);

      if (transactions.isEmpty) {
        print(
          '$_tag [getSpendingForecast] ⚠️ No expense data found for forecast',
        );
        return ForecastResult(
          success: false,
          forecast: [],
          period: period,
          periodsAhead: periodsAhead,
          confidence: 0,
        );
      }

      // Step 2: Group by month and calculate monthly spending totals
      print(
        '$_tag [getSpendingForecast] Step 2: Aggregating expenses by month',
      );

      final monthlySpending = <String, double>{};
      for (final txn in transactions) {
        var date = txn['date'];
        final amount = (txn['amount'] ?? 0).toDouble().abs();

        if (date != null && amount > 0) {
          String dateStr;
          try {
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
              monthlySpending[month] = (monthlySpending[month] ?? 0) + amount;
            }
          } catch (e) {
            print('$_tag [getSpendingForecast] Failed to parse date: $e');
          }
        }
      }

      if (monthlySpending.isEmpty) {
        print(
          '$_tag [getSpendingForecast] ⚠️ No valid monthly data after aggregation',
        );
        return ForecastResult(
          success: false,
          forecast: [],
          period: period,
          periodsAhead: periodsAhead,
          confidence: 0,
        );
      }

      // Step 3: Sort months and prepare data for API
      final sortedMonths = monthlySpending.keys.toList()..sort();
      final dataForForecast = sortedMonths.map((month) {
        return {'date': month, 'value': monthlySpending[month]};
      }).toList();

      print(
        '$_tag [getSpendingForecast] Step 3: Prepared ${dataForForecast.length} months of data for forecast',
      );
      print('$_tag [getSpendingForecast] Data: $dataForForecast');

      // Step 4: Call backend Forecast API
      print('$_tag [getSpendingForecast] Step 4: Calling Forecast API...');

      final response = await http
          .post(
            Uri.parse('$_backendUrl/api/forecast/spending'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'user_id': userId,
              'data': dataForForecast,
              'periods': periodsAhead,
              'period_type': period,
            }),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        print('$_tag [getSpendingForecast] ✅ Forecast received: $json');
        return ForecastResult.fromJson(json);
      } else {
        print(
          '$_tag [getSpendingForecast] ❌ API error: ${response.statusCode}',
        );
        return ForecastResult(
          success: false,
          forecast: [],
          period: period,
          periodsAhead: periodsAhead,
          confidence: 0,
        );
      }
    } catch (e) {
      print('$_tag Error in getSpendingForecast: $e');
      return ForecastResult(
        success: false,
        forecast: [],
        period: period,
        periodsAhead: periodsAhead,
        confidence: 0,
      );
    }
  }

  /// Generate AI-powered spending suggestion based on forecast
  /// Compares predicted spending with historical average
  /// Provides actionable advice
  static Future<SpendingSuggestion> generateSpendingSuggestion(
    String userId,
    List<double> pastSpending,
    List<double> forecastedSpending,
  ) async {
    try {
      print(
        '$_tag [generateSpendingSuggestion] Generating suggestion from forecast',
      );

      if (pastSpending.isEmpty || forecastedSpending.isEmpty) {
        return SpendingSuggestion(
          success: false,
          suggestion: 'Insufficient data to generate suggestions.',
          severity: 'low',
          trendChange: 0,
          actionItems: [],
          confidenceLevel: 'low',
        );
      }

      // Calculate average of past spending
      final avgPastSpending =
          pastSpending.reduce((a, b) => a + b) / pastSpending.length;

      // Get the next forecasted value
      final nextForecast = forecastedSpending.first;

      // Calculate percentage change
      final trendChange =
          (((nextForecast - avgPastSpending) / avgPastSpending * 100).clamp(
            -100,
            100,
          )).toDouble();

      print(
        '$_tag [generateSpendingSuggestion] Past avg: RM${avgPastSpending.toStringAsFixed(2)}, Forecast: RM${nextForecast.toStringAsFixed(2)}, Change: ${trendChange.toStringAsFixed(1)}%',
      );

      // Determine severity based on trend change
      final severity = _determineSeverity(trendChange);

      // Generate suggestion text (local AI logic)
      final suggestion = _generateSuggestionText(
        avgPastSpending,
        nextForecast,
        trendChange,
      );

      // Generate action items
      final actionItems = _generateActionItems(trendChange, severity);

      // Determine confidence (based on data points)
      final confidenceLevel = pastSpending.length >= 12
          ? 'high'
          : pastSpending.length >= 6
          ? 'medium'
          : 'low';

      return SpendingSuggestion(
        success: true,
        suggestion: suggestion,
        severity: severity,
        trendChange: trendChange,
        actionItems: actionItems,
        confidenceLevel: confidenceLevel,
      );
    } catch (e) {
      print('$_tag Error in generateSpendingSuggestion: $e');
      return SpendingSuggestion(
        success: false,
        suggestion: 'Error generating suggestion',
        severity: 'low',
        trendChange: 0,
        actionItems: [],
        confidenceLevel: 'low',
      );
    }
  }

  /// Get category-based spending advice
  /// Analyzes spending distribution across categories
  /// Provides targeted advice for high-spending categories
  static Future<List<CategorySpendingAdvice>> getCategorySpendingAdvice(
    String userId, {
    int lookbackMonths = 3,
  }) async {
    try {
      print(
        '$_tag [getCategorySpendingAdvice] Analyzing category spending distribution',
      );

      // Step 1: Fetch expense transactions from past N months
      final today = DateTime.now();
      final nMonthsAgo = DateTime(
        today.year,
        today.month - lookbackMonths,
        today.day,
      );
      final dateString = DateFormat('yyyy-MM-dd').format(nMonthsAgo);

      final transactions = await Supabase.instance.client
          .from('Transaction')
          .select('amount, categoryId, date')
          .eq('type', 'expense')
          .gte('date', dateString);

      if (transactions.isEmpty) {
        print('$_tag No transaction data for category analysis');
        return [];
      }

      // Step 2: Group by categoryId and sum amounts
      final categorySpending = <String, double>{};
      final categoryTransactionCount = <String, int>{};

      for (final txn in transactions) {
        final catId = txn['categoryId'];
        final amount = (txn['amount'] ?? 0).toDouble().abs();

        if (catId != null && amount > 0) {
          categorySpending[catId] = (categorySpending[catId] ?? 0) + amount;
          categoryTransactionCount[catId] =
              (categoryTransactionCount[catId] ?? 0) + 1;
        }
      }

      // Step 3: Calculate total and percentages
      final totalSpending = categorySpending.values.reduce((a, b) => a + b);

      print(
        '$_tag Total spending across ${categorySpending.length} categories: RM${totalSpending.toStringAsFixed(2)}',
      );

      // Step 4: Fetch category names and generate advice
      final advice = <CategorySpendingAdvice>[];

      for (final entry in categorySpending.entries) {
        final categoryId = entry.key;
        final spending = entry.value;
        final percentOfTotal = (spending / totalSpending * 100);

        // Fetch category details
        try {
          final categories = await Supabase.instance.client
              .from('Category')
              .select('name')
              .eq('categoryId', categoryId);

          if (categories.isNotEmpty) {
            final categoryName = categories[0]['name'] as String;

            // Generate advice based on spending percentage
            final categoryAdvice = _generateCategoryAdvice(
              categoryName,
              percentOfTotal,
            );

            advice.add(categoryAdvice);
          }
        } catch (e) {
          print('$_tag Error fetching category $categoryId: $e');
        }
      }

      // Sort by percentage spending (highest first)
      advice.sort((a, b) => b.percentOfTotal.compareTo(a.percentOfTotal));

      print('$_tag Generated advice for ${advice.length} categories');

      return advice;
    } catch (e) {
      print('$_tag Error in getCategorySpendingAdvice: $e');
      return [];
    }
  }

  /// =========== HELPER METHODS FOR SUGGESTIONS ===========

  /// Determine risk level based on expense percentage
  static String _determineRiskLevel(
    double expensePercentage,
    double riskThresholdPercent,
  ) {
    if (expensePercentage > riskThresholdPercent * 1.1) {
      // >88% (very high)
      return 'critical'; // Cannot save 20%
    } else if (expensePercentage > riskThresholdPercent) {
      // 80-88% (high)
      return 'high'; // Minimal savings possible
    } else if (expensePercentage > 70) {
      // 70-80% (medium)
      return 'medium'; // Can save ~15-20%
    } else {
      // <70% (low)
      return 'low'; // Can save >20%
    }
  }

  /// Generate urgent action items based on expense forecast
  static List<String> _generateUrgentSavingsActions(
    double expensePercentage,
    String riskLevel,
    double availableForSavings,
    double monthlyIncome,
  ) {
    final actions = <String>[];

    if (riskLevel == 'critical') {
      actions.add('🚨 URGENT: Expenses are consuming 88%+ of your income!');
      actions.add(
        'Immediately cut discretionary spending (dining, entertainment)',
      );
      actions.add('Review all subscriptions and cancel unused ones');
      actions.add('Consider additional income sources');
      actions.add(
        'Your 20% savings goal is not feasible - reduce to 5% temporarily',
      );
    } else if (riskLevel == 'high') {
      actions.add('⚠️ HIGH RISK: Predicted expenses will be 80%+ of income');
      actions.add(
        'Focus on reducing controllable expenses (food, transport, shopping)',
      );
      actions.add('Postpone non-essential purchases');
      actions.add('Target: Reduce spending by 5-10% to free up savings');
      actions.add(
        'Alternative: Lower savings goal from 20% to 10-15% temporarily',
      );
    } else if (riskLevel == 'medium') {
      actions.add('📊 MEDIUM: You have tight budget margin (20-30% of income)');
      actions.add('Focus on optimizing one major category');
      actions.add('Build emergency fund before pursuing large savings goals');
      actions.add('Track expenses closely for 2-3 months');
      actions.add('Look for 15-20% savings rate instead of immediate 20%');
    } else {
      actions.add('✅ GOOD: You have healthy savings capacity (>30% of income)');
      actions.add('You can comfortably save 20% of income');
      actions.add('Consider saving even more if possible');
      actions.add('Start or increase your savings goal immediately');
      actions.add('Review quarterly to maintain this strong position');
    }

    return actions;
  }

  /// Generate alternative savings scenarios
  static List<Map<String, dynamic>> _generateAlternativeSavingsScenarios(
    double monthlyIncome,
    double predictedExpense,
    double targetSavings20Percent,
  ) {
    final scenarios = <Map<String, dynamic>>[];

    // Scenario 1: 5% savings (emergency mode)
    final savings5 = monthlyIncome * 0.05;
    final expense5 = monthlyIncome - savings5;
    scenarios.add({
      'name': 'Emergency Mode (5% savings)',
      'monthly_savings': savings5,
      'monthly_expense': expense5,
      'savings_per_year': savings5 * 12,
      'reach_target_months': targetSavings20Percent > 0
          ? (targetSavings20Percent / savings5).ceil()
          : 0,
      'feasibility': expense5 >= predictedExpense ? 'FEASIBLE' : 'TIGHT',
      'description': 'Minimum savings mode. Use if expenses are high.',
    });

    // Scenario 2: 10% savings (conservative)
    final savings10 = monthlyIncome * 0.10;
    final expense10 = monthlyIncome - savings10;
    scenarios.add({
      'name': 'Conservative (10% savings)',
      'monthly_savings': savings10,
      'monthly_expense': expense10,
      'savings_per_year': savings10 * 12,
      'reach_target_months': targetSavings20Percent > 0
          ? (targetSavings20Percent / savings10).ceil()
          : 0,
      'feasibility': expense10 >= predictedExpense ? 'FEASIBLE' : 'TIGHT',
      'description': 'Balanced approach. Good if budget is moderate.',
    });

    // Scenario 3: 20% savings (target)
    final savings20 = monthlyIncome * 0.20;
    final expense20 = monthlyIncome - savings20;
    scenarios.add({
      'name': 'Target (20% savings)',
      'monthly_savings': savings20,
      'monthly_expense': expense20,
      'savings_per_year': savings20 * 12,
      'reach_target_months': targetSavings20Percent > 0
          ? (targetSavings20Percent / savings20).ceil()
          : 0,
      'feasibility': expense20 >= predictedExpense
          ? 'FEASIBLE'
          : 'NOT FEASIBLE',
      'description': 'Recommended savings rate. AIM FOR THIS.',
    });

    // Scenario 4: 25% savings (aggressive)
    final savings25 = monthlyIncome * 0.25;
    final expense25 = monthlyIncome - savings25;
    scenarios.add({
      'name': 'Aggressive (25% savings)',
      'monthly_savings': savings25,
      'monthly_expense': expense25,
      'savings_per_year': savings25 * 12,
      'reach_target_months': targetSavings20Percent > 0
          ? (targetSavings20Percent / savings25).ceil()
          : 0,
      'feasibility': expense25 >= predictedExpense
          ? 'FEASIBLE'
          : 'NOT FEASIBLE',
      'description': 'High savings rate. Requires disciplined expense control.',
    });

    return scenarios;
  }

  /// Generate comprehensive analysis text for forecast-aware savings
  static String _generateSavingsForecastAnalysis(
    double monthlyIncome,
    double predictedExpense,
    double expensePercentage,
    bool isGoalFeasible,
    String riskLevel,
    double originalTarget,
    double adjustedTarget,
  ) {
    final buffer = StringBuffer();

    buffer.writeln('=== FORECAST-AWARE SAVINGS ANALYSIS ===\n');

    buffer.writeln('📊 YOUR FINANCIAL SNAPSHOT:');
    buffer.writeln('Monthly Income: RM${monthlyIncome.toStringAsFixed(2)}');
    buffer.writeln(
      'Predicted Expenses: RM${predictedExpense.toStringAsFixed(2)}',
    );
    buffer.writeln('Expense Ratio: ${expensePercentage.toStringAsFixed(1)}%');
    buffer.writeln(
      'Available for Savings: RM${(monthlyIncome - predictedExpense).toStringAsFixed(2)}\n',
    );

    if (isGoalFeasible) {
      buffer.writeln('✅ GOOD NEWS:');
      buffer.writeln(
        'Your predicted expenses (${expensePercentage.toStringAsFixed(1)}%) are UNDER 80% of income.',
      );
      buffer.writeln(
        'Your 20% savings goal is FEASIBLE with current spending pattern.',
      );
      buffer.writeln(
        'Recommended savings: RM${originalTarget.toStringAsFixed(2)}/month',
      );
      buffer.writeln('You can reach your goal on schedule!\n');
    } else {
      buffer.writeln('⚠️  ATTENTION REQUIRED:');
      buffer.writeln(
        'Your predicted expenses (${expensePercentage.toStringAsFixed(1)}%) exceed 80% of income.',
      );
      buffer.writeln('Your 20% savings goal is NOT FEASIBLE without changes.');
      buffer.writeln(
        'Original 20% target: RM${originalTarget.toStringAsFixed(2)}/month',
      );
      buffer.writeln(
        'Adjusted recommendation: RM${adjustedTarget.toStringAsFixed(2)}/month\n',
      );
    }

    buffer.writeln('⚡ RISK ASSESSMENT:');
    switch (riskLevel) {
      case 'critical':
        buffer.writeln('RISK LEVEL: 🔴 CRITICAL');
        buffer.writeln(
          'Your budget is extremely tight. You\'re spending 88%+ of income.',
        );
        buffer.writeln(
          'ACTION: Reduce expenses immediately or increase income.',
        );
        break;
      case 'high':
        buffer.writeln('RISK LEVEL: 🟠 HIGH');
        buffer.writeln(
          'Your budget is tight. You\'re spending 80-88% of income.',
        );
        buffer.writeln(
          'ACTION: Reduce expenses by 5-10% to create savings cushion.',
        );
        break;
      case 'medium':
        buffer.writeln('RISK LEVEL: 🟡 MEDIUM');
        buffer.writeln(
          'You have moderate budget flexibility. You can save 10-20%.',
        );
        buffer.writeln('ACTION: Optimize spending and track expenses closely.');
        break;
      case 'low':
        buffer.writeln('RISK LEVEL: 🟢 LOW');
        buffer.writeln('You have healthy budget cushion. You can save >20%.');
        buffer.writeln(
          'ACTION: Lock in your 20% savings goal and start today!',
        );
        break;
    }

    buffer.writeln('\n💡 RECOMMENDATION:');
    if (isGoalFeasible) {
      buffer.writeln('1. Maintain or reduce your current spending');
      buffer.writeln(
        '2. Save RM${originalTarget.toStringAsFixed(2)} monthly (20% of income)',
      );
      buffer.writeln('3. Reach your savings goal on the planned timeline');
      buffer.writeln('4. Review monthly to ensure expenses stay under 80%');
    } else {
      buffer.writeln('1. FIRST: Reduce expenses to below 80% of income');
      buffer.writeln(
        '2. TARGET: Identify categories to cut by ${((predictedExpense - (monthlyIncome * 0.80)) / predictedExpense * 100).toInt()}%',
      );
      buffer.writeln(
        '3. THEN: Start with RM${adjustedTarget.toStringAsFixed(2)}/month savings',
      );
      buffer.writeln('4. GROWTH: Increase savings as you optimize expenses');
      buffer.writeln(
        '5. GOAL: Work your way up to 20% savings within 3-6 months',
      );
    }

    return buffer.toString();
  }

  /// Determine severity level based on trend change
  static String _determineSeverity(double trendChange) {
    if (trendChange > 20) {
      return 'high'; // Significant increase
    } else if (trendChange > 10) {
      return 'medium'; // Moderate increase
    } else {
      return 'low'; // Stable or decreasing
    }
  }

  /// Generate human-readable suggestion text
  static String _generateSuggestionText(
    double avgPast,
    double forecast,
    double trendChange,
  ) {
    if (trendChange > 20) {
      return 'Your spending is projected to increase significantly by ${trendChange.toStringAsFixed(1)}%. '
          'Try reducing discretionary expenses by 10–15% to maintain your savings goal.';
    } else if (trendChange > 10) {
      return 'Your spending is trending up (${trendChange.toStringAsFixed(1)}%). '
          'Keep track of your expenses and look for areas to cut back.';
    } else if (trendChange < -15) {
      return 'Excellent! Your spending is decreasing (${trendChange.toStringAsFixed(1)}%). '
          'Keep up this positive trend and consider increasing your savings rate.';
    } else {
      return 'Good job! Your spending is stable. Continue monitoring your expenses to meet your savings goals.';
    }
  }

  /// Generate action items based on trend and severity
  static List<String> _generateActionItems(
    double trendChange,
    String severity,
  ) {
    final items = <String>[];

    if (severity == 'high') {
      items.add('Review all subscriptions and recurring expenses');
      items.add('Set daily spending limits on discretionary items');
      items.add('Create a detailed budget for next month');
      items.add('Consider cutting non-essential services');
    } else if (severity == 'medium') {
      items.add('Monitor spending over the next 2 weeks');
      items.add('Review major expense categories');
      items.add('Look for one category to reduce by 10%');
    } else {
      items.add('Continue same spending habits');
      items.add('Review monthly to maintain stability');
      if (trendChange < -15) {
        items.add('Consider increasing savings rate');
      }
    }

    return items;
  }

  /// Generate category-specific advice
  static CategorySpendingAdvice _generateCategoryAdvice(
    String categoryName,
    double percentOfTotal,
  ) {
    final isConcerning = percentOfTotal > 30; // >30% is concerning

    String advice = '';
    final tips = <String>[];

    // Category-specific logic
    if (categoryName.toLowerCase().contains('food') ||
        categoryName.toLowerCase().contains('dining')) {
      if (percentOfTotal > 30) {
        advice =
            'Food & dining is your largest expense category. Consider meal planning and cooking more at home.';
        tips.addAll([
          'Meal plan for the week before shopping',
          'Cook at home instead of ordering out',
          'Pack lunch instead of buying',
          'Set a weekly food budget',
        ]);
      } else if (percentOfTotal > 20) {
        advice =
            'You\'re spending a reasonable amount on food. Look for small optimizations.';
        tips.addAll([
          'Compare grocery prices',
          'Reduce eating out frequency',
          'Use loyalty programs',
        ]);
      } else {
        advice = 'Good food spending control!';
        tips.addAll([
          'Maintain your current habits',
          'Keep enjoying your meals responsibly',
        ]);
      }
    } else if (categoryName.toLowerCase().contains('transportation')) {
      if (percentOfTotal > 25) {
        advice =
            'Transportation is taking a large portion of your budget. Consider carpooling or public transit.';
        tips.addAll([
          'Use public transportation when possible',
          'Carpool with friends or coworkers',
          'Maintain vehicle to reduce repair costs',
          'Combine trips to save fuel',
        ]);
      } else {
        advice = 'Your transportation spending looks reasonable.';
        tips.addAll([
          'Continue efficient travel habits',
          'Regular vehicle maintenance',
        ]);
      }
    } else if (categoryName.toLowerCase().contains('entertainment')) {
      if (percentOfTotal > 20) {
        advice =
            'Entertainment spending is quite high. Look for free or low-cost entertainment options.';
        tips.addAll([
          'Explore free events in your area',
          'Share subscription services',
          'Have movie nights at home',
          'Use library resources',
        ]);
      } else {
        advice = 'You have a balanced approach to entertainment.';
        tips.addAll([
          'Keep enjoying yourself within budget',
          'Look for deals and discounts',
        ]);
      }
    } else if (categoryName.toLowerCase().contains('utilities')) {
      if (percentOfTotal > 15) {
        advice =
            'Utilities are higher than average. Check for energy-saving opportunities.';
        tips.addAll([
          'Switch to LED lightbulbs',
          'Use programmable thermostat',
          'Unplug devices when not in use',
          'Compare utility providers',
        ]);
      } else {
        advice = 'Your utilities spending is well-controlled.';
        tips.addAll([
          'Maintain energy-efficient habits',
          'Monitor monthly usage',
        ]);
      }
    } else {
      // Generic advice for other categories
      if (percentOfTotal > 25) {
        advice =
            '$categoryName is consuming a significant portion of your budget.';
        tips.addAll([
          'Review all expenses in this category',
          'Look for areas to reduce',
          'Set a monthly limit',
        ]);
      } else {
        advice = 'Your $categoryName spending is under control.';
        tips.addAll([
          'Continue monitoring',
          'Look for optimization opportunities',
        ]);
      }
    }

    return CategorySpendingAdvice(
      success: true,
      categoryName: categoryName,
      percentOfTotal: percentOfTotal,
      advice: advice,
      savingtips: tips,
      isConcerning: isConcerning,
    );
  }
}
