import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fyp_zy/FinancialTip/tip_detail_page.dart';
import 'package:fyp_zy/FinancialTip/view_tips_page.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:url_launcher/url_launcher.dart';

import '../Missions/mission_service.dart';

class DailyFinanceTipPage extends StatefulWidget {
  final String userId;

  const DailyFinanceTipPage({
    super.key,
    required this.userId,
  });

  @override
  State<DailyFinanceTipPage> createState() => _DailyFinanceTipPageState();
}

class _DailyFinanceTipPageState extends State<DailyFinanceTipPage> {
  late DateTime _focusedDay;
  late DateTime _selectedDay;

  String? newsTitle;
  String? newsUrl;


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

  Future<Map<String, dynamic>?> fetchFinancialNews() async {
    final apiKey = dotenv.env['NEWS_API_KEY'];

    final url = Uri.parse(
      "https://newsapi.org/v2/top-headlines?category=business&language=en&apiKey=$apiKey",
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (data['articles'].isNotEmpty) {
        return data['articles'][0];
      }
    }

    return null;
  }

  Future<Map<String, dynamic>?> findMatchingCategory(String newsTitle) async {

    final supabase = Supabase.instance.client;

    final categories = await supabase
        .from('TipCategory')
        .select('tipCategoryId,title,topicKeyword');

    newsTitle = newsTitle
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ');

    int bestScore = 0;
    Map<String, dynamic>? bestCategory;

    for (var category in categories) {

      String keywords = category['topicKeyword'] ?? "";
      List<String> keywordList = keywords.split(',');

      int score = 0;

      for (var keyword in keywordList) {

        String word = keyword
            .trim()
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9 ]'), '');

        if (newsTitle.contains(word)) {
          score++;
          debugPrint("Matched keyword: $word");
        }

      }

      if (score > bestScore) {
        bestScore = score;
        bestCategory = category;
      }

    }

    return bestCategory;
  }

  Future<void> _loadTipForDate(DateTime date) async {
    final targetDay = DateTime(date.year, date.month, date.day);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final supabase = Supabase.instance.client;

    bool isToday =
        targetDay.year == today.year &&
            targetDay.month == today.month &&
            targetDay.day == today.day;

    if (targetDay.isAfter(today)) {
      setState(() {
        dailyTip = null;
        isLoading = false;
      });
      return;
    }

    setState(() => isLoading = true);

    final existing = await supabase
        .from('DailyFinanceRecommendation')
        .select()
        .eq('date', targetDay.toIso8601String().split("T")[0])
        .maybeSingle();

    if (existing != null) {

      newsTitle = existing['newsTitle'];
      newsUrl = existing['newsUrl'];

      final tip = await supabase
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
          .eq('tipId', existing['tipId'])
          .single();

      dailyTip = tip;

      setState(() => isLoading = false);
      return;
    }

    try {

      dynamic category;
      List<dynamic> tips;
      String? combinedNews;

      if (isToday) {

        /// 1️⃣ Fetch news ONLY for today
        final news = await fetchFinancialNews();

        if (news != null) {
          combinedNews =
              "${news['title']} ${news['description'] ?? ""}";
          newsTitle = news['title'];
          newsUrl = news['url'];

          debugPrint("News title from API: ${news['title']}");
        }

        /// 2️⃣ Match category
        if (combinedNews != null) {
          category = await findMatchingCategory(combinedNews);
        }

      } else {

        /// ❌ Past date → no news
        newsTitle = null;
        newsUrl = null;

      }

      /// 3️⃣ Fetch tips
      if (category != null) {

        tips = await supabase
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
            .eq('tipCategoryId', category['tipCategoryId']);

      } else {

        /// fallback → random tips
        tips = await supabase
            .from('FinancialTip')
            .select('''
          tipId,
          title,
          subTitle,
          content,
          TipCategory (
            tipIcon
          )
        ''');

      }

      /// 4️⃣ Pick one tip
      if (tips.isNotEmpty) {

        /// random tip for both cases
        tips.shuffle();
        dailyTip = tips.first;

        final last = await supabase
            .from('DailyFinanceRecommendation')
            .select('recommendationId')
            .order('date', ascending: false)
            .limit(1)
            .maybeSingle();

        String newId = "R0001";

        if (last != null) {
          int num = int.parse(last['recommendationId'].substring(1)) + 1;
          newId = "R${num.toString().padLeft(4, '0')}";
        }

        if (isToday && dailyTip != null) {

          await supabase.from('DailyFinanceRecommendation').upsert({
            'recommendationId': newId,
            'date': targetDay.toIso8601String().split("T")[0],
            'tipId': dailyTip!['tipId'],
            'newsTitle': newsTitle,
            'newsUrl': newsUrl
          });

        }

      } else {
        dailyTip = null;
      }

    } catch (e) {
      debugPrint('❌ Error fetching smart tip: $e');
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
          onPressed: () => Navigator.pop(context),
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
                            onPressed: () async {
                              await MissionService.completeMission(
                                userId: widget.userId,
                                missionId: 'M002',
                              );

                              if (!mounted) return;

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
                const SizedBox(height :20),

                ///news section
                if (newsTitle != null)
                  Container(
                    margin: const EdgeInsets.only(top: 20),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        const Text(
                          "Related Financial News",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),

                        const SizedBox(height: 8),

                        Text(newsTitle!),

                        const SizedBox(height: 10),

                        InkWell(
                          onTap: () async {
                            if (newsUrl != null) {
                              final uri = Uri.parse(newsUrl!);
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            }
                          },
                          child: const Text(
                            "Read News",
                            style: TextStyle(
                              color: Colors.blue,
                              decoration: TextDecoration.underline,
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
