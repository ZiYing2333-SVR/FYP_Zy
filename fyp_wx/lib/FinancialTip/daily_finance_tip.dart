import 'package:flutter/material.dart';
import 'package:fyp_wx/FinancialTip/tip_detail_page.dart';
import 'package:fyp_wx/FinancialTip/view_tips_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';

class DailyFinanceTipPage extends StatefulWidget {
  const DailyFinanceTipPage({super.key});

  @override
  State<DailyFinanceTipPage> createState() => _DailyFinanceTipPageState();
}

class _DailyFinanceTipPageState extends State<DailyFinanceTipPage> {
  late DateTime _focusedDay;
  late DateTime _selectedDay;

  Map<String, dynamic>? dailyTip;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    _focusedDay = today;
    _selectedDay = today;

    _loadTipForDate(today);
  }

  /// 🔐 Deterministic daily tip (same date → same tip)
  Future<void> _loadTipForDate(DateTime date) async {
    final targetDay = DateTime(date.year, date.month, date.day);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (targetDay.isAfter(today)) {
      setState(() {
        dailyTip = null;
        isLoading = false;
      });
      return;
    }

    setState(() => isLoading = true);

    try {
      final supabase = Supabase.instance.client;

      final List<dynamic> tips = await supabase
          .from('FinancialTip')
          .select('''
  tipId,
  title,
  subTitle,
  content,
  TipCategory (
    tipIcon
  )
''')

          .order('tipId');

      if (tips.isEmpty) {
        dailyTip = null;
      } else {
        final daysSinceEpoch =
            targetDay.difference(DateTime(1970, 1, 1)).inDays;
        final index = daysSinceEpoch % tips.length;
        dailyTip = tips[index];
        debugPrint('📦 dailyTip = $dailyTip');

      }
    } catch (e) {
      debugPrint('❌ Error fetching daily tip: $e');
      dailyTip = null;
    }

    setState(() => isLoading = false);
  }

  /// 🖼 Convert storage path → PUBLIC URL
  String? get tipIconUrl {
    final iconPath = dailyTip?['TipCategory']?['tipIcon'];
    debugPrint('🖼 iconPath from DB = $iconPath');
    if (iconPath == null || iconPath.isEmpty) return null;

    return iconPath;
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
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ViewTipsPage(),
              ),
            );
          },
        ),
      ),
      body: SafeArea(
        child: Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 🔆 Page Title
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/lightbulb.png',
                      width: 45,
                      height: 45,
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Daily Finance Tip',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // 📅 Calendar
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
                    onFormatChanged: (_) {},
                    enabledDayPredicate: (day) {
                      final now = DateTime.now();
                      final today =
                      DateTime(now.year, now.month, now.day);
                      final target =
                      DateTime(day.year, day.month, day.day);
                      return !target.isAfter(today);
                    },
                    selectedDayPredicate: (day) =>
                        isSameDay(_selectedDay, day),
                    onDaySelected: (selectedDay, focusedDay) {
                      final now = DateTime.now();
                      final today =
                      DateTime(now.year, now.month, now.day);
                      final target = DateTime(
                        selectedDay.year,
                        selectedDay.month,
                        selectedDay.day,
                      );
                      if (target.isAfter(today)) return;

                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });

                      _loadTipForDate(selectedDay);
                    },
                    headerStyle: const HeaderStyle(
                      titleCentered: true,
                      formatButtonVisible: false,
                    ),
                    daysOfWeekStyle: const DaysOfWeekStyle(
                      weekdayStyle: TextStyle(fontSize: 10),
                      weekendStyle: TextStyle(fontSize: 10),
                    ),
                    calendarStyle: CalendarStyle(
                      defaultTextStyle:
                      const TextStyle(fontSize: 11),
                      weekendTextStyle:
                      const TextStyle(fontSize: 11),
                      todayTextStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      selectedTextStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      todayDecoration: const BoxDecoration(
                        color: Color(0xFFA7E399),
                        shape: BoxShape.circle,
                      ),
                      selectedDecoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                      outsideDaysVisible: false,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // 💡 Tip Card
                if (isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (dailyTip == null)
                  const Center(child: Text('No tip available'))
                else
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 🖼 Icon + Title
                        Row(
                          children: [
                            if (tipIconUrl != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  tipIconUrl!,
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                  errorBuilder:
                                      (context, error, stackTrace) {
                                    debugPrint(
                                        '❌ Image error: $error');
                                    return const Icon(
                                      Icons.image_not_supported,
                                      size: 40,
                                      color: Colors.grey,
                                    );
                                  },
                                ),
                              ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                dailyTip!['title'],
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        Padding(
                          padding: const EdgeInsets.only(left: 53),
                          child: Text(
                            dailyTip!['subTitle'],
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        Center(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                              const Color(0xFFA7E399),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                BorderRadius.circular(30),
                              ),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => TipDetailPage(
                                    tipId: dailyTip!['tipId'],
                                  ),
                                ),
                              );
                            },

                            child: const Text(
                              'Read Tip',
                              style:
                              TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
