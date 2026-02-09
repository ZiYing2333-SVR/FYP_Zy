import 'package:flutter/material.dart';
import 'auto_expense_categorization_screen.dart';

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
            // Budget Forecasting with Badge
            Stack(
              children: [
                _buildFeatureButton(
                  context,
                  title: 'Budget Forecasting',
                  icon: Icons.trending_up,
                  onTap: () {
                    // Navigate to Budget Forecasting screen
                    print('Budget Forecasting tapped');
                  },
                ),
                // Red badge
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
                      child: Text(
                        '1',
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
            const SizedBox(height: 12),
            // Savings Goal Assistant
            _buildFeatureButton(
              context,
              title: 'Savings Goal Assistant',
              icon: Icons.savings,
              onTap: () {
                // Navigate to Savings Goal Assistant screen
                print('Savings Goal Assistant tapped');
              },
            ),
          ],
        ),
      ),
    );
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
