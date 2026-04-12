import 'package:supabase_flutter/supabase_flutter.dart';
import 'auto_deduction_service.dart';

/// Service to handle missing transfer detection and alert management
/// Tracks dismissed alerts per session (resets after logout/login)
class MissingTransferAlertService {
  static const String _tag = '[MissingTransferAlertService]';

  // Track dismissed alerts in this session (userId -> Set of goalIds)
  static final Map<String, Set<String>> _dismissedAlerts = {};

  /// Check all goals for missing transfers and return list of goals with missing transfers
  static Future<List<Map<String, dynamic>>> checkAllMissingTransfers(
    String userId, {
    Set<String>? executedFreshDeductionGoals,
  }) async {
    try {
      final supabase = Supabase.instance.client;
      print('$_tag Checking for missing transfers for user: $userId');

      // Get all active cycle-based goals
      final goals = await supabase
          .from('SavingGoal')
          .select()
          .eq('userId', userId)
          .eq('status', 'active')
          .eq('cycleStatus', true);

      List<Map<String, dynamic>> missingList = [];

      // Check each goal for missing transfers
      for (final goal in goals) {
        final goalId = goal['goalId'] as String;

        // Skip if dismissed in this session
        if (_isDismissedInSession(userId, goalId)) {
          print('$_tag Goal $goalId is dismissed for this session, skipping');
          continue;
        }

        // Check if this goal had a fresh auto-deduction executed
        final hadFreshDeductionExecuted =
            executedFreshDeductionGoals?.contains(goalId) ?? false;

        // Check for missing transfers
        // If fresh deduction was executed, exclude today from calculation
        final missing = await AutoDeductionService.checkForMissingTransfers(
          goal,
          excludeToday: hadFreshDeductionExecuted,
        );

        if (missing != null) {
          missingList.add(missing);
          print(
            '$_tag Found missing transfers for goal: $goalId (Missing: ${missing['missingCount']}, excludeToday: $hadFreshDeductionExecuted)',
          );
        }
      }

      print(
        '$_tag Check complete: Found ${missingList.length} goals with missing transfers',
      );
      return missingList;
    } catch (e) {
      print('$_tag ❌ Error checking missing transfers: $e');
      return [];
    }
  }

  /// Dismiss an alert for the current session
  /// Alert will reappear only after user logs out and logs back in
  static void dismissAlertForSession(String userId, String goalId) {
    if (!_dismissedAlerts.containsKey(userId)) {
      _dismissedAlerts[userId] = {};
    }
    _dismissedAlerts[userId]!.add(goalId);
    print(
      '$_tag Alert dismissed for session: goalId=$goalId (will reappear after logout)',
    );
  }

  /// Clear all dismissed alerts for a user (called on logout)
  static void clearDismissedAlerts(String userId) {
    _dismissedAlerts.remove(userId);
    print('$_tag Cleared dismissed alerts for user: $userId');
  }

  /// Check if an alert is dismissed in current session
  static bool _isDismissedInSession(String userId, String goalId) {
    return _dismissedAlerts[userId]?.contains(goalId) ?? false;
  }

  /// Process and auto-deduct missing transfers
  static Future<int> processMissingTransfers(
    Map<String, dynamic> missingInfo, {
    String? selectedLedgerId,
  }) async {
    try {
      print(
        '$_tag Processing missing transfers for goal: ${missingInfo['goalId']}',
      );

      final created = await AutoDeductionService.autoDeductMissingTransfers(
        missingInfo,
        selectedLedgerId: selectedLedgerId,
      );

      if (created > 0) {
        print('$_tag ✅ Successfully created $created missing transfers');
        // Note: The dismissed status is NOT cleared here
        // User can still dismiss the alert again if they want
      }

      return created;
    } catch (e) {
      print('$_tag ❌ Error processing missing transfers: $e');
      return 0;
    }
  }

  /// Generate alert message for display with amounts formatted to 2 decimal places
  static String generateAlertMessage(Map<String, dynamic> missingInfo) {
    final goalName = missingInfo['goalName'] ?? 'Unnamed Goal';
    final frequency = missingInfo['frequency'] ?? 'unknown';
    final missingCount = missingInfo['missingCount'] as int;
    final currencySymbol = missingInfo['currencySymbol'] as String? ?? '\$';

    // Format amounts to exactly 2 decimal places
    final totalMissing = double.parse(
      missingInfo['totalMissingAmount'].toString(),
    ).toStringAsFixed(2);
    final amountPerTransfer = double.parse(
      missingInfo['amountPerTransfer'].toString(),
    ).toStringAsFixed(2);
    final currentAmount = double.parse(
      (missingInfo['currentAmount'] ?? 0).toString(),
    ).toStringAsFixed(2);
    final targetAmount = double.parse(
      (missingInfo['targetAmount'] ?? 0).toString(),
    ).toStringAsFixed(2);

    // Generate list of missing dates with amounts
    DateTime now = DateTime.now();
    final excludeToday = missingInfo['excludeToday'] as bool? ?? false;

    List<String> missingDatesWithAmount = [];

    if (frequency.toLowerCase() == 'daily') {
      // For daily missing transfers, generate dates from oldest to newest
      // If excludeToday=true: missing dates are from (now - missingCount) to (now - 1)
      //   Example: now=Apr13, missingCount=3 → Apr10, Apr11, Apr12
      // If excludeToday=false: missing dates are from (now - missingCount + 1) to now
      //   Example: now=Apr13, missingCount=3 → Apr11, Apr12, Apr13
      for (int i = 0; i < missingCount; i++) {
        final daysBack = excludeToday
            ? (missingCount - i)
            : (missingCount - i - 1);
        final date = now.subtract(Duration(days: daysBack));
        missingDatesWithAmount.add(
          '${_formatDate(date)}: $currencySymbol$amountPerTransfer',
        );
      }
    } else if (frequency.toLowerCase() == 'weekly') {
      // For weekly: similar logic adjusted for weekly frequency
      for (int i = 0; i < missingCount; i++) {
        final weeksBack = excludeToday
            ? (missingCount - i)
            : (missingCount - i - 1);
        final date = now.subtract(Duration(days: weeksBack * 7));
        missingDatesWithAmount.add(
          '${_formatDate(date)}: $currencySymbol$amountPerTransfer',
        );
      }
    } else if (frequency.toLowerCase() == 'monthly') {
      // For monthly: adjust by months with same logic
      for (int i = 0; i < missingCount; i++) {
        final monthsBack = excludeToday
            ? (missingCount - i)
            : (missingCount - i - 1);
        final date = DateTime(now.year, now.month - monthsBack, now.day);
        missingDatesWithAmount.add(
          '${_formatDate(date)}: $currencySymbol$amountPerTransfer',
        );
      }
    }

    // Build the details section with individual dates
    String detailsSection = missingDatesWithAmount.join('\n• ');
    if (detailsSection.isNotEmpty) {
      detailsSection = '• $detailsSection';
    }

    return '''Goal: $goalName
Frequency: $frequency

You missed $missingCount $frequency transfers!

Missing Dates:
$detailsSection

Summary:
• Total missing amount: $currencySymbol$totalMissing
• Current goal progress: $currencySymbol$currentAmount / $currencySymbol$targetAmount

Would you like to auto-deduct all missing transfers now?

(If you click "Not Now", this alert will only appear again after you logout and login again.)''';
  }

  /// Format date as "MMM d, yyyy"
  static String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
