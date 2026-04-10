# Auto-Deduction System - Visual Flowcharts

## System Architecture Diagram

```
┌─────────────────────────────────────────────────────────┐
│           USER OPENS FLUTTER APP                        │
└────────────────────┬────────────────────────────────────┘
                     │
                     ↓
        ┌────────────────────────┐
        │   HomeScreen initState │
        │   or didChangeAppLift  │
        │   (AppLifecycleState)  │
        └────────┬───────────────┘
                 │
                 ├─→ _fetchLedgers()
                 │
                 ├─→ _checkAutoDeductions() ◄─── NEW
                 │
                 └─→ _checkBudgetAlertFlags()
                     _fetchTransactions()

┌─────────────────────────────────────────────────────────┐
│      AutoDeductionService.checkAndCreateAutoDeductions  │
├─────────────────────────────────────────────────────────┤
│  1. Fetch all SavingGoal records where:                 │
│     - userId = current user                            │
│     - status = 'active'                                │
│     - cycleStatus = true                               │
│                                                          │
│  2. For each goal:                                      │
│     └─→ Check if deduction due (frequency logic)       │
│         ├─ Daily: Is today a new date?                 │
│         ├─ Weekly: 7+ days since last?                 │
│         └─ Monthly: Different month?                   │
│                                                          │
│  3. If due:                                             │
│     ├─→ Calculate amount (target ÷ cycles)             │
│     ├─→ Check source balance sufficient                │
│     ├─→ Create Transfer record                         │
│     ├─→ Update source account (-$)                     │
│     ├─→ Update dest account (+$)                       │
│     └─→ Update goal currentAmount (+$)                 │
│                                                          │
│  4. Return result                                       │
└─────────────────────────────────────────────────────────┘
                     │
                     ↓
        ┌────────────────────────┐
        │  _fetchTransactions()  │
        │  (if transfers created)│
        └────────┬───────────────┘
                 │
                 ↓
        ┌────────────────────────┐
        │   Display new          │
        │   transfers to user    │
        └────────────────────────┘
```

## Deduction Due Logic - Decision Tree

```
                    ┌─────────────────────────┐
                    │ Goal has cycleFrequency │
                    └────────────┬────────────┘
                                 │
                   ┌─────────────┼─────────────┐
                   │             │             │
                   ↓             ↓             ↓
            ┌────────────┐  ┌────────────┐  ┌────────────┐
            │   DAILY    │  │  WEEKLY    │  │  MONTHLY   │
            └─────┬──────┘  └─────┬──────┘  └─────┬──────┘
                  │                │              │
                  ↓                ↓              ↓
         Get last transfer  Get last transfer  Get last transfer
         
                  │                │              │
                  ↓                ↓              ↓
    Is TODAY !=  Is DAYS >=  Is MONTH/YEAR
    LAST_DATE?    7 days?      different?
                  │                │              │
           ┌──────┴──────┐  ┌──────┴──────┐  ┌──────┴──────┐
           ↓             ↓  ↓             ↓  ↓             ↓
          YES            NO YES           NO YES            NO
           │              │  │             │  │              │
           ↓              ↓  ↓             ↓  ↓              ↓
    ✅ TRANSFER     ❌ SKIP  ✅ TRANSFER  ❌ SKIP  ✅ TRANSFER  ❌ SKIP
    TODAY          TODAY   WEEKLY       WEEKLY  NEW_MONTH   MONTH
```

## Transfer Creation Process Flow

```
           ┌─────────────────────────┐
           │ Create Auto-Deduction   │
           │ Transfer Record         │
           └────────────┬────────────┘
                        │
                        ↓
        ┌───────────────────────────────┐
        │ Validate Source Account       │
        │ Has sufficient balance?       │
        └─────┬───────────────┬─────────┘
              │               │
         YES  │               │  NO
              ↓               ↓
        ┌──────────┐      ┌────────────┐
        │ Continue │      │ Log Error  │
        │ Transfer │      │ & Return   │
        └────┬─────┘      └────────────┘
             │
             ↓
    ┌────────────────────────────┐
    │ Calculate Deduction Amount │
    │ targetAmount ÷ cycles      │
    └────────────┬───────────────┘
                 │
                 ↓
    ┌────────────────────────────┐
    │ Generate Transfer Record   │
    │ with:                      │
    │ - isAutoDeduction = true   │
    │ - savingGoalId = goalId    │
    │ - note = "Auto-deduction"  │
    └────────────┬───────────────┘
                 │
                 ├─→ Insert Transfer
                 │   into database
                 │
                 ├─→ Update Source Account
                 │   balance -= amount
                 │
                 ├─→ Update Dest Account
                 │   balance += amount
                 │
                 └─→ Update SavingGoal
                     currentAmount += amount
```

## Frequency Check Details

### Daily Frequency Flow

```
┌─────────────────────────────┐
│ Daily Frequency Check       │
└────────────┬────────────────┘
             │
             ↓
┌─────────────────────────────┐
│ Get last auto-deduction    │
│ transfer for this goal      │
└────────────┬────────────────┘
             │
             ↓
    ┌────────────────────────────┐
    │ Last transfer exists?      │
    └─┬──────────────────────┬───┘
      │                      │
     NO                     YES
      │                      │
      ↓                      ↓
    Use goal          Parse transfer date
    startDate         to DateTime
      │                      │
      └──────────┬───────────┘
                 │
                 ↓
    ┌────────────────────────────┐
    │ Format dates (yyyy-MM-dd)  │
    │ lastDate vs todayDate      │
    └─┬──────────────────────┬───┘
      │                      │
    DIFFERENT               SAME
      │                      │
      ↓                      ↓
   ✅ DUE                ❌ SKIP
   (transfer             (already
    today)                done)
```

### Weekly Frequency Flow

```
┌─────────────────────────────┐
│ Weekly Frequency Check      │
└────────────┬────────────────┘
             │
             ↓
┌─────────────────────────────┐
│ Get last auto-deduction    │
│ transfer for this goal      │
└────────────┬────────────────┘
             │
             ↓
    ┌────────────────────────────┐
    │ Last transfer exists?      │
    └─┬──────────────────────┬───┘
      │                      │
     NO                     YES
      │                      │
      ↓                      ↓
    Use goal          Parse transfer date
    startDate         to DateTime
      │                      │
      └──────────┬───────────┘
                 │
                 ↓
    ┌──────────────────────────────────┐
    │ Calculate days difference        │
    │ today - lastDate = daysCount     │
    └─┬──────────────────────┬─────────┘
      │                      │
    daysCount >= 7        daysCount < 7
      │                      │
      ↓                      ↓
   ✅ DUE               ❌ SKIP
   (transfer            (too
    this week)           soon)
```

### Monthly Frequency Flow

```
┌─────────────────────────────┐
│ Monthly Frequency Check     │
└────────────┬────────────────┘
             │
             ↓
┌─────────────────────────────┐
│ Get last auto-deduction    │
│ transfer for this goal      │
└────────────┬────────────────┘
             │
             ↓
    ┌────────────────────────────┐
    │ Last transfer exists?      │
    └─┬──────────────────────┬───┘
      │                      │
     NO                     YES
      │                      │
      ↓                      ↓
    Use goal          Parse transfer date
    startDate         to DateTime
      │                      │
      └──────────┬───────────┘
                 │
                 ↓
    ┌──────────────────────────────────┐
    │ Extract:                         │
    │ - lastMonth & lastYear           │
    │ - currentMonth & currentYear     │
    └─┬──────────────────────┬─────────┘
      │                      │
    Different              Same
    month/year            month/year
      │                      │
      ↓                      ↓
   ✅ DUE               ❌ SKIP
   (new month)         (done
                        this month)
```

## Amount Calculation Logic

```
                    ┌──────────────────────┐
                    │ SavingGoal Data      │
                    │ - targetAmount       │
                    │ - startDate          │
                    │ - endDate            │
                    │ - cycleFrequency     │
                    └────────────┬─────────┘
                                 │
                                 ↓
                    ┌──────────────────────┐
                    │ Parse dates to get   │
                    │ total days between   │
                    └────────────┬─────────┘
                                 │
                                 ↓
                    ┌──────────────────────┐
                    │ Calculate cycles     │
                    │ based on frequency   │
                    └─┬──────┬──────┬──────┘
                      │      │      │
                   DAILY  WEEKLY MONTHLY
                      │      │      │
                      ↓      ↓      ↓
                   days/1  days/7  months
                      │      │      │
                      └──────┬──────┘
                             │
                             ↓
                    ┌──────────────────────┐
                    │ amount =             │
                    │ targetAmount ÷ cycles│
                    └────────────┬─────────┘
                                 │
                                 ↓
     ┌──────────────────────────────────┐
     │ Example:                         │
     │ $1,200 ÷ 90 days = $13.33/day   │
     │ $1,000 ÷ 12 weeks = $83.33/wk   │
     │ $900 ÷ 3 months = $300/month    │
     └──────────────────────────────────┘
```

## Database State Changes

```
Before Transfer:
┌──────────────────────────────────────┐
│ Source Account (Checking)            │
│ balance = $500.00                    │
│ ────────────────────────────────     │
│ Destination Account (Savings)        │
│ balance = $100.00                    │
│ ────────────────────────────────     │
│ SavingGoal                           │
│ currentAmount = $50.00               │
│ ────────────────────────────────     │
│ Transfer                             │
│ (No new record)                      │
└──────────────────────────────────────┘
                  │
                  │ Auto-Deduction Creates $13.33 Transfer
                  ↓
After Transfer:
┌──────────────────────────────────────┐
│ Source Account (Checking)            │
│ balance = $486.67 ◄─── DECREASED    │
│ ────────────────────────────────     │
│ Destination Account (Savings)        │
│ balance = $113.33 ◄─── INCREASED    │
│ ────────────────────────────────     │
│ SavingGoal                           │
│ currentAmount = $63.33 ◄─── INCREASED
│ ────────────────────────────────     │
│ Transfer                             │
│ NEW Record:                          │
│ - fromAccountId = Checking.id        │
│ - toAccountId = Savings.id           │
│ - amount = $13.33                    │
│ - isAutoDeduction = true ◄─── MARKED │
│ - savingGoalId = Goal.id ◄─── LINKED│
└──────────────────────────────────────┘
```

## Error Handling Flow

```
┌──────────────────────────────┐
│ Start Auto-Deduction Check   │
└────────────┬─────────────────┘
             │
             ↓
    ┌────────────────────┐
    │ Try to:            │
    │ - Fetch goals      │
    │ - Check transfers  │
    │ - Create transfers │
    └─┬──────────────┬───┘
      │              │
    Success         Error Caught
      │              │
      ↓              ↓
   Return      ┌──────────────────┐
   success     │ Log error:       │
   result      │ "Error in [func] │
               │ {error message}" │
               └────────┬─────────┘
                        │
                        ↓
              Return error result
              with empty transfers
              (doesn't crash app)
```

## App Lifecycle Integration

```
┌──────────────────────────────────┐
│     App Started                  │
└─────────────────┬────────────────┘
                  │
                  ↓
        ┌─────────────────────┐
        │ HomeScreen created  │
        │ initState() called  │
        └────────┬────────────┘
                 │
                 ├─→ _fetchLedgers()
                 │
                 ├─→ _checkAutoDeductions() ◄─── AUTO-DEDUCTION CHECK #1
                 │
                 ├─→ _checkBudgetAlertFlags()
                 │
                 └─→ _fetchTransactions()
                    (to display home screen)
                 
                 ↓
        ┌─────────────────────┐
        │  User uses app      │
        │  (3-5 minutes)      │
        └────────┬────────────┘
                 │
                 ↓
        ┌─────────────────────┐
        │  User minimizes app │
        │  (goes to background)
        └────────┬────────────┘
                 │
                 ↓
        ┌──────────────────────────┐
        │ didChangeAppLifecycleState
        │  state = paused          │
        └──────────────────────────┘
                 
                 ↓
        ┌──────────────────────────┐
        │ User brings app back     │
        │ (foreground again)       │
        └────────┬─────────────────┘
                 │
                 ↓
        ┌──────────────────────────────┐
        │ didChangeAppLifecycleState   │
        │  state = resumed             │
        └────────┬─────────────────────┘
                 │
                 ├─→ _checkAutoDeductions() ◄─── AUTO-DEDUCTION CHECK #2
                 │
                 ├─→ _checkBudgetAlertFlags()
                 │
                 └─→ _fetchTransactions()
                    (refresh transactions)
```

---

These flowcharts visualize the complete auto-deduction system flow! 📊
