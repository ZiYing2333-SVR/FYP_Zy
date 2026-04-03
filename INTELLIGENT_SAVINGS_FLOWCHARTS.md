# Intelligent Savings Goal Assistant - Visual Flowcharts

## Flowchart 1: Complete Decision Flow

```
                        ┌─────────────────────────────┐
                        │  START: User Sets Goal      │
                        │  Amount: RM14,400           │
                        │  Timeline: 12 months        │
                        └──────────────┬──────────────┘
                                       │
                    ┌──────────────────▼──────────────────┐
                    │  PHASE 1: INCOME VALIDATION         │
                    │  (Smart Income Detection)           │
                    └──────────────────┬──────────────────┘
                                       │
        ┌──────────────────────────────▼──────────────────────────────┐
        │  Step 1️⃣: Query Transaction (type='income', past 12 months) │
        │  ✅ Found 47 income transactions from 2024-2026             │
        └──────────────────────────────┬──────────────────────────────┘
                                       │
        ┌──────────────────────────────▼──────────────────────────────┐
        │  Step 2️⃣: Extract Distinct Category IDs                    │
        │  ✅ Distinct categories: {cat_salary_1, cat_bonus_1}       │
        └──────────────────────────────┬──────────────────────────────┘
                                       │
        ┌──────────────────────────────▼──────────────────────────────┐
        │  Step 3️⃣: Find Salary Category (ILIKE '%salary%')          │
        │  ✅ Found: "Monthly Salary" (cat_salary_1)                 │
        └──────────────────────────────┬──────────────────────────────┘
                                       │
        ┌──────────────────────────────▼──────────────────────────────┐
        │  Step 4️⃣: Validate 3+ Consecutive Months                   │
        │  ✅ Found 8 consecutive months (May 2025 - Dec 2025)       │
        │  ✅ Average: RM5,000/month                                  │
        └──────────────────────────────┬──────────────────────────────┘
                                       │
                    ┌──────────────────▼──────────────────┐
                    │  INCOME VALIDATION: ✅ SUCCESS       │
                    │  Monthly Income: RM5,000            │
                    └──────────────────┬──────────────────┘
                                       │
                    ┌──────────────────▼──────────────────┐
                    │  PHASE 2: EXPENSE FORECASTING      │
                    │  (Predictive Analysis)              │
                    └──────────────────┬──────────────────┘
                                       │
        ┌──────────────────────────────▼──────────────────────────────┐
        │  Step 1️⃣: Collect Historical Expenses (past 12 months)     │
        │  📊 Data: 12 months × avg RM4,000/month                    │
        │     Jan: 3500, Feb: 3600, Mar: 3450, ... Dec: 4500        │
        └──────────────────────────────┬──────────────────────────────┘
                                       │
        ┌──────────────────────────────▼──────────────────────────────┐
        │  Step 2️⃣: Send to Forecast API (Prophet ML Model)          │
        │  📡 POST /v2/forecast                                       │
        │     Confidence Interval: 95%                                │
        │     Periods: 3 months                                       │
        └──────────────────────────────┬──────────────────────────────┘
                                       │
        ┌──────────────────────────────▼──────────────────────────────┐
        │  Step 3️⃣: Receive Predicted Expenses                       │
        │  ✅ Jan 2026: RM3,800                                       │
        │  ✅ Feb 2026: RM3,900                                       │
        │  ✅ Mar 2026: RM4,000                                       │
        │  Average Forecast: RM3,900/month                            │
        └──────────────────────────────┬──────────────────────────────┘
                                       │
                    ┌──────────────────▼──────────────────┐
                    │  EXPENSE FORECAST: ✅ SUCCESS       │
                    │  Avg Predicted: RM3,900/month      │
                    └──────────────────┬──────────────────┘
                                       │
                    ┌──────────────────▼──────────────────┐
                    │  PHASE 3: FEASIBILITY ASSESSMENT    │
                    │  (20% Savings / 80% Expenses Rule) │
                    └──────────────────┬──────────────────┘
                                       │
        ┌──────────────────────────────▼──────────────────────────────┐
        │  CALCULATE KEY METRICS:                                     │
        │  ─────────────────────────────────────────────────────────  │
        │  Monthly Income:           RM5,000 (100%)                   │
        │  Required Savings:         RM1,200 (24%)                    │
        │  Forecasted Expenses:      RM3,900 (78%)                    │
        │  Available for Savings:    RM1,100 (22%)                    │
        │                                                              │
        │  Shortfall:               -RM100/month                       │
        └──────────────────────────────┬──────────────────────────────┘
                                       │
                    ┌──────────────────▼──────────────────┐
                    │  ASSESSMENT LOGIC:                  │
                    │                                     │
                    │  Savings Rate:  24% > 20%? YES     │
                    │  Expense Ratio: 78% ≤ 80%? YES     │
                    │  Available ≥ Required? NO (-100)    │
                    └──────────────────┬──────────────────┘
                                       │
                    ┌──────────────────▼──────────────────────────┐
                    │  🟡 VERDICT: CHALLENGING (Type A)           │
                    │                                             │
                    │  Why: You need to save 24% (above 20%       │
                    │        recommendation), and expenses are    │
                    │        rising to 78% (near 80% limit)       │
                    │                                             │
                    │  Status: Possible but needs adjustment      │
                    └──────────────────┬──────────────────────────┘
                                       │
            ┌──────────────────────────▼──────────────────────────┐
            │  PHASE 4: GENERATE PERSONALIZED ADVICE              │
            │  (Category-Based Recommendations)                   │
            └──────────────────────────────┬──────────────────────┘
                                           │
        ┌──────────────────────────────────▼──────────────────────────────┐
        │  IDENTIFY TOP SPENDING CATEGORIES:                             │
        │  ─────────────────────────────────────────────────────────────  │
        │  1. Food & Dining:     RM1,200/month (24% of budget)           │
        │  2. Transport:          RM800/month  (16% of budget)           │
        │  3. Entertainment:      RM600/month  (12% of budget)           │
        │  4. Bills & Utilities:  RM500/month  (10% of budget)           │
        │  5. Shopping:           RM400/month  (8% of budget)            │
        │  ─────────────────────────────────────────────────────────────  │
        │  Total:                RM3,900/month ✅                         │
        └──────────────────────────────┬──────────────────────────────────┘
                                       │
        ┌──────────────────────────────▼──────────────────────────────────┐
        │  CALCULATE REQUIRED CUTS:                                      │
        │  ─────────────────────────────────────────────────────────────  │
        │  To bridge RM100 gap, recommend cuts:                          │
        │                                                                │
        │  Food & Dining:   save RM40  (3% reduction)                  │
        │  Transport:       save RM30  (4% reduction)                  │
        │  Entertainment:   save RM20  (3% reduction)                  │
        │  Shopping:        save RM10  (2% reduction)                  │
        │  ─────────────────────────────────────────────────────────────  │
        │  TOTAL CUT:       RM100/month ✅                               │
        └──────────────────────────────┬──────────────────────────────────┘
                                       │
            ┌──────────────────────────▼──────────────────────────────┐
            │  🟡 FINAL ADVICE GENERATED:                            │
            │                                                         │
            │  OPTION 1: Cut Expenses by RM100                       │
            │  ───────────────────────────────────────────────────  │
            │  🍽️  Food: Save RM40 (eat out 2x less/month)          │
            │  🚗 Transport: Save RM30 (carpool 1 day/week)          │
            │  🎬 Entertainment: Save RM20 (skip 1 movie/month)      │
            │  🛍️  Shopping: Save RM10 (reduce impulse buys)        │
            │                                                         │
            │  Result: RM5,000 - RM3,800 = RM1,200 ✅                │
            │                                                         │
            │  OPTION 2: Extend Timeline to 13 months                │
            │  ───────────────────────────────────────────────────  │
            │  Required/month: 14,400 ÷ 13 = RM1,107 ✅             │
            │  Less pressure on budget                               │
            │                                                         │
            │  OPTION 3: Reduce Goal to RM13,200                    │
            │  ───────────────────────────────────────────────────  │
            │  Required/month: 13,200 ÷ 12 = RM1,100 ✅             │
            │  Achievable with current capacity                      │
            └──────────────────────────────┬──────────────────────────┘
                                           │
                        ┌──────────────────▼──────────────┐
                        │  END: Advice Report Generated    │
                        │  User Selects Path & Takes Action│
                        └──────────────────────────────────┘
```

---

## Flowchart 2: Feasibility Assessment Matrix

```
                     SAVINGS RATE (% of Monthly Income)
                    ↑
              70%   │
                    │              ┌────────────────┐
                    │       ❌      │   IMPOSSIBLE   │
            CRITICAL│      ZONE    │   (>70% rate)  │
                    │              └────────────────┘
              50%   │
                    │
              30%   │
                    │     ┌─────────────────────────────────────┐
                    │  🟡 │   CHALLENGING        │   CHALLENGING  │
                    │  20%│   (More effort)      │   (Tight budgt)│
                    │     │                      │                │
            ┌───────┼─────┼──────────────────────┼────────────────┼──────┐
   70%      │   🔴  │ 🟡  │     🟢 ACHIEVABLE   │  🟡 CHALLENGING│ 🔴   │
 (EXPENSES) │IMPOSS.│     │                      │                │IMPOSS│
   ╮       │ ZONE  │     │   (Easy path)       │  (Risky)       │ ZONE │
   │       │       │     │                      │                │      │
   │       │       │     └──────────────────────┴────────────────┘      │
   │       │       │                                                     │
   │       │       │                                                     │
   ▼       └───────┴─────────────────────────────────────────────────────┘
         0%      20%     40%     60%     80%     100% (EXPENSE RATIO)
                 
   Legend:
   • X-Axis: How much of income goes to expenses (0-100%)
   • Y-Axis: How much needs to go to savings (0-100%)
   
   🟢 ACHIEVABLE: 
      • Savings ≤ 20% (comfortable)
      • Expenses ≤ 80% (safe)
      
   🟡 CHALLENGING (Types A, B, C):
      • Savings > 20% but expenses still < 80%
      • Savings ≤ 20% but expenses > 80%
      • Either pushing limits but not impossible
      
   🔴 IMPOSSIBLE:
      • Savings + Expenses > 100%
      • Or Savings > 70% (unrealistic)
      • Requires fundamental solution (income ↑ or goal ↓)
```

---

## Flowchart 3: Three-Stage Feasibility Decision Tree

```
                        HAS CONSISTENT INCOME?
                              │
                    ┌─────────┴──────────┐
                    │                    │
                   NO                   YES
                    │                    │
            📋 Show Error         ✅ Get Avg Income
            Request Data          (RM5,000)
                    │                    │
                    │                    ▼
                    │         GET EXPENSE FORECAST
                    │         (RM3,900/month)
                    │                    │
                    │         ┌──────────┴──────────┐
                    │         │                     │
                    │    CALCULATE METRICS:   COMPARE WITH RULE:
                    │    Savings% = ?         Savings ≤ 20%?
                    │    Expenses% = ?        Expenses ≤ 80%?
                    │                         Both ok?
                    │                             │
                    │              ┌──────────────┼──────────────┐
                    │              │              │              │
                    │            YES             MIX           NO
                    │              │              │              │
                    │              ▼              ▼              ▼
                    │          ┌────────┐    ┌─────────┐   ┌──────────┐
                    │          │ 🟢     │    │ 🟡      │   │ 🟡/🔴    │
                    │          │ACHIEVAB│    │CHALLENGE│   │CHALLENGE/│
                    │          │LE      │    │ ING      │   │IMPOSSIBLE│
                    │          └────┬───┘    └────┬─────┘   └────┬─────┘
                    │               │             │              │
                    │               ▼             ▼              ▼
                    │           ┌────────┐   ┌──────────┐  ┌──────────┐
                    │           │ Advice:│   │Advice:   │  │Advice:   │
                    │           │        │   │▶ 3 OPTS: │  │▶ 3 OPTS: │
                    │           │Continue│   │1. Cut    │  │1.↓Goal   │
                    │           │current │   │2.↑Time   │  │2.↑Income │
                    │           │pattern │   │3.↓Goal   │  │3.↑Time   │
                    │           │        │   │          │  │          │
                    │           │Monitor │   │Provides  │  │Critical  │
                    │           │monthly │   │category- │  │changes   │
                    │           │        │   │specific  │  │required  │
                    │           │Surplus │   │guidance  │  │          │
                    │           │budget  │   │          │  │          │
                    │           └────────┘   └──────────┘  └──────────┘
                    │                              │              │
                    │                              │              │
                    └──────────────────────────────┴──────────────┘
                                     │
                                     ▼
                         ┌─────────────────────────┐
                         │ USER SELECTS: ✅ Action │
                         │ ┌─────────────────────┐ │
                         │ │ Save Report         │ │
                         │ │ Share with Advisor  │ │
                         │ │ Set Reminders       │ │
                         │ │ Track Progress      │ │
                         │ └─────────────────────┘ │
                         └─────────────────────────┘
```

---

## Flowchart 4: Database Query Flow

```
   USER SUBMITS GOAL
   (Amount: RM14,400, Timeline: 12 months)
            │
            ▼
   ┌────────────────────────────────────┐
   │ QUERY 1: INCOME VALIDATION         │
   │─────────────────────────────────────│
   │ FROM Transaction                   │
   │ WHERE type='income'                │
   │   AND date >= DATE_SUB(NOW(),      │
   │       INTERVAL 12 MONTH)           │
   │                                    │
   │ RESULT: 47 income transactions ✅  │
   └────────────────────────────────────┘
            │
            ▼
   ┌────────────────────────────────────┐
   │ QUERY 2: EXTRACT CATEGORIES        │
   │─────────────────────────────────────│
   │ SELECT DISTINCT categoryId         │
   │ FROM (income transactions)         │
   │                                    │
   │ RESULT: [cat_salary_1,             │
   │          cat_bonus_1]  ✅          │
   └────────────────────────────────────┘
            │
            ▼
   ┌────────────────────────────────────┐
   │ QUERY 3: FIND SALARY CATEGORY      │
   │─────────────────────────────────────│
   │ FROM Category                      │
   │ WHERE categoryId IN (...)           │
   │   AND name ILIKE '%salary%'        │
   │                                    │
   │ RESULT: "Monthly Salary"           │
   │         (cat_salary_1) ✅          │
   └────────────────────────────────────┘
            │
            ▼
   ┌────────────────────────────────────┐
   │ QUERY 4: GROUP BY MONTH            │
   │─────────────────────────────────────│
   │ GROUP salary transactions          │
   │ BY YEAR-MONTH format               │
   │ SUM(amount) per month              │
   │                                    │
   │ RESULT: 8 consecutive months       │
   │         Average: RM5,000 ✅        │
   └────────────────────────────────────┘
            │
            ▼
   ┌────────────────────────────────────┐
   │ QUERY 5: GET EXPENSES (12M)        │
   │─────────────────────────────────────│
   │ FROM Transaction                   │
   │ WHERE type='expense'               │
   │   AND date >= DATE_SUB(NOW(),      │
   │       INTERVAL 12 MONTH)           │
   │                                    │
   │ RESULT: Monthly avg RM3,500-4,500  │
   │         Ready for forecast ✅      │
   └────────────────────────────────────┘
            │
            ▼
   ┌────────────────────────────────────┐
   │ CALL: FORECAST API (Prophet)       │
   │─────────────────────────────────────│
   │ POST forecastapi.com/v2/forecast   │
   │ Payload: 12 months historical data │
   │ Periods: 3 months ahead            │
   │                                    │
   │ RESULT: [3800, 3900, 4000]         │
   │         Avg: RM3,900 ✅            │
   └────────────────────────────────────┘
            │
            ▼
   ┌────────────────────────────────────┐
   │ QUERY 6: GET EXPENSE BY CATEGORY   │
   │─────────────────────────────────────│
   │ FROM Transaction                   │
   │ WHERE type='expense'               │
   │ GROUP BY categoryId                │
   │ ORDER BY total DESC                │
   │                                    │
   │ RESULT:                            │
   │ 1. Food: RM1,200 (24%)             │
   │ 2. Transport: RM800 (16%)          │
   │ 3. Entertainment: RM600 (12%)      │
   │ ... etc ✅                          │
   └────────────────────────────────────┘
            │
            ▼
   ┌────────────────────────────────────┐
   │ CALCULATE ADVICE:                  │
   │─────────────────────────────────────│
   │ All data now available             │
   │ Match against 20/80 rule           │
   │ Generate category-specific cuts    │
   │ Create 3 alternative options       │
   │                                    │
   │ RESULT: Full assessment report ✅  │
   └────────────────────────────────────┘
```

---

## Flowchart 5: Advice Generation Based on Stage

```
                        FEASIBILITY STAGE DETERMINED
                              │
                ┌─────────────┼─────────────┐
                │             │             │
            🟢 ACHIEVABLE   🟡 CHALLENGING  🔴 IMPOSSIBLE
                │             │             │
                ▼             ▼             ▼
        ┌──────────────┐┌──────────────┐┌──────────────┐
        │ Your goal  │ │Your goal is │ │Your goal    │
        │ is easily  │ │possible but │ │cannot be    │
        │achievable! │ │requires     │ │achieved     │
        │            │ │effort       │ │with current │
        │Easy Path   │ │            │ │info        │
        └──────┬──────┘└──────┬──────┘└──────┬───────┘
               │              │              │
        ┌──────▼──────┐ ┌────▼──────┐ ┌────▼───────┐
        │             │ │            │ │ Choose 1 │
        │ ✅ Continue │ │ 🔧 Adjust: │ │ of 3      │
        │ ✅ Monitor  │ │ A. Cut     │ │ OPTIONS:  │
        │ ✅ Optimize │ │    expenses│ │            │
        │    slowly   │ │ B. Extend  │ │ A. ↓ Goal │
        │            │ │    timeline│ │ B. ↑ Income│
        │✻ Surplus   │ │ C. Lower   │ │ C. ↑ Time │
        │  available │ │    goal    │ │            │
        │            │ │            │ │📋 Show 3  │
        │💰 Build    │ │✻ Need this │ │   paths   │
        │  emergency │ │  effort    │ │            │
        │  fund      │ │            │ │❌ Cannot  │
        │            │ │🎯 Target:  │ │   quick   │
        │🎯 Trim to  │ │   likely   │ │   fix     │
        │   achieve  │ │   succeed  │ │            │
        │   earlier  │ │            │ │            │
        └────────────┘ └────────────┘ └────────────┘
```

---

## Flowchart 6: Income Consistency Validation

```
         INCOME TRANSACTIONS COLLECTION
         (Past 12 months: type='income')
                      │
                      ▼
         ┌────────────────────────┐
         │ Amount Filter Check    │
         │ amount > 0?            │
         └────────┬─────────┬─────┘
         YES      │         NO
         │        │         │
         ▼        ▼         ▼
    ✅ Include 🔄 Skip   (skip negative)
         │
         ▼
    EXTRACT CATEGORY IDs
         │
         ▼
    GROUP INTO MONTHS
    (YYYY-MM format)
         │
         ▼
    SUM PER MONTH
         │
         ▼
  ┌──────────────────────┐
  │ Check Consecutiveness│
  │ 2025-01: RM5000  ✅  │
  │ 2025-02: RM5000  ✅  │
  │ 2025-03: RM5000  ✅  │
  │ 2025-04: RM5000  ✅  │
  │ 2025-05: RM5000  ✅  │
  │ ...                  │
  │ Count: 5 months      │
  │ ≥ 3 months? YES ✅   │
  └──────────┬───────────┘
             │
             ▼
    CALCULATE AVERAGE
    (5000+5000+5000+5000+5000)/5
    = RM5000/month
             │
             ▼
    ┌─────────────────────────┐
    │ RESULT: Valid Income    │
    │ Consistency: ✅ YES     │
    │ Avg: RM5,000/month      │
    │ Count: 5 months         │
    │ Ready: YES              │
    └─────────────────────────┘
```

These flowcharts visualize the complete intelligent decision-making process from start to finish!

