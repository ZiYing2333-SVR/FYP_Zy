import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/budget_forecast_service.dart';
import '../services/budget_alert_service.dart';
import '../services/alert_status_service.dart';
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

  @override
  void initState() {
    super.initState();
    _initializeAlerts();
  }

  Future<void> _initializeAlerts() async {
    // Fetch budgets first
    await _fetchBudgets();

    // Check budget caution after fetching
    await _checkBudgetCaution();

    // Check for alerts after a short delay to ensure UI is built
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _checkAndShowHighRiskAlert();
          _checkAndShowCautionAlert();
        }
      });
    }
  }

  Future<void> _fetchBudgets() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final response = await Supabase.instance.client
          .from('Budget')
          .select()
          .eq('userId', widget.userId)
          .order('budgetId', ascending: false);

      setState(() {
        _budgets = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      print('Error fetching budgets: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading budgets: $e')));
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
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

      // Sum up transaction amounts (subtract refunds)
      double totalSpent = 0;
      for (var transaction in transactions) {
        final amount = ((transaction['amount'] ?? 0) as num).toDouble();
        final isRefund = transaction['refund'] == true;

        if (isRefund) {
          // Refund: subtract from budget usage
          totalSpent -= amount;
        } else {
          // Normal transaction: add to budget usage
          totalSpent += amount;
        }
      }

      // Ensure total spent doesn't go below 0
      totalSpent = totalSpent < 0 ? 0 : totalSpent;

      return (totalSpent / budgetAmount) * 100;
    } catch (e) {
      print('Error calculating budget usage: $e');
      return 0;
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

      // Notify all pages in real-time
      AlertStatusService().updateHighRiskAlertStatus(false);
    } catch (e) {
      print('Error dismissing high-risk alert: $e');
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
      final alertService = BudgetAlertService();

      print('[BudgetPage] === DISMISS START ===');
      print('[BudgetPage] Dismissing ${budgetIds.length} budgets: $budgetIds');

      // Dismiss all selected budgets
      for (var budgetId in budgetIds) {
        print('[BudgetPage] Dismissing budget: $budgetId');
        await alertService.dismissCautionAlert(budgetId, widget.userId);
      }

      print(
        '[BudgetPage] All dismissals completed, waiting 1s for database sync...',
      );

      // Wait for database to fully persist dismissal across all regions
      await Future.delayed(const Duration(seconds: 1));

      print('[BudgetPage] Verifying dismissal was saved...');
      // Refresh caution status to verify dismissal is in database
      await _checkBudgetCaution();

      print(
        '[BudgetPage] Verification complete: _hasBudgetCaution = $_hasBudgetCaution',
      );
      print('[BudgetPage] === DISMISS END ===');

      // Notify all pages in real-time
      AlertStatusService().updateCautionAlertStatus(_hasBudgetCaution);

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      print('Error dismissing caution: $e');
    }
  }

  Future<void> _dismissExceedAlert(List<String> budgetIds) async {
    try {
      final alertService = BudgetAlertService();

      print('[BudgetPage] === DISMISS EXCEED START ===');
      print(
        '[BudgetPage] Dismissing ${budgetIds.length} exceed budgets: $budgetIds',
      );

      // Dismiss all selected exceed budgets
      for (var budgetId in budgetIds) {
        print('[BudgetPage] Dismissing exceed budget: $budgetId');
        await alertService.dismissExceedAlert(budgetId, widget.userId);
      }

      print(
        '[BudgetPage] All exceed dismissals completed, waiting 1s for database sync...',
      );

      // Wait for database to fully persist dismissal
      await Future.delayed(const Duration(seconds: 1));

      print('[BudgetPage] Verifying exceed dismissal was saved...');
      // Refresh budget display
      setState(() {});

      print('[BudgetPage] === DISMISS EXCEED END ===');

      // Notify all pages in real-time that warning alerts have been updated
      final budgets = await Supabase.instance.client
          .from('Budget')
          .select('isWarning')
          .eq('userId', widget.userId);

      bool hasAnyWarning = false;
      for (var budget in budgets) {
        if (budget['isWarning'] == true) {
          hasAnyWarning = true;
          break;
        }
      }

      AlertStatusService().updateHighRiskAlertStatus(hasAnyWarning);

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      print('Error dismissing exceed alert: $e');
    }
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

  Future<void> _deleteBudget(String budgetId) async {
    try {
      await Supabase.instance.client
          .from('Budget')
          .delete()
          .eq('budgetId', budgetId);

      _fetchBudgets();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Budget deleted successfully')),
        );
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
                              // Use database fields: isAlert = yellow icon, isWarning = red icon
                              final bool isAlert = budget['isAlert'] ?? false;
                              final bool isWarning =
                                  budget['isWarning'] ?? false;
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
                                                    isAlert
                                                        ? Icons.error_rounded
                                                        : Icons.warning_rounded,
                                                    color: isAlert
                                                        ? Colors.red.shade600
                                                        : Colors
                                                              .orange
                                                              .shade600,
                                                    size: 16,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                    child: Text(
                                                      isAlert
                                                          ? 'Budget has exceeded the limit!'
                                                          : 'Budget usage is approaching the limit.',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        color: isAlert
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
                                          // Spending Suggestions
                                          if (isAlert || isWarning)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 10,
                                              ),
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: isAlert
                                                      ? Colors.red.shade50
                                                      : Colors.orange.shade50,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: isAlert
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
                                                        color: isAlert
                                                            ? Colors
                                                                  .red
                                                                  .shade700
                                                            : Colors
                                                                  .orange
                                                                  .shade700,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 6),
                                                    ...(isAlert
                                                        ? [
                                                            _buildSuggestion(
                                                              '• Stop all non-essential spending immediately',
                                                              isAlert,
                                                            ),
                                                            _buildSuggestion(
                                                              '• Review and reduce daily expenses',
                                                              isAlert,
                                                            ),
                                                            _buildSuggestion(
                                                              '• Consider increasing your budget limit',
                                                              isAlert,
                                                            ),
                                                          ]
                                                        : [
                                                            _buildSuggestion(
                                                              '• Limit spending for the rest of the cycle',
                                                              isAlert,
                                                            ),
                                                            _buildSuggestion(
                                                              '• Avoid large purchases this period',
                                                              isAlert,
                                                            ),
                                                            _buildSuggestion(
                                                              '• Plan expenses carefully',
                                                              isAlert,
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
