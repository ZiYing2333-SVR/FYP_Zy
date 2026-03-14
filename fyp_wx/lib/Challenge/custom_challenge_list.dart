import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'View_Challenge.dart';
import 'create_custom_challenge.dart';
import 'custom_challenge_detail.dart';


class CustomChallengePage extends StatefulWidget {
  const CustomChallengePage({super.key});

  @override
  State<CustomChallengePage> createState() =>
      _CustomChallengePageState();
}

class _CustomChallengePageState
    extends State<CustomChallengePage> {
  List challenges = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadChallenges();
  }

  /// ===== LOAD DATA =====
  Future<void> loadChallenges() async {
    final supabase = Supabase.instance.client;

    final response = await supabase
        .from('CustomChallenge')
        .select(
        'customChallengeId, title, rules, duration, rewardedCoins')
        .order('customChallengeId');


    setState(() {
      challenges = response;
      isLoading = false;
    });
  }

  /// ===== UI =====
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
      const Color(0xFFFEFFD3),

      /// ===== APPBAR =====
      appBar: AppBar(
        backgroundColor:
        const Color(0xFFFEFFD3),
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

      /// ===== BODY =====
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
                  'assets/images/createChallenge.png',
                  width: 60,
                  height: 60,
                ),
                const SizedBox(width: 10),
                const Text(
                  'Create Challenge',
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
                  : ListView.builder(
                itemCount:
                challenges.length,
                itemBuilder:
                    (context, index) {
                  final c =
                  challenges[
                  index];

                  return InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              CustomChallengeDetailsPage(
                                customChallengeId:
                                c['customChallengeId'],
                              ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      margin:
                      const EdgeInsets.only(bottom: 14),
                      padding:
                      const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color:
                        Colors.white.withValues(alpha: 0.4),
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

      /// ===== ➕ BUTTON =====
      floatingActionButton:
      FloatingActionButton(
        backgroundColor:
        const Color(0xFF9ED39E),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
              const CreateCustomChallengePage(),
            ),
          );

          loadChallenges(); // refresh
        },
        child: const Icon(
          Icons.add,
          color: Colors.white,
        ),
      ),
    );
  }
}
