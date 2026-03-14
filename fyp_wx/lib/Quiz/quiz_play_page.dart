import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fyp_wx/Quiz/quiz_result_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class QuizPlayPage extends StatefulWidget {
  const QuizPlayPage({super.key});

  @override
  State<QuizPlayPage> createState() => _QuizPlayPageState();
}

class _QuizPlayPageState extends State<QuizPlayPage> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> questions = [];
  int currentIndex = 0;
  int score = 0;

  int timeLeft = 40;
  Timer? timer;

  bool answered = false;
  late DateTime startTime;

  @override
  void initState() {
    super.initState();
    startTime = DateTime.now();
    fetchQuestions();
  }

  // ===============================
  // FETCH RANDOM QUESTIONS
  // ===============================
  Future<void> fetchQuestions() async {
    try {
      final response = await supabase
          .from('QuizQuestion') // confirmed correct
          .select();

      if (response.isEmpty) {
        throw Exception('No questions found');
      }

      final List<Map<String, dynamic>> list =
      List<Map<String, dynamic>>.from(response);

      list.shuffle(); //randomize in Flutter

      setState(() {
        questions = list.take(10).toList();
      });

      startTimer();
    } catch (e) {
      debugPrint('Quiz fetch error: $e');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load quiz questions')),
      );
    }
  }


  // ===============================
  // TIMER
  // ===============================
  void startTimer() {
    timer?.cancel();
    timeLeft = 40;

    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (timeLeft == 0) {
        t.cancel();
        Future.microtask(() async {
          await goNextQuestion();
        });
      }
      else {
        setState(() => timeLeft--);
      }
    });
  }

  // ===============================
  // ANSWER HANDLING
  // ===============================
  Future<void> selectAnswer(String selected) async {
    if (answered) return;

    answered = true;
    timer?.cancel();

    final correct = questions[currentIndex]['correctOption'];

    if (selected == correct) {
      score++;
      await showResultPopup(
        isCorrect: true,
        message: 'Correct!',
      );
    } else {
      await showResultPopup(
        isCorrect: false,
        message: 'Wrong!\nCorrect answer:\n$correct',
      );
    }

    await goNextQuestion();
  }



  Future<void> showResultPopup({
    required bool isCorrect,
    required String message,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        // auto close dialog after 1.2s
        Future.delayed(const Duration(milliseconds: 1200), () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        });

        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFFEFFD3),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isCorrect ? Icons.check_circle : Icons.cancel,
                  size: 60,
                  color: isCorrect ? const Color(0xFF00BA00) : Colors.red,
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }




  // ===============================
  // NEXT QUESTION / FINISH
  // ===============================
  Future<void> goNextQuestion() async {
    if (!mounted || answered == false && timer == null) return;
    bool finishing = false;

    if (currentIndex == questions.length - 1) {
      finishing = true;
      final done = await showQuizCompletedDialog();
      if (done) {
        await finishQuiz();
      }
    } else {
      setState(() {
        currentIndex++;
        answered = false;
      });
      startTimer();
    }
  }



  // ===============================
  // QUIT CONFIRMATION
  // ===============================
  Future<bool> confirmExit() async {
    return await showDialog(
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
                  Icons.warning_amber_rounded,
                  size: 48,
                  color: Colors.orange,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Quit Quiz?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Your progress will be lost.\nAre you sure you want to quit?',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 24),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFA7E399)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: Color(0xFFA7E399)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFA7E399),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text(
                          'Quit',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ) ??
        false;
  }


  // ===============================
  // ATTEMPT ID GENERATOR
  // ===============================
  Future<String> generateAttemptId() async {
    final res = await supabase
        .from('QuizAttempt')
        .select('attemptId')
        .order('attemptId', ascending: false)
        .limit(1);

    if (res.isEmpty) return 'A0001';

    final last = res.first['attemptId'];
    final num = int.parse(last.substring(1)) + 1;
    return 'A${num.toString().padLeft(4, '0')}';
  }

  Future<bool> showQuizCompletedDialog() async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
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
                  Icons.celebration,
                  size: 64,
                  color: Color(0xFF00BA00),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Quiz Completed!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'You have answered all questions.\nGreat job!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFA7E399),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => Navigator.pop(context, true), // ✅ return true
                    child: const Text(
                      'Done',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ) ?? false;
  }



  // ===============================
  // SAVE RESULT
  // ===============================
  Future<void> finishQuiz() async {
    timer?.cancel();

    final attemptId = await generateAttemptId();
    final timeSpent =
        DateTime.now().difference(startTime).inMinutes;

    await supabase.from('QuizAttempt').insert({
      'attemptId': attemptId,
      'totalQuestion': 10,
      'score': score,
      'completeDate': DateTime.now().toIso8601String(),
      'timeSpent': timeSpent,
    });

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => QuizResultPage(
          score: score,
          totalQuestion: 10,
          coinsEarned: score * 2,
        ),
      ),
    );
  }


  // ===============================
  // UI
  // ===============================
  @override
  Widget build(BuildContext context) {
    if (questions.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final q = questions[currentIndex];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFFEFFD3),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () async {
            final exit = await confirmExit();
            if (exit) Navigator.pop(context);
          },
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Row(
              children: [
                Icon(Icons.monetization_on, color: Colors.amber),
                SizedBox(width: 4),
                Text(
                  '0',
                  style: TextStyle(color: Colors.black),
                ),
              ],
            ),
          ),
        ],
      ),

      body: Container(
        color: const Color(0xFFFEFFD3),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 5),

            /// ⏱ Circular Countdown Timer
            SizedBox(
              width: 80,
              height: 80,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: timeLeft / 40, // shrink ring
                    strokeWidth: 8,
                    backgroundColor: Colors.grey.shade300,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
                  ),
                  Text(
                    '$timeLeft',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 0),


            /// 📘 Question Container
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 28, // 👈 bigger height
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(
                          text: 'Question ',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.black, // 🖤 black
                          ),
                        ),
                        TextSpan(
                          text: '${currentIndex + 1} / 10',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF00BA00), // 🟢 green
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),
                  Text(
                    q['question'],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),


            const SizedBox(height: 30),

            /// 🃏 Options as Cards
            _optionCard(q['option1']),
            _optionCard(q['option2']),
            _optionCard(q['option3']),
          ],
        ),
      ),

    );
  }

  Widget _optionCard(String text) {
    return GestureDetector(
      onTap: () => selectAnswer(text),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(
          vertical: 18,
          horizontal: 16,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.grey, // ✅ grey options
          ),
        ),
      ),
    );
  }
}


