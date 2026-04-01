# Intelligent Savings Goal Assistant - Data Structures & Examples

## Return Data Structures

### 1. IncomeValidationResult

**Purpose**: Returned from `validateConsistentIncome(userId)`

**Dart Class**:
```dart
class IncomeValidationResult {
  final bool success;
  final bool hasConsistentIncome;
  final double averageMonthlyIncome;
  final List<String> salaryMonths;
  final int consistentMonthsCount;
  final String message;
  final String? salaryCategoryId;
}
```

**Example 1: User has NO consistent income**
```dart
IncomeValidationResult(
  success: true,
  hasConsistentIncome: false,
  averageMonthlyIncome: 0.0,
  salaryMonths: [],
  consistentMonthsCount: 0,
  message: 'No salary income category found. Please record your monthly salary first.',
  salaryCategoryId: null,
)
```

**Example 2: User has salary records but less than 3 months**
```dart
IncomeValidationResult(
  success: true,
  hasConsistentIncome: false,
  averageMonthlyIncome: 3500.0,
  salaryMonths: ['2026-01', '2026-02'], // Only 2 months
  consistentMonthsCount: 2,
  message: 'You need to record at least 3 months of consistent salary income before we can provide savings suggestions.',
  salaryCategoryId: 'cat_salary_user123',
)
```

**Example 3: User has 3+ months of consistent income ✓**
```dart
IncomeValidationResult(
  success: true,
  hasConsistentIncome: true,
  averageMonthlyIncome: 3500.0,
  salaryMonths: ['2025-11', '2025-12', '2026-01', '2026-02'],
  consistentMonthsCount: 4,
  message: 'Great! You have 3+ months of consistent income (RM3500.00/month).',
  salaryCategoryId: 'cat_salary_user123',
)
```

**Example 4: Database error**
```dart
IncomeValidationResult(
  success: false,
  hasConsistentIncome: false,
  averageMonthlyIncome: 0.0,
  salaryMonths: [],
  consistentMonthsCount: 0,
  message: 'Error validating income: PgException(...)',
  salaryCategoryId: null,
)
```

---

### 2. SavingsSuggestionResult

**Purpose**: Returned from `generateSavingsSuggestion(userId, targetAmount, targetDate)`

**Dart Class**:
```dart
class SavingsSuggestionResult {
  final bool success;
  final double suggestedMonthlySavings;
  final double targetAmount;
  final int timelineMonths;
  final DateTime targetDate;
  final double averageMonthlyIncome;
  final String analysis;
  final bool isFeasible;
  final String feasibilityMessage;
}
```

**Example 1: Goal is FEASIBLE ✓**
```dart
SavingsSuggestionResult(
  success: true,
  suggestedMonthlySavings: 416.67,
  targetAmount: 5000.0,
  timelineMonths: 12,
  targetDate: DateTime(2027, 4, 2),
  averageMonthlyIncome: 3500.0,
  analysis: 'Based on your consistent monthly income of RM3500.00, you need to save RM416.67 per month to reach your goal of RM5000.00 by Apr 2027.',
  isFeasible: true,
  feasibilityMessage: 'Goal is achievable! You can save RM416.67/month comfortably with your current income (RM3500.00) and expenses (RM2500.00).',
)
```

**Example 2: Goal is NOT FEASIBLE ⚠️**
```dart
SavingsSuggestionResult(
  success: true,
  suggestedMonthlySavings: 833.33,
  targetAmount: 10000.0,
  timelineMonths: 12,
  targetDate: DateTime(2027, 4, 2),
  averageMonthlyIncome: 3500.0,
  analysis: 'Based on your consistent monthly income of RM3500.00, you need to save RM833.33 per month to reach your goal of RM10000.00 by Apr 2027.',
  isFeasible: false,
  feasibilityMessage: 'This goal may be challenging. You need to save RM833.33/month, but your net monthly savings is only RM1000.00. Consider extending the timeline or reducing expenses.',
)
```

**Example 3: Invalid target date in the past**
```dart
SavingsSuggestionResult(
  success: false,
  suggestedMonthlySavings: 0.0,
  targetAmount: 5000.0,
  timelineMonths: 0,
  targetDate: DateTime(2025, 1, 1), // Past date
  averageMonthlyIncome: 3500.0,
  analysis: 'Invalid target date',
  isFeasible: false,
  feasibilityMessage: 'Target date must be in the future. Please select a date after today.',
)
```

**Example 4: User doesn't have consistent income yet**
```dart
SavingsSuggestionResult(
  success: true,
  suggestedMonthlySavings: 0.0,
  targetAmount: 5000.0,
  timelineMonths: 0,
  targetDate: DateTime(2027, 4, 2),
  averageMonthlyIncome: 0.0,
  analysis: 'Cannot provide suggestion without consistent income data',
  isFeasible: false,
  feasibilityMessage: 'No salary income records found. Please record your monthly salary in the transaction page.',
)
```

---

## Real-World Calculation Examples

### Example Scenario 1: Simple monthly savings goal
```
User Profile:
- Monthly Salary: RM 3,500 (consistent for 4 months)
- Monthly Expenses: RM 2,500 (average of last 3 months)
- Monthly Net Savings Capacity: RM 1,000

Goal:
- Target Amount: RM 5,000
- Target Date: 12 months from now (April 2027)

Calculation:
Timeline = 12 months
Monthly Savings Needed = RM 5,000 ÷ 12 months = RM 416.67/month

Feasibility Check:
- Needed: RM 416.67/month
- Available: RM 1,000/month
- Result: ✓ FEASIBLE (416.67 ≤ 1,000)

Message:
"Based on your consistent monthly income of RM3,500.00, you need to save RM416.67 per month 
to reach your goal of RM5,000.00 by Apr 2027. You can save this amount comfortably with 
your current income and expenses."
```

### Example Scenario 2: Challenging goal (requires extension)
```
User Profile:
- Monthly Salary: RM 3,000 (consistent for 3 months)
- Monthly Expenses: RM 2,900 (average of last 3 months)
- Monthly Net Savings Capacity: RM 100

Goal:
- Target Amount: RM 5,000
- Target Date: 6 months from now (October 2026)

Calculation:
Timeline = 6 months
Monthly Savings Needed = RM 5,000 ÷ 6 months = RM 833.33/month

Feasibility Check:
- Needed: RM 833.33/month
- Available: RM 100/month
- Result: ❌ NOT FEASIBLE (833.33 > 100)

Recommendation:
To reach RM 5,000 with only RM 100/month available, you would need:
Required Timeline = RM 5,000 ÷ RM 100 = 50 months

Message:
"This goal is very challenging. You need to save RM833.33/month, but your net monthly 
savings is only RM100.00. Consider:
1. Extending timeline to 50 months (4+ years)
2. Reducing your goal to RM600 (achievable in 6 months)
3. Increasing your income or reducing expenses"
```

### Example Scenario 3: User with only 2 months of records
```
User Profile:
- Salary Records: 2 months only (2026-02, 2026-03)
- Average Monthly Salary: RM 3,500

Result: ❌ CANNOT PROVIDE SUGGESTION
- hasConsistentIncome = false
- consistentMonthsCount = 2
- message = "You need to record at least 3 months of consistent salary income..."

UI Action: Show prompt to record more salary transactions
```

---

## Database Schema Reference

### Transaction Table Structure
```sql
CREATE TABLE public."Transaction" (
  "transactionId" character varying NOT NULL,
  "userId" character varying NOT NULL,
  "accountId" character varying NOT NULL,
  "categoryId" character varying NOT NULL,
  "ledgerId" character varying NULL,
  amount float64 NOT NULL,
  type character varying,                   -- 'income' or 'expense'
  date date,                                -- Transaction date (YYYY-MM-DD)
  "transactionNote" text NULL,
  "transactionImg" text NULL,
  "createdAt" timestamp with time zone,
  "updatedAt" timestamp with time zone,
  CONSTRAINT Transaction_pkey PRIMARY KEY ("transactionId"),
  CONSTRAINT Transaction_userId_fkey FOREIGN KEY ("userId") 
    REFERENCES "User" ("userId") ON UPDATE CASCADE ON DELETE CASCADE
);
```

### Category Table Structure
```sql
CREATE TABLE public."Category" (
  "categoryId" character varying NOT NULL,
  name character varying NOT NULL,          -- 'Salary', 'Bonus', 'Groceries'...
  icon character varying NULL,
  type character varying NOT NULL,          -- 'income' or 'expense'
  "userId" character varying NULL,          -- User who owns this category
  "spendingSummaryId" character varying NULL,
  "incomeSummaryId" character varying NULL,
  keywords text NULL,
  CONSTRAINT Category_pkey PRIMARY KEY ("categoryId"),
  CONSTRAINT Category_userId_fkey FOREIGN KEY ("userId") 
    REFERENCES "User" ("userId") ON UPDATE CASCADE ON DELETE CASCADE
);
```

---

## Month Grouping Logic

### How months are identified and grouped

**Date Format**: YYYY-MM-DD (e.g., 2026-02-15)
**Grouped As**: YYYY-MM (e.g., 2026-02)

**Example Transaction List**:
```
Date          | Amount | Category | Type   | Month (grouped)
2026-01-05    | 3500   | Salary   | income | 2026-01
2026-01-15    | 500    | Bonus    | income | 2026-01  (same month, added)
2026-02-01    | 5000   | Salary   | income | 2026-02
2026-03-05    | 3500   | Salary   | income | 2026-03
2026-04-01    | 3500   | Salary   | income | 2026-04 (4 consecutive months)
```

**Grouping Result**:
```dart
{
  '2026-01': 4000.0,    // 3500 + 500
  '2026-02': 5000.0,
  '2026-03': 3500.0,
  '2026-04': 3500.0,
}

averageMonthlyIncome = (4000 + 5000 + 3500 + 3500) / 4 = 4000.0
consistentMonthsCount = 4  // 2026-01 to 2026-04 are consecutive
```

---

## Consecutive Month Detection

### Algorithm
```
Input: ['2026-01', '2026-02', '2026-03', '2026-05', '2026-06']
       (Note: 2026-04 is missing, breaking sequence)

Process:
1. Start with first month: [2026-01]
2. Check 2026-02: Previous + 1 month? YES → Add to sequence → [2026-01, 2026-02]
3. Check 2026-03: Previous + 1 month? YES → Add to sequence → [2026-01, 2026-02, 2026-03]
4. Check 2026-05: Previous + 1 month? NO (gap of 2 months) → Sequence broken
   - Current sequence length: 3
   - Longest so far: 3
   - Reset to: [2026-05]
5. Check 2026-06: Previous + 1 month? YES → [2026-05, 2026-06]
6. End of list
   - Current sequence length: 2
   - Longest: 3 (from 2026-01 to 2026-03)

Result: [2026-01, 2026-02, 2026-03]
consistentMonthsCount = 3
```

### Edge Cases
```
1. Single month with transactions
   Input: ['2026-02']
   Result: [2026-02]
   Count: 1 (< 3, NOT FEASIBLE)

2. All consecutive months
   Input: ['2025-12', '2026-01', '2026-02', '2026-03', '2026-04']
   Result: [2025-12, 2026-01, 2026-02, 2026-03, 2026-04]
   Count: 5 (✓ FEASIBLE)

3. Multiple breaks
   Input: ['2025-11', '2025-12', '2026-02', '2026-03', '2026-04']
   Result: [2026-02, 2026-03, 2026-04]
   Count: 3 (✓ FEASIBLE)

4. No transactions
   Input: []
   Result: []
   Count: 0 (NOT FEASIBLE)
```

---

## Expense Averaging Logic

### Last 3 Months of Expenses
```
Current Date: 2026-04-02
Query Range: 2026-01-01 to 2026-04-02

Transactions with type='expense':
Date       | Amount (absolute) | Month
2026-01-05 | 2400              | 2026-01
2026-01-15 | 100               | 2026-01
2026-02-10 | 2600              | 2026-02
2026-03-05 | 2300              | 2026-03
2026-03-20 | 200               | 2026-03
2026-04-01 | 500               | 2026-04

Monthly Totals:
2026-01: 2400 + 100 = 2500
2026-02: 2600
2026-03: 2300 + 200 = 2500
2026-04: 500 (partial month, only 2 days)

Average Expenses = (2500 + 2600 + 2500) / 3 = 2533.33
(Note: 2026-04 excluded as it's incomplete)
```

---

## Timeline Calculation

### Formula
```
Timeline (months) = (targetDate.year - today.year) × 12 + (targetDate.month - today.month)
```

### Examples
```
Today: 2026-04-02

Target: 2026-05-15
Timeline = (2026 - 2026) × 12 + (5 - 4) = 0 + 1 = 1 month

Target: 2027-04-02
Timeline = (2027 - 2026) × 12 + (4 - 4) = 12 + 0 = 12 months

Target: 2026-03-15
Timeline = (2026 - 2026) × 12 + (3 - 4) = 0 - 1 = -1 month (INVALID - past date)

Target: 2028-12-31
Timeline = (2028 - 2026) × 12 + (12 - 4) = 24 + 8 = 32 months
```

---

## UI Decision Tree

```
START: User opens Savings Goal Screen
│
├─1─> Call validateConsistentIncome(userId)
│
├─ Yes: hasConsistentIncome = true
│   │
│   ├─ Show: "✓ Consistent Income: RM{average}/month"
│   ├─ Show: "Based on {months} months of salary records"
│   ├─ Enable: Goal Input Fields
│   │
│   └─ User enters Target Amount & Target Date
│       │
│       ├─2─> Call generateSavingsSuggestion()
│       │
│       ├─ Success: Show Suggestion Dialog
│       │  ├─ Display: "RM{suggestedMonthlySavings}/month"
│       │  ├─ Display: {analysis} text
│       │  ├─ If isFeasible = true:
│       │  │  └─ Show: "✓ {feasibilityMessage}"
│       │  └─ If isFeasible = false:
│       │     └─ Show: "⚠️ {feasibilityMessage}"
│       │
│       └─ Error: Show error message
│
└─ No: hasConsistentIncome = false
    │
    ├─ Show: "❌ {message}" (e.g., "No salary records found")
    ├─ Disable: Goal Input Fields
    ├─ Show: "Record Salary" Button
    │
    └─ User clicks "Record Salary"
        │
        └─ Navigate to Add Transaction
           ├─ categoryId = salaryCategoryId
           ├─ type = 'income'
           └─ Display = Salary Income Entry Form
```

---

## API Integration Notes

### Time Complexity
- `validateConsistentIncome()`: O(n + m) where n = months, m = transactions
- `generateSavingsSuggestion()`: O(n + m + p) where p = expense transactions
- Overall: O(n + m + p) ≈ Linear in number of transactions

### Database Queries
1. Find salary category: ~instant (indexed by userId + type)
2. Fetch salary transactions (12 months): ~fast (indexed by categoryId + date)
3. Fetch expense transactions (3 months): ~fast (indexed by type + date)

### Expected Response Times
- validateConsistentIncome(): 500-800ms (depends on transaction count)
- generateSavingsSuggestion(): 800-1200ms (includes income validation)

### Error Handling
```dart
try {
  final result = await IntelligentSavingsGoalAssistant.validateConsistentIncome(userId);
  if (!result.success) {
    print("Error: ${result.message}");
    // Fallback: Show generic error message
  }
} catch (e) {
  print("Exception: $e");
  // Network error, Supabase error, etc.
}
```

