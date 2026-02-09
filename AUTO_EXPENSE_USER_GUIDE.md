# Auto Expense Categorization - Quick Reference Guide

## How to Use the Enhanced Feature

### Step 1: Enter Transaction Note
- Navigate to **AI Features** → **Auto Expense Categorization**
- Enter a transaction note with details and optional amount
- **Examples**:
  - "Breakfast at café RM12.50"
  - "Grab ride to office"
  - "Online shopping shirt 89.99"
  - "Salary payment received"
  - "PAY123" (ambiguous note)

### Step 2: AI Analysis
- Tap **"Analyze & Categorize"** button
- System will:
  - ✓ Extract amount automatically (if available)
  - ✓ Analyze note using NLP
  - ✓ Suggest appropriate category
  - ✓ Generate top 3 alternatives if uncertain

### Step 3: Confirm Transaction
The confirmation page shows:

**Transaction Note** (Breadcrumb)
- Your original note is displayed
- Helps you track what you're categorizing

**AI Suggestion**
- Primary recommended category
- Confidence percentage (0-100%)
- Reasoning explanation

**Suggested Categories** (if low confidence)
- Up to 3 alternative options
- Each with confidence score
- Tap any to select it

**Amount (RM)**
- Auto-filled if extracted from note
- Edit if needed
- Required field

**Transaction Type**
- Expense (default for spending)
- Income (for earnings/salary)
- Transfer (between accounts)

**Category**
- Selected category shown
- Dropdown to choose alternatives
- Filters based on transaction type

**Account**
- Choose account for transaction
- Shows account balance
- Required field

**Date**
- Defaults to today's date
- Tap to change if needed

### Step 4: Save Transaction
- Verify all details
- Tap **"Save Transaction"**
- System updates account balance
- Returns to home screen

---

## Understanding Confidence Scores

### High Confidence (>0.8)
- Clear match found
- "AI Suggestion" label shown
- Ready to confirm

### Medium Confidence (0.5-0.8)
- Multiple possible matches
- "Best Match" label shown
- "Suggested Categories" panel displayed
- **Recommended**: Review alternatives

### Low Confidence (<0.5)
- Ambiguous note
- "No suitable category found" indicator
- Must select from alternatives
- Help system learn from your choice

---

## Example Scenarios

### Scenario 1: Clear Match
**Note**: "Starbucks coffee RM2.80"
- **AI detects**: Food category
- **Confidence**: 95%
- **Action**: Tap Save (or review alternatives)

### Scenario 2: Multiple Options
**Note**: "Payment to 123"
- **AI suggests**: Others
- **Confidence**: 65%
- **Alternatives**: Food, Utilities, Shopping
- **Action**: Select correct category from alternatives

### Scenario 3: Income Transaction
**Note**: "Monthly salary received"
- **AI detects**: Income type
- **Category**: Salary
- **Confidence**: 98%
- **Auto-adjusts**: Transaction Type to Income
- **Action**: Confirm and save

---

## Pro Tips

✅ **Be Specific**: "Starbucks espresso" works better than "Payment"
✅ **Include Amount**: "RM12.50 lunch" is better than "lunch"
✅ **Check Alternatives**: If confidence is low, alternatives are usually helpful
✅ **Verify Date**: Change date for past transactions before saving
✅ **Watch Balance**: Account balance updates immediately after save
✅ **Track Notes**: Original note is preserved in transaction record

---

## What Happens to Your Data

- **Note**: Saved with transaction for reference
- **Category**: Stored for expense tracking
- **Amount**: Deducted from/added to account balance
- **Date**: Recorded for chronological tracking
- **Account**: Updated with new balance

---

## If Something Goes Wrong

**Amount not extracted?**
- Manually enter in "Amount (RM)" field

**Wrong category suggested?**
- Check "Suggested Categories" panel
- Or use dropdown to select manually

**Can't select account?**
- Ensure at least one active account exists
- Check account status in Account Manager

**Category filtering strange?**
- Note: Categories filter by transaction type
- Change type if you need different categories

---

## Keyboard Shortcuts

- **Enter Note**: Type directly in text area
- **Decimal Numbers**: Use format like "123.45" or "RM123.45"
- **Tab Navigation**: Move between fields quickly

---

## Related Features

- **Home Screen**: View all transactions
- **Account Manager**: Create/edit accounts
- **Category Manager**: Create/edit categories
- **Expense Trends**: Analyze spending patterns
- **Budget Forecasting**: Plan your budget

---

## Need Help?

- **Icons**: Hover over (?) icons for more info
- **Tooltips**: Most fields have helpful hints
- **Balance**: Always shown in account dropdown
- **Date Picker**: Calendar opens to select date

---

## Database Tables Used

```
Category
├── categoryId (unique identifier)
├── name (category name)
├── type (expense/income)
├── icon (category icon URL)
└── userId (custom categories)

Account
├── accountId (unique identifier)
├── accountName (display name)
├── balance (current amount)
├── iconImage (account icon)
└── ledgerId (linked ledger)

Transaction
├── transactionId (auto-generated)
├── amount (transaction value)
├── type (expense/income/transfer)
├── date (timestamp)
├── categoryId (linked category)
├── accountId (linked account)
├── note (description)
└── ledgerId (linked ledger)
```

---

## API Used

- **OpenAI GPT-3.5**: For intelligent note analysis
- **Supabase**: For data storage
- **NLP**: For keyword extraction and understanding

---

*Last Updated: 2025-02-09*
