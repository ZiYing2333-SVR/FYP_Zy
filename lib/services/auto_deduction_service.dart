import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

/// Service to handle automatic deductions for cycle-based savings goals
/// Checks on every home page access whether transfers need to be created
class AutoDeductionService {
  static const String _tag = '[AutoDeductionService]';

  /// Check and create auto-deduction transfers when home page is accessed
  /// This runs on every home page load to ensure transfers are created promptly
  static Future<Map<String, dynamic>> checkAndCreateAutoDeductions(
    String userId,
  ) async {
    try {
      final supabase = Supabase.instance.client;
      print('$_tag ========== AUTO-DEDUCTION CHECK START ==========');
      print('$_tag Current time: ${DateTime.now()}');
      print('$_tag Checking auto-deductions for user: $userId');

      // Fetch all active cycle-based savings goals for this user
      print(
        '$_tag Fetching SavingGoal records... (status=active, cycleStatus=true)',
      );
      final savingGoals = await supabase
          .from('SavingGoal')
          .select()
          .eq('userId', userId)
          .eq('status', 'active')
          .eq('cycleStatus', true);

      print('$_tag Found ${savingGoals.length} active cycle-based goals');

      if (savingGoals.isEmpty) {
        print('$_tag ⚠️  No active cycle-based savings goals found');
        print('$_tag DEBUG: Check if SavingGoal table exists and has data');
        print('$_tag DEBUG: Try creating a test goal with:');
        print('$_tag DEBUG:   - status: "active"');
        print('$_tag DEBUG:   - cycleStatus: true');
        print('$_tag DEBUG:   - cycleFrequency: "daily"');
        print('$_tag ========== AUTO-DEDUCTION CHECK END ==========');
        return {
          'success': true,
          'message': 'No active cycle-based savings goals',
          'transfersCreated': 0,
        };
      }

      print('$_tag Processing ${savingGoals.length} goal(s)...');

      int transfersCreated = 0;
      List<String> processedGoals = [];
      List<String> errors = [];

      // Process each active cycle-based goal
      for (final goal in savingGoals) {
        try {
          final goalId = goal['goalId'] as String;
          final cycleFrequency = goal['cycleFrequency'] as String?;

          print('$_tag Processing goal: $goalId (frequency: $cycleFrequency)');

          if (cycleFrequency == null) {
            errors.add('Goal $goalId has no cycle frequency set');
            continue;
          }

          // Check if deduction is needed based on frequency
          final isDeductionDue = await _isDeductionDue(goalId, cycleFrequency);

          if (!isDeductionDue) {
            print(
              '$_tag Deduction not due for goal $goalId (frequency: $cycleFrequency)',
            );
            continue;
          }

          // Calculate deduction amount
          final deductionAmount = _calculateDeductionAmount(goal);
          print(
            '$_tag Calculated deduction amount for $goalId: ${deductionAmount.toStringAsFixed(2)}',
          );

          // Create transfer record
          final transferCreated = await _createAutoDeductionTransfer(
            goal,
            deductionAmount,
          );

          if (transferCreated) {
            transfersCreated++;
            processedGoals.add(goalId);
            print(
              '$_tag ✅ Auto-deduction created for goal $goalId: ${deductionAmount.toStringAsFixed(2)}',
            );
          }
        } catch (e) {
          final goalId = goal['goalId'] as String;
          print('$_tag ❌ Error processing goal $goalId: $e');
          errors.add('Error processing goal ${goal['goalId']}: $e');
        }
      }

      print('$_tag ========== AUTO-DEDUCTION CHECK SUMMARY ==========');
      print('$_tag Total goals processed: ${savingGoals.length}');
      print('$_tag Transfers created: $transfersCreated');
      if (errors.isNotEmpty) {
        print('$_tag Errors encountered:');
        for (final error in errors) {
          print('$_tag   - $error');
        }
      }
      print('$_tag ========== AUTO-DEDUCTION CHECK END ==========');

      return {
        'success': true,
        'transfersCreated': transfersCreated,
        'processedGoals': processedGoals,
        'errors': errors,
        'message':
            'Processed ${savingGoals.length} goals, created $transfersCreated transfers',
      };
    } catch (e) {
      print('$_tag ❌ CRITICAL ERROR in checkAndCreateAutoDeductions: $e');
      print('$_tag ========== AUTO-DEDUCTION CHECK END (ERROR) ==========');
      return {'success': false, 'error': 'Failed to check auto-deductions: $e'};
    }
  }

  /// Check for missing transfers based on goal dates and frequency
  /// Returns map with goal details and missing transfer information
  static Future<Map<String, dynamic>?> checkForMissingTransfers(
    Map<String, dynamic> goal,
  ) async {
    try {
      final supabase = Supabase.instance.client;
      final goalId = goal['goalId'] as String;
      final startDate = goal['startDate'];
      final endDate = goal['endDate'];
      final cycleFrequency = (goal['cycleFrequency'] as String?)?.toLowerCase();

      if (startDate == null || endDate == null || cycleFrequency == null) {
        return null;
      }

      // Parse dates
      DateTime start;
      if (startDate is String) {
        start = DateTime.parse(startDate).toUtc();
      } else if (startDate is DateTime) {
        start = startDate.toUtc();
      } else {
        return null;
      }

      DateTime end;
      if (endDate is String) {
        end = DateTime.parse(endDate).toUtc();
      } else if (endDate is DateTime) {
        end = endDate.toUtc();
      } else {
        return null;
      }

      final today = DateTime.now().toUtc();
      final calculationEnd = today.isBefore(end) ? today : end;

      // Calculate expected number of transfers
      int expectedCount = _calculateExpectedTransferCount(
        start,
        calculationEnd,
        cycleFrequency,
      );

      // Get actual non-refunded transfers
      final transfers = await supabase
          .from('Transfer')
          .select()
          .eq('savingGoalId', goalId)
          .eq('isAutoDeduction', true);

      // Filter out refunded transfers
      int actualCount = 0;
      for (final transfer in transfers) {
        final refunded = transfer['refund'] as bool? ?? false;
        if (!refunded) {
          actualCount++;
        }
      }

      final missingCount = expectedCount - actualCount;

      print(
        '$_tag [MISSING] Goal: $goalId | Frequency: $cycleFrequency | Expected: $expectedCount | Actual: $actualCount | Missing: $missingCount',
      );

      if (missingCount > 0) {
        // Fetch currency symbol and destination account balance
        String currencySymbol = '\$'; // Default fallback
        double destAccountBalance = 0; // Actual amount saved
        try {
          final destAccount = await supabase
              .from('Account')
              .select('currencyId, balance')
              .eq('accountId', goal['destAccountId'] as String)
              .single();

          // Get actual balance (this is the real progress)
          destAccountBalance =
              (destAccount['balance'] as num?)?.toDouble() ?? 0;

          final currencyId = destAccount['currencyId'] as String?;
          if (currencyId != null && currencyId != 'NULL') {
            final currency = await supabase
                .from('Currency')
                .select('symbol')
                .eq('currencyId', currencyId)
                .single();

            currencySymbol = currency['symbol'] as String? ?? '\$';
          }
        } catch (e) {
          print(
            '$_tag [MISSING] ⚠️  Could not fetch currency symbol or balance: $e',
          );
          // Use default $ symbol if query fails
        }

        return {
          'goalId': goalId,
          'goalName': goal['name'] ?? 'Unnamed Goal',
          'targetAmount': goal['targetAmount'] ?? 0,
          'currentAmount': destAccountBalance, // Use actual account balance
          'frequency': cycleFrequency,
          'expectedCount': expectedCount,
          'actualCount': actualCount,
          'missingCount': missingCount,
          'amountPerTransfer': _calculateDeductionAmount(
            goal,
          ).toStringAsFixed(2),
          'totalMissingAmount': (missingCount * _calculateDeductionAmount(goal))
              .toStringAsFixed(2),
          'sourceAccountId': goal['sourceAcountId'],
          'destAccountId': goal['destAccountId'],
          'userId': goal['userId'],
          'currencySymbol': currencySymbol,
        };
      }

      return null;
    } catch (e) {
      print('$_tag [MISSING] ❌ Error checking for missing transfers: $e');
      return null;
    }
  }

  /// Calculate expected number of transfers based on dates and frequency
  static int _calculateExpectedTransferCount(
    DateTime startDate,
    DateTime endDate,
    String frequency,
  ) {
    final totalDays = endDate.difference(startDate).inDays + 1;

    switch (frequency.toLowerCase()) {
      case 'daily':
        return totalDays;

      case 'weekly':
        return (totalDays / 7).ceil();

      case 'monthly':
        return _countMonths(startDate, endDate);

      default:
        return 0;
    }
  }

  /// Auto-deduct all missing transfers for a goal
  static Future<int> autoDeductMissingTransfers(
    Map<String, dynamic> missingInfo,
  ) async {
    try {
      final supabase = Supabase.instance.client;
      final goalId = missingInfo['goalId'] as String;
      final userId = missingInfo['userId'] as String;
      // Parse and round to 2 decimal places
      final amountPerTransfer = double.parse(
        missingInfo['amountPerTransfer'].toString(),
      );
      final missingCount = missingInfo['missingCount'] as int;

      print(
        '$_tag [BATCH] Creating $missingCount missing transfers for goal: $goalId (Amount per transfer: ${amountPerTransfer.toStringAsFixed(2)})',
      );

      int created = 0;

      // Get the full goal data
      final goalData = await supabase
          .from('SavingGoal')
          .select()
          .eq('goalId', goalId)
          .single();

      // OPTIMIZATION: Get the max sequence number ONCE, then calculate locally
      print('$_tag [BATCH] Fetching max sequence number for user: $userId');
      final allTransfers = await supabase
          .from('Transfer')
          .select('transferId')
          .like('transferId', 'TRANSFER${userId}%');

      int nextSequence = 1;
      if (allTransfers.isNotEmpty) {
        // Find the maximum sequence number
        int maxSeq = 0;
        for (final transfer in allTransfers) {
          final id = transfer['transferId'] as String;
          final seqPart = id.replaceFirst('TRANSFER$userId', '');
          try {
            final seq = int.parse(seqPart);
            if (seq > maxSeq) maxSeq = seq;
          } catch (e) {
            // Skip if can't parse
          }
        }
        nextSequence = maxSeq + 1;
      }

      print('$_tag [BATCH] Starting sequence from: $nextSequence');

      // Calculate the dates for each missing transfer
      final missingDates = _calculateMissingTransferDates(
        goalData,
        missingCount,
      );
      print('$_tag [BATCH] Missing transfer dates: $missingDates');

      for (int i = 0; i < missingCount; i++) {
        // Calculate sequence locally instead of querying database
        final sequence = nextSequence + i;
        // Get the date for this missing transfer (or use today if list is shorter)
        final transferDate = i < missingDates.length
            ? missingDates[i]
            : DateTime.now();

        final success = await _createAutoDeductionTransfer(
          goalData,
          amountPerTransfer,
          sequence,
          transferDate, // Pass the calculated date for this transfer
        );
        if (success) {
          created++;
        }
      }

      print(
        '$_tag [BATCH] ✅ Successfully created $created of $missingCount missing transfers',
      );

      return created;
    } catch (e) {
      print('$_tag [BATCH] ❌ Error creating missing transfers: $e');
      return 0;
    }
  }

  /// Check if a deduction is due based on cycle frequency and last transfer date
  static Future<bool> _isDeductionDue(
    String goalId,
    String cycleFrequency,
  ) async {
    try {
      final supabase = Supabase.instance.client;
      final today = DateTime.now();
      final dateFormat = DateFormat('yyyy-MM-dd');

      // Get the last auto-deduction transfer for this goal
      final lastTransfers = await supabase
          .from('Transfer')
          .select()
          .eq('savingGoalId', goalId)
          .eq('isAutoDeduction', true)
          .order('date', ascending: false)
          .limit(1);

      DateTime lastDeductionDate;
      if (lastTransfers.isEmpty) {
        // First deduction, check against goal start date
        final goalData = await supabase
            .from('SavingGoal')
            .select('startDate')
            .eq('goalId', goalId)
            .single();

        final startDate = goalData['startDate'];
        if (startDate is String) {
          lastDeductionDate = DateTime.parse(startDate);
        } else if (startDate is DateTime) {
          lastDeductionDate = startDate;
        } else {
          lastDeductionDate = today;
        }
      } else {
        final lastTransfer = lastTransfers.first;
        final transferDate = lastTransfer['date'];
        if (transferDate is String) {
          lastDeductionDate = DateTime.parse(transferDate);
        } else if (transferDate is DateTime) {
          lastDeductionDate = transferDate;
        } else {
          return false;
        }
      }

      print(
        '$_tag Last deduction date for $goalId: ${dateFormat.format(lastDeductionDate)} (today: ${dateFormat.format(today)})',
      );

      // Check based on frequency
      switch (cycleFrequency.toLowerCase()) {
        case 'daily':
          // Check if a transfer was created today
          if (dateFormat.format(lastDeductionDate) ==
              dateFormat.format(today)) {
            print(
              '$_tag [DAILY] ❌ Already deducted today for $goalId (last: ${dateFormat.format(lastDeductionDate)}, today: ${dateFormat.format(today)})',
            );
            return false;
          }
          print(
            '$_tag [DAILY] ✅ Deduction is due for $goalId (last: ${dateFormat.format(lastDeductionDate)}, today: ${dateFormat.format(today)})',
          );
          return true;

        case 'weekly':
          // Check if 7+ days have passed
          final daysSinceLastDeduction = today
              .difference(lastDeductionDate)
              .inDays;
          if (daysSinceLastDeduction >= 7) {
            print(
              '$_tag [WEEKLY] ✅ Deduction is due for $goalId ($daysSinceLastDeduction days since: ${dateFormat.format(lastDeductionDate)})',
            );
            return true;
          }
          print(
            '$_tag [WEEKLY] ❌ Not due yet for $goalId (only $daysSinceLastDeduction/7 days, last: ${dateFormat.format(lastDeductionDate)})',
          );
          return false;

        case 'monthly':
          // Check if we're in a new month
          final lastMonth = lastDeductionDate.month;
          final lastYear = lastDeductionDate.year;
          final currentMonth = today.month;
          final currentYear = today.year;

          if (lastYear < currentYear ||
              (lastYear == currentYear && lastMonth < currentMonth)) {
            print(
              '$_tag [MONTHLY] ✅ Deduction is due for $goalId (last: $lastYear-$lastMonth, current: $currentYear-$currentMonth)',
            );
            return true;
          }
          print(
            '$_tag [MONTHLY] ❌ Already done this month for $goalId (last: $lastYear-$lastMonth, current: $currentYear-$currentMonth)',
          );
          return false;

        default:
          print(
            '$_tag [UNKNOWN] ⚠️  Unknown frequency: $cycleFrequency for $goalId',
          );
          return false;
      }
    } catch (e) {
      print(
        '$_tag [ERROR] ❌ Error checking if deduction is due for $goalId: $e',
      );
      return false;
    }
  }

  /// Calculate the deduction amount based on goal timeline
  static double _calculateDeductionAmount(Map<String, dynamic> goal) {
    try {
      final targetAmount = (goal['targetAmount'] as num?)?.toDouble() ?? 0;
      final startDate = goal['startDate'];
      final endDate = goal['endDate'];
      final cycleFrequency = (goal['cycleFrequency'] as String?)?.toLowerCase();

      if (startDate == null || endDate == null) {
        // If no dates, divide equally across first month (30 days)
        if (cycleFrequency == 'daily') {
          return targetAmount / 30;
        }
        return targetAmount / 4; // Weekly average for a month
      }

      // Parse dates
      DateTime start;
      if (startDate is String) {
        start = DateTime.parse(startDate);
      } else if (startDate is DateTime) {
        start = startDate;
      } else {
        return targetAmount / 30;
      }

      DateTime end;
      if (endDate is String) {
        end = DateTime.parse(endDate);
      } else if (endDate is DateTime) {
        end = endDate;
      } else {
        return targetAmount / 30;
      }

      // Calculate total days
      final totalDays = end.difference(start).inDays;
      if (totalDays <= 0) return targetAmount;

      // Calculate cycles based on frequency
      int totalCycles;
      switch (cycleFrequency) {
        case 'daily':
          totalCycles = totalDays;
          break;
        case 'weekly':
          totalCycles = (totalDays / 7).ceil();
          break;
        case 'monthly':
          // Approximate: count unique months
          totalCycles = _countMonths(start, end);
          break;
        default:
          totalCycles = 30; // Default: 30 days
      }

      final amountPerCycle = targetAmount / totalCycles;
      print(
        '$_tag Calculated ${targetAmount.toStringAsFixed(2)} / $totalCycles cycles = ${amountPerCycle.toStringAsFixed(2)} per cycle',
      );
      return amountPerCycle;
    } catch (e) {
      print('$_tag Error calculating deduction amount: $e');
      return 0;
    }
  }

  /// Count the number of months between two dates (inclusive)
  static int _countMonths(DateTime start, DateTime end) {
    int months = 0;
    DateTime current = start;

    while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
      months++;
      // Move to next month
      if (current.month == 12) {
        current = DateTime(current.year + 1, 1, 1);
      } else {
        current = DateTime(current.year, current.month + 1, 1);
      }
    }

    return months > 0 ? months : 1;
  }

  /// Calculate the dates when each missing transfer should have occurred
  /// Returns list of DateTime objects in chronological order
  static List<DateTime> _calculateMissingTransferDates(
    Map<String, dynamic> goal,
    int missingCount,
  ) {
    try {
      final startDate = goal['startDate'];
      final cycleFrequency = (goal['cycleFrequency'] as String?)?.toLowerCase();

      DateTime goalStart;
      if (startDate is String) {
        goalStart = DateTime.parse(startDate);
      } else if (startDate is DateTime) {
        goalStart = startDate;
      } else {
        // Fallback: use today minus missingCount days
        return List.generate(
          missingCount,
          (i) => DateTime.now().subtract(Duration(days: missingCount - i - 1)),
        );
      }

      final today = DateTime.now();
      List<DateTime> dates = [];

      if (cycleFrequency == 'daily') {
        // Generate dates from goalStart onwards, up to today
        DateTime current = goalStart;
        while (current.isBefore(today) || current.isAtSameMomentAs(today)) {
          if (dates.length >= missingCount) break;
          dates.add(current);
          current = current.add(Duration(days: 1));
        }
      } else if (cycleFrequency == 'weekly') {
        // Generate weekly dates
        DateTime current = goalStart;
        while (current.isBefore(today) || current.isAtSameMomentAs(today)) {
          if (dates.length >= missingCount) break;
          dates.add(current);
          current = current.add(Duration(days: 7));
        }
      } else if (cycleFrequency == 'monthly') {
        // Generate monthly dates
        DateTime current = goalStart;
        while (current.isBefore(today) || current.isAtSameMomentAs(today)) {
          if (dates.length >= missingCount) break;
          dates.add(current);
          // Move to next month
          if (current.month == 12) {
            current = DateTime(current.year + 1, 1, current.day);
          } else {
            current = DateTime(current.year, current.month + 1, current.day);
          }
        }
      }

      print(
        '$_tag [DATES] Calculated ${dates.length} missing transfer dates for frequency: $cycleFrequency',
      );
      return dates;
    } catch (e) {
      print('$_tag [DATES] ❌ Error calculating missing transfer dates: $e');
      // Return fallback dates (working backwards from today)
      return List.generate(
        missingCount,
        (i) => DateTime.now().subtract(Duration(days: missingCount - i - 1)),
      );
    }
  }

  /// Create an auto-deduction transfer record
  /// sequenceNumber: Optional - pass to use sequence-based format for batch operations
  /// transferDate: Optional - pass to record historical transfers (instead of using today's date)
  static Future<bool> _createAutoDeductionTransfer(
    Map<String, dynamic> goal,
    double deductionAmount, [
    int? sequenceNumber,
    DateTime? transferDate,
  ]) async {
    try {
      final supabase = Supabase.instance.client;
      final goalId = goal['goalId'] as String;
      final sourceAccountId = goal['sourceAcountId'] as String?;
      final destAccountId = goal['destAccountId'] as String;
      final userId = goal['userId'] as String;

      print('$_tag [TRANSFER] Creating transfer for goal: $goalId');
      print('$_tag [TRANSFER]   Source: $sourceAccountId');
      print('$_tag [TRANSFER]   Destination: $destAccountId');
      print('$_tag [TRANSFER]   Amount: ${deductionAmount.toStringAsFixed(2)}');

      if (sourceAccountId == null) {
        print(
          '$_tag [TRANSFER] ❌ ERROR: Source account not set for goal $goalId',
        );
        return false;
      }

      // Verify source account has sufficient balance and get ledgerId
      print('$_tag [TRANSFER] Checking source account balance...');
      final sourceAccount = await supabase
          .from('Account')
          .select('balance, ledgerId')
          .eq('accountId', sourceAccountId)
          .single();

      final sourceBalance = (sourceAccount['balance'] as num?)?.toDouble() ?? 0;
      final ledgerId = sourceAccount['ledgerId'] as String?;
      print('$_tag [TRANSFER]   Source balance: $sourceBalance');
      print('$_tag [TRANSFER]   Ledger ID: $ledgerId');

      if (sourceBalance < deductionAmount) {
        print(
          '$_tag [TRANSFER] ❌ Insufficient balance. Available: $sourceBalance, Required: $deductionAmount',
        );
        return false;
      }

      print('$_tag [TRANSFER] ✅ Sufficient balance - proceeding with transfer');

      // Get transfer date (use provided transferDate for historical transfers, or today)
      final now = transferDate ?? DateTime.now();
      print(
        '$_tag [TRANSFER] Using transfer date: ${now.toIso8601String()} ${transferDate != null ? '(historical)' : '(today)'}',
      );

      // Create transfer record ID using sequence-based format (like confirm_bulk_transactions.dart)
      // Format: TRANSFER + userId + 6-digit padded sequence
      // Examples: TRANSFER123450000001, TRANSFER123450000002
      String transferId;

      if (sequenceNumber != null) {
        // Batch mode: use provided sequence number
        final formattedSequence = sequenceNumber.toString().padLeft(6, '0');
        transferId = 'TRANSFER${userId}$formattedSequence';
        print(
          '$_tag [TRANSFER] Using sequence-based ID (batch): $transferId (sequence: $sequenceNumber)',
        );
      } else {
        // Single transfer mode: query database for next sequence
        final existingTransfers = await supabase
            .from('Transfer')
            .select('transferId')
            .like('transferId', 'TRANSFER${userId}%');
        final nextSeq = existingTransfers.length + 1;
        final formattedSequence = nextSeq.toString().padLeft(6, '0');
        transferId = 'TRANSFER${userId}$formattedSequence';
        print(
          '$_tag [TRANSFER] Using sequence-based ID (single): $transferId (sequence: $nextSeq)',
        );
      }

      // Round amount to 2 decimal places before saving
      final roundedAmount = double.parse(deductionAmount.toStringAsFixed(2));

      // Get goal name for the transfer note
      final goalName = goal['name'] as String? ?? 'Savings Goal';

      // Only include columns that exist in the Transfer table
      final transferData = {
        'transferId': transferId,
        'fromAccountId': sourceAccountId,
        'toAccountId': destAccountId,
        'amount': roundedAmount,
        'date': now.toIso8601String(),
        'note': 'Auto-deduction for savings goal: $goalName',
        'savingGoalId': goalId,
        'isAutoDeduction': true,
        'ledgerId': ledgerId,
      };

      print('$_tag [TRANSFER] Inserting transfer record: $transferId');
      print('$_tag [TRANSFER] Transfer data: $transferData');

      // Insert transfer
      await supabase.from('Transfer').insert(transferData);
      print('$_tag [TRANSFER] ✅ Transfer inserted');

      // Update source account balance (rounded to 2 decimal places)
      print('$_tag [TRANSFER] Updating source account balance...');
      final newSourceBalance = double.parse(
        (sourceBalance - deductionAmount).toStringAsFixed(2),
      );
      await supabase
          .from('Account')
          .update({'balance': newSourceBalance})
          .eq('accountId', sourceAccountId);
      print(
        '$_tag [TRANSFER] ✅ Source account updated (- ${deductionAmount.toStringAsFixed(2)})',
      );

      // Update destination account balance
      print('$_tag [TRANSFER] Updating destination account balance...');
      final destAccount = await supabase
          .from('Account')
          .select('balance')
          .eq('accountId', destAccountId)
          .single();

      final destBalance = (destAccount['balance'] as num?)?.toDouble() ?? 0;
      final newDestBalance = double.parse(
        (destBalance + deductionAmount).toStringAsFixed(2),
      );
      await supabase
          .from('Account')
          .update({'balance': newDestBalance})
          .eq('accountId', destAccountId);
      print(
        '$_tag [TRANSFER] ✅ Destination account updated (+ ${deductionAmount.toStringAsFixed(2)})',
      );

      // Update SavingGoal current amount (rounded to 2 decimal places)
      print('$_tag [TRANSFER] Updating SavingGoal progress...');
      final currentAmount = (goal['currentAmount'] as num?)?.toDouble() ?? 0;
      final newGoalAmount = double.parse(
        (currentAmount + deductionAmount).toStringAsFixed(2),
      );
      await supabase
          .from('SavingGoal')
          .update({'currentAmount': newGoalAmount})
          .eq('goalId', goalId);
      print(
        '$_tag [TRANSFER] ✅ SavingGoal updated (currentAmount: ${currentAmount.toStringAsFixed(2)} → ${(currentAmount + deductionAmount).toStringAsFixed(2)})',
      );

      print(
        '$_tag [TRANSFER] ✅✅✅ SUCCESS! Transfer created: $transferId | Amount: ${deductionAmount.toStringAsFixed(2)}',
      );
      return true;
    } catch (e) {
      print('$_tag [TRANSFER] ❌❌❌ ERROR creating transfer: $e');
      return false;
    }
  }
}
