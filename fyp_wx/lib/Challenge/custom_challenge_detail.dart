import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CustomChallengeDetailsPage
    extends StatefulWidget {
  final String customChallengeId;

  const CustomChallengeDetailsPage({
    super.key,
    required this.customChallengeId,
  });

  @override
  State<CustomChallengeDetailsPage>
  createState() =>
      _CustomChallengeDetailsPageState();
}

class _CustomChallengeDetailsPageState
    extends State<
        CustomChallengeDetailsPage> {
  Map<String, dynamic>? challenge;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadChallenge();
  }

  /// ===== LOAD DATA =====
  Future<void> loadChallenge() async {
    final supabase =
        Supabase.instance.client;

    final response = await supabase
        .from('CustomChallenge')
        .select(
        'title, rules, duration, rewardedCoins')
        .eq('customChallengeId',
        widget.customChallengeId)
        .single();

    setState(() {
      challenge = response;
      isLoading = false;
    });
  }

  Future<String> generateParticipantId() async {
    final supabase = Supabase.instance.client;

    final data = await supabase
        .from('ChallengeParticipant')
        .select('challengeParticipantId')
        .order('challengeParticipantId',
        ascending: false)
        .limit(1);

    if (data.isEmpty) {
      return "CP0001";
    }

    final lastId =
    data.first['challengeParticipantId'];

    final number =
        int.parse(lastId.substring(2)) + 1;

    return "CP${number.toString().padLeft(4, '0')}";
  }

  Future<void> joinChallenge() async {
    final supabase = Supabase.instance.client;

    /// 1️⃣ Retrieve challenge info
    final challengeData = await supabase
        .from('CustomChallenge')
        .select('duration')
        .eq('customChallengeId',
        widget.customChallengeId)
        .single();

    final duration =
    challengeData['duration'];

    /// 2️⃣ Generate participant ID
    final participantId =
    await generateParticipantId();

    /// 3️⃣ Dates
    final startDate = DateTime.now();
    final endDate =
    startDate.add(Duration(days: duration));

    /// 4️⃣ Insert participant
    await supabase
        .from('ChallengeParticipant')
        .insert({
      "challengeParticipantId":
      participantId,
      "progressValue": 0,
      "coinEarned": 0,
      "isWinner": false,
      "startDate":
      startDate.toIso8601String(),
      "endDate":
      endDate.toIso8601String(),
      "joinedAt":
      DateTime.now().toIso8601String(),
      "isComplete": false,
      "userId": null,
      "customChallengeId":
      widget.customChallengeId,
    });

    /// 5️⃣ SUCCESS DIALOG
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius:
          BorderRadius.circular(20),
        ),
        contentPadding:
        const EdgeInsets.all(24),
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
                fontWeight:
                FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "You’ve joined this challenge.\nStart tracking your progress now!",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            /// OK BUTTON
            SizedBox(
              width: 120,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // close dialog
                  Navigator.pop(
                      context); // back to list page
                },
                style: ElevatedButton
                    .styleFrom(
                  backgroundColor:
                  const Color(
                      0xFF9ED39E),
                  shape:
                  RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius
                        .circular(30),
                  ),
                ),
                child: const Text(
                  "OK",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }



  /// 🔢 Format rules
  List<String> formatRules(
      String rulesText) {
    return rulesText
        .split('.')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
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

    final formattedRules =
    formatRules(
        challenge!['rules'] ?? '');

    return Scaffold(
      backgroundColor:
      const Color(0xFFFEFFD3),

      body: SafeArea(
        child: SingleChildScrollView(
          padding:
          const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              /// Back
              IconButton(
                icon:
                const Icon(Icons.arrow_back),
                onPressed: () =>
                    Navigator.pop(context),
              ),

              const SizedBox(height: 10),

              /// Header
              Row(
                mainAxisAlignment:
                MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/createChallenge.png',
                    width: 60,
                    height: 60,
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Custom Challenge',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              /// Card
              Container(
                padding:
                const EdgeInsets.all(20),
                decoration:
                BoxDecoration(
                  color: Colors.white
                      .withValues(alpha: 0.4),
                  borderRadius:
                  BorderRadius.circular(
                      20),
                ),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
                  children: [
                    /// Title
                    Text(
                      challenge![
                      'title'],
                      style:
                      const TextStyle(
                        fontSize: 15,
                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),

                    const SizedBox(
                        height: 16),

                    /// Duration
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule,
                          size: 20,
                          color: Color(
                              0xFF4CAF50),
                        ),
                        const SizedBox(
                            width: 6),
                        Text(
                          "Duration: ${challenge!['duration']} Days",
                          style:
                          const TextStyle(
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                        height: 8),

                    /// Coins
                    Row(
                      children: [
                        const Icon(
                          Icons
                              .monetization_on_outlined,
                          size: 20,
                          color: Color(
                              0xFF4CAF50),
                        ),
                        const SizedBox(
                            width: 6),
                        Text(
                          "Reward: ${challenge!['rewardedCoins']} Coins",
                          style:
                          const TextStyle(
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                        height: 20),

                    /// Rules
                    ListView.builder(
                      shrinkWrap: true,
                      physics:
                      const NeverScrollableScrollPhysics(),
                      itemCount:
                      formattedRules
                          .length,
                      itemBuilder:
                          (context, index) {
                        return Padding(
                          padding:
                          const EdgeInsets
                              .only(
                              bottom:
                              16),
                          child: Row(
                            children: [
                              Container(
                                width: 30,
                                height: 30,
                                alignment:
                                Alignment.center,
                                decoration:
                                const BoxDecoration(
                                  color: Color(0xFF4CAF50),
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  "${index + 1}",
                                  style:
                                  const TextStyle(
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(
                                  width: 10),
                              Expanded(
                                child: Text(
                                    formattedRules[index]),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  /// ===== JOIN BUTTON =====
                  SizedBox(
                    width: 130,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: joinChallenge,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                        const Color(0xFF9ED39E),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(30),
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


                  const SizedBox(width: 16),

                  /// ===== INVITE FRIENDS BUTTON =====
                  SizedBox(
                    width: 170,
                    height: 55,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        /// Invite logic later
                      },
                      label: const Text(
                        "Invite Friends",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                        const Color(0xFF9ED39E), // same green
                        shape: RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(30),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

            ],
          ),
        ),
      ),
    );
  }
}
