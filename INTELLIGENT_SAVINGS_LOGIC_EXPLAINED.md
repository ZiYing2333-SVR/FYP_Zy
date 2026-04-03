# Intelligent Savings Goal Assistant - Complete Logic Explanation

## 🧠 How It Becomes "Intelligent"

The Intelligent Savings Goal Assistant is "intelligent" because it:

1. **Validates Real User Data** - Uses actual transaction history to determine income reliability
2. **Predicts Future Spending** - Uses Forecast API (Prophet ML model) to predict future expense patterns
3. **Multi-Stage Feasibility Assessment** - Not just yes/no, but provides three levels: ACHIEVABLE, CHALLENGING, IMPOSSIBLE
4. **Context-Aware Advice** - Gives tailored recommendations based on the specific scenario
5. **Risk Detection** - Identifies when the 20% savings target becomes at risk due to forecast expenses

---

## 📊 System Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                   INTELLIGENT SAVINGS GOAL ASSISTANT                │
└─────────────────────────────────────────────────────────────────────┘
                                  │
                    ┌─────────────┼─────────────┐
                    │             │             │
              ┌─────▼──────┐ ┌───▼────────┐ ┌─▼──────────────┐
              │   INCOME    │ │  EXPENSE   │ │   FORECAST     │
              │ VALIDATION  │ │ ANALYSIS   │ │   API (Prophet)│
              └─────┬──────┘ └───┬────────┘ └─┬──────────────┘
                    │             │            │
                    │             │            │
              ┌─────▼──────────────▼────────────▼────────┐
              │   FEASIBILITY ASSESSMENT ENGINE          │
              │  (20% Savings / 80% Expenses Rule)      │
              └─────┬──────────────────────────────────┘
                    │
        ┌───────────┼───────────┐
        │           │           │
   ┌────▼────┐ ┌───▼────┐ ┌───▼─────┐
   │ACHIEVABLE│ │CHALLEN-│ │IMPOSSIBLE│
   │          │ │GING    │ │          │
   └────┬─────┘ └───┬────┘ └────┬────┘
        │           │           │
        │           │           │
   ┌────▼───────────▼───────────▼──┐
   │  PERSONALIZED ADVICE GENERATOR │
   │  (Category-based suggestions)  │
   └────────────────────────────────┘
```

---

## 🔍 PHASE 1: INCOME VALIDATION (Smart Income Detection)

### Purpose
Determine if the user has **consistent, reliable income** to build savings goals on.

### The 4-Step Smart Income Detection Process

#### **Step 1️⃣: Find Income Transactions (Past 12 Months)**
```sql
Query: SELECT categoryId, amount, date FROM Transaction 
       WHERE type = 'income' AND date >= (TODAY - 365 days)
```
- Retrieves ALL income transactions from the past 12 months
- Filters by `type == 'income'`
- Gets: categoryId, amount, date

**Example Data:**
```
categoryId    | amount  | date       | type
──────────────┼─────────┼────────────┼──────
cat_salary_1  | 5000.00 | 2025-01-15 | income
cat_bonus_1   |  800.00 | 2025-01-20 | income
cat_salary_1  | 5000.00 | 2025-02-10 | income
cat_salary_1  | 5000.00 | 2025-03-15 | income
(... more records)
```

#### **Step 2️⃣: Extract Distinct Category IDs**
```
From the income transactions above:
Distinct Categories: [cat_salary_1, cat_bonus_1]
```

#### **Step 3️⃣: Find Salary Category (Case-Insensitive)**
```sql
Query: SELECT categoryId, name FROM Category 
       WHERE categoryId IN (cat_salary_1, cat_bonus_1)
       AND name ILIKE '%salary%'
```

**Result:**
```
categoryId    | name
──────────────┼────────────
cat_salary_1  | Monthly Salary
```

**Why ILIKE '%salary%'?**
- Case-insensitive match (ilike vs like)
- Pattern matching: catches "Salary", "SALARY", "Monthly Salary", "Bonus Salary", etc.
- Bonus might be labeled separately

#### **Step 4️⃣: Validate 3+ Consecutive Months**
```
Group salary transactions by month:

Month    | Total Income
─────────┼─────────────
2025-01  | 5000
2025-02  | 5000
2025-03  | 5000
2025-04  | 5000
2025-05  | 5000

Consecutive sequence: [2025-01, 2025-02, 2025-03, 2025-04, 2025-05]
Count: 5 months ✅ (Exceeds minimum of 3)
Average: RM5000/month
```

**Minimum Requirement: 3+ Consecutive Months**

### Output: IncomeValidationResult
```
{
  success: true,
  hasConsistentIncome: true,
  averageMonthlyIncome: 5000.00,
  salaryMonths: ["2025-01", "2025-02", "2025-03", "2025-04", "2025-05"],
  consistentMonthsCount: 5,
  salaryCategoryId: "cat_salary_1",
  message: "Great! You have 5 months of consistent income (RM5,000/month)."
}
```

---

## 📈 PHASE 2: EXPENSE FORECASTING (Predictive Analysis)

### Purpose
Predict future expense patterns to assess if the user's budget can support the savings goal.

### The Expense Forecasting Process

#### **Step 1️⃣: Collect Historical Expense Data**
```sql
Query: SELECT amount, date FROM Transaction 
       WHERE type = 'expense' AND date >= (TODAY - 365 days)
```

**Example Dataset (12 months of expense history):**
```
Month    | Total Expenses
─────────┼───────────────
2025-01  | 3500
2025-02  | 3600
2025-03  | 3450
2025-04  | 3700
2025-05  | 3550
2025-06  | 4200  ⬆️ (Higher spending)
2025-07  | 4100
2025-08  | 3800
2025-09  | 3600
2025-10  | 3650
2025-11  | 3700
2025-12  | 4500  ⬆️ (Holiday spending)
```

#### **Step 2️⃣: Send to Forecast API (Prophet)**
```
POST /v2/forecast
{
  "data": [
    {"date": "2025-01", "value": 3500},
    {"date": "2025-02", "value": 3600},
    ... (all 12 months)
  ],
  "forecast_periods": 3,
  "confidence_interval": 0.95
}
```

**Forecast API Used:** `forecastapi.com/v2/forecast`
- Uses **Facebook Prophet** (time-series forecasting ML model)
- Detects trends, seasonality, holidays
- Returns predicted values for next N periods

#### **Step 3️⃣: Receive Forecast Results**
```
Predicted Expenses for Next 3 Months:
Month    | Forecasted Expense
─────────┼───────────────────
2026-01  | 3800  (baseline)
2026-02  | 3900  (slight increase)
2026-03  | 4200  (seasonal increase)

Current Average: 3731.25/month
```

### Output: ForecastResult
```
{
  success: true,
  forecast: [3800, 3900, 4200],  // Next 3 months predicted
  confidence: "high",
  trend: "slight_upward"
}
```

---

## ⚖️ PHASE 3: FEASIBILITY ASSESSMENT (The Intelligence Core)

### The 20/80 Rule

**Budget Formula:**
```
Monthly Income = 100%
├─ Savings Target = 20% ← Can be adjusted based on goal
└─ Expenses = 80%  ← Should not exceed this
```

### Key Decision Logic

Let's say:
- **Monthly Income:** RM5,000
- **Target Savings/Month:** RM1,200 (24% - user wants to reach RM14,400 in 12 months)
- **Forecasted Expenses:** RM4,000 (80% of income = exactly at limit)

### Three-Stage Feasibility System

---

## 🟢 STAGE 1: ACHIEVABLE

**Conditions:**
```
Planned Savings ≤ 20% (recommended rate)
AND
Forecasted Expenses ≤ 80%
```

**Example:**
```
Monthly Income:         RM5,000
Target Savings:         RM900 (18% ✅ within 20%)
Forecasted Expenses:    RM3,800 (76% ✅ within 80%)
───────────────────────────────
Available for Savings:  RM1,200
```

**Analysis:**
✅ **VERDICT: ACHIEVABLE**
- You only need to save 18% of your income (RM900/month)
- Forecast predicts expenses at 76% of income (well within limit)
- You have RM1,200 available for savings
- Comfortable margin for unexpected expenses

**Advice Given:**
```
"Your goal is comfortably achievable! 
You need to save RM900/month (18% of income), 
which is well below the recommended 20% rate.
Forecasted expenses: RM3,800/month (76% of income)."
```

**Suitable Recommendations:**
- Continue current spending patterns
- Look for small optimizations only
- Build emergency fund with surplus
- Consider accelerating the timeline

---

## 🟡 STAGE 2: CHALLENGING (Type A)

**Conditions:**
```
Planned Savings > 20% (exceeds recommended)
BUT
Forecasted Expenses < 80% (still manageable)
```

**Example:**
```
Monthly Income:         RM5,000
Target Savings:         RM1,500 (30% ✅ above 20% but possible)
Forecasted Expenses:    RM3,200 (64% ✅ within 80%)
───────────────────────────────
Available for Savings:  RM1,800
```

**Analysis:**
⚠️ **VERDICT: CHALLENGING (but possible)**
- You need to save 30% of your income (exceeds 20% recommendation)
- Forecast shows expenses at 64% (good news!)
- You have RM1,800 capacity, but only need RM1,500
- Tight but achievable if you stick to budget

**Advice Given:**
```
"This goal is CHALLENGING but achievable!
You need to save 30% of income (above the 20% recommendation),
but your forecasted expenses are only 64% of income,
leaving you with RM1,800/month capacity.

Recommendation: You CAN achieve this, but:
- Monitor expenses closely
- Use the extra RM300/month as a safety buffer
- Look for ways to reduce the one-time unexpected costs"
```

**Suitable Recommendations:**
- Identify discretionary spending to cut
- Build a buffer for unexpected costs
- Track expenses weekly (not just monthly)
- Reduce by 5-10% to be safe

---

## 🟡 STAGE 2: CHALLENGING (Type B)

**Conditions:**
```
Planned Savings ≤ 20% (within recommended)
BUT
Forecasted Expenses > 80% (risk of overspending)
```

**Example:**
```
Monthly Income:         RM5,000
Target Savings:         RM950 (19% ✅ within 20%)
Forecasted Expenses:    RM4,100 (82% ❌ exceeds 80%)
───────────────────────────────
Available for Savings:  RM900
```

**Analysis:**
⚠️ **VERDICT: CHALLENGING (expenses at risk)**
- You need to save 19% of income (within recommended 20%)
- BUT forecast predicts expenses at 82% (2% over limit!)
- Available capacity is only RM900, need RM950
- Expense forecast is the risk factor

**Advice Given:**
```
"This goal is CHALLENGING due to rising expenses!
You need to save 19% (reasonable target),
but your forecasted expenses are 82% of income (exceeds 80% limit).

This means you need to CUT expenses by at least RM100/month
to make room for your RM950 monthly savings.

Looking at your highest expense categories:
1. Food & Groceries: RM1,200 → Cut by 10% (save RM120)
2. Transport: RM800 → Cut by 5% (save RM40)
3. Entertainment: RM600 → Cut by 20% (save RM120)"
```

**Suitable Recommendations:**
- **Identify highest spending categories**
- **Show category-specific cuts needed**
- Prioritize cutting discretionary categories first
- If cuts impossible: extend timeline or lower goal

---

## 🟡 STAGE 2: CHALLENGING (Type C)

**Conditions:**
```
Planned Savings > 20% (exceeds recommended)
AND
Forecasted Expenses < 80% (manageable)
BUT ONE is pushing the limit
```

**Example:**
```
Monthly Income:         RM5,000
Target Savings:         RM1,200 (24% above 20%)
Forecasted Expenses:    RM3,500 (70% within limit)
───────────────────────────────
Available for Savings:  RM1,500
```

**Analysis:**
⚠️ **VERDICT: CHALLENGING (tight but doable)**
- Need to save 24% (4% above recommendation)
- Expenses at 70% (10% buffer - good!)
- Available RM1,500 > Required RM1,200
- The 24% savings rate itself is the challenge

**Advice Given:**
```
"Your goal is CHALLENGING because it requires 24% savings
(4% above the recommended 20% rate),
but you CAN achieve it!

Why it's possible:
- Your expenses are only 70% of income (good!)
- You have RM1,500 available, but only need RM1,200
- You have a RM300/month buffer

How to succeed:
- Maintain strict expense control (70% target)
- Treat the extra RM300 as untouchable emergency fund
- Review spending bi-weekly for the first 3 months"
```

**Suitable Recommendations:**
- Extra monitoring required
- Build emergency fund quickly
- Automate savings (pay yourself first)
- Review after 1 month to adjust if needed

---

## 🔴 STAGE 3: IMPOSSIBLE

**Conditions:**
```
Planned Savings > 70% of monthly income
OR
Planned Savings > Available Capacity
AND there's no way to fix it with cuts
```

**Example 1: Unrealistic Savings Rate**
```
Monthly Income:         RM5,000
Target Savings:         RM4,000 (80% of income!)
Forecasted Expenses:    RM3,500 (70%)
───────────────────────────────
Available for Savings:  RM1,500 (only)
```

**Analysis:**
❌ **VERDICT: IMPOSSIBLE**
- Goal requires saving 80% of income (impossible standard)
- Even if you cut expenses to bare minimum, you can only save RM1,500
- Gap: RM4,000 - RM1,500 = RM2,500 shortfall
- No way to bridge this without major income increase

**Advice Given:**
```
"This goal is IMPOSSIBLE with your current situation.
You're trying to save RM4,000/month (80% of income),
but you can only afford RM1,500/month even with minimum spending.

You have 3 options:

Option 1: REDUCE GOAL AMOUNT
Current: RM4,000/month → RM1,500/month (feasible)
Or set goal: RM6,000 target instead of current target

Option 2: INCREASE TIMELINE
Current Timeline: 12 months → 32 months (at RM1,500/month)
This gives you RM48,000 instead of current goal

Option 3: INCREASE INCOME
Need increase: RM2,500/month more income
(Side gig, freelance work, salary negotiation)"
```

**Suitable Recommendations:**
- Help user choose: Goal ↓, Timeline ↑, or Income ↑
- Break into phases if possible
- Show what's achievable with current resources

---

## Example 2: Expenses Exceed Income
```
Monthly Income:         RM5,000
Target Savings:         RM1,000
Forecasted Expenses:    RM4,500 (90% too high!)
───────────────────────────────
Available for Savings:  RM500 (not enough)
```

**Advice Given:**
```
"This goal is IMPOSSIBLE right now!

Critical Issue: Your forecasted expenses (RM4,500)
exceed the safe spending limit by RM500/month.

You're spending 90% of income (should be 80% max).

IMMEDIATE ACTIONS REQUIRED:

1. Cut expenses by at least RM500/month
   - Food: Cut RM100
   - Transport: Cut RM150
   - Entertainment: Cut RM150
   - Subscriptions: Cut RM100

2. After expense cuts: RM4,000 expenses
   Available for savings: RM1,000 ✅ (Matches goal!)

3. If you can't cut that much:
   - Reduce savings goal to RM500/month
   - OR increase income by RM500"
```

---

## 📋 CATEGORY-BASED EXPENSE ADVICE

When the system identifies that expenses need to be cut, it provides **category-specific recommendations**.

### How It Works

#### **Step 1: Identify Spending by Category**
```sql
Query: SELECT categoryId, SUM(amount) as total 
       FROM Transaction 
       WHERE type = 'expense' AND date >= (TODAY - 90 days)
       GROUP BY categoryId
       ORDER BY total DESC
```

**Result:**
```
Category        | Total (Last 90 days) | Monthly Avg | % of Budget
────────────────┼─────────────────────┼─────────────┼────────────
Food & Dining   | 3600                | 1200.00     | 24%
Transport       | 2400                | 800.00      | 16%
Entertainment   | 1800                | 600.00      | 12%
Bills & Utilities| 1500                | 500.00      | 10%
Shopping        | 1200                | 400.00      | 8%
Other           | 1500                | 500.00      | 10%
Total           | 12000               | 4000.00     | 80% ✅
```

#### **Step 2: Calculate Required Cuts**
If you need to reduce expenses by RM500/month:

```
Category         | Current | Cut % | Cut Amount | New Amount
─────────────────┼─────────┼───────┼────────────┼───────────
Food & Dining    | 1200    | 10%   | -120       | 1080
Transport        | 800     | 15%   | -120       | 680
Entertainment    | 600     | 20%   | -120       | 480
Bills & Utilities | 500    | 40%   | -140       | 360
Total Cut        |         |       | -500       |
```

#### **Step 3: Provide Category-Specific Advice**
```
"To achieve your savings goal, reduce expenses by RM500/month:

🍽️ FOOD & DINING (Cut RM120)
   • Cook at home more often (currently: 1200/month)
   • Set grocery budget: RM900/month
   • Reduce eating out: 2-3 times/week instead of daily

🚗 TRANSPORT (Cut RM120)
   • Carpool 2 days/week
   • Use public transport on weekends
   • Current: RM800/month → Target: RM680/month

🎬 ENTERTAINMENT (Cut RM120)
   • Cancel 1 streaming subscription (RM50)
   • Reduce outings to 2x/month (RM70)
   • Current: RM600/month → Target: RM480/month

⚡ BILLS & UTILITIES (Cut RM140)
   • Switch to cheaper phone plan: -RM50
   • Reduce energy use (AC set to 25°C): -RM30
   • Negotiate internet: -RM60
   • Current: RM500/month → Target: RM360/month"
```

---

## 🎯 Complete Decision Tree

```
START: User Sets Goal (Amount, Timeline)
  │
  ├─────────────────────────────────────────────┐
  │                                             │
  ▼                                             │
Check: Has user 3+ months ────→ NO ──→ Request more income data
consistent income?            │      (Need 3 months historical data)
  │                          │
  │ YES                       │
  │                          │
  ▼                          │
Get: Average Monthly Income  │
(e.g., RM5,000)              │
  │                          │
  ├─────────────────────────────────────────────┤
  │                                             │
  ▼                                             │
Calculate: Required Monthly Savings             │
(Goal ÷ Timeline)                               │
(e.g., RM1,000/month)                           │
  │                                             │
  ├─────────────────────────────────────────────┤
  │                                             │
  ▼                                             │
Get: Expense Forecast for Next 3 Months         │
(Using Prophet API)                             │
(e.g., RM3,800, RM3,900, RM4,000)              │
  │                                             │
  ├─────────────────────────────────────────────┤
  │                                             │
  ▼                                             │
Calculate: Savings Rate & Expense Ratio         │
  • Savings %: 1000 ÷ 5000 = 20%                │
  • Expense %: 3900 ÷ 5000 = 78%                │
  │                                             │
  ├─────────────────────────────────────────────┤
  │                                             │
  ▼                                             │
Feasibility Assessment:                         │
  │                                             │
  ├─ Savings ≤ 20% AND Expenses ≤ 80%           │
  │    └─→ 🟢 ACHIEVABLE                         │
  │        Advice: Continue, optimize           │
  │                                             │
  ├─ Savings > 20% AND Expenses < 80%           │
  │    └─→ 🟡 CHALLENGING (A)                    │
  │        Advice: Monitor closely, doable      │
  │                                             │
  ├─ Savings ≤ 20% AND Expenses > 80%           │
  │    └─→ 🟡 CHALLENGING (B)                    │
  │        Advice: Cut expenses first           │
  │                                             │
  ├─ Savings > 20% AND Expenses ≥ 80% (tight)   │
  │    └─→ 🟡 CHALLENGING (C)                    │
  │        Advice: Tight but doable             │
  │                                             │
  └─ Savings > 70% OR Unfeasible                │
       └─→ 🔴 IMPOSSIBLE                         │
           Advice: Change goal/timeline/income
```

---

## 💡 Why This System Is Intelligent

### 1. **Data-Driven Decision Making**
- Not just theoretical budgets
- Based on actual transaction history
- Validates income before trusting it

### 2. **Predictive, Not Reactive**
- Uses Forecast API to predict future expenses
- Shows risks before they happen
- Gives users time to adjust

### 3. **Nuanced Assessment**
- Not just "possible" or "impossible"
- Distinguishes between ACHIEVABLE and CHALLENGING
- 3 types of CHALLENGING with different strategies

### 4. **Personalized Recommendations**
- Each stage gets specific, actionable advice
- Category-level suggestions
- Shows exactly what to cut and how much

### 5. **Confidence & Risk Awareness**
- Shows margin of safety
- Alerts when 20% savings target at risk
- Provides buffer calculations

### 6. **Flexible Problem-Solving**
- Not one solution for all
- Offers multiple options (reduce goal, extend timeline, increase income)
- Let's user choose their path

---

## 🔧 Technical Implementation Summary

### Database Queries Used

```dart
// 1. Get income transactions (past 12 months)
SELECT categoryId, amount, date FROM Transaction
WHERE type = 'income' AND date >= DATE_SUB(NOW(), INTERVAL 12 MONTH)

// 2. Get distinct income categories
SELECT DISTINCT categoryId FROM Transaction WHERE type = 'income'

// 3. Find salary category
SELECT categoryId, name FROM Category
WHERE categoryId IN (distinct_ids) AND name ILIKE '%salary%'

// 4. Get expense transactions (past 90 days)
SELECT amount, date FROM Transaction
WHERE type = 'expense' AND date >= DATE_SUB(NOW(), INTERVAL 3 MONTH)

// 5. Get spending by category (for advice)
SELECT categoryId, category_name, SUM(amount) as total
FROM Transaction GROUP BY categoryId
ORDER BY total DESC

// 6. Check for consecutive months
GROUP BY YEAR-MONTH, CHECK 3+ consecutive months
```

### External API Call

```http
POST https://forecastapi.com/v2/forecast
Content-Type: application/json
Authorization: Bearer {API_KEY}

{
  "data": [
    {"date": "2025-01", "value": 3500},
    {"date": "2025-02", "value": 3600},
    ... (12 months historical data)
  ],
  "forecast_periods": 3,
  "model": "prophet",
  "confidence_interval": 0.95
}

Response: 
{
  "forecast": [3800, 3900, 4200],
  "confidence_upper": [4200, 4300, 4600],
  "confidence_lower": [3400, 3500, 3800]
}
```

---

## 📈 Example: Complete Workflow

A user wants to save RM14,400 in 12 months for a vacation.

### **Input:**
- Goal Amount: RM14,400
- Timeline: 12 months
- Target Date: April 3, 2027

### **System Processing:**

**Phase 1: Income Validation**
```
✅ Found consistent income
   • 8 months of salary records
   • Average monthly: RM5,000
   • Status: READY FOR ANALYSIS
```

**Phase 2: Expense Forecasting**
```
✅ Historical expenses (past 12 months): RM3,500 - RM4,500
✅ Forecast API prediction (next 3 months): RM3,800, RM3,900, RM4,000
✅ Average forecast: RM3,900/month
   Expense Ratio: 78% of income (within safe limit)
```

**Phase 3: Feasibility Assessment**
```
Monthly Income:           RM5,000
Required Monthly Savings: RM1,200 (14,400 ÷ 12)
Savings Rate:            24% (exceeds 20% recommendation)
Forecasted Expenses:     RM3,900 (78% of income)

Assessment:              🟡 CHALLENGING (Type A)

Projected Savings Capacity: RM1,100/month
Shortfall:                  -RM100/month when using forecast


Wait, let me recalculate...
Income:                   RM5,000
Expenses:                 RM3,900
Actual Capacity:          RM1,100/month

But Goal Requires:        RM1,200/month
────────────────────────────────
Your forecast shows you can only save RM1,100/month,
but your goal requires RM1,200/month.
```

**Final Verdict & Advice:**
```
🟡 GOAL IS CHALLENGING

Your goal requires saving RM1,200/month (24% of income),
but based on expense forecasts, you'll likely have RM1,100/month available.

Options:

1. ADJUST GOAL DOWN
   Instead of RM14,400, save RM13,200 (RM1,100 × 12 months)
   Your new vacuum will be slightly smaller budget 😄

2. EXTEND TIMELINE
   Keep the RM14,400 goal, but extend to 13 months
   This reduces monthly requirement to RM1,107/month (achievable!)

3. CUT EXPENSES BY RM100/MONTH
   Looking at your spending:
   • Food & Dining: RM1,200 → Cut to RM1,100 (skip 2-3 restaurant visits)
   • Transport: RM800 → Cut to RM750 (carpool 1 day/week)
   
   These small cuts give you the extra RM100 needed!

RECOMMENDATION: 
Cut expenses by RM100 (easiest!) + extend timeline by 1 month
This gives you: RM1,200/month × 13 months = RM15,600 ✅
```

---

## Summary: The Intelligence Loop

1. **Validate** → Check if income is reliable (3+ months)
2. **Forecast** → Predict future expenses using Prophet
3. **Calculate** → Determine savings rate and expense ratio
4. **Assess** → Compare against 20/80 rule
5. **Categorize** → Determine ACHIEVABLE/CHALLENGING/IMPOSSIBLE
6. **Advise** → Provide category-specific, actionable recommendations
7. **Iterate** → User can adjust and re-run the analysis

This creates a feedback loop where users can understand not just if their goal is possible, but **exactly why** and **how to fix it**.

