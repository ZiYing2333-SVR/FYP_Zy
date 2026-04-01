# 🎯 Forecast-Aware Intelligent Savings Assistant

## Overview
Your intelligent savings assistant now integrates **expense forecasting with savings goal analysis**. 

**Key Logic:**
```
If predicted expenses > 80% of salary
  → Available savings < 20%
  → Adjust recommendations accordingly
  → Suggest expense reductions
  → Provide alternative savings scenarios
```

---

## 🧠 How It Works

### The Logic Flow

```
┌──────────────────────────────────────────────┐
│ User wants to create a savings goal          │
└──────────────────┬───────────────────────────┘
                   │
                   ↓
    ┌──────────────────────────────┐
    │ Get User Monthly Income      │
    │ (from salary transactions)   │
    └──────────────┬───────────────┘
                   │
                   ↓
     ┌─────────────────────────────┐
     │ Predict Next Month Expenses │
     │ (using Prophet AI)          │
     └──────────────┬──────────────┘
                    │
                    ↓
      ┌──────────────────────────────────┐
      │ Calculate Expense Ratio          │
      │ = (Predicted Expense / Income) * 100%
      │                                  │
      │ If > 80%: ❌ Cannot save 20%    │
      │ If ≤ 80%: ✅ Can save 20%       │
      └──────────────┬───────────────────┘
                     │
        ┌────────────┴────────────┐
        │                         │
        ↓                         ↓
   ❌ HIGH RISK            ✅ HEALTHY
   (>80% expenses)         (<80% expenses)
        │                         │
        ├─ Adjust goal down       ├─ Maintain 20%
        ├─ Suggest cuts           ├─ Optimize spending
        ├─ Target categories      ├─ Save more if possible
        └─ Provide alternatives   └─ Review quarterly
```

---

## 📊 The New Method: `analyzeSavingsGoalWithExpenseForecast()`

This is the **MAIN** integration method. Use it in your savings goal screens.

### Method Signature
```dart
static Future<ForecastAwareSavingsAnalysis> analyzeSavingsGoalWithExpenseForecast(
  String userId, {
  double savingsTargetPercent = 0.20,  // Default 20%
  double riskThreshold = 0.80,         // Alert at 80% of income
})
```

### What It Returns: `ForecastAwareSavingsAnalysis`

```dart
class ForecastAwareSavingsAnalysis {
  // Financial Summary
  double monthlyIncome;
  double predictedMonthlyExpense;
  double expenseRatio;                 // 0-1 (0-100%)
  double availableForSavings;          // What's left after expenses
  
  // Savings Recommendations
  double originalSavingsTarget;        // 20% of income
  double adjustedSavingsTarget;        // What's actually feasible
  
  // Risk Assessment
  String riskLevel;                    // 'low', 'medium', 'high', 'critical'
  bool isSavingsGoalFeasible;          // Can achieve 20%?
  
  // AI-Generated Actions
  String analysis;                     // Detailed text analysis
  List<String> urgentActions;          // What to do immediately
  List<String> categoryReductionSuggestions;  // "Reduce X by Y%"
  int recommendedExpenseReductionPercent;    // How much to cut
  
  // Scenarios
  List<Map<String, dynamic>> alternativeScenarios;
  // [
  //   {"name": "5% savings", "monthly_savings": 500, ...},
  //   {"name": "10% savings", "monthly_savings": 1000, ...},
  //   {"name": "20% savings", "monthly_savings": 2000, ...},
  //   {"name": "25% savings", "monthly_savings": 2500, ...},
  // ]
}
```

---

## 💻 Usage Example

### In Your Savings Goal Assistant Screen

```dart
Future<void> _analyzeSavingsWithForecast() async {
  final userId = Supabase.instance.client.auth.currentSession?.user.id ?? '';
  
  try {
    // ✅ Call the new forecast-aware method
    final analysis = await IntelligentSavingsGoalAssistant
        .analyzeSavingsGoalWithExpenseForecast(userId);

    if (!analysis.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${analysis.analysis}')),
      );
      return;
    }

    print('📊 Analysis Results:');
    print('Monthly Income: RM${analysis.monthlyIncome.toStringAsFixed(2)}');
    print('Predicted Expense: RM${analysis.predictedMonthlyExpense.toStringAsFixed(2)}');
    print('Expense Ratio: ${(analysis.expenseRatio * 100).toStringAsFixed(1)}%');
    print('Risk Level: ${analysis.riskLevel}');
    print('Can achieve 20% savings? ${analysis.isSavingsGoalFeasible ? '✅ YES' : '❌ NO'}');
    
    setState(() {
      _analysis = analysis;
      _showAnalysisResults();
    });
  } catch (e) {
    print('Error: $e');
  }
}

void _showAnalysisResults() {
  // Show different UI based on risk level
  
  if (_analysis.isSavingsGoalFeasible) {
    // ✅ GREEN: Show "You can achieve 20% savings"
    _showGreenCard(
      title: 'Great News! ✅',
      body: 'You can save 20% (RM${_analysis.originalSavingsTarget.toStringAsFixed(2)})',
      actions: _analysis.urgentActions,
    );
  } else {
    // ❌ RED: Show adjusted recommendation
    _showWarningCard(
      title: 'Adjust Your Goal',
      riskLevel: _analysis.riskLevel,
      body: _analysis.analysis,
      newTarget: _analysis.adjustedSavingsTarget,
      suggestions: _analysis.categoryReductionSuggestions,
      urgentActions: _analysis.urgentActions,
      scenarios: _analysis.alternativeScenarios,
    );
  }
}
```

---

## 🎨 4 Risk Levels & What to Do

### 🟢 **RISK LEVEL: LOW** (<70% expenses)
```
Expense Ratio: 60%
Available for Savings: 40%

✅ Great News!
You have excellent budget control.
You can save 20%+ of income.

Action: 
• Start or increase savings goal immediately
• Consider saving 25%+ if possible
• Review quarterly to maintain
```

### 🟡 **RISK LEVEL: MEDIUM** (70-80% expenses)
```
Expense Ratio: 75%
Available for Savings: 25%

📊 Good Position
You can save 15-20% of income.

Action:
• Optimize top 1-2 spending categories
• Track expenses closely
• Avoid big new purchases
• Monitor monthly for 2-3 months
```

### 🟠 **RISK LEVEL: HIGH** (80-88% expenses)
```
Expense Ratio: 85%
Available for Savings: 15%

⚠️ Attention Required!
You cannot save full 20% right now.
Recommended: Reduce to 10-15% temporarily.

Action:
• Immediately identify 5-10% expense cuts
• Reduce: Food, Transport, Entertainment
• Postpone non-essential purchases
• Work toward 20% within 3-6 months
```

### 🔴 **RISK LEVEL: CRITICAL** (>88% expenses)
```
Expense Ratio: 92%
Available for Savings: 8%

🚨 URGENT ACTION NEEDED!
You're not saving enough to build wealth.
Cannot achieve 20% savings goal.

Action (DO THIS NOW):
1. Review ALL subscriptions - cancel unused ones
2. Cut discretionary expenses: dining, shopping
3. Find additional income sources
4. Reduce savings target to 5% temporarily
5. Get professional budget help

Alternative: Lower goal to 5%, increase income
```

---

## 📋 Category Reduction Suggestions

When expenses are high, the system analyzes your spending by category and suggests:

```
Current Breakdown:
• Food & Dining: 35% 🔴 CONCERNING
  → Reduce by 8% (Save RM240/month)
  
• Transport: 20% ✅ OK
  → Reduce by 5% (Save RM50/month)
  
• Entertainment: 15% ✅ OK
  → Reduce by 3% (Save RM30/month)

TOTAL REDUCTION TARGET: ~10% (Save RM320/month)
This frees up the 20% savings goal!
```

---

## 🎯 Alternative Scenarios Provided

The system generates **4 savings scenarios** automatically:

```dart
// Results included in: analysis.alternativeScenarios

[
  {
    'name': 'Emergency Mode (5% savings)',
    'monthly_savings': 500,
    'monthly_expense': 9500,
    'savings_per_year': 6000,
    'feasibility': 'FEASIBLE',
    'description': 'Minimum savings mode. Use if expenses are high.'
  },
  {
    'name': 'Conservative (10% savings)',
    'monthly_savings': 1000,
    'monthly_expense': 9000,
    'savings_per_year': 12000,
    'feasibility': 'FEASIBLE',
    'description': 'Balanced approach. Good if budget is moderate.'
  },
  {
    'name': 'Target (20% savings)',  // ⭐ GOAL
    'monthly_savings': 2000,
    'monthly_expense': 8000,
    'savings_per_year': 24000,
    'feasibility': 'NOT FEASIBLE' or 'FEASIBLE',
    'description': 'Recommended savings rate. AIM FOR THIS.'
  },
  {
    'name': 'Aggressive (25% savings)',
    'monthly_savings': 2500,
    'monthly_expense': 7500,
    'savings_per_year': 30000,
    'feasibility': 'NOT FEASIBLE',
    'description': 'High savings rate. Requires expense control.'
  }
]
```

---

## 📊 What The Analysis Includes

The `analysis.analysis` text includes:

```
=== FORECAST-AWARE SAVINGS ANALYSIS ===

📊 YOUR FINANCIAL SNAPSHOT:
Monthly Income: RM10,000
Predicted Expenses: RM8,500
Expense Ratio: 85.0%
Available for Savings: RM1,500

⚠️ ATTENTION REQUIRED:
Your predicted expenses (85.0%) exceed 80% of income.
Your 20% savings goal is NOT FEASIBLE without changes.
Original 20% target: RM2,000/month
Adjusted recommendation: RM1,500/month

⚡ RISK ASSESSMENT:
RISK LEVEL: 🟠 HIGH
Your budget is tight. You're spending 80-88% of income.
ACTION: Reduce expenses by 5-10% to create savings cushion.

💡 RECOMMENDATION:
1. FIRST: Reduce expenses to below 80% of income
2. TARGET: Identify categories to cut by 6%
3. THEN: Start with RM1,500/month savings
4. GROWTH: Increase savings as you optimize expenses
5. GOAL: Work your way up to 20% savings within 3-6 months
```

---

## 🚀 Integration Checklist

### Phase 1: Immediate Integration
- [ ] Import the method in your savings goal screen
- [ ] Call `analyzeSavingsGoalWithExpenseForecast(userId)` when analyzing goals
- [ ] Display the risk level with color coding (🔴 🟠 🟡 🟢)
- [ ] Show the analysis text to the user

### Phase 2: Enhanced UI
- [ ] Show urgent action items list
- [ ] Display category reduction suggestions
- [ ] Show alternative scenarios in a carousel/list
- [ ] Add progress tracking (current vs target savings)

### Phase 3: Smart Notifications
- [ ] Alert if risk level is "high" or "critical"
- [ ] Notify when forecast improves
- [ ] Remind to review monthly

---

## 🔄 Data Flow in Your App

```
Savings Goal Assistant Screen
        │
        ├─ User enters target amount
        ├─ User enters timeline
        │
        ↓
analyzeSavingsGoalWithExpenseForecast(userId)
        │
        ├─ Query: Get monthly income
        ├─ Call: getSpendingForecast() ← Uses Prophet AI
        ├─ Call: getCategorySpendingAdvice() ← Breakdown by category
        │
        ├─ Calculate: Expense Ratio
        ├─ Calculate: Available for Savings
        ├─ Generate: Risk Level
        ├─ Generate: Urgent Actions
        ├─ Generate: Category Reductions
        ├─ Generate: Alternative Scenarios
        │
        ↓
Returns: ForecastAwareSavingsAnalysis
        │
        ├─ Analysis.isSavingsGoalFeasible → Green/Red card
        ├─ Analysis.riskLevel → Color code
        ├─ Analysis.urgentActions → Action checklist
        ├─ Analysis.categoryReductionSuggestions → Targeted advice
        ├─ Analysis.alternativeScenarios → Other options
        │
        ↓
Display in UI with appropriate messaging
```

---

## 📱 UI Examples

### Scenario 1: Healthy Budget (✅ Green)
```
┌─────────────────────────────────┐
│ ✅ EXCELLENT NEWS               │
├─────────────────────────────────┤
│                                 │
│ You can achieve your 20% goal!  │
│                                 │
│ Monthly Income:    RM 10,000    │
│ Predicted Expense: RM  7,000    │
│ Expense Ratio:     70%          │
│ Can Save:          RM  3,000    │
│ (30% of income!)                │
│                                 │
│ [✓] Proceed with 20% goal       │
│ [+] Even consider 25%           │
│                                 │
└─────────────────────────────────┘
```

### Scenario 2: Tight Budget (⚠️ Orange)
```
┌──────────────────────────────────┐
│ ⚠️ ADJUST YOUR GOAL              │
├──────────────────────────────────┤
│                                  │
│ Your 20% goal is at risk         │
│                                  │
│ Monthly Income:    RM 10,000     │
│ Predicted Expense: RM  8,500     │
│ Expense Ratio:     85%           │
│ Can Actually Save: RM  1,500     │
│ (15% of income)                  │
│                                  │
│ ⚡ URGENT ACTIONS:              │
│ • Reduce Food by 8% (Save RM240) │
│ • Reduce Transport by 5%         │
│ • Cancel unused subscriptions    │
│                                  │
│ 📊 SCENARIOS:                   │
│ 5%:  RM  500 - FEASIBLE         │
│ 10%: RM 1000 - FEASIBLE         │
│ 20%: RM 2000 - NOT FEASIBLE ❌  │
│                                  │
│ [✓] Reduce expenses first        │
│ [→] Try 10% for now              │
│                                  │
└──────────────────────────────────┘
```

---

## 🎯 Summary

**This integration gives you:**

1. ✅ **Intelligent Prediction** - Uses Prophet to forecast expenses
2. ✅ **Risk Assessment** - Tells you if 20% savings is feasible
3. ✅ **Smart Recommendations** - Adjusts goals based on forecast
4. ✅ **Category Analysis** - "Reduce food by 8%, transport by 5%..."
5. ✅ **Alternative Options** - 5%, 10%, 20%, 25% savings scenarios
6. ✅ **Urgent Actions** - What to do immediately to improve

**The user experience:**
```
User: "I want to save RM10,000 in 12 months"
       ↓
App analyzes forecast and says:
"Your expenses are too high right now. 
 Start by saving 10% (RM1,500/month) 
 by reducing food spending by 8%.
 After 3 months, scale up to 20%!"
       ↓
User sees exactly what to do to make it work ✅
```

---

Good luck with your FYP! 🚀
