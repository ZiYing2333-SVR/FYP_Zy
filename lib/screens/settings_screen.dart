import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// import 'package:image_picker/image_picker.dart';
// import 'dart:typed_data';
import '../Challenge/View_Challenge.dart';
import '../Challenge/view_achievement.dart';
import '../FinancialTip/view_tips_page.dart';
import '../Missions/view_mission.dart';
import '../Quiz/view_quiz_page.dart';
import '../pet/pet_home_page.dart';
import '../pet/pet_main.dart';
import '../services/budget_alert_service.dart';
import '../services/alert_status_service.dart';
import '../widgets/shared_bottom_nav_bar.dart';
import 'home_screen.dart';
import 'welcome_screen.dart';
import 'profile_settings_screen.dart';
import 'ledger_manager.dart';
import 'account_manager.dart';
import 'currency_settings_page.dart';
import 'account_page.dart';
import 'category_manager.dart';
import 'savings_page.dart';
import 'budget_page.dart';
import 'report_page.dart';

class SettingsScreen extends StatefulWidget {
  final String userId;

  const SettingsScreen({Key? key, required this.userId}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  int _selectedIndex = 4;
  String _userNickname = 'Nickname';
  String? _profileImageUrl;
  bool _isLoadingProfile = true;
  bool _hasBudgetAlert = false;
  bool _hasBudgetCaution = false;
  bool _alertsShownThisSession = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchUserProfile();
    // _initializeAlerts(); // DISABLED: Prevent automatic budget alert popups
  }

  Future<void> _initializeAlerts() async {
    await _checkBudgetAlerts();
    await _checkBudgetCaution();

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
      print('[SettingsScreen] App resumed, refreshing badge status...');
      _checkBudgetCaution();
    }
  }

  Future<void> _fetchUserProfile() async {
    try {
      final response = await Supabase.instance.client
          .from('User')
          .select()
          .eq('userId', widget.userId)
          .single();

      setState(() {
        _userNickname = response['nickname'] ?? 'Nickname';
        _profileImageUrl = response['profileImage'];
        _isLoadingProfile = false;
      });
    } catch (e) {
      print('Error fetching user profile: $e');
      setState(() => _isLoadingProfile = false);
    }
  }

  Future<void> _checkBudgetAlerts() async {
    try {
      // Check if any budget has isAlert or isWarning flags
      final alertService = BudgetAlertService();
      final hasAlert = await alertService.hasAnyBudgetAlert(widget.userId);

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
                          color: const Color(0xFFF39C12).withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.warning_amber_rounded,
                          color: Color(0xFFF39C12),
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
                            activeColor: const Color(0xFFF39C12),
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
                                backgroundColor: const Color(0xFFF39C12),
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
                        decoration: BoxDecoration(
                          color: const Color(0xFFE74C3C).withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.error_rounded,
                          color: Color(0xFFE74C3C),
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
                            activeColor: const Color(0xFFE74C3C),
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
                                backgroundColor: const Color(0xFFE74C3C),
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

  Future<void> _dismissBudgetCaution(String budgetId) async {
    try {
      final alertService = BudgetAlertService();
      await alertService.dismissCautionAlert(budgetId, widget.userId);

      // Refresh caution status
      _checkBudgetCaution();
    } catch (e) {
      print('Error dismissing budget caution: $e');
    }
  }

  List<Widget> _buildNavBadges() {
    // Position badge only on Settings icon (index 4)
    final badges = <Widget>[];
    const badgeSize = 20.0;
    const badgeTopOffset = 8.0;
    const badgeRightOffset = 12.0;

    if (!(_hasBudgetCaution || _hasBudgetAlert)) {
      return badges;
    }

    // Show isAlert (ORANGE) badge
    if (_hasBudgetAlert) {
      badges.add(
        Positioned(
          right: badgeRightOffset,
          top: badgeTopOffset,
          child: Container(
            width: badgeSize,
            height: badgeSize,
            decoration: const BoxDecoration(
              color: Color(0xFFF39C12),
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
              color: Color(0xFFE74C3C),
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
            builder: (context) =>
                PetHomePage(userId: widget.userId, petId: petId),
          ),
        );
      } else {
        // ❌ No pet → go create page
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PetMainPage(userId: widget.userId),
          ),
        );
      }
    } catch (e) {
      print('Error checking pet: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AlertStatusService().hasCautionAlertNotifier,
      builder: (context, hasCaution, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: AlertStatusService().hasHighRiskAlertNotifier,
          builder: (context, hasHighRisk, _) {
            return Scaffold(
              backgroundColor: const Color(0xFFFFF9E6),
              body: Stack(
                children: [
                  SingleChildScrollView(
                    child: Column(
                      children: [
                        // Profile Section
                        Stack(
                          children: [
                            Container(
                              margin: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                              padding: const EdgeInsets.all(28),
                              width: double.infinity,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    const Color(0xFFFFF0F5),
                                    const Color(0xFFFFE5F0),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(25),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF52C77A,
                                    ).withOpacity(0.15),
                                    blurRadius: 15,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                                border: Border.all(
                                  color: const Color(0xFFFFE5B4),
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                children: [
                                  // Avatar with border
                                  Container(
                                    width: 110,
                                    height: 110,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF52C77A),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(
                                            0xFF52C77A,
                                          ).withOpacity(0.3),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 3,
                                      ),
                                    ),
                                    child: _isLoadingProfile
                                        ? const Center(
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                            ),
                                          )
                                        : _profileImageUrl != null &&
                                              _profileImageUrl!.isNotEmpty
                                        ? ClipOval(
                                            child: Image.network(
                                              _profileImageUrl!,
                                              fit: BoxFit.cover,
                                              errorBuilder:
                                                  (context, error, stackTrace) {
                                                    return Center(
                                                      child: Icon(
                                                        Icons.person,
                                                        size: 65,
                                                        color: Colors.white,
                                                      ),
                                                    );
                                                  },
                                            ),
                                          )
                                        : Center(
                                            child: Icon(
                                              Icons.person,
                                              size: 65,
                                              color: Colors.white,
                                            ),
                                          ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _userNickname,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF333333),
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Profile Settings',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black.withOpacity(0.5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        // Menu Items Section with better styling
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Column(
                            children: [
                              _buildMenuItemCard(
                                'Ledger Manager',
                                0,
                                icon: Icons.book_rounded,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          LedgerManager(userId: widget.userId),
                                    ),
                                  );
                                },
                              ),
                              _buildMenuItemCard(
                                'Account Manager',
                                1,
                                icon: Icons.account_balance_wallet_rounded,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          AccountManager(userId: widget.userId),
                                    ),
                                  );
                                },
                              ),
                              _buildMenuItemCard(
                                'Category Manager',
                                2,
                                icon: Icons.category_rounded,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => CategoryManager(
                                        userId: widget.userId,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              _buildMenuItemCard(
                                'Report',
                                3,
                                icon: Icons.assessment_rounded,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          ReportPage(userId: widget.userId),
                                    ),
                                  );
                                },
                              ),
                              _buildMenuItemCard(
                                'Budget',
                                4,
                                icon: Icons.attach_money_rounded,
                                hasAlert: hasHighRisk,
                                hasCaution: hasCaution,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          BudgetPage(userId: widget.userId),
                                    ),
                                  ).then((_) {
                                    // Refresh alerts when returning from Budget page
                                    _checkBudgetAlerts();
                                    _checkBudgetCaution();
                                  });
                                },
                              ),
                              _buildMenuItemCard(
                                'Saving',
                                5,
                                icon: Icons.savings_rounded,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          SavingsPage(userId: widget.userId),
                                    ),
                                  );
                                },
                              ),
                              _buildMenuItemCard(
                                'Default Currency',
                                6,
                                icon: Icons.currency_exchange_rounded,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          CurrencySettingsPage(
                                            userId: widget.userId,
                                          ),
                                    ),
                                  );
                                },
                              ),
                              _buildMenuItemCard(
                                'Profile Settings',
                                7,
                                icon: Icons.person_outline_rounded,
                                onTap: () async {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          ProfileSettingsScreen(
                                            userId: widget.userId,
                                          ),
                                    ),
                                  );

                                  // If returned with true, refresh the profile data
                                  if (result == true) {
                                    await _fetchUserProfile();
                                  }
                                },
                              ),
                              _buildMenuItemCard(
                                'Finance Tips',
                                8,
                                icon: Icons.lightbulb_rounded,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          ViewTipsPage(userId: widget.userId),
                                    ),
                                  );
                                },
                              ),
                              _buildMenuItemCard(
                                'Daily Missions',
                                9,
                                icon: Icons.task_alt_rounded,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          MissionPage(userId: widget.userId),
                                    ),
                                  );
                                },
                              ),
                              _buildMenuItemCard(
                                'Challenges',
                                11,
                                icon: Icons.emoji_events_rounded,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ViewChallengePage(
                                        userId: widget.userId,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              _buildMenuItemCard(
                                'Achievement',
                                11,
                                icon: Icons.star_rounded,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => AchievementPage(
                                        userId: widget.userId,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              _buildMenuItemCard(
                                'Quiz',
                                11,
                                icon: Icons.quiz_rounded,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          ViewQuizPage(userId: widget.userId),
                                    ),
                                  );
                                },
                              ),
                              // Logout Menu Item
                              Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFFE74C3C),
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.06),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: const Color(0xFFFFEBEE),
                                  borderRadius: BorderRadius.circular(16),
                                  child: InkWell(
                                    onTap: () {
                                      showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          backgroundColor: const Color(
                                            0xFFFFF9E6,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          contentPadding: const EdgeInsets.all(
                                            24,
                                          ),
                                          content: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              // Icon
                                              Container(
                                                padding: const EdgeInsets.all(
                                                  12,
                                                ),
                                                decoration: const BoxDecoration(
                                                  color: Color(0xFFE74C3C),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.logout_rounded,
                                                  color: Colors.white,
                                                  size: 48,
                                                ),
                                              ),
                                              const SizedBox(height: 20),
                                              // Title
                                              const Text(
                                                'Logout',
                                                style: TextStyle(
                                                  fontSize: 22,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFFE74C3C),
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                              const SizedBox(height: 12),
                                              // Description
                                              const Text(
                                                'Are you sure you want to logout from your account?',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Color(0xFF666666),
                                                  height: 1.5,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                              const SizedBox(height: 24),
                                              // Cancel Button
                                              SizedBox(
                                                width: double.infinity,
                                                height: 48,
                                                child: ElevatedButton(
                                                  onPressed: () =>
                                                      Navigator.pop(context),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        const Color(0xFFE74C3C),
                                                    foregroundColor:
                                                        Colors.white,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                    ),
                                                    elevation: 0,
                                                  ),
                                                  child: const Text(
                                                    'Cancel',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              // Logout Button
                                              SizedBox(
                                                width: double.infinity,
                                                height: 48,
                                                child: OutlinedButton(
                                                  onPressed: () {
                                                    Navigator.pop(context);
                                                    Navigator.pushAndRemoveUntil(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (context) =>
                                                            const WelcomeScreen(),
                                                      ),
                                                      (route) => false,
                                                    );
                                                  },
                                                  style: OutlinedButton.styleFrom(
                                                    foregroundColor:
                                                        Colors.grey[700],
                                                    side: BorderSide(
                                                      color: Colors.grey[300]!,
                                                      width: 1.5,
                                                    ),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                    ),
                                                  ),
                                                  child: const Text(
                                                    'Logout',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(16),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          // Icon and Text
                                          Expanded(
                                            child: Row(
                                              children: [
                                                // Icon Container
                                                Container(
                                                  width: 50,
                                                  height: 50,
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                      0xFFFFCDD2,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                  ),
                                                  child: const Center(
                                                    child: Icon(
                                                      Icons.logout_rounded,
                                                      color: Color(0xFFE74C3C),
                                                      size: 26,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 16),
                                                // Text
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Text(
                                                        'Logout',
                                                        style: const TextStyle(
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: Color(
                                                            0xFFE74C3C,
                                                          ),
                                                          letterSpacing: 0.3,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Icon(
                                            Icons.chevron_right_rounded,
                                            color: Colors.black.withOpacity(
                                              0.4,
                                            ),
                                            size: 26,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ],
              ),
              bottomNavigationBar: SharedBottomNavBar(
                currentIndex: 4,
                userId: widget.userId,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMenuItemCard(
    String title,
    int index, {
    IconData? icon,
    bool hasNotification = false,
    bool hasAlert = false,
    bool hasCaution = false,
    VoidCallback? onTap,
  }) {
    // Color palette matching home page theme with greens, warm tones
    final List<Color> iconBackgroundColors = [
      const Color(0xFFC8E6C9), // light green
      const Color(0xFFFFF9C4), // light yellow
      const Color(0xFFA7E399), // soft green
      const Color(0xFFFFE0B2), // light orange
      const Color(0xFFF0F4C3), // pale green
      const Color(0xFFFFFACD), // light lemon
      const Color(0xFFDCEDC8), // soft sage
      const Color(0xFFFFD4B3), // peach
      const Color(0xFFB9E4D0), // mint green
      const Color(0xFFFFE5B2), // butter
      const Color(0xFFC8E6C9), // light green
      const Color(0xFFF0F4C3), // pale green
      const Color(0xFFFFE0B2), // light orange
    ];

    final List<Color> iconColors = [
      const Color(0xFF52C77A), // main green
      const Color(0xFFF39C12), // orange/warm
      const Color(0xFF388E3C), // dark green
      const Color(0xFFE65100), // deep orange
      const Color(0xFF558B2F), // olive green
      const Color(0xFFF57F17), // amber
      const Color(0xFF33691E), // forest green
      const Color(0xFFD84315), // burnt sienna
      const Color(0xFF00796B), // teal
      const Color(0xFFE8A700), // gold
      const Color(0xFF52C77A), // main green
      const Color(0xFF558B2F), // olive green
      const Color(0xFFE65100), // deep orange
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF52C77A), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: const Color(0xFF90EE90).withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Icon and Text
                Expanded(
                  child: Row(
                    children: [
                      // Icon Container
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color:
                              iconBackgroundColors[index %
                                  iconBackgroundColors.length],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Icon(
                            icon ?? Icons.arrow_forward_rounded,
                            color: iconColors[index % iconColors.length],
                            size: 26,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Text
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF333333),
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Alert/Caution badge and chevron
                Row(
                  children: [
                    // Alert icon (red ! for >= 100% usage) - HIGH PRIORITY
                    if (hasAlert)
                      Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE74C3C),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Text(
                            '!',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      )
                    // Caution icon (orange warning for 70-99% usage) - LOWER PRIORITY
                    else if (hasCaution)
                      Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF39C12),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.warning_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.black.withOpacity(0.4),
                      size: 26,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    String title,
    int index, {
    bool hasNotification = false,
    bool hasAlert = false,
    bool hasCaution = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ),
            // Alert icon (red ! for >= 100% usage) - HIGH PRIORITY
            if (hasAlert)
              Container(
                width: 24,
                height: 24,
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
                      fontSize: 14,
                    ),
                  ),
                ),
              )
            // Caution icon (orange warning for 70-99% usage) - LOWER PRIORITY
            else if (hasCaution)
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.orange.shade700,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.warning_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
            // Generic notification icon (for backwards compatibility)
            if (hasNotification && !hasAlert && !hasCaution)
              Container(
                width: 24,
                height: 24,
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
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            const SizedBox(width: 12),
            const Icon(Icons.chevron_right, color: Colors.black54, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Divider(color: Colors.green[400], height: 1, thickness: 1),
    );
  }
}
