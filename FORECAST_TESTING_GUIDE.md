# 🧪 Forecast Expenses Pattern - Testing Guide

## Quick Start: Test the Forecast Feature

### Prerequisites
- User must have at least **3+ months of expense data** for forecast to work
- Backend must be running at `https://fyp-zy.onrender.com`
- Flutter app must be connected to the backend

---

## 🔍 Test Method 1: Direct API Test

### Test Endpoint in Postman or cURL

```bash
curl -X POST https://fyp-zy.onrender.com/forecast \
  -H "Content-Type: application/json" \
  -d '{
    "historical_data": [
      {"date": "2025-02", "amount": 1200},
      {"date": "2025-03", "amount": 1300},
      {"date": "2025-04", "amount": 1350},
      {"date": "2025-05", "amount": 1220},
      {"date": "2025-06", "amount": 1180},
      {"date": "2025-07", "amount": 1280},
      {"date": "2025-08", "amount": 1320},
      {"date": "2025-09", "amount": 1150},
      {"date": "2025-10", "amount": 1200},
      {"date": "2025-11", "amount": 1280},
      {"date": "2025-12", "amount": 1420},
      {"date": "2026-01", "amount": 1190}
    ],
    "forecast_periods": 3,
    "budget_amount": 1000
  }'
```

**Expected Response:**
```json
{
  "forecast": [
    {
      "date": "2026-02-01",
      "predicted_amount": 1380.45,
      "lower_bound": 1250.23,
      "upper_bound": 1510.67,
      "is_anomaly": false
    },
    {
      "date": "2026-03-01",
      "predicted_amount": 1350.20,
      "lower_bound": 1220.10,
      "upper_bound": 1480.30,
      "is_anomaly": false
    },
    {
      "date": "2026-04-01",
      "predicted_amount": 1320.15,
      "lower_bound": 1190.05,
      "upper_bound": 1450.25,
      "is_anomaly": false
    }
  ],
  "mae": 45.32,
  "has_sufficient_data": true,
  "alert_status": "normal",
  "alert_message": "Expenses within expected range"
}
```

---

## 📱 Test Method 2: In Flutter App

### Step 1: Enable Console Logs
The app already includes debug logs. Check your Flutter console:

```
[FlutterApp] [getSpendingForecast] Fetching spending forecast for 3 month(s) ahead
[FlutterApp] [getSpendingForecast] Step 1: Querying expenses from past year
[FlutterApp] [getSpendingForecast] Found 75 expense transactions in past 12 months
[FlutterApp] [getSpendingForecast] Step 2: Aggregating expenses by month
[FlutterApp] [getSpendingForecast] Step 3: Prepared 12 months of data for forecast
[FlutterApp] [getSpendingForecast] Step 4: Calling Forecast API...
[FlutterApp] [getSpendingForecast] ✅ Forecast received successfully
```

### Step 2: Test with Code Snippet

Add this to any screen's `initState()` to test:

```dart
void _testForecast() async {
  try {
    print('🧪 Starting Forecast Test...');
    
    final userId = Supabase.instance.client.auth.currentSession?.user.id ?? '';
    
    // Test 1: Get Forecast
    print('\n📊 Test 1: Getting spending forecast...');
    final forecast = await IntelligentSavingsGoalAssistant.getSpendingForecast(
      userId,
      periodsAhead: 3,
    );
    
    print('✅ Forecast Result:');
    print('   Success: ${forecast.success}');
    print('   Forecast Values: ${forecast.forecast}');
    print('   Confidence: ${(forecast.confidence * 100).toStringAsFixed(1)}%');
    print('   Period: ${forecast.period}');
    
    // Test 2: Get Suggestion (requires past spending)
    if (forecast.success && forecast.forecast.isNotEmpty) {
      print('\n💡 Test 2: Generating spending suggestion...');
      
      // Mock past 6 months of spending
      final pastSpending = [1200, 1250, 1300, 1350, 1400, 1380];
      
      final suggestion = await IntelligentSavingsGoalAssistant.generateSpendingSuggestion(
        userId,
        pastSpending,
        forecast.forecast,
      );
      
      print('✅ Suggestion Result:');
      print('   Success: ${suggestion.success}');
      print('   Suggestion: ${suggestion.suggestion}');
      print('   Severity: ${suggestion.severity}');
      print('   Trend Change: ${suggestion.trendChange.toStringAsFixed(1)}%');
      print('   Action Items: ${suggestion.actionItems}');
      print('   Confidence: ${suggestion.confidenceLevel}');
    }
    
    // Test 3: Get Category Advice
    print('\n🏷️ Test 3: Analyzing category spending...');
    final advice = await IntelligentSavingsGoalAssistant.getCategorySpendingAdvice(userId);
    
    print('✅ Category Advice Result:');
    for (var cat in advice) {
      print('   ${cat.categoryName}: ${cat.percentOfTotal.toStringAsFixed(1)}%');
      print('      Advice: ${cat.advice}');
      print('      Concerning: ${cat.isConcerning}');
      print('      Tips: ${cat.savingtips.join(", ")}');
    }
    
    print('\n✅ All tests completed!');
    
  } catch (e) {
    print('❌ Test error: $e');
  }
}

// Call in initState:
// _testForecast();
```

### Step 3: View Console Output
Open your IDE's debug console and look for:
- ✅ Success messages = API working
- ⚠️ Warning messages = Missing data
- ❌ Error messages = API connection issue

---

## 🎯 Expected Console Output (Successful)

```
═══════════════════════════════════════════════════════════════════════
                         🧪 FORECAST TEST START
═══════════════════════════════════════════════════════════════════════

🧪 Starting Forecast Test...

📊 Test 1: Getting spending forecast...
[FlutterApp] [getSpendingForecast] Fetching spending forecast for 3 month(s) ahead
[FlutterApp] [getSpendingForecast] Step 1: Querying expenses from past year
[FlutterApp] [getSpendingForecast] Found 75 expense transactions in past 12 months
[FlutterApp] [getSpendingForecast] Step 2: Aggregating expenses by month
[FlutterApp] [getSpendingForecast] Monthly Spending:
[FlutterApp]   2025-02: 1150.50
[FlutterApp]   2025-03: 1200.75
[FlutterApp]   2025-04: 1350.25
[FlutterApp]   2025-05: 1220.00
[FlutterApp]   2025-06: 1180.40
[FlutterApp]   2025-07: 1280.60
[FlutterApp]   2025-08: 1320.30
[FlutterApp]   2025-09: 1150.80
[FlutterApp]   2025-10: 1200.00
[FlutterApp]   2025-11: 1280.50
[FlutterApp]   2025-12: 1420.75
[FlutterApp]   2026-01: 1190.20
[FlutterApp] [getSpendingForecast] Step 3: Prepared 12 months of data for forecast
[FlutterApp] [getSpendingForecast] Data: [{date: 2025-02, value: 1150.50}, ...]
[FlutterApp] [getSpendingForecast] Step 4: Calling Forecast API...
[FlutterApp] [getSpendingForecast] Sending request to /forecast endpoint
[FlutterApp] [getSpendingForecast] Request body: {
  historical_data: [
    {date: 2025-02, amount: 1150.50},
    ...
  ],
  forecast_periods: 3,
  budget_amount: 1000.0
}
[FlutterApp] [getSpendingForecast] ✅ Forecast received successfully
[FlutterApp] [getSpendingForecast] Response: {
  forecast: [
    {date: 2026-02-01, predicted_amount: 1380.45, ...},
    {date: 2026-03-01, predicted_amount: 1350.20, ...},
    {date: 2026-04-01, predicted_amount: 1320.15, ...}
  ],
  mae: 45.32,
  has_sufficient_data: true,
  alert_status: normal,
  ...
}

✅ Forecast Result:
   Success: true
   Forecast Values: [1380.45, 1350.20, 1320.15]
   Confidence: 95.5%
   Period: month

💡 Test 2: Generating spending suggestion...
[FlutterApp] [generateSpendingSuggestion] Generating suggestion from forecast
[FlutterApp] [generateSpendingSuggestion] Past avg: RM1,245.83
[FlutterApp] [generateSpendingSuggestion] Forecast: RM1,380.45
[FlutterApp] [generateSpendingSuggestion] Change: +10.8%

✅ Suggestion Result:
   Success: true
   Suggestion: Your spending is trending up by 10.8%. Keep track of expenses 
               and look for areas to cut back.
   Severity: medium
   Trend Change: +10.8%
   Action Items: [Monitor spending over next 2 weeks, Review major categories, 
                  Identify discretionary vs essential expenses, Look for 5-10% reduction]
   Confidence: high

🏷️ Test 3: Analyzing category spending...
[FlutterApp] [getCategorySpendingAdvice] Analyzing category spending distribution
[FlutterApp] [getCategorySpendingAdvice] Fetching past 3 months of category data

✅ Category Advice Result:
   Food & Dining: 36.5%
      Advice: Your food & dining spending is high. Consider meal planning and cooking 
              at home more often to reduce expenses.
      Concerning: true
      Tips: Meal plan for the week, Cook at home, Pack lunch, Set weekly budget

   Transport: 24.2%
      Advice: Transportation costs are reasonable. Continue monitoring and look for 
              alternatives to reduce if needed.
      Concerning: false
      Tips: Carpool with colleagues, Use public transport, Plan efficient routes

   Entertainment: 18.3%
      Advice: Entertainment spending could be reduced. Explore free or low-cost options 
              in your area.
      Concerning: false
      Tips: Look for free events, Set monthly entertainment budget, Join free groups

   Utilities: 12.0%
      Advice: Utility costs are well-managed. Small savings possible with LED and thermostat.
      Concerning: false
      Tips: Switch to LED bulbs, Use smart thermostat, Unplug devices

   Healthcare: 9.0%
      Advice: Healthcare spending is reasonable. Maintain current coverage and preventive care.
      Concerning: false
      Tips: Keep health insurance current, Schedule regular check-ups

═══════════════════════════════════════════════════════════════════════

✅ All tests completed!

═══════════════════════════════════════════════════════════════════════
```

---

## ❌ Troubleshooting: Common Issues

### Issue 1: "API error: 404" or "API error: 400"

**Cause:** Wrong endpoint path  
**Solution:** Check that the endpoint is `/forecast` not `/api/forecast/spending`

```dart
// ✅ CORRECT
Uri.parse('$_backendUrl/forecast')

// ❌ WRONG
Uri.parse('$_backendUrl/api/forecast/spending')
```

### Issue 2: "No expense data found for forecast"

**Cause:** User has <3 months of expense data  
**Solution:** 
- Add at least 3 months of transaction data
- Test only with users having 12 months of history

### Issue 3: "Response: null" or Decode Error

**Cause:** Bad response data  
**Solution:** Add more error logging:

```dart
print('Status Code: ${response.statusCode}');
print('Response Body: ${response.body}');
print('Content-Type: ${response.headers['content-type']}');
```

### Issue 4: Backend Returns Different Format

**Cause:** Backend version mismatch  
**Solution:** Verify backend response format matches:

```json
{
  "forecast": [
    {
      "date": "...",
      "predicted_amount": 1400.5,
      "lower_bound": 1250.0,
      "upper_bound": 1550.0,
      "is_anomaly": false
    }
  ],
  "mae": 45.32,
  "has_sufficient_data": true,
  "alert_status": "...",
  "alert_message": "..."
}
```

---

## ✅ Verification Checklist

After implementation:

- [ ] Endpoint path corrected to `/forecast`
- [ ] Request body format matches backend expectation
- [ ] ForecastResult.fromJson() parses new format correctly
- [ ] Console logs show "✅ Forecast received successfully"
- [ ] Confidence calculated from MAE
- [ ] SpendingSuggestion generates correct severity
- [ ] CategorySpendingAdvice categories identified correctly
- [ ] Test with 12 months of data works
- [ ] Test with 3 months of data works
- [ ] Error handling for <3 months of data
- [ ] All console logs visible in debug output

---

## 📊 Sample Data for Testing

If you don't have enough real transaction data, use this SQL to add test transactions:

```sql
-- Insert 12 months of expense data
INSERT INTO public."Transaction" (userId, amount, "type", categoryId, date, description) VALUES
('user-id-here', 1200.00, 'expense', 'cat-id', '2025-02-15', 'Monthly expenses'),
('user-id-here', 1280.00, 'expense', 'cat-id', '2025-03-15', 'Monthly expenses'),
('user-id-here', 1350.00, 'expense', 'cat-id', '2025-04-15', 'Monthly expenses'),
('user-id-here', 1220.00, 'expense', 'cat-id', '2025-05-15', 'Monthly expenses'),
('user-id-here', 1180.00, 'expense', 'cat-id', '2025-06-15', 'Monthly expenses'),
('user-id-here', 1280.00, 'expense', 'cat-id', '2025-07-15', 'Monthly expenses'),
('user-id-here', 1320.00, 'expense', 'cat-id', '2025-08-15', 'Monthly expenses'),
('user-id-here', 1150.00, 'expense', 'cat-id', '2025-09-15', 'Monthly expenses'),
('user-id-here', 1200.00, 'expense', 'cat-id', '2025-10-15', 'Monthly expenses'),
('user-id-here', 1280.00, 'expense', 'cat-id', '2025-11-15', 'Monthly expenses'),
('user-id-here', 1420.00, 'expense', 'cat-id', '2025-12-15', 'Monthly expenses - Holiday'),
('user-id-here', 1190.00, 'expense', 'cat-id', '2026-01-15', 'Monthly expenses');
```

---

## 🎓 Understanding the Output

### Forecast Values
- **[1380.45, 1350.20, 1320.15]** = Predicted spending for next 3 months
- Values use Prophet's seasonal decomposition
- Based on trends and patterns from past 12 months

### Confidence (95.5%)
- High confidence = Stable spending pattern
- Low confidence = Irregular or volatile spending
- Calculated from MAE (prediction error)

### Severity (Medium)
- 🟢 LOW: <10% increase (stable)
- 🟡 MEDIUM: 10-20% increase (watch)
- 🔴 HIGH: >20% increase (urgent)

### Alert Status
- "normal" = Expenses within expected range
- "warning" = Expenses above typical
- "critical" = Expenses significantly above budget

---

## 📱 Next Steps: Display Results

Once testing confirms the API works:

1. Create a **Smart Insights Screen** to display forecast
2. Add **Forecast Alert Widget** to home screen
3. Integrate with **Savings Goal Pages**
4. Add **Category Advice Cards**
5. Create **Notification System** for critical alerts

Each display location gets different formatted output (cards, charts, alerts).

---

## 💡 Final Note

The console already has detailed logging built in. When you run the test:
- Watch for ✅ success messages
- Note any ❌ error messages
- Check timing of API calls
- Verify data aggregation is correct

All this helps debug any remaining issues quickly!
