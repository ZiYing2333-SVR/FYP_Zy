# Smart Budgeting & Forecast Alerts - Complete Setup Guide

## 🎯 Overview

The Smart Budgeting & Forecast Alerts feature is now powered by **Facebook Prophet**, a state-of-the-art time-series forecasting library. The system uses:

1. **Python FastAPI Backend** - Runs Prophet forecasting engine
2. **Flutter Frontend** - Displays predictions and handles user interactions
3. **Supabase** - Stores user data and transactions
4. **Alerts System** - Warns you when spending may exceed budget

## 📊 Key Features

### ✅ Accurate Forecasting
- Analyzes your spending patterns over 12 months
- Detects trends (increasing/decreasing spending)
- Finds seasonality (regular patterns each month)
- Identifies anomalies (unusual months)
- 95% confidence intervals for predictions

### 📈 Smart Alerts
- **Green (✅ On Track)**: Predicted expenses are below budget
- **Orange (⚠️ Warning)**: Predicted expenses may exceed budget
- **Red (🚨 Critical)**: Predicted expenses significantly exceed budget

### 📉 Accuracy Metrics
- **MAE (Mean Absolute Error)**: Measures forecast accuracy
- Lower MAE = More accurate predictions
- System adjusts confidence based on available data

---

## 🚀 Quick Start (5 minutes)

### Step 1: Install Python Dependencies

Open terminal/command prompt in the `backend` folder and run:

```bash
# Create virtual environment
python -m venv venv

# Activate virtual environment
# On Windows:
venv\Scripts\activate
# On macOS/Linux:
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt
```

**⏱️ Note**: First install may take 5-10 minutes (Prophet compiles C++ code).

### Step 2: Start the Backend Server

```bash
python main.py
```

You should see:
```
INFO:     Uvicorn running on http://127.0.0.1:8000
```

### Step 3: Verify Backend is Working

Open browser and go to:
```
http://127.0.0.1:8000/docs
```

You'll see interactive API documentation. Click "Try it out" on the `/forecast` endpoint to test.

### Step 4: Run Flutter App

The Flutter app will automatically connect to the backend at `http://127.0.0.1:8000`

Navigate to **Budget Forecasting** screen and you should see:
- Monthly spending history chart
- Next month's prediction with confidence level
- Alert status (Green/Orange/Red)
- Forecast accuracy (MAE)

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Flutter App                          │
│  (Budget Forecasting Screen)                            │
│                                                          │
│  • Fetches historical transactions from Supabase        │
│  • Aggregates into monthly spending                     │
│  • Sends to Prophet API                                 │
│  • Displays predictions + alerts                        │
└────────────────────┬────────────────────────────────────┘
                     │ HTTP POST /forecast
                     │ (JSON with spending data)
                     ▼
┌─────────────────────────────────────────────────────────┐
│                    Python Backend                       │
│           (FastAPI + Facebook Prophet)                  │
│                                                          │
│  • Receives historical spending data                    │
│  • Trains Prophet model                                │
│  • Detects trends & seasonality                        │
│  • Generates predictions                               │
│  • Calculates confidence intervals                      │
│  • Checks alert conditions                             │
└────────────────────┬────────────────────────────────────┘
                     │ JSON Response
                     │ (predictions + alerts)
                     ▼
┌─────────────────────────────────────────────────────────┐
│                    Flutter App                          │
│  • Displays forecast chart                              │
│  • Shows alert (Green/Orange/Red)                      │
│  • Displays MAE accuracy metric                         │
└─────────────────────────────────────────────────────────┘
```

---

## 📡 API Endpoints

### GET /health
Check if backend is alive
```bash
curl http://127.0.0.1:8000/health
```

### POST /forecast (Main Endpoint)
Generate expense forecast

**Request:**
```json
{
  "historical_data": [
    {"date": "2024-01-01", "amount": 1200},
    {"date": "2024-02-01", "amount": 1500},
    {"date": "2024-03-01", "amount": 1800}
  ],
  "forecast_periods": 3,
  "budget_amount": 2000
}
```

**Response:**
```json
{
  "forecast": [
    {
      "date": "2024-04-01",
      "predicted_amount": 1950.25,
      "lower_bound": 1500.50,
      "upper_bound": 2400.75,
      "is_anomaly": false
    }
  ],
  "mae": 150.75,
  "has_sufficient_data": true,
  "alert_status": "warning",
  "alert_message": "⚠️ WARNING: Predicted expenses may exceed budget..."
}
```

### GET /docs
Interactive API documentation (Swagger UI)

---

## 🔧 Configuration

### Local Development
Default backend URL: `http://127.0.0.1:8000`

The app automatically connects to this URL.

### Production Deployment

When deploying, update the backend URL in `lib/services/budget_forecast_service.dart`:

```dart
static const String _backendUrl = 'YOUR_PRODUCTION_URL';
```

---

## ☁️ Production Deployment Options

### Option 1: Render (Recommended FREE)

1. **Push code to GitHub**
```bash
git add .
git commit -m "Add Prophet forecasting backend"
git push
```

2. **Create account** at [render.com](https://render.com)

3. **Deploy:**
   - Click "Create" → "Web Service"
   - Connect GitHub repo
   - Settings:
     - **Name**: `smart-budgeting-api`
     - **Build Command**: `pip install -r requirements.txt`
     - **Start Command**: `uvicorn main:app --host 0.0.0.0 --port 8000`
   - Click "Create Web Service"

4. **Get deploymentt URL** (e.g., `https://smart-budgeting-api.onrender.com`)

5. **Update Flutter:**
   ```dart
   static const String _backendUrl = 'https://smart-budgeting-api.onrender.com';
   ```

⚠️ **Note**: Free tier on Render spins down after 15 minutes of inactivity (takes 30 seconds to restart).

---

### Option 2: Railway

1. Go to [railway.app](https://railway.app)
2. Create new project
3. Deploy from GitHub
4. Railway auto-detects Python and installs dependencies
5. Set start command: `uvicorn main:app --host 0.0.0.0 --port $PORT`
6. Get public URL and update Flutter

---

### Option 3: Replit

1. Import repo to [Replit](https://replit.com)
2. Click "Run"
3. Replit handles installation automatically
4. Use Replit public URL for backend

---

## 🛟 Troubleshooting

### Issue: "Connection failed to 127.0.0.1:8000"
**Solution**: Make sure backend is running and accessible
```bash
# In backend folder, check if server is running
python main.py
```

### Issue: "Address already in use"
**Solution**: Backend server is already running, or port 8000 is in use
```bash
# Linux/macOS: Kill process on port 8000
lsof -ti:8000 | xargs kill -9

# Windows: Use different port in main.py
# Change "uvicorn.run(app, host="0.0.0.0", port=8001)"
```

### Issue: Prophet installation fails
**Solution**: Install required build tools first

**Windows**:
```bash
pip install --upgrade pip
pip install prophet
```

**macOS**:
```bash
# If you have M1/M2 Mac, use conda
conda create -n prophet python=3.10
conda activate prophet
conda install -c conda-forge prophet
```

**Linux**:
```bash
sudo apt-get install build-essential
pip install prophet
```

### Issue: Empty forecast results in Flutter app
**Solution**: 
1. Check if you have at least 3 months of spending history
2. Verify backend is returning data (check `/docs` page)
3. Check Flutter console logs for error messages

---

## 📊 Understanding Forecast Data

### Historical Data Requirement
- **Minimum**: 3 months of transaction history
- **Recommended**: 12+ months for seasonal patterns

### Confidence Intervals (95%)
- **Lower Bound**: 95% chance actual will be ≥ this value
- **Upper Bound**: 95% chance actual will be ≤ this value
- Wider intervals = Less confident in prediction

### Mean Absolute Error (MAE)
Measures how accurate the model was on historical data
- MAE = 100 → Average error of $100
- Lower MAE = Better predictions
- Only meaningful with 6+ months of data

### Alert Status Rules

| Status | Condition | Color |
|--------|-----------|-------|
| ✅ Normal | Predicted < Budget - 20% | Green |
| ⚠️ Warning | Predicted ≥ Budget OR Upper Bound > Budget × 115% | Orange |
| 🚨 Critical | Predicted > Budget × 120% | Red |

---

## 🧠 How Prophet Works

### 1. Trend Detection
Prophet identifies long-term spending patterns:
- Your spending increasing each month?
- Stable spending?
- Declining spending?

### 2. Seasonality Detection
Finds recurring patterns each month:
- Holidays (Dec spending spike?)
- Salary cycles
- Subscription renewals

### 3. Holiday Effects (Advanced)
Can account for special events (available in production version)

### 4. Anomaly Detection
Marks unusual months automatically:
- Emergency expense?
- Unexpected income?

### 5. Confidence Intervals
Provides upper/lower bounds:
- Accounts for unpredictability
- Wider bounds = Less certain prediction

---

## 💡 Tips for Better Forecasts

1. **Collect Data**: Wait 3+ months before using (12+ for seasonal patterns)
2. **Regular Categories**: Keep spending categories consistent
3. **Budget Alignment**: Set realistic budgets based on trends
4. **Review Monthly**: Check actual vs predicted to improve model
5. **Act on Alerts**: When you get a warning, adjust spending early

---

## 🔄 Data Flow in Detail

### 1. User Opens Budget Forecasting Screen
```
Flutter → Supabase: Fetch all transactions last 12 months
```

### 2. Transactions Aggregated
```
Daily transactions → Monthly spending amounts
2024-01: [Grocery $50, Utilities $100] → Total: $150
2024-02: [Grocery $60, Utilities $100] → Total: $160
```

### 3. Call Prophet API
```
Flutter → Backend: POST /forecast
{
  "historical_data": [
    {"date": "2024-01-01", "amount": 150},
    {"date": "2024-02-01", "amount": 160}
  ],
  "forecast_periods": 3,
  "budget_amount": 2000
}
```

### 4. Prophet Processes
```
Backend:
1. Train model on historical data
2. Fit trend & seasonality
3. Forecast next 3 months
4. Calculate confidence intervals
5. Check alert conditions
6. Calculate MAE accuracy
```

### 5. Response Sent Back
```
Backend → Flutter: Return predictions + alerts
{
  "forecast": [...],
  "mae": 50.25,
  "alert_status": "warning"
}
```

### 6. Display to User
```
Flutter:
- Show forecast chart
- Display alert (Green/Orange/Red)
- Show MAE accuracy
- Display confidence intervals
```

---

## 🚀 Next Steps

1. **Run the backend** following Step 1-3 above
2. **Test the API** at `/docs`
3. **Run Flutter app** and navigate to Budget Forecasting
4. **Create a budget** if you don't have one
5. **Check predictions** against your actual spending
6. **Adjust budget** based on forecasts
7. **Deploy to production** when ready (Render, Railway, or Replit)

---

## 📞 Support & Resources

- **Prophet Documentation**: https://facebook.github.io/prophet/
- **FastAPI Guide**: https://fastapi.tiangolo.com/
- **Render Docs**: https://render.com/docs
- **Flutter HTTP**: https://pub.dev/packages/http

---

## ✨ Summary

**What you've got:**
- ✅ Enterprise-grade forecasting using Facebook Prophet
- ✅ Real-time predictions with confidence intervals
- ✅ Smart alert system (Green/Orange/Red)
- ✅ Accuracy metrics (MAE)
- ✅ Cloud deployment ready

**Your app can now:**
- 📊 Predict future spending with high accuracy
- 📈 Track spending trends automatically
- 🎯 Stay within budget with early warnings
- 💰 Plan finances based on data, not guesses

Enjoy your smart budgeting system! 🎉
