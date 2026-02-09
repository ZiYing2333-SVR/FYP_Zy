import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AIService {
  // Note: Hugging Face API key should be set via environment variables or secure configuration
  // Do not commit secrets to version control
  static String get huggingFaceApiKey => dotenv.env['HF_TOKEN'] ?? '';
  static const String huggingFaceModel =
      'facebook/bart-large-mnli'; // Zero-shot classification model
  static const String huggingFaceApiUrl =
      'https://api-inference.huggingface.co/models/facebook/bart-large-mnli'; // Hugging Face API endpoint

  /// Extracts amount from transaction note
  /// Matches patterns like "RM2.80", "RM 2.80", "2000", "200.50", etc.
  static double? extractAmountFromNote(String note) {
    if (note.isEmpty) return null;

    // Pattern 1: RM followed by optional space, then digits with optional decimal
    final regexRM = RegExp(r'RM\s*(\d+(?:\.\d{2})?)', caseSensitive: false);
    var match = regexRM.firstMatch(note);

    if (match != null && match.groupCount > 0) {
      final amountStr = match.group(1);
      final amount = double.tryParse(amountStr ?? '');
      if (amount != null) {
        print('✓ Extracted amount from note: RM${amount.toStringAsFixed(2)}');
        return amount;
      }
    }

    // Pattern 2: Standalone number with decimal places (looks like currency)
    final regexDecimal = RegExp(r'\b(\d+\.\d{2})\b');
    match = regexDecimal.firstMatch(note);

    if (match != null && match.groupCount > 0) {
      final amountStr = match.group(1);
      final amount = double.tryParse(amountStr ?? '');
      if (amount != null) {
        print('✓ Extracted amount from note: RM${amount.toStringAsFixed(2)}');
        return amount;
      }
    }

    // Pattern 3: Standalone number without decimal (fallback)
    final regexNumber = RegExp(r'\b(\d+)\b');
    match = regexNumber.firstMatch(note);

    if (match != null && match.groupCount > 0) {
      final amountStr = match.group(1);
      final amount = double.tryParse(amountStr ?? '');
      if (amount != null) {
        print('✓ Extracted amount from note: RM${amount.toStringAsFixed(2)}');
        return amount;
      }
    }

    print('✗ No amount found in note');
    return null;
  }

  /// Analyzes a transaction note and suggests a category
  /// Returns a map with suggested category, confidence score, and all category scores
  static Future<Map<String, dynamic>> analyzeTransactionNote(
    String note,
    List<Map<String, dynamic>> categories,
  ) async {
    try {
      if (note.isEmpty) {
        return {'success': false, 'error': 'Note cannot be empty'};
      }

      // Extract amount from note
      final amount = extractAmountFromNote(note);

      // Extract category names for the classification
      final categoryNames = categories.map((c) => c['name'] as String).toList();

      // Call Hugging Face API
      final result = await _callHuggingFaceAPI(note, categories, categoryNames);

      // Add extracted amount to result
      if (amount != null) {
        result['extractedAmount'] = amount;
      }

      return result;
    } catch (e) {
      print('Error analyzing transaction note: $e');
      return {'success': false, 'error': 'Failed to analyze note: $e'};
    }
  }

  /// Calls Hugging Face API for transaction categorization using zero-shot classification
  static Future<Map<String, dynamic>> _callHuggingFaceAPI(
    String note,
    List<Map<String, dynamic>> categories,
    List<String> categoryNames,
  ) async {
    try {
      // Prepare candidate labels (category names)
      final candidateLabels = categoryNames;

      // Call Hugging Face API for zero-shot classification
      final response = await http
          .post(
            Uri.parse(huggingFaceApiUrl),
            headers: {
              'Authorization': 'Bearer $huggingFaceApiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'inputs': note,
              'parameters': {
                'candidate_labels': candidateLabels,
                'hypothesis_template': 'This text is about {}.',
              },
            }),
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () =>
                throw Exception('Hugging Face API request timeout'),
          );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        print('\n=== Hugging Face API Response ===');
        print('API Result: $result');

        // Extract results from Hugging Face response
        final scores = result['scores'] as List<dynamic>?;
        final labels = result['labels'] as List<dynamic>?;

        if (scores != null && labels != null && scores.isNotEmpty) {
          // Get top result
          final topScore = (scores[0] as num).toDouble();
          final topLabel = labels[0] as String;

          print(
            'Top match: "$topLabel" with score: ${(topScore * 100).toStringAsFixed(1)}%',
          );

          // Build all category scores for confirmation page
          final categoryScores = <Map<String, dynamic>>[];
          if (labels.isNotEmpty && scores.isNotEmpty) {
            for (var i = 0; i < labels.length; i++) {
              categoryScores.add({
                'category': labels[i] as String,
                'confidence': (scores[i] as num).toDouble(),
              });
            }
          }

          // Determine transaction type based on content
          final transactionType = _determineTransactionType(note);

          // Extract amount from note
          final amount = extractAmountFromNote(note);

          final result = {
            'success': true,
            'suggestedCategory': topLabel,
            'confidence': topScore,
            'transactionType': transactionType,
            'allCategoryScores':
                categoryScores, // ALL scores for confirmation page
            'reasoning':
                'Analyzed using Hugging Face natural language processing (facebook/bart-large-mnli)',
          };

          // Add extracted amount if found
          if (amount != null) {
            result['extractedAmount'] = amount;
          }

          return result;
        }
      } else {
        print('Hugging Face API error: ${response.statusCode}');
        print('Response body: ${response.body}');
        // Fallback to keyword-based categorization
        return _getMockAIResponse(note, categories);
      }
    } catch (e) {
      print('Error calling Hugging Face API: $e');
      print('Note: "$note"');
      // Fallback to keyword-based categorization
      return _getMockAIResponse(note, categories);
    }

    return {'success': false, 'error': 'Failed to categorize transaction'};
  }

  /// Determine transaction type (expense/income/transfer) based on note content
  static String _determineTransactionType(String note) {
    final lowerNote = note.toLowerCase();

    // Income keywords
    if (_containsAny(lowerNote, [
      'salary',
      'income',
      'bonus',
      'commission',
      'refund',
      'reimbursement',
      'dividend',
      'interest earned',
      'freelance',
      'consulting',
      'allowance',
      'grant',
      'payment received',
      'received',
    ])) {
      return 'income';
    }

    // Transfer keywords
    if (_containsAny(lowerNote, [
      'transfer',
      'moved',
      'send',
      'sent',
      'receive',
      'received',
      'account transfer',
    ])) {
      return 'transfer';
    }

    // Default to expense
    return 'expense';
  }

  /// Maps common category names to actual database categories
  /// Used when mock/keyword-based matching returns a generic category
  static String _mapCommonCategoryToDatabase(
    String suggestedCategory,
    List<Map<String, dynamic>> allCategories,
  ) {
    final lowerSuggested = suggestedCategory.toLowerCase();

    // Mapping rules: common category name -> list of possible database matches
    final mappings = {
      'food': [
        'groceries',
        'snack',
        'food delivery',
        'restaurant',
        'take away',
      ],
      'dining': ['restaurant', 'food delivery', 'groceries'],
      'restaurant': ['restaurant', 'food delivery', 'groceries'],
      'transportation': [
        'public transport',
        'fuel',
        'car rental',
        'parking',
        'toll',
      ],
      'transport': [
        'public transport',
        'fuel',
        'car rental',
        'parking',
        'toll',
      ],
      'utilities': ['utilities', 'internet', 'house insurance'],
      'entertainment': ['entertainment', 'movie', 'hobby', 'music streaming'],
      'shopping': ['shopping', 'cosmetic', 'gift', 'furniture'],
      'healthcare': ['health insurance', 'medication', 'personal care'],
      'vehicle': [
        'car insurance',
        'car payment',
        'vehicle maintenance',
        'fuel',
        'car rental',
      ],
      'salary': ['salary', 'bonus', 'commission', 'part time'],
      'income': [
        'salary',
        'bonus',
        'commission',
        'dividend',
        'rental income',
        'refund',
      ],
    };

    // Try to find a mapping
    if (mappings.containsKey(lowerSuggested)) {
      final possibleMatches = mappings[lowerSuggested]!;

      // Find first category that exists in database
      for (var possibleMatch in possibleMatches) {
        final found = allCategories.firstWhere(
          (cat) => (cat['name'] as String?)?.toLowerCase() == possibleMatch,
          orElse: () => <String, dynamic>{},
        );

        if (found.isNotEmpty) {
          final actualName = found['name'] as String? ?? suggestedCategory;
          print('✓ Mapped "$suggestedCategory" → "$actualName"');
          return actualName;
        }
      }
    }

    // Try fuzzy match if exact mapping not found
    final lowerCategories = allCategories
        .map((c) => c['name'] as String? ?? '')
        .toList();
    for (var dbCategory in lowerCategories) {
      if (dbCategory.toLowerCase().contains(lowerSuggested) ||
          lowerSuggested.contains(dbCategory.toLowerCase())) {
        print('✓ Fuzzy matched "$suggestedCategory" → "$dbCategory"');
        return dbCategory;
      }
    }

    print('✗ No mapping found for "$suggestedCategory", returning as-is');
    return suggestedCategory;
  }

  /// Fallback keyword-based categorization for when API fails
  /// or for development/testing
  /// Returns top 3 alternatives when there's no high confidence match
  static Future<Map<String, dynamic>> _getMockAIResponse(
    String note,
    List<Map<String, dynamic>> categories,
  ) async {
    // Simulate API delay
    await Future.delayed(const Duration(milliseconds: 800));

    final lowerNote = note.toLowerCase();
    String suggestedCategory = 'Others';
    double confidence = 0.5;
    String transactionType = 'expense';

    print('\n=== AI Categorization Debug ===');
    print('Note: "$note" (lowercase: "$lowerNote")');
    print('Available categories: ${categories.map((c) => c['name']).toList()}');

    // First, check if the note matches any existing category name from database
    for (var category in categories) {
      final categoryName = category['name'] as String?;
      if (categoryName != null &&
          lowerNote.contains(categoryName.toLowerCase())) {
        suggestedCategory = categoryName;
        confidence = 0.89; // High confidence - matched database category
        transactionType = category['type'] ?? 'expense';
        print(
          '✓ Matched database category: $categoryName (type: $transactionType)',
        );
        return {
          'success': true,
          'suggestedCategory': suggestedCategory,
          'confidence': confidence,
          'transactionType': transactionType,
          'allCategoryScores': [
            {'category': categoryName, 'confidence': confidence},
          ],
          'reasoning': 'Matched to existing category: $categoryName',
        };
      }
    }
    print('✗ No database category name match found');

    // Food-related keywords with high confidence
    if (_containsAny(lowerNote, [
      'breakfast',
      'lunch',
      'dinner',
      'coffee',
      'cafe',
      'restaurant',
      'food',
      'bread',
      'cake',
      'pizza',
      'burger',
      'noodle',
      'rice',
      'milk',
      'juice',
      'tea',
      'starbucks',
      'mcdonald',
      'kfc',
      'domino',
      'grab food',
      'foodpanda',
      'snack',
      'dessert',
      'bakery',
    ])) {
      suggestedCategory = 'Food';
      confidence = 0.95;
      transactionType = 'expense';

      // Map to actual database category if exists
      suggestedCategory = _mapCommonCategoryToDatabase(
        suggestedCategory,
        categories,
      );
    }
    // Transportation-related keywords
    else if (_containsAny(lowerNote, [
      'uber',
      'grab',
      'taxi',
      'bus',
      'transport',
      'petrol',
      'gasoline',
      'gas',
      'fuel',
      'parking',
      'toll',
      'train',
      'flight',
      'airline',
      'car',
      'bike',
      'motorcycle',
      'vehicle',
      'maintenance',
      'repair',
      'service',
      'mrt',
      'lrt',
      'taxi fare',
      'ride',
    ])) {
      suggestedCategory = 'Transportation';
      confidence = 0.92;
      transactionType = 'expense';
      suggestedCategory = _mapCommonCategoryToDatabase(
        suggestedCategory,
        categories,
      );
    }
    // Credit Card Payment-related keywords
    else if (_containsAny(lowerNote, [
      'credit card',
      'credit card payment',
      'cc payment',
      'cc pay',
      'credit payment',
      'card payment',
    ])) {
      suggestedCategory = 'Credit Card Payment';
      confidence = 0.95;
      transactionType = 'expense';
      suggestedCategory = _mapCommonCategoryToDatabase(
        suggestedCategory,
        categories,
      );
    }
    // Loan Payment-related keywords
    else if (_containsAny(lowerNote, [
      'loan payment',
      'loan pay',
      'loan installment',
      'mortgage payment',
      'mortgage pay',
    ])) {
      suggestedCategory = 'Loan Payment';
      confidence = 0.94;
      transactionType = 'expense';
      suggestedCategory = _mapCommonCategoryToDatabase(
        suggestedCategory,
        categories,
      );
    }
    // Income-related keywords
    else if (_containsAny(lowerNote, [
      'salary',
      'salary payment',
      'bonus',
      'income',
      'payment',
      'received',
      'freelance',
      'consulting',
      'commission',
      'dividend',
      'interest',
      'refund',
      'reimbursement',
      'allowance',
      'stipend',
      'grant',
    ])) {
      suggestedCategory = 'Salary';
      confidence = 0.98;
      transactionType = 'income';
      suggestedCategory = _mapCommonCategoryToDatabase(
        suggestedCategory,
        categories,
      );
    }
    // Entertainment-related keywords
    else if (_containsAny(lowerNote, [
      'movie',
      'cinema',
      'theater',
      'game',
      'gaming',
      'concert',
      'music',
      'entertainment',
      'show',
      'ticket',
      'streaming',
      'spotify',
      'netflix',
      'youtube',
      'gaming console',
      'playstation',
      'xbox',
      'playstation',
    ])) {
      suggestedCategory = 'Entertainment';
      confidence = 0.90;
      transactionType = 'expense';
      suggestedCategory = _mapCommonCategoryToDatabase(
        suggestedCategory,
        categories,
      );
    }
    // Shopping-related keywords
    else if (_containsAny(lowerNote, [
      'shopping',
      'clothes',
      'dress',
      'shoes',
      'mall',
      'shop',
      'store',
      'retail',
      'amazon',
      'ebay',
      'lazada',
      'shopee',
      'online',
      'purchase',
      'buy',
      'apparel',
      'fashion',
    ])) {
      suggestedCategory = 'Shopping';
      confidence = 0.88;
      transactionType = 'expense';
      suggestedCategory = _mapCommonCategoryToDatabase(
        suggestedCategory,
        categories,
      );
    }
    // Healthcare-related keywords
    else if (_containsAny(lowerNote, [
      'doctor',
      'hospital',
      'medical',
      'medicine',
      'pharmacy',
      'clinic',
      'health',
      'dental',
      'prescription',
      'surgery',
    ])) {
      suggestedCategory = 'Healthcare';
      confidence = 0.93;
      transactionType = 'expense';
      suggestedCategory = _mapCommonCategoryToDatabase(
        suggestedCategory,
        categories,
      );
    }
    // Utilities-related keywords
    else if (_containsAny(lowerNote, [
      'electricity',
      'water',
      'internet',
      'phone bill',
      'utility',
      'electric',
      'gas bill',
      'phone',
      'mobile',
      'wifi',
    ])) {
      suggestedCategory = 'Utilities';
      confidence = 0.94;
      transactionType = 'expense';
      suggestedCategory = _mapCommonCategoryToDatabase(
        suggestedCategory,
        categories,
      );
    }
    // Education-related keywords
    else if (_containsAny(lowerNote, [
      'school',
      'university',
      'college',
      'tuition',
      'course',
      'class',
      'education',
      'textbook',
      'book',
      'learning',
      'student',
    ])) {
      suggestedCategory = 'Education';
      confidence = 0.91;
      transactionType = 'expense';
      suggestedCategory = _mapCommonCategoryToDatabase(
        suggestedCategory,
        categories,
      );
    }
    // Ambiguous case with multiple possibilities
    else if (_containsAny(lowerNote, ['pay', 'expense', 'cost', 'spend'])) {
      suggestedCategory = 'Others';
      confidence = 0.65;
      transactionType = 'expense';
    } else {
      // Default case for no keyword match
      suggestedCategory = 'Others';
      confidence = 0.50;
      transactionType = 'expense';
    }

    // Extract amount from note
    final amount = extractAmountFromNote(note);

    // Build allCategoryScores for the confirmation page
    final allCategoryScores = <Map<String, dynamic>>[];

    // Add the suggested category first
    allCategoryScores.add({
      'category': suggestedCategory,
      'confidence': confidence,
    });

    // Get top 3 alternative categories
    final topAlternatives = _getTop3Alternatives(
      suggestedCategory,
      transactionType,
      categories,
    );

    // Add alternatives to the scores list (up to 3 total alternatives, not including suggested)
    for (
      var i = 0;
      i < topAlternatives.length && allCategoryScores.length < 4;
      i++
    ) {
      allCategoryScores.add({
        'category': topAlternatives[i]['category'] as String,
        'confidence': topAlternatives[i]['confidence'] as double,
      });
    }

    final result = {
      'success': true,
      'suggestedCategory': suggestedCategory,
      'confidence': confidence,
      'transactionType': transactionType,
      'allCategoryScores': allCategoryScores,
      'reasoning': _generateReasoning(note, suggestedCategory),
    };

    // Add extracted amount to result if found
    if (amount != null) {
      result['extractedAmount'] = amount;
    }

    return result;
  }

  /// Generate top 3 alternative categories with smart scoring
  /// Only returns categories with 70%+ confidence, otherwise empty list means "Cannot Match"
  static List<Map<String, dynamic>> _getTop3Alternatives(
    String suggestedCategory,
    String transactionType,
    List<Map<String, dynamic>> allCategories,
  ) {
    final alternatives = <Map<String, dynamic>>[];
    final seen = <String>{};
    final scoredCategories = <Map<String, dynamic>>[];

    // Score categories of the same type
    final sameTypeCategories = allCategories
        .where(
          (c) =>
              (c['type'] as String? ?? 'expense') == transactionType &&
              (c['name'] as String? ?? '') != suggestedCategory,
        )
        .toList();

    // Add same-type categories with scoring (start at 75%, decrease by 5% each)
    for (var i = 0; i < sameTypeCategories.length; i++) {
      final name = sameTypeCategories[i]['name'] as String? ?? '';
      if (name.isNotEmpty && !seen.contains(name)) {
        seen.add(name);
        final confidence = 0.75 - (i * 0.05); // 75%, 70%, 65%, etc.
        if (confidence >= 0.70) {
          // Only include if 70% or higher
          scoredCategories.add({'category': name, 'confidence': confidence});
        }
      }
    }

    // The user's task says: try other categories with high chance (70 and above)
    // Sort by confidence descending and take top 3
    scoredCategories.sort(
      (a, b) =>
          (b['confidence'] as double).compareTo(a['confidence'] as double),
    );

    for (
      var i = 0;
      i < scoredCategories.length && alternatives.length < 3;
      i++
    ) {
      if ((scoredCategories[i]['confidence'] as double) >= 0.70) {
        alternatives.add(scoredCategories[i]);
      }
    }

    // If still need more and have high-confidence alternatives from other types
    if (alternatives.length < 3) {
      final otherTypeCategories = allCategories
          .where(
            (c) =>
                (c['type'] as String? ?? 'expense') != transactionType &&
                (c['name'] as String? ?? '') != suggestedCategory,
          )
          .toList();

      for (var category in otherTypeCategories) {
        if (alternatives.length >= 3) break;
        final name = category['name'] as String? ?? '';
        if (name.isNotEmpty && !seen.contains(name)) {
          seen.add(name);
          // Lower confidence for different types (55-65%)
          final confidence = 0.65 - (alternatives.length * 0.05);
          if (confidence >= 0.70) {
            // Still only if 70% or higher
            alternatives.add({'category': name, 'confidence': confidence});
          }
        }
      }
    }

    return alternatives;
  }

  /// Helper method to check if text contains any of the keywords
  static bool _containsAny(String text, List<String> keywords) {
    for (String keyword in keywords) {
      if (text.contains(keyword)) {
        return true;
      }
    }
    return false;
  }

  static String _generateReasoning(String note, String category) {
    final reasoningMap = {
      'Food':
          'Keywords detected: food-related items (breakfast, coffee, restaurant, etc.)',
      'Transportation':
          'Keywords detected: transportation-related items (uber, bus, petrol, etc.)',
      'Vehicle Maintenance':
          'Keywords detected: vehicle-related items (repair, maintenance, service, etc.)',
      'Entertainment':
          'Keywords detected: entertainment-related items (movie, game, concert, etc.)',
      'Salary':
          'Keywords detected: income-related items (salary, bonus, income, etc.)',
      'Credit Card Payment':
          'Keywords detected: credit card payment-related items (credit card, cc payment, etc.)',
      'Loan Payment':
          'Keywords detected: loan payment-related items (loan payment, mortgage, etc.)',
      'Shopping':
          'Keywords detected: shopping-related items (clothes, mall, online shops, etc.)',
      'Healthcare':
          'Keywords detected: healthcare-related items (doctor, hospital, medicine, etc.)',
      'Utilities':
          'Keywords detected: utility-related items (electricity, water, internet, etc.)',
      'Education':
          'Keywords detected: education-related items (school, tuition, course, etc.)',
      'Others': 'General transaction - category uncertain',
    };

    return reasoningMap[category] ?? 'Categorized as: $category';
  }

  /// Get all categories from database
  /// Returns categories with duplicates removed (by categoryId)
  static Future<List<Map<String, dynamic>>> getCategories(String userId) async {
    try {
      final supabase = Supabase.instance.client;

      // Fetch default categories
      final defaultCategories = await supabase
          .from('Category')
          .select()
          .isFilter('userId', null)
          .order('name');

      // Fetch user's custom categories
      final userCategories = await supabase
          .from('Category')
          .select()
          .eq('userId', userId)
          .order('name');

      // Combine and remove duplicates by categoryId
      final seen = <String>{};
      final combined = <Map<String, dynamic>>[];

      for (var category in [
        ...List<Map<String, dynamic>>.from(defaultCategories as List),
        ...List<Map<String, dynamic>>.from(userCategories as List),
      ]) {
        final categoryId = category['categoryId'] as String?;
        if (categoryId != null && !seen.contains(categoryId)) {
          seen.add(categoryId);
          combined.add(category);
        }
      }

      return combined;
    } catch (e) {
      print('Error fetching categories: $e');
      return [];
    }
  }

  /// Get all accounts for a user
  static Future<List<Map<String, dynamic>>> getAccounts(String userId) async {
    try {
      final supabase = Supabase.instance.client;

      final response = await supabase
          .from('Account')
          .select('''
            accountId,
            accountName,
            balance,
            iconImage,
            chartColor,
            ledgerId,
            currencyId,
            Currency: currencyId (
              currencyId,
              code,
              symbol
            )
            ''')
          .eq('userId', userId)
          .eq('assetStatus', true)
          .order('accountName');

      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      print('Error fetching accounts: $e');
      return [];
    }
  }

  /// Get account icon URL
  static String getAccountIconUrl(String? iconPath) {
    if (iconPath == null || iconPath.isEmpty) {
      return '';
    }

    if (iconPath.startsWith('http')) {
      return iconPath;
    }

    const baseUrl =
        'https://drohtvfhklvqoeokopey.storage.supabase.co/storage/v1/s3';
    return '$baseUrl/images/account_icons/$iconPath';
  }

  /// Get category icon URL
  static String getCategoryIconUrl(String? iconPath) {
    if (iconPath == null || iconPath.isEmpty) {
      return '';
    }

    if (iconPath.startsWith('http')) {
      return iconPath;
    }

    const baseUrl =
        'https://drohtvfhklvqoeokopey.storage.supabase.co/storage/v1/s3';
    return '$baseUrl/images/category_icons/$iconPath';
  }

  /// Save transaction to database
  /// Matches the actual Transaction table schema with optional fields
  static Future<bool> saveTransaction({
    required String accountId,
    required double amount,
    required String type,
    required DateTime transactionDate,
    String? categoryId,
    String? subCategoryId,
    String? note,
    String? ledgerId,
    String? image,
    bool refund = false,
    String? receiptId,
  }) async {
    try {
      final supabase = Supabase.instance.client;

      // Generate transaction ID: TRANS+timestamp+random suffix
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final random = DateTime.now().microsecond % 1000;
      final transactionId = 'TRANS$timestamp$random';

      // Build transaction data map based on the actual schema
      final transactionData = {
        'transactionId': transactionId,
        'amount': amount,
        'type': type,
        'date': transactionDate.toIso8601String(),
        'accountId': accountId,
        'refund': refund,
      };

      // Add optional fields only if provided
      if (categoryId != null && categoryId.isNotEmpty) {
        transactionData['categoryId'] = categoryId;
      }
      if (subCategoryId != null && subCategoryId.isNotEmpty) {
        transactionData['subCategoryId'] = subCategoryId;
      }
      if (note != null && note.isNotEmpty) {
        transactionData['note'] = note;
      }
      if (ledgerId != null && ledgerId.isNotEmpty) {
        transactionData['ledgerId'] = ledgerId;
      }
      if (image != null && image.isNotEmpty) {
        transactionData['image'] = image;
      }
      if (receiptId != null && receiptId.isNotEmpty) {
        transactionData['receiptId'] = receiptId;
      }

      // Save transaction to database
      await supabase.from('Transaction').insert(transactionData);

      // Update account balance based on transaction type
      final accountResponse = await supabase
          .from('Account')
          .select('balance')
          .eq('accountId', accountId)
          .single();

      final currentBalance = (accountResponse['balance'] as num).toDouble();

      // Calculate new balance (only for expense/income, not transfer)
      double newBalance = currentBalance;
      if (type.toLowerCase() == 'expense') {
        newBalance = currentBalance - amount;
      } else if (type.toLowerCase() == 'income') {
        newBalance = currentBalance + amount;
      }
      // For transfer and other types, balance is handled separately

      // Update account balance
      await supabase
          .from('Account')
          .update({'balance': newBalance})
          .eq('accountId', accountId);

      print('✅ Transaction saved successfully: $transactionId');
      return true;
    } catch (e) {
      print('❌ Error saving transaction: $e');
      return false;
    }
  }
}
