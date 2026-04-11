# Missing Transfer Detection & Auto-Deduction Feature

## Overview

When users don't open the app for an extended period, they may miss several auto-deduction transfers. This feature automatically detects "missing" transfers and prompts the user to auto-deduct them in bulk when they next open the app.

---

## What is a "Missing" Transfer?

A missing transfer is any transfer that **should have been created** based on the goal's start date, end date, and frequency, but **hasn't been created yet**, OR was **created but then refunded**.

### Examples:

**Daily savings goal** (started 4/1, today 4/10):
- Expected: 10 transfers (one per day)
- Actual created: 3 transfers
- Missing: 7 transfers ❌

**Refunded transfers count as missing:**
- Transfer was created on 4/5 but user refunded it
- That refunded transfer counts as "missing" again
- It should be re-deducted

---

## How It Works

### 1. **On App Open (Home Page Load)**

When user opens the app:
- ✅ Checks all active cycle-based savings goals
- ✅ Calculates expected transfers based on goal dates and frequency
- ✅ Counts actual non-refunded transfers
- ✅ Detects missing transfers (including refunded ones)
- ✅ Shows alert for goals with missing transfers

### 2. **Alert Dialog Display**

If missing transfers are detected, alert shows:
- **Goal Name** & Target Amount
- **Frequency** (daily, weekly, monthly)
- **Number of missing transfers** (e.g., "7 daily transfers")
- **Total missing amount** (e.g., "$23.33")
- **Current goal progress** (e.g., "50.00 / 100.00")

User can:
- **"Yes, Auto-Deduct All"** → Creates all missing transfers
- **"Not Now"** → Dismisses alert for this session

### 3. **Session-Based Dismissal**

If user selects "Not Now":
- Alert is dismissed for the current session
- Alert will **reappear after logout/login**
- This prevents recurring popups but ensures user is re-prompted when returning

---

## Implementation Details

### Files Added/Modified

#### **New Files:**
1. `lib/services/missing_transfer_alert_service.dart`
   - Detects missing transfers
   - Manages session dismissals
   - Generates alert messages
   - Processes batch auto-deductions

2. `lib/services/auto_deduction_service.dart` (Enhanced)
   - Added `checkForMissingTransfers()` method
   - Added `_calculateExpectedTransferCount()` method
   - Added `autoDeductMissingTransfers()` method for batch processing

#### **Modified Files:**
1. `lib/screens/home_screen.dart`
   - Imports MissingTransferAlertService
   - Adds tracking variable `_missingTransferAlertShown`
   - Enhanced `_checkAutoDeductions()` to also check for missing transfers
   - Added `_checkForMissingTransfersAlert()` method
   - Added `_showMissingTransferAlertDialog()` method for UI

### Key Classes & Methods

#### AutoDeductionService

```dart
// Check if a goal has missing transfers
static Future<Map<String, dynamic>?> checkForMissingTransfers(
  Map<String, dynamic> goal,
) async

// Calculate how many transfers should exist based on dates & frequency
static int _calculateExpectedTransferCount(
  DateTime startDate,
  DateTime endDate,
  String frequency,
) 

// Auto-deduct all missing transfers in batch
static Future<int> autoDeductMissingTransfers(
  Map<String, dynamic> missingInfo,
)
```

#### MissingTransferAlertService

```dart
// Check all goals for missing transfers
static Future<List<Map<String, dynamic>>> checkAllMissingTransfers(
  String userId,
)

// Dismiss an alert for current session (reappears after logout)
static void dismissAlertForSession(String userId, String goalId)

// Clear all dismissed alerts (called on logout)
static void clearDismissedAlerts(String userId)

// Generate formatted alert message
static String generateAlertMessage(Map<String, dynamic> missingInfo)
```

---

## How Missing Transfers Are Calculated

### For Daily Frequency

```
Expected count = Total days between startDate and endDate (inclusive)

Example:
- Start: 2026-04-01
- End: 2026-04-10
- Today: 2026-04-10
- Expected: 10 transfers (one per day)
```

### For Weekly Frequency

```
Expected count = ceil(Total days / 7)

Example:
- Start: 2026-03-01
- End: 2026-04-10 (41 days)
- Expected: ceil(41 / 7) = 6 transfers
```

### For Monthly Frequency

```
Expected count = Number of unique months between startDate and endDate

Example:
- Start: 2026-03-15
- End: 2026-06-15
- Expected: 4 transfers (March, April, May, June)
```

### Refunded Transfers

Any transfer with `refund = true` is **not counted** in the "actual" transfers, so it becomes part of the missing count:

```
Missing = Expected - Actual (where refund != true)
```

---

## User Workflow

### Scenario: User Opens App After 1 Week

1. **App opens** → Home screen loads
2. **Auto-deduction check runs:**
   - Found 1 daily savings goal
   - Expected transfers: 7 (one per day for 7 days)
   - Actual transfers: 1 (missed 6 days)
   - Missing: 6 transfers
3. **Alert dialog shows:**
   ```
   💰 Missing Transfers Detected
   
   Goal: Daily Savings
   You missed 6 daily transfers!
   
   Details:
   • Amount per transfer: $10.00
   • Total missing amount: $60.00
   • Current goal progress: 10.00 / 300.00
   
   [Not Now] [Yes, Auto-Deduct All]
   ```
4. **User clicks "Yes, Auto-Deduct All":**
   - Creates 6 transfer records
   - Deducts $60.00 from source account
   - Adds $60.00 to savings account
   - Updates goal progress to $70.00
5. **Success message shown:**
   - "✅ Auto-deducted 6 transfers for Daily Savings"
6. **Checks for more missing transfers:**
   - If other goals have missing transfers, shows next alert

---

## Alert Dismissal & Re-Appearance

### Session-Based Tracking

```
Session Dismissed Alerts = {
  userId: {Set of dismissed goalIds}
}
```

### Timeline

1. **App Open (Day 1)** → Alert shown for Goal A with 5 missing transfers
2. **User clicks "Not Now"** → Alert dismissed, stored in session memory
3. **User scrolls home page** → Alert doesn't reappear (already dismissed this session)
4. **User logs out** → Session memory cleared
5. **User logs back in** → Alert reappears for Goal A

### Clearing Dismissed Alerts

When user logs out, call:
```dart
MissingTransferAlertService.clearDismissedAlerts(userId);
```

**Location in code**: settings_screen.dart logout handler

---

## Console Logging

New console messages for debugging:

```
[AutoDeductionService] [MISSING] Goal: goal_1 | Frequency: daily | Expected: 7 | Actual: 1 | Missing: 6
[MissingTransferAlertService] Checking for missing transfers for user: UID0001
[MissingTransferAlertService] Found missing transfers for goal: goal_1 (Missing: 6)
[MissingTransferAlertService] Alert dismissed for session: goalId=goal_1 (will reappear after logout)
[MissingTransferAlertService] Processing missing transfers for goal: goal_1
[AutoDeductionService] [BATCH] Creating 6 missing transfers for goal: goal_1
[AutoDeductionService] [BATCH] ✅ Successfully created 6 of 6 missing transfers
```

---

## Testing Checklist

- [ ] Create a daily savings goal with start date in the past
- [ ] Don't open app for 3-5 days
- [ ] Open app → Alert should show with correct missing count
- [ ] Click "Yes, Auto-Deduct All" → Transfers created
- [ ] Verify in Supabase: 
  - Transfer records created with `isAutoDeduction = true`
  - Source account balance decreased
  - Destination account balance increased
  - Goal currentAmount increased
- [ ] Close and reopen app (same session) → Alert doesn't reappear
- [ ] Logout and login → Alert reappears if still missing transfers
- [ ] Test with refunded transfers:
  - Create goal, create a transfer manually
  - Refund it (set `refund = true`)
  - Don't open app for 1 day
  - Open app → Alert should show this as missing

---

## Error Handling

- **No goals found**: Alert not shown, logs message
- **Goal has no dates**: Goal skipped with debug message
- **Insufficient balance**: Individual transfer skipped, continues with rest
- **Database errors**: Caught and logged, doesn't crash app
- **Multiple missing goals**: Shows one alert at a time, shows next after user responds

---

## Future Enhancements

1. **Batch confirmation**: Instead of alerting one goal at a time, show all missing goals in a list
2. **Smart scheduling**: Ask if user wants to spread missing transfers over time instead of all at once
3. **Analytics**: Track how many missing transfers users defer vs. confirm
4. **Customizable behavior**: Let users set preference (always auto-deduct, never show again, etc.)

---

## Integration Checklist

- [x] Created AutoDeductionService enhancements
- [x] Created MissingTransferAlertService
- [x] Updated home_screen.dart to check and show alerts
- [ ] **TODO**: Add `MissingTransferAlertService.clearDismissedAlerts(userId)` call to logout handler in settings_screen.dart

---

## Key Metrics

**What the system tracks:**
- Expected transfer count (based on dates & frequency)
- Actual non-refunded transfer count
- Missing transfer count
- Total missing amount
- List of goals with missing transfers (per user per session)

**What impacts calculations:**
- Goal start date
- Goal end date
- Goal cycle frequency
- Current date/time
- Transfer refund status (`refund = true`)

---

## Notes

- Alerts appear once per session to avoid annoying users
- Dismissed status cleared on logout for fresh experience on next login
- All missing transfers use the same deduction amount (calculated once per goal)
- Multiple goals with missing transfers trigger sequential alerts
- Failed transfers are reported but don't block other transfers in the batch
