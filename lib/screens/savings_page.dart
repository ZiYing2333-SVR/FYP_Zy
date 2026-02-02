import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'home_screen.dart';
import 'account_page.dart';
import 'settings_screen.dart';

class SavingsPage extends StatefulWidget {
  final String userId;

  const SavingsPage({super.key, required this.userId});

  @override
  State<SavingsPage> createState() => _SavingsPageState();
}

class _SavingsPageState extends State<SavingsPage> {
  List<Map<String, dynamic>> _savingGoals = [];
  bool _isLoading = true;
  int _selectedNavIndex = 3;
  bool _showBalance = true;

  @override
  void initState() {
    super.initState();
    _fetchSavingGoals();
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
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching saving goals: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  double _calculateTotalSaved() {
    double total = 0;
    for (final goal in _savingGoals) {
      total += (goal['currentAmount'] ?? 0).toDouble();
    }
    return total;
  }

  Map<String, List<Map<String, dynamic>>> _groupGoalsByStatus() {
    final grouped = <String, List<Map<String, dynamic>>>{};

    for (final goal in _savingGoals) {
      final status = goal['status'] ?? 'active';
      grouped.putIfAbsent(status, () => []).add(goal);
    }

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

  void _navigateTo(int index) {
    if (index == _selectedNavIndex) return;

    Widget nextPage;
    switch (index) {
      case 0:
        nextPage = HomeScreen(userId: widget.userId);
        break;
      case 1:
        nextPage = AccountPage(userId: widget.userId);
        break;
      case 3:
        return;
      case 4:
        nextPage = SettingsScreen(userId: widget.userId);
        break;
      default:
        return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => nextPage),
    );
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
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () {
                // Add new saving goal
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
                    // Saving Goals by Status
                    ...groupedGoals.entries.map((entry) {
                      final status = entry.key;
                      final goals = entry.value;
                      final statusLabel = status == 'active'
                          ? 'Active'
                          : 'Done';

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Status Header
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: Text(
                              statusLabel,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                          // Goals Container
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF9E6),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.grey.shade200,
                                width: 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                ...goals.asMap().entries.map((goalEntry) {
                                  final goalIndex = goalEntry.key;
                                  final goal = goalEntry.value;
                                  final isLastGoal =
                                      goalIndex == goals.length - 1;

                                  final goalName = goal['name'] ?? 'Goal';
                                  final targetAmount =
                                      (goal['targetAmount'] ?? 0).toDouble();
                                  final currentAmount =
                                      (goal['currentAmount'] ?? 0).toDouble();
                                  final endDate = goal['endDate'];
                                  final goalId = goal['goalId'] ?? '';

                                  final progress = targetAmount > 0
                                      ? (currentAmount / targetAmount * 100)
                                            .clamp(0, 100)
                                      : 0.0;

                                  return Column(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 12,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            // Goal Header Row
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    goalName,
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Colors.black87,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                GestureDetector(
                                                  onTap: () {
                                                    showDialog(
                                                      context: context,
                                                      builder: (context) => AlertDialog(
                                                        title: const Text(
                                                          'Delete Goal',
                                                        ),
                                                        content: const Text(
                                                          'Are you sure you want to delete this goal?',
                                                        ),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () =>
                                                                Navigator.pop(
                                                                  context,
                                                                ),
                                                            child: const Text(
                                                              'Cancel',
                                                            ),
                                                          ),
                                                          TextButton(
                                                            onPressed: () {
                                                              _deleteSavingGoal(
                                                                goalId,
                                                              );
                                                              Navigator.pop(
                                                                context,
                                                              );
                                                            },
                                                            child: const Text(
                                                              'Delete',
                                                              style: TextStyle(
                                                                color:
                                                                    Colors.red,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  },
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.all(4),
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
                                                  MainAxisAlignment
                                                      .spaceBetween,
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
                                            const SizedBox(height: 8),
                                            // Progress Bar
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              child: LinearProgressIndicator(
                                                value: progress / 100,
                                                minHeight: 6,
                                                backgroundColor:
                                                    Colors.grey[300],
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                      Color
                                                    >(Colors.green.shade300),
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            // Current Amount and Progress Percentage
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                  _formatCurrency(
                                                    currentAmount,
                                                  ),
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                                Text(
                                                  '${progress.toStringAsFixed(1)}%',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.green,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Divider
                                      if (!isLastGoal)
                                        Divider(
                                          color: Colors.grey.shade200,
                                          height: 1,
                                          thickness: 1,
                                        ),
                                    ],
                                  );
                                }).toList(),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      );
                    }).toList(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: BottomNavigationBar(
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
          BottomNavigationBarItem(icon: Icon(Icons.savings), label: 'Saving'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Setting'),
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
            );
          }
        },
      ),
    );
  }
}
