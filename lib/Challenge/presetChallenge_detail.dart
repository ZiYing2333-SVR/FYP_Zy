import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'challenge_tracking_service.dart';

class ChallengeDetailsPage extends StatefulWidget {
  final String userId;
  final String challengeId;
  final String title;
  final String rules;
  final int duration;
  final int coins;

  const ChallengeDetailsPage({
    super.key,
    required this.userId,
    required this.challengeId,
    required this.title,
    required this.rules,
    required this.duration,
    required this.coins,
  });

  @override
  State<ChallengeDetailsPage> createState() => _ChallengeDetailsPageState();
}

class _ChallengeDetailsPageState extends State<ChallengeDetailsPage> {
  Future<String> generateParticipantId() async {
    final supabase = Supabase.instance.client;

    final data = await supabase
        .from('ChallengeParticipant')
        .select('challengeParticipantId')
        .order('challengeParticipantId', ascending: false)
        .limit(1);

    if (data.isEmpty) {
      return "CP0001";
    }

    final lastId = data.first['challengeParticipantId'];
    final number = int.parse(lastId.substring(2)) + 1;

    return "CP${number.toString().padLeft(4, '0')}";
  }

  Future<void> joinChallenge() async {
    final supabase = Supabase.instance.client;

    try {
      /// optional: prevent duplicate join
      final existing = await supabase
          .from('ChallengeParticipant')
          .select('challengeParticipantId')
          .eq('userId', widget.userId)
          .eq('challengeId', widget.challengeId)
          .maybeSingle();

      if (existing != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You already joined this challenge'),
          ),
        );
        return;
      }

      final participantId = await generateParticipantId();

      final startDate = DateTime.now();
      final endDate = startDate.add(Duration(days: widget.duration - 1));

      await supabase.from('ChallengeParticipant').insert({
        "challengeParticipantId": participantId,
        "progressValue": 0,
        "coinEarned": 0,
        "isWinner": false,
        "startDate": startDate.toIso8601String(),
        "endDate": endDate.toIso8601String(),
        "joinedAt": DateTime.now().toIso8601String(),
        "isComplete": false,
        "userId": widget.userId,
        "challengeId": widget.challengeId,
      });

      await ChallengeTrackingService().updateUserChallenges(widget.userId);

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.emoji_events,
                color: Color(0xFF4CAF50),
                size: 60,
              ),
              const SizedBox(height: 16),
              const Text(
                "Successfully Joined!",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Start completing the challenge now!",
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: 120,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9ED39E),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    "OK",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error joining challenge: $e');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to join challenge: $e')),
      );
    }
  }

  List<String> formatRules(String rulesText) {
    return rulesText
        .split('.')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final formattedRules = formatRules(widget.rules);

    return Scaffold(
      backgroundColor: const Color(0xFFFEFFD3),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/presetChallenge.png',
                    width: 60,
                    height: 60,
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Pre-set Challenge',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text("Duration: ${widget.duration} Days"),
                    Text("Reward: ${widget.coins} Coins"),
                    const SizedBox(height: 20),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: formattedRules.length,
                      itemBuilder: (context, index) {
                        return Text("${index + 1}. ${formattedRules[index]}");
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              Center(
                child: SizedBox(
                  width: 200,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: joinChallenge,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9ED39E),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text(
                      "Join",
                      style: TextStyle(
                        fontSize: 16,
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
    );
  }
}