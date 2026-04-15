import 'package:flutter/material.dart';
import 'free_saving_page.dart';
import 'cycle_saving_page.dart';
import '../AIFeatures/saving_goal_assistant_screen.dart';

class CreateSavingPage extends StatefulWidget {
  final String userId;
  final String? ledgerId;

  const CreateSavingPage({super.key, required this.userId, this.ledgerId});

  @override
  State<CreateSavingPage> createState() => _CreateSavingPageState();
}

class _CreateSavingPageState extends State<CreateSavingPage> {
  String _selectedSavingType = 'Free Saving';
  final List<String> _savingTypes = ['Free Saving', 'Cycle Saving'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF9E6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF9E6),
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.close, color: Colors.black),
        ),
        title: const Text(
          'Saving Types',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            const Text(
              'Choose a Saving Method',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            ..._savingTypes.map(
              (type) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedSavingType = type;
                    });
                    // Navigate to the specific saving type creation page
                    _navigateToSavingTypeCreation(type);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade200,
                      borderRadius: BorderRadius.circular(12),
                      border: _selectedSavingType == type
                          ? Border.all(color: Colors.green, width: 2)
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          type,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.green.shade700,
                          size: 24,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // AI Features Divider
            Row(
              children: [
                Expanded(
                  child: Container(height: 1, color: Colors.grey.shade300),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'or',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                ),
                Expanded(
                  child: Container(height: 1, color: Colors.grey.shade300),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // AI Features Button
            GestureDetector(
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SavingGoalAssistantScreen(
                      userId: widget.userId,
                      ledgerId: widget.ledgerId,
                    ),
                  ),
                );
                // If a goal was created successfully, pop back to savings_page with result
                if (result == true && mounted) {
                  Navigator.pop(context, true);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.shade200,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green, width: 2),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.auto_awesome, color: Colors.green, size: 24),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AI Savings Goal Assistant',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                            ),
                            Text(
                              'Get personalized suggestions',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.green.shade700,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToSavingTypeCreation(String savingType) async {
    Widget nextPage;

    if (savingType == 'Free Saving') {
      nextPage = FreeSavingPage(userId: widget.userId);
    } else {
      nextPage = CircleSavingPage(userId: widget.userId);
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => nextPage),
    );

    // If a goal was created successfully, pop back to savings_page with result
    if (result == true && mounted) {
      Navigator.pop(context, true);
    }
  }
}
