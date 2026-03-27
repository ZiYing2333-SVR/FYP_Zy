"""
Smart Budgeting & Forecast Alerts Backend
Uses Facebook Prophet for time-series forecasting of expenses
Uses Google Gemini for intelligent savings goal analysis
"""

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import pandas as pd
from prophet import Prophet
import numpy as np
from datetime import datetime, timedelta
import warnings
import os
from dotenv import load_dotenv
import google.generativeai as genai
import json

warnings.filterwarnings('ignore')

# Load environment variables
load_dotenv()

# Configure Gemini API
GEMINI_API_KEY = os.getenv('GEMINI_API_KEY')
if GEMINI_API_KEY:
    genai.configure(api_key=GEMINI_API_KEY)
    gemini_model = genai.GenerativeModel('gemini-pro')

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


# ==================== SAVINGS GOAL MODELS ====================

class SavingsGoalRequest(BaseModel):
    """Request for savings goal analysis"""
    monthly_income: float
    monthly_expenses: float
    goal_amount: float  # Total amount to save
    timeline_months: int  # How many months to save
    income_transactions: list = []  # Optional: for spending patterns
    expense_transactions: list = []  # Optional: for spending patterns


class GoalFeasibilityResponse(BaseModel):
    """Analysis of whether savings goal is feasible"""
    success: bool
    is_feasible: bool
    monthly_savings: float
    cumulative_savings_timeline: list[float]  # Cumulative savings over months
    analysis: str  # AI-generated analysis
    suggestions: list[str]  # Actionable suggestions
    confidence_level: str  # "low", "medium", "high"


class RecommendationsRequest(BaseModel):
    """Request for smart recommendations"""
    monthly_income: float
    monthly_expenses: float
    goal_amount: float
    timeline_months: int
    current_savings: float = 0.0
    spending_breakdown: dict = {}  # e.g., {"food": 500, "entertainment": 300}


class SmartRecommendationResponse(BaseModel):
    """AI-generated smart recommendations"""
    success: bool
    recommendations: list[str]
    priority_actions: list[str]  # Most impactful actions
    estimated_impact: list[dict]  # e.g., [{"action": "reduce food by 10%", "savings": 50}]


class ScenarioSimulationRequest(BaseModel):
    """Request for scenario simulation"""
    monthly_income: float
    monthly_expenses: float
    goal_amount: float
    base_timeline_months: int
    scenarios: list[dict]  # e.g., [{"expense_reduction": 0.1}, {"expense_reduction": 0.2}]


class ScenarioResult(BaseModel):
    """Result of a scenario simulation"""
    description: str
    new_timeline_months: int
    new_monthly_savings: float
    total_savings_variation: float


class NaturalLanguageReportRequest(BaseModel):
    """Request for natural language report generation"""
    monthly_income: float
    predicted_monthly_expense: float
    goal_amount: float
    timeline_months: int
    cumulative_savings: list[float]
    actual_spending_patterns: dict = {}  # Optional: for personalized insights


class NaturalLanguageReportResponse(BaseModel):
    """AI-generated natural language report"""
    success: bool
    executive_summary: str
    financial_analysis: str
    goal_feasibility_analysis: str
    personalized_recommendations: str
    action_items: list[str]
    warning_signals: list[str]


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


# ==================== SAVINGS GOAL ENDPOINTS ====================

@app.post("/savings-goal/feasibility", response_model=GoalFeasibilityResponse)
async def analyze_goal_feasibility(request: SavingsGoalRequest) -> GoalFeasibilityResponse:
    """
    Analyze if a savings goal is feasible and provide AI-powered insights
    """
    try:
        if not GEMINI_API_KEY:
            raise ValueError("Gemini API key not configured")
        
        # Calculate basic metrics
        monthly_savings = request.monthly_income - request.monthly_expenses
        is_feasible = monthly_savings > 0
        
        if is_feasible:
            months_needed = request.goal_amount / monthly_savings
            is_feasible = months_needed <= request.timeline_months
        
        # Generate cumulative savings timeline
        cumulative_savings = []
        for month in range(1, request.timeline_months + 1):
            cumulative = monthly_savings * month
            cumulative_savings.append(min(cumulative, request.goal_amount))
        
        # Use Gemini for intelligent analysis
        prompt = f"""
You are a financial advisor helping someone achieve their savings goal.

FINANCIAL SITUATION:
- Monthly Income: RM{request.monthly_income:.2f}
- Monthly Expenses: RM{request.monthly_expenses:.2f}
- Monthly Savings Capacity: RM{monthly_savings:.2f}
- Savings Goal: RM{request.goal_amount:.2f}
- Target Timeline: {request.timeline_months} months
- Goal Feasibility: {'YES' if is_feasible else 'NO'}

Please provide:
1. A brief analysis (2-3 sentences) of whether this goal is realistic
2. 3-5 specific, actionable suggestions to improve savings

Format your response as JSON with keys: "analysis" and "suggestions" (suggestions as a list of strings)
"""
        
        response = gemini_model.generate_content(prompt)
        
        try:
            # Parse Gemini response
            response_text = response.text
            # Extract JSON from response
            json_start = response_text.find('{')
            json_end = response_text.rfind('}') + 1
            json_str = response_text[json_start:json_end]
            gemini_response = json.loads(json_str)
            
            analysis = gemini_response.get('analysis', 'Goal analysis completed.')
            suggestions = gemini_response.get('suggestions', [])
        except:
            # Fallback if parsing fails
            analysis = response.text[:200]
            suggestions = ["Review your expense categories", "Consider increasing income sources"]
        
        # Determine confidence level
        if monthly_savings <= 0:
            confidence = "low"
        elif is_feasible and monthly_savings > (request.goal_amount / request.timeline_months) * 1.5:
            confidence = "high"
        else:
            confidence = "medium"
        
        return GoalFeasibilityResponse(
            success=True,
            is_feasible=is_feasible,
            monthly_savings=monthly_savings,
            cumulative_savings_timeline=cumulative_savings,
            analysis=analysis,
            suggestions=suggestions,
            confidence_level=confidence
        )
    
    except Exception as e:
        print(f"Goal feasibility error: {str(e)}")
        # Return a reasonable default response even if Gemini fails
        monthly_savings = request.monthly_income - request.monthly_expenses
        is_feasible = monthly_savings > 0 and (monthly_savings * request.timeline_months) >= request.goal_amount
        
        cumulative_savings = [min(monthly_savings * m, request.goal_amount) for m in range(1, request.timeline_months + 1)]
        
        return GoalFeasibilityResponse(
            success=True,  # Calculation succeeded even if AI analysis failed
            is_feasible=is_feasible,
            monthly_savings=monthly_savings,
            cumulative_savings_timeline=cumulative_savings,
            analysis=f"Your goal requires RM{monthly_savings:.2f} monthly savings. This is {'achievable' if is_feasible else 'not achievable'} in your timeline.",
            suggestions=[
                "Track your expenses regularly",
                "Set up automatic savings transfers",
                "Review and cut unnecessary expenses"
            ],
            confidence_level="medium"
        )


@app.post("/savings-goal/recommendations", response_model=SmartRecommendationResponse)
async def get_smart_recommendations(request: RecommendationsRequest) -> SmartRecommendationResponse:
    """
    Get AI-powered personalized recommendations to achieve savings goal faster
    """
    try:
        if not GEMINI_API_KEY:
            raise ValueError("Gemini API key not configured")
        
        monthly_savings = request.monthly_income - request.monthly_expenses
        months_needed = request.goal_amount / monthly_savings if monthly_savings > 0 else float('inf')
        
        # Format spending breakdown
        spending_details = "\n".join([f"- {k}: RM{v:.2f}" for k, v in request.spending_breakdown.items()]) if request.spending_breakdown else "Not specified"
        
        prompt = f"""
You are a financial advisor. Help this person achieve their savings goal faster.

SITUATION:
- Monthly Income: RM{request.monthly_income:.2f}
- Monthly Expenses: RM{request.monthly_expenses:.2f}
- Monthly Savings Capacity: RM{monthly_savings:.2f}
- Savings Goal: RM{request.goal_amount:.2f}
- Target Timeline: {request.timeline_months} months
- Months Needed at Current Rate: {months_needed:.1f}
- Current Savings: RM{request.current_savings:.2f}

Spending Breakdown:
{spending_details}

Provide:
1. Top 3-5 specific recommendations (be concrete with numbers)
2. Priority actions that will have the biggest impact
3. For each recommendation: estimated monthly savings from that action

Format as JSON with keys: "recommendations" (list), "priority_actions" (list), "estimated_impact" (list of objects with "action" and "savings" keys)
"""
        
        response = gemini_model.generate_content(prompt)
        
        try:
            response_text = response.text
            json_start = response_text.find('{')
            json_end = response_text.rfind('}') + 1
            json_str = response_text[json_start:json_end]
            gemini_response = json.loads(json_str)
            
            recommendations = gemini_response.get('recommendations', [])
            priority_actions = gemini_response.get('priority_actions', [])
            estimated_impact = gemini_response.get('estimated_impact', [])
        except:
            recommendations = [
                "Reduce dining out by 20%",
                "Cancel unused subscriptions",
                "Shop with a meal plan to reduce food waste"
            ]
            priority_actions = ["Reduce dining out", "Cancel subscriptions"]
            estimated_impact = [
                {"action": "Reduce dining out", "savings": 100},
                {"action": "Cancel subscriptions", "savings": 50}
            ]
        
        return SmartRecommendationResponse(
            success=True,
            recommendations=recommendations,
            priority_actions=priority_actions,
            estimated_impact=estimated_impact
        )
    
    except Exception as e:
        print(f"Recommendation error: {str(e)}")
        return SmartRecommendationResponse(
            success=True,
            recommendations=[
                "Track daily spending to identify waste",
                "Set spending limits by category",
                "Use cashback apps for purchases"
            ],
            priority_actions=["Track spending", "Set category limits"],
            estimated_impact=[
                {"action": "Reduce impulse purchases", "savings": 200}
            ]
        )


@app.post("/savings-goal/scenarios", response_model=list[ScenarioResult])
async def simulate_scenarios(request: ScenarioSimulationRequest) -> list[ScenarioResult]:
    """
    Simulate different expense reduction scenarios to show impact on timeline
    """
    try:
        base_monthly_savings = request.monthly_income - request.monthly_expenses
        results = []
        
        for scenario in request.scenarios:
            expense_reduction = scenario.get('expense_reduction', 0)
            
            new_monthly_expenses = request.monthly_expenses * (1 - expense_reduction)
            new_monthly_savings = request.monthly_income - new_monthly_expenses
            
            if new_monthly_savings > 0:
                new_timeline = request.goal_amount / new_monthly_savings
            else:
                new_timeline = float('inf')
            
            variation = request.goal_amount - (base_monthly_savings * request.base_timeline_months)
            
            reduction_pct = int(expense_reduction * 100)
            savings_increase = new_monthly_savings - base_monthly_savings
            
            scenario_result = ScenarioResult(
                description=f"Reduce expenses by {reduction_pct}% (RM{request.monthly_expenses * expense_reduction:.2f}/month)",
                new_timeline_months=int(max(1, new_timeline)),
                new_monthly_savings=new_monthly_savings,
                total_savings_variation=savings_increase
            )
            results.append(scenario_result)
        
        return results
    
    except Exception as e:
        print(f"Scenario simulation error: {str(e)}")
        return []


@app.post("/savings-goal/report", response_model=NaturalLanguageReportResponse)
async def generate_natural_language_report(request: NaturalLanguageReportRequest) -> NaturalLanguageReportResponse:
    """
    Generate a comprehensive natural language report for the user
    """
    try:
        if not GEMINI_API_KEY:
            raise ValueError("Gemini API key not configured")
        
        monthly_savings = request.monthly_income - request.predicted_monthly_expense
        timeline_feasible = (monthly_savings * request.timeline_months) >= request.goal_amount if monthly_savings > 0 else False
        
        cumulative_final = request.cumulative_savings[-1] if request.cumulative_savings else 0
        
        prompt = f"""
You are a financial advisor creating a friendly, personalized savings goal report for a user.

FINANCIAL OVERVIEW:
- Monthly Income: RM{request.monthly_income:.2f}
- Predicted Monthly Expenses: RM{request.predicted_monthly_expense:.2f}
- Monthly Savings: RM{monthly_savings:.2f}
- Savings Goal: RM{request.goal_amount:.2f}
- Target Timeline: {request.timeline_months} months
- Projected Total Savings: RM{cumulative_final:.2f}
- Goal Achievable: {'YES' if timeline_feasible else 'NO'}

Create a comprehensive report with these sections (use friendly, encouraging tone):

1. **Executive Summary**: 1-2 sentence overview of their savings journey
2. **Financial Analysis**: Current situation analysis (2-3 sentences)
3. **Goal Feasibility**: Is their goal realistic? (2-3 sentences)
4. **Personalized Recommendations**: 2-3 specific, actionable recommendations based on their situation
5. **Action Items**: A numbered list (3-5 items) of immediate steps they should take
6. **Warning Signals**: 2-3 potential challenges they should watch out for

Format your response as JSON with these exact keys: "executive_summary", "financial_analysis", "goal_feasibility_analysis", "personalized_recommendations", "action_items" (list), "warning_signals" (list)
"""
        
        response = gemini_model.generate_content(prompt)
        
        try:
            response_text = response.text
            json_start = response_text.find('{')
            json_end = response_text.rfind('}') + 1
            json_str = response_text[json_start:json_end]
            gemini_response = json.loads(json_str)
            
            return NaturalLanguageReportResponse(
                success=True,
                executive_summary=gemini_response.get('executive_summary', 'Savings goal report generated.'),
                financial_analysis=gemini_response.get('financial_analysis', ''),
                goal_feasibility_analysis=gemini_response.get('goal_feasibility_analysis', ''),
                personalized_recommendations=gemini_response.get('personalized_recommendations', ''),
                action_items=gemini_response.get('action_items', []),
                warning_signals=gemini_response.get('warning_signals', [])
            )
        except:
            return NaturalLanguageReportResponse(
                success=True,
                executive_summary="You're on track to achieve your savings goal!",
                financial_analysis=f"With monthly savings of RM{monthly_savings:.2f}, you're building wealth steadily.",
                goal_feasibility_analysis="Your goal is realistic with disciplined saving.",
                personalized_recommendations="Focus on consistent monthly savings and avoid unexpected expenses.",
                action_items=[
                    "Set up automatic transfers to savings account",
                    "Review and categorize your monthly expenses",
                    "Identify and cut at least 3 non-essential expenses"
                ],
                warning_signals=[
                    "Watch for lifestyle inflation as income increases",
                    "Monitor for unexpected large expenses"
                ]
            )
    
    except Exception as e:
        print(f"Report generation error: {str(e)}")
        return NaturalLanguageReportResponse(
            success=True,
            executive_summary="Your savings journey has been analyzed.",
            financial_analysis=f"Current monthly savings: RM{monthly_savings:.2f}",
            goal_feasibility_analysis="Your goal requires consistent effort.",
            personalized_recommendations="Stay focused and track your progress regularly.",
            action_items=["Set up savings reminders", "Review monthly progress"],
            warning_signals=["Unexpected expenses could derail plans"]
        )


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
