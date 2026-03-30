import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';

class AchievementPage extends StatefulWidget {
  final String userId;

  const AchievementPage({super.key,required this.userId});

  @override
  State<AchievementPage> createState() =>
      _AchievementPageState();
}

class _AchievementPageState
    extends State<AchievementPage> {

  final supabase = Supabase.instance.client;

  Map<String, dynamic>? recentAchievement;

  Map<DateTime, Map<String, dynamic>>
  achievementMap = {};


  List<DateTime> awardedDates = [];

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // =========================================================
  // INIT
  // =========================================================
  @override
  void initState() {
    super.initState();
    fetchAchievements();
  }

  // =========================================================
  // FETCH USER ACHIEVEMENTS + DATES
  // =========================================================
  Future<void> fetchAchievements() async {

    final data = await supabase
        .from('UserAchievement')
        .select('''
        awardedAt,
        Achievement (
          title,
          rewardCoins,
          iconName
        )
      ''')
    .eq('userId', widget.userId);

    debugPrint("ACH DATA: $data");

    if (data.isEmpty) return;

    achievementMap.clear();
    awardedDates.clear();

    for (var e in data) {

      DateTime utc = DateTime.parse(e['awardedAt']);

      DateTime cleanDate = DateTime(
        utc.year,
        utc.month,
        utc.day,
      );

      achievementMap[cleanDate] =
      e['Achievement'];

      awardedDates.add(cleanDate);
    }


    /// Default show most recent
    data.sort((a, b) =>
        DateTime.parse(b['awardedAt'])
            .compareTo(
            DateTime.parse(a['awardedAt'])));

    recentAchievement =
    data.first['Achievement'];

    setState(() {});
  }


  // =========================================================
  // UI
  // =========================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEFFD3),

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            /// ICON + TITLE
            Row(
              mainAxisAlignment:
              MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/achievement.png',
                  width: 60,
                  height: 60,
                ),
                const SizedBox(width: 8),
                const Text(
                  "Achievement",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            _buildRecentEarned(),

            const SizedBox(height: 20),

            _buildCalendar(),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // RECENTLY EARNED
  // =========================================================
  Widget _buildRecentEarned() {

    if (recentAchievement == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.4),
          borderRadius:
          BorderRadius.circular(20),
        ),
        child: const Center(
          child: Text(
            "No achievement available",
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    final achievement =
    recentAchievement!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.4),
        borderRadius:
        BorderRadius.circular(20),
      ),

      child: Column(
        children: [

          const Text(
            "Recently earned",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            achievement['title'],
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          Image.network(
            achievement['iconName'],
            width: 60,
            height: 60,
          ),

          const SizedBox(height: 8),

        ],
      ),
    );
  }


  // =========================================================
  // CALENDAR
  // =========================================================
  Widget _buildCalendar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.4),
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

          DateTime cleanDate = DateTime(
              selectedDay.year,
              selectedDay.month,
              selectedDay.day);

          if (achievementMap
              .containsKey(cleanDate)) {

            recentAchievement =
            achievementMap[cleanDate];

          } else {

            recentAchievement = null;
          }

          setState(() {});
        },


        headerStyle: const HeaderStyle(
          titleCentered: true,
          formatButtonVisible: false,
        ),

        daysOfWeekStyle:
        const DaysOfWeekStyle(
          weekdayStyle:
          TextStyle(fontSize: 10),
          weekendStyle:
          TextStyle(fontSize: 10),
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

        /// 🌟 AWARDED DATE HIGHLIGHT
        calendarBuilders:
        CalendarBuilders(
          defaultBuilder:
              (context, day, _) {

            bool isAwarded =
            awardedDates.any(
                  (d) =>
              d.year ==
                  day.year &&
                  d.month ==
                      day.month &&
                  d.day ==
                      day.day,
            );

            if (isAwarded) {
              return Container(
                margin:
                const EdgeInsets.all(6),
                decoration:
                const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
                alignment:
                Alignment.center,
                child: Text(
                  '${day.day}',
                  style:
                  const TextStyle(
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
    );
  }
}
