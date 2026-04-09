import 'package:flutter/material.dart';
import 'package:fyp_wx/Quiz/quiz_play_page.dart';
import 'package:fyp_wx/Quiz/view_quiz_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class QuizRulePage extends StatelessWidget {
  final String userId;
  const QuizRulePage({super.key, required this.userId});

  Future<bool> hasPlayedToday() async {
    final supabase = Supabase.instance.client;

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final tomorrow = todayStart.add(const Duration(days: 1));

    final res = await supabase
        .from('QuizAttempt')
        .select()
        .eq('userId', userId)
        .gte('completeDate', todayStart.toIso8601String())
        .lt('completeDate', tomorrow.toIso8601String())
        .limit(1)
        .maybeSingle();

    return res != null;
  }

  Future<void> showAlreadyPlayedDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (_) {
        return Dialog(
          backgroundColor: const Color(0xFFFEFFD3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [

                const Icon(
                  Icons.info_outline,
                  size: 50,
                  color: Colors.orange,
                ),

                const SizedBox(height: 16),

                const Text(
                  "Quiz Already Attempted",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                const Text(
                  "You can only play the quiz once per day. Please try again tomorrow.",
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFA7E399),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      "OK",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (_) => ViewQuizPage(userId: userId),
              ),
                  (route) => false,
            );
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),

            /// Brain Image + Attempt Quiz Text
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/brain.png',
                  width: 60,
                  height: 60,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Attempt Quiz',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),


            const SizedBox(height: 30),

            /// Rules Container
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
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
              child: Column(
                children: const [
                  _RuleItem(
                    text: 'Each correct answer earns 2 coins.',
                  ),
                  SizedBox(height: 25),
                  _RuleItem(
                    text: 'Each quiz can be attempted once per day.',
                  ),
                  SizedBox(height: 25),
                  _RuleItem(
                    text: 'Quiz questions are randomly selected each time.',
                  ),
                ],
              ),

            ),

            const SizedBox(height: 80),


            /// Start Quiz Button
            SizedBox(
              width: 180,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFA7E399),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                onPressed: () async {

                  bool alreadyPlayed = await hasPlayedToday();

                  if (alreadyPlayed) {
                    await showAlreadyPlayedDialog(context);
                    return;
                  }

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => QuizPlayPage(userId: userId),
                    ),
                  );
                },

                child: const Text(
                  'Start Quiz',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rule Item Widget
class _RuleItem extends StatelessWidget {
  final String text;

  const _RuleItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.check_circle,
          color: Colors.green,
          size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }
}

