import 'package:flutter/material.dart';
import 'package:fyp_wx/Challenge/presetChallenge_detail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'View_Challenge.dart';
import 'presetChallenge_detail.dart';

class PresetChallengePage extends StatefulWidget {
  const PresetChallengePage({super.key});

  @override
  State<PresetChallengePage> createState() =>
      _PresetChallengePageState();
}

class _PresetChallengePageState
    extends State<PresetChallengePage> {
  List<dynamic> challenges = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChallenges();
  }

  Future<void> _loadChallenges() async {
    try {
      final supabase = Supabase.instance.client;

      final response = await supabase
          .from('Challenge')
          .select(
          'challengeId, title, duration, rules, rewardedCoins')
          .order('challengeId');

      setState(() {
        challenges = response;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error loading challenges: $e');
      setState(() => isLoading = false);
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
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            /// 🏷 Title
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

            /// 📂 Challenge list
            Expanded(
              child: isLoading
                  ? const Center(
                  child:
                  CircularProgressIndicator())
                  : ListView.builder(
                itemCount: challenges.length,
                itemBuilder: (context, index) {
                  final challenge =
                  challenges[index];

                  return _buildChallengeButton(
                    title: challenge['title'],
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ChallengeDetailsPage(
                                challengeId: challenge['challengeId'],
                                title: challenge[
                                'title'],
                                rules: challenge[
                                'rules'],
                                duration:
                                challenge[
                                'duration'],
                                coins: challenge[
                                'rewardedCoins'],
                              ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 📦 Challenge Container
  Widget _buildChallengeButton({
    required String title,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: 18,
            horizontal: 20,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF555555),
                  ),
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
