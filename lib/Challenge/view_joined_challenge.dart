import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'View_Challenge.dart';
import 'challenge_progress.dart';

class ViewJoinedChallengePage
    extends StatefulWidget {
  const ViewJoinedChallengePage(
      {super.key});

  @override
  State<ViewJoinedChallengePage>
  createState() =>
      _ViewJoinedChallengePageState();
}

class _ViewJoinedChallengePageState
    extends State<
        ViewJoinedChallengePage> {
  List joinedChallenges = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadJoinedChallenges();
  }

  /// ===== LOAD JOINED =====
  Future<void> loadJoinedChallenges() async {
    final supabase = Supabase.instance.client;

    /// Get all participants (userId null for now)
    final participants =
    await supabase
        .from('ChallengeParticipant')
        .select(
        'challengeParticipantId, challengeId, customChallengeId');


    List tempList = [];

    /// Loop participants
    for (var p in participants) {

      /// PRESET
      if (p['challengeId'] != null) {
        final preset = await supabase
            .from('Challenge')
            .select('title')
            .eq('challengeId', p['challengeId'])
            .single();

        tempList.add({
          "title": preset['title'],
          "participantId":
          p['challengeParticipantId'], // ADD
        });
      }

      /// CUSTOM
      if (p['customChallengeId'] != null) {
        final custom = await supabase
            .from('CustomChallenge')
            .select('title')
            .eq('customChallengeId',
            p['customChallengeId'])
            .single();

        tempList.add({
          "title": custom['title'],
          "participantId":
          p['challengeParticipantId'], // ADD
        });
      }
    }


    setState(() {
      joinedChallenges = tempList;
      isLoading = false;
    });
  }

  /// ===== UI =====
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
      const Color(0xFFFEFFD3),

      appBar: AppBar(
        backgroundColor: const Color(0xFFFEFFD3),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) =>
                const ViewChallengePage(),
              ),
            );
          },
        ),

      ),


      body: Padding(
        padding:
        const EdgeInsets.all(20),
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
                const Text(
                  'Challenge Joined',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            /// ===== LIST =====
            Expanded(
              child: isLoading
                  ? const Center(
                  child:
                  CircularProgressIndicator())
                  : joinedChallenges
                  .isEmpty
                  ? const Center(
                  child: Text(
                    "No challenges joined yet",
                  ))
                  : ListView.builder(
                itemCount:
                joinedChallenges
                    .length,
                itemBuilder:
                    (context,
                    index) {
                  final c =
                  joinedChallenges[
                  index];

                  return InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      /// Navigate to Progress Page
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              JoinedChallengeProgressPage(
                                participantId:
                                c['participantId'], // pass ID
                              ),
                        ),
                      );
                    },
                    child: Container(
                      margin:
                      const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white
                            .withValues(alpha: 0.4),
                        borderRadius:
                        BorderRadius.circular(20),
                      ),
                      child: Text(
                        c['title'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );

                    },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
