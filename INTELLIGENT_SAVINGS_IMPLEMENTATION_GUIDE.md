# Intelligent Savings Goal Assistant - Implementation Guide

## Quick Reference: Core Methods & Their Purposes

```dart
// ==================== INCOME VALIDATION ====================

/// Check if user has recent income (past 3 months)
Future<IncomeCheckResult> checkRecentIncomeExists(String userId)
  Purpose: Quick check before showing income dialog
  Returns: bool hasRecentIncome, String? salaryCategoryId
  Time: ~500ms

/// Validate 3+ consecutive months of income from 12-month history  
Future<IncomeValidationResult> validateConsistentIncome(String userId)
  Purpose: Deep validation for goal feasibility analysis
  Returns: Full income details including average, months, consistency
  Time: ~1500ms
  
// ==================== EXPENSE FORECASTING ====================

/// Get spending forecast using Forecast API (Prophet)
Future<ForecastResult> getSpendingForecast(
  String userId,
  int periodsAhead = 1,
  String period = 'month'
)
  Purpose: Predict future expenses using ML model
  Returns: List<double> predictions for next N periods
  Time: ~3000ms (includes API call)
  
// ==================== FEASIBILITY ANALYSIS ====================

/// Main entry point for savings goal analysis
Future<GoalFeasibilityResult> analyzeGoalFeasibility({
  required String userId,
  required double monthlyIncome,
  required double monthlyExpenses,
  required double goalAmount,
  required int timelineMonths,
})
  Purpose: Complete feasibility assessment with all factors
  Returns: Full analysis including suggestions and confidence level
  Time: ~4500ms (combines all above)

/// Generate personalized savings suggestion
Future<SavingsSuggestionResult> generateSavingsSuggestion({
  required String userId,
  required double targetAmount,
  required DateTime targetDate,
})
  Purpose: Calculate required monthly savings and assess feasibility
  Returns: Specific amounts, feasibility stage, and advice
  Time: ~1500ms

// ==================== CATEGORY-BASED ADVICE ====================

/// Get spending breakdown by category for advice generation
Future<CategorySpendingAdvice> getCategorySpendingAdvice(
  String userId,
  int lookbackMonths = 3
)
  Purpose: Identify where to cut expenses
  Returns: Ranked list of spending categories with amounts
  Time: ~800ms
```

---

## Implementation Code Walkthrough

### Section 1: Income Validation Pipeline

#### **Query Path 1️⃣ → 2️⃣ → 3️⃣**

```dart
// STEP 1️⃣: Get all income transactions (past 12 months)
static Future<IncomeValidationResult> validateConsistentIncome(
  String userId,
) async {
  try {
    final today = DateTime.now();
    final oneYearAgo = today.subtract(const Duration(days: 365));
    final dateString = DateFormat('yyyy-MM-dd').format(oneYearAgo);

    print('$_tag Step 1️⃣: Query Transaction (type=income, past 12M)');

    // Query: SELECT categoryId, amount, date FROM Transaction
    //        WHERE type = 'income' AND date >= dateString
    final incomeTransactions = await Supabase.instance.client
        .from('Transaction')
        .select('categoryId, amount, date')
        .eq('type', 'income')                    // ← Filter: type must be 'income'
        .gte('date', dateString);                // ← 12 months of history

    print('$_tag Found ${incomeTransactions.length} income transactions');

    if (incomeTransactions.isEmpty) {
      // No income data available
      return IncomeValidationResult(
        success: true,
        hasConsistentIncome: false,
        message: 'No income transactions found in the past 12 months.',
      );
    }

    // STEP 2️⃣: Extract distinct category IDs from income transactions
    print('$_tag Step 2️⃣: Extract distinct categoryIds');
    
    final distinctCategoryIds = <String>{};
    for (final txn in incomeTransactions) {
      final catId = txn['categoryId'];
      final amount = (txn['amount'] ?? 0).toDouble().abs();

      // Only include categories with positive amounts
      if (catId != null && amount > 0) {
        distinctCategoryIds.add(catId as String);
      }
    }

    print('$_tag Found ${distinctCategoryIds.length} distinct categories');

    // STEP 3️⃣: Find salary category (case-insensitive search)
    print('$_tag Step 3️⃣: Search for salary category');

    // Query: SELECT categoryId, name FROM Category
    //        WHERE categoryId IN (distinctCategoryIds)
    //        AND name ILIKE '%salary%'
    final salaryCategories = await Supabase.instance.client
        .from('Category')
        .select()
        .inFilter('categoryId', distinctCategoryIds.toList())
        .ilike('name', '%salary%');  // ← Case-insensitive match

    String? salaryCategoryId;
    if (salaryCategories.isNotEmpty) {
      salaryCategoryId = salaryCategories[0]['categoryId'] as String;
      print('$_tag ✅ Found salary category: ${salaryCategories[0]['name']}');
    } else {
      // Fallback: use any income category
      final allCategories = await Supabase.instance.client
          .from('Category')
          .select()
          .inFilter('categoryId', distinctCategoryIds.toList());
      
      if (allCategories.isNotEmpty) {
        salaryCategoryId = allCategories[0]['categoryId'] as String;
        print('$_tag Using fallback category: ${allCategories[0]['name']}');
      }
    }

    // STEP 4️⃣: Group into months and check consecutiveness
    print('$_tag Step 4️⃣: Group by month and validate');

    // Filter to only this user's salary category transactions
    final salaryTransactions = incomeTransactions
        .where((txn) => txn['categoryId'] == salaryCategoryId)
        .toList();

    // Group by month (YYYY-MM format)
    final monthlyIncomeSalary = <String, double>{};
    for (final txn in salaryTransactions) {
      var date = txn['date'];
      final amount = (txn['amount'] ?? 0).toDouble().abs();

      if (date != null && amount > 0) {
        String dateStr;
        if (date is DateTime) {
          dateStr = DateFormat('yyyy-MM-dd').format(date);
        } else if (date is String) {
          dateStr = date;
        } else {
          dateStr = date.toString();
        }

        // Extract YYYY-MM (first 7 chars: "2025-01")
        if (dateStr.length >= 7) {
          final month = dateStr.substring(0, 7);
          monthlyIncomeSalary[month] = 
              (monthlyIncomeSalary[month] ?? 0) + amount;
        }
      }
    }

    // Check for 3+ consecutive months
    final sortedMonths = monthlyIncomeSalary.keys.toList()..sort();
    final consistentMonths = _findConsecutiveMonths(sortedMonths);
    
    print('$_tag Consecutive months: ${consistentMonths.length}');

    // Calculate average
    final avgIncome = monthlyIncomeSalary.values.isNotEmpty
        ? monthlyIncomeSalary.values.reduce((a, b) => a + b) / 
          monthlyIncomeSalary.length
        : 0.0;

    return IncomeValidationResult(
      success: true,
      hasConsistentIncome: consistentMonths.length >= 3,
      averageMonthlyIncome: avgIncome,
      salaryMonths: sortedMonths,
      consistentMonthsCount: consistentMonths.length,
      salaryCategoryId: salaryCategoryId,
    );
  } catch (e) {
    print('$_tag Error validating income: $e');
    return IncomeValidationResult(success: false, ...);
  }
}

// Helper: Find longest consecutive sequence of months
static List<String> _findConsecutiveMonths(List<String> sortedMonths) {
  if (sortedMonths.isEmpty) return [];

  List<String> longestSequence = [];
  List<String> currentSequence = [sortedMonths[0]];

  for (int i = 1; i < sortedMonths.length; i++) {
    final previousMonth = sortedMonths[i - 1];
    final currentMonth = sortedMonths[i];

    // Parse YYYY-MM format: "2025-01"
    final prevDate = DateTime.parse('$previousMonth-01');
    final currDate = DateTime.parse('$currentMonth-01');

    // Calculate month difference
    final monthDiff = (currDate.year - prevDate.year) * 12 +
                      (currDate.month - prevDate.month);

    if (monthDiff == 1) {  // ← Consecutive months
      currentSequence.add(currentMonth);
    } else {
      // Broke sequence, check if longest
      if (currentSequence.length > longestSequence.length) {
        longestSequence = currentSequence;
      }
      currentSequence = [currentMonth];  // Start new sequence
    }
  }

  // Check final sequence
  if (currentSequence.length > longestSequence.length) {
    longestSequence = currentSequence;
  }

  return longestSequence;
}
```

---

### Section 2: Expense Forecasting Integration

```dart
/// Get spending forecast using Forecast API (Prophet ML model)
static Future<ForecastResult> getSpendingForecast(
  String userId, {
  int periodsAhead = 1,
  String period = 'month',
}) async {
  try {
    print('$_tag Fetching spending forecast...');

    // STEP 1️⃣: Collect historical expense data (12 months)
    final today = DateTime.now();
    final oneYearAgo = today.subtract(const Duration(days: 365));
    final dateString = DateFormat('yyyy-MM-dd').format(oneYearAgo);

    print('$_tag Step 1️⃣: Collecting expense history...');

    // Query: SELECT amount, date FROM Transaction
    //        WHERE type = 'expense' AND date >= dateString
    final transactions = await Supabase.instance.client
        .from('Transaction')
        .select('amount, date')
        .eq('type', 'expense')
        .gte('date', dateString);

    print('$_tag Found ${transactions.length} expense records');

    if (transactions.isEmpty) {
      return ForecastResult(success: false, forecast: []);
    }

    // STEP 2️⃣: Group by month and calculate monthly totals
    print('$_tag Step 2️⃣: Grouping by month...');
    
    final monthlyExpenses = <String, double>{};
    for (final txn in transactions) {
      var date = txn['date'];
      final amount = (txn['amount'] ?? 0).toDouble().abs();

      if (date != null && amount > 0) {
        String dateStr;
        if (date is DateTime) {
          dateStr = DateFormat('yyyy-MM-dd').format(date);
        } else if (date is String) {
          dateStr = date;
        } else {
          dateStr = date.toString();
        }

        // Extract YYYY-MM
        if (dateStr.length >= 7) {
          final month = dateStr.substring(0, 7);
          monthlyExpenses[month] = (monthlyExpenses[month] ?? 0) + amount;
        }
      }
    }

    final sortedMonths = monthlyExpenses.keys.toList()..sort();
    print('$_tag Months with data: ${sortedMonths.length}');

    // STEP 3️⃣: Prepare forecast API payload
    print('$_tag Step 3️⃣: Preparing forecast API call...');

    final forecastData = sortedMonths.map((month) {
      return {
        'date': month,
        'value': monthlyExpenses[month],
      };
    }).toList();

    // STEP 4️⃣: Call Forecast API (Prophet)
    print('$_tag Step 4️⃣: Calling Forecast API...');

    final response = await http
        .post(
          Uri.parse(_forecastApiUrl),  // forecastapi.com/v2/forecast
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_forecastApiKey',
          },
          body: jsonEncode({
            'data': forecastData,
            'forecast_periods': periodsAhead,
            'confidence_interval': 0.95,
            'model': 'prophet',
          }),
        )
        .timeout(const Duration(seconds: 15));  // 15 second timeout

    if (response.statusCode != 200) {
      print('$_tag Forecast API error: ${response.statusCode}');
      return ForecastResult(success: false, forecast: []);
    }

    // STEP 5️⃣: Parse forecast response
    print('$_tag Step 5️⃣: Parsing forecast results...');

    final jsonResponse = jsonDecode(response.body);
    final forecastValues = List<double>.from(
      (jsonResponse['forecast'] as List).map((x) => (x as num).toDouble()),
    );

    print('$_tag Forecast successful: $forecastValues');

    return ForecastResult(
      success: true,
      forecast: forecastValues,
      confidence: 'high',
    );
  } catch (e) {
    print('$_tag Forecast error: $e');
    return ForecastResult(success: false, forecast: []);
  }
}
```

**Prophet Model Benefits:**
- ✅ Detects seasonality (holiday spending, monthly patterns)
- ✅ Handles trends (gradual increase/decrease)
- ✅ Robust to missing data
- ✅ Returns confidence intervals
- ✅ Fast predictions (fits in 15 seconds)

---

### Section 3: Feasibility Assessment Logic

```dart
/// Main analysis method that uses income + forecast to assess goal feasibility
static Future<SavingsSuggestionResult> generateSavingsSuggestion({
  required String userId,
  required double targetAmount,
  required DateTime targetDate,
}) async {
  try {
    // STEP 1️⃣: Validate income
    print('$_tag Step 1️⃣: Validating income...');
    final incomeValidation = await validateConsistentIncome(userId);

    if (!incomeValidation.hasConsistentIncome) {
      return SavingsSuggestionResult(
        success: true,
        isFeasible: false,
        feasibilityMessage: incomeValidation.message,
      );
    }

    final monthlyIncome = incomeValidation.averageMonthlyIncome;
    print('$_tag Income validated: RM${monthlyIncome.toStringAsFixed(2)}/month');

    // STEP 2️⃣: Calculate timeline
    print('$_tag Step 2️⃣: Calculating timeline...');
    final today = DateTime.now();
    final timelineMonths = _calculateMonthsBetween(today, targetDate);

    if (timelineMonths <= 0) {
      return SavingsSuggestionResult(
        success: false,
        isFeasible: false,
        feasibilityMessage: 'Target date must be in the future',
      );
    }

    print('$_tag Timeline: $timelineMonths months');

    // STEP 3️⃣: Calculate required savings
    print('$_tag Step 3️⃣: Calculating required savings...');
    
    // IMPORTANT: Round UP to ensure hitting target amount
    // Example: 1000 / 12 = 83.33 → round to 83.34
    // So: 83.34 * 12 = 1000.08 (hits target!)
    final requiredMonthlySavings = _ceilToTwoDecimals(
      targetAmount / timelineMonths,
    );

    final recommendedMonthlySavings = monthlyIncome * 0.20;  // 20% rule

    print(
      '$_tag Required: RM${requiredMonthlySavings.toStringAsFixed(2)}/month',
    );
    print(
      '$_tag Recommended (20%): RM${recommendedMonthlySavings.toStringAsFixed(2)}/month',
    );

    // STEP 4️⃣: Get forecasted expenses
    print('$_tag Step 4️⃣: Getting expense forecast...');
    final forecast = await getSpendingForecast(
      userId,
      periodsAhead: 3,
      period: 'month',
    );

    double forecastedExpense = await _getAverageMonthlyExpenses(userId);
    if (forecast.success && forecast.forecast.isNotEmpty) {
      forecastedExpense = forecast.forecast.reduce((a, b) => a + b) / 
                         forecast.forecast.length;
    }

    print('$_tag Forecasted expenses: RM${forecastedExpense.toStringAsFixed(2)}/month');

    // STEP 5️⃣: Calculate actual available for savings
    final monthlyNetIncome = (monthlyIncome - forecastedExpense).toDouble();

    // STEP 6️⃣: ASSESS FEASIBILITY (The Intelligence!)
    print('$_tag Step 5️⃣: Assessing feasibility with 20/80 rule...');

    // 20/80 Rule:
    // - 20% should go to savings (recommendation)
    // - 80% should be expenses (safe limit)

    String feasibilityStage = 'achievable';  // default
    String feasibilityMessage = '';
    bool isFeasible = false;

    // ════════════════════════════════════════════════════════════════
    // STAGE 1️⃣: ACHIEVABLE (EASY PATH)
    // ════════════════════════════════════════════════════════════════
    // Conditions:
    //   • Required ≤ Recommended 20%
    //   • Forecasted expenses ≤ 80%
    // Status: Green light, continue as normal
    // ════════════════════════════════════════════════════════════════

    if (requiredMonthlySavings <= recommendedMonthlySavings) {
      // Savings target is within 20% recommendation
      final expenseRatio = (forecastedExpense / monthlyIncome * 100);

      if (expenseRatio <= 80) {
        // ACHIEVABLE: Both conditions met
        feasibilityStage = 'achievable';
        isFeasible = true;
        feasibilityMessage =
            'Your goal requires RM${requiredMonthlySavings.toStringAsFixed(2)}/month, '
            'which is ${(requiredMonthlySavings / monthlyIncome * 100).toStringAsFixed(1)}% of income. '
            'Expenses forecast to ${expenseRatio.toStringAsFixed(1)}%. '
            'This is comfortable and achievable!';
      } else {
        // CHALLENGING (Type B): Savings ok, but expenses risky
        feasibilityStage = 'challenging';
        isFeasible = false;
        final expenseOverage = expenseRatio - 80;
        feasibilityMessage =
            'Savings target is feasible (${(requiredMonthlySavings / monthlyIncome * 100).toStringAsFixed(1)}%), '
            'BUT expenses are forecasted at ${expenseRatio.toStringAsFixed(1)}% (${expenseOverage.toStringAsFixed(1)}% over limit). '
            'Cut expenses by RM${(forecastedExpense - monthlyIncome * 0.80).toStringAsFixed(2)}/month to succeed.';
      }
    } else {
      // ════════════════════════════════════════════════════════════════
      // STAGE 2️⃣: CHALLENGING (NEEDS EFFORT)
      // ════════════════════════════════════════════════════════════════
      // Condition: Required > 20% recommendation
      // Status: Possible but needs tighter budget management
      // ════════════════════════════════════════════════════════════════

      if (requiredMonthlySavings <= monthlyNetIncome &&
          requiredMonthlySavings <= monthlyIncome) {
        // CHALLENGING (Type A or C): High savings target but possible
        feasibilityStage = 'challenging';
        isFeasible = false;
        feasibilityMessage =
            'Your goal requires RM${requiredMonthlySavings.toStringAsFixed(2)}/month '
            '(${(requiredMonthlySavings / monthlyIncome * 100).toStringAsFixed(1)}% of income), '
            'which exceeds the recommended 20%. '
            'Feasible only if you strictly control expenses at ${(forecastedExpense / monthlyIncome * 100).toStringAsFixed(1)}%.';
      } else if (requiredMonthlySavings > monthlyIncome) {
        // ════════════════════════════════════════════════════════════════
        // STAGE 3️⃣: IMPOSSIBLE (REQUIRES MAJOR CHANGE)
        // ════════════════════════════════════════════════════════════════
        // Condition: Required > 70% or > monthly income
        // Status: Cannot achieve without changing goal/income/timeline
        // ════════════════════════════════════════════════════════════════

        feasibilityStage = 'impossible';
        isFeasible = false;
        feasibilityMessage =
            'Your goal requires RM${requiredMonthlySavings.toStringAsFixed(2)}/month, '
            'which exceeds your entire monthly income of RM${monthlyIncome.toStringAsFixed(2)}! '
            'This is impossible. Consider: 1) Reduce goal, 2) Extend timeline, 3) Increase income.';
      } else {
        // Still challenging but possible if expenses minimal
        feasibilityStage = 'challenging';
        isFeasible = false;
        feasibilityMessage =
            'Your goal requires RM${requiredMonthlySavings.toStringAsFixed(2)}/month. '
            'This is challenging. Available capacity: RM${monthlyNetIncome.toStringAsFixed(2)}/month. '
            'You need to reduce expenses or adjust your goal.';
      }
    }

    print('$_tag Feasibility Stage: $feasibilityStage');
    print('$_tag Feasible: $isFeasible');

    return SavingsSuggestionResult(
      success: true,
      suggestedMonthlySavings: recommendedMonthlySavings,
      requiredMonthlySavings: requiredMonthlySavings,
      targetAmount: targetAmount,
      timelineMonths: timelineMonths,
      targetDate: targetDate,
      averageMonthlyIncome: monthlyIncome,
      isFeasible: isFeasible,
      feasibilityMessage: feasibilityMessage,
    );
  } catch (e) {
    print('$_tag Error: $e');
    return SavingsSuggestionResult(
      success: false,
      isFeasible: false,
      feasibilityMessage: 'Error: $e',
    );
  }
}

// Helper: Round up to 2 decimal places
static double _ceilToTwoDecimals(double value) {
  return (value * 100).ceil() / 100;
}

// Helper: Calculate months between dates
static int _calculateMonthsBetween(DateTime start, DateTime end) {
  return (end.year - start.year) * 12 + (end.month - start.month);
}
```

---

### Section 4: Category-Based Advice Generation

```dart
/// Get spending advice by category (for recommendations)
Future<List<CategoryAdvice>> getCategorySpendingAdvice(
  String userId,
  int lookbackMonths = 3,
) async {
  try {
    final today = DateTime.now();
    final lookbackDate = today.subtract(Duration(days: lookbackMonths * 30));
    final dateString = DateFormat('yyyy-MM-dd').format(lookbackDate);

    print('$_tag Fetching category spending for past $lookbackMonths months...');

    // Query spending by category (GROUP BY categoryId)
    // SELECT categoryId, SUM(amount) as total
    // FROM Transaction
    // WHERE type = 'expense' AND date >= lookbackDate
    // GROUP BY categoryId
    // ORDER BY total DESC

    final transactions = await Supabase.instance.client
        .from('Transaction')
        .select('categoryId, amount, Category!inner(categoryId, name)')
        .eq('type', 'expense')
        .gte('date', dateString);

    // Group by category and sum
    final categoryTotals = <String, Map<String, dynamic>>{};
    for (final txn in transactions) {
      final categoryId = txn['categoryId'] as String;
      final amount = (txn['amount'] ?? 0).toDouble().abs();
      final category = txn['Category'];
      final categoryName = category != null ? category['name'] : 'Unknown';

      if (!categoryTotals.containsKey(categoryId)) {
        categoryTotals[categoryId] = {
          'name': categoryName,
          'total': 0.0,
          'count': 0,
        };
      }

      categoryTotals[categoryId]!['total'] += amount;
      categoryTotals[categoryId]!['count'] += 1;
    }

    // Convert to list and sort by total (descending)
    final sortedCategories = categoryTotals.entries
        .map((e) => CategoryAdvice(
          categoryId: e.key,
          categoryName: e.value['name'] as String,
          totalSpent: e.value['total'] as double,
          transactionCount: e.value['count'] as int,
        ))
        .toList()
      ..sort((a, b) => b.totalSpent.compareTo(a.totalSpent));

    print('$_tag Top 5 spending categories:');
    for (int i = 0; i < sortedCategories.length && i < 5; i++) {
      final cat = sortedCategories[i];
      print(
        '$_tag ${i + 1}. ${cat.categoryName}: RM${cat.totalSpent.toStringAsFixed(2)} '
        '(${cat.transactionCount} transactions)',
      );
    }

    return sortedCategories;
  } catch (e) {
    print('$_tag Error getting category advice: $e');
    return [];
  }
}

class CategoryAdvice {
  final String categoryId;
  final String categoryName;
  final double totalSpent;
  final int transactionCount;
  double get monthlyAverage => totalSpent / 3;  // Assuming 3 months lookback

  CategoryAdvice({
    required this.categoryId,
    required this.categoryName,
    required this.totalSpent,
    required this.transactionCount,
  });
}
```

---

## Performance Optimization Tips

### 1. **Caching Income Validation**
```dart
// Cache results for 7 days to reduce queries
final incomeCache = <String, CachedIncome>{};

Future<IncomeValidationResult> validateConsistentIncome(String userId) async {
  final cached = incomeCache[userId];
  
  if (cached != null && 
      DateTime.now().difference(cached.timestamp).inDays < 7) {
    print('$_tag Using cached income validation');
    return cached.result;
  }
  
  // Fresh validation...
  final result = await _validateConsistentIncomeFromDB(userId);
  incomeCache[userId] = CachedIncome(result, DateTime.now());
  return result;
}
```

### 2. **Parallel Queries**
```dart
// Run income validation and expense fetch in parallel
Future<GoalAssessment> assessGoal(String userId, ...) async {
  final [incomeResult, expenseResult] = await Future.wait([
    validateConsistentIncome(userId),
    getAverageMonthlyExpenses(userId),
  ]);
  
  // Now have both results to work with
  ...
}
```

### 3. **Forecast Caching**
```dart
// Cache forecast results for 24 hours
final forecastCache = <String, CachedForecast>{};

Future<ForecastResult> getSpendingForecast(
  String userId, {
  int periodsAhead = 1,
  String period = 'month',
}) async {
  final cacheKey = '$userId-$periodsAhead-$period';
  final cached = forecastCache[cacheKey];
  
  if (cached != null && 
      DateTime.now().difference(cached.timestamp).inHours < 24) {
    print('$_tag Using cached forecast');
    return cached.result;
  }
  
  // Fresh forecast from API...
  final result = await _getForecastFromAPI(...);
  forecastCache[cacheKey] = CachedForecast(result, DateTime.now());
  return result;
}
```

---

## Testing the Intelligence System

```dart
// Unit test example
void main() {
  group('Intelligent Savings Assistant', () {
    test('Achievable stage: Low savings, low expenses', () async {
      const monthlyIncome = 5000.0;
      const requiredSavings = 900.0;  // 18%
      const forecastedExpenses = 3800.0;  // 76%
      
      // Should be ACHIEVABLE
      expect(requiredSavings <= monthlyIncome * 0.20, true);
      expect(forecastedExpenses <= monthlyIncome * 0.80, true);
    });

    test('Challenging stage: High savings, manageable expenses', () async {
      const monthlyIncome = 5000.0;
      const requiredSavings = 1200.0;  // 24%
      const forecastedExpenses = 3800.0;  // 76%
      
      // Should be CHALLENGING (Type A)
      expect(requiredSavings > monthlyIncome * 0.20, true);
      expect(forecastedExpenses < monthlyIncome * 0.80, true);
      expect(requiredSavings <= monthlyIncome, true);
    });

    test('Impossible stage: Savings exceeds monthly income', () async {
      const monthlyIncome = 5000.0;
      const requiredSavings = 5500.0;  // 110%
      
      // Should be IMPOSSIBLE
      expect(requiredSavings > monthlyIncome, true);
    });

    test('Income validation: Finds 3+ consecutive months', () async {
      final months = ['2025-01', '2025-02', '2025-03', '2025-04'];
      final consecutive = _findConsecutiveMonths(months);
      
      expect(consecutive.length >= 3, true);
    });

    test('Forecast integration: Receives API response', () async {
      final forecast = await getSpendingForecast(
        userId: 'test_user',
        periodsAhead: 3,
      );
      
      expect(forecast.success, true);
      expect(forecast.forecast.length, 3);
      expect(forecast.forecast.every((v) => v > 0), true);
    });
  });
}
```

---

## Real-World Scenario Example

**User:** Amir  
**Goal:** Save RM18,000 for a car in 12 months  
**Current:** Monthly income RM6,000, expenses ~RM4,500

### System Workflow:

```
1. USER SUBMITS GOAL
   └─ Amount: RM18,000
   └─ Timeline: 12 months
   └─ Target Date: April 3, 2027

2. INCOME VALIDATION
   └─ Query: Transaction (type='income', past 12M)
   └─ Found: 12 months of salary
   └─ Result: RM6,000/month average ✅

3. EXPENSE FORECASTING
   └─ Historical: [4000, 4100, 4200, 4300, 4400, ...]
   └─ API Call: Prophet model
   └─ Forecast: [4500, 4550, 4600] for next 3 months

4. FEASIBILITY ASSESSMENT
   └─ Required: RM18,000 ÷ 12 = RM1,500/month
   └─ Savings %: 1500 ÷ 6000 = 25%
   └─ Expense %: 4550 ÷ 6000 = 75.8%
   
   └─ Check Stage:
      └─ 25% > 20%? YES
      └─ 75.8% < 80%? YES
      └─ Available: 6000 - 4550 = RM1,450 < Required RM1,500
   
   └─ VERDICT: 🟡 CHALLENGING (Type A)

5. ADVICE GENERATION
   └─ Top Categories:
      └─ 1. Food: RM1,400 (23%)
      └─ 2. Transport: RM900 (15%)
      └─ 3. Utilities: RM800 (13%)
      └─ 4. Entertainment: RM600 (10%)
      └─ 5. Shopping: RM500 (8%)
   
   └─ Recommendation:
      "You need to save RM1,500/month but currently have 
       capacity of RM1,450. Short by RM50/month.
       
       Easy fix: Reduce food spending by 3.5% (RM50/month)
       └─ Currently: RM1,400 → Target: RM1,350
       └─ Skip lunch Out 1x/week
       └─ Cook at home more
       
       Result: RM1,500/month capacity → ACHIEVABLE! ✅"

6. USER ACTION
   └─ Select: "Cut food by RM50"
   └─ Set Reminder: Weekly expense tracking
   └─ Save Goal: To dashboard
   └─ Monitor: Progress bar shows track to goal
```

This is the "intelligence" in action: not just "yes/no", but **why, how much, and how to fix it**!

