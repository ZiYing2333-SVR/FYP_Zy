# Auto Expense Categorization Feature - Implementation Guide

## Overview
The Auto Expense Categorization feature enables users to automatically categorize transactions using AI-powered natural language processing. Users enter a transaction note (e.g., "Breakfast bread RM2.80"), and the system analyzes it to suggest the appropriate expense category with confidence scores.

## Features Implemented

### 1. **Auto Expense Categorization Screen** (`auto_expense_categorization_screen.dart`)
   - **Purpose**: First page where users input their transaction note
   - **Components**:
     - Text input field for transaction notes
     - "Analyze & Categorize" button with checkmark icon
     - Informational section explaining how the feature works
     - Loading indicator during analysis
     - Navigation back button (close button) to return to AI Features screen

   - **User Flow**:
     1. User enters transaction note (e.g., "Breakfast bread RM2.80")
     2. Taps "Analyze & Categorize" button
     3. AI analyzes the note
     4. Navigates to confirmation screen with AI results

### 2. **Auto Expense Confirmation Screen** (`auto_expense_confirmation_screen.dart`)
   - **Purpose**: Second page where users confirm and finalize the transaction
   - **Components**:
     - AI Suggestion Display (with confidence percentage)
     - Amount input field
     - Transaction Type selector (Expense/Income/Transfer)
     - Category dropdown (filtered by transaction type)
     - Account selector (with balance display)
     - Date picker
     - Alternative category suggestions (if ambiguous)
     - Cancel and Save buttons

   - **Features**:
     - Dynamic category filtering based on selected transaction type
     - Confidence percentage display for AI suggestion
     - Alternative suggestions if the note is ambiguous
     - Account selection with balance preview
     - Date selection with calendar picker
     - Real-time validation

### 3. **AI Service** (`services/ai_service.dart`)
   - **Core Functions**:
     - `analyzeTransactionNote()`: Analyzes transaction notes using NLP
     - `getCategories()`: Fetches all available categories
     - `getAccounts()`: Fetches user's accounts
     - `saveTransaction()`: Saves the confirmed transaction to the database
     - `getAccountIconUrl()`: Constructs account icon URLs
     - `getCategoryIconUrl()`: Constructs category icon URLs

   - **Current Implementation**: Uses mock AI responses with keyword matching
   - **Future Integration**: Replace with actual AI API (OpenAI, Google Cloud NLP, etc.)

### 4. **Updated AI Features Screen** (`ai_features_screen.dart`)
   - Navigation to Auto Expense Categorization feature
   - Proper routing with userId and ledgerId parameters

## Database Structure

### Transaction Table (Required)
Your Supabase database already has the Transaction table with the following structure:

```sql
CREATE TABLE public."Transaction" (
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
) TABLESPACE pg_default;
```

**Key Fields:**
- `transactionId` - Unique identifier (auto-generated)
- `amount` - Transaction amount (required)
- `type` - Transaction type: 'expense', 'income', or 'transfer' (required)
- `date` - Date of transaction (can be null)
- `note` - Transaction notes/description (optional)
- `accountId` - Associated account (required, foreign key)
- `categoryId` - Transaction category (optional, foreign key)
- `subCategoryId` - Sub-category if applicable (optional, foreign key)
- `ledgerId` - Associated ledger (optional, foreign key)
- `image` - Receipt/attachment image URL (optional)
- `refund` - Is this a refund? (optional, default false)
- `receiptId` - Associated receipt ID (optional, foreign key)

## Integration with AI API

The current implementation uses mock responses for development. To integrate with a real AI API:

### Option 1: OpenAI API (ChatGPT)

1. **Install HTTP Package** (if not already installed):
```bash
flutter pub add http
```

2. **Update `ai_service.dart`** - Replace the API key and modify `analyzeTransactionNote()`:

```dart
static Future<Map<String, dynamic>> analyzeTransactionNote(
  String note,
  List<Map<String, dynamic>> categories,
) async {
  try {
    final categoryNames = categories
        .map((c) => c['name'])
        .toList()
        .join(', ');

    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'gpt-3.5-turbo',
        'messages': [
          {
            'role': 'system',
            'content': 'You are a financial transaction categorization assistant.',
          },
          {
            'role': 'user',
            'content': '''
Analyze this transaction note and categorize it.
Available categories: $categoryNames

Transaction note: "$note"

Return JSON with: suggestedCategory, confidence (0-1), transactionType (expense|income|transfer), reasoning
'''
          }
        ],
        'temperature': 0.7,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final content = data['choices'][0]['message']['content'];
      final result = jsonDecode(content);
      result['success'] = true;
      return result;
    } else {
      return {'success': false, 'error': 'API request failed'};
    }
  } catch (e) {
    return {'success': false, 'error': 'Error: $e'};
  }
}
```

### Option 2: Google Cloud Natural Language API

Similar process but uses Google's NLP service for entity recognition and sentiment analysis.

### Option 3: Custom Backend Service

If you have your own ML model, update the API URL and implement custom logic for your model's response format.

## Usage Instructions

### For Users:
1. Open the app and navigate to "AI Features" from the home screen
2. Tap "Auto Expense Categorization"
3. Enter your transaction note (e.g., "Starbucks coffee RM12.50")
4. Tap "Analyze & Categorize"
5. Review the suggested category and confidence score
6. Enter the transaction amount
7. Select transaction type (typically pre-filled based on AI analysis)
8. Choose the correct category if needed
9. Select the account to debit/credit
10. Confirm the date
11. Tap "Save" to record the transaction

### For Developers:

#### Adding Custom Categories for AI Training:
You can expand the mock AI responses by:
1. Adding more keyword patterns in `_getMockAIResponse()`
2. Creating category-keyword mappings
3. Implementing machine learning model for better accuracy

#### Testing:
Test different transaction notes:
- "Starbucks coffee" → Food
- "Uber ride" → Transportation
- "Cinema ticket" → Entertainment
- "Ambiguous note" → Shows alternatives

#### Error Handling:
The system handles:
- Empty notes → Shows validation error
- Ambiguous notes → Displays alternatives
- Network errors → Shows error message
- Database errors → Displays user-friendly error message

## Security Considerations

1. **API Key Management**: 
   - Store API keys in environment variables or secure storage
   - Do not commit API keys to version control
   - Use different keys for development/production

2. **User Data**:
   - Transaction notes are stored in the database
   - Ensure HTTPS/encrypted connections for API calls
   - Implement proper access control using userId field

3. **Rate Limiting**:
   - Implement rate limiting on the backend
   - Cache frequent categorizations
   - Add delay between API calls if needed

## Performance Optimization

1. **Caching**:
   - Cache category list for faster filtering
   - Implement result caching for similar notes

2. **Lazy Loading**:
   - Load accounts and categories asynchronously
   - Show loading indicators while fetching data

3. **Image Optimization**:
   - Use image URLs from Supabase storage
   - Implement proper error handling for missing icons

## Future Enhancements

1. **Machine Learning Model**:
   - Train on user's historical categorizations
   - Improve accuracy over time
   - Personalized category suggestions

2. **Voice Input**:
   - Allow users to speak notes
   - Implement speech-to-text

3. **Receipt Analysis**:
   - Extract data from receipt images
   - Auto-fill amount and category

4. **Recurring Transactions**:
   - Identify and suggest recurring transactions
   - Auto-categorize similar transactions

5. **Multi-language Support**:
   - Support multiple languages
   - Localized category names

6. **Advanced Analytics**:
   - Track AI accuracy over time
   - User feedback loop for model improvement
   - Category confidence trends

## File Structure

```
lib/
├── screens/
│   ├── auto_expense_categorization_screen.dart    # Page 1: Note input
│   ├── auto_expense_confirmation_screen.dart       # Page 2: Confirmation
│   ├── ai_features_screen.dart                     # AI Features menu
│   └── ... (other screens)
├── services/
│   ├── ai_service.dart                             # AI and database operations
│   └── ... (other services)
└── ... (other directories)
```

## Troubleshooting

### Issue: "Please select an account"
- **Solution**: Ensure you have created at least one account in the app

### Issue: Cannot find categories
- **Solution**: 
  - Verify that categories exist in the database
  - Check that categories have the correct type (expense/income)
  - Ensure user has access to those categories

### Issue: Transaction not saving
- **Solution**:
  - Check database connection
  - Verify all required fields are filled
  - Check Supabase error logs
  - Ensure consistent data types with database schema

### Issue: AI suggestion not appearing
- **Solution**: 
  - Check internet connection
  - Verify API keys are correct
  - Check API rate limits
  - Review error logs in console

## Testing Checklist

- [ ] Navigation to Auto Expense Categorization works
- [ ] Cross button returns to previous screen
- [ ] AI analysis generates suggestions
- [ ] Category filtering works by type
- [ ] Transaction saves with correct data
- [ ] Account balance updates correctly
- [ ] Date picker works
- [ ] Alternative suggestions display for ambiguous notes
- [ ] Error handling works properly
- [ ] Icons load from Supabase storage
- [ ] Amount validation works
- [ ] Form submission succeeds

## Support & Maintenance

For issues or improvements:
1. Check the error logs in the console
2. Verify database schema matches requirements
3. Test with different transaction notes
4. Monitor API usage and costs
5. Update keywords and patterns in mock AI as needed

## Related Documentation
- See `BANK_SYSTEM_SUMMARY.md` for overall system architecture
- See `README.md` for general setup instructions
