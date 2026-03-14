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
  State<LeaderboardPage> createState() =>
      _LeaderboardPageState();
}

class _LeaderboardPageState
    extends State<LeaderboardPage> {
  List participants = [];
  bool isLoading = true;
  String challengeTitle = "";


  @override
  void initState() {
    super.initState();
    loadLeaderboard();
  }

  /// ================= LOAD =================
  Future<void> loadLeaderboard() async {
    final supabase = Supabase.instance.client;

    late final List data;

    /// ===== GET CHALLENGE TITLE =====
    if (widget.challengeId != null) {

      final challenge = await supabase
          .from('Challenge')
          .select('title')
          .eq('challengeId', widget.challengeId!)
          .single();

      challengeTitle = challenge['title'];

      data = await supabase
          .from('ChallengeParticipant')
          .select('progressValue, userId')
          .eq('challengeId', widget.challengeId!)
          .order('progressValue', ascending: false);

    }

    else if (widget.customChallengeId != null) {

      final challenge = await supabase
          .from('CustomChallenge')
          .select('title')
          .eq('customChallengeId', widget.customChallengeId!)
          .single();

      challengeTitle = challenge['title'];

      data = await supabase
          .from('ChallengeParticipant')
          .select('progressValue, userId')
          .eq('customChallengeId',
          widget.customChallengeId!)
          .order('progressValue', ascending: false);
    }

    else {
      data = [];
    }

    /// ===== BUILD PARTICIPANTS =====
    List temp = [];

    for (var p in data) {
      if (p['userId'] == null) continue;

      final userList = await supabase
          .from('User')
          .select('nickname, profileImage')
          .eq('userId', p['userId']);

      if (userList.isEmpty) continue;

      final user = userList.first;

      temp.add({
        "nickname": user['nickname'],
        "profileImage": user['profileImage'],
        "progress": p['progressValue'] ?? 0,
      });
    }

    setState(() {
      participants = temp;
      isLoading = false;
    });
  }



  /// ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
      const Color(0xFFFEFFD3),

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

      body: isLoading
          ? const Center(
          child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [

            /// ===== HEADER =====
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
                    challengeTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            /// ===== LEADERBOARD CONTAINER =====
            Expanded(
              child: Container(
                padding:
                const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white
                      .withValues(alpha: 0.4),
                  borderRadius:
                  BorderRadius.circular(
                      20),
                ),

                child: Column(
                  children: [

                    /// TITLE
                    const Text(
                      "Leaderboard",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 20),

                    /// ===== PODIUM =====
                    buildPodium(),

                    const SizedBox(height: 20),

                    /// ===== REMAINING USERS =====
                    Expanded(
                      child: participants
                          .length >
                          3
                          ? ListView.builder(
                        itemCount:
                        participants
                            .length -
                            3,
                        itemBuilder:
                            (context,
                            index) {
                          final p =
                          participants[
                          index +
                              3];

                          return buildRankCard(
                            index + 4,
                            p,
                          );
                        },
                      )
                          : const Center(
                        child: Text(
                          "No more participants",
                          style:
                          TextStyle(
                            color: Colors
                                .grey,
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

    );
  }

  /// ================= PODIUM =================
  Widget buildPodium() {
    if (participants.isEmpty) {
      return const Text(
          "No leaderboard data");
    }

    return Container(
      padding:
      const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white
            .withValues(alpha: 0.4),
        borderRadius:
        BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment:
        MainAxisAlignment.spaceEvenly,
        crossAxisAlignment:
        CrossAxisAlignment.end,
        children: [
          if (participants.length >= 2)
            buildTopUser(
                participants[1], 2),

          buildTopUser(
              participants[0], 1,
              isFirst: true),

          if (participants.length >= 3)
            buildTopUser(
                participants[2], 3),
        ],
      ),
    );
  }

  /// ================= TOP USER =================
  Widget buildTopUser(
      Map user,
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
        medalColor =
            Colors.brown.shade300;
        break;
      default:
        medalColor = Colors.green;
    }

    return Column(
      children: [
        Stack(
          alignment:
          Alignment.bottomCenter,
          children: [
            /// Avatar ring
            Container(
              padding:
              const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: medalColor,
                  width: 3,
                ),
              ),
              child: CircleAvatar(
                radius:
                isFirst ? 38 : 30,
                backgroundImage:
                NetworkImage(
                  user['profileImage'],
                ),
              ),
            ),

            /// Medal badge
            Positioned(
              bottom: -4,
              child: CircleAvatar(
                radius: 14,
                backgroundColor:
                medalColor,
                child: Text(
                  "$rank",
                  style:
                  const TextStyle(
                    color: Colors.white,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 6),

        Text(
          user['nickname'],
          style: const TextStyle(
            fontWeight:
            FontWeight.bold,
          ),
        ),

        Text("${user['progress']}%"),
      ],
    );
  }

  /// ================= RANK CARD =================
  Widget buildRankCard(
      int rank, Map user) {
    return Container(
      margin:
      const EdgeInsets.only(
          bottom: 12),
      padding:
      const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF9ED39E),
            const Color(0xFFCDE8C9),
          ],
        ),
        borderRadius:
        BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          /// Rank circle
          CircleAvatar(
            backgroundColor:
            Colors.green,
            child: Text(
              "$rank",
              style: const TextStyle(
                color: Colors.white,
                fontWeight:
                FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(width: 12),

          /// Name
          Expanded(
            child: Text(
              user['nickname'],
              style: const TextStyle(
                fontWeight:
                FontWeight.bold,
              ),
            ),
          ),

          /// Progress
          Text("${user['progress']}%"),
        ],
      ),
    );
  }
}
