# Bulk Transactions Feature - Complete Guide

## Overview
The app has a bulk transaction input feature that allows you to enter **multiple transactions at once** using a simple format. When you use this format, the app will display the `ConfirmBulkTransactionsScreen` for review and confirmation.

## How the Bulk Feature Works

### Bulk Format Requirements
The app recognizes bulk format when your note contains **semicolons (;)** to separate multiple transactions.

**Format:** `note, amount; note, amount; note, amount`

### Example Entries

#### ✅ Valid Bulk Transactions
```
Coffee, 5.50; Lunch, 12.00; Dinner, 25.75
Shopping at mall, 49.99; Gas, 35.50
Groceries, 150.00; Medicine, 25.00; Transport, 15.00
```

#### ❌ Invalid Format (Will NOT trigger bulk screen)
```
Coffee and lunch (no amounts)
5.50, 12.00, 25.75 (no notes)
Coffee; Lunch; Dinner (no amounts after notes)
```

## Testing the Bulk Feature

### Step-by-Step Test

1. **Open the Add Transaction Screen**
   - From Home Screen → Tap "+"

2. **Select Transaction Type**
   - Choose: Expense (or Income)

3. **Select Account (if required)**
   - Pick any account from the list

4. **Enter Data in Bulk Format**
   - In the "Note" field, enter something like:
   ```
   coffee, 10.50; lunch, 20.00; shopping, 85.00
   ```

5. **Press "Save"**
   - You should see snackbar: "🎉 Bulk format detected! Processing multiple transactions..."
   - The screen should transition to `ConfirmBulkTransactionsScreen`

### What Happens on Bulk Screen

You'll see:
- ✅ All parsed transactions listed
- ✅ Auto-categorization for each transaction
- ✅ Edit option for each transaction
- ✅ Confirmation button to save all at once

---

## Current Implementation Details

### File Locations
- **Main Bulk Handler:** `lib/screens/add_transaction.dart` (lines 296-340)
- **Confirmation Screen:** `lib/screens/confirm_bulk_transactions.dart`
- **Parser Logic:** `lib/utils/transaction_parser.dart`

### How It's Triggered
1. User enters note with semicolon(s)
2. `TransactionParser.isBulkFormat()` detects semicolons
3. If bulk format found → routes to `ConfirmBulkTransactionsScreen`
4. Otherwise → uses regular single transaction flow

### Parsing Logic
```dart
// Format: note, amount; note, amount; ...
// Example: "coffee, 10.50; lunch, 20.00"

// Splits by semicolon first (multiple transactions)
// Then splits each by comma (note and amount)
```

---

## Debug Checklist

If bulk transactions aren't showing:

- [ ] Verify note contains **semicolon (;)**
- [ ] Verify format is: `note, amount; note, amount`
- [ ] Check that amounts are **valid numbers**
- [ ] Verify amounts are **greater than 0**
- [ ] Check console logs for "BULK FORMAT DETECTED" message

### Common Issues

| Issue | Solution |
|-------|----------|
| Screen doesn't appear | Check that note has semicolon (;) |
| "No valid transactions parsed" | Verify format: `text, number; text, number` |
| Amount not recognized | Make sure amount is a valid number (10 or 10.50) |
| Blank notes | Each transaction must have a note before comma |

---

## Features on Confirmation Screen

The `ConfirmBulkTransactionsScreen` provides:
1. **Auto-Categorization** - AI analyzes each transaction note
2. **Manual Editing** - Adjust note/category for each transaction
3. **Batch Save** - Save all transactions with one tap
4. **Progress Tracking** - See real-time parsing and categorization

---

## Example Complete Flow

```
User Input: "coffee, 5.50; lunch, 12.00; movie, 15.00"
                        ↓
            TransactionParser detects semicolons
                        ↓
            Parses 3 transactions:
              • Coffee = 5.50
              • Lunch = 12.00
              • Movie = 15.00
                        ↓
          ConfirmBulkTransactionsScreen shows all 3
                        ↓
            User confirms and saves all at once
```

---

## Notes
- Maximum 50 transactions per bulk entry
- Category auto-detection uses AI service
- Each transaction can be manually edited before confirmation
- Supports same transaction types as single entry (expense, income, transfer)
