# Smart Budgeting & Forecast Alerts Implementation Guide

## Overview

The **Smart Budgeting & Forecast Alerts** feature uses advanced forecasting algorithms to predict future expenses and automatically alert users when there's a high risk of exceeding their budget limits. This replaces the basic ≥80% usage threshold with an intelligent, data-driven approach.

## Key Features

### 1. **Forecast Algorithm (Facebook Prophet-Based)**
- **Trend Analysis**: Detects long-term spending trends using linear regression
- **Seasonality Detection**: Identifies recurring patterns in spending (monthly, seasonal, etc.)
- **Anomaly Detection**: Flags unusual spending patterns that deviate significantly from historical norms
- **Confidence Intervals**: Provides upper and lower bounds for forecast predictions (95% confidence)

### 2. **High-Risk Alert System**
Alerts are **only displayed when there's high risk**, not based on simple percentage thresholds. High risk is determined by:
- **Forecasted Expense > Budget Limit** AND
- **Upper Confidence Bound > 120% of Budget**

This dual-condition approach ensures alerts are only triggered when there's significant risk of budget overrun.

### 3. **Forecast Accuracy Metrics**
- **Mean Absolute Error (MAE)**: Measures the average difference between predicted and actual expenses
- **Backtesting**: Validates forecast accuracy against historical data
- **Confidence Scoring**: Shows how confident the forecast is for each prediction

## Architecture

### New Services

#### `budget_forecast_service.dart`
Located in `lib/services/budget_forecast_service.dart`

**Key Classes and Methods:**

```dart
// Data Models
- ForecastResult: Contains forecasted amount, confidence bounds, and anomaly flag
- HistoricalSpending: Represents historical monthly spending data

// Main Service Class
class BudgetForecastService {
  Future<bool> checkHighRiskAlert(...)
  Future<List<ForecastResult>> getForecast(...)
  Future<List<HistoricalSpending>> getHistoricalData(...)
  Future<double> calculateForecastAccuracy(...)
}
```

**Core Algorithms:**
- `_forecastWithProphet()`: Implements Facebook Prophet-like forecasting
- `_calculateTrend()`: Linear regression for trend analysis
- `_calculateSeasonality()`: Month-over-month pattern detection
- `_calculateMAE()`: Forecast accuracy calculation

### New Screens

#### `budget_forecasting_screen.dart`
Located in `lib/screens/budget_forecasting_screen.dart`

**Features:**
- Budget selector dropdown
- High-risk alert display (only shown when risk is present)
- Next month forecast summary
- 3-month detailed forecast
- Historical data analysis (12 months)
- Forecast accuracy metrics (MAE)

### Updated Screens

#### `ai_features_screen.dart`
- Now includes Budget Forecasting feature
- Dynamic alert badge that **only displays when there's high risk**
- Navigates to BudgetForecastingScreen

#### `account_page.dart`
- Updated `_checkBudgetAlerts()` to use forecast-based logic
- Replaces old 80% usage threshold

## How It Works

### 1. **Data Collection**
```
Historical Data (12 months)
        ↓
Aggregated by Month
        ↓
Transactions by Budget Type (Account/Category/Ledger)
```

### 2. **Forecast Process**
```
Training Data (First 12 months)
        ↓
Trend Analysis (Linear Regression)
        ↓
Seasonality Detection (Monthly Patterns)
        ↓
Forecast for Next 3 Months
        ↓
Calculate Confidence Bounds (95% CI)
```

### 3. **Alert Logic**
```
Next Month Forecast Generated
        ↓
Check: Forecast > Budget?
        ↓
Check: Upper Bound > 120% of Budget?
        ↓
Both TRUE → HIGH RISK ALERT ✓
Either FALSE → No Alert (Budget is Safe)
```

### 4. **Accuracy Validation**
```
Split Historical Data (50/50 Train/Test)
        ↓
Train on First 50%, Forecast Second 50%
        ↓
Calculate MAE (Mean Absolute Error)
        ↓
Display Accuracy to User
```

## Alert Badge Behavior

### Previous Implementation
- Alert badge always displayed on Budget Forecasting button
- Based on simple 80% usage threshold

### New Implementation
- Alert badge **only appears when:**
  - Forecasted expenses exceed budget limit
  - AND upper confidence bound exceeds 120% of budget
- Alert badge **disappears when:**
  - Forecast is within budget limits
  - OR predicted spending is close enough to budget

**Visual Indicator:**
- Red badge with warning icon (⚠️) when high risk
- No badge when budget is safe

## Database Schema

The feature uses the existing Budget table:

```sql
CREATE TABLE public."Budget" (
  "budgetId" CHARACTER VARYING NOT NULL,
  type CHARACTER VARYING NOT NULL,
  "rolloverStatus" BOOLEAN NULL,
  "reuseStatus" BOOLEAN NULL,
  "cycleType" CHARACTER VARYING NULL,
  amount DOUBLE PRECISION NULL,
  "ledgerId" CHARACTER VARYING NULL,
  "categoryId" CHARACTER VARYING NULL,
  "userId" CHARACTER VARYING NULL,
  "accountId" CHARACTER VARYING NULL,
  CONSTRAINT Budget_pkey PRIMARY KEY ("budgetId"),
  CONSTRAINT Budget_accountId_fkey FOREIGN KEY ("accountId") 
    REFERENCES "Account" ("accountId") ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT Budget_categoryId_fkey FOREIGN KEY ("categoryId") 
    REFERENCES "Category" ("categoryId") ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT Budget_ledgerId_fkey FOREIGN KEY ("ledgerId") 
    REFERENCES "Ledger" ("ledgerId") ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT Budget_userId_fkey FOREIGN KEY ("userId") 
    REFERENCES "User" ("userId") ON UPDATE CASCADE ON DELETE CASCADE
) TABLESPACE pg_default;
```

## Usage Flow

### User Journey

**1. View AI Features Screen**
- User navigates to AI Features
- System checks all budgets for high-risk status
- **Red alert badge appears ONLY if high risk detected**
- Blue badge (or no badge) if all budgets are safe

**2. Navigate to Budget Forecasting**
- User taps on Budget Forecasting feature
- BudgetForecastingScreen loads
- Shows all available budgets in dropdown

**3. View Budget Analysis**
- Select a budget from dropdown
- See forecast for next month
- View 3-month detailed forecast
- Review 12-month historical data
- Check forecast accuracy (MAE)

**4. Interpret Results**
- Green high-risk container appears if forecast exceeds budget
- Shows forecasted amount vs. budget limit
- Displays expected usage percentage
- Range shows confidence bounds (low-high estimates)

## Forecast Interpretation

### Example 1: Safe Budget
```
Forecasted Amount: RM 2,500
Budget Limit: RM 3,000
Expected Usage: 83%
Status: Safe (Forecast < Budget)
Alert Badge: None
```

### Example 2: High Risk Alert
```
Forecasted Amount: RM 3,200
Budget Limit: RM 3,000
Upper Bound: RM 3,850 (>120% of Budget)
Expected Usage: 107%
Status: HIGH RISK
Alert Badge: Red Warning Icon
Recommendation: Reduce spending or increase budget
```

## Mean Absolute Error (MAE)

**What it means:**
- Shows average prediction error in RM
- Smaller MAE = More accurate predictions
- Calculated by comparing historical forecast accuracy

**Example:**
```
MAE: RM 150
Interpretation: The forecast typically deviates by RM 150
from actual spending
```

## Minimum Data Requirements

- **Minimum Historical Months**: 3 months for basic forecast
- **Recommendation**: 12+ months for most accurate seasonality detection
- **If insufficient data**: Feature shows message and doesn't generate forecast

## Technical Implementation Details

### Trend Calculation
Uses simple linear regression on historical data:
```
forecast = slope * time_index + intercept
```

### Seasonality Calculation
Compares monthly average to overall average:
```
seasonality_factor = (month_average) / (overall_average)
```

### Anomaly Detection
Detects unusual patterns using Z-score:
```
is_anomaly = |value - mean| > 2.0 * std_deviation
```

### Confidence Bounds
Uses 95% confidence interval:
```
margin = 1.96 * standard_deviation
upper_bound = forecast + margin
lower_bound = max(0, forecast - margin)
```

## Performance Considerations

- **Data Fetch**: Queries last 12-24 months of transactions
- **Computation**: Linear regression and statistical calculations
- **Caching**: Forecasts are recalculated only when budget is selected
- **Network**: Single Supabase query per budget check

## Future Enhancements

1. **Machine Learning Integration**: Replace Prophet approximation with actual Prophet library
2. **Custom Alerts**: User-configurable risk thresholds
3. **Spending Recommendations**: AI-driven suggestions to reduce spending
4. **Budget Adjustment**: Auto-adjustment of budget based on trends
5. **Notifications**: Push notifications for high-risk alerts
6. **Historical Comparison**: Show how prediction accuracy improved over time
7. **Category-Specific Insights**: Forecast per expense category
8. **Savings Projections**: Forecast savings goals achievement

## Testing Checklist

- [ ] Forecast displays correctly for budgets with 12+ months data
- [ ] High-risk alert badge appears only when appropriate
- [ ] MAE calculation matches expected accuracy
- [ ] Insufficient data message shows for new budgets
- [ ] Budget dropdown switches forecasts correctly
- [ ] Historical data aggregates correctly by month
- [ ] Confidence bounds are realistic
- [ ] Navigation between screens works properly

## Troubleshooting

### No Forecast Generated
**Cause**: Insufficient historical data (<3 months)
**Solution**: Wait for more months of data to accumulate

### Forecast Seems Inaccurate
**Cause**: Unusual spending patterns or recent behavioral changes
**Solution**: Check MAE value; higher MAE indicates lower confidence

### Alert Badge Always Shows
**Cause**: Budget is within high-risk threshold
**Solution**: Review your spending patterns or increase budget

### Forecast Not Updating
**Cause**: Cache or network issues
**Solution**: Exit and re-enter the Budget Forecasting screen

## Code Integration Points

### To enable forecasting in other parts of the app:

```dart
// Import the service
import 'package:fyp_zy/services/budget_forecast_service.dart';

// Create instance
final forecastService = BudgetForecastService();

// Check for high risk
bool isHighRisk = await forecastService.checkHighRiskAlert(
  userId,
  budgetId,
  budgetAmount,
  accountId,
  categoryId,
  ledgerId,
);

// Get forecast
List<ForecastResult> forecast = await forecastService.getForecast(
  userId,
  budgetId,
  accountId,
  categoryId,
  ledgerId,
  3, // months to forecast
);

// Get accuracy
double mae = await forecastService.calculateForecastAccuracy(
  userId,
  budgetId,
  accountId,
  categoryId,
  ledgerId,
);
```

---

## Summary

The Smart Budgeting & Forecast Alerts feature provides users with intelligent, data-driven budget management. By analyzing spending patterns and forecasting future expenses, it helps users:

✅ **Avoid Overspending**: Get warned before exceeding budget
✅ **Make Informed Decisions**: Understand spending trends and seasonality
✅ **Plan Ahead**: See 3-month forecasts with confidence intervals
✅ **Track Accuracy**: Monitor how accurate predictions are (MAE)
✅ **Reduce Financial Stress**: Focus only on high-risk alerts, not false positives

The alert system is intelligent: **alerts only display when there's genuine high-risk**, ensuring users aren't overwhelmed with unnecessary notifications while staying informed about real financial risks.
