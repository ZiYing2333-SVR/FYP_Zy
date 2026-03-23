import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MissionPage extends StatefulWidget {
  final String userId;
  const MissionPage({
    super.key,
    required this.userId,
  });

  @override
  State<MissionPage> createState() => _MissionPageState();
}

class _MissionPageState extends State<MissionPage> {

  final supabase = Supabase.instance.client;

  int coinBalance = 0;

  int currentStreak = 0;

  List<Map<String, dynamic>> missions = [];

  String todayDate =
  DateFormat('dd - MM - yyyy').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    fetchUserCoinBalance();
    assignDailyMissions();
    fetchCurrentStreak();
  }

  Future<void> fetchUserCoinBalance() async {
    try {
      final data = await supabase
          .from('User')
          .select('coinbalance')
          .eq('userId', widget.userId)
          .single();

      setState(() {
        coinBalance = data['coinbalance'] ?? 0;
      });
    } catch (e) {
      debugPrint('Error fetching coin balance: $e');
    }
  }

  // =========================================================
  // 🎲 ASSIGN RANDOM MISSIONS INTO MissionProgress
  // =========================================================
  Future<void> assignDailyMissions() async {
    final today = DateTime.now().toIso8601String().substring(0, 10);

    try {
      /// Check whether this user already has missions assigned today
      final existing = await supabase
          .from('MissionProgress')
          .select()
          .eq('assignDate', today)
          .eq('userId', widget.userId);

      if (existing.isNotEmpty) {
        await fetchAssignedMissions();
        return;
      }

      /// Get fixed daily mission M001
      final dailyMission = await supabase
          .from('Mission')
          .select()
          .eq('missionId', 'M001')
          .single();

      /// Get all other missions except M001
      final otherMissionData = await supabase
          .from('Mission')
          .select()
          .neq('missionId', 'M001');

      /// Shuffle and take 2 random missions
      final otherMissions =
      List<Map<String, dynamic>>.from(otherMissionData)..shuffle();

      final selectedOtherMissions = otherMissions.take(2).toList();

      /// Insert M001 first
      /// Since user opened the mission page, count as daily check-in
      await supabase.from('MissionProgress').insert({
        'assignDate': today,
        'isComplete': true,
        'isClaim': false,
        'missionId': dailyMission['missionId'],
        'userId': widget.userId,
      });

      /// Insert 2 random missions as incomplete
      for (var m in selectedOtherMissions) {
        await supabase.from('MissionProgress').insert({
          'assignDate': today,
          'isComplete': false,
          'isClaim': false,
          'missionId': m['missionId'],
          'userId': widget.userId,
        });
      }

      await fetchAssignedMissions();
    } catch (e) {
      debugPrint('Error assigning daily missions: $e');
    }
  }

  // =========================================================
  // 🔗 FETCH JOINED DATA
  // =========================================================
  Future<void> fetchAssignedMissions() async {
    final today = DateTime.now().toIso8601String().substring(0, 10);

    try {
      final data = await supabase
          .from('MissionProgress')
          .select('''
          progressId,
          isComplete,
          isClaim,
          assignDate,
          userId,
          Mission (
            missionId,
            title,
            iconName,
            rewardCoins
          )
        ''')
          .eq('assignDate', today)
          .eq('userId', widget.userId);

      List<Map<String, dynamic>> missionList =
      List<Map<String, dynamic>>.from(data);

      /// Make sure M001 appears first
      missionList.sort((a, b) {
        final idA = a['Mission']?['missionId'] ?? '';
        final idB = b['Mission']?['missionId'] ?? '';

        if (idA == 'M001' && idB != 'M001') return -1;
        if (idA != 'M001' && idB == 'M001') return 1;
        return 0;
      });

      setState(() {
        missions = missionList;
      });

      await fetchCurrentStreak();

      debugPrint("MISSION TODAY: $missionList");
    } catch (e) {
      debugPrint('Error fetching assigned missions: $e');
    }
  }

  Future<void> fetchCurrentStreak() async {
    try {
      final data = await supabase
          .from('MissionProgress')
          .select('assignDate, isComplete, isClaim')
          .eq('userId', widget.userId)
          .order('assignDate', ascending: false);

      final progressList = List<Map<String, dynamic>>.from(data);

      Map<String, List<Map<String, dynamic>>> groupedByDate = {};

      for (var row in progressList) {
        final rawDate = row['assignDate'];

        /// normalize to yyyy-MM-dd string
        final date = rawDate.toString().substring(0, 10);

        groupedByDate.putIfAbsent(date, () => []);
        groupedByDate[date]!.add(row);
      }

      debugPrint("Grouped By Date: $groupedByDate");

      int streak = 0;
      DateTime checkDate = DateTime.now();

      while (true) {
        final dateStr =
            "${checkDate.year.toString().padLeft(4, '0')}-"
            "${checkDate.month.toString().padLeft(2, '0')}-"
            "${checkDate.day.toString().padLeft(2, '0')}";

        final dayMissions = groupedByDate[dateStr];

        debugPrint("Checking date: $dateStr");
        debugPrint("Day missions: $dayMissions");

        if (dayMissions == null || dayMissions.length < 3) {
          break;
        }

        final allCompleted =
        dayMissions.every((mission) => mission['isComplete'] == true);

        if (!allCompleted) {
          break;
        }

        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      }

      debugPrint("Final streak = $streak");

      if (!mounted) return;

      setState(() {
        currentStreak = streak;
      });
    } catch (e) {
      debugPrint('Error fetching streak: $e');
    }
  }

  Future<void> completeMission(String missionId) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);

    try {
      await supabase
          .from('MissionProgress')
          .update({'isComplete': true})
          .eq('userId', widget.userId)
          .eq('assignDate', today)
          .eq('missionId', missionId);

      await fetchAssignedMissions();
    } catch (e) {
      debugPrint('Error completing mission $missionId: $e');
    }
  }


  // =========================================================
  // 🪙 CLAIM REWARD
  // =========================================================
  Future<void> claimReward(Map missionProgress) async {
    try {
      final progressId = missionProgress['progressId'];
      final reward = missionProgress['Mission']['rewardCoins'] as int;

      /// 1. Mark mission as claimed
      await supabase
          .from('MissionProgress')
          .update({'isClaim': true})
          .eq('progressId', progressId)
          .eq('userId', widget.userId);

      /// 2. Calculate new coin balance
      final newBalance = coinBalance + reward;

      /// 3. Update User table
      await supabase
          .from('User')
          .update({'coinbalance': newBalance})
          .eq('userId', widget.userId);

      /// 4. Update local UI
      setState(() {
        coinBalance = newBalance;
      });

      await fetchAssignedMissions();
    } catch (e) {
      debugPrint('Error claiming reward: $e');
    }
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
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (index) {
        bool isActive = index < currentStreak;

        return Container(
          width: 42,
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFFA7E399)
                : Colors.green.shade100,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Text(
                "Day",
                style: TextStyle(
                  fontSize: 10,
                  color: isActive ? Colors.white : Colors.green,
                ),
              ),
              Text(
                "${index + 1}",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isActive ? Colors.white : Colors.green,
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
