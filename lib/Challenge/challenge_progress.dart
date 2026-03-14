import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:percent_indicator/percent_indicator.dart';

import 'leaderboard_page.dart';

class JoinedChallengeProgressPage
    extends StatefulWidget {
  final String participantId;

  const JoinedChallengeProgressPage({
    super.key,
    required this.participantId,
  });

  @override
  State<JoinedChallengeProgressPage>
  createState() =>
      _JoinedChallengeProgressPageState();
}

class _JoinedChallengeProgressPageState
    extends State<
        JoinedChallengeProgressPage> {
  Map<String, dynamic>? data;
  bool isLoading = true;

  DateTime? startDate;
  DateTime? endDate;

  String? challengeId;
  String? customChallengeId;

  DateTime _focusedDay =
  DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    loadProgress();
  }

  /// ===== LOAD DATA =====
  Future<void> loadProgress() async {
    final supabase =
        Supabase.instance.client;

    /// Participant
    final participant = await supabase
        .from('ChallengeParticipant')
        .select()
        .eq('challengeParticipantId',
        widget.participantId)
        .single();

    challengeId = participant['challengeId'];
    customChallengeId =
    participant['customChallengeId'];


    Map<String, dynamic>? challenge;
    int duration = 0;

    /// Preset challenge
    if (participant['challengeId'] !=
        null) {
      challenge = await supabase
          .from('Challenge')
          .select('title, duration')
          .eq('challengeId',
          participant['challengeId'])
          .single();

      duration = challenge['duration'];
    }

    /// Custom challenge
    if (participant[
    'customChallengeId'] !=
        null) {
      challenge = await supabase
          .from('CustomChallenge')
          .select('title, duration')
          .eq(
          'customChallengeId',
          participant[
          'customChallengeId'])
          .single();

      duration = challenge['duration'];
    }

    /// TEMP USER UID0001
    final user = await supabase
        .from('User')
        .select('profileImage, nickname')
        .eq('userId', 'UID0001')
        .single();

    startDate = DateTime.parse(
        participant['startDate']);
    endDate = DateTime.parse(
        participant['endDate']);

    setState(() {
      data = {
        "title": challenge?['title'],
        "progress":
        participant['progressValue'],
        "duration": duration,
        "profileImage":
        user['profileImage'],
        "nickname":
        user['nickname'],
      };
      isLoading = false;
    });
  }


  /// ===== RANGE HIGHLIGHT =====
  bool isWithinRange(DateTime day) {
    if (startDate == null ||
        endDate == null) return false;

    final start = DateTime(
        startDate!.year,
        startDate!.month,
        startDate!.day);

    final end = DateTime(
        endDate!.year,
        endDate!.month,
        endDate!.day);

    final current = DateTime(
        day.year, day.month, day.day);

    return (current
        .isAtSameMomentAs(
        start) ||
        current.isAfter(start)) &&
        (current.isAtSameMomentAs(
            end) ||
            current.isBefore(end));
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(
            child:
            CircularProgressIndicator()),
      );
    }

    final progress =
        (data!['progress'] ?? 0) /
            (data!['duration'] ?? 1);


    return Scaffold(
      backgroundColor:
      const Color(0xFFFEFFD3),

      /// ===== APPBAR =====
      appBar: AppBar(
        backgroundColor:
        const Color(0xFFFEFFD3),
        elevation: 0,
        leading: IconButton(
          icon:
          const Icon(Icons.arrow_back),
          onPressed: () =>
              Navigator.pop(context),
        ),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding:
          const EdgeInsets.all(20),
          child: Column(
            children: [
              /// ===== HEADER BELOW APPBAR =====
              Row(
                mainAxisAlignment:
                MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/joinChallenge.png',
                    width: 60,
                    height: 60,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      data!['title'],
                      style:
                      const TextStyle(
                        fontSize: 18,
                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              /// ===== PROGRESS CARD =====
              Container(
                padding:
                const EdgeInsets.all(
                    20),
                decoration:
                BoxDecoration(
                  color: Colors.white
                      .withValues(
                      alpha: 0.4),
                  borderRadius:
                  BorderRadius
                      .circular(
                      20),
                ),
                child: Column(
                  children: [
                    const Text(
                      "Progress",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight:
                        FontWeight
                            .bold,
                      ),
                    ),
                    const SizedBox(
                        height: 16),

                    /// USER IMAGE FROM DB
                    CircleAvatar(
                      radius: 35,
                      backgroundImage:
                      NetworkImage(
                        data![
                        'profileImage'],
                      ),
                    ),

                    Text(
                      data!['nickname'] ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),


                    const SizedBox(
                        height: 16),


                    LinearPercentIndicator(
                      lineHeight: 14,
                      percent:
                      progress.clamp(
                          0.0, 1.0),
                      backgroundColor:
                      Colors.grey
                          .shade300,
                      progressColor:
                      const Color(
                          0xFF9ED39E),
                      barRadius:
                      const Radius
                          .circular(
                          20),
                    ),

                    const SizedBox(
                        height: 8),

                    Text(
                      "Task completed ${data!['progress']}/${data!['duration']}",
                    ),

                  ],
                ),
              ),

              const SizedBox(height: 20),

              /// ===== CALENDAR =====
              Container(
                padding:
                const EdgeInsets.all(
                    12),
                decoration:
                BoxDecoration(
                  color: Colors.white
                      .withValues(
                      alpha: 0.4),
                  borderRadius:
                  BorderRadius
                      .circular(
                      20),
                ),
                child: TableCalendar(
                  firstDay:
                  DateTime.utc(
                      2023, 1, 1),
                  lastDay:
                  DateTime.utc(
                      2030, 12, 31),
                  focusedDay:
                  _focusedDay,

                  selectedDayPredicate:
                      (day) => isSameDay(
                      _selectedDay,
                      day),

                  onDaySelected:
                      (selectedDay,
                      focusedDay) {
                    setState(() {
                      _selectedDay =
                          selectedDay;
                      _focusedDay =
                          focusedDay;
                    });
                  },

                  headerStyle:
                  const HeaderStyle(
                    titleCentered: true,
                    formatButtonVisible:
                    false,
                  ),

                  calendarBuilders:
                  CalendarBuilders(
                    defaultBuilder:
                        (context, day,
                        _) {
                      if (isWithinRange(
                          day)) {
                        return Container(
                          margin:
                          const EdgeInsets
                              .all(6),
                          decoration:
                          const BoxDecoration(
                            color: Color(
                                0xFF9ED39E),
                            shape: BoxShape
                                .circle,
                          ),
                          alignment:
                          Alignment
                              .center,
                          child: Text(
                            '${day.day}',
                            style:
                            const TextStyle(
                              color: Colors
                                  .white,
                            ),
                          ),
                        );
                      }
                      return null;
                    },
                  ),
                ),
              ),

              const SizedBox(height: 30),

              /// ===== LEADERBOARD =====
              SizedBox(
                width: 220,
                height: 55,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            LeaderboardPage(
                              challengeId: challengeId,
                              customChallengeId: customChallengeId,
                            ),
                      ),
                    );
                  },

                  style:
                  ElevatedButton
                      .styleFrom(
                    backgroundColor:
                    const Color(
                        0xFF9ED39E),
                    shape:
                    RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius
                          .circular(
                          30),
                    ),
                  ),
                  child: const Text(
                    "View Leaderboard",
                    style: TextStyle(
                      color:
                      Colors.white,
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
