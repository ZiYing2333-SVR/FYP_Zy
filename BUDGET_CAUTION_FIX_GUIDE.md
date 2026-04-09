# Budget Alert System - Complete Setup Guide

## Overview

This guide covers the complete budget alert system with two types of dismissible alerts:
1. **Caution Alert** (70-99% usage) - Orange warning icon
2. **Exceed Alert** (>100% usage) - Red alert icon

## Database Setup

### Step 1: Run the Migrations in Supabase

1. Go to your **Supabase Dashboard** → Select your project
2. Navigate to **SQL Editor** (left sidebar)
3. Click **New Query**

#### Migration 1: Create BudgetCaution Table

Copy and paste the entire contents of:
```
supabase/migrations/create_budget_caution_table.sql
```
Click **Run** and verify `SUCCESS`

#### Migration 2: Add Exceed Alert Columns

Copy and paste the entire contents of:
```
supabase/migrations/add_exceed_alert_columns.sql
```
Click **Run** and verify `SUCCESS`

### Step 2: Verify Table Structure

1. Go to **Table Editor** in Supabase
2. Click on `BudgetCaution` table
3. Verify columns exist:
   - `cautionId` (UUID, primary key)
   - `budgetId` (varchar)
   - `userId` (varchar)
   - `dismissed` (boolean) - for caution alerts
   - `dismissedAt` (timestamp) - for caution alerts
   - `exceedDismissed` (boolean) - for exceed alerts
   - `exceedDismissedAt` (timestamp) - for exceed alerts
   - `createdAt` (timestamp)
   - `updatedAt` (timestamp)

## App Behavior

### Caution Alert (70-99% Usage)
✅ Shows orange warning icon on budget card
✅ Dialog appears when caution budgets detected
✅ User can tick "don't show this again"
✅ Icon disappears until budget cycle resets
✅ Auto-reset when entering new cycle (daily/weekly/monthly/yearly)

### Exceed Alert (>100% Usage)  
✅ Shows red alert icon on budget card
✅ Dialog appears when budget exceeds limit
✅ User can tick "don't show this again"
✅ Icon disappears until amount is reduced below budget
✅ Auto-reset when budget goes below 100% again

## Testing the Alerts

### Test Caution Alert
1. Navigate to **Budget** page
2. Create a budget with amount RM100
3. Add expenses totaling RM75 or more (75%+)
4. You should see an orange warning icon
5. Tap the icon or wait for the dialog
6. Check "don't show this again" and click Confirm
7. Icon should disappear immediately
8. Icon reappears when cycle resets

### Test Exceed Alert
1. Create a budget with amount RM100
2. Add expenses totaling RM101 or more (101%+)
3. You should see a red alert icon  
4. Tap the icon or wait for the dialog
5. Check "don't show this again" and click Confirm
6. Icon should disappear immediately
7. Icon reappears when amount is reduced below RM100

## Database Schema

### BudgetCaution Table

```sql
Table: public.BudgetCaution

Columns:
- cautionId (UUID) - Primary key, auto-generated
- budgetId (varchar) - References Budget.budgetId
- userId (varchar) - References User.userId
- dismissed (boolean) - Caution alert dismissed status (70-99%)
- dismissedAt (timestamp) - When caution was dismissed
- exceedDismissed (boolean) - Exceed alert dismissed status (>100%)
- exceedDismissedAt (timestamp) - When exceed was dismissed
- createdAt (timestamp) - Record creation time
- updatedAt (timestamp) - Record update time

Constraints:
- UNIQUE(budgetId, userId) - One record per budget per user
- Foreign keys to Budget and User tables
- Cascade delete on Budget/User removal

Indexes:
- idx_budget_caution_budget - For budgetId queries
- idx_budget_caution_user - For userId queries
- idx_budget_caution_dismissed - For dismissal lookups
- idx_budget_caution_exceed_dismissed - For exceed dismissal lookups
```

## Code Architecture

### BudgetAlertService (`lib/services/budget_alert_service.dart`)

#### Caution Alert Methods:
- `isCautionDismissed()` - Check if caution dismissed + cycle renewed
- `getCautionBudgets()` - Get all caution budgets for user
- `dismissCautionAlert()` - Record caution dismissal
- `hasAnyCautionAlert()` - Check if any active caution exists

#### Exceed Alert Methods:
- `isExceedDismissed()` - Check if exceed dismissed
- `getExceedBudgets()` - Get all exceed budgets for user
- `dismissExceedAlert()` - Record exceed dismissal
- `hasAnyExceedAlert()` - Check if any active exceed exists

### BudgetPage (`lib/screens/budget_page.dart`)

#### New Methods:
- `_checkAndShowExceedAlert()` - Check and display exceed dialogs
- `_showExceedAlertDialog()` - Render exceed alert dialog
- `_dismissExceedAlert()` - Handle exceed dismissal
- `_shouldShowAlertIcon()` - Determine if icon should display

#### Updated Methods:
- `_checkAndShowCautionAlert()` - Now also checks exceed
- Icon rendering now uses FutureBuilder to check dismissal status

## Troubleshooting

### Icons Still Show After Dismissal
1. **Clear app cache:**
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

2. **Verify database record:**
   - Go to Supabase Table Editor
   - Click `BudgetCaution` table
   - Check for entries matching your budgetId with:
     - `dismissed = true` (caution)
     - `exceedDismissed = true` (exceed)

3. **Check logs:**
   - Look for `[BudgetAlertService]` messages
   - Database errors show here

### Dialog Not Appearing
1. **Check budget usage:**
   - Caution: Usage must be 70-100%
   - Exceed: Usage must be >100%

2. **Verify dismissal not active:**
   - Caution: Not dismissed AND cycle hasn't renewed
   - Exceed: Not dismissed OR budget below 100%

3. **Test with fresh budget:**
   - Create new budget
   - Add fresh expenses
   - Check if dialog appears

### Icons Not Disappearing
1. **Ensure column exists:**
   ```sql
   SELECT * FROM information_schema.columns 
   WHERE table_name = 'BudgetCaution' 
   AND column_name = 'exceedDismissed';
   ```

2. **If missing, run migration:**
   ```sql
   ALTER TABLE public."BudgetCaution"
   ADD COLUMN IF NOT EXISTS "exceedDismissed" BOOLEAN DEFAULT false,
   ADD COLUMN IF NOT EXISTS "exceedDismissedAt" TIMESTAMP WITH TIME ZONE;
   ```

## Auto-Reset Mechanism

### Caution Alert Auto-Reset
- Cycle Type: `day` → Resets midnight
- Cycle Type: `week` → Resets Monday morning
- Cycle Type: `month` → Resets 1st of month
- Cycle Type: `year` → Resets Jan 1st

### Exceed Alert Auto-Reset
- Resets immediately when budget amount ≤ 100%
- No cycle dependency

## Future Enhancements
- [x] Track both caution and exceed dismissals
- [x] Show dismiss dialogs for exceed
- [x] Hide icons based on dismissal status
- [ ] Analytics on dismissal frequency
- [ ] Per-user notification preferences
- [ ] Email notifications for exceed
- [ ] Scheduled alerts for approaching limits

## Questions?

### Related Files:
- **Service:** `lib/services/budget_alert_service.dart`
- **UI:** `lib/screens/budget_page.dart`
- **Migrations:** `supabase/migrations/` folder

### Key Logic:
- Dismissal state stored in `BudgetCaution` table
- Two separate dismissal flags per budget
- Auto-reset based on status/cycle changes
- Icons rendered conditionally based on dismissal + threshold

