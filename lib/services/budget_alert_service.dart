import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for managing budget caution alerts
class BudgetAlertService {
  static const String _tag = '[BudgetAlertService]';

  /// Check if a caution alert is dismissed with renewal consideration
  /// Returns true if the alert is dismissed and hasn't been triggered by a renewal
  Future<bool> isCautionDismissed(String budgetId, String cycleType) async {
    try {
      final response = await Supabase.instance.client
          .from('BudgetCaution')
          .select()
          .eq('budgetId', budgetId)
          .eq('dismissed', true)
          .maybeSingle();

      if (response == null) {
        print('$_tag Budget $budgetId: No dismissal record found');
        return false;
      }

      print(
        '$_tag Budget $budgetId: Dismissal record found - dismissedAt: ${response['dismissedAt']}',
      );

      // Check if the budget cycle has renewed since dismissal
      final dismissedAtStr = response['dismissedAt'];
      if (dismissedAtStr != null) {
        final hasRenewed = _hasCycleRenewed(dismissedAtStr, cycleType);
        print(
          '$_tag Budget $budgetId: Cycle renewed? $hasRenewed (cycleType: $cycleType)',
        );

        if (hasRenewed) {
          // Reset the dismissal if cycle has renewed
          print(
            '$_tag Budget $budgetId: Resetting dismissal due to cycle renewal',
          );
          await _resetCautionDismissal(budgetId);
          // Reset isAlert and isWarning when cycle renews
          await _resetBudgetAlertFlags(budgetId);
          return false;
        }
      }

      print('$_tag Budget $budgetId: Still dismissed - returning true');
      return true;
    } catch (e) {
      print('$_tag Error checking dismissed caution for $budgetId: $e');
      return false;
    }
  }

  /// Get all budgets with caution status (>=70% spent, not dismissed)
  Future<List<Map<String, dynamic>>> getCautionBudgets(
    String userId,
    Map<String, double> budgetUsageMap, // {budgetId: usagePercentage}
  ) async {
    try {
      final List<Map<String, dynamic>> cautionBudgets = [];

      for (var entry in budgetUsageMap.entries) {
        final budgetId = entry.key;
        final usagePercentage = entry.value;

        print(
          '$_tag getCautionBudgets: Checking budget $budgetId with usage $usagePercentage%',
        );

        // Get budget details to check cycle type
        final budget = await Supabase.instance.client
            .from('Budget')
            .select()
            .eq('budgetId', budgetId)
            .single();

        final cycleType = (budget['cycleType'] ?? 'month').toLowerCase();

        // Check if usage is >= 70% and not dismissed
        if (usagePercentage >= 70) {
          final isDismissed = await isCautionDismissed(budgetId, cycleType);

          print(
            '$_tag getCautionBudgets: Budget $budgetId >= 70%, isDismissed = $isDismissed',
          );

          if (!isDismissed) {
            print('$_tag getCautionBudgets: Adding $budgetId to caution list');
            cautionBudgets.add({
              'budgetId': budgetId,
              'usagePercentage': usagePercentage,
              'budget': budget,
            });
          }
        }
      }

      print(
        '$_tag getCautionBudgets: Total caution budgets = ${cautionBudgets.length}',
      );
      return cautionBudgets;
    } catch (e) {
      print('$_tag Error getting caution budgets: $e');
      return [];
    }
  }

  /// Dismiss a caution alert for a specific budget
  Future<void> dismissCautionAlert(String budgetId, String userId) async {
    try {
      print('$_tag dismissCautionAlert: Dismissing budget $budgetId');

      // Check if record exists
      final existing = await Supabase.instance.client
          .from('BudgetCaution')
          .select()
          .eq('budgetId', budgetId)
          .maybeSingle();

      if (existing != null) {
        print(
          '$_tag dismissCautionAlert: Updating existing record for $budgetId',
        );
        // Update existing record
        await Supabase.instance.client
            .from('BudgetCaution')
            .update({
              'dismissed': true,
              'dismissedAt': DateTime.now().toIso8601String(),
            })
            .eq('budgetId', budgetId);
        print('$_tag dismissCautionAlert: Record updated for $budgetId');
      } else {
        print('$_tag dismissCautionAlert: Creating new record for $budgetId');
        // Create new record
        await Supabase.instance.client.from('BudgetCaution').insert({
          'budgetId': budgetId,
          'userId': userId,
          'dismissed': true,
          'dismissedAt': DateTime.now().toIso8601String(),
        });
        print('$_tag dismissCautionAlert: New record created for $budgetId');
      }

      // Also set isAlert flag to false (yellow icon dismissed)
      await setIsAlert(budgetId, false);
    } catch (e) {
      print('$_tag Error dismissing caution alert for $budgetId: $e');
    }
  }

  /// Reset the dismissal status (used when cycle renews)
  Future<void> _resetCautionDismissal(String budgetId) async {
    try {
      await Supabase.instance.client
          .from('BudgetCaution')
          .update({'dismissed': false, 'dismissedAt': null})
          .eq('budgetId', budgetId);
    } catch (e) {
      print('$_tag Error resetting caution dismissal: $e');
    }
  }

  /// Reset isAlert and isWarning flags when budget cycle renews
  Future<void> _resetBudgetAlertFlags(String budgetId) async {
    try {
      print('$_tag Resetting isAlert and isWarning for budget $budgetId');
      await Supabase.instance.client
          .from('Budget')
          .update({'isAlert': false, 'isWarning': false})
          .eq('budgetId', budgetId);
      print('$_tag Successfully reset alert flags for $budgetId');
    } catch (e) {
      print('$_tag Error resetting alert flags for $budgetId: $e');
    }
  }

  /// Set isAlert flag (yellow icon) for caution status (70-99% spent)
  Future<void> setIsAlert(String budgetId, bool value) async {
    try {
      print('$_tag Setting isAlert=$value for budget $budgetId (yellow icon)');
      await Supabase.instance.client
          .from('Budget')
          .update({'isAlert': value})
          .eq('budgetId', budgetId);
      print('$_tag Successfully set isAlert for $budgetId');
    } catch (e) {
      print('$_tag Error setting isAlert for $budgetId: $e');
    }
  }

  /// Set isWarning flag (red icon) for exceed status (100%+ spent)
  Future<void> setIsWarning(String budgetId, bool value) async {
    try {
      print('$_tag Setting isWarning=$value for budget $budgetId (red icon)');
      await Supabase.instance.client
          .from('Budget')
          .update({'isWarning': value})
          .eq('budgetId', budgetId);
      print('$_tag Successfully set isWarning for $budgetId');
    } catch (e) {
      print('$_tag Error setting isWarning for $budgetId: $e');
    }
  }

  /// Detect and set flags based on budget usage (call periodically to keep flags in sync)
  Future<void> updateAlertFlags(String budgetId, double usagePercentage) async {
    try {
      // Get the budget to see current flag states
      final budget = await Supabase.instance.client
          .from('Budget')
          .select()
          .eq('budgetId', budgetId)
          .single();

      bool shouldSetAlert = false;
      bool shouldSetWarning = false;

      if (usagePercentage >= 100) {
        // Exceed: set warning flag
        shouldSetWarning = true;
        shouldSetAlert = false;
      } else if (usagePercentage >= 70) {
        // Caution: set alert flag
        shouldSetAlert = true;
        shouldSetWarning = false;
      } else {
        // Normal: clear both flags
        shouldSetAlert = false;
        shouldSetWarning = false;
      }

      // Update if needed
      final currentAlert = budget['isAlert'] ?? false;
      final currentWarning = budget['isWarning'] ?? false;

      if (currentAlert != shouldSetAlert ||
          currentWarning != shouldSetWarning) {
        await Supabase.instance.client
            .from('Budget')
            .update({'isAlert': shouldSetAlert, 'isWarning': shouldSetWarning})
            .eq('budgetId', budgetId);

        print(
          '$_tag Updated flags for $budgetId: isAlert=$shouldSetAlert, isWarning=$shouldSetWarning (usage: ${usagePercentage.toStringAsFixed(1)}%)',
        );
      }

      // Reset dismissals when transitioning between states
      // If usage < 70%, reset caution dismissal (so alert can reappear if budget goes back to 70%+)
      if (usagePercentage < 70) {
        print('$_tag Budget $budgetId below 70%, resetting caution dismissal');
        await _resetCautionDismissal(budgetId);
      }

      // If usage drops from warning (>100%) to non-warning (<=100%), reset exceed dismissal
      // This ensures the warning will reappear when budget goes back above 100%
      if (usagePercentage <= 100 && currentWarning) {
        print(
          '$_tag Budget $budgetId dropped from warning to non-warning, resetting exceed dismissal so warning can reappear',
        );
        await _resetExceedDismissal(budgetId);
      }
    } catch (e) {
      print('$_tag Error updating alert flags for $budgetId: $e');
    }
  }

  /// Check if the budget cycle has renewed since the dismissal time
  bool _hasCycleRenewed(String dismissedAtStr, String cycleType) {
    try {
      final dismissedAt = DateTime.parse(dismissedAtStr);
      final now = DateTime.now();

      switch (cycleType) {
        case 'day':
          // Renews daily
          return dismissedAt.day != now.day ||
              dismissedAt.month != now.month ||
              dismissedAt.year != now.year;

        case 'week':
          // Renews weekly (Monday)
          final dismissedWeekStart = dismissedAt.subtract(
            Duration(days: dismissedAt.weekday - 1),
          );
          final nowWeekStart = now.subtract(Duration(days: now.weekday - 1));
          return dismissedWeekStart.difference(nowWeekStart).inDays >= 7;

        case 'month':
          // Renews monthly
          return dismissedAt.month != now.month || dismissedAt.year != now.year;

        case 'year':
          // Renews yearly
          return dismissedAt.year != now.year;

        default:
          // Assume monthly
          return dismissedAt.month != now.month || dismissedAt.year != now.year;
      }
    } catch (e) {
      print('$_tag Error checking cycle renewal: $e');
      return false;
    }
  }

  /// Check if any budget has caution status for display on bottom nav
  Future<bool> hasAnyCautionAlert(
    String userId,
    Map<String, double> budgetUsageMap,
  ) async {
    try {
      print('$_tag === hasAnyCautionAlert START ===');
      print('$_tag Checking ${budgetUsageMap.length} budgets for user $userId');

      int checkedCount = 0;
      int dismissedCount = 0;
      int activeCautionCount = 0;

      for (var entry in budgetUsageMap.entries) {
        final budgetId = entry.key;
        final usagePercentage = entry.value;

        checkedCount++;
        print(
          '$_tag [$checkedCount] Budget $budgetId usage = ${usagePercentage.toStringAsFixed(1)}%',
        );

        if (usagePercentage >= 70) {
          print('$_tag   → Usage >= 70%, checking dismissal status...');

          final budget = await Supabase.instance.client
              .from('Budget')
              .select()
              .eq('budgetId', budgetId)
              .single();

          final cycleType = (budget['cycleType'] ?? 'month').toLowerCase();
          print('$_tag   → Cycle type: $cycleType');

          final isDismissed = await isCautionDismissed(budgetId, cycleType);
          print('$_tag   → isDismissed = $isDismissed');

          if (!isDismissed) {
            activeCautionCount++;
            print('$_tag   → Budget has ACTIVE caution alert!');
            print('$_tag === hasAnyCautionAlert END (FOUND ACTIVE) ===');
            return true;
          } else {
            dismissedCount++;
            print('$_tag   → Budget is dismissed, continuing');
          }
        } else {
          print('$_tag   → Usage < 70%, skipping');
        }
      }

      print(
        '$_tag Summary: Checked=$checkedCount, ActiveCautions=$activeCautionCount, Dismissed=$dismissedCount',
      );
      print('$_tag === hasAnyCautionAlert END (NO ACTIVE) ===');
      return false;
    } catch (e) {
      print('$_tag Error checking caution alerts: $e');
      return false;
    }
  }

  /// Check if an exceed alert is dismissed
  /// Returns true if the alert is dismissed and budget is still exceeding
  Future<bool> isExceedDismissed(String budgetId) async {
    try {
      final response = await Supabase.instance.client
          .from('BudgetCaution')
          .select()
          .eq('budgetId', budgetId)
          .eq('exceedDismissed', true)
          .maybeSingle();

      if (response == null) {
        print('$_tag Budget $budgetId: No exceed dismissal record found');
        return false;
      }

      print(
        '$_tag Budget $budgetId: Exceed dismissal found - checking cycle renewal',
      );

      // Get budget to check cycle type
      final budget = await Supabase.instance.client
          .from('Budget')
          .select()
          .eq('budgetId', budgetId)
          .single();

      final cycleType = (budget['cycleType'] ?? 'month').toLowerCase();

      // Check if the budget cycle has renewed since exceeding
      final exceedDismissedAtStr = response['exceedDismissedAt'];
      if (exceedDismissedAtStr != null) {
        final hasRenewed = _hasCycleRenewed(exceedDismissedAtStr, cycleType);
        print(
          '$_tag Budget $budgetId: Cycle renewed? $hasRenewed (cycleType: $cycleType)',
        );

        if (hasRenewed) {
          // Reset the exceed dismissal if cycle has renewed
          print(
            '$_tag Budget $budgetId: Resetting exceed dismissal due to cycle renewal',
          );
          await _resetExceedDismissal(budgetId);
          // Reset isAlert and isWarning when cycle renews
          await _resetBudgetAlertFlags(budgetId);
          return false;
        }
      }

      print('$_tag Budget $budgetId: Exceed dismissal still active');
      return true;
    } catch (e) {
      print('$_tag Error checking exceed dismissal for $budgetId: $e');
      return false;
    }
  }

  /// Get all budgets exceeding limit (>100% spent, not dismissed)
  Future<List<Map<String, dynamic>>> getExceedBudgets(
    String userId,
    Map<String, double> budgetUsageMap,
  ) async {
    try {
      final List<Map<String, dynamic>> exceedBudgets = [];

      for (var entry in budgetUsageMap.entries) {
        final budgetId = entry.key;
        final usagePercentage = entry.value;

        print(
          '$_tag getExceedBudgets: Checking budget $budgetId with usage $usagePercentage%',
        );

        // Check if usage is > 100% and not dismissed
        if (usagePercentage > 100) {
          final isDismissed = await isExceedDismissed(budgetId);

          print(
            '$_tag getExceedBudgets: Budget $budgetId > 100%, isDismissed = $isDismissed',
          );

          if (!isDismissed) {
            final budget = await Supabase.instance.client
                .from('Budget')
                .select()
                .eq('budgetId', budgetId)
                .single();

            print('$_tag getExceedBudgets: Adding $budgetId to exceed list');
            exceedBudgets.add({
              'budgetId': budgetId,
              'usagePercentage': usagePercentage,
              'budget': budget,
            });
          }
        }
      }

      print(
        '$_tag getExceedBudgets: Total exceed budgets = ${exceedBudgets.length}',
      );
      return exceedBudgets;
    } catch (e) {
      print('$_tag Error getting exceed budgets: $e');
      return [];
    }
  }

  /// Dismiss an exceed alert for a specific budget
  Future<void> dismissExceedAlert(String budgetId, String userId) async {
    try {
      print('$_tag dismissExceedAlert: Dismissing budget $budgetId');

      // Check if record exists
      final existing = await Supabase.instance.client
          .from('BudgetCaution')
          .select()
          .eq('budgetId', budgetId)
          .maybeSingle();

      if (existing != null) {
        print(
          '$_tag dismissExceedAlert: Updating existing record for $budgetId',
        );
        // Update existing record
        await Supabase.instance.client
            .from('BudgetCaution')
            .update({
              'exceedDismissed': true,
              'exceedDismissedAt': DateTime.now().toIso8601String(),
            })
            .eq('budgetId', budgetId);
        print('$_tag dismissExceedAlert: Record updated for $budgetId');
      } else {
        print('$_tag dismissExceedAlert: Creating new record for $budgetId');
        // Create new record
        await Supabase.instance.client.from('BudgetCaution').insert({
          'budgetId': budgetId,
          'userId': userId,
          'exceedDismissed': true,
          'exceedDismissedAt': DateTime.now().toIso8601String(),
        });
        print('$_tag dismissExceedAlert: New record created for $budgetId');
      }

      // Also set isWarning flag to false (red icon dismissed)
      await setIsWarning(budgetId, false);
    } catch (e) {
      print('$_tag Error dismissing exceed alert for $budgetId: $e');
    }
  }

  /// Reset exceed dismissal (when budget goes below 100%)
  Future<void> _resetExceedDismissal(String budgetId) async {
    try {
      await Supabase.instance.client
          .from('BudgetCaution')
          .update({'exceedDismissed': false, 'exceedDismissedAt': null})
          .eq('budgetId', budgetId);
    } catch (e) {
      print('$_tag Error resetting exceed dismissal: $e');
    }
  }

  /// Check if any budget has exceed status for display on bottom nav
  Future<bool> hasAnyExceedAlert(
    String userId,
    Map<String, double> budgetUsageMap,
  ) async {
    try {
      print('$_tag === hasAnyExceedAlert START ===');
      print('$_tag Checking ${budgetUsageMap.length} budgets for exceed...');

      for (var entry in budgetUsageMap.entries) {
        final budgetId = entry.key;
        final usagePercentage = entry.value;

        print(
          '$_tag Checking budget $budgetId usage = ${usagePercentage.toStringAsFixed(1)}%',
        );

        if (usagePercentage > 100) {
          print('$_tag   → Usage > 100%, checking dismissal status...');
          final isDismissed = await isExceedDismissed(budgetId);
          print('$_tag   → isDismissed = $isDismissed');

          if (!isDismissed) {
            print('$_tag   → Budget has ACTIVE exceed alert!');
            print('$_tag === hasAnyExceedAlert END (FOUND ACTIVE) ===');
            return true;
          } else {
            // Check if budget is still exceeding, if not, reset
            if (usagePercentage <= 100) {
              print('$_tag   → Budget at or below 100%, resetting dismissal');
              await _resetExceedDismissal(budgetId);
            }
          }
        }
      }

      print('$_tag === hasAnyExceedAlert END (NO ACTIVE) ===');
      return false;
    } catch (e) {
      print('$_tag Error checking exceed alerts: $e');
      return false;
    }
  }

  /// Check if any budget has isAlert or isWarning flag set to true
  /// Returns true if at least one budget has an active alert or warning
  Future<bool> hasAnyBudgetAlert(String userId) async {
    try {
      print('$_tag === hasAnyBudgetAlert START ===');

      final budgets = await Supabase.instance.client
          .from('Budget')
          .select()
          .eq('userId', userId);

      print('$_tag Checking ${budgets.length} budgets for alerts');

      for (var budget in budgets) {
        final isAlert = budget['isAlert'] ?? false;
        final isWarning = budget['isWarning'] ?? false;
        final budgetId = budget['budgetId'];

        if (isAlert || isWarning) {
          print(
            '$_tag Budget $budgetId has active alert - isAlert: $isAlert, isWarning: $isWarning',
          );
          print('$_tag === hasAnyBudgetAlert END (FOUND) ===');
          return true;
        }
      }

      print('$_tag === hasAnyBudgetAlert END (NOT FOUND) ===');
      return false;
    } catch (e) {
      print('$_tag Error checking budget alerts: $e');
      return false;
    }
  }
}
