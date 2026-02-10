# Smart Budgeting & Forecast Alerts - Visual Architecture

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         USER INTERFACE                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌───────────────────────┐      ┌──────────────────────────┐   │
│  │  AI Features Screen   │      │ Budget Forecasting Screen│   │
│  │  - Feature List       │━━━━┓ │ - Budget Selector        │   │
│  │  - Alert Badge (⚠️)   │    │ │ - High Risk Alert        │   │
│  │                       │    │ │ - Next Month Forecast    │   │
│  └───────────────────────┘    │ │ - 3-Month Details        │   │
│                           ┐    │ │ - Historical Data        │   │
│  ┌───────────────────────┐│    │ │ - MAE Accuracy          │   │
│  │  Account Page         │├─━━┓│ └──────────────────────────┘   │
│  │ - Budget Alert Icon   ││   │└─ Dynamic Navigation            │
│  │ - Account List        ││   │                                  │
│  └───────────────────────┘└─┐ │                                  │
│                             │ │  Budget Forecasting Screen       │
│                             │ └──────────────────────────────────┘
│                             │
│  ┌───────────────────────┐  │
│  │  Supabase (Backend)   │◀─┘
│  │ - Transaction Data    │
│  │ - Budget Info         │
│  │ - User Data           │
│  └───────────────────────┘
│
└─────────────────────────────────────────────────────────────────┘
         │
         │ (Calls)
         ▼
┌─────────────────────────────────────────────────────────────────┐
│                  BUDGET FORECAST SERVICE                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌──────────────────────┐  ┌──────────────────────────────┐    │
│  │  Data Retrieval      │  │  Forecast Algorithms         │    │
│  │  ┌────────────────┐  │  │  ┌──────────────────────┐    │    │
│  │  │ Fetch 12M      │  │  │  │  Trend Analysis      │    │    │
│  │  │ transactions   │  │  │  │  (Linear Regression) │    │    │
│  │  │                │  │  │  │                      │    │    │
│  │  │ Filter by:     │  │  │  │  Seasonality Det.    │    │    │
│  │  │ - Account      │  │  │  │  (Monthly Patterns)  │    │    │
│  │  │ - Category     │  │  │  │                      │    │    │
│  │  │ - Ledger       │  │  │  │  Anomaly Detection   │    │    │
│  │  │                │  │  │  │  (Z-Score: 2.0σ)     │    │    │
│  │  │ Aggregate:     │  │  │  │                      │    │    │
│  │  │ Daily → Monthly│  │  │  │  Confidence Bounds   │    │    │
│  │  │                │  │  │  │  (95% CI)            │    │    │
│  │  └────────────────┘  │  │  └──────────────────────┘    │    │
│  └──────────────────────┘  └──────────────────────────────┘    │
│           │                          │                          │
│           └──────────┬───────────────┘                          │
│                      ▼                                          │
│           ┌─────────────────────────┐                          │
│           │ Historical Data Model   │                          │
│           │ [Month: Spending Amt]   │                          │
│           │                         │                          │
│           │ - Jan: RM 2000          │                          │
│           │ - Feb: RM 2100          │                          │
│           │ - Mar: RM 2050          │                          │
│           │ - ...                   │                          │
│           │ - Dec: RM 5000 (spike)  │                          │
│           └─────────────────────────┘                          │
│                      │                                          │
│                      ▼                                          │
│           ┌──────────────────────────────┐                    │
│           │ Forecast Calculations        │                    │
│           │                              │                    │
│           │ Trend Slope: +100/month      │                    │
│           │ Seasonality Factor: 2.5x     │ (Dec)              │
│           │ StdDev: RM 400               │                    │
│           │ Next Month Forecast: RM2400  │                    │
│           │ Lower Bound: RM 1630         │                    │
│           │ Upper Bound: RM 3170         │                    │
│           └──────────────────────────────┘                    │
│                      │                                          │
│                      ▼                                          │
│           ┌──────────────────────────────┐                    │
│           │ MeanAbsoluteError(MAE)       │                    │
│           │ Calculation                  │                    │
│           │                              │                    │
│           │ Test Data Accuracy:          │                    │
│           │ MAE = RM 150                 │                    │
│           │ (Typical deviation)          │                    │
│           └──────────────────────────────┘                    │
│                      │                                          │
│                      ▼                                          │
│           ┌──────────────────────────────┐                    │
│           │ High Risk Check              │                    │
│           │                              │                    │
│           │ IF:                          │                    │
│           │ Forecast > Budget AND        │                    │
│           │ UpperBound > Budget × 1.2    │                    │
│           │ THEN: HIGH RISK = True       │                    │
│           │ ELSE: HIGH RISK = False      │                    │
│           └──────────────────────────────┘                    │
│                      │                                          │
│                      ▼                                          │
│           ┌──────────────────────────────┐                    │
│           │ Return Results               │                    │
│           │                              │                    │
│           │ - Forecast Results (list)    │                    │
│           │ - High Risk Status (bool)    │                    │
│           │ - MAE Score (double)         │                    │
│           │ - Historical Data (list)     │                    │
│           └──────────────────────────────┘                    │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
         │
         │ (Returns)
         ▼
┌─────────────────────────────────────────────────────────────────┐
│                      UI DISPLAY LOGIC                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │         If High Risk = True                             │   │
│  │         ┌────────────────────────────────────────────┐  │   │
│  │         │ SHOW: Red Alert Badge ⚠️                  │  │   │
│  │         │ DISPLAY: High Risk Alert Container       │  │   │
│  │         │            "Forecasted expenses may       │  │   │
│  │         │             exceed your budget next month"│  │   │
│  │         └────────────────────────────────────────────┘  │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │         If High Risk = False                            │   │
│  │         ┌────────────────────────────────────────────┐  │   │
│  │         │ HIDE: Alert Badge                          │  │   │
│  │         │ NO: High Risk Alert Container              │  │   │
│  │         │ MESSAGE: Budget is safe                    │  │   │
│  │         └────────────────────────────────────────────┘  │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Always Display:                                        │   │
│  │  - Forecast Summary (Next Month)                       │   │
│  │  - 3-Month Details                                     │   │
│  │  - Historical Data Graph                              │   │
│  │  - Accuracy Metrics (MAE)                             │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

## Alert Badge Flow

```
User Opens AI Features Screen
           │
           ▼
Check All User Budgets
    │ │ │ │ │ │
    ▼ ▼ ▼ ▼ ▼ ▼
All Budgets
    │
    ├─ Budget 1: Not High Risk ✓
    │
    ├─ Budget 2: Not High Risk ✓
    │
    ├─ Budget 3: HIGH RISK ⚠️  ◄── Found one!
    │
    └─ Budget 4: Not High Risk ✓

Result: At Least One High Risk = True
Action: Show Red Alert Badge on Button
```

## Forecast Calculation Flow

```
Historical Data (12 months)
┌──────────────────────────────┐
│  Jan: RM 2000                │
│  Feb: RM 2100                │
│  Mar: RM 2050                │
│  Apr: RM 2200                │
│  May: RM 2150                │
│  Jun: RM 2300                │
│  Jul: RM 2400                │
│  Aug: RM 2350                │
│  Sep: RM 2500                │
│  Oct: RM 2600                │
│  Nov: RM 2700                │
│  Dec: RM 5000 (Holiday!) ◄── Anomaly
└──────────────────────────────┘
           │
           ▼
1. TREND ANALYSIS
   ┌──────────────────────────┐
   │ Linear Regression        │
   │ Slope = +100/month       │
   │ Base = RM 2000           │
   │ Formula:                 │
   │ Forecast = 2000 + 100×n  │
   └──────────────────────────┘
           │
           ▼
2. SEASONALITY DETECTION
   ┌──────────────────────────┐
   │ Monthly Averages:        │
   │ Month 1-11: RM 2250 avg  │
   │ Month 12: RM 5000 spike  │
   │                          │
   │ Seasonality Factor:      │
   │ Month 12: 5000/2250 = 2.2│
   │ Months 1-11: 1.0 avg     │
   └──────────────────────────┘
           │
           ▼
3. GENERATE FORECAST
   ┌──────────────────────────┐
   │ For Next 3 Months:       │
   │                          │
   │ Month 13 (Jan-like):     │
   │ Trend: 2000 + 100×13=3300│
   │ Seasonal: 3300 × 1.0=3300│
   │ Forecast: RM 3300        │
   │                          │
   │ Month 14 (Feb-like):     │
   │ Trend: 2000 + 100×14=3400│
   │ Seasonal: 3400 × 1.0=3400│
   │ Forecast: RM 3400        │
   │                          │
   │ Month 15 (Dec-like):     │
   │ Trend: 2000 + 100×15=3500│
   │ Seasonal: 3500 × 2.2=7700│
   │ Forecast: RM 7700 ◄── High!
   └──────────────────────────┘
           │
           ▼
4. CALCULATE CONFIDENCE BOUNDS
   ┌──────────────────────────┐
   │ StdDev = RM 800          │
   │ Margin = 1.96 × 800      │
   │        = RM 1568         │
   │                          │
   │ Month 13:                │
   │ Lower: 3300 - 1568 = 1732│
   │ Upper: 3300 + 1568 = 4868│
   │                          │
   │ Month 15:                │
   │ Lower: 7700 - 1568 = 6132│
   │ Upper: 7700 + 1568 = 9268│
   └──────────────────────────┘
           │
           ▼
5. CHECK HIGH RISK
   ┌──────────────────────────┐
   │ Budget = RM 3000         │
   │                          │
   │ Month 13 (RM 3300):      │
   │ 3300 > 3000? YES ✓       │
   │ 4868 > 3600? YES ✓       │
   │ HIGH RISK: YES ⚠️         │
   │                          │
   │ Month 15 (RM 7700):      │
   │ 7700 > 3000? YES ✓       │
   │ 9268 > 3600? YES ✓       │
   │ HIGH RISK: YES ⚠️         │
   └──────────────────────────┘
           │
           ▼
RESULT: Alert Badge Shows ⚠️
```

## Budget Type Filtering

```
Budget has one of:
    │
    ├─ accountId  ─────┐
    │                  │
    ├─ categoryId ──┐  │    Fetch Transactions
    │               │  │        │
    └─ ledgerId ───┼──┤        │
                   │  │        ▼
                   │  └─► By Account
                   │
                   │        By Category
                   │        + type='expense'
                   │
                   └─► By Ledger
                        + type='expense'

GROUP BY Month
    │
    ▼
Aggregate daily → monthly spending
```

---

**For code details**, see the service implementation in:
- `lib/services/budget_forecast_service.dart`

**For UI details**, see the screen implementation in:
- `lib/screens/budget_forecasting_screen.dart`
