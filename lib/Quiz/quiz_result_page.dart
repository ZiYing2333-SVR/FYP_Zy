import 'package:flutter/material.dart';
import 'package:fyp_zy/Quiz/view_quiz_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class QuizResultPage extends StatefulWidget {
  final int score;
  final int totalQuestion;
  final int coinsEarned;
  final String userId;

  const QuizResultPage({
    super.key,
    required this.userId,
    required this.score,
    required this.totalQuestion,
    required this.coinsEarned,
  });

  @override
  State<QuizResultPage> createState() => _QuizResultPageState();
}

class _QuizResultPageState extends State<QuizResultPage> {

  final supabase = Supabase.instance.client;

  int coinBalance = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadCoinBalance();
  }

  Future<void> loadCoinBalance() async {
    try {
      final data = await supabase
          .from('User')
          .select('coinbalance')
          .eq('userId', widget.userId)
          .single();

      setState(() {
        coinBalance = data['coinbalance'] ?? 0;
        isLoading = false;
      });

    } catch (e) {
      debugPrint("Error loading coin balance: $e");
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {

    final percentage =
    ((widget.score / widget.totalQuestion) * 100).round();

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
                builder: (_) => ViewQuizPage(userId: widget.userId),
              ),
                  (route) => false,
            );
          },
        ),

        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.monetization_on,
                    color: Colors.amber, size: 18),

                const SizedBox(width: 4),

                Text(
                  isLoading ? '...' : '$coinBalance',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 16),

            const Text(
              'Result of Your Quiz',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 30),

            Container(
              width: double.infinity,
              height: 425,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                  ),
                ],
              ),

              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [

                  const Text(
                    'Congratulations! You\nhave scored',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Text(
                    '$percentage%',
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 24),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: List.generate(
                        20,
                            (index) => Expanded(
                          child: Container(
                            height: 1,
                            color: index.isEven
                                ? Colors.grey.shade400
                                : Colors.transparent,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    'You earned',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${widget.coinsEarned}',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(width: 8),

                      const Icon(
                        Icons.monetization_on,
                        color: Colors.amber,
                        size: 30,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}