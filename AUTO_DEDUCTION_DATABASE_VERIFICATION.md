# Auto-Deduction System - Database Verification Checklist

Use these SQL queries in Supabase SQL Editor to verify your system is properly set up.

---

## Check 1: SavingGoal Table Exists

```sql
-- Check if SavingGoal table exists
SELECT table_name 
FROM information_schema.tables 
WHERE table_name = 'SavingGoal';
```

**Expected**: One row with `SavingGoal`
**If empty**: Table doesn't exist - need to run migration

---

## Check 2: SavingGoal Table Structure

```sql
-- Check SavingGoal columns
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'SavingGoal'
ORDER BY ordinal_position;
```

**Expected columns**:
- `goalId` (character varying)
- `name` (character varying)
- `type` (character varying)
- `targetAmount` (double precision)
- `currentAmount` (double precision)
- `startDate` (date)
- `endDate` (date)
- `status` (character varying)
- `cycleStatus` (boolean)
- `cycleFrequency` (text)
- `sourceAccountId` (character varying)
- `destAccountId` (character varying)
- `linkedAccountId` (character varying)
- `userId` (character varying)

---

## Check 3: Transfer Table has Auto-Deduction Columns

```sql
-- Check if Transfer table has auto-deduction columns
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'Transfer' 
AND column_name IN ('savingGoalId', 'isAutoDeduction')
ORDER BY column_name;
```

**Expected**: Two rows
- `isAutoDeduction` (boolean)
- `savingGoalId` (character varying)

**If empty**: Columns don't exist - need to add them or run migration

---

## Check 4: All Active Cycle-Based Savings Goals

```sql
-- This is exactly what the auto-deduction service queries
SELECT 
    "goalId",
    "name",
    "cycleFrequency",
    "targetAmount",
    "currentAmount",
    "status",
    "cycleStatus",
    "sourceAccountId",
    "destAccountId",
    "startDate",
    "endDate"
FROM "SavingGoal"
WHERE "userId" = 'your_user_id'  -- Replace with your actual user ID
AND "status" = 'active'
AND "cycleStatus" = true;
```

**Expected**: Rows for all your active daily/weekly/monthly savings goals
**If empty**: No goals are set up yet - create one!

---

## Check 5: Test Goal Details

```sql
-- Get full details of one goal
SELECT *
FROM "SavingGoal"
WHERE "goalId" = 'test_goal_1';  -- Replace with your goal ID
```

**Verify these fields**:
- ✅ `status` = 'active' (not 'paused' or 'completed')
- ✅ `cycleStatus` = true (not false)
- ✅ `cycleFrequency` is 'daily', 'weekly', or 'monthly'
- ✅ `sourceAccountId` is NOT null
- ✅ `destAccountId` is NOT null
- ✅ `startDate` should be today or earlier
- ✅ `endDate` should be today or later
- ✅ `targetAmount` > 0
- ✅ `userId` matches your user ID

---

## Check 6: Verify Source Account Exists and Has Balance

```sql
-- Check source account
SELECT "accountId", "accountName", "balance", "accountType"
FROM "Account"
WHERE "accountId" = 'your_source_account_id';  -- From SavingGoal.sourceAccountId
```

**Verify**:
- ✅ Account exists (1 row returned)
- ✅ `balance` >= expected deduction amount
- ✅ `accountType` is NOT 'savings' (should be checking/cash)

---

## Check 7: Verify Destination Account Exists

```sql
-- Check destination account
SELECT "accountId", "accountName", "balance", "accountType"
FROM "Account"
WHERE "accountId" = 'your_dest_account_id';  -- From SavingGoal.destAccountId
```

**Verify**:
- ✅ Account exists (1 row returned)
- ✅ `accountType` = 'savings' (should be savings)

---

## Check 8: Calculate Expected Deduction Amount

For your test goal, manually calculate what amount should be deducted:

```
startDate: 2026-04-10
endDate:   2026-05-10
Duration:  30 days

For DAILY frequency:
  Amount = targetAmount / days
  Amount = 100 / 30 = 3.33 per day

For WEEKLY frequency:
  Amount = targetAmount / weeks
  Amount = 100 / 4 ≈ 25 per week (30 days ≈ 4 weeks)

For MONTHLY frequency:
  Amount = targetAmount / months
  Amount = 100 / 1 = 100 per month
```

---

## Check 9: View All Auto-Deduction Transfers

```sql
-- See all auto-deduction transfers created
SELECT 
    "transferId",
    "savingGoalId",
    "fromAccountId",
    "toAccountId",
    "amount",
    "date",
    "time",
    "isAutoDeduction",
    "createdAt"
FROM "Transfer"
WHERE "isAutoDeduction" = true
ORDER BY "createdAt" DESC
LIMIT 20;
```

**Expected**: After running the app, you should see your transfer here
**Columns to verify**:
- ✅ `isAutoDeduction` = true
- ✅ `savingGoalId` = your goal ID
- ✅ `amount` = calculated deduction amount
- ✅ `date` = today's date
- ✅ `fromAccountId` = your source account
- ✅ `toAccountId` = your destination account

---

## Check 10: Verify Account Balances Were Updated

```sql
-- Check source account after transfer
SELECT "accountId", "accountName", "balance"
FROM "Account"
WHERE "accountId" = 'your_source_account_id';

-- Check destination account after transfer
SELECT "accountId", "accountName", "balance"
FROM "Account"
WHERE "accountId" = 'your_dest_account_id';
```

**After a successful auto-deduction**:
- ✅ Source balance should be LOWER by deduction amount
- ✅ Destination balance should be HIGHER by deduction amount

Example:
```
Before:
  Source:      1000.00
  Destination: 5000.00

After $3.33 auto-deduction:
  Source:      996.67  (1000.00 - 3.33)
  Destination: 5003.33 (5000.00 + 3.33)
```

---

## Check 11: Verify SavingGoal Progress Updated

```sql
-- Check goal progress
SELECT 
    "goalId",
    "name",
    "targetAmount",
    "currentAmount",
    "startDate",
    "endDate"
FROM "SavingGoal"
WHERE "goalId" = 'test_goal_1';
```

**After successful auto-deduction**:
- ✅ `currentAmount` should be HIGHER (0 → 3.33 after first deduction)

---

## Check 12: View Last Auto-Deduction Transfer for a Goal

```sql
-- Get the most recent auto-deduction transfer for a specific goal
SELECT *
FROM "Transfer"
WHERE "savingGoalId" = 'test_goal_1'  -- Your goal ID
AND "isAutoDeduction" = true
ORDER BY "date" DESC, "time" DESC
LIMIT 1;
```

**Expected**: 
- Recent date (today)
- Amount matches calculated value
- `isAutoDeduction` = true

---

## Check 13: Verify User ID is Correct

```sql
-- Get your user ID
SELECT "userId", email, "firstName", "lastName"
FROM "User"
LIMIT 1;
```

**Note**: Use this `userId` when creating test goals or checking logs

---

## Check 14: Validate Goal Dates

```sql
-- Double-check your goal's dates
SELECT 
    "goalId",
    "name",
    "startDate",
    "endDate",
    NOW()::date as today,
    ("endDate" - "startDate") * 1 as days_until_end
FROM "SavingGoal"
WHERE "goalId" = 'test_goal_1';
```

**Rules**:
- ✅ `startDate` should be ≤ today
- ✅ `endDate` should be ≥ today
- ✅ `days_until_end` should be > 0 (goal not expired)

---

## Check 15: Full System Diagnostic

Run this comprehensive check:

```sql
-- DIAGNOSTIC QUERY
WITH goal_check AS (
    SELECT 
        COUNT(*) as total_goals,
        COUNT(*) FILTER (WHERE "status" = 'active' AND "cycleStatus" = true) as active_cycle_goals,
        COUNT(*) FILTER (WHERE "sourceAccountId" IS NULL) as goals_missing_source
    FROM "SavingGoal"
    WHERE "userId" = 'your_user_id'
),
transfer_check AS (
    SELECT 
        COUNT(*) as total_transfers,
        COUNT(*) FILTER (WHERE "isAutoDeduction" = true) as auto_deductions,
        MAX("createdAt") as last_transfer
    FROM "Transfer"
),
account_check AS (
    SELECT 
        COUNT(*) as total_accounts,
        COUNT(*) FILTER (WHERE "balance" < 0) as accounts_with_negative_balance,
        MIN("balance") as lowest_balance,
        MAX("balance") as highest_balance
    FROM "Account"
)
SELECT 
    'Goals' as category,
    'Total' as metric,
    total_goals::text as value
FROM goal_check
UNION ALL
SELECT 'Goals', 'Active & Cycle', active_cycle_goals::text FROM goal_check
UNION ALL
SELECT 'Goals', 'Missing Source', goals_missing_source::text FROM goal_check
UNION ALL
SELECT 'Transfers', 'Total', total_transfers::text FROM transfer_check
UNION ALL
SELECT 'Transfers', 'Auto-Deductions', auto_deductions::text FROM transfer_check
UNION ALL
SELECT 'Transfers', 'Last Created', last_transfer::text FROM transfer_check
UNION ALL
SELECT 'Accounts', 'Total', total_accounts::text FROM account_check
UNION ALL
SELECT 'Accounts', 'Negative Balance', accounts_with_negative_balance::text FROM account_check
UNION ALL
SELECT 'Accounts', 'Min Balance', ROUND(lowest_balance::numeric, 2)::text FROM account_check
UNION ALL
SELECT 'Accounts', 'Max Balance', ROUND(highest_balance::numeric, 2)::text FROM account_check;
```

This gives you a complete system overview in one query!

---

## Quick Test Plan

### Step 1: Run Check 1-7
Verify tables, columns, and test data exist

### Step 2: Create Test Goal (if needed)
```sql
INSERT INTO "SavingGoal" (
    "goalId", "name", "type", "targetAmount", "currentAmount",
    "startDate", "endDate", "status", "cycleStatus", "cycleFrequency",
    "sourceAccountId", "destAccountId", "linkedAccountId", "userId"
) VALUES (
    'test_' || gen_random_uuid()::text,
    'Auto-Deduction Test',
    'cycle',
    100,
    0,
    CURRENT_DATE,
    CURRENT_DATE + INTERVAL '30 days',
    'active',
    true,
    'daily',
    'your_checking_account_id',
    'your_savings_account_id',
    'your_account_id',
    'your_user_id'
);
```

### Step 3: Reopen App
The app will automatically:
- Fetch this goal
- Detect deduction is due
- Create transfer
- Update balances
- Update goal progress

### Step 4: Check Logs
Look for `[AutoDeductionService]` entries

### Step 5: Run Checks 8-12
Verify transfer, balances, and progress were updated

---

## Troubleshooting with These Queries

| Problem | Query to Run |
|---------|--------------|
| No goals found | Check 4 |
| Goal has wrong status | Check 5 |
| Source account not found | Check 6 |
| Source account has no balance | Check 6 |
| Transfer not created | Check 9 |
| Accounts not updated | Check 10 |
| Goal progress not updated | Check 11 |
| Dates invalid | Check 14 |
| Overall system health | Check 15 |

---

Now run these queries to diagnose your system! 🔍
