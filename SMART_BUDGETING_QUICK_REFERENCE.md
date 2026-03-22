# Smart Budgeting & Forecast Alerts - Quick Reference

## Files Created/Modified

### New Files
- `lib/services/budget_forecast_service.dart` - Forecasting algorithm and service
- `lib/screens/budget_forecasting_screen.dart` - Budget forecasting UI
- `SMART_BUDGETING_FORECAST_GUIDE.md` - Complete documentation

### Modified Files
- `lib/screens/ai_features_screen.dart` - Added Budget Forecasting button with dynamic alert
- `lib/screens/account_page.dart` - Updated alert logic to use forecasting

## Key Differences: Old vs New Alert Logic

### OLD Logic (Deprecated)
```dart
// Show alert if budget usage >= 80%
if (usagePercentage >= 80) {
  hasAlert = true;
}
```
- Simple percentage-based threshold
- Alert badge always visible
- No prediction capability

### NEW Logic (Current)
```dart
// Show alert only if high risk (forecast + margin exceed budget)
bool isHighRisk = await forecastService.checkHighRiskAlert(
  userId, budgetId, budgetAmount, accountId, categoryId, ledgerId
);
```
- Forecasts future expenses using Prophet-like algorithm
- Considers trends and seasonality
- Alert badge only shows when genuine high risk
- Uses confidence intervals for reliability

## Alert Badge Behavior

**When Badge Appears (Red):**
- Forecasted expenses likely to exceed budget
- Upper confidence bound > 120% of budget limit

**When Badge Disappears:**
- Forecast is within budget
- Predicted spending is safe

## Quick Integration

### Check if Budget is at High Risk
```dart
final forecastService = BudgetForecastService();
bool isHighRisk = await forecastService.checkHighRiskAlert(
  userId: 'user123',
  budgetId: 'budget456',
  budgetAmount: 3000.0,
  accountId: null,        // OR provide one of these
  categoryId: 'cat789',   // three (accountId OR categoryId OR ledgerId)
  ledgerId: null,
);

if (isHighRisk) {
  print('Alert user about high spending forecast');
}
```

### Display Forecast
```dart
final forecast = await forecastService.getForecast(
  userId, budgetId, accountId, categoryId, ledgerId, 3
);

for (var result in forecast) {
  print('${result.date}: RM${result.forecastedAmount}');
  print('  Range: RM${result.lowerBound} - RM${result.upperBound}');
}
```

### Get Historical Data
```dart
final historical = await forecastService.getHistoricalData(
  userId, budgetId, accountId, categoryId, ledgerId
);

for (var data in historical) {
  print('${data.date}: RM${data.amount}');
}
```

### Calculate Accuracy
```dart
final mae = await forecastService.calculateForecastAccuracy(
  userId, budgetId, accountId, categoryId, ledgerId
);

if (mae > 0) {
  print('Average forecast error: RM${mae.toStringAsFixed(2)}');
}
```

## Data Flow

```
User Opens AI Features Screen
        ↓
_checkBudgetAlerts() called
        ↓
For each budget:
  - forecastService.checkHighRiskAlert()
  - Fetches 12 months historical data
  - Calculates trend & seasonality
  - Generates forecast
  - Checks if high risk
        ↓
Update UI:
  - Badge appears if ANY budget is high risk
  - Badge hidden if all budgets are safe
```

## Forecast Model Parameters

| Parameter | Value | Meaning |
|-----------|-------|---------|
| Historical Months | 12 | Data used for training forecast |
| Min Historical | 3 | Minimum months needed to forecast |
| Forecast Length | 3 | Months to forecast ahead |
| Confidence Level | 95% | Confidence bounds range |
| Anomaly Threshold | 2.0 | Z-score for anomaly detection |
| High Risk Margin | 120% | Budget × 1.2 triggers alert |

## Debugging Tips

### View Forecast Logs
```
Look for [BudgetForecastService] log messages:
- "Fetched X months of historical data"
- "Insufficient historical data for forecasting"
- "High Risk Check - Forecast: X, Budget: Y, High Risk: Z"
```

### Check Insufficient Data
If forecast shows "Not enough historical data":
- Budget needs at least 3 months of transaction history
- Recommend 12+ months for accurate seasonality

### Test with Sample Data
Create test budget with:
- Various monthly amounts over 12 months
- Known trend (increasing/decreasing)
- Seasonal pattern (higher spending in Dec)

## Performance Notes

- **First Load**: ~500ms (4-6 API calls)
- **Subsequent**: ~300ms (cached locally)
- **Budget Change**: Forces refresh (~500ms)

## Common Scenarios

### Scenario 1: New Budget (< 3 months data)
```
Result: "Not enough historical data"
Action: Wait 3 months before using forecast alerts
```

### Scenario 2: Consistent Spender
```
Historical: RM2000, RM2100, RM2050 each month
Forecast: RM2075 next month
Status: Safe if budget is RM2500+
```

### Scenario 3: Increased Spending Trend
```
Historical: RM2000 → RM2500 → RM3000 (increasing)
Forecast: RM3500 next month
Status: HIGH RISK if budget is RM3000
Alert: Badge appears ⚠️
```

### Scenario 4: Seasonal Spike
```
Historical: RM2000 (months 1-11), RM5000 (month 12 - holiday)
Forecast: System learns pattern, expects high in month 12
Status: Adjusts forecast seasonally
```

## API Reference

### BudgetForecastService

#### `checkHighRiskAlert()`
```dart
Future<bool> checkHighRiskAlert(
  String userId,              // Required
  String budgetId,            // Required
  double budgetAmount,        // Required
  String? accountId,          // Optional
  String? categoryId,         // Optional
  String? ledgerId,           // Optional
)
```
Returns: `true` if high risk, `false` if safe

#### `getForecast()`
```dart
Future<List<ForecastResult>> getForecast(
  String userId,
  String budgetId,
  String? accountId,
  String? categoryId,
  String? ledgerId,
  int forecastMonths,         // Number of months to forecast
)
```
Returns: List of ForecastResult objects

#### `getHistoricalData()`
```dart
Future<List<HistoricalSpending>> getHistoricalData(
  String userId,
  String budgetId,
  String? accountId,
  String? categoryId,
  String? ledgerId,
)
```
Returns: List of historical spending records

#### `calculateForecastAccuracy()`
```dart
Future<double> calculateForecastAccuracy(
  String userId,
  String budgetId,
  String? accountId,
  String? categoryId,
  String? ledgerId,
)
```
Returns: MAE value (Mean Absolute Error) in RM

## Data Models

### ForecastResult
```dart
class ForecastResult {
  DateTime date;              // Forecast date
  double forecastedAmount;    // Main forecast
  double lowerBound;          // 95% confidence lower
  double upperBound;          // 95% confidence upper
  bool isAnomaly;             // Unusual pattern flag
}
```

### HistoricalSpending
```dart
class HistoricalSpending {
  DateTime date;              // Transaction/aggregate date
  double amount;              // Amount spent
}
```

## Troubleshooting Checklist

- [ ] Import `budget_forecast_service.dart` in your screen
- [ ] Budget has at least 3 months of transaction history
- [ ] Check account/category/ledger is correctly filtered
- [ ] Verify Supabase connection is working
- [ ] Check logs for error messages
- [ ] Test with known data first

---

**For complete documentation**, see: `SMART_BUDGETING_FORECAST_GUIDE.md`
