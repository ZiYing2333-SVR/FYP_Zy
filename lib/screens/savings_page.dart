import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../pet/pet_home_page.dart';
import '../pet/pet_main.dart';
import '../services/budget_alert_service.dart';
import 'home_screen.dart';
import 'account_page.dart';
import 'settings_screen.dart';
import 'create_saving_page.dart';
import 'saving_detail_page.dart';
import 'saving_goal_assistant_screen.dart';
import 'ai_features_screen.dart';

class SavingsPage extends StatefulWidget {
  final String userId;
  final String? ledgerId;

  const SavingsPage({super.key, required this.userId, this.ledgerId});

  @override
  State<SavingsPage> createState() => _SavingsPageState();
}

class _SavingsPageState extends State<SavingsPage> with WidgetsBindingObserver {
  List<Map<String, dynamic>> _savingGoals = [];
  Map<String, double> _accountBalances = {};
  Map<String, String?> _accountCurrencies = {};
  Map<String, dynamic> _currencies = {};
  bool _isLoading = true;
  int _selectedNavIndex = 3;
  bool _showBalance = true;
  bool _hasBudgetAlert = false;
  bool _hasBudgetCaution = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchCurrencies();
    _fetchSavingGoals();
    _checkBudgetAlerts();
    _checkBudgetCaution();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      print('[SavingsPage] App resumed, refreshing badge status...');
      _checkBudgetCaution();
    }
  }

  Future<void> _fetchCurrencies() async {
    try {
      final response = await Supabase.instance.client.from('Currency').select();
      final Map<String, dynamic> currencyMap = {};
      for (var currency in response) {
        currencyMap[currency['currencyId']] = currency;
      }
      setState(() {
        _currencies = currencyMap;
      });
    } catch (e) {
      print('Error fetching currencies: $e');
    }
  }

  Future<void> _fetchSavingGoals() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final response = await Supabase.instance.client
          .from('SavingGoal')
          .select()
          .eq('userId', widget.userId)
          .order('endDate', ascending: true);

      setState(() {
        _savingGoals = List<Map<String, dynamic>>.from(response);
      });

      // Fetch account balances for destination accounts
      await _fetchAccountBalances();

      // Check progress for each goal
      for (final goal in _savingGoals) {
        final destAccountId = goal['destAccountId'] as String?;
        if (destAccountId != null) {
          final balance = _accountBalances[destAccountId] ?? 0.0;
          final targetAmount = (goal['targetAmount'] ?? 0).toDouble();
          await _checkAndUpdateGoalProgress(
            goal['goalId'],
            targetAmount,
            balance,
          );
        }
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching saving goals: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchAccountBalances() async {
    try {
      // Get all unique destination account IDs
      final destAccountIds = _savingGoals
          .map((goal) => goal['destAccountId'] as String)
          .toSet();

      if (destAccountIds.isEmpty) return;

      for (final accountId in destAccountIds) {
        final response = await Supabase.instance.client
            .from('Account')
            .select()
            .eq('accountId', accountId)
            .single();

        setState(() {
          _accountBalances[accountId] = (response['balance'] ?? 0).toDouble();
          _accountCurrencies[accountId] = response['currencyId'] as String?;
        });
      }
    } catch (e) {
      print('Error fetching account balances: $e');
    }
  }

  Future<void> _checkBudgetAlerts() async {
    try {
      final budgets = await Supabase.instance.client
          .from('Budget')
          .select()
          .eq('userId', widget.userId);

      bool hasAlert = false;

      // Check each budget for exceeded (> 100% usage)
      for (var budget in budgets) {
        final double usagePercentage = await _calculateBudgetUsage(budget);
        if (usagePercentage > 100) {
          hasAlert = true;
          break;
        }
      }

      setState(() {
        _hasBudgetAlert = hasAlert;
      });
    } catch (e) {
      print('Error checking budget alerts: $e');
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

      // Sum up transaction amounts
      double totalSpent = 0;
      for (var transaction in transactions) {
        totalSpent += ((transaction['amount'] ?? 0) as num).toDouble();
      }

      return (totalSpent / budgetAmount) * 100;
    } catch (e) {
      print('Error calculating budget usage: $e');
      return 0;
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
      }

      // Check if any budget has caution alert using the new service
      final hasCaution = await alertService.hasAnyCautionAlert(
        widget.userId,
        budgetUsageMap,
      );

      setState(() {
        _hasBudgetCaution = hasCaution;
      });
    } catch (e) {
      print('Error checking budget caution: $e');
    }
  }

  double _calculateTotalSaved() {
    double total = 0;
    for (final goal in _savingGoals) {
      final destAccountId = goal['destAccountId'] as String?;
      if (destAccountId != null) {
        total += _accountBalances[destAccountId] ?? 0.0;
      }
    }
    return total;
  }

  Map<String, List<Map<String, dynamic>>> _groupGoalsByStatus() {
    final grouped = <String, List<Map<String, dynamic>>>{};

    // Separate finished (inactive status) and non-finished goals
    final finished = <Map<String, dynamic>>[];
    final active = <Map<String, dynamic>>[];

    for (final goal in _savingGoals) {
      final status = goal['status'] ?? 'active';
      if (status == 'inactive') {
        finished.add(goal);
      } else {
        active.add(goal);
      }
    }

    if (active.isNotEmpty) grouped['active'] = active;
    if (finished.isNotEmpty) grouped['finished'] = finished;

    return grouped;
  }

  String _getCurrencySymbol(String? currencyId) {
    if (currencyId == null || currencyId.isEmpty || currencyId == 'NULL') {
      return 'RM';
    }
    final currency = _currencies[currencyId];
    if (currency != null && currency['symbol'] != null) {
      return currency['symbol'];
    }
    return currency?['code'] ?? 'RM';
  }

  String _formatCurrencyWithSymbol(double amount, String? currencyId) {
    final symbol = _getCurrencySymbol(currencyId);
    return '$symbol${amount.toStringAsFixed(2)}';
  }

  String _formatCurrency(double value) {
    return 'RM${value.toStringAsFixed(2)}';
  }

  Map<String, double> _calculateTotalSavedByCurrency() {
    final totalByCurrency = <String, double>{};
    for (final goal in _savingGoals) {
      final destAccountId = goal['destAccountId'] as String?;
      if (destAccountId != null) {
        final balance = _accountBalances[destAccountId] ?? 0.0;
        final currencyId = _accountCurrencies[destAccountId] ?? 'NULL';
        totalByCurrency.update(
          currencyId,
          (existing) => existing + balance,
          ifAbsent: () => balance,
        );
      }
    }
    return totalByCurrency;
  }

  String _getEndDateText(String? endDate) {
    if (endDate == null) return 'No end date';
    try {
      final date = DateTime.parse(endDate);
      final now = DateTime.now();
      final daysLeft = date.difference(now).inDays;

      if (daysLeft < 0) {
        return 'Ended ${(-daysLeft)} days ago';
      } else if (daysLeft == 0) {
        return 'Ends today';
      } else if (daysLeft == 1) {
        return 'Ends tomorrow';
      } else {
        return 'Ends in $daysLeft days';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  Future<void> _deleteSavingGoal(String goalId) async {
    try {
      await Supabase.instance.client
          .from('SavingGoal')
          .delete()
          .eq('goalId', goalId);

      _fetchSavingGoals();
    } catch (e) {
      print('Error deleting saving goal: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting goal: $e')));
      }
    }
  }

  Future<void> _updateGoalStatus(
    String goalId,
    String newStatus, {
    bool? cycleStatus,
  }) async {
    try {
      final updateData = <String, dynamic>{'status': newStatus};
      if (cycleStatus != null) {
        updateData['cycleStatus'] = cycleStatus;
      }

      await Supabase.instance.client
          .from('SavingGoal')
          .update(updateData)
          .eq('goalId', goalId);

      _fetchSavingGoals();
    } catch (e) {
      print('Error updating goal status: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating goal: $e')));
      }
    }
  }

  Future<void> _checkAndUpdateGoalProgress(
    String goalId,
    double targetAmount,
    double currentAmount,
  ) async {
    // If current amount reaches or exceeds target and status is not inactive
    if (currentAmount >= targetAmount) {
      final goal = _savingGoals.firstWhere(
        (g) => g['goalId'] == goalId,
        orElse: () => {},
      );

      if (goal.isNotEmpty && goal['status'] != 'inactive') {
        await _updateGoalStatus(goalId, 'inactive', cycleStatus: false);
      }
    }
  }

  Future<void> _handlePetNavigation() async {
    try {
      final supabase = Supabase.instance.client;

      final response = await supabase
          .from('Pet')
          .select('petId') // 👈 only get petId
          .eq('userId', widget.userId)
          .maybeSingle();

      if (response != null) {
        final petId = response['petId'];

        // ✅ Navigate with petId
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PetHomePage(
              userId: widget.userId,
              petId: petId,
            ),
          ),
        );
      } else {
        // ❌ No pet → go create page
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PetMainPage(
              userId: widget.userId,
            ),
          ),
        );
      }
    } catch (e) {
      print('Error checking pet: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalSaved = _calculateTotalSaved();
    final totalByCurrency = _calculateTotalSavedByCurrency();
    final groupedGoals = _groupGoalsByStatus();

    return Scaffold(
      backgroundColor: const Color(0xFFFEFFD3),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFEFFD3),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Saving',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SavingGoalAssistantScreen(
                      userId: widget.userId,
                      ledgerId: widget.ledgerId,
                    ),
                  ),
                );
                // Refresh the data if a saving goal was created
                if (result == true) {
                  _fetchSavingGoals();
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFA7E399), width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(6),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Color(0xFFA7E399),
                  size: 20,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CreateSavingPage(
                      userId: widget.userId,
                      ledgerId: widget.ledgerId,
                    ),
                  ),
                );
                // Refresh the data if a saving goal was created
                if (result == true) {
                  _fetchSavingGoals();
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFA7E399), width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(6),
                child: const Icon(
                  Icons.add,
                  color: Color(0xFFA7E399),
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    // Total Saved Card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFFA7E399),
                            const Color(0xFFC8F7DC),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFA7E399).withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                          BoxShadow(
                            color: const Color(0xFFA7E399).withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                        border: Border.all(
                          color: Colors.white.withOpacity(0.5),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          // Header with icon
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.savings,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Total Saved',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _showBalance = !_showBalance;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    _showBalance
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          // Amount display - Multi-currency support
                          if (totalByCurrency.isEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                _showBalance ? 'RM0.00' : '***',
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            )
                          else if (totalByCurrency.length == 1)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                _showBalance
                                    ? _formatCurrencyWithSymbol(
                                        totalByCurrency.values.first,
                                        totalByCurrency.keys.first,
                                      )
                                    : '***',
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            )
                          else
                            Column(
                              children: totalByCurrency.entries.map((entry) {
                                final currencyId = entry.key;
                                final amount = entry.value;
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    _showBalance
                                        ? _formatCurrencyWithSymbol(
                                            amount,
                                            currencyId,
                                          )
                                        : '***',
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Saving Goals by Status
                    ...groupedGoals.entries.map((entry) {
                      final status = entry.key;
                      final goals = entry.value;
                      final statusLabel = status == 'active'
                          ? 'Active Savings'
                          : 'Finished Savings';

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Status Header
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: 12.0,
                              top: 12.0,
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: status == 'active'
                                    ? Colors.blue.shade700
                                    : Colors.grey.shade700,
                              ),
                            ),
                          ),
                          // Individual Goal Cards
                          ...goals.asMap().entries.map((goalEntry) {
                            final goal = goalEntry.value;
                            final goalName = goal['name'] ?? 'Goal';
                            final targetAmount = (goal['targetAmount'] ?? 0)
                                .toDouble();
                            final destAccountId = goal['destAccountId'] ?? '';
                            final destAccountBalance =
                                _accountBalances[destAccountId] ?? 0.0;
                            final endDate = goal['endDate'];
                            final goalId = goal['goalId'] ?? '';

                            final progress = targetAmount > 0
                                ? (destAccountBalance / targetAmount * 100)
                                      .clamp(0, 100)
                                : 0.0;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF9E6),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFFFE5B4),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => SavingDetailPage(
                                        goalId: goalId,
                                        userId: widget.userId,
                                      ),
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Goal Header Row
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              goalName,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.black87,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          GestureDetector(
                                            onTap: () {
                                              showDialog(
                                                context: context,
                                                builder: (context) => AlertDialog(
                                                  backgroundColor: Colors.white,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          20,
                                                        ),
                                                  ),
                                                  contentPadding:
                                                      const EdgeInsets.all(24),
                                                  title: const Text(
                                                    'Delete Goal',
                                                    style: TextStyle(
                                                      fontSize: 20,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Color(0xFFF39C12),
                                                    ),
                                                  ),
                                                  content: const Text(
                                                    'Are you sure you want to delete this goal?',
                                                    style: TextStyle(
                                                      color: Color(0xFF666666),
                                                    ),
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                            context,
                                                          ),
                                                      child: const Text(
                                                        'Cancel',
                                                        style: TextStyle(
                                                          color: Color(
                                                            0xFFF39C12,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    TextButton(
                                                      onPressed: () {
                                                        _deleteSavingGoal(
                                                          goalId,
                                                        );
                                                        Navigator.pop(context);
                                                      },
                                                      child: const Text(
                                                        'Delete',
                                                        style: TextStyle(
                                                          color: Color(
                                                            0xFF666666,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              child: const Icon(
                                                Icons.delete,
                                                color: Colors.red,
                                                size: 20,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      // End Date and Goal Amount
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            _getEndDateText(endDate),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFFBCBCBC),
                                            ),
                                          ),
                                          Text(
                                            'Goal ${_formatCurrency(targetAmount)}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFFBCBCBC),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      // Progress Bar
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: progress / 100,
                                          minHeight: 8,
                                          backgroundColor: Colors.grey[300],
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                const Color(0xFFA7E399),
                                              ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      // Current Amount and Progress Percentage
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Saved',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                              Text(
                                                _formatCurrency(
                                                  destAccountBalance,
                                                ),
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                'Progress',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                              Text(
                                                '${progress.toStringAsFixed(1)}%',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFFA7E399),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ],
                      );
                    }).toList(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // AI Feature Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF90EE90),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AIFeaturesScreen(
                        userId: widget.userId,
                        ledgerId: widget.ledgerId,
                      ),
                    ),
                  );
                },
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.auto_awesome, color: Colors.black, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'AI Features',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Bottom Navigation Bar
          Stack(
            children: [
              BottomNavigationBar(
                currentIndex: _selectedNavIndex,
                selectedItemColor: const Color(0xFFA7E399),
                backgroundColor: const Color(0xFFFEFFD3),
                type: BottomNavigationBarType.fixed,
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.home),
                    label: 'Home',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.account_balance_wallet),
                    label: 'Account',
                  ),
                  BottomNavigationBarItem(icon: Icon(Icons.pets), label: 'Pet'),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.savings),
                    label: 'Saving',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.settings),
                    label: 'Setting',
                  ),
                ],
                onTap: (index) {
                  setState(() {
                    _selectedNavIndex = index;
                  });
                  if (index == 0) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => HomeScreen(userId: widget.userId),
                      ),
                    );
                  } else if (index == 1) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            AccountPage(userId: widget.userId),
                      ),
                    );
                  } else if (index == 4) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            SettingsScreen(userId: widget.userId),
                      ),
                    ).then((_) {
                      _checkBudgetAlerts();
                    });
                  }
                },
              ),
              // Caution badge on Settings icon
              if (_hasBudgetCaution)
                Positioned(
                  right: 12,
                  top: 8,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.orange.shade700,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.warning_rounded,
                        color: Colors.white,
                        size: 12,
                      ),
                    ),
                  ),
                ),
              // Alert badge on Settings icon
              if (_hasBudgetAlert)
                Positioned(
                  right: 12,
                  top: 8,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE53935),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text(
                        '!',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          BottomNavigationBar(
            currentIndex: _selectedNavIndex,
            backgroundColor: const Color(0xFFFEFFD3),
            type: BottomNavigationBarType.fixed,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
              BottomNavigationBarItem(
                icon: Icon(Icons.account_balance_wallet),
                label: 'Account',
              ),
              BottomNavigationBarItem(icon: Icon(Icons.pets), label: 'Pet'),
              BottomNavigationBarItem(
                icon: Icon(Icons.savings),
                label: 'Saving',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.settings),
                label: 'Setting',
              ),
            ],
            onTap: (index) {
              setState(() {
                _selectedNavIndex = index;
              });
              if (index == 0) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => HomeScreen(userId: widget.userId),
                  ),
                );
              } else if (index == 1) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AccountPage(userId: widget.userId),
                  ),
                );
              } else if (index == 2) {
                // 🐶 PET LOGIC HERE
                _handlePetNavigation();
              }else if (index == 4) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SettingsScreen(userId: widget.userId),
                  ),
                ).then((_) {
                  _checkBudgetAlerts();
                });
              }
            },
          ),
          // Alert badge on Settings icon
          if (_hasBudgetAlert)
            Positioned(
              right: 12,
              top: 8,
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: Color(0xFFE53935),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text(
                    '!',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
