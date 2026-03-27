import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_screen.dart';
import 'account_page.dart';
import 'settings_screen.dart';
import 'create_saving_page.dart';
import 'saving_detail_page.dart';
import 'saving_goal_assistant_screen.dart';

class SavingsPage extends StatefulWidget {
  final String userId;

  const SavingsPage({super.key, required this.userId});

  @override
  State<SavingsPage> createState() => _SavingsPageState();
}

class _SavingsPageState extends State<SavingsPage> {
  List<Map<String, dynamic>> _savingGoals = [];
  Map<String, double> _accountBalances = {};
  bool _isLoading = true;
  int _selectedNavIndex = 3;
  bool _showBalance = true;
  bool _hasBudgetAlert = false;

  @override
  void initState() {
    super.initState();
    _fetchSavingGoals();
    _checkBudgetAlerts();
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

      // Check each budget for >= 80% usage
      for (var budget in budgets) {
        final double usagePercentage = await _calculateBudgetUsage(budget);
        if (usagePercentage >= 80) {
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

  String _formatCurrency(double value) {
    return 'RM${value.toStringAsFixed(2)}';
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

  @override
  Widget build(BuildContext context) {
    final totalSaved = _calculateTotalSaved();
    final groupedGoals = _groupGoalsByStatus();

    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFFFB),
        elevation: 0,
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
                    builder: (context) =>
                        SavingGoalAssistantScreen(userId: widget.userId),
                  ),
                );
                // Refresh the data if a saving goal was created
                if (result == true) {
                  _fetchSavingGoals();
                }
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.blue.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Colors.blue,
                  size: 24,
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
                    builder: (context) =>
                        CreateSavingPage(userId: widget.userId),
                  ),
                );
                // Refresh the data if a saving goal was created
                if (result == true) {
                  _fetchSavingGoals();
                }
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.green.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.add, color: Colors.green, size: 24),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 24,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade200,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total Saved',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _showBalance = !_showBalance;
                                  });
                                },
                                child: Icon(
                                  _showBalance
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  color: Colors.black87,
                                  size: 24,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _showBalance
                                ? _formatCurrency(totalSaved)
                                : '••••••',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // AI Features Button
                    GestureDetector(
                      onTap: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SavingGoalAssistantScreen(
                              userId: widget.userId,
                            ),
                          ),
                        );
                        // Refresh the data if a saving goal was created
                        if (result == true) {
                          _fetchSavingGoals();
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.purple.shade300,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              color: Colors.purple.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'AI Features',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.purple.shade700,
                              ),
                            ),
                          ],
                        ),
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
                                color: status == 'active'
                                    ? const Color(0xFFFFF9E6)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: status == 'active'
                                      ? Colors.grey.shade200
                                      : Colors.grey.shade300,
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
                                                  backgroundColor: const Color(
                                                    0xFFFFF9E6,
                                                  ),
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
                                                Colors.green.shade400,
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
                                                  color: Colors.green,
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
      bottomNavigationBar: Stack(
        children: [
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
              } else if (index == 4) {
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
