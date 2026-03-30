import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'View_Challenge.dart';
import 'challenge_progress.dart';

class ViewJoinedChallengePage
    extends StatefulWidget {

  final String userId;
  const ViewJoinedChallengePage({
    super.key,
    required this.userId,
  });

  @override
  State<ViewJoinedChallengePage>
  createState() =>
      _ViewJoinedChallengePageState();
}

class _ViewJoinedChallengePageState
    extends State<
        ViewJoinedChallengePage> {
  List<Map<String, dynamic>> joinedChallenges = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadJoinedChallenges();
  }

  Future<String> _generateChallengeParticipantId() async {
    final supabase = Supabase.instance.client;

    final lastRecord = await supabase
        .from('ChallengeParticipant')
        .select('challengeParticipantId')
        .order('challengeParticipantId', ascending: false)
        .limit(1)
        .maybeSingle();

    if (lastRecord == null || lastRecord['challengeParticipantId'] == null) {
      return 'CP00001';
    }

    final lastId = lastRecord['challengeParticipantId'].toString();
    final lastNumber = int.tryParse(lastId.replaceFirst('CP', '')) ?? 0;
    final newNumber = lastNumber + 1;

    return 'CP${newNumber.toString().padLeft(5, '0')}';
  }

  Future<void> _showInvitationActionDialog(Map<String, dynamic> challenge) async {
    final action = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFFF9E6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Challenge Invitation',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF52C77A),
            ),
          ),
          content: Text(
            'Do you want to accept or reject "${challenge['title']}"?',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'reject'),
              child: const Text('Reject'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, 'accept'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9ED39E),
              ),
              child: const Text(
                'Accept',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (action == 'reject') {
      await _rejectInvitation(challenge);
    } else if (action == 'accept') {
      await _acceptInvitation(challenge);
    }
  }

  Future<void> _rejectInvitation(Map<String, dynamic> challenge) async {
    final supabase = Supabase.instance.client;

    try {
      await supabase
          .from('ChallengeInvitation')
          .update({'status': 'reject'})
          .eq('challengeInvitationId', challenge['challengeInvitationId']);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invitation rejected')),
      );

      await loadJoinedChallenges();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error rejecting invitation: $e')),
      );
    }
  }

  Future<void> _acceptInvitation(Map<String, dynamic> challenge) async {
    final supabase = Supabase.instance.client;

    try {
      final existingParticipant = await supabase
          .from('ChallengeParticipant')
          .select('challengeParticipantId')
          .eq('userId', widget.userId)
          .eq(
        challenge['challengeId'] != null ? 'challengeId' : 'customChallengeId',
        challenge['challengeId'] ?? challenge['customChallengeId'],
      )
          .maybeSingle();

      if (existingParticipant != null) {
        await supabase
            .from('ChallengeInvitation')
            .update({'status': 'accept'})
            .eq('challengeInvitationId', challenge['challengeInvitationId']);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You already joined this challenge')),
        );

        await loadJoinedChallenges();
        return;
      }

      int duration = 0;

      if (challenge['challengeId'] != null) {
        final challengeData = await supabase
            .from('Challenge')
            .select('duration')
            .eq('challengeId', challenge['challengeId'])
            .single();

        duration = challengeData['duration'] ?? 0;
      }

      if (challenge['customChallengeId'] != null) {
        final customData = await supabase
            .from('CustomChallenge')
            .select('duration')
            .eq('customChallengeId', challenge['customChallengeId'])
            .single();

        duration = customData['duration'] ?? 0;
      }

      final participantId = await _generateChallengeParticipantId();
      final startDate = DateTime.now();
      final endDate = startDate.add(Duration(days: duration));

      await supabase.from('ChallengeParticipant').insert({
        'challengeParticipantId': participantId,
        'userId': widget.userId,
        'challengeId': challenge['challengeId'],
        'customChallengeId': challenge['customChallengeId'],
        'progressValue': 0,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
      });

      await supabase
          .from('ChallengeInvitation')
          .update({'status': 'accept'})
          .eq('challengeInvitationId', challenge['challengeInvitationId']);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invitation accepted')),
      );

      await loadJoinedChallenges();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error accepting invitation: $e')),
      );
    }
  }

  /// ===== LOAD JOINED =====
  Future<void> loadJoinedChallenges() async {
    final supabase = Supabase.instance.client;

    final now = DateTime.now().toIso8601String();

    final participants = await supabase
        .from('ChallengeParticipant')
        .select('challengeParticipantId, challengeId, customChallengeId, userId, endDate, hasViewedResult, hasClaimedReward')
        .eq('userId', widget.userId)
        .or('hasViewedResult.eq.false,hasClaimedReward.eq.false');

    List<Map<String, dynamic>> tempList = [];

    for (var p in participants) {
      /// PRESET challenge
      if (p['challengeId'] != null) {

        print("DEBUG participant loop");
        print("participant: $p");
        print("challengeId: ${p['challengeId']}");
        final preset = await supabase
            .from('Challenge')
            .select('title')
            .eq('challengeId', p['challengeId'])
            .single();

        tempList.add({
          "title": preset['title'],
          "participantId": p['challengeParticipantId'],
          "isInvitation": false,
        });
      }

      /// CUSTOM challenge
      if (p['customChallengeId'] != null) {
        final custom = await supabase
            .from('CustomChallenge')
            .select('title')
            .eq('customChallengeId', p['customChallengeId'])
            .single();

        tempList.add({
          "title": custom['title'],
          "participantId": p['challengeParticipantId'],
          "isInvitation": false,
        });
      }
    }

    final invitations = await supabase
        .from('ChallengeInvitation')
        .select('challengeInvitationId, challengeId, customChallengeId, status')
        .eq('receiverUserId', widget.userId)
        .eq('status', 'pending');

    for (var i in invitations) {
      if (i['challengeId'] != null) {

        print("DEBUG invitation loop");
        print("invitation: $i");
        print("challengeId: ${i['challengeId']}");

        final preset = await supabase
            .from('Challenge')
            .select('title')
            .eq('challengeId', i['challengeId'])
            .maybeSingle();

        tempList.add({
          "title": preset?['title'] ?? 'Unknown Challenge',
          "challengeInvitationId": i['challengeInvitationId'],
          "challengeId": i['challengeId'],
          "customChallengeId": null,
          "isInvitation": true,
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
                builder: (_) => ViewChallengePage(userId: widget.userId),
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
                      print("🔥 CLICKED ITEM: $c");
                      if (c['isInvitation'] == true) {
                        _showInvitationActionDialog(c);
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => JoinedChallengeProgressPage(
                              participantId: c['participantId'],
                            ),
                          ),
                        );
                      }
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
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              c['title'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (c['isInvitation'] == true)
                            const Icon(
                              Icons.notifications_active,
                              color: Colors.red,
                            ),
                        ],
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
