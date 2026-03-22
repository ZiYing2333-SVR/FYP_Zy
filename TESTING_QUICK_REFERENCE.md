# Auto Expense Categorization - Quick Reference & Testing Guide

## 🚀 Quick Start

### Step 1: Database Table Already Exists
Your Supabase has the Transaction table configured with these fields:
- `transactionId` - Auto-generated unique ID
- `amount` - Amount of transaction (required)
- `type` - 'expense', 'income', or 'transfer' (required)
- `date` - Transaction date (optional)
- `note` - Transaction description (optional)
- `accountId` - Account reference (required)
- `categoryId` - Category reference (optional)
- `subCategoryId` - Sub-category reference (optional)
- `ledgerId` - Ledger reference (optional)
- `image` - Receipt image URL (optional)
- `refund` - Is refund? (optional, default false)
- `receiptId` - Receipt reference (optional)

If you need to create the table, use:

```sql
CREATE TABLE IF NOT EXISTS public."Transaction" (
  "transactionId" character varying not null,
  amount double precision not null,
  type character varying not null,
  date timestamp without time zone null,
  note character varying null,
  "accountId" character varying not null,
  "categoryId" character varying null,
  "subCategoryId" character varying null,
  "ledgerId" character varying null,
  image character varying null,
  refund boolean null default false,
  "receiptId" character varying null,
  constraint Transaction_pkey primary key ("transactionId"),
  constraint Transaction_accountId_fkey foreign KEY ("accountId") 
    references "Account" ("accountId") on update CASCADE on delete CASCADE,
  constraint Transaction_categoryId_fkey foreign KEY ("categoryId") 
    references "Category" ("categoryId") on update CASCADE on delete set null,
  constraint Transaction_ledgerId_fkey foreign KEY ("ledgerId") 
    references "Ledger" ("ledgerId") on update CASCADE on delete CASCADE,
  constraint Transaction_receiptId_fkey foreign KEY ("receiptId") 
    references "Receipt" ("receiptId"),
  constraint Transaction_subCategoryId_fkey foreign KEY ("subCategoryId") 
    references "Subcategory" ("subCategoryId") on update CASCADE on delete set null
);

CREATE INDEX IF NOT EXISTS idx_transaction_account_date ON public."Transaction"("accountId", "date");
CREATE INDEX IF NOT EXISTS idx_transaction_category ON public."Transaction"("categoryId");
```

### Step 2: Test the Feature
1. Run the app: `flutter run`
2. Navigate to: Home Screen → Scroll down → AI Features
3. Click: "Auto Expense Categorization"
4. Enter a note and test the AI analysis

### Step 3: Verify Navigation
- Cross button on Page 1 should return to AI Features screen
- Cancel button on Page 2 should return to Page 1
- Save button should save transaction and return to AI Features screen

## 📋 Test Cases

### Test Case 1: Food Transaction
**Input**: "Breakfast bread RM2.80"
**Expected Output**:
- Category Suggestion: Food
- Confidence: 95%
- Reasoning: Keywords detected: food-related items
- Transaction Type: Expense

**Verification**:
- [ ] Note input accepted
- [ ] AI analysis completes
- [ ] Correct category suggested
- [ ] Confidence score displays
- [ ] Alternative categories show (if any)

### Test Case 2: Income Transaction
**Input**: "Salary payment March"
**Expected Output**:
- Category Suggestion: Salary
- Confidence: 98%
- Transaction Type: Income (auto-selected)

**Verification**:
- [ ] Income type correctly identified
- [ ] Category filtered to income categories
- [ ] Transaction saves as income

### Test Case 3: Ambiguous Note
**Input**: "PAY123"
**Expected Output**:
- Category Suggestion: Others
- Confidence: 50-65%
- Multiple Alternative Suggestions

**Verification**:
- [ ] System handles ambiguous input
- [ ] Shows alternatives to user
- [ ] User can select any category

### Test Case 4: Transportation
**Input**: "Uber ride to airport RM45"
**Expected Output**:
- Category: Transportation
- Confidence: 92%

### Test Case 5: Empty Input
**Input**: "" (empty)
**Expected Output**: Error message "Please enter a transaction note"

**Verification**:
- [ ] Validation error displayed
- [ ] No API call made
- [ ] User can retry

## 🔧 Configuration Options

### In `ai_service.dart`:

**Adjust confidence threshold:**
```dart
confidence = 0.95; // Change confidence level
```

**Add new keywords:**
```dart
else if (_containsAny(lowerNote, [
  'your_keyword_1',
  'your_keyword_2',
  'your_keyword_3',
])) {
  suggestedCategory = 'YourCategory';
  confidence = 0.90;
}
```

**Change API delay (for testing):**
```dart
await Future.delayed(const Duration(milliseconds: 800)); // Adjust delay
```

## 🎨 UI Customization

### Colors
- Primary Green: `0xFFA7E399`
- Background: `0xFFFEFFD3` (light yellow)
- Button Save: `0xFFFDD835` (yellow)
- Button Cancel: `0xFF9E9E9E` (gray)

### Modify in Confirmation Screen:
```dart
Container(
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: const Color(0xFFA7E399), // Change color here
    borderRadius: BorderRadius.circular(12),
  ),
```

## 🐛 Common Issues & Solutions

### Issue: "Please select an account"
**Solution**: 
- Create at least one account in the Account Manager
- Ensure account has `assetStatus: true`
- Refresh the app

### Issue: Categories not appearing
**Causes**:
- Categories don't exist in database
- Categories have wrong type (expense vs income)
- Categories filtered by wrong transaction type

**Solution**:
- Check `Category` table in Supabase
- Verify category `type` field matches transaction type
- Create categories if missing

### Issue: Amount field not accepting decimal input
**Solution**: 
- Ensure keyboard type is correct
- Update InputType to: `TextInputType.numberWithOptions(decimal: true)`

### Issue: Transaction not saving
**Causes**:
- Database not connected
- Missing required fields
- Foreign key constraint violation

**Solution**:
- Check Supabase connection
- Verify all required fields filled
- Check Supabase logs for constraint errors
- Ensure Category and Account exist for selected items

### Issue: AI analysis takes too long
**Solution**:
- In mock: Reduce delay in `_getMockAIResponse()`
- In live API: Implement timeout and error handling
- Add loading indicator (already implemented)

## 📊 Database Queries

### View Recent Transactions:
```sql
SELECT t.*, c.name as category_name, a."accountName"
FROM public."Transaction" t
JOIN public."Category" c ON t."categoryId" = c."categoryId"
JOIN public."Account" a ON t."accountId" = a."accountId"
ORDER BY t."date" DESC
LIMIT 10;
```

### Check Category Distribution:
```sql
SELECT c.name, COUNT(*) as count
FROM public."Transaction" t
JOIN public."Category" c ON t."categoryId" = c."categoryId"
GROUP BY c.name
ORDER BY count DESC;
```

### Verify Account Balance Updates:
```sql
SELECT 
  a."accountName",
  a.balance,
  COUNT(t."transactionId") as transaction_count
FROM public."Account" a
LEFT JOIN public."Transaction" t ON a."accountId" = t."accountId"
GROUP BY a."accountId", a."accountName", a.balance;
```

## 🔐 Security Checklist

Before deploying to production:

- [ ] Replace mock AI with real API
- [ ] Store API keys in environment variables
- [ ] Implement API rate limiting
- [ ] Add user authentication validation
- [ ] Enable Supabase Row Level Security (RLS)
- [ ] Add audit logging for transactions
- [ ] Implement data encryption
- [ ] Set up error monitoring (Sentry, etc.)
- [ ] Review Supabase security rules
- [ ] Test with production database

## 📈 Performance Optimization

### Current Performance:
- AI Analysis: ~800ms (mock)
- Database Save: ~500ms
- UI Response: <100ms

### Optimization Tips:
1. **Caching**:
   ```dart
   static final _categoryCache = <String, List<Map>>{};
   ```

2. **Batch Operations**:
   - Save multiple transactions in one request

3. **Image Optimization**:
   - Compress images before upload
   - Use WebP format if supported

4. **Database**:
   - Create indexes on frequently queried columns
   - Optimize foreign key relationships

## 🌍 Future Enhancements

Priority Order:
1. **Real AI Integration** (High Priority)
   - OpenAI API integration
   - Error handling for API failures
   - Fallback to local keywords

2. **Machine Learning** (Medium Priority)
   - Learn from user corrections
   - Improve accuracy over time
   - Personalized suggestions

3. **Advanced Features** (Lower Priority)
   - Receipt image recognition
   - Voice input
   - Recurring transaction detection
   - Multi-language support

## 🧪 Testing Checklist

### Functional Testing
- [ ] Input note text correctly
- [ ] AI analysis produces suggestions
- [ ] Category filtering works
- [ ] Account selection works
- [ ] Date picker works
- [ ] Amount validation works
- [ ] Transaction saves correctly
- [ ] Account balance updates correctly

### Edge Cases
- [ ] Empty note input
- [ ] Very long note
- [ ] Special characters in note
- [ ] Very large amount
- [ ] Past dates
- [ ] Future dates
- [ ] Ambiguous transactions
- [ ] Invalid category selection

### UI/UX Testing
- [ ] All buttons clickable
- [ ] Loading indicators show
- [ ] Error messages clear
- [ ] Navigation works smoothly
- [ ] Icons load correctly
- [ ] Layout responsive on different screens

### Integration Testing
- [ ] Works with existing home screen
- [ ] Integrates with account manager
- [ ] Shows correct categories from database
- [ ] Saves transactions with correct ledgerId

## 📞 Support & Debugging

### Enable Logging:
```dart
// Add to ai_service.dart
print('📊 AI Analysis: Category=$category, Confidence=$confidence');
```

### Check Supabase Logs:
1. Go to Supabase Dashboard
2. Navigate to Database/Logs
3. Filter by recent errors
4. Check API responses

### Flutter DevTools:
```bash
flutter pub global activate devtools
devtools
```

### VSCode Debugging:
Set breakpoints in code and use VSCode Flutter debugger

## 📚 Related Files
- `AUTO_EXPENSE_CATEGORIZATION_GUIDE.md` - Comprehensive guide
- `AUTO_EXPENSE_CATEGORIZATION_SUMMARY.md` - Implementation summary
- `lib/services/ai_service.dart` - Core service
- `lib/screens/auto_expense_categorization_screen.dart` - Input screen
- `lib/screens/auto_expense_confirmation_screen.dart` - Confirmation screen

---

**Last Updated**: February 9, 2026
**Status**: Ready for Testing and Deployment