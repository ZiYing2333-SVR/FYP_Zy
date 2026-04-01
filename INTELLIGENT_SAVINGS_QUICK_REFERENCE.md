# Quick Reference Card - Intelligent Savings Goal Assistant

## 📋 Two Main Methods

### Method 1: Validate Income
```dart
final result = await IntelligentSavingsGoalAssistant.validateConsistentIncome(userId);

if (result.hasConsistentIncome) {
  // ✓ User has 3+ months of salary income
  print('Monthly income: RM${result.averageMonthlyIncome}');
  // Enable goal input fields
} else {
  // ✗ User doesn't have enough income records
  print(result.message); // User-friendly message
  // Show "Record Salary" button
  // Navigate with: categoryId = result.salaryCategoryId
}
```

### Method 2: Generate Suggestion
```dart
final suggestion = await IntelligentSavingsGoalAssistant.generateSavingsSuggestion(
  userId: userId,
  targetAmount: 5000,              // RM goal
  targetDate: DateTime(2027, 4, 2), // When to reach it
);

if (suggestion.success && suggestion.isFeasible) {
  // ✓ Goal is achievable
  print('Save RM${suggestion.suggestedMonthlySavings}/month');
} else if (suggestion.success && !suggestion.isFeasible) {
  // ⚠️ Goal is challenging
  print('${suggestion.feasibilityMessage}');
} else {
  // ✗ Error occurred
  print('Error: ${suggestion.feasibilityMessage}');
}
```

---

## 🔄 Implementation Flow

```
1. User Opens Savings Goal Screen
   └─> Call validateConsistentIncome(userId)
       ├─ No? Show: "Record salary" → Redirect to Add Transaction
       └─ Yes? Continue...

2. User Enters Target & Date
   └─> Call generateSavingsSuggestion(userId, target, date)
       ├─ Show: "Save RM{amount}/month"
       ├─ Status: ✓ Achievable or ⚠️ Challenging
       └─> User confirms → Proceed to plan
```

---

## 📊 Key Calculations

| What | Formula |
|------|---------|
| Monthly Savings Needed | goal ÷ months |
| Timeline (months) | (targetYear - nowYear) × 12 + (targetMonth - nowMonth) |
| Feasible? | suggestedMonthlySavings ≤ (income - expenses) |
| Average Income | Sum of salaries ÷ count |
| Average Expense | Sum of expenses (3mo) ÷ 3 |

**Example**:
- Goal: RM 5,000
- Timeline: 12 months
- **Monthly Savings = 5,000 ÷ 12 = RM 416.67**
- Income: RM 3,500/mo
- Expenses: RM 2,500/mo
- Available: RM 1,000/mo
- **Feasible? Yes (416.67 ≤ 1,000) ✓**

---

## 🎯 Return Values Quick Reference

### IncomeValidationResult
```dart
{
  success: bool,                    // Operation worked?
  hasConsistentIncome: bool,        // Has 3+ months?
  averageMonthlyIncome: double,     // RM/month
  salaryMonths: ["2026-01", ...],   // Months with income
  consistentMonthsCount: int,       // Count of consecutive months
  message: String,                  // Explanation for UI
  salaryCategoryId: String,         // To pass to Add Transaction
}
```

### SavingsSuggestionResult
```dart
{
  success: bool,                      // Operation worked?
  suggestedMonthlySavings: double,   // RM/month to save
  targetAmount: double,               // Goal amount
  timelineMonths: int,                // Months to goal
  targetDate: DateTime,               // When goal is reached
  averageMonthlyIncome: double,       // RM/month income
  analysis: String,                   // Explanation for UI
  isFeasible: bool,                   // Achievable?
  feasibilityMessage: String,         // ✓ or ⚠️ message
}
```

---

## 🚀 Quick Implementation (3 Steps)

### Step 1: Check Income
```dart
final check = await IntelligentSavingsGoalAssistant.validateConsistentIncome(userId);
```

### Step 2: If No Income
```dart
ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(check.message)));
// Navigate to Add Transaction with:
// categoryId = check.salaryCategoryId, type = 'income'
```

### Step 3: If Has Income
```dart
final suggestion = await IntelligentSavingsGoalAssistant.generateSavingsSuggestion(
  userId: userId,
  targetAmount: double.parse(targetController.text),
  targetDate: selectedDate,
);

// Display: RM{suggestion.suggestedMonthlySavings}/month
// Status: suggestion.isFeasible ? '✓' : '⚠️'
// Message: suggestion.feasibilityMessage
```

---

## 🔑 Key Points

✅ **Always validate income first** before suggesting savings  
✅ **3 months minimum** of consistent salary income required  
✅ **Monthly savings = Target ÷ Months** (simple formula)  
✅ **Show feasibility status** (✓ or ⚠️) to set expectations  
✅ **Auto-select salary category** when redirecting to add income  

---

## ⚠️ Common Errors & Fixes

| Error | Cause | Fix |
|-------|-------|-----|
| "No salary category found" | User never created one | Show "Record salary" prompt |
| "Need 3 months" | Only 1-2 months of income | Tell user to add more |
| "Target date is past" | Selected past date | Validate: date > today |
| Monthly savings seems wrong | Check calculation | Verify: (target ÷ timeline) |

---

## 📌 UI Checklist

- [ ] Income validation card (shows status + amount)
- [ ] Goal input disabled if no consistent income
- [ ] "Record Salary" button visible if no income
- [ ] "Save RM{X}/month" prominently displayed
- [ ] Feasibility status (✓ or ⚠️) with message
- [ ] Timeline calculation correct (months from today)
- [ ] Salary category auto-selected on redirect

---

## 🔗 Database Tables Used

### Category
- Lookup: userId + type='income' + name contains 'salary'
- Returns: categoryId, name

### Transaction
- Query: categoryId + date (12 months back) → salary amounts
- Query: type='expense' + date (3 months back) → expense amounts
- Group by: YYYY-MM format

---

## 📚 Documentation

For complete details, see:
1. `INTELLIGENT_SAVINGS_INCOME_VALIDATION_GUIDE.md` - Full guide
2. `SAVINGS_GOAL_IMPLEMENTATION_STEPS.md` - Code examples
3. `INTELLIGENT_SAVINGS_DATA_STRUCTURES.md` - Data reference

For implementation in UI screen, see:
- `SAVINGS_GOAL_IMPLEMENTATION_STEPS.md` - Code snippets for saving_goal_assistant_screen.dart

---

## 🧪 Test Cases

```
✓ No salary records → Show "Record salary" + disabled fields
✓ 1-2 months salary → Show "Need 3 months" + disabled fields
✓ 3+ months salary → Show income amount + enabled fields
✓ Enter goal & date → Show "Save RM{X}/month"
✓ Achievable goal → Show "✓ Achievable" message
✓ Challenging goal → Show "⚠️ May be challenging" + suggestion
✓ Past date → Show "Target date must be future"
✓ Redirect to Add Transaction → Salary category auto-selected
```

---

## 💡 Tips

1. **Always check `result.success`** before using other fields
2. **Use `result.message`** for user-facing error text
3. **Use `result.salaryCategoryId`** when redirecting to Add Transaction
4. **Show `isFeasible` with icon** (✓ or ⚠️) not just text
5. **Calculate timeline fresh** - don't hardcode months
6. **Round amounts to 2 decimals** (use `.toStringAsFixed(2)`)

---

