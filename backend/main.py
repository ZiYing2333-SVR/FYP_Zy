"""
Smart Budgeting & Forecast Alerts Backend
Uses Facebook Prophet for time-series forecasting of expenses
"""

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import pandas as pd
from prophet import Prophet
import numpy as np
from datetime import datetime, timedelta
import warnings

warnings.filterwarnings('ignore')

app = FastAPI(
    title="Smart Budgeting API",
    description="API for expense forecasting using Facebook Prophet",
    version="1.0.0"
)

# Enable CORS for Flutter app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ==================== DATA MODELS ====================

class SpendingData(BaseModel):
    """Historical spending data point"""
    date: str  # Format: YYYY-MM-DD
    amount: float


class ForecastRequest(BaseModel):
    """Request for expense forecast"""
    historical_data: list[SpendingData]  # Historical monthly spending data
    forecast_periods: int = 3  # Number of months to forecast
    budget_amount: float  # Monthly budget for alert checking


class ForecastPoint(BaseModel):
    """Single forecast data point"""
    date: str  # Format: YYYY-MM-DD
    predicted_amount: float
    lower_bound: float
    upper_bound: float
    is_anomaly: bool = False


class ForecastResponse(BaseModel):
    """Response containing forecast results"""
    forecast: list[ForecastPoint]
    mae: float  # Mean Absolute Error
    has_sufficient_data: bool
    alert_status: str  # "normal", "warning", "critical"
    alert_message: str


class HealthResponse(BaseModel):
    """Health check response"""
    status: str
    version: str


# ==================== UTILITY FUNCTIONS ====================

def calculate_mae(actual: pd.Series, predicted: pd.Series) -> float:
    """Calculate Mean Absolute Error between actual and predicted values"""
    if len(actual) != len(predicted):
        return -1.0
    
    mae = np.mean(np.abs(actual.values - predicted.values))
    return float(mae)


def check_alert_status(
    forecast_data: list[dict],
    budget_amount: float,
    mae: float
) -> tuple[str, str]:
    """
    Determine alert status based on forecast vs budget
    Returns: (alert_status, alert_message)
    """
    if not forecast_data:
        return "normal", "No forecast data available"
    
    # Check next month's forecast
    next_month = forecast_data[0]
    predicted = next_month['predicted_amount']
    upper_bound = next_month['upper_bound']
    
    # Critical: Predicted amount significantly exceeds budget
    if predicted > budget_amount * 1.2:
        return "critical", (
            f"⚠️ CRITICAL: Predicted expenses (${predicted:.2f}) are 20%+ above "
            f"your ${budget_amount:.2f} budget. Take action immediately."
        )
    
    # Warning: Predicted amount exceeds budget or upper bound significantly exceeds
    if predicted > budget_amount or upper_bound > budget_amount * 1.15:
        return "warning", (
            f"⚠️ WARNING: Predicted expenses (${predicted:.2f}) may exceed your "
            f"${budget_amount:.2f} budget next month. Consider adjusting spending."
        )
    
    # Normal: Within budget with margin
    return "normal", (
        f"✅ On track: Predicted expenses (${predicted:.2f}) are below your "
        f"${budget_amount:.2f} budget. Keep it up!"
    )


# ==================== FORECAST ENDPOINT ====================

@app.post("/forecast", response_model=ForecastResponse)
async def generate_forecast(request: ForecastRequest) -> ForecastResponse:
    """
    Generate expense forecast using Facebook Prophet
    
    Args:
        request: Contains historical spending data and forecast parameters
    
    Returns:
        ForecastResponse with predictions, confidence intervals, and alerts
    """
    try:
        # Validate input
        if not request.historical_data:
            raise ValueError("No historical data provided")
        
        if request.forecast_periods <= 0:
            raise ValueError("Forecast periods must be > 0")
        
        if request.budget_amount <= 0:
            raise ValueError("Budget amount must be > 0")
        
        # Prepare data
        df_data = []
        for point in request.historical_data:
            df_data.append({
                'ds': pd.to_datetime(point.date),
                'y': float(point.amount)
            })
        
        df = pd.DataFrame(df_data)
        
        # Check if we have sufficient historical data (minimum 3 data points recommended)
        has_sufficient_data = len(df) >= 3
        
        # Train Prophet model
        model = Prophet(
            yearly_seasonality=len(df) >= 12,  # Only use yearly seasonality if we have 12+ months
            weekly_seasonality=False,  # Disable weekly seasonality for monthly data
            daily_seasonality=False,
            interval_width=0.95,  # 95% confidence interval
            changepoint_prior_scale=0.05,  # Less aggressive trend changes
        )
        
        with warnings.catch_warnings():
            warnings.simplefilter("ignore")
            model.fit(df)
        
        # Generate future dataframe
        future = model.make_future_dataframe(periods=request.forecast_periods, freq='MS')
        
        # Make predictions
        forecast = model.predict(future)
        
        # Extract only future predictions (exclude historical data)
        future_forecast = forecast[len(df):].copy()
        
        # Calculate MAE on training data
        train_forecast = model.predict(df)
        mae = calculate_mae(df['y'], train_forecast['yhat'])
        
        # Calculate anomaly detection (Z-score method)
        # Points significantly different from trend are marked as anomalies
        residuals = df['y'].values - train_forecast['yhat'].tail(len(df)).values
        residual_mean = np.mean(residuals)
        residual_std = np.std(residuals)
        
        # Prepare response forecast data
        response_forecast = []
        for idx, row in future_forecast.iterrows():
            date_str = row['ds'].strftime('%Y-%m-01')  # First day of month
            predicted = max(0, float(row['yhat']))
            lower = max(0, float(row['yhat_lower']))
            upper = float(row['yhat_upper'])
            
            # Check if predicted value is anomalous
            is_anomalous = False
            if residual_std > 0:
                z_score = (predicted - residual_mean) / residual_std
                is_anomalous = abs(z_score) > 2.0  # 2 standard deviations
            
            response_forecast.append({
                'date': date_str,
                'predicted_amount': predicted,
                'lower_bound': lower,
                'upper_bound': upper,
                'is_anomaly': is_anomalous
            })
        
        # Determine alert status
        alert_status, alert_message = check_alert_status(
            response_forecast,
            request.budget_amount,
            mae
        )
        
        # Create response objects
        forecast_points = [
            ForecastPoint(
                date=f['date'],
                predicted_amount=f['predicted_amount'],
                lower_bound=f['lower_bound'],
                upper_bound=f['upper_bound'],
                is_anomaly=f['is_anomaly']
            )
            for f in response_forecast
        ]
        
        return ForecastResponse(
            forecast=forecast_points,
            mae=mae,
            has_sufficient_data=has_sufficient_data,
            alert_status=alert_status,
            alert_message=alert_message
        )
    
    except ValueError as ve:
        raise HTTPException(status_code=400, detail=f"Invalid input: {str(ve)}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Forecasting error: {str(e)}")


# ==================== HEALTH CHECK ====================

@app.get("/health", response_model=HealthResponse)
async def health_check() -> HealthResponse:
    """Health check endpoint"""
    return HealthResponse(
        status="healthy",
        version="1.0.0"
    )


# ==================== ROOT ====================

@app.get("/")
async def root():
    """Root endpoint with API documentation"""
    return {
        "name": "Smart Budgeting & Forecast Alerts API",
        "version": "1.0.0",
        "documentation": "/docs",
        "health": "/health",
        "forecast": "/forecast (POST)"
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
