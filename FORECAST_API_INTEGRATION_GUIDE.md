# 🔮 Forecast API Integration Guide

## Overview
Your intelligent savings service now includes **AI-powered spending forecasts** using Prophet algorithm integrated with your Flutter app.

---

## 📊 What's New

### Three Core Features Added:

#### 1️⃣ **Spending Forecast with Prophet**
```dart
final forecast = await IntelligentSavingsGoalAssistant.getSpendingForecast(
  userId,
  periodsAhead: 3,
  period: 'month',
);

if (forecast.success) {
  print('Next 3 months forecast: ${forecast.forecast}');
  // Output: [1350, 1400, 1450] (predicted spending)
}
```

**What it does:**
- Fetches last 12 months of expense data from Transaction table
- Groups by month (YYYY-MM format)
- Sends to backend: POST `/api/forecast/spending`
- Returns array of predicted spending values

**Data Flow:**
```
App → Query Transaction(type='expense', past 12 months)
    → Group by month
    → POST to /api/forecast/spending
    → Returns: {forecast: [1350, 1400, 1450], confidence: 0.87}
```

---

#### 2️⃣ **Smart Spending Suggestions**
```dart
final pastSpending = [1200, 1300, 1250, 1400, 1350, 1380];
final forecast = [1450]; // From step 1

final suggestion = await IntelligentSavingsGoalAssistant.generateSpendingSuggestion(
  userId,
  pastSpending,
  forecast,
);

// Result:
// suggestion.suggestion: "Your spending is trending up (+7.4%). Keep track of expenses and look for areas to cut back."
// suggestion.severity: "medium"
// suggestion.actionItems: ["Monitor spending over next 2 weeks", "Review major categories", ...]
```

**How it works:**
- Calculates average of past spending: `avg(1200, 1300, ...) = 1313`
- Compares to forecast: `1450 - 1313 = +137 (+10.4%)`
- Generates 3 severity levels:
  - **HIGH** (>20% increase): "Reduce discretionary expenses by 10-15%"
  - **MEDIUM** (10-20%): "Keep track and look for areas to cut"
  - **LOW** (<10%): "Good job, spending is stable"

---

#### 3️⃣ **Category-Based Spending Advice**
```dart
final categoryAdvice = await IntelligentSavingsGoalAssistant.getCategorySpendingAdvice(
  userId,
  lookbackMonths: 3,
);

for (var advice in categoryAdvice) {
  print('${advice.categoryName}: ${advice.percentOfTotal}%');
  print('Advice: ${advice.advice}');
  print('Tips: ${advice.savingtips}');
}

// Output:
// Food: 35% of total
// Advice: Food & dining is your largest expense. Consider meal planning and cooking at home.
// Tips: [Meal plan for the week, Cook at home, Pack lunch, Set weekly budget]
```

**Category Intelligence:**
- **Food >30%**: "Meal plan and cook at home"
- **Transport >25%**: "Consider carpooling or public transit"
- **Entertainment >20%**: "Explore free or low-cost options"
- **Utilities >15%**: "Switch to LED, use smart thermostat"
- **Generic**: Review expenses and set monthly limits

---

## 🎯 How to Use in UI

### Example 1: Smart Insights Page
```dart
class SmartInsightsPage extends StatefulWidget {
  @override
  State<SmartInsightsPage> createState() => _SmartInsightsPageState();
}

class _SmartInsightsPageState extends State<SmartInsightsPage> {
  @override
  void initState() {
    super.initState();
    _loadInsights();
  }

  Future<void> _loadInsights() async {
    final userId = Supabase.instance.client.auth.currentSession?.user.id ?? '';
    
    // Get forecast
    final forecast = await IntelligentSavingsGoalAssistant.getSpendingForecast(
      userId,
      periodsAhead: 1,
    );
    
    // Get past 6 months for comparison
    final avgMonthly = await IntelligentSavingsGoalAssistant._getAverageMonthlyExpenses(userId);
    
    // Get suggestion
    final suggestion = await IntelligentSavingsGoalAssistant.generateSpendingSuggestion(
      userId,
      [1200, 1250, 1300, 1350, 1400, 1380], // Past 6 months
      forecast.forecast,
    );
    
    // Get category advice
    final advice = await IntelligentSavingsGoalAssistant.getCategorySpendingAdvice(userId);
    
    setState(() {
      // Update UI with results
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Smart Insights')),
      body: ListView(
        children: [
          // Forecast Card
          Card(
            child: Column(
              children: [
                Text('Next Month Prediction'),
                Text(
                  'RM${forecast.forecast.first.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          
          // Suggestion Card
          Card(
            color: suggestion.severity == 'high' ? Colors.red[100] : Colors.blue[100],
            child: Column(
              children: [
                Text(suggestion.suggestion),
                SizedBox(height: 8),
                ...suggestion.actionItems.map((item) => Text('• $item')),
              ],
            ),
          ),
          
          // Category Breakdown
          ...advice.map((cat) => ListTile(
            title: Text('${cat.categoryName}: ${cat.percentOfTotal.toStringAsFixed(1)}%'),
            subtitle: Text(cat.advice),
          )),
        ],
      ),
    );
  }
}
```

---

### Example 2: Budget Forecast Page Integration
```dart
// Add to your existing BudgetForecastingScreen
Future<void> _loadSmartForecast() async {
  final userId = Supabase.instance.client.auth.currentSession?.user.id ?? '';
  
  try {
    // Step 1: Get Prophet forecast
    final forecast = await IntelligentSavingsGoalAssistant.getSpendingForecast(
      userId,
      periodsAhead: 3,
      period: 'month',
    );

    if (forecast.success) {
      print('Prophet Forecast: ${forecast.forecast}');
      
      // Step 2: Compare with user's goal
      final goal = widget.goal;
      final predictedVsGoal = forecast.forecast.first - goal.monthlyTarget;
      
      // Step 3: Show warning if exceeding goal
      if (predictedVsGoal > 0) {
        _showForecastWarning(
          'Your spending may exceed target by RM${predictedVsGoal.toStringAsFixed(2)} next month',
        );
      }
    }
  } catch (e) {
    print('Error loading forecast: $e');
  }
}
```

---

## 🔧 Backend Requirements

Your backend needs TWO endpoints:

### 1. **Forecast Endpoint** (Prophet)
```
POST /api/forecast/spending
Content-Type: application/json

{
  "user_id": "123abc",
  "data": [
    {"date": "2025-01", "value": 1200},
    {"date": "2025-02", "value": 1300},
    {"date": "2025-03", "value": 1250},
    ...
  ],
  "periods": 1,
  "period_type": "month"
}

Response:
{
  "success": true,
  "forecast": [1350],
  "period": "month",
  "periods_ahead": 1,
  "confidence": 0.87
}
```

### 2. **Backend must use Prophet**
If you haven't set up Prophet forecasting yet, your backend needs:

```python
# backend/main.py
from statsmodels.tsa.holtwinters import ExponentialSmoothing
from statsmodels.tsa.arima.model import ARIMA
# OR use Prophet:
# from prophet import Prophet

@app.post('/api/forecast/spending')
async def forecast_spending(request: ForecastRequest):
    # Convert request data to time series
    # Run Prophet or ARIMA
    # Return predictions
    pass
```

---

## 📱 Integration Checklist

- [ ] Add the 3 new models to service
- [ ] Add the 3 new methods to service
- [ ] Test `getSpendingForecast()` with your backend
- [ ] Create UI page for Smart Insights
- [ ] Add suggestion card with severity colors
- [ ] Add category breakdown list
- [ ] Test with real transaction data

---

## 🎨 UI Suggestions

### Severity Color Codes
```dart
// High: Red (spending increasing >20%)
color: Color(0xFFEF5350) // #EF5350

// Medium: Orange (spending increasing 10-20%)
color: Color(0xFFFFA726) // #FFA726

// Low: Green (spending stable)
color: Color(0xFF66BB6A) // #66BB6A
```

### Icons
```dart
// High: ⚠️ warning_amber_outlined
// Medium: 📊 show_chart_outlined
// Low: ✅ check_circle_outlined
```

---

## 🐛 Troubleshooting

**Q: Forecast returns empty array?**
A: Your Transaction table needs at least 12 months of expense data. Check:
```dart
// Verify transactions exist
final count = await Supabase.instance.client
  .from('Transaction')
  .select()
  .eq('type', 'expense')
  .count();
```

**Q: Suggestions showing "low confidence"?**
A: You need more than 6 months of data for high confidence. Currently:
- <3 months: "low"
- 3-6 months: "medium"
- >12 months: "high"

**Q: Backend returning 500 error?**
A: Check if Prophet is installed and your API key is correctly set.

---

## 🚀 Next Steps

1. **Test the three methods** with your user data
2. **Create Smart Insights page** showing all three features
3. **Add to Dashboard** with key metrics
4. **Implement notifications** when spending trend is "high"
5. **Add historical tracking** (maintain previous predictions)

---

## 📚 Data Flow Summary

```
┌─────────────────┐
│   Flutter App   │
└────────┬────────┘
         │
         ├─→ Query Transaction (past 12 months)
         │
         ├─→ Group by month
         │
         ├─→ POST /api/forecast/spending
         │
         ├─→ Receive: {forecast: [1350, 1400, 1450]}
         │
         ├─→ Compare with history
         │
         └─→ Generate Suggestions + Category Advice
              │
              └─→ Display in UI with colors & tips
```

---

Good luck with your FYP! 🎉
