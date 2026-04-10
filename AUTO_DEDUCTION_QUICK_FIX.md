# Auto-Deduction - QUICK START TROUBLESHOOTING

## The Issue
Auto-deduction transfers are not being created automatically.

## The Root Causes (Most Common)
1. ❌ **SavingGoal table doesn't exist** (migration not applied)
2. ❌ **No test savings goals created** (nothing to process)
3. ❌ **Test goal has wrong settings** (status/cycleStatus/frequency)
4. ❌ **Source account has no balance** (can't deduct)
5. ❌ **Deduction isn't due yet** (waiting for next cycle)

---

## IMMEDIATE ACTION PLAN

### Action 1: Rebuild & Check Logs (5 minutes)

```bash
cd c:\Users\Zy231\StudioProjects\fyp_zy

# Clean and build
flutter clean
flutter pub get
flutter run
```

✅ **What to look for in console**:
- Should see: `[AutoDeductionService] ========== AUTO-DEDUCTION CHECK START ==========`
- If you DON'T see this → Method not being called → Check home_screen.dart
- If you DO see this → Continue to Action 2

---

### Action 2: Check Console Output (2 minutes)

**Search your console for these patterns**:

Pattern 1: Goals found count
```
[AutoDeductionService] Found X active cycle-based goals
```

- **If `Found 0`** → Go to Action 3 (Create test goal)
- **If `Found 1+`** → Go to Action 4 (Check details)

---

### Action 3: Create a Test Savings Goal (5 minutes)

If no goals found, add one in Supabase:

1. Open Supabase dashboard
2. Go to `SavingGoal` table
3. Click "Insert" → "New row"
4. Fill in:

```
goalId:           test_goal_1
name:             Test Daily Savings
type:             cycle
targetAmount:     100
currentAmount:    0
startDate:        2026-04-10 (TODAY)
endDate:          2026-05-10 (30 days from today)
status:           active ◄─── CRITICAL!
cycleStatus:      true ◄─── CRITICAL!
cycleFrequency:   daily
icon:             piggy_bank
sourceAccountId:  [your_checking_account_id]
destAccountId:    [your_savings_account_id]
linkedAccountId:  [your_account_id]
userId:           [your_user_id]
```

❓ **Don't know your account IDs?**
- Open Supabase → `Account` table → Copy accountId
- Checking/Main account → sourceAccountId
- Savings account → destAccountId

5. **Reopen the app** → Go to Action 2 again

---

### Action 4: Analyze the Logs (5 minutes)

After creating a goal and reopening app, search console for:

**Pattern A: Frequency Check**
```
[AutoDeductionService] [DAILY] ✅ Deduction is due for test_goal_1
```

✅ If you see `✅` → Deduction is due → Go to Action 5
❌ If you see `❌ Already deducted today` → Normal! Try tomorrow or use weekly

**Pattern B: Transfer Creation**
```
[AutoDeductionService] [TRANSFER] ✅✅✅ SUCCESS! Transfer created
```

✅ If you see `SUCCESS` → Transfer WAS created! Check Supabase
❌ If you see `ERROR` → See error message → Fix and retry

**Pattern C: Final Summary**
```
[AutoDeductionService] ========== AUTO-DEDUCTION CHECK SUMMARY ==========
[AutoDeductionService] Transfers created: X
```

✅ If X > 0 → Transfers created! Check Supabase
❌ If X = 0 → Check logs above for why

---

### Action 5: Verify in Supabase (3 minutes)

Go to `Transfer` table and look for:

```sql
WHERE "isAutoDeduction" = true 
AND "savingGoalId" = 'test_goal_1'
```

✅ **You should see**:
- New Transfer record with today's date
- `isAutoDeduction` = true
- Amount ≈ 3.33 (100 ÷ 30 days)

---

### Action 6: Check Account Balances Updated (3 minutes)

Go to `Account` table:

```
BEFORE auto-deduction:
  Source account:      1000.00
  Destination account: 5000.00

AFTER auto-deduction:
  Source account:      996.67 ← Decreased by 3.33
  Destination account: 5003.33 ← Increased by 3.33
```

✅ If balances changed → System working correctly!
❌ If balances same → Transfer didn't execute → Check logs for errors

---

### Action 7: Verify in App (2 minutes)

Open your app and check:

✅ **Transactions list** should show new auto-deduction transfer
✅ **Savings page** should show goal progress increased
✅ **Accounts page** should show updated balances

---

## Common Issues & Quick Fixes

| Issue | Fix |
|-------|-----|
| `Found 0 goals` | Create a test goal (Action 3) |
| `❌ Already deducted today` | Normal! Wait until tomorrow, or change to weekly/monthly |
| `❌ Insufficient balance` | Add funds to source account |
| `❌ Source account not set` | Update goal with valid sourceAccountId |
| `CRITICAL ERROR: relation 'SavingGoal' does not exist` | Apply migration: `supabase migrations up` |

---

## Complete Diagnostic Queries

Run these in Supabase SQL Editor:

```sql
-- Check 1: Does SavingGoal table exist?
SELECT * FROM "SavingGoal" LIMIT 1;

-- Check 2: Do you have active cycle goals?
SELECT COUNT(*) as active_goals
FROM "SavingGoal"
WHERE "status" = 'active' AND "cycleStatus" = true;

-- Check 3: Are auto-deduction transfers being created?
SELECT COUNT(*) as auto_deductions, MAX("date") as latest
FROM "Transfer"
WHERE "isAutoDeduction" = true;

-- Check 4: Have balances changed?
SELECT "accountId", "balance" FROM "Account" ORDER BY "accountId";
```

---

## Timeline Estimate

- **Total time to diagnose**: 20-30 minutes
- **Rebuild**: 2-3 minutes
- **Create test goal**: 5 minutes
- **Wait for app reload**: 1 minute
- **Analysis**: 5 minutes
- **Database verification**: 5 minutes
- **Fix any issues**: 5-10 minutes

---

## Success Indicators

✅ Console shows `[AutoDeductionService] ✅✅✅ SUCCESS!`
✅ Transfer record appears in Supabase with `isAutoDeduction = true`
✅ Source account balance decreased
✅ Destination account balance increased
✅ SavingGoal currentAmount increased
✅ Transfer appears in app transaction list

---

## Still Not Working?

1. Run all diagnostics above
2. Document the exact console ERROR message
3. Check the detailed guides:
   - `AUTO_DEDUCTION_DEBUGGING_GUIDE.md` - Console log analysis
   - `AUTO_DEDUCTION_DATABASE_VERIFICATION.md` - SQL verification

---

## TL;DR

1. ✅ `flutter clean && flutter pub get && flutter run`
2. ✅ Check console for `[AutoDeductionService]` logs
3. ✅ If 0 goals → Create test goal in Supabase
4. ✅ If transfer ERROR → Read error message → Fix issue
5. ✅ If SUCCESS → Verify in Supabase Transfer table
6. ✅ Verify balances changed and progress updated

You've got this! 🚀
