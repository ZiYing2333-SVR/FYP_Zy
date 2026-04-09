import 'package:supabase_flutter/supabase_flutter.dart';

/// Service to manage budget caution dismissal state
/// Uses the BudgetCaution table to track which budgets have been dismissed
class BudgetCautionService {
  static final BudgetCautionService _instance =
      BudgetCautionService._internal();

  factory BudgetCautionService() {
    return _instance;
  }

  BudgetCautionService._internal();

  /// Get or create a caution record for a budget
  Future<Map<String, dynamic>> getOrCreateCautionRecord(
    String budgetId,
    String userId,
  ) async {
    try {
      final supabase = Supabase.instance.client;

      // Try to get existing record
      final existing = await supabase
          .from('BudgetCaution')
          .select()
          .eq('budgetId', budgetId)
          .eq('userId', userId)
          .maybeSingle();

      if (existing != null) {
        return existing;
      }

      // Create new record if doesn't exist
      final newRecord = {
        'budgetId': budgetId,
        'userId': userId,
        'dismissed': false,
        'exceedDismissed': false,
      };

      await supabase.from('BudgetCaution').insert(newRecord);

      return newRecord;
    } catch (e) {
      print('[BudgetCautionService] Error getting/creating caution record: $e');
      rethrow;
    }
  }

  /// Check if a budget's caution alert has been dismissed
  Future<bool> isCautionDismissed(String budgetId, String userId) async {
    try {
      final supabase = Supabase.instance.client;

      final record = await supabase
          .from('BudgetCaution')
          .select()
          .eq('budgetId', budgetId)
          .eq('userId', userId)
          .maybeSingle();

      if (record == null) return false;

      return record['dismissed'] == true;
    } catch (e) {
      print('[BudgetCautionService] Error checking caution dismissed: $e');
      return false;
    }
  }

  /// Check if a budget's exceed alert has been dismissed
  Future<bool> isExceedDismissed(String budgetId, String userId) async {
    try {
      final supabase = Supabase.instance.client;

      final record = await supabase
          .from('BudgetCaution')
          .select()
          .eq('budgetId', budgetId)
          .eq('userId', userId)
          .maybeSingle();

      if (record == null) return false;

      return record['exceedDismissed'] == true;
    } catch (e) {
      print('[BudgetCautionService] Error checking exceed dismissed: $e');
      return false;
    }
  }

  /// Dismiss caution alert for a budget
  Future<void> dismissCautionAlert(String budgetId, String userId) async {
    try {
      final supabase = Supabase.instance.client;

      // Get or create record first
      await getOrCreateCautionRecord(budgetId, userId);

      // Update dismissal status
      await supabase
          .from('BudgetCaution')
          .update({
            'dismissed': true,
            'dismissedAt': DateTime.now().toIso8601String(),
          })
          .eq('budgetId', budgetId)
          .eq('userId', userId);

      print(
        '[BudgetCautionService] Dismissed caution alert for budget: $budgetId',
      );
    } catch (e) {
      print('[BudgetCautionService] Error dismissing caution alert: $e');
      rethrow;
    }
  }

  /// Dismiss exceed alert for a budget
  Future<void> dismissExceedAlert(String budgetId, String userId) async {
    try {
      final supabase = Supabase.instance.client;

      // Get or create record first
      await getOrCreateCautionRecord(budgetId, userId);

      // Update dismissal status
      await supabase
          .from('BudgetCaution')
          .update({
            'exceedDismissed': true,
            'exceedDismissedAt': DateTime.now().toIso8601String(),
          })
          .eq('budgetId', budgetId)
          .eq('userId', userId);

      print(
        '[BudgetCautionService] Dismissed exceed alert for budget: $budgetId',
      );
    } catch (e) {
      print('[BudgetCautionService] Error dismissing exceed alert: $e');
      rethrow;
    }
  }

  /// Clear/reset dismissal for a budget (re-enable alerts)
  Future<void> clearDismissal(String budgetId, String userId) async {
    try {
      final supabase = Supabase.instance.client;

      await supabase
          .from('BudgetCaution')
          .update({
            'dismissed': false,
            'dismissedAt': null,
            'exceedDismissed': false,
            'exceedDismissedAt': null,
          })
          .eq('budgetId', budgetId)
          .eq('userId', userId);

      print('[BudgetCautionService] Cleared dismissal for budget: $budgetId');
    } catch (e) {
      print('[BudgetCautionService] Error clearing dismissal: $e');
      rethrow;
    }
  }

  /// Get all dismissed caution budgets for a user
  Future<List<String>> getDismissedCautionBudgets(String userId) async {
    try {
      final supabase = Supabase.instance.client;

      final records = await supabase
          .from('BudgetCaution')
          .select('budgetId')
          .eq('userId', userId)
          .eq('dismissed', true);

      return List<String>.from(records.map((r) => r['budgetId'] as String));
    } catch (e) {
      print(
        '[BudgetCautionService] Error getting dismissed caution budgets: $e',
      );
      return [];
    }
  }

  /// Get all dismissed exceed budgets for a user
  Future<List<String>> getDismissedExceedBudgets(String userId) async {
    try {
      final supabase = Supabase.instance.client;

      final records = await supabase
          .from('BudgetCaution')
          .select('budgetId')
          .eq('userId', userId)
          .eq('exceedDismissed', true);

      return List<String>.from(records.map((r) => r['budgetId'] as String));
    } catch (e) {
      print(
        '[BudgetCautionService] Error getting dismissed exceed budgets: $e',
      );
      return [];
    }
  }
}
