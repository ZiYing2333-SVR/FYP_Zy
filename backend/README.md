# Smart Budgeting Backend - Prophet Forecasting API

This is a FastAPI-based backend service that provides expense forecasting using Facebook Prophet. It integrates with your Flutter app to generate accurate spending predictions and budget alerts.

## 🚀 Quick Start

### Prerequisites
- Python 3.10 or higher
- pip package manager

### Local Development

1. **Create a virtual environment** (recommended):
```bash
python -m venv venv

# On Windows:
venv\Scripts\activate

# On macOS/Linux:
source venv/bin/activate
```

2. **Install dependencies**:
```bash
pip install -r requirements.txt
```

Note: First-time Prophet installation may take 5-10 minutes as it compiles C++ dependencies.

3. **Run the server**:
```bash
python main.py
```

The API will be available at: `http://127.0.0.1:8000`

4. **Access API documentation**:
```
http://127.0.0.1:8000/docs
```

## 📡 API Endpoints

### Health Check
```bash
GET /health
```
Returns server status.

### Forecast Endpoint (Main)
```bash
POST /forecast
Content-Type: application/json

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

**Response**:
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
  "alert_message": "⚠️ WARNING: Predicted expenses may exceed your budget..."
}
```

## 🔍 Understanding Responses

### Forecast Fields
- **predicted_amount**: Most likely expense amount for the month
- **lower_bound**: 95% confidence interval lower bound
- **upper_bound**: 95% confidence interval upper bound
- **is_anomaly**: True if prediction is unusual compared to historical patterns
- **mae**: Mean Absolute Error - measures forecast accuracy (lower is better)

### Alert Status
- **normal** (✅): Predicted expenses are below budget with margin
- **warning** (⚠️): Predicted expenses may exceed budget or are near limit
- **critical** (🚨): Predicted expenses significantly exceed budget

## 🚀 Production Deployment

### Option 1: Render (Recommended - FREE)
1. Push your code to GitHub
2. Go to [render.com](https://render.com)
3. Deploy with these settings:
   - **Build Command**: `pip install -r requirements.txt`
   - **Start Command**: `uvicorn main:app --host 0.0.0.0 --port 8000`
4. Set **BACKEND_URL** in your Flutter app to Render's URL

### Option 2: Railway
1. Go to [railway.app](https://railway.app)
2. Connect your GitHub repository
3. Railway automatically detects Python requirements
4. Set **BACKEND_URL** in Flutter to Railway's URL

### Option 3: Replit
1. Import project to [Replit](https://replit.com)
2. Click "Run" - Replit handles dependencies
3. Use Replit's public URL for **BACKEND_URL**

### Environment Variables (Production)
Create a `.env` file in the backend folder:
```
BACKEND_HOST=0.0.0.0
BACKEND_PORT=8000
```

## 🔧 Troubleshooting

### Prophet Installation Issues
If you encounter C++ compilation errors:

**Windows**:
```bash
pip install prophet --no-binary :all:
```

**macOS**:
```bash
# Install gcc if needed
brew install gcc
pip install prophet
```

**Linux** (Ubuntu/Debian):
```bash
sudo apt-get install build-essential
pip install prophet
```

### Port Already in Use
If port 8000 is already in use, change in `main.py`:
```python
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8001)  # Changed to 8001
```

### Connection Issues from Flutter
- **Local development**: Make sure Flutter can access `http://127.0.0.1:8000`
- **Android emulator**: Use `http://10.0.2.2:8000` instead of `127.0.0.1`
- **Production**: Use the full backend URL from your deployment platform

## 📊 How Prophet Works

Facebook Prophet is a time-series forecasting library that:

1. **Detects Trends**: Identifies long-term spending increases/decreases
2. **Finds Seasonality**: Recognizes monthly or seasonal spending patterns
3. **Handles Anomalies**: Flags unusual spending months
4. **Calculates Confidence Intervals**: Provides upper/lower bounds (95% confidence)
5. **Calculates MAE**: Measures how accurate the model is on historical data

### Data Requirements
- **Minimum**: 3 months of historical data (works with less but less accurate)
- **Recommended**: 12 months of data for seasonal pattern detection
- **Format**: Monthly aggregated spending amounts

## 🔄 Integration with Flutter

The Flutter app sends:
1. Historical monthly spending data
2. Number of months to forecast (typically 3)
3. Monthly budget amount

The backend responds with:
1. Predicted expenses for each month
2. Confidence intervals (95%)
3. Alert status and message
4. Forecast accuracy (MAE)

## 📝 Example Usage Flow

```
User views Budget Forecasting Screen
    ↓
Flutter queries Supabase for historical transactions
    ↓
Aggregates into monthly spending amounts
    ↓
Sends to /forecast endpoint
    ↓
Prophet analyzes trends and seasonality
    ↓
Returns predictions + alert status
    ↓
Flutter displays forecast chart + alert notification
    ↓
User adjusts spending based on predictions
```

## 🛡️ Security Notes

- **CORS**: Configured to accept requests from Flutter apps
- **Input Validation**: All inputs validated before processing
- **Error Handling**: Detailed error messages for debugging
- **Rate Limiting**: Not implemented (add if needed for production)

## 📚 Resources

- [Facebook Prophet Documentation](https://facebook.github.io/prophet/)
- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [Render Deployment Guide](https://render.com/docs/deploy-fastapi)
- [Railway Deployment Guide](https://docs.railway.app/)

## 💡 Tips

- For more accurate forecasts, collect 12+ months of data
- Weekly or daily forecasts are not supported; only monthly aggregation works well
- If data is sparse, confidence intervals will be wider (more conservative)
- The system automatically adjusts based on available data (limited data vs sufficient data)

## 📞 Support

If you encounter issues:
1. Check the FastAPI docs at `/docs`
2. Test the `/health` endpoint
3. Verify your historical data format
4. Check Flutter console logs for API errors
