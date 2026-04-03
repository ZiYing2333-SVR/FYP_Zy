# 🔍 Forecast API Timeout - Debugging Guide

## Problem
```
[BudgetForecastService] Error calling forecast API: 
TimeoutException after 0:00:30.000000: Future not completed
```

The Flutter app can't reach the forecast API within 30 seconds.

---

## Step 1: Check Backend Status

### In Browser (Quickest)
Visit: `https://fyp-zy.onrender.com/docs`

**Expected:** Swagger API documentation loads  
**If Error:** 502, 503, or timeout → Backend is down

### With cURL (Alternative)
```bash
curl -v https://fyp-zy.onrender.com/docs
```

**Expected:** HTTP 200 + HTML content  
**If Error:** Connection refused, timeout → Backend issue

---

## Step 2: Test Forecast Endpoint Directly

### With cURL
```bash
curl -X POST https://fyp-zy.onrender.com/forecast \
  -H "Content-Type: application/json" \
  -d '{
    "historical_data": [
      {"date": "2026-01-01", "amount": 100},
      {"date": "2026-02-01", "amount": 150},
      {"date": "2026-03-01", "amount": 200}
    ],
    "forecast_periods": 3,
    "budget_amount": 150
  }' \
  --max-time 45
```

**Expected:** JSON response within 10-45 seconds  
**If Timeout:** Request takes >45 seconds  
**If Error:** Check error message

### With Postman
1. New POST request
2. URL: `https://fyp-zy.onrender.com/forecast`
3. Body (JSON):
```json
{
  "historical_data": [
    {"date": "2026-01-01", "amount": 100},
    {"date": "2026-02-01", "amount": 150},
    {"date": "2026-03-01", "amount": 200}
  ],
  "forecast_periods": 3,
  "budget_amount": 150
}
```
4. Set timeout to 60000ms (60 seconds)
5. Send

---

## Step 3: Check Backend Logs on Render

### Go to Render Dashboard
1. Visit `https://dashboard.render.com`
2. Select your service (fyp-zy)
3. Click **Logs** tab
4. Scroll to when timeout happened
5. Look for:
   - Python errors
   - Prophet model training logs
   - Request received messages

**Expected Logs:**
```
Starting server...
Application startup complete [uvicorn]
POST /forecast
Prophet model initialized
Forecast generated successfully
```

**Problem Logs:**
```
ERROR: Exception in ASGI application
Traceback (most recent call last):
  File "main.py", line 216, in generate_forecast
MemoryError: Unable to allocate memory for Prophet
```

---

## Step 4: Likely Causes & Solutions

### Cause 1: Backend Server Sleeping (Render Free Plan)

**Symptom:** First request takes 30+ seconds (cold start)

**Solution:** 
- Upgrade Render plan OR
- Increase timeout to 60 seconds
- Use a monitoring service to keep server warm

**Fix in Code:**
```dart
// lib/services/budget_forecast_service.dart
static const Duration _timeout = Duration(seconds: 60);

// lib/services/intelligent_savings_goal_assistant_service.dart  
// Add at top:
static const Duration _timeout = Duration(seconds: 60);
```

---

### Cause 2: Backend Python Dependencies Missing

**Symptom:** Server starts but crashes on first `/forecast` call

**Solution:** Check backend logs for `ModuleNotFoundError`

**Fix in Backend:**
```bash
cd backend
pip install -r requirements.txt
```

---

### Cause 3: Prophet Model Training Too Slow

**Symptom:** Endpoint responds but takes >60 seconds

**Solution:** 
- Use Prophet with fewer components
- Or use a simpler forecasting model for <12 months data

**Fix in Backend (main.py):**
```python
# Make Prophet faster
model = Prophet(
    yearly_seasonality=False,  # Disable for faster training
    weekly_seasonality=False,
    daily_seasonality=False,
    interval_width=0.95,
    changepoint_prior_scale=0.05,
    changepoint_range=0.8,
    seasonality_mode='additive',
)
```

---

### Cause 4: Server Out of Memory

**Symptom:** Render logs show "MemoryError"

**Solution:** 
- Upgrade Render instance size
- Reduce historical data window
- Or run locally

---

## Step 5: Increase Timeout as Temporary Fix

### File 1: `lib/services/budget_forecast_service.dart`

Find (Line ~50):
```dart
static const Duration _timeout = Duration(seconds: 30);
```

Replace with:
```dart
static const Duration _timeout = Duration(seconds: 60);
```

### File 2: `lib/services/intelligent_savings_goal_assistant_service.dart`

Find (Line ~349):
```dart
static const Duration _timeout = Duration(seconds: 30);
```

Replace with:
```dart
static const Duration _timeout = Duration(seconds: 60);
```

---

## Step 6: Test After Fix

Run app again:
```bash
flutter run
```

**Watch for:**
- ✅ "✅ Forecast received successfully" → Working!
- ❌ Still timing out after 60s → Backend issue
- 🔴 Error 500 → Backend crashed

---

## Step 7: Permanent Solutions

### Option A: Deploy to Better Backend

**Render Pro Plan (~$12/month):**
- Keeps server always warm
- More resources
- Better response times

**Or Use Railway/Replit:**
- Better cold start times
- Free tier more generous

### Option B: Local Backend Testing

Use local development server while fixing:

**Terminal 1 (Backend):**
```bash
cd backend
python main.py
# Server runs at http://localhost:8000
```

**Update Flutter** (temporarily):
```dart
// lib/services/budget_forecast_service.dart
static const String _backendUrl = 'http://localhost:8000';  // Local testing
// static const String _backendUrl = 'https://fyp-zy.onrender.com';  // Production
```

**Run App:**
```bash
flutter run -d chrome
```

---

## Step 8: Monitor Performance

Add timing logs to debug:

```dart
// In _callForecastAPI method
print('$_tag Calling Prophet API at $_backendUrl/forecast');
final stopwatch = Stopwatch()..start();

final response = await http
    .post(...)
    .timeout(_timeout);

stopwatch.stop();
print('$_tag API took ${stopwatch.elapsedMilliseconds}ms');
```

**This shows:**
- ✅ <5 seconds = normal
- 🟡 5-30 seconds = slow but acceptable
- 🔴 >30 seconds = timeout issue

---

## Checklist

- [ ] Check `https://fyp-zy.onrender.com/docs` in browser
- [ ] Test endpoint with cURL (get response time)
- [ ] Check Render backend logs
- [ ] Increase timeout to 60 seconds in both service files
- [ ] Rebuild and test Flutter app
- [ ] Monitor console for timing logs
- [ ] If still failing, check backend logs for errors
- [ ] Consider upgrading Render or switching to Railway

---

## When to Escalate

**If after all above steps still failing:**
1. Backend might be permanently down
2. Render service might have issues
3. Network connectivity problem
4. Backend code error (needs code fix)

**Action:** Check Render status page and backend logs, then fix root cause
