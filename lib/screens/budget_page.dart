import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/budget_forecast_service.dart';
import '../services/budget_alert_service.dart';
import '../services/alert_status_service.dart';
import '../services/budget_caution_service.dart';
import 'home_screen.dart';
import 'account_page.dart';
import 'savings_page.dart';
import 'settings_screen.dart';
import 'create_budget_page.dart';
import 'edit_budget_page.dart';

class BudgetPage extends StatefulWidget {
  final String userId;

  const BudgetPage({super.key, required this.userId});

  @override
  State<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends State<BudgetPage> {
  List<Map<String, dynamic>> _budgets = [];
  bool _isLoading = true;
  bool _hasBudgetCaution = false;

  // Track the last checked cycle date to detect resets
  DateTime? _lastCycleCheckDate;

  // Track which budgets have shown dismissed alert pop-up to avoid showing on every rebuild
  final Set<String> _shownDismissedAlertPopups = {};

  @override
  void initState() {
    super.initState();
    _initializeAndLoadBudgets();
    _setupAlertListeners();
  }

  @override
  void dispose() {
    // Remove listeners when page is disposed
    AlertStatusService().hasCautionAlertNotifier.removeListener(
      _onAlertStatusChanged,
    );
    AlertStatusService().hasHighRiskAlertNotifier.removeListener(
      _onAlertStatusChanged,
    );
    super.dispose();
  }

  /// Setup real-time listeners for alert status changes
  void _setupAlertListeners() {
    AlertStatusService().hasCautionAlertNotifier.addListener(
      _onAlertStatusChanged,
    );
    AlertStatusService().hasHighRiskAlertNotifier.addListener(
      _onAlertStatusChanged,
    );
  }

  /// Refresh budgets when alert status changes (triggered by transaction delete/refund)
  void _onAlertStatusChanged() {
    print('[BudgetPage] Alert status changed, refreshing budgets...');
    if (mounted) {
      _initializeAndLoadBudgets();
    }
  }

  /// Initialize budgets and alerts with single state update
  Future<void> _initializeAndLoadBudgets() async {
    try {
      // Clear dismissed alert pop-up tracking on refresh
      _shownDismissedAlertPopups.clear();

      // Fetch budgets from database
      final response = await Supabase.instance.client
          .from('Budget')
          .select()
          .eq('userId', widget.userId)
          .order('budgetId', ascending: false);

      if (mounted) {
        setState(() {
          _budgets = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });

        // Show alerts AFTER UI is built
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _checkAndDisplayAlertsFromFlags();
          }
        });
      }
    } catch (e) {
      print('Error initializing budgets: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading budgets: $e')));
      }
    }
  }

  /// Check if any budget cycles have reset (new day/week/month) and clear dismissals if so
  Future<void> _clearDismissalsIfCycleReset() async {
    try {
      final now = DateTime.now();

      // Check if we need to clear dismissals based on cycle changes
      if (_lastCycleCheckDate == null) {
        _lastCycleCheckDate = now;
        return; // First check, no dismissals to clear
      }

      final cautionService = BudgetCautionService();
      bool shouldRefreshAlerts = false;

      // Check if any budgets have cycle types and if their cycles have reset
      for (var budget in _budgets) {
        final budgetId = budget['budgetId'];
        final cycleType = (budget['cycleType'] ?? 'month').toLowerCase();
        bool cycleHasReset = false;

        switch (cycleType) {
          case 'day':
            // Check if date changed
            cycleHasReset =
                _lastCycleCheckDate!.day != now.day ||
                _lastCycleCheckDate!.month != now.month ||
                _lastCycleCheckDate!.year != now.year;
            break;
          case 'week':
            // Check if week changed (Monday-based)
            final lastWeekStart = _lastCycleCheckDate!.subtract(
              Duration(days: _lastCycleCheckDate!.weekday - 1),
            );
            final currentWeekStart = now.subtract(
              Duration(days: now.weekday - 1),
            );
            cycleHasReset =
                lastWeekStart.day != currentWeekStart.day ||
                lastWeekStart.month != currentWeekStart.month ||
                lastWeekStart.year != currentWeekStart.year;
            break;
          case 'month':
            // Check if month changed
            cycleHasReset =
                _lastCycleCheckDate!.month != now.month ||
                _lastCycleCheckDate!.year != now.year;
            break;
          case 'year':
            // Check if year changed
            cycleHasReset = _lastCycleCheckDate!.year != now.year;
            break;
        }

        // If cycle has reset, clear both dismissals for this budget
        if (cycleHasReset) {
          print('[BudgetPage] Cycle reset detected for $budgetId ($cycleType)');
          print('[BudgetPage] Clearing dismissals for budget: $budgetId');
          await cautionService.clearDismissal(budgetId, widget.userId);
          shouldRefreshAlerts = true;
        }
      }

      // Update the last check date
      _lastCycleCheckDate = now;

      // Refresh alerts if cycles reset
      if (shouldRefreshAlerts) {
        print('[BudgetPage] Cycle resets detected, refreshing alerts...');
        // Clear dismissed alert pop-up tracking so they can show again after cycle reset
        _shownDismissedAlertPopups.clear();
        // Refresh the dismissal lists by calling check again
        // This will be called anyway, so just log it
      }
    } catch (e) {
      print('Error checking cycle resets: $e');
    }
  }

  /// Clear ALL dismissals for this user - useful for testing or resetting alerts
  /// This clears both caution and exceed dismissals for all budgets
  Future<void> _clearAllDismissals() async {
    try {
      print('[BudgetPage] === CLEARING ALL DISMISSALS ===');
      final cautionService = BudgetCautionService();

      // Get all dismissed records for this user
      final allBudgets = await Supabase.instance.client
          .from('Budget')
          .select('budgetId')
          .eq('userId', widget.userId);

      // Clear dismissals for each budget
      for (var budget in allBudgets) {
        final budgetId = budget['budgetId'];
        await cautionService.clearDismissal(budgetId, widget.userId);
        print('[BudgetPage] Cleared dismissals for budget: $budgetId');
      }

      print('[BudgetPage] All dismissals cleared!');

      // Refresh alerts to show all outstanding ones
      if (mounted) {
        await _checkAndDisplayAlertsFromFlags();
      }
    } catch (e) {
      print('Error clearing dismissals: $e');
    }
  }

  /// Clear mismatched dismissals when budget state changes to show fresh alerts
  /// Logic:
  /// - If CURRENT is RED (100%+): clear old YELLOW dismissal so fresh RED shows
  /// - If CURRENT is YELLOW (70-99%): clear old RED dismissal so fresh YELLOW shows
  /// - If CURRENT is SAFE (<70%): clear both dismissals for fresh alerts next cycle
  /// This ensures the alert matches the CURRENT bottom bar status
  Future<void> _clearMismatchedStateDismissals() async {
    try {
      final supabase = Supabase.instance.client;

      for (var budget in _budgets) {
        final budgetId = budget['budgetId'];
        final usagePercentage = await _calculateBudgetUsage(budget);

        // Get current dismissal record
        final record = await supabase
            .from('BudgetCaution')
            .select()
            .eq('budgetId', budgetId)
            .eq('userId', widget.userId)
            .maybeSingle();

        if (record == null) continue;

        if (usagePercentage >= 100) {
          // 🔴 CURRENT STATE: RED (100%+)
          // Clear old YELLOW dismissal so fresh RED alert shows
          if (record['dismissed'] == true) {
            print(
              '[BudgetPage] Clearing YELLOW dismissal for $budgetId (now RED: $usagePercentage%)',
            );
            await supabase
                .from('BudgetCaution')
                .update({'dismissed': false})
                .eq('budgetId', budgetId)
                .eq('userId', widget.userId);
          }
        } else if (usagePercentage >= 70) {
          // 🟠 CURRENT STATE: YELLOW (70-99%)
          // Clear old RED dismissal so fresh YELLOW alert shows
          if (record['exceedDismissed'] == true) {
            print(
              '[BudgetPage] Clearing RED dismissal for $budgetId (now YELLOW: $usagePercentage%)',
            );
            await supabase
                .from('BudgetCaution')
                .update({'exceedDismissed': false})
                .eq('budgetId', budgetId)
                .eq('userId', widget.userId);
          }
        } else {
          // ✅ CURRENT STATE: SAFE (<70%)
          // Clear ALL dismissals for fresh alerts next cycle
          if (record['dismissed'] == true ||
              record['exceedDismissed'] == true) {
            print(
              '[BudgetPage] Clearing all dismissals for $budgetId (now SAFE: $usagePercentage%)',
            );
            await supabase
                .from('BudgetCaution')
                .update({'dismissed': false, 'exceedDismissed': false})
                .eq('budgetId', budgetId)
                .eq('userId', widget.userId);
          }
        }
      }

      print('[BudgetPage] State-matched dismissals cleared');
    } catch (e) {
      print('[BudgetPage] Error clearing mismatched state dismissals: $e');
    }
  }

  /// Check and display alerts based on ACTUAL CURRENT USAGE PERCENTAGE
  /// Respects dismissal state from BudgetCaution table - won't show dismissed alerts
  Future<void> _checkAndDisplayAlertsFromFlags() async {
    try {
      if (_budgets.isEmpty) return;

      // First check if any cycles have reset and clear dismissals
      await _clearDismissalsIfCycleReset();

      // ✅ NEW: Clear old dismissals when budget state changes (RED → YELLOW or YELLOW → RED)
      // This allows fresh alerts for new states
      await _clearMismatchedStateDismissals();

      final cautionService = BudgetCautionService();
      final List<Map<String, dynamic>> cautionBudgets = [];
      final List<Map<String, dynamic>> exceedBudgets = [];

      // Get dismissed budgets to skip them
      // ⚠️ IMPORTANT: Caution and Exceed dismissals are INDEPENDENT
      // - User can dismiss caution (70-99%), then budget goes to 100%+ → exceed alert shows anyway
      // - User can dismiss exceed (100%+), then budget goes down to 70% → caution alert shows
      // This allows re-alerting when budget STATUS CHANGES
      final dismissedCautionBudgets = await cautionService
          .getDismissedCautionBudgets(widget.userId);
      final dismissedExceedBudgets = await cautionService
          .getDismissedExceedBudgets(widget.userId);

      // Recalculate all budgets and check CURRENT usage percentage thresholds
      for (var budget in _budgets) {
        final budgetId = budget['budgetId'];
        final displayName = await _getBudgetDisplayName(budget);
        final usagePercentage = await _calculateBudgetUsage(budget);

        // ✅ Update database flags based on CURRENT usage
        // This ensures database reflects actual status after transactions/refunds
        await _updateBudgetAlertFlags(budgetId, usagePercentage);

        // Show alert based on ACTUAL CURRENT usage, respecting dismissals
        // When budget crosses thresholds (e.g., 99% → 100%), the NEW alert type shows even if old one was dismissed
        if (usagePercentage >= 100) {
          // 🔴 RED EXCEED ALERT (100%+) - only skip if THIS specific dismissal is set
          if (!dismissedExceedBudgets.contains(budgetId)) {
            exceedBudgets.add({
              'budget': budget,
              'displayName': displayName,
              'budgetId': budgetId,
              'usagePercentage': usagePercentage,
            });
          }
        } else if (usagePercentage >= 70) {
          // 🟠 ORANGE CAUTION ALERT (70-99%) - only skip if THIS specific dismissal is set
          if (!dismissedCautionBudgets.contains(budgetId)) {
            cautionBudgets.add({
              'budget': budget,
              'displayName': displayName,
              'budgetId': budgetId,
              'usagePercentage': usagePercentage,
            });
          }
        }
      }

      // Combine all alerts (exceed = RED, caution = YELLOW) into one list
      // RED alerts have higher priority and display first
      final allAlerts = [
        ...exceedBudgets.map(
          (b) => {
            ...b,
            'alertType': 'exceed',
            'priority': 1, // Higher priority
          },
        ),
        ...cautionBudgets.map(
          (b) => {
            ...b,
            'alertType': 'caution',
            'priority': 2, // Lower priority
          },
        ),
      ];

      // Show unified alert dialog if there are any alerts (RED has priority)
      if (allAlerts.isNotEmpty && mounted) {
        print(
          '[BudgetPage] Showing unified alert for ${allAlerts.length} budgets (${exceedBudgets.length} exceed, ${cautionBudgets.length} caution)',
        );
        _showUnifiedAlertDialog(allAlerts);
      }

      // ✅ UPDATE ALERT STATUS SERVICE FOR BOTTOM NAV BAR
      // This ensures the bottom bar icon reflects actual current state
      final hasExceedAlert = exceedBudgets.isNotEmpty;
      final hasCautionAlert = cautionBudgets.isNotEmpty;
      print(
        '[BudgetPage] Updating AlertStatusService - Caution: $hasCautionAlert, Exceed: $hasExceedAlert',
      );
      AlertStatusService().refreshAlertStatus(
        hasCaution: hasCautionAlert,
        hasHighRisk: hasExceedAlert,
      );
    } catch (e) {
      print('Error checking and displaying alerts: $e');
    }
  }

  /// Fetch budgets when user manually refreshes from edit/create
  Future<void> _fetchBudgets() async {
    try {
      final response = await Supabase.instance.client
          .from('Budget')
          .select()
          .eq('userId', widget.userId)
          .order('budgetId', ascending: false);

      if (mounted) {
        setState(() {
          _budgets = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (e) {
      print('Error fetching budgets: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading budgets: $e')));
      }
    }
  }

  Future<double> _calculateBudgetUsage(Map<String, dynamic> budget) async {
    try {
      final budgetType = budget['type'] ?? '';
      final budgetAmount = (budget['amount'] ?? 0).toDouble();
      final cycleType = (budget['cycleType'] ?? 'month').toLowerCase();

      if (budgetAmount <= 0) return 0;

      // Calculate date range based on cycle type
      final now = DateTime.now();
      final DateTime startDate;

      switch (cycleType) {
        case 'day':
          startDate = DateTime(now.year, now.month, now.day);
          break;
        case 'week':
          startDate = now.subtract(Duration(days: now.weekday - 1));
          break;
        case 'month':
          startDate = DateTime(now.year, now.month, 1);
          break;
        case 'year':
          startDate = DateTime(now.year, 1, 1);
          break;
        default:
          startDate = DateTime(now.year, now.month, 1);
      }

      // Fetch transactions based on budget type
      List<dynamic> transactions = [];

      if (budgetType == 'account') {
        final accountId = budget['accountId'];
        if (accountId != null) {
          transactions = await Supabase.instance.client
              .from('Transaction')
              .select()
              .eq('accountId', accountId)
              .eq('type', 'expense') // Only expenses, exclude income/transfers
              .gte('date', startDate.toIso8601String());
        }
      } else if (budgetType == 'category') {
        final categoryId = budget['categoryId'];
        if (categoryId != null) {
          transactions = await Supabase.instance.client
              .from('Transaction')
              .select()
              .eq('categoryId', categoryId)
              .eq('type', 'expense')
              .gte('date', startDate.toIso8601String());
        }
      } else if (budgetType == 'ledger') {
        final ledgerId = budget['ledgerId'];
        if (ledgerId != null) {
          transactions = await Supabase.instance.client
              .from('Transaction')
              .select()
              .eq('ledgerId', ledgerId)
              .eq('type', 'expense')
              .gte('date', startDate.toIso8601String());
        }
      }

      // Sum up NON-REFUNDED transaction amounts only
      // ✅ Skip refunded transactions entirely, don't subtract them
      double totalSpent = 0;
      for (var transaction in transactions) {
        // Skip refunded transactions (they should not count toward budget)
        if (transaction['refund'] == true) {
          continue;
        }
        totalSpent += ((transaction['amount'] ?? 0) as num).toDouble();
      }

      // Ensure total spent doesn't go below 0
      totalSpent = totalSpent < 0 ? 0 : totalSpent;

      return (totalSpent / budgetAmount) * 100;
    } catch (e) {
      print('Error calculating budget usage: $e');
      return 0;
    }
  }

  /// Update the database with correct isAlert and isWarning flags based on current usage
  /// This ensures the database reflects the actual budget status after transactions/refunds
  Future<void> _updateBudgetAlertFlags(
    String budgetId,
    double usagePercentage,
  ) async {
    try {
      // Calculate new status based on usage percentage
      final bool newIsWarning = usagePercentage >= 100; // 🔴 RED: exceeded 100%
      final bool newIsAlert =
          usagePercentage >= 70 &&
          usagePercentage < 100; // 🟠 YELLOW: caution 70-99%

      print(
        '[BudgetPage] Updating flags for $budgetId: usage=$usagePercentage%, isWarning=$newIsWarning, isAlert=$newIsAlert',
      );

      // Update the Budget record in database
      await Supabase.instance.client
          .from('Budget')
          .update({'isWarning': newIsWarning, 'isAlert': newIsAlert})
          .eq('budgetId', budgetId);

      print('[BudgetPage] Budget alert flags updated successfully');
    } catch (e) {
      print('Error updating budget alert flags: $e');
    }
  }

  Future<Map<String, dynamic>> _getBudgetItemDetails(
    Map<String, dynamic> budget,
  ) async {
    try {
      final budgetType = budget['type'] ?? '';
      String? name;
      String? iconUrl;

      if (budgetType == 'account') {
        final accountId = budget['accountId'];
        if (accountId != null) {
          final result = await Supabase.instance.client
              .from('Account')
              .select('accountName, iconImage')
              .eq('accountId', accountId)
              .single();
          name = result['accountName'];
          iconUrl = result['iconImage'];
        }
      } else if (budgetType == 'category') {
        final categoryId = budget['categoryId'];
        if (categoryId != null) {
          final result = await Supabase.instance.client
              .from('Category')
              .select('name, icon')
              .eq('categoryId', categoryId)
              .single();
          name = result['name'];
          iconUrl = result['icon'];
        }
      } else if (budgetType == 'ledger') {
        final ledgerId = budget['ledgerId'];
        if (ledgerId != null) {
          final result = await Supabase.instance.client
              .from('Ledger')
              .select('name')
              .eq('ledgerId', ledgerId)
              .single();
          name = result['name'];
        }
      }

      return {'name': name ?? 'Unnamed', 'iconUrl': iconUrl};
    } catch (e) {
      print('Error fetching item details: $e');
      return {'name': 'Unnamed', 'iconUrl': null};
    }
  }

  String _formatCurrency(double value) {
    return 'RM${value.toStringAsFixed(2)}';
  }

  Widget _buildSuggestion(String text, bool isAlert) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          height: 1.4,
          color: isAlert ? Colors.red.shade600 : Colors.orange.shade600,
        ),
      ),
    );
  }

  Future<void> _checkAndShowHighRiskAlert() async {
    try {
      if (_budgets.isEmpty) return;

      print('[BudgetPage] Checking for high-risk alerts...');
      final forecastService = BudgetForecastService();
      final List<Map<String, dynamic>> highRiskBudgets = [];

      // Check each budget for high risk
      for (var budget in _budgets) {
        // Skip if alert already dismissed (isAlert = false)
        if (budget['isAlert'] == false) {
          print(
            '[BudgetPage] High-risk already dismissed for: ${budget['budgetId']}',
          );
          continue;
        }

        final isHighRisk = await forecastService.checkHighRiskAlert(
          widget.userId,
          budget['budgetId'],
          (budget['amount'] ?? 0).toDouble(),
          budget['accountId'],
          budget['categoryId'],
          budget['ledgerId'],
        );

        if (isHighRisk) {
          print('[BudgetPage] High-risk found: ${budget['budgetId']}');
          highRiskBudgets.add(budget);
        }
      }

      // Show alert dialog with all high-risk budgets if any exist
      if (highRiskBudgets.isNotEmpty && mounted) {
        print(
          '[BudgetPage] Showing high-risk alert for ${highRiskBudgets.length} budget(s)',
        );
        _showHighRiskAlertDialog(highRiskBudgets);
      }
    } catch (e) {
      print('Error checking high-risk alerts: $e');
    }
  }

  void _showHighRiskAlertDialog(List<Map<String, dynamic>> highRiskBudgets) {
    bool checkboxValue = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Warning Icon
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.warning_rounded,
                          color: Colors.red.shade700,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Title
                      Text(
                        highRiskBudgets.length > 1
                            ? 'Multiple High-Risk Alerts'
                            : 'Budget Exceed Risk is High',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),

                      // Message
                      Text(
                        highRiskBudgets.length > 1
                            ? 'Current financial projections indicate a strong likelihood of budget exceedance for the following budgets without immediate intervention.'
                            : 'Current financial projections indicate a strong likelihood of budget exceedance without immediate intervention.',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),

                      // Budget List (if multiple)
                      if (highRiskBudgets.length > 1)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.red.shade200,
                              width: 1,
                            ),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: List.generate(highRiskBudgets.length, (
                              index,
                            ) {
                              final budget = highRiskBudgets[index];
                              return Padding(
                                padding: EdgeInsets.only(
                                  bottom: index < highRiskBudgets.length - 1
                                      ? 8
                                      : 0,
                                ),
                                child: Text(
                                  '${budget['budgetName'] ?? 'Budget'}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }),
                          ),
                        ),
                      const SizedBox(height: 20),

                      // Checkbox
                      Row(
                        children: [
                          Checkbox(
                            value: checkboxValue,
                            onChanged: (newValue) {
                              setDialogState(() {
                                checkboxValue = newValue ?? false;
                              });
                            },
                            activeColor: Colors.red.shade700,
                          ),
                          const Expanded(
                            child: Text(
                              'I understand, don\'t show this again',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Button Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey[300],
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'OK',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: checkboxValue
                                  ? () {
                                      // Dismiss all high-risk budgets
                                      final budgetIds = highRiskBudgets
                                          .map((b) => b['budgetId'] as String)
                                          .toList();
                                      _dismissHighRiskAlert(budgetIds);
                                      Navigator.pop(context);
                                    }
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade700,
                                disabledBackgroundColor: Colors.grey[400],
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Confirm',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _dismissHighRiskAlert(List<String> budgetIds) async {
    try {
      print(
        '[BudgetPage] Dismissing high-risk alert for ${budgetIds.length} budgets',
      );

      // Mark all budgets as alert dismissed
      for (var budgetId in budgetIds) {
        await Supabase.instance.client
            .from('Budget')
            .update({'isAlert': false})
            .eq('budgetId', budgetId);
        print('[BudgetPage] High-risk dismissed for budget: $budgetId');
      }

      print('[BudgetPage] All high-risk alerts dismissed');

      // ✅ Recalculate alert status based on remaining undismissed alerts
      await _recalculateAlertStatus();
    } catch (e) {
      print('Error dismissing high-risk alert: $e');
    }
  }

  /// Recalculate alert status based on CURRENT dismissal state
  /// Only show icon if there are ANY undismissed alerts of that type
  /// ✅ Uses state-aware logic: budget can only be in ONE state at a time
  Future<void> _recalculateAlertStatus() async {
    try {
      final cautionService = BudgetCautionService();

      // Get current dismissed state
      final dismissedCautionBudgets = await cautionService
          .getDismissedCautionBudgets(widget.userId);
      final dismissedExceedBudgets = await cautionService
          .getDismissedExceedBudgets(widget.userId);

      // Check if there are ANY undismissed alerts
      bool hasUndismissedCaution = false;
      bool hasUndismissedExceed = false;

      for (var budget in _budgets) {
        final budgetId = budget['budgetId'];
        final usagePercentage = await _calculateBudgetUsage(budget);

        // 🔴 If budget is in EXCEED zone (100%+), only check exceed dismissal
        // Old caution dismissals from previous state are irrelevant
        if (usagePercentage >= 100) {
          if (!dismissedExceedBudgets.contains(budgetId)) {
            hasUndismissedExceed = true;
          }
          // Note: We DON'T check caution here even if dismissed=true
          // because budget is no longer in caution zone (70-99%)
        }
        // 🟠 If budget is in CAUTION zone (70-99%), only check caution dismissal
        // Exceed dismissals from previous state are irrelevant
        else if (usagePercentage >= 70 && usagePercentage < 100) {
          if (!dismissedCautionBudgets.contains(budgetId)) {
            hasUndismissedCaution = true;
          }
          // Note: We DON'T check exceed here even if exceedDismissed=true
          // because budget is no longer in exceed zone (100%+)
        }
        // Otherwise: budget < 70%, no alert needed
      }

      print(
        '[BudgetPage] Alert status recalculated - Exceed: $hasUndismissedExceed, Caution: $hasUndismissedCaution',
      );

      // Update AlertStatusService with correct state
      AlertStatusService().refreshAlertStatus(
        hasCaution: hasUndismissedCaution,
        hasHighRisk: hasUndismissedExceed,
      );
    } catch (e) {
      print('Error recalculating alert status: $e');
    }
  }

  Future<void> _checkAndShowCautionAlert() async {
    try {
      if (_budgets.isEmpty) return;

      final alertService = BudgetAlertService();
      final Map<String, double> budgetUsageMap = {};

      // Calculate all budget usage percentages
      for (var budget in _budgets) {
        final usagePercentage = await _calculateBudgetUsage(budget);
        budgetUsageMap[budget['budgetId']] = usagePercentage;
      }

      // Get all budgets with caution status
      final cautionBudgets = await alertService.getCautionBudgets(
        widget.userId,
        budgetUsageMap,
      );

      // Fetch display names for all caution budgets
      for (var cautionBudget in cautionBudgets) {
        final displayName = await _getBudgetDisplayName(
          cautionBudget['budget'],
        );
        cautionBudget['displayName'] = displayName;
      }

      // Show caution alert dialog with all caution budgets if any exist
      if (cautionBudgets.isNotEmpty && mounted) {
        _showCautionAlertDialog(cautionBudgets);
      }

      // Check for exceed alerts
      await _checkAndShowExceedAlert();
    } catch (e) {
      print('Error checking caution alerts: $e');
    }
  }

  Future<void> _checkAndShowExceedAlert() async {
    try {
      if (_budgets.isEmpty) return;

      final alertService = BudgetAlertService();
      final Map<String, double> budgetUsageMap = {};

      // Calculate all budget usage percentages
      for (var budget in _budgets) {
        final usagePercentage = await _calculateBudgetUsage(budget);
        budgetUsageMap[budget['budgetId']] = usagePercentage;
      }

      // Get all budgets exceeding limit
      final exceedBudgets = await alertService.getExceedBudgets(
        widget.userId,
        budgetUsageMap,
      );

      // Fetch display names for all exceed budgets
      for (var exceedBudget in exceedBudgets) {
        final displayName = await _getBudgetDisplayName(exceedBudget['budget']);
        exceedBudget['displayName'] = displayName;
      }

      // Show exceed alert dialog with all exceed budgets if any exist
      if (exceedBudgets.isNotEmpty && mounted) {
        _showExceedAlertDialog(exceedBudgets);
      }
    } catch (e) {
      print('Error checking exceed alerts: $e');
    }
  }

  Future<void> _dismissBudgetCaution(List<String> budgetIds) async {
    try {
      final cautionService = BudgetCautionService();

      print('[BudgetPage] === DISMISS CAUTION START ===');
      print(
        '[BudgetPage] Dismissing ${budgetIds.length} caution budgets: $budgetIds',
      );

      // Dismiss all selected budgets using BudgetCaution table
      for (var budgetId in budgetIds) {
        print('[BudgetPage] Dismissing caution for budget: $budgetId');
        await cautionService.dismissCautionAlert(budgetId, widget.userId);
      }

      print(
        '[BudgetPage] All caution dismissals completed, waiting 1s for database sync...',
      );

      // Wait for database to fully persist dismissal
      await Future.delayed(const Duration(seconds: 1));

      print('[BudgetPage] Caution dismissal verified');
      print('[BudgetPage] === DISMISS CAUTION END ===');

      // ✅ Recalculate alert status based on remaining undismissed alerts
      await _recalculateAlertStatus();

      // ℹ️ Do NOT pop here - unified alert dialog closes after all dismissals done
    } catch (e) {
      print('Error dismissing caution: $e');
    }
  }

  Future<void> _dismissExceedAlert(List<String> budgetIds) async {
    try {
      final cautionService = BudgetCautionService();

      print('[BudgetPage] === DISMISS EXCEED START ===');
      print(
        '[BudgetPage] Dismissing ${budgetIds.length} exceed budgets: $budgetIds',
      );

      // Dismiss all selected exceed budgets using BudgetCaution table
      for (var budgetId in budgetIds) {
        print('[BudgetPage] Dismissing exceed for budget: $budgetId');
        await cautionService.dismissExceedAlert(budgetId, widget.userId);
      }

      print(
        '[BudgetPage] All exceed dismissals completed, waiting 1s for database sync...',
      );

      // Wait for database to fully persist dismissal
      await Future.delayed(const Duration(seconds: 1));

      print('[BudgetPage] Exceed dismissal verified');
      print('[BudgetPage] === DISMISS EXCEED END ===');

      // ✅ Recalculate alert status based on remaining undismissed alerts
      await _recalculateAlertStatus();

      // ℹ️ Do NOT pop here - unified alert dialog closes after all dismissals done
    } catch (e) {
      print('Error dismissing exceed alert: $e');
    }
  }

  /// Show unified alert dialog for ALL alerts (red + yellow)
  /// RED (exceed) alerts display first with higher priority
  /// Each alert has its own checkbox for individual dismissal
  void _showUnifiedAlertDialog(List<Map<String, dynamic>> allAlerts) {
    // Track which alerts user selects to dismiss
    final Map<String, bool> dismissalMap = {};
    for (var alert in allAlerts) {
      dismissalMap[alert['budgetId']] = false;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Count selected dismissals
            int selectedCount = dismissalMap.values.where((v) => v).length;

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header Icon - Show highest priority alert type
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color:
                              allAlerts.any((a) => a['alertType'] == 'exceed')
                              ? Colors.red.shade100
                              : Colors.orange.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          allAlerts.any((a) => a['alertType'] == 'exceed')
                              ? Icons.error_rounded
                              : Icons.warning_amber_rounded,
                          color:
                              allAlerts.any((a) => a['alertType'] == 'exceed')
                              ? Colors.red.shade700
                              : Colors.orange.shade700,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Title
                      Text(
                        'Budget Alerts',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),

                      // Message
                      Text(
                        'You have ${allAlerts.length} budget alert${allAlerts.length > 1 ? 's' : ''}. Please review and select which to dismiss.',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),

                      // Alert List - RED first, then YELLOW
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.grey.shade300,
                            width: 1,
                          ),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: List.generate(allAlerts.length, (index) {
                            final alert = allAlerts[index];
                            final budgetId = alert['budgetId'];
                            final alertType = alert['alertType'];
                            final usagePercentage = alert['usagePercentage'];
                            final itemName =
                                alert['displayName'] ?? 'Unnamed Budget';
                            final isExceed = alertType == 'exceed';
                            final isSelected = dismissalMap[budgetId] ?? false;

                            return Column(
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    setDialogState(() {
                                      dismissalMap[budgetId] =
                                          !(dismissalMap[budgetId] ?? false);
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? (isExceed
                                                ? Colors.red.shade50
                                                : Colors.orange.shade50)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isSelected
                                            ? (isExceed
                                                  ? Colors.red.shade200
                                                  : Colors.orange.shade200)
                                            : Colors.transparent,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Checkbox(
                                          value: isSelected,
                                          onChanged: (newValue) {
                                            setDialogState(() {
                                              dismissalMap[budgetId] =
                                                  newValue ?? false;
                                            });
                                          },
                                          activeColor: isExceed
                                              ? Colors.red.shade700
                                              : Colors.orange.shade700,
                                        ),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                          vertical: 2,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: isExceed
                                                          ? Colors.red.shade600
                                                          : Colors
                                                                .orange
                                                                .shade600,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            4,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      isExceed
                                                          ? 'EXCEED'
                                                          : 'CAUTION',
                                                      style: const TextStyle(
                                                        fontSize: 9,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      itemName,
                                                      style: const TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors.black87,
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${usagePercentage.toStringAsFixed(1)}% of budget spent',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey.shade600,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isExceed
                                                ? Colors.red.shade200
                                                : Colors.orange.shade200,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            '${usagePercentage.toStringAsFixed(0)}%',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: isExceed
                                                  ? Colors.red.shade700
                                                  : Colors.orange.shade700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (index < allAlerts.length - 1)
                                  Divider(
                                    color: Colors.grey.shade300,
                                    height: 8,
                                  ),
                              ],
                            );
                          }),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Info text
                      Text(
                        'Select alerts to dismiss. Unselected alerts will remain visible.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),

                      // Button Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey[300],
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: selectedCount > 0
                                  ? () {
                                      // Dismiss selected alerts
                                      final exceedBudgetIds = <String>[];
                                      final cautionBudgetIds = <String>[];

                                      dismissalMap.forEach((
                                        budgetId,
                                        shouldDismiss,
                                      ) {
                                        if (shouldDismiss) {
                                          final alertType = allAlerts
                                              .firstWhere(
                                                (a) =>
                                                    a['budgetId'] == budgetId,
                                              )['alertType'];
                                          if (alertType == 'exceed') {
                                            exceedBudgetIds.add(budgetId);
                                          } else {
                                            cautionBudgetIds.add(budgetId);
                                          }
                                        }
                                      });

                                      // Dismiss separately
                                      if (exceedBudgetIds.isNotEmpty) {
                                        _dismissExceedAlert(exceedBudgetIds);
                                      }
                                      if (cautionBudgetIds.isNotEmpty) {
                                        _dismissBudgetCaution(cautionBudgetIds);
                                      }

                                      // Close dialog
                                      if (mounted) {
                                        Navigator.pop(context);
                                      }
                                    }
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade700,
                                disabledBackgroundColor: Colors.grey[400],
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                selectedCount > 0
                                    ? 'Confirm ($selectedCount)'
                                    : 'Confirm',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _checkBudgetCaution() async {
    try {
      final budgets = await Supabase.instance.client
          .from('Budget')
          .select()
          .eq('userId', widget.userId);

      final alertService = BudgetAlertService();
      final Map<String, double> budgetUsageMap = {};

      // Calculate all budget usage percentages
      for (var budget in budgets) {
        final double usagePercentage = await _calculateBudgetUsage(budget);
        budgetUsageMap[budget['budgetId']] = usagePercentage;
        print(
          '[BudgetPage] Budget ${budget['budgetId']}: ${usagePercentage.toStringAsFixed(1)}%',
        );
      }

      // Check if any budget has caution alert
      final hasCaution = await alertService.hasAnyCautionAlert(
        widget.userId,
        budgetUsageMap,
      );

      print('[BudgetPage] hasAnyCautionAlert returned: $hasCaution');

      setState(() {
        _hasBudgetCaution = hasCaution;
      });
    } catch (e) {
      print('Error checking budget caution: $e');
    }
  }

  void _showCautionAlertDialog(List<Map<String, dynamic>> cautionBudgets) {
    bool checkboxValue = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Caution Icon
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.orange.shade700,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Title
                      Text(
                        cautionBudgets.length > 1
                            ? 'Multiple Budget Cautions'
                            : 'Budget Caution',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),

                      // Message
                      Text(
                        cautionBudgets.length > 1
                            ? 'The following budgets have spending over 70%. Please monitor your expenses to avoid exceeding these budgets.'
                            : 'Your budget spending is over 70%. Please monitor your expenses to avoid exceeding your budget.',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),

                      // Budget List
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.orange.shade200,
                            width: 1,
                          ),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: List.generate(cautionBudgets.length, (
                            index,
                          ) {
                            final cautionBudget = cautionBudgets[index];
                            final usagePercentage =
                                cautionBudget['usagePercentage'];
                            final itemName =
                                cautionBudget['displayName'] ??
                                'Unnamed Budget';

                            return Padding(
                              padding: EdgeInsets.only(
                                bottom: index < cautionBudgets.length - 1
                                    ? 8
                                    : 0,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          itemName,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black87,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          '${usagePercentage.toStringAsFixed(1)}% spent',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.orange.shade600,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade200,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${usagePercentage.toStringAsFixed(0)}%',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Checkbox
                      Row(
                        children: [
                          Checkbox(
                            value: checkboxValue,
                            onChanged: (newValue) {
                              setDialogState(() {
                                checkboxValue = newValue ?? false;
                              });
                            },
                            activeColor: Colors.orange.shade700,
                          ),
                          const Expanded(
                            child: Text(
                              'I understand, don\'t show this again',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Button Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey[300],
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Close',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: checkboxValue
                                  ? () {
                                      // Dismiss all caution budgets
                                      final budgetIds = cautionBudgets
                                          .map((b) => b['budgetId'] as String)
                                          .toList();
                                      _dismissBudgetCaution(budgetIds);
                                    }
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange.shade700,
                                disabledBackgroundColor: Colors.grey[400],
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Confirm',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showExceedAlertDialog(List<Map<String, dynamic>> exceedBudgets) {
    bool checkboxValue = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Alert Icon
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.error_rounded,
                          color: Colors.red.shade700,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Title
                      Text(
                        exceedBudgets.length > 1
                            ? 'Multiple Budgets Exceeded'
                            : 'Budget Exceeded',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),

                      // Message
                      Text(
                        exceedBudgets.length > 1
                            ? 'The following budgets have exceeded their limits. Please review your expenses immediately.'
                            : 'Your budget has exceeded the limit. Please review your expenses immediately.',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),

                      // Budget List
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.red.shade200,
                            width: 1,
                          ),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: List.generate(exceedBudgets.length, (
                            index,
                          ) {
                            final exceedBudget = exceedBudgets[index];
                            final usagePercentage =
                                exceedBudget['usagePercentage'];
                            final itemName =
                                exceedBudget['displayName'] ?? 'Unnamed Budget';
                            final excessAmount = usagePercentage - 100;

                            return Padding(
                              padding: EdgeInsets.only(
                                bottom: index < exceedBudgets.length - 1
                                    ? 8
                                    : 0,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          itemName,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black87,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          'Exceeded by ${excessAmount.toStringAsFixed(1)}%',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.red.shade600,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade200,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${usagePercentage.toStringAsFixed(0)}%',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Checkbox
                      Row(
                        children: [
                          Checkbox(
                            value: checkboxValue,
                            onChanged: (newValue) {
                              setDialogState(() {
                                checkboxValue = newValue ?? false;
                              });
                            },
                            activeColor: Colors.red.shade700,
                          ),
                          const Expanded(
                            child: Text(
                              'I understand, don\'t show this again',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Button Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey[300],
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Close',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: checkboxValue
                                  ? () {
                                      // Dismiss all exceed budgets
                                      final budgetIds = exceedBudgets
                                          .map((b) => b['budgetId'] as String)
                                          .toList();
                                      _dismissExceedAlert(budgetIds);
                                    }
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade700,
                                disabledBackgroundColor: Colors.grey[400],
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Confirm',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Helper method to get budget item display name
  Future<String> _getBudgetDisplayName(Map<String, dynamic> budget) async {
    try {
      final budgetType = budget['type'] ?? '';
      String? name;

      if (budgetType == 'account') {
        final accountId = budget['accountId'];
        if (accountId != null) {
          final result = await Supabase.instance.client
              .from('Account')
              .select('accountName')
              .eq('accountId', accountId)
              .maybeSingle();
          name = result?['accountName'];
        }
      } else if (budgetType == 'category') {
        final categoryId = budget['categoryId'];
        if (categoryId != null) {
          final result = await Supabase.instance.client
              .from('Category')
              .select('name')
              .eq('categoryId', categoryId)
              .maybeSingle();
          name = result?['name'];
        }
      } else if (budgetType == 'ledger') {
        final ledgerId = budget['ledgerId'];
        if (ledgerId != null) {
          final result = await Supabase.instance.client
              .from('Ledger')
              .select('name')
              .eq('ledgerId', ledgerId)
              .maybeSingle();
          name = result?['name'];
        }
      }

      return name ?? 'Unnamed Budget';
    } catch (e) {
      print('Error fetching budget display name: $e');
      return 'Budget';
    }
  }

  /// Show pop-up dialog for dismissed alerts (when user is still in alert zone)
  /// This allows user to dismiss the alert again from a clear dialog
  void _showDismissedAlertDialog(
    String budgetId,
    String budgetName,
    String alertType,
    double usagePercentage,
  ) {
    showDialog(
      context: context,
      barrierDismissible: true, // User can tap outside to close
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: const Color(0xFFFFF9E6),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF9E6),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFFE5B4), width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Alert Icon
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: alertType == 'exceed'
                        ? Colors.red.shade100
                        : Colors.orange.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    alertType == 'exceed'
                        ? Icons.error_rounded
                        : Icons.warning_rounded,
                    color: alertType == 'exceed'
                        ? Colors.red.shade600
                        : Colors.orange.shade600,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 20),
                // Title
                Text(
                  'Budget Alert',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: alertType == 'exceed'
                        ? Colors.red.shade600
                        : Colors.orange.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                // Message
                Text(
                  'Budget: $budgetName\n${usagePercentage.toStringAsFixed(1)}% spent',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                // Alert Message
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: alertType == 'exceed'
                        ? Colors.red.shade50
                        : Colors.orange.shade50,
                    border: Border.all(
                      color: alertType == 'exceed'
                          ? Colors.red.shade200
                          : Colors.orange.shade200,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    alertType == 'exceed'
                        ? '⚠️ You are still above your budget limit.\nConsider reducing your spending.'
                        : '⚠️ You are still in the caution zone.\nBe mindful of your remaining budget.',
                    style: TextStyle(
                      fontSize: 12,
                      color: alertType == 'exceed'
                          ? Colors.red.shade700
                          : Colors.orange.shade700,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 24),
                // Buttons
                Row(
                  children: [
                    // Cancel button
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[300],
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Keep Alert',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Dismiss button
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          await _dismissAlertMessageFromBudgetPage(
                            budgetId,
                            alertType,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: alertType == 'exceed'
                              ? Colors.red.shade400
                              : Colors.orange.shade400,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Dismiss',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDeleteSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: const Color(0xFFFFF9E6),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF9E6),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFFE5B4), width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Success icon
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFA7E399),
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 32),
                ),
                const SizedBox(height: 20),
                // Success title
                const Text(
                  'Budget Deleted Successfully!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFF39C12),
                  ),
                ),
                const SizedBox(height: 12),
                // Success message
                const Text(
                  'Your budget has been deleted successfully.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Color(0xFF666666)),
                ),
                const SizedBox(height: 24),
                // OK button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFA7E399),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: const Text('OK'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteBudget(String budgetId) async {
    try {
      await Supabase.instance.client
          .from('Budget')
          .delete()
          .eq('budgetId', budgetId);

      _fetchBudgets();
      if (mounted) {
        _showDeleteSuccessDialog();
      }
    } catch (e) {
      print('Error deleting budget: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting budget: $e')));
      }
    }
  }

  /// Check if alert was dismissed but user is still in the alert zone
  /// Returns {isDismissedAndInZone: bool, alertType: 'caution'|'exceed'|null}
  Future<Map<String, dynamic>> _checkDismissedAlertStatus(
    double usagePercentage,
    String budgetId,
    String cycleType,
  ) async {
    try {
      final alertService = BudgetAlertService();

      // Check for caution (yellow) alert: 70-99% spent
      if (usagePercentage >= 70 && usagePercentage < 100) {
        final isDismissed = await alertService.isCautionDismissed(
          budgetId,
          cycleType,
        );
        // If dismissed AND still in caution zone → show message
        if (isDismissed) {
          return {
            'isDismissedAndInZone': true,
            'alertType': 'caution',
            'percentage': usagePercentage,
          };
        }
      }

      // Check for exceed (red) alert: 100%+ spent
      if (usagePercentage >= 100) {
        final isDismissed = await alertService.isExceedDismissed(budgetId);
        // If dismissed AND still exceeding → show message
        if (isDismissed) {
          return {
            'isDismissedAndInZone': true,
            'alertType': 'exceed',
            'percentage': usagePercentage,
          };
        }
      }

      return {'isDismissedAndInZone': false, 'alertType': null};
    } catch (e) {
      print('[BudgetPage] Error checking dismissed alert status: $e');
      return {'isDismissedAndInZone': false, 'alertType': null};
    }
  }

  /// Dismiss alert notification from the budget page itself
  Future<void> _dismissAlertMessageFromBudgetPage(
    String budgetId,
    String alertType,
  ) async {
    try {
      final alertService = BudgetAlertService();

      if (alertType == 'caution') {
        print(
          '[BudgetPage] Dismissing caution alert from budget page for: $budgetId',
        );
        await alertService.dismissCautionAlert(budgetId, widget.userId);
      } else if (alertType == 'exceed') {
        print(
          '[BudgetPage] Dismissing exceed alert from budget page for: $budgetId',
        );
        await alertService.dismissExceedAlert(budgetId, widget.userId);
      }

      // Refresh to update UI
      if (mounted) {
        _initializeAndLoadBudgets();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Alert dismissed'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('[BudgetPage] Error dismissing alert from budget page: $e');
    }
  }

  /// Check if alert icon should be displayed for a budget
  Future<bool> _shouldShowAlertIcon(
    double usagePercentage,
    String budgetId,
    String cycleType,
  ) async {
    try {
      final alertService = BudgetAlertService();

      // For exceed alerts (>100%)
      if (usagePercentage > 100) {
        final isDismissed = await alertService.isExceedDismissed(budgetId);
        return !isDismissed; // Show icon if NOT dismissed
      }

      // For caution alerts (70-99%)
      if (usagePercentage >= 70 && usagePercentage <= 100) {
        final isDismissed = await alertService.isCautionDismissed(
          budgetId,
          cycleType,
        );
        return !isDismissed; // Show icon if NOT dismissed
      }

      return false; // Don't show icon for < 70%
    } catch (e) {
      print('Error checking if should show alert icon: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEFFD3),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFEFFD3),
        elevation: 0,
        leading: GestureDetector(
          onTap: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => SettingsScreen(userId: widget.userId),
              ),
            );
          },
          child: const Icon(Icons.close, size: 28, color: Colors.black),
        ),
        title: const Text(
          'Budget',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        CreateBudgetPage(userId: widget.userId),
                  ),
                );
                // Refresh budgets if a new one was created
                if (result != null) {
                  _fetchBudgets();
                }
              },
              child: const Icon(Icons.add, size: 28, color: Color(0xFF52C77A)),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _budgets.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.account_balance_wallet,
                    size: 64,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No budgets yet',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create your first budget to get started',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...List.generate(_budgets.length, (index) {
                      final budget = _budgets[index];
                      final budgetId = budget['budgetId'] ?? '';

                      return FutureBuilder<Map<String, dynamic>>(
                        future: _getBudgetItemDetails(budget),
                        builder: (context, detailsSnapshot) {
                          return FutureBuilder<double>(
                            future: _calculateBudgetUsage(budget),
                            builder: (context, usageSnapshot) {
                              if (usageSnapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade200,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }

                              final double usagePercentage =
                                  usageSnapshot.data ?? 0;
                              // ✅ Calculate alert status based on CURRENT usage percentage
                              // Don't trust stale database fields - recalculate dynamically
                              final bool isWarning =
                                  usagePercentage >= 100; // 🔴 RED: exceeded
                              final bool isAlert =
                                  usagePercentage >= 70 &&
                                  usagePercentage < 100; // 🟠 YELLOW: caution
                              final itemName =
                                  detailsSnapshot.data?['name'] ?? 'Budget';
                              final iconUrl = detailsSnapshot.data?['iconUrl'];
                              final budgetAmount = (budget['amount'] ?? 0)
                                  .toDouble();

                              return Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.08),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                    width: 1,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Header Row with Icon, Title, Warning, and Menu
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Row(
                                              children: [
                                                // Icon
                                                Container(
                                                  width: 50,
                                                  height: 50,
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                      0xFFC8E6C9,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                  ),
                                                  child:
                                                      (iconUrl != null &&
                                                          iconUrl.isNotEmpty)
                                                      ? Image.network(
                                                          iconUrl,
                                                          fit: BoxFit.contain,
                                                          errorBuilder:
                                                              (
                                                                context,
                                                                error,
                                                                stackTrace,
                                                              ) {
                                                                return Icon(
                                                                  budget['type'] ==
                                                                          'ledger'
                                                                      ? Icons
                                                                            .book
                                                                      : Icons
                                                                            .category_outlined,
                                                                  size: 28,
                                                                  color: const Color(
                                                                    0xFF52C77A,
                                                                  ),
                                                                );
                                                              },
                                                        )
                                                      : Icon(
                                                          budget['type'] ==
                                                                  'ledger'
                                                              ? Icons.book
                                                              : Icons
                                                                    .category_outlined,
                                                          size: 28,
                                                          color: const Color(
                                                            0xFF52C77A,
                                                          ),
                                                        ),
                                                ),
                                                const SizedBox(width: 16),
                                                // Name and Amount
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        itemName,
                                                        style: const TextStyle(
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: Colors.black87,
                                                        ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        _formatCurrency(
                                                          budgetAmount,
                                                        ),
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          color: Colors.black54,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          // Caution/Alert Icon
                                          FutureBuilder<bool>(
                                            future: _shouldShowAlertIcon(
                                              usagePercentage,
                                              budgetId,
                                              (budget['cycleType'] ?? 'month')
                                                  .toLowerCase(),
                                            ),
                                            builder: (context, iconSnapshot) {
                                              final shouldShowIcon =
                                                  iconSnapshot.data ?? false;

                                              if (shouldShowIcon &&
                                                  (isAlert || isWarning)) {
                                                return Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        right: 12,
                                                      ),
                                                  child: Container(
                                                    width: 40,
                                                    height: 40,
                                                    decoration: BoxDecoration(
                                                      // isWarning = red, isAlert = yellow
                                                      color: isWarning
                                                          ? Colors.red.shade100
                                                          : Colors
                                                                .orange
                                                                .shade100,
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: Center(
                                                      child: Icon(
                                                        isWarning
                                                            ? Icons
                                                                  .error_rounded
                                                            : Icons
                                                                  .warning_rounded,
                                                        color: isWarning
                                                            ? Colors
                                                                  .red
                                                                  .shade600
                                                            : Colors
                                                                  .orange
                                                                  .shade600,
                                                        size: 20,
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              }
                                              return const SizedBox.shrink();
                                            },
                                          ),
                                          // Menu Button
                                          PopupMenuButton<String>(
                                            onSelected: (value) async {
                                              if (value == 'edit') {
                                                final result =
                                                    await Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (context) =>
                                                            EditBudgetPage(
                                                              budget: budget,
                                                              userId:
                                                                  widget.userId,
                                                            ),
                                                      ),
                                                    );
                                                if (result == true) {
                                                  _fetchBudgets();
                                                }
                                              } else if (value == 'delete') {
                                                showDialog(
                                                  context: context,
                                                  barrierDismissible: false,
                                                  builder: (BuildContext context) {
                                                    return Dialog(
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              20,
                                                            ),
                                                      ),
                                                      backgroundColor:
                                                          const Color(
                                                            0xFFFFF9E6,
                                                          ),
                                                      child: Container(
                                                        padding:
                                                            const EdgeInsets.all(
                                                              24,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: const Color(
                                                            0xFFFFF9E6,
                                                          ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                20,
                                                              ),
                                                          border: Border.all(
                                                            color: const Color(
                                                              0xFFFFE5B4,
                                                            ),
                                                            width: 2,
                                                          ),
                                                        ),
                                                        child: Column(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            // Warning icon
                                                            Container(
                                                              width: 60,
                                                              height: 60,
                                                              decoration:
                                                                  BoxDecoration(
                                                                    shape: BoxShape
                                                                        .circle,
                                                                    color: Colors
                                                                        .red
                                                                        .shade200,
                                                                  ),
                                                              child: Icon(
                                                                Icons
                                                                    .warning_rounded,
                                                                color: Colors
                                                                    .red
                                                                    .shade600,
                                                                size: 32,
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              height: 20,
                                                            ),
                                                            // Title
                                                            const Text(
                                                              'Delete Budget?',
                                                              textAlign:
                                                                  TextAlign
                                                                      .center,
                                                              style: TextStyle(
                                                                fontSize: 20,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color: Color(
                                                                  0xFFF39C12,
                                                                ),
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              height: 12,
                                                            ),
                                                            // Message
                                                            const Text(
                                                              'Are you sure you want to delete this budget? This action cannot be undone.',
                                                              textAlign:
                                                                  TextAlign
                                                                      .center,
                                                              style: TextStyle(
                                                                fontSize: 14,
                                                                color: Color(
                                                                  0xFF666666,
                                                                ),
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              height: 24,
                                                            ),
                                                            // Buttons
                                                            Row(
                                                              children: [
                                                                // Cancel button
                                                                Expanded(
                                                                  child: SizedBox(
                                                                    height: 48,
                                                                    child: ElevatedButton(
                                                                      onPressed: () {
                                                                        Navigator.pop(
                                                                          context,
                                                                        );
                                                                      },
                                                                      style: ElevatedButton.styleFrom(
                                                                        backgroundColor:
                                                                            const Color(
                                                                              0xFFE8E8E8,
                                                                            ),
                                                                        foregroundColor:
                                                                            Colors.black87,
                                                                        shape: RoundedRectangleBorder(
                                                                          borderRadius: BorderRadius.circular(
                                                                            10,
                                                                          ),
                                                                        ),
                                                                        textStyle: const TextStyle(
                                                                          fontSize:
                                                                              16,
                                                                          fontWeight:
                                                                              FontWeight.w600,
                                                                        ),
                                                                      ),
                                                                      child: const Text(
                                                                        'Cancel',
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                  width: 12,
                                                                ),
                                                                // Delete button
                                                                Expanded(
                                                                  child: SizedBox(
                                                                    height: 48,
                                                                    child: ElevatedButton(
                                                                      onPressed: () {
                                                                        _deleteBudget(
                                                                          budgetId,
                                                                        );
                                                                        Navigator.pop(
                                                                          context,
                                                                        );
                                                                      },
                                                                      style: ElevatedButton.styleFrom(
                                                                        backgroundColor: Colors
                                                                            .red
                                                                            .shade400,
                                                                        foregroundColor:
                                                                            Colors.white,
                                                                        shape: RoundedRectangleBorder(
                                                                          borderRadius: BorderRadius.circular(
                                                                            10,
                                                                          ),
                                                                        ),
                                                                        textStyle: const TextStyle(
                                                                          fontSize:
                                                                              16,
                                                                          fontWeight:
                                                                              FontWeight.w600,
                                                                        ),
                                                                      ),
                                                                      child: const Text(
                                                                        'Delete',
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                );
                                              }
                                            },
                                            itemBuilder:
                                                (BuildContext context) => [
                                                  const PopupMenuItem(
                                                    value: 'edit',
                                                    child: Text('Edit'),
                                                  ),
                                                  const PopupMenuItem(
                                                    value: 'delete',
                                                    child: Text(
                                                      'Delete',
                                                      style: TextStyle(
                                                        color: Colors.red,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      // Progress Bar
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                'Spent',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.black54,
                                                ),
                                              ),
                                              Text(
                                                '${usagePercentage.toStringAsFixed(1)}%',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            child: LinearProgressIndicator(
                                              value: (usagePercentage / 100)
                                                  .clamp(0.0, 1.0),
                                              minHeight: 8,
                                              backgroundColor: Colors.white
                                                  .withOpacity(0.5),
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                    usagePercentage > 100
                                                        ? Colors.red
                                                        : Colors.green.shade600,
                                                  ),
                                            ),
                                          ),
                                          // Warning Message
                                          if (isAlert || isWarning)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 8,
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    isWarning
                                                        ? Icons.error_rounded
                                                        : Icons.warning_rounded,
                                                    color: isWarning
                                                        ? Colors.red.shade600
                                                        : Colors
                                                              .orange
                                                              .shade600,
                                                    size: 16,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                    child: Text(
                                                      isWarning
                                                          ? 'Budget has exceeded the limit!'
                                                          : 'Budget usage is approaching the limit.',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        color: isWarning
                                                            ? Colors
                                                                  .red
                                                                  .shade600
                                                            : Colors
                                                                  .orange
                                                                  .shade600,
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          // Dismissed Alert Pop-up (triggered automatically when dismissed but still in alert zone)
                                          FutureBuilder<Map<String, dynamic>>(
                                            future: _checkDismissedAlertStatus(
                                              usagePercentage,
                                              budgetId,
                                              (budget['cycleType'] ?? 'month')
                                                  .toLowerCase(),
                                            ),
                                            builder: (context, dismissedSnapshot) {
                                              final dismissedStatus =
                                                  dismissedSnapshot.data ?? {};
                                              final isDismissedAndInZone =
                                                  dismissedStatus['isDismissedAndInZone']
                                                      as bool? ??
                                                  false;
                                              final alertType =
                                                  dismissedStatus['alertType']
                                                      as String?;

                                              // Trigger pop-up automatically when dismissed but still in zone
                                              if (isDismissedAndInZone &&
                                                  alertType != null &&
                                                  !isAlert &&
                                                  !isWarning &&
                                                  !_shownDismissedAlertPopups
                                                      .contains(budgetId)) {
                                                // Mark that we've shown the pop-up for this budget
                                                _shownDismissedAlertPopups.add(
                                                  budgetId,
                                                );

                                                // Show pop-up after frame is built
                                                WidgetsBinding.instance
                                                    .addPostFrameCallback((_) {
                                                      if (mounted) {
                                                        _showDismissedAlertDialog(
                                                          budgetId,
                                                          itemName,
                                                          alertType,
                                                          usagePercentage,
                                                        );
                                                      }
                                                    });
                                              }

                                              return const SizedBox.shrink();
                                            },
                                          ),
                                          // Spending Suggestions
                                          if (isAlert || isWarning)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 10,
                                              ),
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: isWarning
                                                      ? Colors.red.shade50
                                                      : Colors.orange.shade50,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: isWarning
                                                        ? Colors.red.shade200
                                                        : Colors
                                                              .orange
                                                              .shade200,
                                                    width: 1,
                                                  ),
                                                ),
                                                padding: const EdgeInsets.all(
                                                  10,
                                                ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Spending Suggestions:',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: isWarning
                                                            ? Colors
                                                                  .red
                                                                  .shade700
                                                            : Colors
                                                                  .orange
                                                                  .shade700,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 6),
                                                    ...(isWarning
                                                        ? [
                                                            _buildSuggestion(
                                                              '• Stop all non-essential spending immediately',
                                                              isWarning,
                                                            ),
                                                            _buildSuggestion(
                                                              '• Review and reduce daily expenses',
                                                              isWarning,
                                                            ),
                                                            _buildSuggestion(
                                                              '• Consider increasing your budget limit',
                                                              isWarning,
                                                            ),
                                                          ]
                                                        : [
                                                            _buildSuggestion(
                                                              '• Limit spending for the rest of the cycle',
                                                              isWarning,
                                                            ),
                                                            _buildSuggestion(
                                                              '• Avoid large purchases this period',
                                                              isWarning,
                                                            ),
                                                            _buildSuggestion(
                                                              '• Plan expenses carefully',
                                                              isWarning,
                                                            ),
                                                          ]),
                                                  ],
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    }),
                  ],
                ),
              ),
            ),
    );
  }
}
