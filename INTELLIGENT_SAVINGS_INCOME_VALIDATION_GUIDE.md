# Intelligent Savings Goal Assistant - Income Validation Guide

## Overview

The updated `IntelligentSavingsGoalAssistant` service now includes **income-based validation** for savings goals. This ensures savings suggestions are based on actual, consistent monthly income records from the Category table.

## Key Features

### 1️⃣ Income Validation (`validateConsistentIncome`)

**Purpose**: Validates that the user has at least **3 consecutive months** of salary income before allowing savings suggestions.

**Business Logic**:
- Searches for "salary" category (case-insensitive, type='income') for the user
- Fetches all salary transactions from the last 12 months
- Groups transactions by month (YYYY-MM format)
- Identifies the longest consecutive month sequence
- Requires minimum 3 months of income to proceed

**Return Value**:
```dart
IncomeValidationResult {
  success: bool,                      // Operation successful?
  hasConsistentIncome: bool,          // Has 3+ months?
  averageMonthlyIncome: double,       // Average salary per month
  salaryMonths: List<String>,         // All months with income (YYYY-MM)
  consistentMonthsCount: int,         // Count of consecutive months
  message: String,                    // User-friendly message
  salaryCategoryId: String?,          // ID of salary category
}
```

**Example Usage**:
```dart
final incomeCheck = await IntelligentSavingsGoalAssistant.validateConsistentIncome(userId);

if (incomeCheck.hasConsistentIncome) {
  // User has 3+ months of salary income - proceed to savings suggestion
  print('Average income: RM${incomeCheck.averageMonthlyIncome}');
} else {
  // User needs to record salary income first
  print(incomeCheck.message); // "Please record your monthly salary first"
  // Show button: "Go to Transaction Page" (navigate with salary category auto-selected)
}
```

**UI Integration**:
1. Call `validateConsistentIncome()` when user opens the savings goal screen
2. If `hasConsistentIncome` is **false**:
   - Show a message: `incomeCheck.message`
   - Provide button: "Record Salary Income"
   - Button navigates to **Add Transaction** screen with:
     - `categoryId` = `incomeCheck.salaryCategoryId`
     - `type` = 'income'
     - Pre-filled as salary income entry

3. If `hasConsistentIncome` is **true**:
   - Show income summary: "Your consistent monthly income: RM{averageMonthlyIncome}"
   - Enable savings goal input fields

---

### 2️⃣ Savings Suggestion (`generateSavingsSuggestion`)

**Purpose**: Calculates the **minimum monthly savings amount** needed to reach a goal by a target date.

**Business Logic**:
1. Validates consistent income (requires 3+ months)
2. Calculates timeline in months (from today to target date)
3. **Calculates monthly savings = Goal Amount ÷ Timeline Months**
4. Fetches average monthly expenses (last 3 months)
5. Assesses feasibility based on: `Monthly Savings Needed ≤ (Income - Expenses)`

**Return Value**:
```dart
SavingsSuggestionResult {
  success: bool,                      // Operation successful?
  suggestedMonthlySavings: double,    // RM amount to save per month
  targetAmount: double,               // Goal amount
  timelineMonths: int,                // Months until target date
  targetDate: DateTime,               // When to reach goal
  averageMonthlyIncome: double,       // User's average salary
  analysis: String,                   // Detailed analysis text
  isFeasible: bool,                   // Achievable with current income/expenses?
  feasibilityMessage: String,         // User-friendly feasibility explanation
}
```

**Example Usage**:
```dart
final suggestion = await IntelligentSavingsGoalAssistant.generateSavingsSuggestion(
  userId: userId,
  targetAmount: 5000,  // Goal: RM 5000
  targetDate: DateTime(2026, 12, 31),  // By end of 2026
);

if (suggestion.success && suggestion.isFeasible) {
  // Goal is achievable
  print('Save RM${suggestion.suggestedMonthlySavings} per month');
  print(suggestion.feasibilityMessage);
} else if (suggestion.success && !suggestion.isFeasible) {
  // Show warning
  print('Goal is challenging: ${suggestion.feasibilityMessage}');
  // Suggest: extend timeline, reduce goal, or increase income
} else {
  // Error occurred
  print('Cannot provide suggestion: ${suggestion.feasibilityMessage}');
}
```

**Calculation Example**:
```
Target Goal: RM 5,000
Target Date: 12 months from now
Timeline: 12 months

Monthly Savings Needed = 5,000 ÷ 12 = RM 416.67 per month

User's Profile:
- Average Monthly Income: RM 3,500 (from 3+ months salary records)
- Average Monthly Expenses: RM 2,500 (from last 3 months)
- Net Monthly Savings Capacity: RM 1,000

Feasibility: RM 416.67 ≤ RM 1,000 ✓ ACHIEVABLE
```

**UI Integration**:
1. Call `validateConsistentIncome()` first
2. If no consistent income, show prompt to record salary
3. If has consistent income, show goal input fields:
   - Target Amount (RM)
   - Target Date (date picker)

4. When user submits:
   ```dart
   final suggestion = await IntelligentSavingsGoalAssistant.generateSavingsSuggestion(
     userId: userId,
     targetAmount: double.parse(targetAmountController.text),
     targetDate: selectedTargetDate,
   );
   ```

5. Display results:
   - "Suggested Monthly Savings: **RM {suggestedMonthlySavings}**"
   - Analysis: `suggestion.analysis`
   - Feasibility status with icon (✓ or ⚠️)
   - Message: `suggestion.feasibilityMessage`

---

## Integration Flow

### Screen: Savings Goal Assistant

```
1. User Opens Savings Goal Screen
   ↓
2. Call validateConsistentIncome()
   ↓
   ├─ No consistent income (< 3 months)
   │  ├─ Show message: "Please record your monthly salary"
   │  ├─ Disable goal input fields
   │  └─ Show "Record Salary" button → Navigate to Add Transaction
   │     (Auto-select salary category, type='income')
   │
   └─ Has consistent income (3+ months)
      ├─ Enable goal input fields
      ├─ Show income summary: "Monthly Income: RM {average}"
      ├─ User enters Target Amount & Target Date
      │
      ├─ Call generateSavingsSuggestion()
      │  ├─ Calculate: Monthly Savings = Target ÷ Months
      │  ├─ Check feasibility vs average income
      │  └─ Return results with analysis
      │
      └─ Display:
         ├─ Suggested Monthly Savings (large, highlighted)
         ├─ Detailed analysis text
         ├─ Feasibility status
         └─ "Continue to Plan" or "Adjust Goal"
```

---

## Category Table Schema (Reference)

```sql
CREATE TABLE public."Category" (
  "categoryId" character varying NOT NULL,
  name character varying NOT NULL,                  -- "Salary", "Bonus", etc.
  icon character varying NULL,
  type character varying NOT NULL,                  -- 'income' or 'expense'
  "userId" character varying NULL,                  -- User who owns this category
  "spendingSummaryId" character varying NULL,
  "incomeSummaryId" character varying NULL,
  keywords text NULL,
  CONSTRAINT Category_pkey PRIMARY KEY ("categoryId"),
  CONSTRAINT Category_userId_fkey FOREIGN KEY ("userId") 
    REFERENCES "User" ("userId") ON UPDATE CASCADE ON DELETE CASCADE
);
```

**Key Points**:
- `type = 'income'` for salary/income categories
- `type = 'expense'` for spending categories
- Search for salary: `ILIKE 'salary'` on name field
- User-specific categories via `userId`

---

## Transaction Table Schema (Reference)

```
Relevant fields used:
- categoryId: Links to Category table
- date: Transaction date (YYYY-MM-DD)
- amount: Positive for income, Negative for expenses
- type: 'income' or 'expense'
- userId: Transaction owner
```

---

## Methods Summary

| Method | Purpose | Returns | Requires |
|--------|---------|---------|----------|
| `validateConsistentIncome(userId)` | Check income consistency | `IncomeValidationResult` | User has salary transactions |
| `generateSavingsSuggestion(userId, targetAmount, targetDate)` | Calculate monthly savings | `SavingsSuggestionResult` | 3+ months consistent income |
| `_findConsecutiveMonths(months)` | Find longest consecutive sequence | `List<String>` | Sorted month list |
| `_calculateMonthsBetween(start, end)` | Calculate month difference | `int` | Two DateTime objects |
| `_getAverageMonthlyExpenses(userId)` | Get avg expenses (3 months) | `double` | Expense transactions |

---

## Important Notes

1. **Income Validation**: Always call `validateConsistentIncome()` before `generateSavingsSuggestion()`
   - User must have 3+ consecutive months of salary income
   - Ensures reliable income data for feasibility analysis

2. **Minimum Months**: Set to **3** (configurable via `_minConsistentMonths`)
   - Provides statistically meaningful average
   - Balance between requirement and user convenience

3. **Timeline Calculation**: Calculated from **today** to target date
   - Months = (targetYear - nowYear) × 12 + (targetMonth - nowMonth)
   - Minimum 1 month required

4. **Feasibility Assessment**: Compares needed savings vs available capacity
   - Needed = Goal ÷ Months
   - Available = Average Income - Average Expenses (last 3 months)
   - Feasible if: Needed ≤ Available

5. **Expense Averaging**: Uses **last 3 months** of transactions
   - More recent data = more accurate feasibility check
   - Defaults to 0 if no expense data available

6. **Error Handling**: All methods return success flag
   - Check `result.success` before using other fields
   - Otherwise use `result.message` / `feasibilityMessage` for error details

---

## Example UI Code

### Check Income & Show GoalAmount Form
```dart
void _initializeSavingsGoal() async {
  final incomeCheck = await IntelligentSavingsGoalAssistant
      .validateConsistentIncome(widget.userId);
  
  setState(() {
    _incomeValidation = incomeCheck;
    _isLoadingIncome = false;
  });
  
  if (!incomeCheck.hasConsistentIncome) {
    // Show prompt
    _showIncomeRecordingPrompt(incomeCheck);
  }
}

void _showIncomeRecordingPrompt(IncomeValidationResult validation) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Record Monthly Salary'),
      content: Text(validation.message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Later'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            // Navigate to Add Transaction with salary category
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AddTransactionScreen(
                  initialCategoryId: validation.salaryCategoryId,
                  initialType: 'income',
                ),
              ),
            );
          },
          child: Text('Record Salary'),
        ),
      ],
    ),
  );
}

void _analyzeSavingsGoal() async {
  final suggestion = await IntelligentSavingsGoalAssistant
      .generateSavingsSuggestion(
    userId: widget.userId,
    targetAmount: double.parse(_targetAmountController.text),
    targetDate: _selectedTargetDate!,
  );
  
  setState(() {
    _savingsSuggestion = suggestion;
    _isAnalyzing = false;
  });
  
  if (suggestion.success) {
    // Show results to user
    _showSavingsSuggestionDialog(suggestion);
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(suggestion.feasibilityMessage)),
    );
  }
}
```

---

## Testing Checklist

- [ ] User with no transactions sees: "Record your monthly salary"
- [ ] User with 1-2 months of salary sees: "Record at least 3 months"
- [ ] User with 3+ months of salary:
  - [ ] Can enter goal amount & target date
  - [ ] Sees calculated monthly savings needed
  - [ ] Sees feasibility assessment (✓ or ⚠️)
  - [ ] Feasibility message matches income vs savings needed
- [ ] Timeline calculation correct (today + 12 months = 12 months)
- [ ] Salary category auto-selected when redirected to add transaction
- [ ] Monthly savings = Goal ÷ Months (verify calculation)
- [ ] Navigation flow: Income validation → Goal input → Suggestion → Plan

---

## Troubleshooting

**Issue**: "No salary income category found"
- **Solution**: Ensure categories are created with `type='income'` and name contains "salary"
- Check Category table directly

**Issue**: "You need to record at least 3 months"
- **Solution**: Expected behavior when user has < 3 months of transactions
- Direct user to Add Transaction screen to record monthly salary

**Issue**: Goal shows as not feasible
- **Solution**: Compare suggested monthly savings vs user's available capacity
- Suggest: extend timeline, reduce goal, or reduce expenses

**Issue**: Monthly savings calculation seems wrong
- **Solution**: Verify calculation: Goal ÷ Months
- Check targetDate is later than today
- Verify average income from salary records (3+ months)

