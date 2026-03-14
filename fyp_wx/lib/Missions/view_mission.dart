import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MissionPage extends StatefulWidget {
  const MissionPage({super.key});

  @override
  State<MissionPage> createState() => _MissionPageState();
}

class _MissionPageState extends State<MissionPage> {

  final supabase = Supabase.instance.client;

  int coinBalance = 26;

  List<Map<String, dynamic>> missions = [];

  String todayDate =
  DateFormat('dd - MM - yyyy').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    assignDailyMissions();
  }

  // =========================================================
  // 🎲 ASSIGN RANDOM MISSIONS INTO MissionProgress
  // =========================================================
  Future<void> assignDailyMissions() async {

    final today =
    DateTime.now().toIso8601String().substring(0, 10);

    /// Check already assigned today
    final existing = await supabase
        .from('MissionProgress')
        .select()
        .eq('assignDate', today);

    if (existing.isNotEmpty) {
      fetchAssignedMissions();
      return;
    }

    /// Random pick 3 missions
    final randomMissions = await supabase
        .from('Mission')
        .select()
        .limit(3);

    /// Insert into MissionProgress
    for (var m in randomMissions) {
      await supabase.from('MissionProgress').insert({
        'assignDate': today,
        'isComplete': false,
        'isClaim': false,
        'missionId': m['missionId'],
        'userId': null, // temp user ----------------------need to change
      });
    }

    fetchAssignedMissions();
  }

  // =========================================================
  // 🔗 FETCH JOINED DATA
  // =========================================================
  Future<void> fetchAssignedMissions() async {

    final today =
    DateTime.now().toIso8601String().substring(0, 10);

    final data = await supabase
        .from('MissionProgress')
        .select('''
        progressId,
        isComplete,
        isClaim,
        assignDate,
        Mission (
          missionId,
          title,
          iconName,
          rewardCoins
        )
      ''')
        .eq('assignDate', today);   // ✅ FILTER TODAY ONLY

    debugPrint("MISSION TODAY: $data");

    setState(() {
      missions =
      List<Map<String, dynamic>>.from(data);
    });
  }


  // =========================================================
  // 🪙 CLAIM REWARD
  // =========================================================
  Future<void> claimReward(
      Map missionProgress) async {

    final progressId =
    missionProgress['progressId'];

    final reward =
    missionProgress['Mission']['rewardCoins'] as int;


    /// Update claim status
    await supabase
        .from('MissionProgress')
        .update({'isClaim': true})
        .eq('progressId', progressId);

    /// Update coins locally
    setState(() {
      coinBalance += reward;
    });

    fetchAssignedMissions();
  }

  // =========================================================
  // 🧱 UI
  // =========================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEFFD3),

      // ================= APP BAR =================
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,

        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),

        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.monetization_on,
                  color: Colors.orange,
                  size: 22,
                ),
                const SizedBox(width: 6),
                Text("$coinBalance"),
              ],
            ),
          )
        ],
      ),

      // ================= BODY =================
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            // ICON + TITLE
            Row(
              mainAxisAlignment:
              MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/mission.png',
                  width: 60,
                  height: 60,
                ),
                const SizedBox(width: 8),
                const Text(
                  "Mission",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // DATE
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.shade300,
                borderRadius:
                BorderRadius.circular(20),
              ),
              child: Text(
                todayDate,
                style: const TextStyle(
                    color: Colors.white),
              ),
            ),

            const SizedBox(height: 12),

            const Text(
              "Welcome Back!",
              style:
              TextStyle(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 16),

            _buildStreakRow(),

            const SizedBox(height: 16),

            if (missions.isEmpty)
              const CircularProgressIndicator()
            else
              ...missions.map(
                      (m) => _buildMissionCard(m)),

            const SizedBox(height: 20),

            _buildProgress(),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // 🔥 STREAK ROW (SMALL NO OVERFLOW)
  // =========================================================
  Widget _buildStreakRow() {
    return Row(
      mainAxisAlignment:
      MainAxisAlignment.spaceBetween,
      children: List.generate(7, (index) {

        bool isActive = index < 3;

        return Container(
          width: 42,
          padding:
          const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFFA7E399)
                : Colors.green.shade100,
            borderRadius:
            BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Text(
                "Day",
                style: TextStyle(
                  fontSize: 10,
                  color: isActive
                      ? Colors.white
                      : Colors.green,
                ),
              ),
              Text(
                "${index + 1}",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isActive
                      ? Colors.white
                      : Colors.green,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  // =========================================================
  // 🎯 MISSION CARD
  // =========================================================
  Widget _buildMissionCard(
      Map missionProgress) {

    final mission =
        missionProgress['Mission'] ?? {};

    bool isComplete =
        missionProgress['isComplete'] ?? false;

    bool isClaimed =
        missionProgress['isClaim'] ?? false;

    /// 🎯 PROGRESS VALUE
    double progressValue =
    isComplete ? 1.0 : 0.0;

    /// 🎯 BUTTON ENABLE STATE
    bool canClaim =
        isComplete && !isClaimed;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFA7E399),
        borderRadius: BorderRadius.circular(16),
      ),

      child: Row(
        children: [

          /// ICON
          Image.network(
            mission['iconName'] ?? '',
            width: 50,
            height: 50,
            errorBuilder: (_, __, ___) =>
            const Icon(
                Icons.image_not_supported),
          ),

          const SizedBox(width: 12),

          /// TITLE + PROGRESS
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [

                Text(
                  mission['title'] ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 6),

                /// 🌟 PROGRESS BAR STATE
                LinearProgressIndicator(
                  value: progressValue,
                  backgroundColor:
                  Colors.white24,
                  color: Colors.yellow,
                  minHeight: 6,
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          /// COINS + CLAIM
          Column(
            children: [

              Row(
                children: [
                  const Icon(
                    Icons.monetization_on,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "${mission['rewardCoins'] ?? 0}",
                    style: const TextStyle(
                        color: Colors.white),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              /// 🌟 CLAIM BUTTON STATE
              ElevatedButton(
                style:
                ElevatedButton.styleFrom(
                  backgroundColor:
                  isClaimed
                      ? Colors.grey
                      : Colors.yellow,
                  foregroundColor:
                  Colors.black,
                  shape:
                  RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius.circular(
                        20),
                  ),
                ),

                onPressed: canClaim
                    ? () => claimReward(
                    missionProgress)
                    : null,

                child: Text(
                  isClaimed
                      ? "Claimed"
                      : "Claim",
                ),
              ),
            ],
          )
        ],
      ),
    );
  }


  // =========================================================
  // 📊 PROGRESS BAR
  // =========================================================
  Widget _buildProgress() {

    int completed = missions
        .where((m) =>
    m['isComplete'] == true)
        .length;

    return Row(
      children: [

        const Text(
          "Mission Progress",
          style: TextStyle(
              fontWeight: FontWeight.bold),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: LinearProgressIndicator(
            value: missions.isEmpty
                ? 0
                : completed /
                missions.length,
            backgroundColor:
            Colors.grey.shade300,
            color: Colors.yellow,
          ),
        ),

        const SizedBox(width: 8),

        Text(
            "$completed/${missions.length}"),
      ],
    );
  }
}
