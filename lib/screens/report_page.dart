import 'package:flutter/material.dart';
import 'spending_pie_chart_page.dart';
import 'income_pie_chart_page.dart';
import 'expense_trends_page.dart';

class ReportPage extends StatefulWidget {
  final String userId;

  const ReportPage({Key? key, required this.userId}) : super(key: key);

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF9E6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFEFFD3),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _buildReportItem(
                    title: 'Spending Pie Chart',
                    description: 'View your spending distribution by category',
                    icon: Icons.pie_chart,
                    iconColor: const Color(0xFFE74C3C),
                    backgroundColor: const Color(0xFFFFE5CC),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              SpendingPieChartPage(userId: widget.userId),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildReportItem(
                    title: 'Income Pie Chart',
                    description: 'Analyze your income sources and breakdown',
                    icon: Icons.pie_chart,
                    iconColor: const Color(0xFF52C77A),
                    backgroundColor: const Color(0xFFE8F5E9),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              IncomePieChartPage(userId: widget.userId),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildReportItem(
                    title: 'Expense Trends',
                    description: 'Track your spending patterns over time',
                    icon: Icons.show_chart,
                    iconColor: const Color(0xFF4CAF50),
                    backgroundColor: const Color(0xFFC8E6C9),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ExpenseTrendsPage(userId: widget.userId),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportItem({
    required String title,
    required String description,
    required IconData icon,
    required Color iconColor,
    required Color backgroundColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFFE5B4), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon Container
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(child: Icon(icon, color: iconColor, size: 32)),
            ),
            const SizedBox(width: 16),
            // Text Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFBCBCBC),
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Chevron Icon
            Container(
              padding: const EdgeInsets.all(8),
              child: const Icon(
                Icons.chevron_right,
                color: Color(0xFFBCBCBC),
                size: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
