import 'package:flutter/material.dart';
import 'package:fyp_wx/Quiz/view_quiz_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';

class QuizHistoryPage extends StatefulWidget {
  final String userId;

  const QuizHistoryPage({super.key, required this.userId});

  @override
  State<QuizHistoryPage> createState() => _QuizHistoryPageState();
}

class _QuizHistoryPageState extends State<QuizHistoryPage> {
  late DateTime _focusedDay;
  late DateTime _selectedDay;

  Map<String, dynamic>? quizAttempt;
  bool isLoading = true;

  List<DateTime> completedDates = [];


  @override
  @override
  void initState() {
    super.initState();

    final now = DateTime.now();
    final today =
    DateTime(now.year, now.month, now.day);

    _focusedDay = today;
    _selectedDay = today;

    _loadQuizForDate(today);
    _loadCompletedDates(); // ⭐ add this
  }


  /// Load quiz attempt by selected date
  Future<void> _loadQuizForDate(DateTime date) async {
    final targetDay = DateTime(date.year, date.month, date.day);

    setState(() => isLoading = true);

    try {
      final supabase = Supabase.instance.client;

      final res = await supabase
          .from('QuizAttempt')
          .select()
          .eq('userId', widget.userId)
          .gte('completeDate', targetDay.toIso8601String())
          .lt(
        'completeDate',
        targetDay.add(const Duration(days: 1)).toIso8601String(),
      )
          .limit(1)
          .maybeSingle();

      quizAttempt = res;
    } catch (e) {
      debugPrint('❌ Error loading quiz history: $e');
      quizAttempt = null;
    }

    setState(() => isLoading = false);
  }

  Future<void> _loadCompletedDates() async {
    final supabase = Supabase.instance.client;

    final data = await supabase
        .from('QuizAttempt')
        .select('completeDate')
        .eq('userId', widget.userId);;


    completedDates = data.map<DateTime>((e) {

      DateTime utc =
      DateTime.parse(e['completeDate']);

      DateTime local = utc.toLocal();

      return DateTime(
        local.year,
        local.month,
        local.day,
      );

    }).toList();

    setState(() {});
  }


  @override
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
                builder: (_) => ViewQuizPage(userId: widget.userId),
              ),
            );
          },
        ),
      ),
      body: SafeArea(
        child: Scrollbar(
          thumbVisibility: true,
          radius: const Radius.circular(10),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                /// 🕓 Page Title
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/history.png',
                      width: 45,
                      height: 45,
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'History',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                /// 📅 Calendar
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: TableCalendar(
                    firstDay: DateTime.utc(2023, 1, 1),
                    lastDay: DateTime.utc(2030, 12, 31),
                    focusedDay: _focusedDay,

                    calendarFormat: CalendarFormat.month,
                    availableCalendarFormats: const {
                      CalendarFormat.month: 'Month',
                    },

                    selectedDayPredicate: (day) =>
                        isSameDay(_selectedDay, day),

                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                      _loadQuizForDate(selectedDay);
                    },

                    headerStyle: const HeaderStyle(
                      titleCentered: true,
                      formatButtonVisible: false,
                    ),

                    daysOfWeekStyle: const DaysOfWeekStyle(
                      weekdayStyle: TextStyle(fontSize: 10),
                      weekendStyle: TextStyle(fontSize: 10),
                    ),

                    calendarStyle: const CalendarStyle(
                      todayDecoration: BoxDecoration(
                        color: Color(0xFFA7E399),
                        shape: BoxShape.circle,
                      ),
                      selectedDecoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                      outsideDaysVisible: false,
                    ),

                    /// 🌟 QUIZ COMPLETED DATE HIGHLIGHT
                    calendarBuilders: CalendarBuilders(

                      defaultBuilder: (context, day, _) {

                        bool isCompleted =
                        completedDates.any(
                              (d) =>
                          d.year == day.year &&
                              d.month == day.month &&
                              d.day == day.day,
                        );

                        if (isCompleted) {
                          return Container(
                            margin: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${day.day}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          );
                        }

                        return null;
                      },
                    ),
                  ),

                ),

                const SizedBox(height: 20),

                /// 📊 History Result
                if (isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (quizAttempt == null)
                  const Center(
                    child: Text(
                      'No quiz is done',
                      style: TextStyle(fontSize: 16),
                    ),
                  )
                else
                  _buildHistoryCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }


  /// 📦 History Card UI
  Widget _buildHistoryCard() {
    final correct = quizAttempt!['score'];
    final total = quizAttempt!['totalQuestion'] ?? 10;
    final timeSpent = quizAttempt!['timeSpent'];
    final coinsEarned = correct * 2;
    final percentage = ((correct / total) * 100).round();
    final date = DateTime.parse(quizAttempt!['completeDate']);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/brain.png',
                width: 45,
                height: 45,
              ),
              const SizedBox(width: 8),
              const Text(
                'Result',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          _infoRow('Date', '${date.year}-${date.month}-${date.day}'),
          _infoRow('Coins Earned', '$coinsEarned'),
          _infoRow('Time Spent', '$timeSpent mins'),
          _infoRow('Total Correct', '$correct / $total'),
          _infoRow('Score', '$percentage %'),
        ],
      ),
    );
  }


  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(value),
        ],
      ),
    );
  }
}
