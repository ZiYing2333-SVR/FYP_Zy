# Smart Budgeting API Documentation

## Complete API Reference

### BudgetForecastService

The main service class for all budget forecasting operations.

---

## Methods

### 1. `checkHighRiskAlert()`

Determines if a budget is at high risk based on forecast analysis.

**Signature**:
```dart
Future<bool> checkHighRiskAlert(
  String userId,
  String budgetId,
  double budgetAmount,
  String? accountId,
  String? categoryId,
  String? ledgerId,
)
```

**Parameters**:
- `userId` (String, required): The user's unique identifier
- `budgetId` (String, required): The budget's unique identifier
- `budgetAmount` (double, required): Budget limit in RM
- `accountId` (String?, optional): Account ID to filter transactions
- `categoryId` (String?, optional): Category ID to filter transactions
- `ledgerId` (String?, optional): Ledger ID to filter transactions

**Returns**: `Future<bool>`
- `true`: Budget is at high risk (forecast > budget AND upper bound > 120% budget)
- `false`: Budget is safe

**Throws**: None (errors are logged)

**Example**:
```dart
final forecastService = BudgetForecastService();

try {
  bool isHighRisk = await forecastService.checkHighRiskAlert(
    'user123',
    'budget456',
    3000.0,
    'account789',
    null,
    null,
  );
  
  if (isHighRisk) {
    showAlert('Your budget may be exceeded next month!');
  }
} catch (e) {
  print('Error: $e');
}
```

**High Risk Logic**:
```
High Risk = True IF:
  forecastedAmount > budgetAmount
  AND
  upperBound > (budgetAmount * 1.2)

ELSE: High Risk = False
```

---

### 2. `getForecast()`

Generates forecast predictions for upcoming months.

**Signature**:
```dart
Future<List<ForecastResult>> getForecast(
  String userId,
  String budgetId,
  String? accountId,
  String? categoryId,
  String? ledgerId,
  int forecastMonths,
)
```

**Parameters**:
- `userId` (String, required): User identifier
- `budgetId` (String, required): Budget identifier
- `accountId` (String?, optional): Filter by account
- `categoryId` (String?, optional): Filter by category
- `ledgerId` (String?, optional): Filter by ledger
- `forecastMonths` (int, required): Number of months to forecast (typically 3)

**Returns**: `Future<List<ForecastResult>>`

Array of forecast results with structure:
```dart
class ForecastResult {
  DateTime date;              // Forecast month
  double forecastedAmount;    // Predicted spending (RM)
  double lowerBound;          // 95% CI lower bound (RM)
  double upperBound;          // 95% CI upper bound (RM)
  bool isAnomaly;             // Unusual pattern flag
}
```

**Returns Empty List If**:
- Less than 3 months of historical data
- Invalid budget ID
- No transactions found

**Example**:
```dart
List<ForecastResult> forecast = await forecastService.getForecast(
  'user123',
  'budget456',
  'account789',
  null,
  null,
  3,
);

for (var result in forecast) {
  print('${result.date.month}/${result.date.year}: '
        'RM${result.forecastedAmount.toStringAsFixed(2)}');
  print('  Range: RM${result.lowerBound.toStringAsFixed(2)} - '
        'RM${result.upperBound.toStringAsFixed(2)}');
  
  if (result.isAnomaly) {
    print('  ⚠️ Unusual pattern detected');
  }
}
```

**Data Example**:
```dart
ForecastResult(
  date: DateTime(2026, 03, 01),
  forecastedAmount: 2400.50,
  lowerBound: 1832.40,
  upperBound: 2968.60,
  isAnomaly: false,
)
```

---

### 3. `getHistoricalData()`

Retrieves aggregated historical spending data.

**Signature**:
```dart
Future<List<HistoricalSpending>> getHistoricalData(
  String userId,
  String budgetId,
  String? accountId,
  String? categoryId,
  String? ledgerId,
)
```

**Parameters**:
- `userId` (String, required): User identifier
- `budgetId` (String, required): Budget identifier
- `accountId` (String?, optional): Filter by account
- `categoryId` (String?, optional): Filter by category
- `ledgerId` (String?, optional): Filter by ledger

**Returns**: `Future<List<HistoricalSpending>>`

Array of historical spending records:
```dart
class HistoricalSpending {
  DateTime date;    // Month (first day of month)
  double amount;    // Total spent that month (RM)
}
```

**Returns Empty List If**:
- No transactions found
- Invalid user/budget ID

**Example**:
```dart
List<HistoricalSpending> history = await forecastService.getHistoricalData(
  'user123',
  'budget456',
  null,
  'category789',
  null,
);

double totalSpent = 0;
for (var month in history) {
  print('${month.date.month}/${month.date.year}: RM${month.amount}');
  totalSpent += month.amount;
}

print('Total (12m): RM${totalSpent.toStringAsFixed(2)}');
print('Average: RM${(totalSpent / history.length).toStringAsFixed(2)}');
```

---

### 4. `calculateForecastAccuracy()`

Calculates Mean Absolute Error (MAE) for forecast reliability.

**Signature**:
```dart
Future<double> calculateForecastAccuracy(
  String userId,
  String budgetId,
  String? accountId,
  String? categoryId,
  String? ledgerId,
)
```

**Parameters**:
- Same as `getForecast()`

**Returns**: `Future<double>`
- `> 0`: MAE value in RM
- `-1`: Insufficient data (show user message)

**MAE Interpretation**:
```
MAE = RM 150
Meaning: Predictions deviate by ±RM 150 on average
Accuracy: Good if MAE < 10% of average monthly spending

Example:
Average monthly: RM 2500
MAE: RM 150
Deviation: 6% → Good accuracy ✓

Average monthly: RM 2500
MAE: RM 500
Deviation: 20% → Poor accuracy ⚠️
```

**Example**:
```dart
double mae = await forecastService.calculateForecastAccuracy(
  'user123',
  'budget456',
  'account789',
  null,
  null,
);

if (mae < 0) {
  print('Not enough data to calculate accuracy');
} else if (mae < 100) {
  print('Excellent forecast accuracy: ±RM${mae.toStringAsFixed(2)}');
} else if (mae < 200) {
  print('Good forecast accuracy: ±RM${mae.toStringAsFixed(2)}');
} else {
  print('Accuracy may vary: ±RM${mae.toStringAsFixed(2)}');
}
```

---

## Data Classes

### ForecastResult

Represents a single month's forecast prediction.

**Properties**:
```dart
DateTime date;           // Year and month of forecast
double forecastedAmount; // Main forecast (RM)
double lowerBound;       // 95% confidence lower bound (RM)
double upperBound;       // 95% confidence upper bound (RM)
bool isAnomaly;          // True if unusual pattern detected
```

**Usage**:
```dart
var forecast = ForecastResult(
  date: DateTime(2026, 3, 1),
  forecastedAmount: 2500.0,
  lowerBound: 1900.0,
  upperBound: 3100.0,
  isAnomaly: false,
);

print('Forecast for ${forecast.date}');
print('Expected: RM${forecast.forecastedAmount}');
print('Safe range: RM${forecast.lowerBound} - RM${forecast.upperBound}');
if (forecast.isAnomaly) {
  print('⚠️ Unusual pattern detected');
}
```

### HistoricalSpending

Represents actual monthly spending.

**Properties**:
```dart
DateTime date;    // Month (always first day of month)
double amount;    // Total spent that month (RM)
```

**Usage**:
```dart
var spending = HistoricalSpending(
  date: DateTime(2025, 12, 1),
  amount: 5000.0,
);

print('In ${spending.date.month}/${spending.date.year}, '
      'spent RM${spending.amount}');
```

---

## Error Handling

The service uses graceful error handling - no exceptions are thrown.

**Error Cases**:

| Scenario | Handling | Return |
|----------|----------|--------|
| No transactions found | Logged | Empty list / false |
| Invalid user ID | Logged | Empty list / false |
| Invalid budget ID | Logged | Empty list / false |
| <3 months data | Logged | Empty list / false |
| Database error | Logged | Empty list / false / -1 |
| Network error | Logged | Empty list / false / -1 |

**Best Practice**:
```dart
try {
  final forecast = await forecastService.getForecast(...);
  
  if (forecast.isEmpty) {
    print('Not enough data yet');
    return;
  }
  
  // Use forecast
} catch (e) {
  print('Unexpected error: $e');
}
```

---

## Constants

The service uses these internal constants:

```dart
static const int _minHistoricalMonths = 3;      // Minimum data
static const double _anomalyThreshold = 2.0;    // Z-score threshold
static const String _tag = '[BudgetForecastService]';
```

**To Modify**:
- Edit these constants in `budget_forecast_service.dart`
- Recompile the app
- No database changes needed

---

## Performance Considerations

### Typical Response Times
- First call: ~500ms (API queries + calculations)
- Subsequent calls: ~300ms (cached locally within screen)

### Network Usage
- Per forecast: 1-4 Supabase queries
- Data size: ~50-200KB per request

### Optimization Tips
```dart
// ✓ Good: Check all budgets in parallel
Future<List<bool>> results = Future.wait(
  budgets.map((b) => forecastService.checkHighRiskAlert(...))
);

// ✗ Avoid: Sequential checks
for (var budget in budgets) {
  await forecastService.checkHighRiskAlert(...);  // Slow
}
```

---

## Integration Examples

### Example 1: Dashboard Widget
```dart
class BudgetAlertWidget extends StatefulWidget {
  final String userId;
  
  @override
  State<BudgetAlertWidget> createState() => _BudgetAlertWidgetState();
}

class _BudgetAlertWidgetState extends State<BudgetAlertWidget> {
  final _forecastService = BudgetForecastService();
  bool _isHighRisk = false;
  
  @override
  void initState() {
    super.initState();
    _checkAlert();
  }
  
  Future<void> _checkAlert() async {
    // Get budgets and check for high risk
    final budgets = await Supabase.instance.client
        .from('Budget')
        .select()
        .eq('userId', widget.userId);
    
    bool hasRisk = false;
    for (var budget in budgets) {
      if (await _forecastService.checkHighRiskAlert(
        widget.userId,
        budget['budgetId'],
        (budget['amount'] ?? 0).toDouble(),
        budget['accountId'],
        budget['categoryId'],
        budget['ledgerId'],
      )) {
        hasRisk = true;
        break;
      }
    }
    
    setState(() => _isHighRisk = hasRisk);
  }
  
  @override
  Widget build(BuildContext context) {
    if (!_isHighRisk) {
      return SizedBox.shrink();
    }
    
    return Container(
      color: Color(0xFFFFEBEE),
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.warning, color: Color(0xFFE53935)),
          SizedBox(width: 12),
          Text('High-risk budget detected'),
        ],
      ),
    );
  }
}
```

### Example 2: Historical Analysis
```dart
class SpendingAnalyzer {
  final BudgetForecastService _forecastService = BudgetForecastService();
  
  Future<void> analyzeSpending(String userId, String budgetId) async {
    // Get historical data
    final history = await _forecastService.getHistoricalData(
      userId, budgetId, null, null, null
    );
    
    if (history.isEmpty) {
      print('No data');
      return;
    }
    
    // Calculate statistics
    final amounts = history.map((h) => h.amount).toList();
    final avg = amounts.reduce((a, b) => a + b) / amounts.length;
    final min = amounts.reduce((a, b) => a < b ? a : b);
    final max = amounts.reduce((a, b) => a > b ? a : b);
    
    print('Monthly Spending Analysis:');
    print('  Average: RM${avg.toStringAsFixed(2)}');
    print('  Min: RM${min.toStringAsFixed(2)}');
    print('  Max: RM${max.toStringAsFixed(2)}');
    print('  Range: RM${(max - min).toStringAsFixed(2)}');
  }
}
```

### Example 3: Forecast Display
```dart
class ForecastChart extends StatelessWidget {
  final String userId;
  final String budgetId;
  final double budgetLimit;
  
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ForecastResult>>(
      future: BudgetForecastService().getForecast(
        userId, budgetId, null, null, null, 3
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return CircularProgressIndicator();
        }
        
        final forecast = snapshot.data!;
        
        return Column(
          children: [
            for (var result in forecast)
              ListTile(
                title: Text('${result.date.month}/${result.date.year}'),
                subtitle: Text(
                  'RM${result.forecasted Amount.toStringAsFixed(2)} '
                  '(${(result.forecastedAmount / budgetLimit * 100).toStringAsFixed(0)}%)'
                ),
                trailing: result.forecastedAmount > budgetLimit
                    ? Icon(Icons.warning, color: Colors.red)
                    : Icon(Icons.check, color: Colors.green),
              ),
          ],
        );
      },
    );
  }
}
```

---

## Troubleshooting

### "Not enough historical data"
**Problem**: Forecast returns empty list
**Solution**: Wait until 3+ months of transactions exist
**Code**:
```dart
final forecast = await forecastService.getForecast(...);
if (forecast.isEmpty) {
  // Show message to user
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Insufficient Data'),
      content: Text('Please wait for 3+ months of transaction history.'),
    ),
  );
}
```

### "MAE is -1"
**Problem**: `calculateForecastAccuracy()` returns -1
**Solution**: Not enough data for backtesting (needs 6+ months)
**Code**:
```dart
double mae = await forecastService.calculateForecastAccuracy(...);
if (mae < 0) {
  print('Not enough data yet');
} else {
  print('MAE: RM${mae.toStringAsFixed(2)}');
}
```

### "Forecast seems inaccurate"
**Problem**: Predictions don't match reality
**Solution**: Check MAE value and review anomalies
**Code**:
```dart
final mae = await forecastService.calculateForecastAccuracy(...);
final forecast = await forecastService.getForecast(...);

// Check accuracy
if (mae > avgSpending * 0.2) {
  print('Low confidence - many anomalies detected');
}

// Review forecast
for (var result in forecast) {
  if (result.isAnomaly) {
    print('Anomaly in ${result.date}: ${result.forecastedAmount}');
  }
}
```

---

## Best Practices

1. **Always check for empty results**
   ```dart
   if (forecast.isEmpty) return; // Not enough data
   ```

2. **Handle async operations properly**
   ```dart
   Future<void> doAsync() async {
     try {
       final result = await forecastService.method(...);
     } catch (e) {
       print('Error: $e');
     }
   }
   ```

3. **Cache results when possible**
   ```dart
   var _cachedForecast;
   List<ForecastResult> getForecast() {
     return _cachedForecast ?? refreshForecast();
   }
   ```

4. **Provide user feedback**
   ```dart
   showLoadingDialog(); // Show before async call
   final result = await forecastService.method(...);
   dismissLoadingDialog(); // Hide after async call
   ```

5. **Log for debugging**
   ```dart
   print('[INFO] Checking budget alert for $budgetId');
   bool isHighRisk = await forecastService.checkHighRiskAlert(...);
   print('[RESULT] High risk: $isHighRisk');
   ```

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-02-10 | Initial implementation |

---

## Support

For issues or questions:
1. Check logs: `[BudgetForecastService]` messages
2. Review `SMART_BUDGETING_QUICK_REFERENCE.md`
3. Check `SMART_BUDGETING_FORECAST_GUIDE.md`

---

**Last Updated**: 2026-02-10  
**Status**: ✅ Complete
