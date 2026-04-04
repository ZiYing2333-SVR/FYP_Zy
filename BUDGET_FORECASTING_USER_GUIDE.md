# Budget Forecasting Screen Guide

## 📱 Overview

The **Budget Forecasting Screen** uses AI (Facebook Prophet) to predict your spending patterns and helps you avoid budget overruns. It analyzes your historical spending data and provides personalized recommendations.

---

## 🎯 Key Features

### 1. **Spending Pattern Dashboard**

Visual representation of your budget vs. actual spending.

#### Three Progress Bars:

| Component | Color | What It Shows |
|-----------|-------|---------------|
| **Budget Limit** | 🔵 Blue | Your total monthly budget (e.g., RM5,000) |
| **Current Month** | 🟠 Orange | How much you've spent so far this month |
| **Projected Month** | Color-coded | AI prediction of total spending by month end |

#### Risk Level Colors:
- 🟢 **Green** = Low Risk (Safe, under budget)
- 🟡 **Yellow** = Medium Risk (Approaching limit)
- 🟠 **Orange** = High Risk (Likely to exceed)
- 🔴 **Red** = Critical (Will definitely overspend)

**Example:**
- Budget Limit: RM5,000
- Current Spending: RM2,500 (50% used)
- Projected Month: RM6,000 (120% - Will overspend by RM1,000)

---

### 2. **Overspend Analysis Card**

Detailed breakdown of your overspending situation.

#### Shows:
- **Overspend Percentage**: How much over budget (e.g., 20%)
- **Overspend Amount**: Actual RM amount (e.g., RM1,000 extra)
- **Budget Limit vs Projected Spending**: Side-by-side comparison

#### Color Coding:
- 🟢 **Green** = "You are on track to stay within budget! 🎉"
- 🔴 **Red** = "You are projected to overspend by RM[amount]"

**Example:**
```
Your Budget: RM5,000
Your Projection: RM6,000
Overspend: RM1,000 (20%)
Risk Level: HIGH
```

---

### 3. **Smart Spending Suggestions**

AI-generated personalized recommendations based on your spending pattern.

#### Priority Levels:

| Priority | Color | Icon | Type of Suggestion |
|----------|-------|------|-------------------|
| **Critical (4-5)** | 🔴 Red | Alert | Urgent actions needed immediately |
| **High (3)** | 🟠 Orange | Warning | Important spending restrictions |
| **Medium (1-2)** | 🔵 Blue | Lightbulb | General monitoring tips |

#### Examples:

**🔴 Critical (If >50% overspend):**
- "URGENT: Reduce Spending Immediately"
- "Stop all non-essential expenses now"
- "Review all transactions and cancel subscriptions"

**🟠 High (If 20-50% overspend):**
- "Limit Large Purchases"
- "Avoid purchases over RM500 for the rest of month"
- "Postpone shopping and dining out"

**🔵 Medium (If 5-20% overspend):**
- "Careful Spending for Rest of Month"
- "Plan remaining purchases carefully"
- "Prioritize only essential expenses"

**🟢 Low (If under budget):**
- "On Track with Budget"
- "You're projected to stay within budget"
- "Maintain current spending pace"

---

### 4. **Alert Status** (Three Types)

Quick status indicator of your budget health.

#### ✅ On Track (Green Alert)
```
Icon: ✓ Check Circle
Title: On Track
Message: "Predicted expenses ($275.19) are below your $1,100.00 budget. Keep it up!"
Color: Green (#7CB342)
```
**Meaning:** Your spending is healthy; keep doing what you're doing.

#### ⚠️ Budget Warning (Orange Alert)
```
Icon: ⚠ Warning Triangle
Title: Budget Warning
Message: "Your spending is approaching the budget limit. Be careful!"
Color: Orange (#F39C12)
```
**Meaning:** Warning sign - adjust spending or you'll overshoot budget.

#### 🚨 Critical Alert (Red Alert)
```
Icon: ✕ Error Circle
Title: Critical Alert
Message: "Your predicted spending significantly exceeds budget. Take immediate action!"
Color: Red (#E53935)
```
**Meaning:** Emergency - you must reduce spending immediately.

---

### 5. **Next Month Forecast**

Detailed prediction for the upcoming month.

#### Components:

| Element | Meaning |
|---------|---------|
| **Forecasted Amount** | AI's predicted total spending (e.g., RM275.19) |
| **Budget Limit** | Your budget cap (e.g., RM1,100.00) |
| **Confidence Interval** | Range of uncertainty (e.g., RM0 to RM588) |
| **Limited Data Warning** | Shows if forecast is based on <3 months history |

#### Understanding Confidence Intervals:

```
Forecast: RM275.19
Lower Bound: RM0 (optimistic - best case)
Upper Bound: RM588 (pessimistic - worst case)

Meaning: "You'll probably spend RM275, but could be as low as RM0 
or as high as RM588 depending on circumstances"
```

#### Limited Data Warning:
If you have less than 3 months of spending history:
> ⚠️ "Based on limited available data. More historical data will improve accuracy."

---

### 6. **Forecast Details** (3-Month Breakdown)

Month-by-month predictions for next 3 months.

#### Format:
```
Month          Predicted    Lower Bound   Upper Bound   Anomaly?
2024-05-01     RM275.19     RM0.00        RM588.82      No
2024-06-01     RM298.06     RM1.04        RM581.52      No
2024-07-01     RM320.19     RM19.54       RM635.67      No
```

#### What It Means:
- **May**: Expect to spend RM275 (could range RM0-RM589)
- **June**: Spending rises to RM298 (trend upward)
- **July**: Further increase to RM320 (continuous trend)

#### Anomaly Flag:
- ✅ **No** = Normal pattern, prediction is reliable
- ⚠️ **Yes** = Unusual spike detected, be cautious of prediction

---

### 7. **Historical Data** (Past Spending)

Your actual spending from previous months used for prediction.

#### Shows:
```
Date          Amount
2026-01-01    RM23.90
2026-02-01    RM366.90
2026-03-01    RM405.18
2026-04-01    RM84.50
```

#### Uses:
- **Training data** for AI model
- **Pattern detection** (identifying trends)
- **Validation** (showing accuracy of past predictions)

#### Minimum Requirement:
- ✅ **3+ months** = Good prediction accuracy
- ⚠️ **<3 months** = Less reliable (flagged with warning)

---

### 8. **Accuracy Metrics**

Statistical measures of how reliable the forecast is.

#### MAE (Mean Absolute Error)
```
MAE: 165.92
```

**Meaning:** On average, the model's predictions are off by ±RM165.92

#### Interpretation:
| MAE Value | Accuracy | Reliability |
|-----------|----------|------------|
| RM0-50 | Excellent | Very reliable ✅✅✅ |
| RM50-150 | Good | Reliable ✅✅ |
| RM150-300 | Fair | Somewhat reliable ✅ |
| >RM300 | Poor | Low reliability ⚠️ |

**Example with MAE 165.92:**
```
If forecast says: RM275
Actual could be: RM275 ± RM165.92
Range: RM109 to RM441
```

---

## 💡 How to Use This Information

### **Step 1: Check Alert Status**
- 🟢 Green? → Keep current spending
- 🟠 Orange? → Start cutting non-essentials
- 🔴 Red? → Emergency spending cuts needed

### **Step 2: Review Overspend Analysis**
- How much will you overspend? RM amount
- What % of budget? Percentage
- What's your risk level? Color indicator

### **Step 3: Follow Smart Suggestions**
- Read suggestions by priority (highest first)
- Follow 🔴 critical suggestions immediately
- Act on 🟠 high suggestions within days

### **Step 4: Monitor Monthly Forecast**
- Check next month's prediction
- Compare to current pace
- Adjust spending if needed

### **Step 5: Track Historical Pattern**
- Are you spending more each month? Trend=bad
- Are you spending less each month? Trend=good
- Use this to understand your behavior

---

## 🎯 Real-World Example

### Scenario: Monthly Food Budget

```
📊 DASHBOARD:
Budget Limit: RM500
Current (Mid-month): RM300 (60% used)
Projected Month: RM600 (120% - Will overspend)

🔴 OVERSPEND ANALYSIS:
Overspend: RM100 (20% over budget)
Risk Level: HIGH

💡 SUGGESTIONS:
1. [CRITICAL] Stop eating out - cancel restaurant orders
2. [HIGH] Buy generic brands instead of premium
3. [MEDIUM] Use coupons for grocery shopping

⚠️ BUDGET WARNING:
"Your spending might exceed RM500. Consider reducing grocery expenses."

📅 NEXT MONTH FORECAST:
Predicted: RM610 (RM110 over)
Confidence: RM450-RM750

📈 HISTORICAL DATA:
January: RM450
February: RM480
March: RM520
April: RM550 (Projected)
(Clear upward trend → spending increasing each month)

🎯 ACCURACY:
MAE: RM45
(Predictions are accurate to within ±RM45)
```

### Action Plan:
1. ✅ Immediately stop eating out (Critical)
2. ✅ Switch to budget groceries (High priority)
3. ✅ Use coupons/discounts (Medium)
4. 📊 Next week: Review if tracking improved
5. 📅 Next month: Monitor if trend reversed

---

## ❓ FAQ

### Q: Why is my forecast showing RM0?
**A:** You passed `budget_amount: 0` to the API. Always provide your actual budget amount for accurate predictions.

### Q: Why are confidence intervals so large?
**A:** You have few months of data. More historical data = narrower (more accurate) intervals.

### Q: How often updates the forecast?
**A:** Real-time - forecast updates based on your latest transactions from Supabase.

### Q: Can I trust the prediction?
**A:** Check the MAE value. Lower MAE = higher trust. Also look at historical accuracy.

### Q: Why does it recommend spending cuts if I'm under budget?
**A:** To help you save more or prepare for increasing expenses (upward trend detected).

---

## 🔗 Related Screens

- **Budget Management** - Create/edit monthly budgets
- **Intelligent Savings** - AI savings goals based on this forecast
- **Transaction History** - View detailed spending data feeding this forecast

---

## 📞 Support

If forecasts seem incorrect:
1. Check if you have **3+ months of data**
2. Verify **actual transactions** match shown history
3. Look at **MAE accuracy score** (higher = less reliable)
4. Contact support if persistent issues

---

**Last Updated:** April 4, 2026  
**AI Model:** Facebook Prophet v1.1.5  
**Backend:** Render Cloud Deployment
