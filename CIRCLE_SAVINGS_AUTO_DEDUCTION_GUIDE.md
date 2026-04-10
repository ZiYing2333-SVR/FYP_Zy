# Circle Savings Auto-Deduction System - Complete Implementation Guide

## Overview

The Circle Savings Auto-Deduction system automatically transfers money from your source account to your savings destination account based on your chosen frequency (daily, weekly, or monthly). **This happens automatically every time you access the home page** - no manual action required!

## How It Works

### Automatic Check on Home Page Access

1. **Every time you open the home page**, the system checks all your active savings goals
2. For each goal with:
   - `Type` = "cycle" 
   - `Status` = "active"
   - `Cycle Status` = ✅ enabled
3. The system checks if a transfer is due based on the cycle frequency
4. If due, it automatically creates a transfer and updates account balances

### Cycle Frequency Rules

#### Daily Cycle
- **Check**: "Has a transfer been created today?"
- **Action**: If NOT, create one for today
- **Example**: $1,000 goal over 90 days = $11.11/day

#### Weekly Cycle
- **Check**: "Have 7+ days passed since last transfer?"
- **Action**: If YES, create one
- **Example**: $1,000 goal over 12 weeks = $83.33/week

#### Monthly Cycle
- **Check**: "Are we in a new month since last transfer?"
- **Action**: If YES, create one
- **Example**: $1,000 goal over 3 months = $333.33/month

## Database Schema

### SavingGoal Table

```sql
CREATE TABLE public."SavingGoal" (
  "goalId" character varying NOT NULL,              -- Unique goal ID
  "name" character varying NOT NULL,                -- Goal name
  "type" character varying NULL,                    -- "cycle", "flex", etc.
  "targetAmount" double precision NOT NULL,         -- Total to save
  "currentAmount" double precision NOT NULL,        -- Amount saved so far
  "startDate" date NULL,                            -- Start of saving period
  "endDate" date NULL,                              -- End of saving period
  "description" text NULL,                          -- Goal description
  "status" character varying NULL,                  -- "active", "completed", "paused"
  "cycleStatus" boolean NULL DEFAULT false,         -- TRUE = auto-deduction ENABLED
  "cycleFrequency" text NULL,                       -- 'daily', 'weekly', 'monthly'
  "icon" character varying NULL,                    -- Goal icon
  "sourceAcountId" character varying NULL,          -- Account to deduct FROM (e.g., Checking)
  "destAccountId" character varying NOT NULL,       -- Account to transfer TO (Savings)
  "linkedAccountId" character varying NOT NULL,     -- Linked account
  "userId" character varying NOT NULL,              -- User owner
  "createdAt" timestamp,
  "updatedAt" timestamp,
  
  PRIMARY KEY ("goalId"),
  FOREIGN KEY ("sourceAcountId") REFERENCES "Account",
  FOREIGN KEY ("destAccountId") REFERENCES "Account",
  FOREIGN KEY ("linkedAccountId") REFERENCES "Account",
  FOREIGN KEY ("userId") REFERENCES "User"
);
```

### Transfer Table Extensions

The Transfer table has been extended with:

```sql
ALTER TABLE public."Transfer" ADD COLUMN "savingGoalId" character varying;
ALTER TABLE public."Transfer" ADD COLUMN "isAutoDeduction" boolean DEFAULT false;
```

So transfers created by auto-deduction are marked with:
- `isAutoDeduction = true`
- `savingGoalId = {goalId}` (links back to the savings goal)

## Flutter Implementation

### 1. AutoDeductionService (lib/services/auto_deduction_service.dart)

**Main Method**: `checkAndCreateAutoDeductions(userId)`

This method:
1. Fetches all active cycle-based goals for the user
2. For each goal, calls `_isDeductionDue(goalId, frequency)` to check if transfer is needed
3. If due, calculates `_calculateDeductionAmount(goal)` based on timeline
4. Calls `_createAutoDeductionTransfer()` to:
   - Validate source account balance
   - Create Transfer record
   - Update source account balance (-$)
   - Update destination account balance (+$)
   - Update SavingGoal currentAmount

**Key Logic**:

```dart
// Daily: Check if same date exists
if (dateFormat.format(lastDeductionDate) == dateFormat.format(today)) {
  return false; // Already done today
}

// Weekly: Check if 7+ days have passed
if (today.difference(lastDeductionDate).inDays >= 7) {
  return true; // Due for transfer
}

// Monthly: Check if in different month
if (lastYear < currentYear || (lastYear == currentYear && lastMonth < currentMonth)) {
  return true; // Due for transfer
}
```

### 2. HomeScreen Integration

**File**: `lib/screens/home_screen.dart`

**Changes**:
```dart
// Import AutoDeductionService
import '../services/auto_deduction_service.dart';

// In initState:
_checkAutoDeductions();

// In didChangeAppLifecycleState (when app resumes):
_checkAutoDeductions();

// New method added:
Future<void> _checkAutoDeductions() async {
  if (_currentUserId == null) return;
  
  try {
    final result = await AutoDeductionService
        .checkAndCreateAutoDeductions(_currentUserId!);
    
    if (result['success'] && result['transfersCreated'] > 0) {
      _fetchTransactions(); // Refresh to show new transfers
    }
  } catch (e) {
    print('[HomeScreen] Error checking auto-deductions: $e');
  }
}
```

## Setting Up Auto-Deduction for a Savings Goal

### Step 1: Create a Savings Goal with Cycle Type

When creating a goal:
- **Type**: Select "Cycle" (circle saving)
- **Name**: "Emergency Fund"
- **Target Amount**: $1,000
- **Start Date**: Jan 1, 2026
- **End Date**: Mar 31, 2026 (3 months = 90 days)
- **Source Account**: Your checking account
- **Destination**: Your savings account

### Step 2: Enable Auto-Deduction

- **Cycle Frequency**: Select `Daily`, `Weekly`, or `Monthly`
- **Cycle Status**: Toggle to ✅ ON

### Step 3: How Much Will Be Deducted?

The system **automatically calculates** the amount:

```
Amount per cycle = Target Amount ÷ Number of Cycles

Example 1 (Daily):
Target: $1,000
Duration: Jan 1 - Mar 31 (90 days)
Deduction: $1,000 ÷ 90 = $11.11 per day

Example 2 (Weekly):
Target: $1,000
Duration: 12 weeks
Deduction: $1,000 ÷ 12 = $83.33 per week

Example 3 (Monthly):
Target: $1,000
Duration: 3 months
Deduction: $1,000 ÷ 3 = $333.33 per month
```

## Real-World Example

You want to save $1,200 for a vacation in 90 days:

1. **Create Goal**:
   - Type: Cycle
   - Name: "Vacation Fund"
   - Target: $1,200
   - Cycle Frequency: Daily
   - Start: Today
   - End: 90 days from now

2. **System calculates**: $1,200 ÷ 90 = **$13.33 per day**

3. **What happens**:
   - Day 1: Transfer $13.33 from checking → savings
   - Day 2: Transfer $13.33 from checking → savings
   - ... (continues automatically)
   - Day 90: Goal is complete with $1,200 saved!

### User Experience

- ✅ Open app each day → auto-deduction checked
- ✅ No manual transfers needed
- ✅ Fail-safe: If source account has insufficient balance, transfer skipped (retried next day)
- ✅ Re-open app after a few days? → System deducts for all missed days
- ✅ Transfers marked with `isAutoDeduction = true` for tracking

## Status & Cycle Status Explained

### Status (Goal lifecycle)
- **"active"**: Goal is running, auto-deductions happen
- **"paused"**: Goal paused, no auto-deductions
- **"completed"**: Goal finished, no auto-deductions

### Cycle Status (Auto-deduction toggle)
- **`true` (✅ ON)**: Auto-deductions ENABLED → transfers created as scheduled
- **`false` (❌ OFF)**: Auto-deductions DISABLED → no transfers created

### Decision Matrix

| Status | Cycle Status | Auto-Deduction? |
|--------|--------------|-----------------|
| active | true (✅) | ✅ YES, create transfers |
| active | false (❌) | ❌ NO, skip transfers |
| paused | true (✅) | ❌ NO, status prevents it |
| paused | false (❌) | ❌ NO, both prevent it |
| completed | true (✅) | ❌ NO, goal finished |
| completed | false (❌) | ❌ NO, goal finished |

## Troubleshooting

### Problem: Transfers not created
**Possible causes**:
- Source account has insufficient balance
- Cycle Status is set to OFF (❌)
- Goal Status is not "active"
- You haven't opened the app yet today (for daily frequency)
- Cycle frequency doesn't match date boundaries

**Solution**: 
- Check source account balance
- Verify Cycle Status is ON (✅)
- Verify Goal Status is "active"
- Open the home page to trigger the check

### Problem: Transfer created with wrong amount
**Cause**: The algorithm divides total target by estimated cycles based on date range

**Solution**: Check your start and end date are correct

## Checking Auto-Deduction Status

### On Home Page

1. **View Recent Transfers**: Scroll through transactions
2. **Look for transfers marked**: "Auto-deduction for savings goal"
3. **Transfer shows**: `isAutoDeduction = true`
4. **Linked to goal**: `savingGoalId = {goalId}`

### In Savings Page

1. **Click on your savings goal**
2. **View "Current Amount"**: Should increase by deduction amount daily/weekly/monthly
3. **Timeline**: Shows progress toward target

## API Integration

### Backend Auto-Deduction Service

A complementary **backend scheduler** (Python) also runs every hour to handle auto-deductions:

**File**: `backend/auto_deduction.py`

Features:
- Runs independently of app (works even if user doesn't open app)
- Double-checks transfers weren't created by app already (prevents duplicates)
- Catches any missed cycles if backend is more frequently accessed than app

### Sync Strategy

Both systems (app + backend) work together:
1. **App checks** when user opens home page (real-time, responsive)
2. **Backend checks** every hour (background, automatic)
3. **De-duplication**: Both check `lastTransferDate` to prevent duplicate transfers

---

## Summary

| Component | Location | Trigger | Frequency |
|-----------|----------|---------|-----------|
| Flutter Service | `lib/services/auto_deduction_service.dart` | Home page load + app resume | On demand |
| Home Screen Integration | `lib/screens/home_screen.dart` | `initState` + lifecycle | Per session |
| Backend Service | `backend/auto_deduction.py` | Scheduler | Every hour |
| Database | Supabase SavingGoal table | N/A | Stores goal config |

This ensures your savings goals are funded **consistently and automatically**! 🎯
