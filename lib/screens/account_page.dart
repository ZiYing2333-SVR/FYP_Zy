import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/bank_icon_helper.dart';
import '../services/budget_forecast_service.dart';
import 'home_screen.dart';
import 'settings_screen.dart';
import 'add_account_page1.dart';
import 'account_detail_screen.dart';
import 'savings_page.dart';
import 'create_account_group_screen.dart';

class AccountPage extends StatefulWidget {
  final String userId;

  const AccountPage({super.key, required this.userId});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  List<Map<String, dynamic>> _accounts = [];
  List<Map<String, dynamic>> _filteredAccounts = [];
  List<Map<String, dynamic>> _accountGroups = [];
  String _selectedGroupId = 'all'; // 'all' or accountCategoryId
  String _selectedGroupName = 'All';
  Map<String, dynamic> _currencies = {};
  bool _isLoading = true;
  int _selectedNavIndex = 1;
  bool _showBalance = true;
  bool _hasBudgetAlert = false;

  @override
  void initState() {
    super.initState();
    _fetchCurrencies();
    _fetchAccountGroups();
    _fetchAccounts();
    _checkBudgetAlerts();
  }

  Future<Map<String, dynamic>?> _fetchGoalForAccount(String accountId) async {
    try {
      // Find goal linked to this savings account
      final goalAccountResult = await Supabase.instance.client
          .from('goalAccount')
          .select()
          .eq('accountId', accountId)
          .maybeSingle();

      if (goalAccountResult == null) {
        return null;
      }

      final goalId = goalAccountResult['goalId'];

      // Fetch the goal details
      final goalResult = await Supabase.instance.client
          .from('SavingGoal')
          .select()
          .eq('goalId', goalId)
          .single();

      return goalResult as Map<String, dynamic>?;
    } catch (e) {
      print('Error fetching goal for account $accountId: $e');
      return null;
    }
  }

  double _calculateGoalProgress(double currentAmount, double targetAmount) {
    if (targetAmount <= 0) return 0;
    final progress = (currentAmount / targetAmount) * 100;
    return progress > 100 ? 100 : progress;
  }

  Widget _buildSavingsAccountCard(
    BuildContext context,
    Map<String, dynamic> account,
    Map<String, dynamic>? goal,
  ) {
    final accountId = account['accountId'] ?? '';
    final accountName = account['accountName'] ?? 'Savings';
    final iconImage = account['iconImage'];
    final balance = (account['balance'] ?? 0).toDouble();
    final currencyId = account['currencyId'];

    double progress = 0;
    double targetAmount = 0;
    if (goal != null) {
      targetAmount = (goal['targetAmount'] ?? 0).toDouble();
      final currentAmount = (goal['currentAmount'] ?? 0).toDouble();
      progress = _calculateGoalProgress(currentAmount, targetAmount);
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AccountDetailScreen(
              accountId: accountId,
              userId: widget.userId,
            ),
          ),
        ).then((_) {
          _fetchAccounts();
        });
      },
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF9E6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with icon and name
            Row(
              children: [
                if (iconImage != null && iconImage.isNotEmpty)
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Image.network(
                      _getIconUrl(iconImage),
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.savings, size: 20),
                        );
                      },
                    ),
                  )
                else
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.savings, size: 20),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    accountName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Progress bar section
            if (goal != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress / 100,
                      minHeight: 6,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.green.shade400,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Progress percentage
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${progress.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.green,
                        ),
                      ),
                      Text(
                        _formatCurrencyWithSymbol(targetAmount, currencyId),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // No goal message
                  Text(
                    'No set goal yet',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Current balance
                  Text(
                    'Balance: ${_formatCurrencyWithSymbol(balance, currencyId)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _getIconUrl(String imagePath) {
    if (imagePath.startsWith('http')) {
      return imagePath;
    } else if (imagePath.startsWith('AccountLogo/')) {
      return BankIconHelper.getBankIconUrl(imagePath);
    } else if (imagePath.startsWith('assets/')) {
      return imagePath;
    }
    return imagePath;
  }

  void _showAllSavingsAccountsList(List<Map<String, dynamic>> savingsAccounts) {
    showDialog(
      context: context,
      builder: (BuildContext context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: const Color(0xFFFEFFD3),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFFEFFD3),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Savings Accounts',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // List of savings accounts
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: savingsAccounts.length,
                  separatorBuilder: (context, index) =>
                      Divider(height: 1, color: Colors.grey[300]),
                  itemBuilder: (context, index) {
                    final account = savingsAccounts[index];
                    final accountId = account['accountId'] ?? '';
                    final accountName = account['accountName'] ?? 'Savings';
                    final balance = (account['balance'] ?? 0).toDouble();
                    final currencyId = account['currencyId'];
                    final iconImage = account['iconImage'];

                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(context); // Close dialog
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AccountDetailScreen(
                              accountId: accountId,
                              userId: widget.userId,
                            ),
                          ),
                        ).then((_) {
                          _fetchAccounts();
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            // Account Icon
                            if (iconImage != null && iconImage.isNotEmpty)
                              Container(
                                width: 45,
                                height: 45,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[200]!),
                                ),
                                child: Image.network(
                                  _getIconUrl(iconImage),
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      decoration: BoxDecoration(
                                        color: Colors.grey[300],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.savings,
                                        size: 24,
                                      ),
                                    );
                                  },
                                ),
                              )
                            else
                              Container(
                                width: 45,
                                height: 45,
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.savings, size: 24),
                              ),
                            const SizedBox(width: 16),
                            // Account Name and Balance
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    accountName,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatCurrencyWithSymbol(
                                      balance,
                                      currencyId,
                                    ),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.green.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Arrow icon
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 18,
                              color: Colors.grey[400],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
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

  Future<void> _fetchAccountGroups() async {
    try {
      final response = await Supabase.instance.client
          .from('AccountCategory')
          .select()
          .ilike('accountCategoryId', 'GACC${widget.userId}%')
          .order('name', ascending: true);

      setState(() {
        _accountGroups = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      print('Error fetching account groups: $e');
    }
  }

  Future<void> _fetchAccounts() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final response = await Supabase.instance.client
          .from('Account')
          .select()
          .eq('userId', widget.userId)
          .order('accountType', ascending: true);

      setState(() {
        _accounts = List<Map<String, dynamic>>.from(response);
        _filteredAccounts =
            _accounts; // Initialize filtered accounts with all accounts
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching accounts: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  double _calculateTotalBalance() {
    double total = 0.0;
    for (var account in _accounts) {
      // Only include in asset if assetStatus is true
      final assetStatus = account['assetStatus'] ?? true;
      if (!assetStatus) continue;

      final balance = account['balance'];
      if (balance != null) {
        total += (balance is int) ? balance.toDouble() : (balance as double);
      }
    }
    return total;
  }

  Future<void> _checkBudgetAlerts() async {
    try {
      final budgets = await Supabase.instance.client
          .from('Budget')
          .select()
          .eq('userId', widget.userId);

      bool hasAlert = false;
      final forecastService = BudgetForecastService();

      // Check each budget for high risk using forecast-based logic
      for (var budget in budgets) {
        final isHighRisk = await forecastService.checkHighRiskAlert(
          widget.userId,
          budget['budgetId'],
          (budget['amount'] ?? 0).toDouble(),
          budget['accountId'],
          budget['categoryId'],
          budget['ledgerId'],
        );

        if (isHighRisk) {
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

  Map<String, double> _calculateCategoryBalance() {
    Map<String, double> categoryBalances = {};
    for (var account in _accounts) {
      // Only include in asset if assetStatus is true
      final assetStatus = account['assetStatus'] ?? true;
      if (!assetStatus) continue;

      final type = account['accountType'] ?? 'Other';
      final balance = account['balance'];
      double balanceValue = 0.0;
      if (balance != null) {
        balanceValue = (balance is int)
            ? balance.toDouble()
            : (balance as double);
      }
      categoryBalances[type] = (categoryBalances[type] ?? 0.0) + balanceValue;
    }
    return categoryBalances;
  }

  Widget _buildIconImage(String imagePath) {
    // For full URLs (custom uploads from Supabase S3)
    if (imagePath.startsWith('http')) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Image.network(
          imagePath,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.account_balance_wallet, size: 20),
            );
          },
        ),
      );
    }
    // For bank logos (AccountLogo/), use Supabase network URL
    else if (imagePath.startsWith('AccountLogo/')) {
      final supabaseUrl = BankIconHelper.getBankIconUrl(imagePath);
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Image.network(
          supabaseUrl,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.account_balance_wallet, size: 20),
            );
          },
        ),
      );
    }
    // For local assets
    else if (imagePath.startsWith('assets/')) {
      final assetPath = imagePath.replaceFirst('assets/', '');
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Image.asset(
          assetPath,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.account_balance_wallet, size: 20),
            );
          },
        ),
      );
    } else {
      // Default placeholder for unknown types
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.account_balance_wallet, size: 20),
      );
    }
  }

  String _getCurrencySymbol(String? currencyId) {
    if (currencyId == null || currencyId.isEmpty || currencyId == 'NULL') {
      return 'RM'; // Default fallback
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

  String _formatCurrency(double amount) {
    return 'RM${amount.toStringAsFixed(2)}';
  }

  List<String> _getUniqueCurrencies() {
    final currencies = <String>{};
    for (var account in _accounts) {
      final assetStatus = account['assetStatus'] ?? true;
      if (assetStatus) {
        final currencyId = account['currencyId'] ?? 'NULL';
        currencies.add(currencyId);
      }
    }
    return currencies.toList();
  }

  double _calculateBalanceByCurrency(String currencyId) {
    double total = 0.0;
    for (var account in _accounts) {
      final assetStatus = account['assetStatus'] ?? true;
      if (!assetStatus) continue;

      final accountCurrency = account['currencyId'] ?? 'NULL';
      if (accountCurrency != currencyId) continue;

      final balance = account['balance'];
      if (balance != null) {
        total += (balance is int) ? balance.toDouble() : (balance as double);
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final totalBalance = _calculateTotalBalance();
    final categoryBalances = _calculateCategoryBalance();
    final accountsByType = <String, List<Map<String, dynamic>>>{};

    // Use filtered accounts if group is selected, otherwise use all accounts
    final displayAccounts = _selectedGroupId == 'all'
        ? _accounts
        : _filteredAccounts;

    for (var account in displayAccounts) {
      final type = account['accountType'] ?? 'Other';
      accountsByType.putIfAbsent(type, () => []);
      accountsByType[type]!.add(account);
    }

    // Filter savings accounts from displayAccounts
    final savingsAccounts = displayAccounts
        .where((acc) => acc['accountType'] == 'Savings')
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFFEFFD3),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: [
                    // Header
                    SizedBox(height: MediaQuery.of(context).size.height * 0.04),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        PopupMenuButton<String>(
                          onSelected: (String value) async {
                            if (value == 'add_group') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      CreateAccountGroupScreen(
                                        userId: widget.userId,
                                      ),
                                ),
                              ).then((_) {
                                _fetchAccountGroups();
                              });
                            } else {
                              setState(() {
                                _selectedGroupId = value;
                                _selectedGroupName = value == 'all'
                                    ? 'All'
                                    : _accountGroups.firstWhere(
                                            (g) =>
                                                g['accountCategoryId'] == value,
                                            orElse: () => {'name': 'All'},
                                          )['name'] ??
                                          'Unknown';
                              });

                              // Fetch filtered accounts
                              if (value == 'all') {
                                setState(() {
                                  _filteredAccounts = _accounts;
                                });
                              } else {
                                try {
                                  final groupAccounts = await Supabase
                                      .instance
                                      .client
                                      .from('GroupAccount')
                                      .select('accountId')
                                      .eq('accountCategoryId', value);

                                  final groupAccountIds = Set<String>.from(
                                    groupAccounts.map((g) => g['accountId']),
                                  );

                                  setState(() {
                                    _filteredAccounts = _accounts
                                        .where(
                                          (account) => groupAccountIds.contains(
                                            account['accountId'],
                                          ),
                                        )
                                        .toList();
                                  });
                                } catch (e) {
                                  print('Error filtering accounts: $e');
                                  setState(() {
                                    _filteredAccounts = _accounts;
                                  });
                                }
                              }
                            }
                          },
                          itemBuilder: (BuildContext context) {
                            final items = <PopupMenuEntry<String>>[
                              const PopupMenuItem<String>(
                                value: 'all',
                                child: Text('All'),
                              ),
                            ];

                            // Add existing groups
                            for (var group in _accountGroups) {
                              items.add(
                                PopupMenuItem<String>(
                                  value: group['accountCategoryId'],
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(group['name'] ?? 'Unknown'),
                                      ),
                                      GestureDetector(
                                        onTap: () {
                                          Navigator.pop(context);
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  CreateAccountGroupScreen(
                                                    userId: widget.userId,
                                                    groupId:
                                                        group['accountCategoryId'],
                                                    groupName: group['name'],
                                                  ),
                                            ),
                                          ).then((_) {
                                            _fetchAccountGroups();
                                          });
                                        },
                                        child: Icon(
                                          Icons.settings,
                                          size: 18,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            // Add divider
                            items.add(const PopupMenuDivider());

                            // Add "Add Group" option
                            items.add(
                              const PopupMenuItem<String>(
                                value: 'add_group',
                                child: Row(
                                  children: [
                                    Icon(Icons.add, size: 18),
                                    SizedBox(width: 8),
                                    Text('Add Group'),
                                  ],
                                ),
                              ),
                            );

                            return items;
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.green.shade300,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  _selectedGroupName,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.arrow_drop_down,
                                  size: 20,
                                  color: Colors.green.shade700,
                                ),
                              ],
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    AddAccountPage1(userId: widget.userId),
                              ),
                            ).then((_) {
                              _fetchAccounts();
                            });
                          },
                          child: const Icon(
                            Icons.add,
                            size: 28,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Asset Summary Card - Multi-Color Design with Currency Support
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFA7E399).withOpacity(0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                          BoxShadow(
                            color: const Color(0xFFA7E399).withOpacity(0.2),
                            blurRadius: 40,
                            offset: const Offset(0, 20),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Header Section with Light Green
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 20,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  const Color(0xFFA7E399),
                                  const Color(0xFF90EE90),
                                ],
                              ),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(20),
                                topRight: Radius.circular(20),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.3),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.account_balance_wallet,
                                        color: Colors.black,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Text(
                                      'Total Assets',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black.withOpacity(0.7),
                                        letterSpacing: 0.5,
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
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      _showBalance
                                          ? Icons.visibility
                                          : Icons.visibility_off,
                                      color: Colors.black.withOpacity(0.7),
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Dark Green Separator
                          Container(
                            height: 3,
                            decoration: BoxDecoration(
                              color: Colors.green.shade800,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          // Balance Section with Darker Background
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 28,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(20),
                                bottomRight: Radius.circular(20),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Show all currencies if multiple exist
                                if (_getUniqueCurrencies().length > 1)
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: _getUniqueCurrencies().map((
                                      currencyId,
                                    ) {
                                      final balance =
                                          _calculateBalanceByCurrency(
                                            currencyId,
                                          );
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 16.0,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _currencies[currencyId]?['name'] ??
                                                  currencyId,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.black.withOpacity(
                                                  0.6,
                                                ),
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              _showBalance
                                                  ? _formatCurrencyWithSymbol(
                                                      balance,
                                                      currencyId,
                                                    )
                                                  : '********',
                                              style: TextStyle(
                                                fontSize: 28,
                                                fontWeight: FontWeight.w900,
                                                color: Colors.green.shade800,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  )
                                else
                                  // Single currency view
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Balance Amount
                                      Text(
                                        _showBalance
                                            ? _formatCurrencyWithSymbol(
                                                totalBalance,
                                                _accounts.isNotEmpty
                                                    ? _accounts
                                                          .first['currencyId']
                                                    : null,
                                              )
                                            : '********',
                                        style: TextStyle(
                                          fontSize: 36,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.green.shade800,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      // Subtitle
                                      Text(
                                        'Available Balance',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black.withOpacity(0.6),
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Savings Accounts Section
                    if (savingsAccounts.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Savings Accounts',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black54,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    _showAllSavingsAccountsList(
                                      savingsAccounts,
                                    );
                                  },
                                  child: Text(
                                    'View all',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.green.shade600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            height: 170,
                            child: FutureBuilder<List<Map<String, dynamic>?>?>(
                              future: Future.wait(
                                savingsAccounts.map(
                                  (account) => _fetchGoalForAccount(
                                    account['accountId'],
                                  ),
                                ),
                              ),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }

                                final goals = snapshot.data ?? [];

                                return ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: savingsAccounts.length,
                                  itemBuilder: (context, index) {
                                    return _buildSavingsAccountCard(
                                      context,
                                      savingsAccounts[index],
                                      goals[index],
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),

                    // Account Categories (excluding Savings)
                    ...accountsByType.entries.where((entry) => entry.key != 'Savings').map((
                      entry,
                    ) {
                      final accountType = entry.key;
                      final accounts = entry.value;
                      final categoryBalance =
                          categoryBalances[accountType] ?? 0.0;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Category Header
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  accountType,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black54,
                                  ),
                                ),
                                Text(
                                  'Bal. ${_formatCurrency(categoryBalance)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Category Container
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
                                ...accounts.map((account) {
                                  final accountId = account['accountId'] ?? '';
                                  final accountName =
                                      account['accountName'] ?? 'Unnamed';
                                  final balanceValue =
                                      account['balance'] ?? 0.0;
                                  final balance = (balanceValue is int)
                                      ? balanceValue.toDouble()
                                      : (balanceValue as double);
                                  final notes =
                                      account['notes'] ?? 'Description';
                                  final iconImage = account['iconImage'];
                                  final hideBalanceStatus =
                                      account['hideBalanceStatus'] ?? false;
                                  final currencyId = account['currencyId'];

                                  return GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              AccountDetailScreen(
                                                accountId: accountId,
                                                userId: widget.userId,
                                              ),
                                        ),
                                      ).then((_) {
                                        // Refresh accounts list when returning from account detail
                                        _fetchAccounts();
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(
                                            color: Colors.grey.shade200,
                                            width: 1,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Row(
                                              children: [
                                                if (iconImage != null &&
                                                    iconImage.isNotEmpty)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          right: 12.0,
                                                        ),
                                                    child: _buildIconImage(
                                                      iconImage,
                                                    ),
                                                  )
                                                else
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          right: 12.0,
                                                        ),
                                                    child: Container(
                                                      width: 40,
                                                      height: 40,
                                                      decoration: BoxDecoration(
                                                        color: Colors.grey[300],
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                      ),
                                                      child: const Icon(
                                                        Icons
                                                            .account_balance_wallet,
                                                        size: 20,
                                                      ),
                                                    ),
                                                  ),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        accountName,
                                                        style: const TextStyle(
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: Colors.black87,
                                                        ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                      Text(
                                                        notes,
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w400,
                                                          color: Colors
                                                              .grey
                                                              .shade600,
                                                        ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Text(
                                            hideBalanceStatus
                                                ? '*****'
                                                : _formatCurrencyWithSymbol(
                                                    balance,
                                                    currencyId,
                                                  ),
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      );
                    }).toList(),

                    // AI Features placeholder
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.grey.shade300,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.auto_awesome,
                            size: 18,
                            color: Colors.black87,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'AI Features',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
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
