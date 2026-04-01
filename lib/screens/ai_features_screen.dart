import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auto_expense_categorization_screen.dart';
import 'budget_forecasting_screen.dart';
import 'saving_goal_assistant_screen.dart';
import '../services/budget_forecast_service.dart';

class AIFeaturesScreen extends StatelessWidget {
  final String userId;
  final String? ledgerId;

  const AIFeaturesScreen({super.key, required this.userId, this.ledgerId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEFFD3),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFEFFD3),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Icon(Icons.close, color: Colors.black, size: 24),
            ),
            const Text(
              'AI Features',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(width: 24), // Placeholder for alignment
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Auto Expense Categorization
            _buildFeatureButton(
              context,
              title: 'Auto Expense Categorization',
              icon: Icons.auto_awesome,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AutoExpenseCategorization(
                      userId: userId,
                      ledgerId: ledgerId,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            // Budget Forecasting with High-Risk Alert Badge
            _buildBudgetForecastingButton(context),
            const SizedBox(height: 12),
            // Savings Goal Assistant
            _buildFeatureButton(
              context,
              title: 'Savings Goal Assistant',
              icon: Icons.savings,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SavingGoalAssistantScreen(
                      userId: userId,
                      ledgerId: ledgerId,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetForecastingButton(BuildContext context) {
    return FutureBuilder<bool>(
      future: _checkBudgetAlerts(),
      builder: (context, snapshot) {
        final hasAlert = snapshot.data ?? false;

        return Stack(
          children: [
            _buildFeatureButton(
              context,
              title: 'Budget Forecasting',
              icon: Icons.trending_up,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BudgetForecastingScreen(
                      userId: userId,
                      ledgerId: ledgerId,
                    ),
                  ),
                );
              },
            ),
            // Show red badge only when there's high risk alert
            if (hasAlert)
              Positioned(
                top: 8,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE53935),
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 20,
                    minHeight: 20,
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
          ],
        );
      },
    );
  }

  Future<bool> _checkBudgetAlerts() async {
    try {
      final budgets = await Supabase.instance.client
          .from('Budget')
          .select()
          .eq('userId', userId);

      final forecastService = BudgetForecastService();

      // Check each budget for high risk
      for (var budget in budgets) {
        final isHighRisk = await forecastService.checkHighRiskAlert(
          userId,
          budget['budgetId'],
          (budget['amount'] ?? 0).toDouble(),
          budget['accountId'],
          budget['categoryId'],
          budget['ledgerId'],
        );

        if (isHighRisk) {
          return true; // Found at least one high-risk budget
        }
      }

      return false; // No high-risk budgets
    } catch (e) {
      print('Error checking budget alerts: $e');
      return false;
    }
  }

  Widget _buildFeatureButton(
    BuildContext context, {
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFA7E399),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.black, size: 24),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.black, size: 18),
          ],
        ),
      ),
    );
  }
}
