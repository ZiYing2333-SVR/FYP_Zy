/// Parses bulk transaction input format
/// Format: "note, amount; note, amount; ..."
/// Example: "coffee, 10.50; lunch, 20.00; shopping, 85.00"

class ParsedTransaction {
  final String note;
  final double amount;

  ParsedTransaction({required this.note, required this.amount});

  @override
  String toString() => 'ParsedTransaction(note: $note, amount: $amount)';
}

class TransactionParser {
  /// Check if input contains bulk format (uses semicolon)
  static bool isBulkFormat(String input) {
    return input.contains(';');
  }

  /// Parse bulk transaction string into list of transactions
  /// Returns empty list if parsing fails
  static List<ParsedTransaction> parseBulk(String input) {
    final transactions = <ParsedTransaction>[];

    if (input.isEmpty) {
      return transactions;
    }

    try {
      // Split by semicolon to get individual transactions
      final records = input.split(';');

      for (final record in records) {
        final trimmed = record.trim();
        if (trimmed.isEmpty) continue;

        // Split each record by comma (note, amount)
        final parts = trimmed.split(',');

        if (parts.length < 2) {
          print('⚠️ Skipping invalid record (missing amount): $trimmed');
          continue;
        }

        final note = parts[0].trim();
        final amountStr = parts[1].trim();

        // Try to parse amount
        final amount = double.tryParse(amountStr);
        if (amount == null || amount <= 0) {
          print('⚠️ Skipping invalid record (invalid amount): $trimmed');
          continue;
        }

        if (note.isEmpty) {
          print('⚠️ Skipping invalid record (empty note): $trimmed');
          continue;
        }

        transactions.add(ParsedTransaction(note: note, amount: amount));
      }

      return transactions;
    } catch (e) {
      print('❌ Error parsing bulk transactions: $e');
      return [];
    }
  }

  /// Validate parsed transactions before confirmation
  static String? validateTransactions(List<ParsedTransaction> transactions) {
    if (transactions.isEmpty) {
      return 'No valid transactions found in input';
    }

    if (transactions.length > 50) {
      return 'Maximum 50 transactions per bulk entry (found ${transactions.length})';
    }

    // Validate each transaction
    for (var i = 0; i < transactions.length; i++) {
      final t = transactions[i];
      if (t.note.isEmpty) {
        return 'Transaction ${i + 1}: Note cannot be empty';
      }
      if (t.amount <= 0) {
        return 'Transaction ${i + 1}: Amount must be greater than 0';
      }
      if (t.note.length > 500) {
        return 'Transaction ${i + 1}: Note is too long (max 500 chars)';
      }
    }

    return null; // All valid
  }
}
