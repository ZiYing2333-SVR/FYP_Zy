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
    String userId,
  ) async {
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

        // Check for missing transfers
        final missing = await AutoDeductionService.checkForMissingTransfers(
          goal,
        );

        if (missing != null) {
          missingList.add(missing);
          print(
            '$_tag Found missing transfers for goal: $goalId (Missing: ${missing['missingCount']})',
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
    Map<String, dynamic> missingInfo,
  ) async {
    try {
      print(
        '$_tag Processing missing transfers for goal: ${missingInfo['goalId']}',
      );

      final created = await AutoDeductionService.autoDeductMissingTransfers(
        missingInfo,
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

    return '''Goal: $goalName
Frequency: $frequency

You missed $missingCount $frequency transfers!

Details:
• Amount per transfer: $currencySymbol$amountPerTransfer
• Total missing amount: $currencySymbol$totalMissing
• Current goal progress: $currencySymbol$currentAmount / $currencySymbol$targetAmount

Would you like to auto-deduct all missing transfers now?

(If you click "Not Now", this alert will only appear again after you logout and login again.)''';
  }
}
