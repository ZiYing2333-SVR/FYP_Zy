import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_screen.dart';
import 'account_page.dart';
import 'savings_page.dart';
import 'settings_screen.dart';
import 'create_budget_page.dart';

class BudgetPage extends StatefulWidget {
  final String userId;

  const BudgetPage({super.key, required this.userId});

  @override
  State<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends State<BudgetPage> {
  List<Map<String, dynamic>> _budgets = [];
  bool _isLoading = true;
  int _selectedNavIndex = 4;

  @override
  void initState() {
    super.initState();
    _fetchBudgets();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFFFB),
        elevation: 0,
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
                padding: const EdgeInsets.all(16),
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
                              final bool isLowUsage = usagePercentage >= 80;
                              final itemName =
                                  detailsSnapshot.data?['name'] ?? 'Budget';
                              final iconUrl = detailsSnapshot.data?['iconUrl'];
                              final budgetAmount = (budget['amount'] ?? 0)
                                  .toDouble();

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade200,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
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
                                                if (iconUrl != null &&
                                                    iconUrl.isNotEmpty)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          right: 12,
                                                        ),
                                                    child: Image.network(
                                                      iconUrl,
                                                      width: 40,
                                                      height: 40,
                                                      fit: BoxFit.contain,
                                                      errorBuilder:
                                                          (
                                                            context,
                                                            error,
                                                            stackTrace,
                                                          ) {
                                                            return Icon(
                                                              Icons
                                                                  .category_outlined,
                                                              size: 40,
                                                              color: Colors
                                                                  .grey
                                                                  .shade400,
                                                            );
                                                          },
                                                    ),
                                                  )
                                                else
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          right: 12,
                                                        ),
                                                    child: Icon(
                                                      Icons.category_outlined,
                                                      size: 40,
                                                      color:
                                                          Colors.grey.shade400,
                                                    ),
                                                  ),
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
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: Colors.black87,
                                                        ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                      Text(
                                                        _formatCurrency(
                                                          budgetAmount,
                                                        ),
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: Colors.black54,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          // Warning Icon
                                          if (isLowUsage)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                right: 8,
                                              ),
                                              child: Container(
                                                width: 32,
                                                height: 32,
                                                decoration: BoxDecoration(
                                                  color: Colors.red.shade200,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    '!',
                                                    style: TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color:
                                                          Colors.red.shade600,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          // Menu Button
                                          PopupMenuButton<String>(
                                            onSelected: (value) {
                                              if (value == 'edit') {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Edit budget feature coming soon',
                                                    ),
                                                  ),
                                                );
                                              } else if (value == 'delete') {
                                                showDialog(
                                                  context: context,
                                                  builder: (context) => AlertDialog(
                                                    title: const Text(
                                                      'Delete Budget',
                                                    ),
                                                    content: const Text(
                                                      'Are you sure you want to delete this budget?',
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
                                                          _deleteBudget(
                                                            budgetId,
                                                          );
                                                          Navigator.pop(
                                                            context,
                                                          );
                                                        },
                                                        child: const Text(
                                                          'Delete',
                                                          style: TextStyle(
                                                            color: Colors.red,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
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
          } else if (index == 3) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => SavingsPage(userId: widget.userId),
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
