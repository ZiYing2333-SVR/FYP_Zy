# Auto-Deduction Troubleshooting & Debugging Guide

## Step 1: Check the Console Logs

When you open the app, look for these log entries:

```
[AutoDeductionService] ========== AUTO-DEDUCTION CHECK START ==========
[AutoDeductionService] Current time: 2026-04-10 14:30:45.123456
[AutoDeductionService] Checking auto-deductions for user: user_id_here
[AutoDeductionService] Fetching SavingGoal records... (status=active, cycleStatus=true)
[AutoDeductionService] Found X active cycle-based goals
```

### If you see "Found 0 active cycle-based goals":

**Problem**: No savings goals exist with the required settings

**Solution**: 
1. You need to create a savings goal first
2. The goal must have:
   - `status` = "active" (NOT "paused" or "completed")
   - `cycleStatus` = true (NOT false)
   - `cycleFrequency` = "daily", "weekly", or "monthly"
   - `sourceAccountId` - Account to deduct from
   - `destAccountId` - Account to transfer to

**How to check in Supabase**:
1. Go to Supabase dashboard
2. Navigate to `SavingGoal` table
3. Check if any records exist
4. If no records, you need to create one first!

---

## Step 2: Verify SavingGoal Table Exists

### In Supabase Dashboard:

1. Click on "SQL Editor"
2. Run this query:
```sql
SELECT * FROM "SavingGoal" LIMIT 10;
```

**Expected result**: Should show your savings goals

**If you get an error like "relation 'SavingGoal' does not exist"**:
- The database migration hasn't been applied yet
- You need to run: `supabase migrations up`
- Or manually execute the migration SQL

---

## Step 3: Create a Test Savings Goal

If no goals exist, you need to create one. Use Supabase dashboard:

1. Go to `SavingGoal` table
2. Click "Insert" → "Add new row"
3. Fill in these fields:

```
goalId:           test_goal_1 (or auto-generate UUID)
name:             Test Daily Savings
type:             cycle
targetAmount:     100
currentAmount:    0
startDate:        2026-04-10 (today's date)
endDate:          2026-05-10 (30 days from today)
description:      Testing auto-deduction
status:           active ◄─── IMPORTANT!
cycleStatus:      true ◄─── IMPORTANT!
cycleFrequency:   daily ◄─── IMPORTANT!
icon:             piggy_bank (or any icon name)
sourceAccountId:  [your_checking_account_id]
destAccountId:    [your_savings_account_id]
linkedAccountId:  [your_account_id]
userId:           [your_user_id]
```

### Where to find account IDs:

1. Go to `Account` table in Supabase
2. Note the `accountId` values:
   - Pick a non-savings account for `sourceAccountId`  
   - Pick a savings account for `destAccountId`
   - Use your user account for `linkedAccountId`
3. Go to `User` table to get `userId`

---

## Step 4: Check Console Logs After Creating Goal

**If goal was created, reopen the app, you should see**:

```
[AutoDeductionService] ========== AUTO-DEDUCTION CHECK START ==========
[AutoDeductionService] Current time: 2026-04-10 14:30:45.123456
[AutoDeductionService] Checking auto-deductions for user: user_id
[AutoDeductionService] Fetching SavingGoal records... (status=active, cycleStatus=true)
[AutoDeductionService] Found 1 active cycle-based goals
[AutoDeductionService] Processing 1 goal(s)...
[AutoDeductionService] Processing goal: test_goal_1 (frequency: daily)
[AutoDeductionService] [DAILY] ✅ Deduction is due for test_goal_1 (last: 2026-04-10, today: 2026-04-10)
```

**Wait, this shows `last: 2026-04-10` and `today: 2026-04-10` - why does it say deduction is due?**

Because it's the first deduction! The "last" date is from `startDate`, so since we're on `startDate`, the deduction is due.

---

## Step 5: If Deduction is Not Due

### For DAILY frequency:
```log
[AutoDeductionService] [DAILY] ❌ Already deducted today for goal_id
(last: 2026-04-10, today: 2026-04-10)
```

**Meaning**: A transfer was already created today
- **Solution**: Wait until tomorrow and reopen the app

### For WEEKLY frequency:
```log
[AutoDeductionService] [WEEKLY] ❌ Not due yet for goal_id
(only 2/7 days, last: 2026-04-03)
```

**Meaning**: Only 2 days have passed, need 7
- **Solution**: Wait until 7 days pass since last deduction

### For MONTHLY frequency:
```log
[AutoDeductionService] [MONTHLY] ❌ Already done this month for goal_id
(last: 2026-04, current: 2026-04)
```

**Meaning**: Already deducted this month
- **Solution**: Wait until next month to trigger next deduction

---

## Step 6: If Transfer is Being Created

You should see:

```log
[AutoDeductionService] [TRANSFER] Creating transfer for goal: test_goal_1
[AutoDeductionService] [TRANSFER]   Source: acc_12345
[AutoDeductionService] [TRANSFER]   Destination: acc_67890
[AutoDeductionService] [TRANSFER]   Amount: 3.33
[AutoDeductionService] [TRANSFER] Checking source account balance...
[AutoDeductionService] [TRANSFER]   Source balance: 1000.00
[AutoDeductionService] [TRANSFER] ✅ Sufficient balance - proceeding with transfer
[AutoDeductionService] [TRANSFER] Inserting transfer record: AUTO_test_goal_1_1712771445000
[AutoDeductionService] [TRANSFER] ✅ Transfer inserted
[AutoDeductionService] [TRANSFER] Updating source account balance...
[AutoDeductionService] [TRANSFER] ✅ Source account updated (- 3.33)
[AutoDeductionService] [TRANSFER] Updating destination account balance...
[AutoDeductionService] [TRANSFER] ✅ Destination account updated (+ 3.33)
[AutoDeductionService] [TRANSFER] Updating SavingGoal progress...
[AutoDeductionService] [TRANSFER] ✅ SavingGoal updated (currentAmount: 0 → 3.33)
[AutoDeductionService] [TRANSFER] ✅✅✅ SUCCESS! Transfer created: AUTO_test_goal_1_1712771445000 | Amount: 3.33
```

**Great! If you see this, the transfer was created successfully!**

---

## Step 7: Verify Transfer in Database

Check if transfer was actually created:

1. Open Supabase dashboard
2. Go to `Transfer` table
3. Look for records with:
   - `isAutoDeduction` = true
   - `savingGoalId` = your goal ID
   - Recent `date` (today)

You should see your transfer record there!

---

## Common Error Messages & Solutions

### Error 1: "Insufficient balance in source account"
```
[AutoDeductionService] [TRANSFER] ❌ Insufficient balance. Available: 5.00, Required: 50.00
```

**Problem**: Source account doesn't have enough money
**Solution**: Add funds to the source account, or reduce the savings goal amount

---

### Error 2: "Source account not set for goal"
```
[AutoDeductionService] [TRANSFER] ❌ ERROR: Source account not set for goal test_goal_1
```

**Problem**: `sourceAccountId` is null in the SavingGoal
**Solution**: Update the goal with a valid `sourceAccountId`

```sql
UPDATE "SavingGoal" 
SET "sourceAccountId" = 'valid_account_id'
WHERE "goalId" = 'test_goal_1';
```

---

### Error 3: "Error creating transfer: relation 'Transfer' does not exist"
```
[AutoDeductionService] [TRANSFER] ❌❌❌ ERROR creating transfer: 
PostgrestException: relation "Transfer" does not exist
```

**Problem**: Transfer table doesn't exist or hasn't been migrated
**Solution**: Run the database migration

---

### Error 4: "CRITICAL ERROR in checkAndCreateAutoDeductions"
```
[AutoDeductionService] ❌ CRITICAL ERROR in checkAndCreateAutoDeductions: 
PostgrestException: relation "SavingGoal" does not exist
```

**Problem**: SavingGoal table doesn't exist
**Solution**: 
1. Apply the database migration
2. Or manually create the table using the migration SQL

---

## Checklist: System Prerequisites

- [ ] **SavingGoal table exists**
  - Check: `SELECT * FROM "SavingGoal" LIMIT 1;`
  
- [ ] **Transfer table extended with columns**
  - Check: `SELECT * FROM "Transfer" LIMIT 1;` and verify `isAutoDeduction` and `savingGoalId` columns exist
  
- [ ] **Test SavingGoal record exists**
  - Check: Go to SavingGoal table and see at least 1 record
  
- [ ] **Test goal has correct settings**
  - [ ] `status` = "active"
  - [ ] `cycleStatus` = true
  - [ ] `cycleFrequency` = "daily" (or weekly/monthly)
  - [ ] `sourceAccountId` is set and not null
  - [ ] `destAccountId` is set and not null
  - [ ] `userId` matches current user
  
- [ ] **Source account has sufficient balance**
  - Check: `SELECT balance FROM "Account" WHERE accountId = 'source_id';`
  - Must be >= calculated deduction amount
  
- [ ] **Destination account exists**
  - Check: `SELECT * FROM "Account" WHERE accountId = 'dest_id';`

- [ ] **Dart code has AutoDeductionService import**
  - Check: `lib/screens/home_screen.dart` imports `auto_deduction_service.dart`
  
- [ ] **_checkAutoDeductions() is called**
  - Check: `lib/screens/home_screen.dart` initState and didChangeAppLifecycleState call it

---

## Quick Debug Checklist

If auto-deduction still isn't working, run through this:

1. **Check logs** - Do you see the `AUTO-DEDUCTION CHECK START` message?
   - If NO → Check if `_checkAutoDeductions()` is being called
   
2. **Check goals count** - Does it say "Found 0" or "Found X"?
   - If 0 → Create a test SavingGoal
   
3. **Check frequency** - Do the frequency logs show why it's not due?
   - If "already deducted today" → Normal behavior, wait until tomorrow
   - If "not due yet" → Normal behavior, wait for the frequency to pass
   
4. **Check transfer creation** - Does it reach the transfer creation step?
   - If NO → Check the `_isDeductionDue()` logs
   - If YES but fails → Check for balance/account errors
   
5. **Check database** - Manually query the Transfer table
   ```sql
   SELECT * FROM "Transfer" 
   WHERE "isAutoDeduction" = true 
   ORDER BY "createdAt" DESC LIMIT 5;
   ```
   Should show your newly created transfers

---

## Enable Debug Mode

To get even more detailed logs, you can modify the service to print all variable values. Look for all `print()` statements prefixed with `[AutoDeductionService]`.

They now include:
- ✅ - Success indicators
- ❌ - Error indicators
- ⚠️ - Warning indicators
- [SECTION] - Current operation (DAILY, TRANSFER, ERROR, etc.)

---

## Next Steps if Still Not Working

1. **Check the Flutter logs in real-time**:
   ```bash
   flutter logs
   ```
   
2. **Search for `[AutoDeductionService]` in the output**

3. **Take a screenshot of the logs** and share the sequence

4. **Verify the database**:
   - SavingGoal table has correct data
   - Transfer tables has the new columns
   - Account balances are correct

---

## Success Indicators

When everything is working, you will see:

✅ Logs showing `Found X active cycle-based goals`
✅ Logs showing frequency check (e.g., `[DAILY] ✅ Deduction is due`)
✅ Logs showing transfer creation steps (TRANSFER section)
✅ Logs showing `✅✅✅ SUCCESS!`
✅ New Transfer record visible in Supabase
✅ Source account balance decreased
✅ Destination account balance increased
✅ SavingGoal currentAmount increased
✅ Transfer appears in app transactions list

---

## Performance Notes

- First check: When app loads (initState)
- Subsequent checks: When app comes back from background (lifecycle)
- Checks are async and don't block UI
- Each check takes ~100-500ms depending on network
- All changes written immediately to database
- Transactions refreshed only if transfers created

---

Now reopen your app and check the console logs! The detailed logging will help us identify exactly what's happening. 📊
