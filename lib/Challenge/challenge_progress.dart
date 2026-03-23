import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:percent_indicator/percent_indicator.dart';

import 'leaderboard_page.dart';

class JoinedChallengeProgressPage extends StatefulWidget {
  final String participantId;

  const JoinedChallengeProgressPage({
    super.key,
    required this.participantId,
  });

  @override
  State<JoinedChallengeProgressPage> createState() =>
      _JoinedChallengeProgressPageState();
}

class _JoinedChallengeProgressPageState
    extends State<JoinedChallengeProgressPage> {
  Map<String, dynamic>? data;
  bool isLoading = true;

  DateTime? startDate;
  DateTime? endDate;

  String? challengeId;
  String? customChallengeId;

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  final TextEditingController _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadProgress();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> loadProgress() async {
    final supabase = Supabase.instance.client;

    final participant = await supabase
        .from('ChallengeParticipant')
        .select()
        .eq('challengeParticipantId', widget.participantId)
        .single();

    challengeId = participant['challengeId'];
    customChallengeId = participant['customChallengeId'];

    Map<String, dynamic>? challenge;
    int duration = 0;
    double targetValue = 0;

    if (participant['challengeId'] != null) {
      challenge = await supabase
          .from('Challenge')
          .select('challengeId, title, duration')
          .eq('challengeId', participant['challengeId'])
          .single();

      duration = challenge['duration'] ?? 0;

      switch (participant['challengeId']) {
        case 'PC0001':
          targetValue = 7;
          break;
        case 'PC0002':
          final budgetData = await supabase
              .from('Budget')
              .select('amount')
              .eq('userId', participant['userId'])
              .maybeSingle();

          targetValue = budgetData != null
              ? (budgetData['amount'] as num).toDouble()
              : 0;
          break;
        case 'PC0003':
          targetValue = 3;
          break;
        case 'PC0004':
          targetValue = 50;
          break;
      }
    }

    if (participant['customChallengeId'] != null) {
      challenge = await supabase
          .from('CustomChallenge')
          .select('title, duration, targetAmount')
          .eq('customChallengeId', participant['customChallengeId'])
          .single();

      duration = challenge['duration'] ?? 0;
      targetValue = ((challenge['targetAmount'] ?? duration) as num).toDouble();
    }

    final user = await supabase
        .from('User')
        .select('profileImage, nickname')
        .eq('userId', participant['userId'])
        .single();

    startDate = DateTime.parse(participant['startDate']);
    endDate = DateTime.parse(participant['endDate']);

    setState(() {
      data = {
        "title": challenge?['title'] ?? '',
        "progress": (participant['progressValue'] ?? 0) as num,
        "duration": duration,
        "targetValue": targetValue,
        "profileImage": user['profileImage'],
        "nickname": user['nickname'],
        "userId": participant['userId'], // sender user
      };
      isLoading = false;
    });
  }

  bool isWithinRange(DateTime day) {
    if (startDate == null || endDate == null) return false;

    final start = DateTime(startDate!.year, startDate!.month, startDate!.day);
    final end = DateTime(endDate!.year, endDate!.month, endDate!.day);
    final current = DateTime(day.year, day.month, day.day);

    return (current.isAtSameMomentAs(start) || current.isAfter(start)) &&
        (current.isAtSameMomentAs(end) || current.isBefore(end));
  }

  bool isCompletedDay(DateTime day) {
    if (!isWithinRange(day)) return false;

    final today = DateTime.now();
    final current = DateTime(day.year, day.month, day.day);
    final normalizedToday = DateTime(today.year, today.month, today.day);

    return current.isAtSameMomentAs(normalizedToday) ||
        current.isBefore(normalizedToday);
  }

  double getProgressPercent() {
    if (data == null) return 0;

    final progress = (data!['progress'] as num).toDouble();
    final target = (data!['targetValue'] as num).toDouble();

    if (target <= 0) return 0;
    return (progress / target).clamp(0.0, 1.0);
  }

  String getProgressText() {
    if (data == null) return '';

    final progress = (data!['progress'] as num).toDouble();
    final target = (data!['targetValue'] as num).toDouble();

    switch (challengeId) {
      case 'PC0001':
        return "Streak progress ${progress.toInt()}/${target.toInt()} days";
      case 'PC0002':
        if (target <= 0) {
          return "No budget set";
        }
        return "Expense used RM${progress.toStringAsFixed(2)} / RM${target.toStringAsFixed(2)}";
      case 'PC0003':
        return "Safe days ${progress.toInt()}/${target.toInt()} days";
      case 'PC0004':
        return "Saved RM${progress.toStringAsFixed(2)} / RM${target.toStringAsFixed(2)}";
      default:
        return "Progress ${progress.toStringAsFixed(0)}/${target.toStringAsFixed(0)}";
    }
  }

  String getProgressTitle() {
    switch (challengeId) {
      case 'PC0001':
        return "Streak Progress";
      case 'PC0002':
        return "Budget Progress";
      case 'PC0003':
        return "Safe Day Progress";
      case 'PC0004':
        return "Saving Progress";
      default:
        return "Progress";
    }
  }

  Future<String> _generateChallengeInvitationId() async {
    final supabase = Supabase.instance.client;

    final lastRecord = await supabase
        .from('ChallengeInvitation')
        .select('challengeInvitationId')
        .order('challengeInvitationId', ascending: false)
        .limit(1)
        .maybeSingle();

    if (lastRecord == null || lastRecord['challengeInvitationId'] == null) {
      return 'CI00001';
    }

    final lastId = lastRecord['challengeInvitationId'].toString(); // e.g. CI00012
    final lastNumber = int.tryParse(lastId.replaceFirst('CI', '')) ?? 0;
    final newNumber = lastNumber + 1;

    return 'CI${newNumber.toString().padLeft(5, '0')}';
  }

  Future<void> _showInviteFriendDialog() async {
    _phoneController.clear();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFFF9E6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Invite Friend',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF52C77A),
            ),
          ),
          content: TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              hintText: 'Enter phone number',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _validateAndInvite();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9ED39E),
              ),
              child: const Text(
                'Search',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _validateAndInvite() async {
    final supabase = Supabase.instance.client;
    final phoneNumber = _phoneController.text.trim();

    if (phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter phone number')),
      );
      return;
    }

    try {
      final user = await supabase
          .from('User')
          .select('userId, nickname, phoneNumber')
          .eq('phoneNumber', phoneNumber)
          .maybeSingle();

      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Phone number not found')),
        );
        return;
      }

      if (user['userId'] == data!['userId']) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You cannot invite yourself')),
        );
        return;
      }

      final existingInvitation = await supabase
          .from('ChallengeInvitation')
          .select('challengeInvitationId')
          .eq('senderUserId', data!['userId'])
          .eq('receiverUserId', user['userId'])
          .eq('status', 'pending')
          .maybeSingle();

      if (existingInvitation != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invitation already sent')),
        );
        return;
      }

      dynamic participantQuery = supabase
          .from('ChallengeParticipant')
          .select('challengeParticipantId')
          .eq('userId', user['userId']);

      if (challengeId != null) {
        participantQuery = participantQuery.eq('challengeId', challengeId!);
      } else {
        participantQuery = participantQuery.isFilter('challengeId', null);
      }

      if (customChallengeId != null) {
        participantQuery =
            participantQuery.eq('customChallengeId', customChallengeId!);
      } else {
        participantQuery = participantQuery.isFilter('customChallengeId', null);
      }

      final existingParticipant = await participantQuery.maybeSingle();

      if (existingParticipant != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This user already joined the challenge')),
        );
        return;
      }

      _showConfirmInvitationDialog(user);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error validating phone number: $e')),
      );
    }
  }

  Future<void> _showConfirmInvitationDialog(Map<String, dynamic> user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFFF9E6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Confirm Invitation',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF52C77A),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Username: ${user['nickname'] ?? ''}'),
              const SizedBox(height: 8),
              Text('Phone Number: ${user['phoneNumber'] ?? ''}'),
              const SizedBox(height: 16),
              const Text('Do you want to send this invitation?'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9ED39E),
              ),
              child: const Text(
                'Confirm',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await _insertInvitation(user);
    }
  }

  Future<void> _insertInvitation(Map<String, dynamic> receiverUser) async {
    final supabase = Supabase.instance.client;

    try {
      final invitationId = await _generateChallengeInvitationId();

      await supabase.from('ChallengeInvitation').insert({
        'challengeInvitationId': invitationId,
        'createdAt': DateTime.now().toIso8601String(),
        'senderUserId': data!['userId'],
        'receiverUserId': receiverUser['userId'],
        'challengeId': challengeId,
        'customChallengeId': customChallengeId,
        'status': 'pending',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invitation sent successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending invitation: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final progressPercent = getProgressPercent();

    return Scaffold(
      backgroundColor: const Color(0xFFFEFFD3),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFEFFD3),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
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
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Text(
                      getProgressTitle(),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    CircleAvatar(
                      radius: 35,
                      backgroundImage: data!['profileImage'] != null &&
                          data!['profileImage'].toString().isNotEmpty
                          ? NetworkImage(data!['profileImage'])
                          : null,
                      child: data!['profileImage'] == null ||
                          data!['profileImage'].toString().isEmpty
                          ? const Icon(Icons.person)
                          : null,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      data!['nickname'] ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    LinearPercentIndicator(
                      lineHeight: 14,
                      percent: progressPercent,
                      backgroundColor: Colors.grey.shade300,
                      progressColor: const Color(0xFF9ED39E),
                      barRadius: const Radius.circular(20),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      getProgressText(),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
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
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                  },
                  headerStyle: const HeaderStyle(
                    titleCentered: true,
                    formatButtonVisible: false,
                  ),
                  calendarBuilders: CalendarBuilders(
                    defaultBuilder: (context, day, _) {
                      if (isWithinRange(day)) {
                        final completed = isCompletedDay(day);

                        return Container(
                          margin: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: completed
                                ? const Color(0xFF9ED39E)
                                : Colors.grey.shade400,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${day.day}',
                            style: const TextStyle(color: Colors.white),
                          ),
                        );
                      }
                      return null;
                    },
                    todayBuilder: (context, day, _) {
                      if (isWithinRange(day)) {
                        final completed = isCompletedDay(day);

                        return Container(
                          margin: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: completed
                                ? const Color(0xFF9ED39E)
                                : Colors.grey.shade400,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${day.day}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
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

              Center(
                child: SizedBox(
                  width: 340, // control total width of both buttons
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 60,
                          child: ElevatedButton(
                            onPressed: _showInviteFriendDialog,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF39C12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text(
                              "Invite Friends",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: SizedBox(
                          height: 60,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => LeaderboardPage(
                                    challengeId: challengeId,
                                    customChallengeId: customChallengeId,
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF9ED39E),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text(
                              "View Leaderboard",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
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