import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/budget_alert_service.dart';
import '../services/alert_status_service.dart';
import '../services/auto_deduction_service.dart';
import '../services/missing_transfer_alert_service.dart';
import '../widgets/shared_bottom_nav_bar.dart';
import '../pet/pet_home_page.dart';
import '../pet/pet_main.dart';
import 'settings_screen.dart';
import 'ledger_manager.dart';
import 'account_page.dart';
import 'add_transaction.dart';
import 'transaction_detail_screen.dart';
import 'transfer_detail_screen.dart';
import 'savings_page.dart';
import 'ai_features_screen.dart';

class HomeScreen extends StatefulWidget {
  final String userId;

  const HomeScreen({super.key, required this.userId});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  DateTime _selectedDate = DateTime.now();
  DateTime _calendarDate = DateTime.now(); // For calendar view
  DateTime? _selectedCalendarDay; // For selected day in calendar view
  double _totalAmount = 0;
  double _incomeAmount = 0;
  double _expenseAmount = 0;
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = true;
  bool _showAmounts = true;
  bool _hasBudgetAlert = false;
  bool _hasBudgetCaution = false;
  bool _isCalendarView = false; // Track view mode
  String _calendarFilter = 'Total'; // Calendar filter: Total, Income, Expenses
  Map<String, double> _dailyBalances = {}; // Daily balances for calendar
  Map<String, double> _dailyIncome = {}; // Daily income for calendar
  Map<String, double> _dailyExpense = {}; // Daily expenses for calendar
  List<Map<String, dynamic>> _selectedDayTransactions =
      []; // Transactions for selected calendar day

  // Ledger related
  List<Map<String, dynamic>> _ledgers = [];
  String? _selectedLedgerId;
  String? _currentUserId;
  bool _isLoadingLedgers = true;
  bool _alertsShownThisSession =
      false; // Track if alerts already shown this session
  bool _missingTransferAlertShown =
      false; // Track if missing transfer alert shown this session

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentUserId = widget.userId;

    // Reset missing transfer alert flag when returning to home screen
    // This allows the check to run again if new missing transfers are found
    _missingTransferAlertShown = false;

    _fetchLedgers();
    // Check and create auto-deductions when home screen loads
    _checkAutoDeductions();
    // _initializeAlerts(); // DISABLED: Prevent automatic budget alert popups
  }

  Future<void> _initializeAlerts() async {
    await _checkBudgetAlertFlags();
    await _checkBudgetCaution();

    // Show alerts once per session after a short delay
    if (mounted && !_alertsShownThisSession) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _alertsShownThisSession = true;
          if (_hasBudgetCaution) {
            _showCautionAlertDialog();
          } else if (_hasBudgetAlert) {
            _showAlertDialog();
          }
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      print(
        '[HomeScreen] App resumed, refreshing badge status and transactions...',
      );
      // Check auto-deductions when app resumes
      _checkAutoDeductions();
      _checkBudgetAlertFlags();
      _fetchTransactions();
    }
  }

  Future<void> _fetchLedgers() async {
    try {
      if (_currentUserId == null) return;

      final supabase = Supabase.instance.client;

      final response = await supabase
          .from('Ledger')
          .select()
          .eq('userId', _currentUserId!);

      setState(() {
        _ledgers = List<Map<String, dynamic>>.from(response);
        _isLoadingLedgers = false;

        // Select the first ledger by default
        if (_ledgers.isNotEmpty && _selectedLedgerId == null) {
          _selectedLedgerId = _ledgers[0]['ledgerId'];
          _fetchTransactions();
        }
      });
    } catch (e) {
      print('Error fetching ledgers: $e');
      setState(() {
        _isLoadingLedgers = false;
      });
    }
  }

  Future<void> _fetchTransactions() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final supabase = Supabase.instance.client;

      // Fetch transactions for the selected month
      final startOfMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
      final endOfMonth = DateTime(
        _selectedDate.year,
        _selectedDate.month + 1,
        0,
      );

      // Fetch transactions
      final transactionResponse = await supabase
          .from('Transaction')
          .select('*, Category(name, icon), Account(accountName, iconImage)')
          .eq('ledgerId', _selectedLedgerId ?? '')
          .gte('date', startOfMonth.toIso8601String())
          .lte('date', endOfMonth.toIso8601String())
          .order('date', ascending: false);

      // Fetch transfers for the same date range (without Account joins to avoid PostgreSQL aliasing issues)
      final transferResponse = await supabase
          .from('Transfer')
          .select('*')
          .gte('date', startOfMonth.toIso8601String())
          .lte('date', endOfMonth.toIso8601String())
          .order('date', ascending: false);

      // Fetch all accounts for enriching transfer data
      final accountsResponse = await supabase
          .from('Account')
          .select('accountId, accountName, iconImage');

      final accountsMap = {
        for (var account in accountsResponse) account['accountId']: account,
      };

      double income = 0;
      double expense = 0;
      List<Map<String, dynamic>> allRecords = [];

      // Process transactions (excluding refunded ones)
      for (var transaction in transactionResponse) {
        allRecords.add(transaction);
        final amount = double.tryParse(transaction['amount'].toString()) ?? 0;
        final type = transaction['type']?.toString().toLowerCase() ?? 'expense';
        final isRefunded = transaction['refund'] == true;

        // Skip refunded transactions from income/expense totals
        if (!isRefunded) {
          if (type == 'income') {
            income += amount;
          } else {
            expense += amount;
          }
        }
      }

      // Process transfers - show all but don't count refunded ones in totals
      for (var transfer in transferResponse) {
        final enrichedTransfer = Map<String, dynamic>.from(transfer);
        enrichedTransfer['recordType'] = 'transfer';

        // Add account data for from and to accounts
        enrichedTransfer['Account!fromAccountId'] =
            accountsMap[transfer['fromAccountId']] ?? {};
        enrichedTransfer['Account!toAccountId'] =
            accountsMap[transfer['toAccountId']] ?? {};

        allRecords.add(enrichedTransfer);
      }

      // Sort all records by date
      allRecords.sort((a, b) {
        final dateA = DateTime.parse(a['date'] ?? '');
        final dateB = DateTime.parse(b['date'] ?? '');
        return dateB.compareTo(dateA);
      });

      setState(() {
        _transactions = allRecords;
        _incomeAmount = income;
        _expenseAmount = expense;
        _totalAmount = income - expense;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching transactions: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showMonthYearPicker() async {
    // Show a custom month/year picker using a dialog
    showDialog(
      context: context,
      builder: (context) {
        int selectedMonth = _selectedDate.month;
        int selectedYear = _selectedDate.year;
        return AlertDialog(
          title: const Text('Select Month and Year'),
          content: StatefulBuilder(
            builder: (context, setState) {
              return SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Year Selector
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios),
                          onPressed: () {
                            setState(() {
                              selectedYear--;
                            });
                          },
                        ),
                        Text(
                          selectedYear.toString(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.arrow_forward_ios),
                          onPressed: () {
                            setState(() {
                              selectedYear++;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Month Grid
                    GridView.builder(
                      shrinkWrap: true,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 2,
                          ),
                      itemCount: 12,
                      itemBuilder: (context, index) {
                        final month = index + 1;
                        final isSelected = month == selectedMonth;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedMonth = month;
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFA7E399)
                                  : Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                _getMonthName(month),
                                style: TextStyle(
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.black,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedDate = DateTime(selectedYear, selectedMonth, 1);
                  if (_isCalendarView) {
                    _calendarDate = DateTime(selectedYear, selectedMonth, 1);
                    _selectedCalendarDay = null;
                    _selectedDayTransactions = [];
                  }
                });
                if (_isCalendarView) {
                  _calculateDailyBalances();
                } else {
                  _fetchTransactions();
                }
                Navigator.pop(context);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _calculateDailyBalances() async {
    try {
      final startOfMonth = DateTime(_calendarDate.year, _calendarDate.month, 1);
      final endOfMonth = DateTime(
        _calendarDate.year,
        _calendarDate.month + 1,
        0,
      );

      final supabase = Supabase.instance.client;

      // Fetch transactions with category and account data for display
      final listResponse = await supabase
          .from('Transaction')
          .select('*, Category(name, icon), Account(accountName, iconImage)')
          .eq('ledgerId', _selectedLedgerId ?? '')
          .gte('date', startOfMonth.toIso8601String())
          .lte('date', endOfMonth.toIso8601String())
          .order('date', ascending: false);

      // Fetch transfers for the same date range (without Account joins to avoid PostgreSQL aliasing issues)
      final transferResponse = await supabase
          .from('Transfer')
          .select('*')
          .gte('date', startOfMonth.toIso8601String())
          .lte('date', endOfMonth.toIso8601String())
          .order('date', ascending: false);

      // Fetch all accounts for enriching transfer data
      final accountsResponse = await supabase
          .from('Account')
          .select('accountId, accountName, iconImage');

      final accountsMap = {
        for (var account in accountsResponse) account['accountId']: account,
      };

      // Fetch all transactions for daily balance calculation
      final response = await supabase
          .from('Transaction')
          .select()
          .eq('ledgerId', _selectedLedgerId ?? '')
          .gte('date', startOfMonth.toIso8601String())
          .lte('date', endOfMonth.toIso8601String());

      Map<String, double> dailyBalances = {};
      Map<String, double> dailyIncome = {};
      Map<String, double> dailyExpense = {};

      for (var transaction in response) {
        final date = transaction['date'] != null
            ? DateTime.parse(transaction['date'])
            : DateTime.now();
        final dateKey =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

        final amount = double.tryParse(transaction['amount'].toString()) ?? 0;
        final type = transaction['type']?.toString().toLowerCase() ?? 'expense';

        if (type == 'income') {
          dailyIncome[dateKey] = (dailyIncome[dateKey] ?? 0) + amount;
          dailyBalances[dateKey] = (dailyBalances[dateKey] ?? 0) + amount;
        } else {
          dailyExpense[dateKey] = (dailyExpense[dateKey] ?? 0) + amount;
          dailyBalances[dateKey] = (dailyBalances[dateKey] ?? 0) - amount;
        }
      }

      // Combine transactions and transfers for display
      List<Map<String, dynamic>> allRecords = [];

      // Add transactions from display response
      for (var transaction in listResponse) {
        allRecords.add(transaction);
      }

      // Add transfers with account data enrichment
      for (var transfer in transferResponse) {
        final enrichedTransfer = Map<String, dynamic>.from(transfer);
        enrichedTransfer['recordType'] = 'transfer';

        // Add account data for from and to accounts
        enrichedTransfer['Account!fromAccountId'] =
            accountsMap[transfer['fromAccountId']] ?? {};
        enrichedTransfer['Account!toAccountId'] =
            accountsMap[transfer['toAccountId']] ?? {};

        allRecords.add(enrichedTransfer);
      }

      // Sort all records by date
      allRecords.sort((a, b) {
        final dateA = DateTime.parse(a['date'] ?? '');
        final dateB = DateTime.parse(b['date'] ?? '');
        return dateB.compareTo(dateA);
      });

      setState(() {
        _dailyBalances = dailyBalances;
        _dailyIncome = dailyIncome;
        _dailyExpense = dailyExpense;
        _transactions = allRecords;
      });
    } catch (e) {
      print('Error calculating daily balances: $e');
    }
  }

  Future<void> _loadSelectedDayTransactions(DateTime day) async {
    try {
      final supabase = Supabase.instance.client;
      final startOfDay = DateTime(day.year, day.month, day.day);
      final endOfDay = DateTime(day.year, day.month, day.day, 23, 59, 59);

      // Fetch transactions for the selected day
      final transactionResponse = await supabase
          .from('Transaction')
          .select('*, Category(name, icon), Account(accountName, iconImage)')
          .eq('ledgerId', _selectedLedgerId ?? '')
          .gte('date', startOfDay.toIso8601String())
          .lte('date', endOfDay.toIso8601String())
          .order('date', ascending: false);

      // Fetch transfers for the same day (without Account joins to avoid PostgreSQL aliasing issues)
      final transferResponse = await supabase
          .from('Transfer')
          .select('*')
          .gte('date', startOfDay.toIso8601String())
          .lte('date', endOfDay.toIso8601String())
          .order('date', ascending: false);

      // Fetch all accounts for enriching transfer data
      final accountsResponse = await supabase
          .from('Account')
          .select('accountId, accountName, iconImage');

      final accountsMap = {
        for (var account in accountsResponse) account['accountId']: account,
      };

      List<Map<String, dynamic>> allRecords = [];

      // Process transactions
      for (var transaction in transactionResponse) {
        allRecords.add(transaction);
      }

      // Process transfers - add account data for from and to accounts
      for (var transfer in transferResponse) {
        final enrichedTransfer = Map<String, dynamic>.from(transfer);
        enrichedTransfer['recordType'] = 'transfer';

        // Add account data for from and to accounts
        enrichedTransfer['Account!fromAccountId'] =
            accountsMap[transfer['fromAccountId']] ?? {};
        enrichedTransfer['Account!toAccountId'] =
            accountsMap[transfer['toAccountId']] ?? {};

        allRecords.add(enrichedTransfer);
      }

      // Sort all records by date
      allRecords.sort((a, b) {
        final dateA = DateTime.parse(a['date'] ?? '');
        final dateB = DateTime.parse(b['date'] ?? '');
        return dateB.compareTo(dateA);
      });

      setState(() {
        _selectedDayTransactions = allRecords;
        _selectedCalendarDay = day;
      });
    } catch (e) {
      print('Error loading day transactions: $e');
    }
  }

  void _previousMonth() {
    setState(() {
      final prevDate = DateTime(_selectedDate.year, _selectedDate.month - 1, 1);
      _selectedDate = prevDate;
      if (_isCalendarView) {
        _calendarDate = prevDate;
        _selectedCalendarDay = null;
        _selectedDayTransactions = [];
      }
    });
    if (_isCalendarView) {
      _calculateDailyBalances();
    } else {
      _fetchTransactions();
    }
  }

  void _nextMonth() {
    setState(() {
      final nextDate = DateTime(_selectedDate.year, _selectedDate.month + 1, 1);
      _selectedDate = nextDate;
      if (_isCalendarView) {
        _calendarDate = nextDate;
        _selectedCalendarDay = null;
        _selectedDayTransactions = [];
      }
    });
    if (_isCalendarView) {
      _calculateDailyBalances();
    } else {
      _fetchTransactions();
    }
  }

  /// Check and create auto-deduction transfers for active cycle-based savings goals
  Future<void> _checkAutoDeductions() async {
    if (_currentUserId == null) return;

    try {
      // First, check for regular auto-deductions
      final result = await AutoDeductionService.checkAndCreateAutoDeductions(
        _currentUserId!,
      );

      if (result['success'] == true && result['transfersCreated'] != null) {
        final transfersCreated = result['transfersCreated'] as int;
        if (transfersCreated > 0) {
          print('[HomeScreen] Auto-deductions created: $transfersCreated');
          // Refresh transactions to show newly created transfers
          await _fetchTransactions();

          // Show success dialog
          if (mounted) {
            _showAutoDeductionSuccessDialog(transfersCreated);
          }
        }
      }

      // Then, check for missing transfers (if not already shown this session)
      if (!_missingTransferAlertShown && mounted) {
        _checkForMissingTransfersAlert();
      }
    } catch (e) {
      print('[HomeScreen] Error checking auto-deductions: $e');
    }
  }

  void _showAutoDeductionSuccessDialog(int count) {
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
                  '✅ Auto-Deductions Successful!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFF39C12),
                  ),
                ),
                const SizedBox(height: 12),
                // Success message
                Text(
                  'Successfully created $count auto-deduction transfer${count > 1 ? 's' : ''}.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF666666),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                // Done button
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
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _checkForMissingTransfersAlert() async {
    if (_currentUserId == null) return;

    try {
      print('[HomeScreen] Checking for missing transfers...');

      // Check all goals for missing transfers
      final missingList =
          await MissingTransferAlertService.checkAllMissingTransfers(
            _currentUserId!,
          );

      if (missingList.isNotEmpty && mounted && !_missingTransferAlertShown) {
        _missingTransferAlertShown = true;

        // Show alert for the first missing goal
        // If there are multiple, user will see them after handling previous ones
        final missingInfo = missingList.first;
        _showMissingTransferAlertDialog(missingInfo);
      }
    } catch (e) {
      print('[HomeScreen] Error checking missing transfers: $e');
    }
  }

  void _showMissingTransferAlertDialog(Map<String, dynamic> missingInfo) {
    if (!mounted) return;

    final message = MissingTransferAlertService.generateAlertMessage(
      missingInfo,
    );
    final goalId = missingInfo['goalId'] as String;
    final goalName = missingInfo['goalName'] ?? 'Unnamed Goal';

    showDialog(
      context: context,
      barrierDismissible: false, // Force user to make a choice
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            '💰 Missing Transfers Detected',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Text(
              message,
              style: const TextStyle(fontSize: 14, height: 1.6),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                // User chose "Not Now" - dismiss alert for this session
                MissingTransferAlertService.dismissAlertForSession(
                  _currentUserId!,
                  goalId,
                );
                Navigator.of(context).pop();
                print('[HomeScreen] User dismissed missing transfer alert');
              },
              child: const Text(
                'Not Now',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();

                // Save navigator AND scaffoldMessenger BEFORE any async operations
                final navigator = Navigator.of(context);
                final scaffoldMessenger = ScaffoldMessenger.of(context);

                // Show loading indicator
                if (mounted) {
                  print(
                    '[HomeScreen] Showing loading dialog for missing transfers...',
                  );
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (BuildContext dialogContext) {
                      return const AlertDialog(
                        content: Row(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(width: 16),
                            Text('Creating missing transfers...'),
                          ],
                        ),
                      );
                    },
                  );
                }

                try {
                  // Process missing transfers
                  print('[HomeScreen] Processing missing transfers...');
                  final created =
                      await MissingTransferAlertService.processMissingTransfers(
                        missingInfo,
                      );

                  print(
                    '[HomeScreen] Created $created missing transfers, waiting 3 seconds...',
                  );

                  // Wait 3 seconds for database to settle
                  await Future.delayed(const Duration(seconds: 3));

                  // Refresh transactions from database
                  print(
                    '[HomeScreen] Refreshing transactions from database...',
                  );
                  if (mounted) {
                    await _fetchTransactions();
                  }

                  print(
                    '[HomeScreen] Waiting 3 more seconds before checking status...',
                  );

                  // Wait another 3 seconds before checking
                  await Future.delayed(const Duration(seconds: 3));

                  // Check if missing transfers still exist
                  print(
                    '[HomeScreen] Checking if missing transfers still exist...',
                  );
                  if (!mounted) {
                    print('[HomeScreen] Widget unmounted, returning early');
                    return;
                  }
                  if (_currentUserId == null) {
                    print('[HomeScreen] UserId is null, returning early');
                    return;
                  }

                  final missingList =
                      await MissingTransferAlertService.checkAllMissingTransfers(
                        _currentUserId!,
                      );

                  print(
                    '[HomeScreen] Missing transfers check result: ${missingList.length} remaining',
                  );

                  if (!mounted) {
                    print(
                      '[HomeScreen] Widget unmounted before closing dialog',
                    );
                    return;
                  }

                  // Close loading dialog using saved navigator state
                  print('[HomeScreen] Attempting to close loading dialog...');
                  try {
                    navigator.pop();
                    print('[HomeScreen] Loading dialog closed successfully');
                  } catch (e) {
                    print('[HomeScreen] Error closing loading dialog: $e');
                  }

                  await Future.delayed(const Duration(milliseconds: 200));

                  if (missingList.isEmpty) {
                    // ✅ No more missing transfers - show success
                    print(
                      '[HomeScreen] All missing transfers resolved! Showing success message...',
                    );

                    _missingTransferAlertShown = false;

                    // Show success using SnackBar with saved ScaffoldMessenger
                    try {
                      scaffoldMessenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            '✅ Successfully created and verified $created transfer(s) for $goalName',
                          ),
                          backgroundColor: Colors.green,
                          duration: const Duration(seconds: 4),
                        ),
                      );
                      print('[HomeScreen] Success SnackBar shown');
                    } catch (e) {
                      print('[HomeScreen] Error showing SnackBar: $e');
                    }

                    // Refresh transactions
                    print(
                      '[HomeScreen] Refreshing transactions after success...',
                    );
                    if (mounted) {
                      _fetchTransactions();
                    }
                  } else {
                    // ❌ Missing transfers still exist - retry
                    print(
                      '[HomeScreen] Missing transfers still exist (${missingList.length}), retrying...',
                    );

                    if (mounted) {
                      _showMissingTransferAlertDialog(missingList.first);
                    }
                  }
                } catch (e) {
                  print(
                    '[HomeScreen] Exception in missing transfer creation: $e',
                  );
                  // Close loading dialog using saved navigator state
                  try {
                    navigator.pop();
                    print('[HomeScreen] Loading dialog closed (error path)');
                  } catch (e2) {
                    print('[HomeScreen] Error closing dialog: $e2');
                  }

                  // Show error using saved ScaffoldMessenger
                  try {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text('❌ Error: $e'),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  } catch (e2) {
                    print('[HomeScreen] Error showing error SnackBar: $e2');
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text(
                'Yes, Auto-Deduct All',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _checkBudgetAlertFlags() async {
    try {
      // Check if any budget has isAlert = true (yellow/orange badge)
      final budgets = await Supabase.instance.client
          .from('Budget')
          .select('isAlert, isWarning')
          .eq('userId', _currentUserId ?? widget.userId);

      bool hasAlert = false;
      bool hasWarning = false;

      for (var budget in budgets) {
        if (budget['isAlert'] == true) {
          hasAlert = true;
        }
        if (budget['isWarning'] == true) {
          hasWarning = true;
        }
      }

      setState(() {
        _hasBudgetAlert = hasAlert;
        _hasBudgetCaution = hasWarning;
      });

      print(
        '[HomeScreen] Badge status: isAlert=$hasAlert, isWarning=$hasWarning',
      );
    } catch (e) {
      print('Error checking budget alert flags: $e');
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
          .eq('userId', _currentUserId ?? widget.userId);

      final alertService = BudgetAlertService();
      final Map<String, double> budgetUsageMap = {};

      // Calculate all budget usage percentages
      for (var budget in budgets) {
        final double usagePercentage = await _calculateBudgetUsage(budget);
        budgetUsageMap[budget['budgetId']] = usagePercentage;
      }

      // Check if any budget has caution alert using the new service
      final hasCaution = await alertService.hasAnyCautionAlert(
        _currentUserId ?? widget.userId,
        budgetUsageMap,
      );

      setState(() {
        _hasBudgetCaution = hasCaution;
      });

      // Notify global service for real-time updates across all pages
      AlertStatusService().updateCautionAlertStatus(hasCaution);
    } catch (e) {
      print('Error checking budget caution: $e');
    }
  }

  /// Update budget isAlert and isWarning flags after a transaction is added
  /// This method calculates budget usage per cycle type and updates flags
  Future<void> _updateBudgetFlagsAfterTransaction() async {
    try {
      print('[HomeScreen] === Starting budget flag updates ===');

      final budgets = await Supabase.instance.client
          .from('Budget')
          .select()
          .eq('userId', _currentUserId ?? widget.userId);

      if (budgets.isEmpty) {
        print('[HomeScreen] No budgets found for user');
        return;
      }

      final alertService = BudgetAlertService();
      bool hasCautionAlert = false;
      bool hasExceedAlert = false;

      for (var budget in budgets) {
        final budgetId = budget['budgetId'];
        final budgetType = budget['type'] ?? '';
        final budgetAmount = (budget['amount'] ?? 0).toDouble();
        final cycleType = (budget['cycleType'] ?? 'month').toLowerCase();

        if (budgetAmount <= 0) {
          print('[HomeScreen] Skipping budget $budgetId: invalid amount');
          continue;
        }

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

        // Fetch transactions based on budget type (excluding refunds)
        List<dynamic> transactions = [];

        if (budgetType == 'account') {
          final accountId = budget['accountId'];
          if (accountId != null) {
            transactions = await Supabase.instance.client
                .from('Transaction')
                .select()
                .eq('accountId', accountId)
                .eq(
                  'type',
                  'expense',
                ) // Only expenses, exclude income/transfers
                .gte('date', startDate.toIso8601String());
          }
        } else if (budgetType == 'category') {
          final categoryId = budget['categoryId'];
          if (categoryId != null) {
            transactions = await Supabase.instance.client
                .from('Transaction')
                .select()
                .eq('categoryId', categoryId)
                .eq('type', 'expense') // Only expenses
                .gte('date', startDate.toIso8601String());
          }
        } else if (budgetType == 'ledger') {
          final ledgerId = budget['ledgerId'];
          if (ledgerId != null) {
            transactions = await Supabase.instance.client
                .from('Transaction')
                .select()
                .eq('ledgerId', ledgerId)
                .eq('type', 'expense') // Only expenses
                .gte('date', startDate.toIso8601String());
          }
        }

        // Sum up transaction amounts (excluding refunded transactions)
        double totalSpent = 0;
        for (var transaction in transactions) {
          // Skip refunded transactions
          if (transaction['refund'] == true) {
            print(
              '[HomeScreen] Skipping refunded transaction: ${transaction['transactionId']}',
            );
            continue;
          }
          totalSpent += ((transaction['amount'] ?? 0) as num).toDouble();
        }

        final double usagePercentage = (totalSpent / budgetAmount) * 100;

        print(
          '[HomeScreen] Budget $budgetId ($budgetType, $cycleType): $totalSpent / $budgetAmount = ${usagePercentage.toStringAsFixed(1)}%',
        );

        // Update alert flags based on usage
        await alertService.updateAlertFlags(budgetId, usagePercentage);

        // Track if we have any caution or exceed alerts
        if (usagePercentage >= 100) {
          hasExceedAlert = true;
        } else if (usagePercentage >= 70) {
          hasCautionAlert = true;
        }
      }

      print(
        '[HomeScreen] Budget check complete: hasCaution=$hasCautionAlert, hasExceed=$hasExceedAlert',
      );

      // Update local state
      setState(() {
        _hasBudgetCaution = hasCautionAlert;
        _hasBudgetAlert = hasExceedAlert;
      });

      // Notify all pages in real-time
      AlertStatusService().updateCautionAlertStatus(hasCautionAlert);
      AlertStatusService().updateHighRiskAlertStatus(hasExceedAlert);

      print('[HomeScreen] === Budget flag updates complete ===');
    } catch (e) {
      print('[HomeScreen] Error updating budget flags: $e');
    }
  }

  /// Update budget flags only for budgets related to a specific transaction
  /// This prevents showing alerts for unrelated budget categories
  Future<void> _updateBudgetFlagsForTransaction(
    Map<String, dynamic> transaction,
  ) async {
    try {
      print('[HomeScreen] === Starting targeted budget flag updates ===');

      final categoryId = transaction['categoryId'];
      final ledgerId = transaction['ledgerId'];
      final accountId = transaction['accountId'];

      print(
        '[HomeScreen] Transaction refs - Category: $categoryId, Ledger: $ledgerId, Account: $accountId',
      );

      // Get ALL budgets for this user first
      final allBudgets = await Supabase.instance.client
          .from('Budget')
          .select()
          .eq('userId', _currentUserId ?? widget.userId);

      if (allBudgets.isEmpty) {
        print('[HomeScreen] No budgets related to this transaction');
        // Clear flags if no related budgets exist
        setState(() {
          _hasBudgetCaution = false;
          _hasBudgetAlert = false;
        });
        AlertStatusService().updateCautionAlertStatus(false);
        AlertStatusService().updateHighRiskAlertStatus(false);
        return;
      }

      // Filter to ONLY include budgets that are actually related to this transaction
      final relatedBudgets = <Map<String, dynamic>>[];
      for (var budget in allBudgets) {
        final budgetType = budget['type'] ?? '';
        bool isRelated = false;

        // Check if budget is related based on its type
        if (budgetType == 'category') {
          // Category budget: only include if transaction has matching categoryId
          isRelated = budget['categoryId'] == categoryId && categoryId != null;
        } else if (budgetType == 'ledger') {
          // Ledger budget: only include if transaction has matching ledgerId
          isRelated = budget['ledgerId'] == ledgerId && ledgerId != null;
        } else if (budgetType == 'account') {
          // Account budget: only include if transaction has matching accountId
          isRelated = budget['accountId'] == accountId && accountId != null;
        }

        if (isRelated) {
          relatedBudgets.add(budget);
          print(
            '[HomeScreen] Budget ${budget['budgetId']} ($budgetType) is related to this transaction',
          );
        }
      }

      if (relatedBudgets.isEmpty) {
        print('[HomeScreen] No related budgets found');
        // Clear flags if no related budgets exist
        setState(() {
          _hasBudgetCaution = false;
          _hasBudgetAlert = false;
        });
        AlertStatusService().updateCautionAlertStatus(false);
        AlertStatusService().updateHighRiskAlertStatus(false);
        return;
      }

      print('[HomeScreen] Found ${relatedBudgets.length} related budgets');

      final alertService = BudgetAlertService();
      bool hasCautionAlert = false;
      bool hasExceedAlert = false;

      for (var budget in relatedBudgets) {
        final budgetId = budget['budgetId'];
        final budgetType = budget['type'] ?? '';
        final budgetAmount = (budget['amount'] ?? 0).toDouble();
        final cycleType = (budget['cycleType'] ?? 'month').toLowerCase();

        if (budgetAmount <= 0) continue;

        // Calculate date range
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

        // Fetch transactions for this specific budget based on its type
        List<dynamic> transactions = [];

        if (budgetType == 'account') {
          final budgetAccountId = budget['accountId'];
          transactions = await Supabase.instance.client
              .from('Transaction')
              .select()
              .eq('accountId', budgetAccountId)
              .eq('type', 'expense')
              .gte('date', startDate.toIso8601String());
        } else if (budgetType == 'category') {
          final budgetCategoryId = budget['categoryId'];
          transactions = await Supabase.instance.client
              .from('Transaction')
              .select()
              .eq('categoryId', budgetCategoryId)
              .eq('type', 'expense')
              .gte('date', startDate.toIso8601String());
        } else if (budgetType == 'ledger') {
          final budgetLedgerId = budget['ledgerId'];
          transactions = await Supabase.instance.client
              .from('Transaction')
              .select()
              .eq('ledgerId', budgetLedgerId)
              .eq('type', 'expense')
              .gte('date', startDate.toIso8601String());
        }

        // Calculate spending (excluding refunded)
        double totalSpent = 0;
        for (var txn in transactions) {
          if (txn['refund'] != true) {
            totalSpent += ((txn['amount'] ?? 0) as num).toDouble();
          }
        }

        final double usagePercentage = (totalSpent / budgetAmount) * 100;

        print(
          '[HomeScreen] Related Budget $budgetId ($budgetType): $totalSpent / $budgetAmount = ${usagePercentage.toStringAsFixed(1)}%',
        );

        // Update alert flags
        await alertService.updateAlertFlags(budgetId, usagePercentage);

        if (usagePercentage >= 100) {
          hasExceedAlert = true;
        } else if (usagePercentage >= 70) {
          hasCautionAlert = true;
        }
      }

      print(
        '[HomeScreen] Targeted budget check: hasCaution=$hasCautionAlert, hasExceed=$hasExceedAlert',
      );

      // Update state and notify
      setState(() {
        _hasBudgetCaution = hasCautionAlert;
        _hasBudgetAlert = hasExceedAlert;
      });

      AlertStatusService().updateCautionAlertStatus(hasCautionAlert);
      AlertStatusService().updateHighRiskAlertStatus(hasExceedAlert);

      print('[HomeScreen] === Targeted budget flag updates complete ===');
    } catch (e) {
      print('[HomeScreen] Error in targeted budget updates: $e');
    }
  }

  String _getDayOfWeek(DateTime date) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[date.weekday - 1];
  }

  String _getMonthName(int month) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }

  IconData _getIconData(String iconName) {
    final iconMap = {
      'shopping_bag': Icons.shopping_bag,
      'restaurant': Icons.restaurant,
      'local_taxi': Icons.local_taxi,
      'local_gas_station': Icons.local_gas_station,
      'movie': Icons.movie,
      'shopping_cart': Icons.shopping_cart,
      'health_and_safety': Icons.health_and_safety,
      'school': Icons.school,
      'airplane': Icons.flight,
      'home': Icons.home,
      'phone': Icons.phone,
      'electric_bolt': Icons.electric_bolt,
      'water': Icons.water,
      'sports_bar': Icons.sports_bar,
      'entertainment': Icons.theaters,
      'fitness_center': Icons.fitness_center,
      'book': Icons.book,
      'pets': Icons.pets,
      'card_giftcard': Icons.card_giftcard,
      'savings': Icons.savings,
      'trending_up': Icons.trending_up,
      'currency_pound': Icons.currency_pound,
    };
    return iconMap[iconName] ?? Icons.shopping_bag;
  }

  Widget _buildCategoryImage(String? iconUrl) {
    // If iconUrl is a URL (starts with http), display it as an image
    if (iconUrl != null &&
        iconUrl.isNotEmpty &&
        (iconUrl.startsWith('http') || iconUrl.startsWith('/'))) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          iconUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: Icon(Icons.shopping_bag, color: Colors.white, size: 20),
            );
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            );
          },
        ),
      );
    }
    // Otherwise, treat it as an icon name
    return Center(
      child: Icon(
        _getIconData(iconUrl ?? 'shopping_bag'),
        color: Colors.white,
        size: 20,
      ),
    );
  }

  List<Widget> _buildTransferAccountIcons(
    Map<String, dynamic>? fromAccount,
    Map<String, dynamic>? toAccount,
  ) {
    final List<Widget> icons = [];

    // From Account Icon
    if (fromAccount != null) {
      final iconImage = fromAccount['iconImage'] ?? '';
      icons.add(
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFFFE5B4), width: 1),
          ),
          child: ClipOval(
            child: iconImage.isNotEmpty
                ? Image.network(
                    iconImage,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[300],
                        child: const Icon(Icons.account_balance, size: 10),
                      );
                    },
                  )
                : Container(
                    color: Colors.grey[300],
                    child: const Icon(Icons.account_balance, size: 10),
                  ),
          ),
        ),
      );
    }

    // Arrow Icon
    icons.add(const SizedBox(width: 4));
    icons.add(const Icon(Icons.arrow_forward, size: 14, color: Colors.grey));
    icons.add(const SizedBox(width: 4));

    // To Account Icon
    if (toAccount != null) {
      final iconImage = toAccount['iconImage'] ?? '';
      icons.add(
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFFFE5B4), width: 1),
          ),
          child: ClipOval(
            child: iconImage.isNotEmpty
                ? Image.network(
                    iconImage,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[300],
                        child: const Icon(Icons.account_balance, size: 10),
                      );
                    },
                  )
                : Container(
                    color: Colors.grey[300],
                    child: const Icon(Icons.account_balance, size: 10),
                  ),
          ),
        ),
      );
    }

    return icons;
  }

  Widget _buildCalendarView() {
    final firstDayOfMonth = DateTime(
      _calendarDate.year,
      _calendarDate.month,
      1,
    );
    final lastDayOfMonth = DateTime(
      _calendarDate.year,
      _calendarDate.month + 1,
      0,
    );
    final daysInMonth = lastDayOfMonth.day;
    final firstWeekday = firstDayOfMonth.weekday;

    final dayLabels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    return Column(
      children: [
        // Month Navigation and Calendar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF9E6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFFE5B4), width: 2),
          ),
          child: Column(
            children: [
              // Month Header with Navigation
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: _previousMonth,
                    child: const Icon(Icons.arrow_back_ios, size: 20),
                  ),
                  GestureDetector(
                    onTap: _showMonthYearPicker,
                    child: Row(
                      children: [
                        Text(
                          '${_getMonthName(_calendarDate.month)} ${_calendarDate.year}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_drop_down, color: Colors.black),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _nextMonth,
                    child: const Icon(Icons.arrow_forward_ios, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Day Labels
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: dayLabels
                    .asMap()
                    .entries
                    .map(
                      (entry) => SizedBox(
                        width: 40,
                        child: Center(
                          child: Text(
                            entry.value,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: entry.key == 0 || entry.key == 6
                                  ? const Color(0xFFE74C3C)
                                  : const Color(0xFFBCBCBC),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 8),
              // Calendar Grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  childAspectRatio: 1.1,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                ),
                itemCount: daysInMonth + (firstWeekday),
                itemBuilder: (context, index) {
                  if (index < firstWeekday) {
                    return const SizedBox();
                  }

                  final day = index - firstWeekday + 1;
                  final dateKey =
                      '${_calendarDate.year}-${_calendarDate.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

                  // Get value based on filter
                  double displayValue = 0;
                  if (_calendarFilter == 'Total') {
                    displayValue = _dailyBalances[dateKey] ?? 0;
                  } else if (_calendarFilter == 'Income') {
                    displayValue = _dailyIncome[dateKey] ?? 0;
                  } else if (_calendarFilter == 'Expenses') {
                    displayValue = _dailyExpense[dateKey] ?? 0;
                  }

                  final isSelected =
                      _selectedCalendarDay?.day == day &&
                      _selectedCalendarDay?.month == _calendarDate.month &&
                      _selectedCalendarDay?.year == _calendarDate.year;

                  return GestureDetector(
                    onTap: () {
                      final selectedDay = DateTime(
                        _calendarDate.year,
                        _calendarDate.month,
                        day,
                      );
                      // Toggle: if already selected, deselect and show all month
                      if (isSelected) {
                        setState(() {
                          _selectedCalendarDay = null;
                          _selectedDayTransactions = [];
                        });
                      } else {
                        _loadSelectedDayTransactions(selectedDay);
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFA7E399)
                            : const Color(0xFFFFF9E6),
                        borderRadius: BorderRadius.circular(6),
                        border: isSelected
                            ? Border.all(
                                color: const Color(0xFFA7E399),
                                width: 2,
                              )
                            : Border.all(
                                color: const Color(0xFFFFE5B4),
                                width: 1,
                              ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            day.toString(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? Colors.white : Colors.black,
                            ),
                          ),
                          const SizedBox(height: 2),
                          // Display value with proper formatting
                          if (displayValue != 0)
                            SizedBox(
                              height: 16,
                              child: Text(
                                displayValue >= 0
                                    ? '${displayValue.toStringAsFixed(0)}'
                                    : '${displayValue.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: _calendarFilter == 'Expenses'
                                      ? const Color(
                                          0xFFE74C3C,
                                        ) // Always red for expenses
                                      : _calendarFilter == 'Income'
                                      ? const Color(
                                          0xFF52C77A,
                                        ) // Always green for income
                                      : displayValue <
                                            0 // For Total: red if negative, green if positive
                                      ? const Color(0xFFE74C3C)
                                      : const Color(0xFF52C77A),
                                ),
                              ),
                            )
                          else
                            const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              // Filter Tabs
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFFFE5B4), width: 2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: ['Expenses', 'Income', 'Total'].map((filter) {
                    final isSelected = _calendarFilter == filter;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _calendarFilter = filter;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFA7E399)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          filter,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.black : Colors.grey[600],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Transactions - Show all month if no day selected, or selected day if chosen
        if (_transactions.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No transactions for this month',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ),
          )
        else if (_selectedCalendarDay == null)
          _buildGroupedTransactionsList()
        else if (_selectedDayTransactions.isNotEmpty)
          _buildSelectedDayTransactionsList()
        else
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No transactions for this day',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSelectedDayTransactionsList() {
    final date = _selectedCalendarDay!;

    // Calculate daily income and expense (excluding transfers and refunded transactions)
    double dayIncome = 0;
    double dayExpense = 0;
    for (var txn in _selectedDayTransactions) {
      final amount = double.tryParse(txn['amount'].toString()) ?? 0;
      final type = txn['type']?.toString().toLowerCase() ?? 'expense';
      final isTransfer = txn['recordType'] == 'transfer';
      final isRefunded = txn['refund'] == true;
      if (!isTransfer && !isRefunded) {
        if (type == 'income') {
          dayIncome += amount;
        } else {
          dayExpense += amount;
        }
      }
    }

    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9E6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFE5B4), width: 1),
      ),
      child: Column(
        children: [
          // Date Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFAE6),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(11),
                topRight: Radius.circular(11),
              ),
              border: Border(
                bottom: BorderSide(color: const Color(0xFFFFE5B4), width: 1),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_getDayOfWeek(date)}, ${date.day.toString().padLeft(2, '0')} ${_getMonthName(date.month)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                Row(
                  children: [
                    if (dayIncome > 0)
                      Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: Text(
                          'IN RM${dayIncome.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF52C77A),
                          ),
                        ),
                      ),
                    if (dayExpense > 0)
                      Text(
                        'OUT RM${dayExpense.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFE74C3C),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          // Transaction Items
          ..._selectedDayTransactions.asMap().entries.map((entry) {
            final txnIndex = entry.key;
            final transaction = entry.value;
            final amount =
                double.tryParse(transaction['amount'].toString()) ?? 0;
            final type =
                transaction['type']?.toString().toLowerCase() ?? 'expense';

            final isTransfer = transaction['recordType'] == 'transfer';

            String displayName = '';
            String displayIcon = 'shopping_bag';
            String displayNote = '';

            if (isTransfer) {
              displayName = 'Transfer';
              displayNote = transaction['note'] ?? '';
              displayIcon = 'transfer_icon';
            } else {
              final categoryData = transaction['Category'] ?? {};
              displayName = categoryData['name'] ?? 'Category';
              displayIcon = categoryData['icon'] ?? 'shopping_bag';
              displayNote = transaction['note'] ?? '';
            }

            final accountData = transaction['Account'] ?? {};
            final accountLogo = accountData['iconImage'] ?? '';
            final isRefunded = transaction['refund'] == true;
            final isLastItem = txnIndex == _selectedDayTransactions.length - 1;

            return Column(
              children: [
                GestureDetector(
                  onTap: () async {
                    if (isTransfer) {
                      final transferId = transaction['transferId'] as String;
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TransferDetailScreen(
                            transferId: transferId,
                            userId: _currentUserId,
                          ),
                        ),
                      );
                      if (result == true) {
                        await _calculateDailyBalances();
                      }
                    } else {
                      final transactionId =
                          transaction['transactionId'] as String;
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TransactionDetailScreen(
                            transactionId: transactionId,
                            userId: _currentUserId,
                          ),
                        ),
                      );
                      if (result == true) {
                        await _calculateDailyBalances();
                        // Only update budget flags for expense transactions related to budgets
                        if (type == 'expense') {
                          await _updateBudgetFlagsForTransaction(transaction);
                        }
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Category Icon
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF9E6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: isTransfer
                              ? const Icon(
                                  Icons.compare_arrows,
                                  color: Colors.black,
                                  size: 28,
                                )
                              : _buildCategoryImage(displayIcon),
                        ),
                        const SizedBox(width: 12),
                        // Category Name and Note
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                displayName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                ),
                              ),
                              if (displayNote.isNotEmpty)
                                Text(
                                  displayNote,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFFBCBCBC),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Right side: Amount, Account Icon, and Refund Badge
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Amount
                                Text(
                                  isTransfer
                                      ? 'RM${amount.toStringAsFixed(2)}'
                                      : '${type == 'income' ? '+' : '-'}RM${amount.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: isTransfer
                                        ? Colors.black
                                        : (type == 'income'
                                              ? const Color(0xFF52C77A)
                                              : const Color(0xFFE74C3C)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Account Icons for transfer or single account for transaction
                                if (isTransfer)
                                  ..._buildTransferAccountIcons(
                                    transaction['Account!fromAccountId'],
                                    transaction['Account!toAccountId'],
                                  )
                                else if (accountLogo.isNotEmpty)
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: const Color(0xFFFFE5B4),
                                        width: 1,
                                      ),
                                    ),
                                    child: ClipOval(
                                      child: Image.network(
                                        accountLogo,
                                        fit: BoxFit.contain,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                              return Container(
                                                decoration: BoxDecoration(
                                                  color: Colors.grey[300],
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.account_balance,
                                                  size: 12,
                                                ),
                                              );
                                            },
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            // Refund Badge below amount and account icon
                            if (isRefunded)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFE5B4),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'REFUNDED',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFE74C3C),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // Divider between transactions (but not after last one)
                if (!isLastItem)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Divider(
                      color: const Color(0xFFFFE5B4),
                      height: 1,
                      thickness: 1,
                    ),
                  ),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildGroupedTransactionsList() {
    // Group transactions by date
    Map<String, List<Map<String, dynamic>>> groupedByDate = {};
    for (var transaction in _transactions) {
      final date = transaction['date'] != null
          ? DateTime.parse(transaction['date'])
          : DateTime.now();
      final dateKey =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      if (!groupedByDate.containsKey(dateKey)) {
        groupedByDate[dateKey] = [];
      }
      groupedByDate[dateKey]!.add(transaction);
    }

    // Sort dates in descending order (latest first)
    final sortedDates = groupedByDate.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sortedDates.length,
      itemBuilder: (context, index) {
        final dateKey = sortedDates[index];
        final dateTransactions = groupedByDate[dateKey]!;
        final date = DateTime.parse(dateTransactions[0]['date']);

        // Calculate daily income and expense separately (excluding transfers and refunded transactions)
        double dayIncome = 0;
        double dayExpense = 0;
        for (var txn in dateTransactions) {
          final amount = double.tryParse(txn['amount'].toString()) ?? 0;
          final type = txn['type']?.toString().toLowerCase() ?? 'expense';
          final isTransfer = txn['recordType'] == 'transfer';
          final isRefunded = txn['refund'] == true;
          if (!isTransfer && !isRefunded) {
            if (type == 'income') {
              dayIncome += amount;
            } else {
              dayExpense += amount;
            }
          }
        }

        return Container(
          margin: const EdgeInsets.only(top: 12, bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF9E6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFFE5B4), width: 1),
          ),
          child: Column(
            children: [
              // Date Header
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFAE6),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(11),
                    topRight: Radius.circular(11),
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: const Color(0xFFFFE5B4),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_getDayOfWeek(date)}, ${date.day.toString().padLeft(2, '0')} ${_getMonthName(date.month)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    Row(
                      children: [
                        if (dayIncome > 0)
                          Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: Text(
                              'IN RM${dayIncome.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF52C77A),
                              ),
                            ),
                          ),
                        if (dayExpense > 0)
                          Text(
                            'OUT RM${dayExpense.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFE74C3C),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              // Transaction Items
              ...dateTransactions.asMap().entries.map((entry) {
                final txnIndex = entry.key;
                final transaction = entry.value;
                final amount =
                    double.tryParse(transaction['amount'].toString()) ?? 0;
                final type =
                    transaction['type']?.toString().toLowerCase() ?? 'expense';

                final isTransfer = transaction['recordType'] == 'transfer';

                String displayName = '';
                String displayIcon = 'shopping_bag';
                String displayNote = '';

                if (isTransfer) {
                  displayName = 'Transfer';
                  displayNote = transaction['note'] ?? '';
                  displayIcon = 'transfer_icon';
                } else {
                  final categoryData = transaction['Category'] ?? {};
                  displayName = categoryData['name'] ?? 'Category';
                  displayIcon = categoryData['icon'] ?? 'shopping_bag';
                  displayNote = transaction['note'] ?? '';
                }

                final accountData = transaction['Account'] ?? {};
                final accountLogo = accountData['iconImage'] ?? '';
                final isRefunded = transaction['refund'] == true;
                final isLastItem = txnIndex == dateTransactions.length - 1;

                return Column(
                  children: [
                    GestureDetector(
                      onTap: () async {
                        if (isTransfer) {
                          final transferId =
                              transaction['transferId'] as String;
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TransferDetailScreen(
                                transferId: transferId,
                                userId: _currentUserId,
                              ),
                            ),
                          );
                          if (result == true) {
                            await _fetchTransactions();
                          }
                        } else {
                          final transactionId =
                              transaction['transactionId'] as String;
                          print(
                            'Opening transaction detail for ID: $transactionId',
                          );
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TransactionDetailScreen(
                                transactionId: transactionId,
                                userId: _currentUserId,
                              ),
                            ),
                          );
                          // Refresh transactions if a transaction was deleted or refunded
                          if (result == true) {
                            await _fetchTransactions();
                            // Only update budget flags for expense transactions related to budgets
                            if (type == 'expense') {
                              await _updateBudgetFlagsForTransaction(
                                transaction,
                              );
                            }
                          }
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Category Icon
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF9E6),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: isTransfer
                                  ? const Icon(
                                      Icons.compare_arrows,
                                      color: Colors.black,
                                      size: 28,
                                    )
                                  : _buildCategoryImage(displayIcon),
                            ),
                            const SizedBox(width: 12),
                            // Category Name and Note
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    displayName,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black,
                                    ),
                                  ),
                                  if (displayNote.isNotEmpty)
                                    Text(
                                      displayNote,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFFBCBCBC),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Right side: Amount, Account Icon(s), and Refund Badge
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Amount
                                    Text(
                                      isTransfer
                                          ? 'RM${amount.toStringAsFixed(2)}'
                                          : '${type == 'income' ? '+' : '-'}RM${amount.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: isTransfer
                                            ? Colors.black
                                            : (type == 'income'
                                                  ? const Color(0xFF52C77A)
                                                  : const Color(0xFFE74C3C)),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Account Icons for transfer or single account for transaction
                                    if (isTransfer)
                                      ..._buildTransferAccountIcons(
                                        transaction['Account!fromAccountId'],
                                        transaction['Account!toAccountId'],
                                      )
                                    else if (accountLogo.isNotEmpty)
                                      Container(
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: const Color(0xFFFFE5B4),
                                            width: 1,
                                          ),
                                        ),
                                        child: ClipOval(
                                          child: Image.network(
                                            accountLogo,
                                            fit: BoxFit.contain,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                                  return Container(
                                                    decoration: BoxDecoration(
                                                      color: Colors.grey[300],
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: const Icon(
                                                      Icons.account_balance,
                                                      size: 12,
                                                    ),
                                                  );
                                                },
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                // Refund Badge below amount and account icon
                                if (isRefunded)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFE5B4),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'REFUNDED',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFE74C3C),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Divider between transactions (but not after last one)
                    if (!isLastItem)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Divider(
                          color: const Color(0xFFFFE5B4),
                          height: 1,
                          thickness: 1,
                        ),
                      ),
                  ],
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handlePetNavigation() async {
    try {
      final supabase = Supabase.instance.client;

      final response = await supabase
          .from('Pet')
          .select('petId') // 👈 only get petId
          .eq('userId', _currentUserId!)
          .maybeSingle();

      if (response != null) {
        final petId = response['petId'];

        // ✅ Navigate with petId
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                PetHomePage(userId: _currentUserId!, petId: petId),
          ),
        );
      } else {
        // ❌ No pet → go create page
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PetMainPage(userId: _currentUserId!),
          ),
        );
      }
    } catch (e) {
      print('Error checking pet: $e');
    }
  }

  List<Widget> _buildNavBadges() {
    // Position badge only on Budget icon (index 2)
    final badges = <Widget>[];
    const badgeIndex = 2; // Budget button
    const badgeSize = 20.0;
    const badgeTopOffset = 8.0;
    const badgeRightOffset = 12.0;

    if (!(_hasBudgetCaution || _hasBudgetAlert)) {
      return badges;
    }

    // Show isAlert (YELLOW/ORANGE) badge
    if (_hasBudgetAlert) {
      badges.add(
        Positioned(
          right: badgeRightOffset,
          top: badgeTopOffset,
          child: Container(
            width: badgeSize,
            height: badgeSize,
            decoration: BoxDecoration(
              color: Colors.orange.shade700, // YELLOW/ORANGE for isAlert
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(Icons.warning_rounded, color: Colors.white, size: 12),
            ),
          ),
        ),
      );
    }

    // Show isWarning (RED) badge
    if (_hasBudgetCaution) {
      badges.add(
        Positioned(
          right: badgeRightOffset,
          top: badgeTopOffset,
          child: Container(
            width: badgeSize,
            height: badgeSize,
            decoration: const BoxDecoration(
              color: Color(0xFFE53935), // RED for isWarning
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
      );
    }

    return badges;
  }

  void _showCautionAlertDialog() {
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
                      const Text(
                        'Budget Caution',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Your budget spending is over 70%. Please monitor your expenses to avoid exceeding your budget.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
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
                                      Navigator.pop(context);
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

  void _showAlertDialog() {
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
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFE5E5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.error_rounded,
                          color: Color(0xFFE53935),
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Budget Alert',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Your budget has been exceeded! Please review your expenses immediately.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Checkbox(
                            value: checkboxValue,
                            onChanged: (newValue) {
                              setDialogState(() {
                                checkboxValue = newValue ?? false;
                              });
                            },
                            activeColor: const Color(0xFFE53935),
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
                                      Navigator.pop(context);
                                    }
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE53935),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEFFD3),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFEFFD3),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            // Ledger Dropdown - Enhanced
            if (_isLoadingLedgers)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFA7E399).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFA7E399),
                    width: 1.5,
                  ),
                ),
                child: const SizedBox(
                  width: 120,
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFFA7E399),
                      ),
                    ),
                  ),
                ),
              )
            else
              PopupMenuButton<String>(
                onSelected: (newValue) {
                  setState(() {
                    _selectedLedgerId = newValue;
                  });
                  _fetchTransactions();
                },
                itemBuilder: (BuildContext context) {
                  return _ledgers.map((ledger) {
                    final ledgerId = ledger['ledgerId'] as String;
                    final ledgerName = ledger['name'] as String;
                    final isSelected = ledgerId == _selectedLedgerId;
                    return PopupMenuItem<String>(
                      value: ledgerId,
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFA7E399).withOpacity(0.2)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.book,
                              size: 18,
                              color: isSelected
                                  ? const Color(0xFFA7E399)
                                  : Colors.grey[600],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              ledgerName,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSelected
                                    ? const Color(0xFFA7E399)
                                    : Colors.black87,
                              ),
                            ),
                            if (isSelected) ...[
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.check,
                                size: 16,
                                color: Color(0xFFA7E399),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList();
                },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                color: Colors.white,
                elevation: 8,
                offset: const Offset(0, 40),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFFA7E399).withOpacity(0.15),
                        const Color(0xFFA7E399).withOpacity(0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFA7E399),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.book,
                        size: 18,
                        color: const Color(0xFFA7E399),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        (_ledgers.firstWhere(
                                  (l) => l['ledgerId'] == _selectedLedgerId,
                                  orElse: () => {'name': 'Select Ledger'},
                                )['name']
                                as String?) ??
                            'Select Ledger',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.arrow_drop_down,
                        size: 18,
                        color: Color(0xFFA7E399),
                      ),
                    ],
                  ),
                ),
              ),
            const Spacer(),
            // View Mode Toggle Button in AppBar
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFEFFD3),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFFFE5B4), width: 2),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (_isCalendarView) {
                        setState(() {
                          _isCalendarView = false;
                          _selectedDate = _calendarDate;
                        });
                        _fetchTransactions();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: !_isCalendarView
                            ? const Color(0xFFA7E399)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'List',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: !_isCalendarView
                              ? Colors.black
                              : Colors.grey[600],
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      if (!_isCalendarView) {
                        setState(() {
                          _isCalendarView = true;
                          _selectedCalendarDay = null;
                          _calendarDate = _selectedDate;
                        });
                        _calculateDailyBalances();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _isCalendarView
                            ? const Color(0xFFA7E399)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Calendar',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _isCalendarView
                              ? Colors.black
                              : Colors.grey[600],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        titleSpacing: 16,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _ledgers.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: const Color(0xFFA7E399).withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.book_rounded,
                          size: 50,
                          color: Color(0xFFA7E399),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'No Ledger Found',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF333333),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'You need to create a ledger to start recording your transactions.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF999999),
                        height: 1.6,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  LedgerManager(userId: widget.userId),
                            ),
                          ).then((_) {
                            _fetchLedgers();
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFA7E399),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Create Your First Ledger',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date and Summary Card - Only in List View
                    if (!_isCalendarView)
                      Column(
                        children: [
                          // Date Navigation Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              GestureDetector(
                                onTap: _previousMonth,
                                child: const Icon(
                                  Icons.arrow_back_ios,
                                  size: 20,
                                  color: Colors.black,
                                ),
                              ),
                              GestureDetector(
                                onTap: _showMonthYearPicker,
                                child: Row(
                                  children: [
                                    Text(
                                      '${_selectedDate.month} / ${_selectedDate.year}',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(
                                      Icons.arrow_drop_down,
                                      color: Colors.black,
                                    ),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: _nextMonth,
                                child: const Icon(
                                  Icons.arrow_forward_ios,
                                  size: 20,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Premium Card Design - Green Base
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFFA7E399), Color(0xFFC8F7DC)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFFA7E399,
                                  ).withOpacity(0.3),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Card Header with Title and Visibility Toggle
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Balance Overview',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _showAmounts = !_showAmounts;
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.3),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Icon(
                                          _showAmounts
                                              ? Icons.visibility
                                              : Icons.visibility_off,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                // Total Balance (Large)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Total Balance',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white.withOpacity(0.85),
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _showAmounts
                                          ? 'RM${_totalAmount.toStringAsFixed(2)}'
                                          : '****',
                                      style: const TextStyle(
                                        fontSize: 36,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                // Income and Expense Row
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Income Card
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFFE8F8F0),
                                            width: 1.5,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(
                                                0xFF52C77A,
                                              ).withOpacity(0.08),
                                              blurRadius: 10,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: const Color(
                                                  0xFF52C77A,
                                                ).withOpacity(0.12),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: const Icon(
                                                Icons.trending_down_rounded,
                                                color: Color(0xFF52C77A),
                                                size: 18,
                                              ),
                                            ),
                                            const SizedBox(height: 10),
                                            Text(
                                              'Income',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.black.withOpacity(
                                                  0.7,
                                                ),
                                                letterSpacing: 0.2,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              _showAmounts
                                                  ? 'RM${_incomeAmount.toStringAsFixed(2)}'
                                                  : '****',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF52C77A),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // Expense Card
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFFFAE8E3),
                                            width: 1.5,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(
                                                0xFFE74C3C,
                                              ).withOpacity(0.08),
                                              blurRadius: 10,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: const Color(
                                                  0xFFE74C3C,
                                                ).withOpacity(0.12),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: const Icon(
                                                Icons.trending_up_rounded,
                                                color: Color(0xFFE74C3C),
                                                size: 18,
                                              ),
                                            ),
                                            const SizedBox(height: 10),
                                            Text(
                                              'Expense',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.black.withOpacity(
                                                  0.7,
                                                ),
                                                letterSpacing: 0.2,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              _showAmounts
                                                  ? 'RM${_expenseAmount.toStringAsFixed(2)}'
                                                  : '****',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFFE74C3C),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 16),
                    // Conditional View: Calendar or Transactions List
                    if (_isCalendarView)
                      _buildCalendarView()
                    else if (_transactions.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Text(
                            'No transactions for this month',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      )
                    else
                      _buildGroupedTransactionsList(),
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
                        userId: _currentUserId!,
                        ledgerId: _selectedLedgerId,
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
          // Shared Bottom Navigation Bar
          SharedBottomNavBar(
            currentIndex: 0,
            userId: _currentUserId!,
            ledgerId: _selectedLedgerId,
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: FloatingActionButton(
          heroTag: 'add_transaction_fab',
          backgroundColor: const Color(0xFF90EE90),
          onPressed: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AddTransaction(
                  userId: _currentUserId!,
                  ledgerId: _selectedLedgerId,
                ),
              ),
            );
            // Refresh transactions if a new one was added
            if (result == true) {
              // Refresh both list view and calendar view
              await _fetchTransactions();
              await _calculateDailyBalances();
              // Budget alerts already handled in AddTransaction screen
              // No need to re-check here
            }
          },
          child: const Icon(Icons.add, color: Colors.black, size: 30),
        ),
      ),
    );
  }
}
