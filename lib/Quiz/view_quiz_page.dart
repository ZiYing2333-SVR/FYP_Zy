import 'package:flutter/material.dart';
import 'package:fyp_zy/Quiz/quiz_history_page.dart';
import 'package:fyp_zy/Quiz/quiz_rule.page.dart';
import '../screens/settings_screen.dart';



class ViewQuizPage extends StatelessWidget {
  final String userId;

  const ViewQuizPage({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEFFD3),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFEFFD3),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => SettingsScreen(userId: userId),
              ),
            );
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 🔆 Light bulb
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/brain.png',
                  width: 60,
                  height: 60,
                ),
                const SizedBox(width: 10),
                const Text(
                  'Quiz',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),


            const SizedBox(height: 24),

            //  Cards fill remaining space
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: _buildCard(
                      imagePath: 'assets/images/quiz.png',
                      title: 'Attempt Quiz',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => QuizRulePage(userId: userId),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: _buildCard(
                      imagePath: 'assets/images/history.png',
                      title: 'Quiz History',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => QuizHistoryPage(userId: userId),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({
    required String imagePath,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [

            BoxShadow(
              color: Colors.black.withValues(alpha:0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Image.asset(
              imagePath,
              width: 70,
              height: 70,
            ),
            const SizedBox(width: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
