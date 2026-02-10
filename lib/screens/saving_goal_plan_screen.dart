import 'package:flutter/material.dart';
import 'saving_goal_confirmation_screen.dart';

class SavingGoalPlanScreen extends StatefulWidget {
  final String userId;
  final Map<String, dynamic> plan;
  final Map<String, dynamic> feasibility;
  final Map<String, dynamic> accountSuggestions;
  final List<Map<String, dynamic>> accounts;

  const SavingGoalPlanScreen({
    super.key,
    required this.userId,
    required this.plan,
    required this.feasibility,
    required this.accountSuggestions,
    required this.accounts,
  });

  @override
  State<SavingGoalPlanScreen> createState() => _SavingGoalPlanScreenState();
}

class _SavingGoalPlanScreenState extends State<SavingGoalPlanScreen> {
  bool _expandedMilestones = false;

  @override
  Widget build(BuildContext context) {
    final isFeasible = widget.plan['willAchieveGoal'] ?? false;
    final suggestions =
        (widget.feasibility['suggestions'] as List<dynamic>?)?.cast<String>() ??
        [];

    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFFFB),
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back, color: Colors.black),
        ),
        title: const Text(
          'Your Saving Plan',
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Feasibility Status Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isFeasible
                    ? Colors.green.shade50
                    : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isFeasible
                      ? Colors.green.shade300
                      : Colors.orange.shade300,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isFeasible ? Icons.check_circle : Icons.warning,
                        color: isFeasible ? Colors.green : Colors.orange,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isFeasible
                              ? 'Your goal is achievable!'
                              : 'Goal needs adjustment',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isFeasible ? Colors.green : Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Target: RM${(widget.plan['targetAmount'] ?? 0).toStringAsFixed(2)} | '
                    'Projected: RM${(widget.plan['projectedSavings'] ?? 0).toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Goal Summary
            Text(
              'Goal Summary',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildSummaryRow(
                    'Goal Name',
                    widget.plan['savingGoalName'] ?? '',
                  ),
                  const SizedBox(height: 12),
                  _buildSummaryRow(
                    'Duration',
                    '${widget.plan['totalMonths']} months',
                  ),
                  const SizedBox(height: 12),
                  _buildSummaryRow(
                    'Monthly Net Savings',
                    'RM${(widget.plan['monthlyNetSavings'] ?? 0).toStringAsFixed(2)}',
                  ),
                  const SizedBox(height: 12),
                  _buildSummaryRow(
                    'Monthly Income',
                    'RM${(widget.plan['monthlyIncome'] ?? 0).toStringAsFixed(2)}',
                  ),
                  const SizedBox(height: 12),
                  _buildSummaryRow(
                    'Monthly Expense',
                    'RM${(widget.plan['monthlyExpense'] ?? 0).toStringAsFixed(2)}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Suggestions
            if (suggestions.isNotEmpty) ...[
              Text(
                'Recommendations',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: suggestions
                      .asMap()
                      .entries
                      .map(
                        (e) => Padding(
                          padding: EdgeInsets.only(
                            bottom: e.key < suggestions.length - 1 ? 12 : 0,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${e.key + 1}. ',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  e.value,
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 24),
            ],
            // Milestones Section
            Container(
              decoration: BoxDecoration(
                color: Colors.green.shade100.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: Theme(
                data: Theme.of(
                  context,
                ).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  title: const Text(
                    'Saving Milestones',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  trailing: Icon(
                    _expandedMilestones ? Icons.expand_less : Icons.expand_more,
                    color: Colors.green,
                  ),
                  onExpansionChanged: (expanded) {
                    setState(() {
                      _expandedMilestones = expanded;
                    });
                  },
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children:
                            (widget.plan['milestones'] as List<dynamic>?)
                                ?.cast<Map<String, dynamic>>()
                                .map(
                                  (milestone) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _buildMilestoneItem(milestone),
                                  ),
                                )
                                .toList() ??
                            [],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Action Buttons
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SavingGoalConfirmationScreen(
                        userId: widget.userId,
                        plan: widget.plan,
                        feasibility: widget.feasibility,
                        accountSuggestions: widget.accountSuggestions,
                        accounts: widget.accounts,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Continue to Setup',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: Colors.green),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Back to Edit',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildMilestoneItem(Map<String, dynamic> milestone) {
    final month = milestone['month'] ?? 0;
    final targetAmount = milestone['targetAmount'] ?? 0;
    final cumulativeTarget = milestone['cumulativeTarget'] ?? 0;
    final percentage = double.tryParse(milestone['percentage'] ?? '0') ?? 0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.green.shade200,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              'M$month',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Colors.black,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'RM${targetAmount.toStringAsFixed(2)}/mo',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Text(
                    'RM${cumulativeTarget.toStringAsFixed(2)} ($percentage%)',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: percentage / 100,
                  minHeight: 6,
                  backgroundColor: Colors.grey.shade300,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.green.shade400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
