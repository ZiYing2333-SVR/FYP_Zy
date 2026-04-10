import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/saving_goal_assistant_service.dart';
import '../services/intelligent_savings_goal_assistant_service.dart';
import 'saving_goal_plan_screen.dart';
import 'saving_goal_confirmation_screen.dart';
import 'add_transaction.dart';
import 'free_saving_page.dart';

class SavingGoalAssistantScreen extends StatefulWidget {
  final String userId;
  final String? ledgerId;

  const SavingGoalAssistantScreen({
    super.key,
    required this.userId,
    this.ledgerId,
  });

  @override
  State<SavingGoalAssistantScreen> createState() =>
      _SavingGoalAssistantScreenState();
}

class _SavingGoalAssistantScreenState extends State<SavingGoalAssistantScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _targetAmountController;
  late TextEditingController _startDateController;
  late TextEditingController _endDateController;

  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _targetAmountController = TextEditingController();
    _startDateController = TextEditingController();
    _endDateController = TextEditingController();

    // Set default dates
    _selectedStartDate = DateTime.now();
    _selectedEndDate = DateTime.now().add(const Duration(days: 365));
    _startDateController.text = DateFormat(
      'yyyy-MM-dd',
    ).format(_selectedStartDate!);
    _endDateController.text = DateFormat(
      'yyyy-MM-dd',
    ).format(_selectedEndDate!);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetAmountController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(
    TextEditingController controller,
    bool isStartDate,
  ) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _selectedStartDate! : _selectedEndDate!,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFA7E399),
              onPrimary: Colors.black,
              secondary: Color(0xFFFFE5B4),
              surface: Color(0xFFFFF9E6),
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      setState(() {
        if (isStartDate) {
          _selectedStartDate = pickedDate;
        } else {
          _selectedEndDate = pickedDate;
        }
        controller.text = DateFormat('yyyy-MM-dd').format(pickedDate);
      });
    }
  }

  Future<void> _analyzeSavingGoal() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedStartDate == null || _selectedEndDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select start and end dates')),
      );
      return;
    }

    if (_selectedEndDate!.isBefore(_selectedStartDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End date must be after start date')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // STEP 1: Check if user has recent income (any salary in past 3 months)
      final recentIncomeCheck =
          await IntelligentSavingsGoalAssistant.checkRecentIncomeExists(
            widget.ledgerId ?? '',
          );

      if (!recentIncomeCheck.hasRecentIncome) {
        // ❌ NO RECENT INCOME - Show dialog with two options
        setState(() {
          _isLoading = false;
        });

        if (mounted) {
          _showIncomeOptionsDialog(recentIncomeCheck);
        }
        return;
      }

      // ✅ HAS RECENT INCOME - Proceed directly to confirmation screen (skip suggestion dialog)

      // STEP 2: Get savings suggestion
      final targetAmount = double.parse(_targetAmountController.text);
      final suggestion =
          await IntelligentSavingsGoalAssistant.generateSavingsSuggestion(
            ledgerId: widget.ledgerId ?? '',
            targetAmount: targetAmount,
            targetDate: _selectedEndDate!,
          );

      setState(() {
        _isLoading = false;
      });

      if (!suggestion.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(suggestion.feasibilityMessage)),
          );
        }
        return;
      }

      // STEP 3: Go directly to confirmation screen (skip suggestion dialog)
      if (mounted) {
        _proceedToConfirmation(suggestion);
      }
    } catch (e) {
      print('Error analyzing saving goal: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  /// Dialog: "Key in Income" or "Free Saving" when no consistent income
  void _showIncomeOptionsDialog(IncomeCheckResult incomeCheck) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(24, 16, 16, 0),
        title: Stack(
          children: [
            const Padding(
              padding: EdgeInsets.only(right: 32),
              child: Text('Record Your Income First'),
            ),
            Positioned(
              right: 0,
              top: -8,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.close, color: Colors.black54, size: 28),
              ),
            ),
          ],
        ),
        content: const Text(
          'To get accurate savings suggestions, please record your salary income. Choose one of the options below:',
        ),
        actions: [
          // Option 1: Go to Free Saving
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FreeSavingPage(userId: widget.userId),
                ),
              );
            },
            child: const Text('Free Saving'),
          ),
          // Option 2: Key in Income
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _navigateToAddIncomeTransaction(incomeCheck.salaryCategoryId);
            },
            icon: const Icon(Icons.add),
            label: const Text('Key in Income'),
          ),
        ],
      ),
    );
  }

  /// Navigate to Add Transaction screen with salary category pre-selected
  Future<void> _navigateToAddIncomeTransaction(String? salaryCategoryId) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AddTransaction(userId: widget.userId, ledgerId: widget.ledgerId),
      ),
    );

    // If transaction was added, refresh the income check
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Income recorded! Now you can create your savings goal.',
          ),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// Dialog: Show calculated savings suggestion before confirmation
  void _showSuggestionConfirmationDialog(SavingsSuggestionResult suggestion) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Savings Goal Suggestion'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Suggested monthly savings (highlighted)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Suggested Monthly Savings',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'RM ${suggestion.suggestedMonthlySavings.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'per month to reach RM ${suggestion.targetAmount.toStringAsFixed(2)} in ${suggestion.timelineMonths} months',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Analysis
              Text('Analysis', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Text(
                suggestion.analysis,
                style: const TextStyle(fontSize: 12, height: 1.5),
              ),
              const SizedBox(height: 16),
              // Feasibility status
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    suggestion.isFeasible ? Icons.check_circle : Icons.warning,
                    color: suggestion.isFeasible ? Colors.green : Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      suggestion.feasibilityMessage,
                      style: const TextStyle(fontSize: 12, height: 1.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Adjust Goal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _proceedToConfirmation(suggestion);
            },
            child: const Text('Confirm & Continue'),
          ),
        ],
      ),
    );
  }

  /// Proceed to confirmation screen with suggestion data
  Future<void> _proceedToConfirmation(
    SavingsSuggestionResult suggestion,
  ) async {
    // Prepare plan data as a Map
    final plan = {
      'savingGoalName': _nameController.text,
      'targetAmount': suggestion.targetAmount,
      'startDate': DateFormat('yyyy-MM-dd').format(_selectedStartDate!),
      'endDate': DateFormat(
        'yyyy-MM-dd',
      ).format(suggestion.targetDate), // Convert DateTime to String
      'totalMonths': suggestion.timelineMonths,
      'plannedMonthlySaving':
          suggestion.requiredMonthlySavings, // Actual required amount
    };

    // Prepare feasibility data as a Map
    final feasibility = {
      'isFeasible': suggestion.isFeasible,
      'analysis': suggestion.analysis,
      'feasibilityMessage': suggestion.feasibilityMessage,
      'averageMonthlyIncome': suggestion.averageMonthlyIncome,
      // Determine stage from analysis
      'stage': suggestion.analysis.contains('IMPOSSIBLE')
          ? 'impossible'
          : suggestion.analysis.contains('CHALLENGING')
          ? 'challenging'
          : 'achievable',
    };

    // TODO: Prepare account suggestions and accounts list
    // For now, pass empty data - you may need to fetch this from your service
    final accountSuggestions = {
      'suggestedSourceAccountId': null,
      'suggestedDestAccountId': null,
    };
    final List<Map<String, dynamic>> accounts = [];

    // Navigate to confirmation screen with the suggestion
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SavingGoalConfirmationScreen(
          userId: widget.userId,
          plan: plan,
          feasibility: feasibility,
          accountSuggestions: accountSuggestions,
          accounts: accounts,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFFFB),
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.close, color: Colors.black),
        ),
        title: const Text(
          'Saving Goal Assistant',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              const Text(
                'Tell us about your saving goal',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 20),
              // Goal Name Field
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: 'Goal Name (e.g., Emergency Fund, Vacation)',
                  filled: true,
                  fillColor: Colors.green.shade200,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a goal name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Target Amount Field
              TextFormField(
                controller: _targetAmountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  hintText: 'Target Amount (RM)',
                  filled: true,
                  fillColor: Colors.green.shade200,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  prefixText: 'RM ',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a target amount';
                  }
                  final amount = double.tryParse(value);
                  if (amount == null || amount <= 0) {
                    return 'Please enter a valid amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Start Date Field
              GestureDetector(
                onTap: () => _selectDate(_startDateController, true),
                child: TextFormField(
                  controller: _startDateController,
                  enabled: false,
                  decoration: InputDecoration(
                    hintText: 'Start Date',
                    filled: true,
                    fillColor: Colors.green.shade200,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    suffixIcon: const Icon(Icons.calendar_today),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // End Date Field
              GestureDetector(
                onTap: () => _selectDate(_endDateController, false),
                child: TextFormField(
                  controller: _endDateController,
                  enabled: false,
                  decoration: InputDecoration(
                    hintText: 'End Date',
                    filled: true,
                    fillColor: Colors.green.shade200,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    suffixIcon: const Icon(Icons.calendar_today),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              // Analyze Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _analyzeSavingGoal,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Analyzing...',
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        )
                      : const Text(
                          'Analyze Goal',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              // Info Box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ℹ️ How this works',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '1. We analyze your income and spending patterns\n'
                      '2. We forecast your future expenses using advanced analytics\n'
                      '3. We check if your goal is achievable and suggest adjustments\n'
                      '4. We help you choose suitable accounts for your goal',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 13,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
