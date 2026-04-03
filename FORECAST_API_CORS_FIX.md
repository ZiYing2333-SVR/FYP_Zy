# Forecast API CORS Issue & Solution

**Status:** ⚠️ ACTION REQUIRED  
**Problem:** Browser CORS error when calling Forecast API directly  
**Error:** `ClientException: Failed to fetch`

---

## Problem Analysis

### Current Error
```
[BudgetForecastService] Network Error: ClientException: Failed to fetch, uri=https://forecastapi.com/v2/forecast
```

### Root Cause
The Flutter web app (running on Edge browser) is trying to call `https://forecastapi.com/v2/forecast` directly. The Forecast API likely has **CORS restrictions** that block browser requests.

**CORS = Cross-Origin Resource Sharing** - Security feature that prevents unauthorized domain access.

---

## Solution Options

### ✅ RECOMMENDED: Use a Backend Proxy

Create a simple backend endpoint that forwards requests to Forecast API. This works because:
- Server-to-server calls don't have CORS restrictions
- Backend can protect your API key
- Better security overall

#### Implementation Steps:

**1. Backend Endpoint (Flask/Python)**

Create a new endpoint in your backend:

```python
# routes/forecast.py
from flask import Blueprint, request, jsonify
import requests

forecast_bp = Blueprint('forecast', __name__)

FORECAST_API_KEY = 'YOUR_JWT_KEY_HERE'
FORECAST_API_URL = 'https://forecastapi.com/v2/forecast'

@forecast_bp.route('/api/forecast', methods=['POST'])
def proxy_forecast():
    """Proxy endpoint for Forecast API"""
    try:
        data = request.get_json()
        
        headers = {
            'Authorization': f'Bearer {FORECAST_API_KEY}',
            'Content-Type': 'application/json'
        }
        
        response = requests.post(
            FORECAST_API_URL,
            json=data,
            headers=headers,
            timeout=15
        )
        
        return jsonify(response.json()), response.status_code
    except Exception as e:
        return jsonify({'error': str(e)}), 500
```

**2. Update Flutter Code**

```dart
// In budget_forecast_service.dart
static const String _forecastApiUrl = 'YOUR_BACKEND_URL/api/forecast';
// Remove API key from frontend
// static const String _apiKey = '...'; // DELETE THIS

// In _callForecastAPI():
final response = await http.post(
  Uri.parse(_forecastApiUrl),
  headers: {
    'Content-Type': 'application/json',
    // No Authorization header needed - backend handles it
  },
  body: jsonEncode(requestBody),
).timeout(_timeout);
```

---

### Alternative: Enable CORS on Forecast API

If Forecast API allows CORS configuration:

1. Contact Forecast API support to enable CORS for your domain
2. Add your domain to their CORS whitelist
3. Update the request headers in Flutter to include CORS headers

---

### Alternative: Server-Side Rendering

If using Flutter Web with SSR capabilities, the backend can handle all API calls.

---

## Updated Intelligent Savings Goal Feasibility

The `analyzeGoalFeasibility()` method now requires additional parameters to forecast expenses:

### New Signature
```dart
static Future<GoalFeasibilityResult> analyzeGoalFeasibility({
  required String userId,                // For querying spending history
  required double monthlyIncome,         // User's income
  required double monthlyExpenses,       // Current avg expenses
  required double goalAmount,            // Savings goal
  required int timelineMonths,           // Timeline to reach goal
  String? budgetId,                      // Optional: specific budget
  String? accountId,                     // Optional: specific account
  String? categoryId,                    // Optional: specific category
  String? ledgerId,                      // Optional: specific ledger
}) async {
```

### What It Does

1. **Fetches spending forecast** using `getSpendingForecast()`
   - Uses historical spending data
   - Predicts next N months of expenses
   - Accounts for spending trends

2. **Calculates feasibility** using forecasted expenses
   - Income vs Forecasted Expenses = Savings Capacity
   - Compares against Required Monthly Savings

3. **Returns analysis** with confidence level
   - ✅ HIGH: Goal is achievable
   - ⚠️ LOW: Goal requires adjustments

### Example Usage

```dart
final feasibility = await IntelligentSavingsGoalAssistant.analyzeGoalFeasibility(
  userId: userId,                    // REQUIRED
  monthlyIncome: 5000,               // From income validation
  monthlyExpenses: 3000,             // Current average
  goalAmount: 10000,                 // User's goal
  timelineMonths: 6,                 // 6 months to save
  accountId: selectedAccountId,      // Optional
);

if (feasibility.isFeasible) {
  print('✅ Goal is achievable!');
  print('Monthly savings: RM${feasibility.monthlySavings.toStringAsFixed(2)}');
  print('Confidence: ${feasibility.confidenceLevel}');
} else {
  print('⚠️ Goal needs adjustment');
  print('${feasibility.analysis}');
  feasibility.suggestions.forEach((s) => print('- $s'));
}
```

---

## Console Log Example (After CORS Fix)

```
[BudgetForecastService] Calling Forecast API at https://YOUR_BACKEND_URL/api/forecast
[BudgetForecastService] Request: {"data":[...], "periods": 3}
[BudgetForecastService] API Response Status: 200
[BudgetForecastService] Successfully parsed 3 forecast points

[IntelligentSavingsGoalAssistant] [analyzeGoalFeasibility] Using forecasted monthly expense: RM2850.50
✅ Your goal is achievable! Based on your income (RM5000) and forecasted expenses (RM2850.50), 
you can save RM2149.50/month and reach RM10000 in 5 months.
```

---

## Next Steps

### Immediate (Fix CORS)
1. Set up backend proxy endpoint (Python/Flask)
2. Update Flutter code to use new endpoint
3. Remove API key from client code
4. Test with `flutter run`

### Short Term
1. Update all screens calling `analyzeGoalFeasibility()` with new parameters
2. Add expense forecasting to savings goal creation flow
3. Display forecast-based feasibility in UI

### Integration Points

Need to update these screens/services:

```dart
// Screens that analyze goals
// TODO: Find and update these files:
- lib/screens/savings_goal_screen.dart (if exists)
- lib/screens/ai_features_screen.dart
- Any page showing goal feasibility
```

---

## Files Modified

### ✅ Updated Services
- `lib/services/intelligent_savings_goal_assistant_service.dart`
  - `analyzeGoalFeasibility()` - Now uses expense forecast
  - `getSmartRecommendations()` - Client-side logic  
  - `simulateScenarios()` - Client-side logic
  - `generateNaturalLanguageReport()` - Client-side logic

- `lib/services/budget_forecast_service.dart`
  - Removed backend health check
  - All calls now use Forecast API

---

## Testing

### Step 1: Verify Backend Proxy
```bash
curl -X POST http://YOUR_BACKEND_URL/api/forecast \
  -H "Content-Type: application/json" \
  -d '{
    "data": [
      {"date": "2026-01", "value": 1200},
      {"date": "2026-02", "value": 1350},
      {"date": "2026-03", "value": 1400}
    ],
    "periods": 3
  }'
```

Expected response:
```json
{
  "forecast": [
    {"date": "2026-04", "value": 1420.5},
    {"date": "2026-05", "value": 1405.2},
    {"date": "2026-06", "value": 1390.8}
  ]
}
```

### Step 2: Flutter Run
```bash
flutter clean
flutter run
# Check console - should show successful forecast calls
```

### Step 3: Savings Goal Analysis
Test the updated `analyzeGoalFeasibility()` by:
1. Creating a new savings goal
2. Checking if feasibility shows forecasted expenses
3. Verifying analysis matches income + forecast

---

## Security Best Practices

✅ **DO:**
- Store API key in backend environment variable
- Validate all inputs before forwarding
- Rate limit proxy endpoint
- Log all forecast requests
- Use HTTPS for backend calls

❌ **DON'T:**
- Store API key in Flutter code (client-side)
- Expose raw API endpoint to frontend
- Trust user-submitted data without validation

---

## FAQ

**Q: Why is the error "Failed to fetch" and not a specific HTTP error?**
A: Browsers throw generic "Failed to fetch" for CORS violations to protect security.

**Q: Can I use Firebase Cloud Functions instead?**
A: Yes! Cloud Functions can act as a proxy similar to the Flask endpoint.

**Q: Will this slow down the app?**
A: Negligibly. Backend proxy adds <100ms latency vs. direct call.

**Q: What if Forecast API keys expire?**
A: They're stored on backend, easier to rotate without app update.

---

## Summary

| Aspect | Issue | Solution |
|--------|-------|----------|
| **CORS Error** | Direct browser → API call blocked | Use backend proxy |
| **Security** | API key exposed in client code | Move to backend env var |
| **Forecasting** | Missing expense predictions | Updated analyzeGoalFeasibility() |
| **Feasibility** | Only income-based check | Now uses income + expense forecast |
| **Confidence** | Low trust in analysis | High with forecasted data |

---

**Status:** Ready for implementation  
**Priority:** HIGH - Blocks forecast feature  
**Effort:** 30-45 minutes for backend proxy + testing
