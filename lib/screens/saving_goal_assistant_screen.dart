import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/saving_goal_assistant_service.dart';
import 'saving_goal_plan_screen.dart';

class SavingGoalAssistantScreen extends StatefulWidget {
  final String userId;

  const SavingGoalAssistantScreen({super.key, required this.userId});

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
      // Fetch financial data
      final financialData =
          await SavingGoalAssistantService.getUserFinancialData(widget.userId);

      if (!financialData['success']) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(financialData['error'] ?? 'Unknown error')),
          );
        }
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Forecast future expenses
      final forecast = SavingGoalAssistantService.forecastFutureExpenses(
        financialData['monthlyData'],
        12,
      );

      // Show warning if data is limited
      if (forecast['hasLimitedData'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Limited transaction data. We\'ll use estimated values for your analysis.',
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }

      // Analyze feasibility
      final targetAmount = double.parse(_targetAmountController.text);
      final feasibility =
          SavingGoalAssistantService.analyzeSavingGoalFeasibility(
            targetAmount: targetAmount,
            startDate: _selectedStartDate!,
            endDate: _selectedEndDate!,
            predictedMonthlyIncome: forecast['predictedMonthlyIncome'],
            predictedMonthlyExpense: forecast['predictedMonthlyExpense'],
          );

      if (!feasibility['success']) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(feasibility['error'] ?? 'Unknown error')),
          );
        }
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Generate saving plan
      final monthlyNetSavings = feasibility['monthlyNetIncome'];
      final plan = SavingGoalAssistantService.generateSavingPlan(
        savingGoalName: _nameController.text,
        targetAmount: targetAmount,
        startDate: _selectedStartDate!,
        endDate: _selectedEndDate!,
        monthlyIncome: forecast['predictedMonthlyIncome'],
        monthlyExpense: forecast['predictedMonthlyExpense'],
        monthlyNetSavings: monthlyNetSavings,
      );

      // Suggest accounts
      final accountSuggestions = SavingGoalAssistantService.suggestAccounts(
        List<Map<String, dynamic>>.from(financialData['accounts'] ?? []),
        List<Map<String, dynamic>>.from(
          financialData['incomeTransactions'] ?? [],
        ),
        List<Map<String, dynamic>>.from(
          financialData['expenseTransactions'] ?? [],
        ),
      );

      setState(() {
        _isLoading = false;
      });

      // Navigate to plan screen
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SavingGoalPlanScreen(
              userId: widget.userId,
              plan: plan,
              feasibility: feasibility,
              accountSuggestions: accountSuggestions,
              accounts: List<Map<String, dynamic>>.from(
                financialData['accounts'] ?? [],
              ),
            ),
          ),
        );
      }
    } catch (e) {
      print('Error analyzing saving goal: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() {
          _isLoading = false;
        });
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
