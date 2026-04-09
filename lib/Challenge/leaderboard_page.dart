import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LeaderboardPage extends StatefulWidget {
  final String? challengeId;
  final String? customChallengeId;

  const LeaderboardPage({
    super.key,
    this.challengeId,
    this.customChallengeId,
  });

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  List<Map<String, dynamic>> participants = [];
  bool isLoading = true;
  String challengeTitle = "";
  String? loadedChallengeId;

  @override
  void initState() {
    super.initState();
    loadLeaderboard();
  }

  Future<void> loadLeaderboard() async {
    final supabase = Supabase.instance.client;

    late final List data;

    if (widget.challengeId != null) {
      loadedChallengeId = widget.challengeId;

      final challenge = await supabase
          .from('Challenge')
          .select('title, challengeId')
          .eq('challengeId', widget.challengeId!)
          .single();

      challengeTitle = challenge['title'];

      data = await supabase
          .from('ChallengeParticipant')
          .select('progressValue, userId, isComplete')
          .eq('challengeId', widget.challengeId!)
          .eq('isComplete', false)
          .order('progressValue', ascending: false);
    } else if (widget.customChallengeId != null) {
      loadedChallengeId = null;

      final challenge = await supabase
          .from('CustomChallenge')
          .select('title')
          .eq('customChallengeId', widget.customChallengeId!)
          .single();

      challengeTitle = challenge['title'];

      data = await supabase
          .from('ChallengeParticipant')
          .select('progressValue, userId, isComplete')
          .eq('customChallengeId', widget.customChallengeId!)
          .eq('isComplete', false)
          .order('progressValue', ascending: false);
    } else {
      data = [];
    }

    List<Map<String, dynamic>> temp = [];

    for (var p in data) {
      if (p['userId'] == null) continue;

      final user = await supabase
          .from('User')
          .select('nickname, profileImage')
          .eq('userId', p['userId'])
          .single();

      temp.add({
        "nickname": user['nickname'] ?? 'Unknown',
        "profileImage": user['profileImage'] ?? '',
        "progress": (p['progressValue'] ?? 0) as num,
      });
    }

    setState(() {
      participants = temp;
      isLoading = false;
    });
  }

  String formatProgress(num progress) {
    switch (loadedChallengeId) {
      case 'PC0001':
        return "${progress.toInt()} days";

      case 'PC0002':
        return "RM${progress.toStringAsFixed(2)}";

      case 'PC0003':
        return "${progress.toInt()} days";

      case 'PC0004':
        return "RM${progress.toStringAsFixed(2)}";

      default:
        return progress.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
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
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
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
                    challengeTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    const Text(
                      "Leaderboard",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    buildPodium(),
                    const SizedBox(height: 20),
                    Expanded(
                      child: participants.length > 3
                          ? ListView.builder(
                        itemCount: participants.length - 3,
                        itemBuilder: (context, index) {
                          final p = participants[index + 3];
                          return buildRankCard(index + 4, p);
                        },
                      )
                          : const Center(
                        child: Text(
                          "No more participants",
                          style: TextStyle(color: Colors.grey),
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
    );
  }

  Widget buildPodium() {
    if (participants.isEmpty) {
      return const Text("No leaderboard data");
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (participants.length >= 2) buildTopUser(participants[1], 2),
          buildTopUser(participants[0], 1, isFirst: true),
          if (participants.length >= 3) buildTopUser(participants[2], 3),
        ],
      ),
    );
  }

  Widget buildTopUser(
      Map<String, dynamic> user,
      int rank, {
        bool isFirst = false,
      }) {
    Color medalColor;

    switch (rank) {
      case 1:
        medalColor = Colors.orange;
        break;
      case 2:
        medalColor = Colors.grey;
        break;
      case 3:
        medalColor = Colors.brown.shade300;
        break;
      default:
        medalColor = Colors.green;
    }

    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: medalColor,
                  width: 3,
                ),
              ),
              child: CircleAvatar(
                radius: isFirst ? 38 : 30,
                backgroundImage: user['profileImage'] != null &&
                    user['profileImage'].toString().isNotEmpty
                    ? NetworkImage(user['profileImage'])
                    : null,
                child: user['profileImage'] == null ||
                    user['profileImage'].toString().isEmpty
                    ? const Icon(Icons.person)
                    : null,
              ),
            ),
            Positioned(
              bottom: -4,
              child: CircleAvatar(
                radius: 14,
                backgroundColor: medalColor,
                child: Text(
                  "$rank",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          user['nickname'],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        Text(formatProgress(user['progress'])),
      ],
    );
  }

  Widget buildRankCard(int rank, Map<String, dynamic> user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF9ED39E),
            Color(0xFFCDE8C9),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.green,
            child: Text(
              "$rank",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              user['nickname'],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Text(formatProgress(user['progress'])),
        ],
      ),
    );
  }
}