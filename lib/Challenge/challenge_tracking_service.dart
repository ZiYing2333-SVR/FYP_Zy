import 'package:supabase_flutter/supabase_flutter.dart';

class ChallengeTrackingService {
  final supabase = Supabase.instance.client;

  Future<List<String>> getUserLedgerIds(String userId) async {
    final response = await supabase
        .from('Ledger')
        .select('ledgerId')
        .eq('userId', userId);

    return response
        .map<String>((row) => row['ledgerId'].toString())
        .toList();
  }

  Future<void> updateUserChallenges(String userId) async {
    try {
      final ledgerIds = await getUserLedgerIds(userId);
      print('ledgerIds: $ledgerIds');

      if (ledgerIds.isEmpty) {
        print('No ledgers found');
        return;
      }

      final joinedChallenges = await supabase
          .from('ChallengeParticipant')
          .select('''
          challengeParticipantId,
          challengeId,
          userId,
          progressValue,
          startDate,
          endDate,
          isComplete,
          coinEarned,
          isWinner,
          hasClaimedReward,
          Challenge (
            achievementId
          )
        ''')
          .eq('userId', userId)
          .not('challengeId', 'is', null)
          .eq('isComplete', false);

      print('joinedChallenges: $joinedChallenges');

      for (final participant in joinedChallenges) {
        final challengeId = participant['challengeId'];
        print('Updating challenge: $challengeId');

        switch (challengeId) {
          case 'PC0001':
            await trackExpenseStreak(participant, userId, ledgerIds);
            break;
          case 'PC0002':
            await trackWeeklyBudget(participant, userId, ledgerIds);
            break;
          case 'PC0003':
            await trackNoImpulseSpending(participant, userId, ledgerIds);
            break;
          case 'PC0004':
            await trackSavingGoal(participant, userId, ledgerIds);
            break;
        }
      }
    } catch (e) {
      print('Error updating challenges: $e');
    }
  }

  Future<void> trackExpenseStreak(
      Map<String, dynamic> participant,
      String userId,
      List<String> ledgerIds,
      ) async {
    final participantId = participant['challengeParticipantId'];
    final startDate = DateTime.parse(participant['startDate']);
    final endDate = DateTime.parse(participant['endDate']);
    final today = DateTime.now();
    final hasClaimed = participant['hasClaimedReward'] ?? false;
    final achievementId = participant['Challenge']?['achievementId'];

    int currentStreak = 0;
    int longestStreak = 0;

    final duration = DateTime.parse(participant['endDate'])
        .difference(DateTime.parse(participant['startDate']))
        .inDays + 1;

    for (int i = 0; i < duration; i++) {
      final day = startDate.add(Duration(days: i));

      final onlyDay = DateTime(day.year, day.month, day.day);
      final onlyToday = DateTime(today.year, today.month, today.day);
      final onlyEndDate = DateTime(endDate.year, endDate.month, endDate.day);

      if (onlyDay.isAfter(onlyToday) || onlyDay.isAfter(onlyEndDate)) {
        print('stop loop at day: $onlyDay');
        break;
      }

      final dayStart = DateTime(onlyDay.year, onlyDay.month, onlyDay.day);
      final dayEnd = dayStart.add(const Duration(days: 1));

      final transactions = await supabase
          .from('Transaction')
          .select('transactionId')
          .eq('type', 'expense')
          .inFilter('ledgerId', ledgerIds)
          .gte('date', dayStart.toIso8601String())
          .lt('date', dayEnd.toIso8601String());

      if (transactions.isNotEmpty) {
        currentStreak++;

        if (currentStreak > longestStreak) {
          longestStreak = currentStreak;
        }
      } else {
        currentStreak = 0; // 🔥 reset but continue
      }
    }

    final target = 5; // or change to 5 if you want easier win

    final isWinner = longestStreak >= target;
    final isComplete = !today.isBefore(endDate);

    print('longest streak: $longestStreak');

    await supabase
        .from('ChallengeParticipant')
        .update({
      'progressValue': longestStreak,
      'isWinner': isWinner,
      'isComplete': isComplete,
      'coinEarned': isWinner ? 50 : 0,
    })
        .eq('challengeParticipantId', participantId);

    final checkUpdated = await supabase
        .from('ChallengeParticipant')
        .select('challengeParticipantId, progressValue, isWinner, isComplete, coinEarned')
        .eq('challengeParticipantId', participantId)
        .single();

    print('updated participant: $checkUpdated');

    if (isWinner && !hasClaimed) {
      await rewardUserCoins(userId, 50);

      await awardAchievement(
        userId,
        achievementId,
      );

      await supabase
          .from('ChallengeParticipant')
          .update({
        'hasClaimedReward': true,
      })
          .eq('challengeParticipantId', participantId);
    }
  }

  Future<void> trackWeeklyBudget(
      Map<String, dynamic> participant,
      String userId,
      List<String> ledgerIds,
      ) async {
    final participantId = participant['challengeParticipantId'];
    final startDate = DateTime.parse(participant['startDate']);
    final endDate = DateTime.parse(participant['endDate']);
    final now = DateTime.now();
    final hasClaimed = participant['hasClaimedReward'] ?? false;
    final achievementId = participant['Challenge']?['achievementId'];

    final budgets = await supabase
        .from('Budget')
        .select('amount, createdAt, categoryId')
        .eq('userId', userId)
        .order('createdAt', ascending: false)
        .limit(1);

    print("Budgets result: $budgets");
    print("Length: ${budgets.length}");

    double budgetAmount =
    (budgets.isNotEmpty ? budgets.first['amount'] : 0).toDouble();

    final budgetCategoryId =
    budgets.isNotEmpty ? budgets.first['categoryId'] : null;

    if (budgetCategoryId == null) {
      print("No category set for budget");
      return;
    }

    final transactions = await supabase
        .from('Transaction')
        .select('amount')
        .eq('type', 'expense')
        .eq('refund', false)
        .inFilter('ledgerId', ledgerIds)
        .eq('categoryId', budgetCategoryId)
        .gte('date', startDate.toIso8601String())
        .lte('date', endDate.toIso8601String());

    double totalExpense = 0;
    for (final t in transactions) {
      totalExpense += (t['amount'] as num).toDouble();
    }

    // Early lose condition: budget exceeded
    if (totalExpense > budgetAmount) {
      await supabase
          .from('ChallengeParticipant')
          .update({
        'progressValue': totalExpense,
        'isWinner': false,
        'isComplete': true,
        'coinEarned': 0,
      })
          .eq('challengeParticipantId', participantId);

      print("Challenge ended early: Budget exceeded");

      return; // stop further execution
    }

    bool isComplete = false;
    bool isWinner = false;

    if (!now.isBefore(endDate)) {
      isComplete = true;
      isWinner = totalExpense <= budgetAmount;
    }

    await supabase
        .from('ChallengeParticipant')
        .update({
      'progressValue': totalExpense,
      'isWinner': isWinner,
      'isComplete': isComplete,
      'coinEarned': isWinner ? 60 : 0,
    })
        .eq('challengeParticipantId', participantId);

    if (isWinner && !hasClaimed) {
      await rewardUserCoins(userId, 60);
      await awardAchievement(userId, achievementId);

      await supabase
          .from('ChallengeParticipant')
          .update({
        'hasClaimedReward': true,
      })
          .eq('challengeParticipantId', participantId);
    }



  }

  Future<void> trackNoImpulseSpending(
      Map<String, dynamic> participant,
      String userId,
      List<String> ledgerIds,
      ) async {
    final participantId = participant['challengeParticipantId'];
    final startDate = DateTime.parse(participant['startDate']);
    final endDate = DateTime.parse(participant['endDate']);
    final now = DateTime.now();
    final hasClaimed = participant['hasClaimedReward'] ?? false;
    final achievementId = participant['Challenge']?['achievementId'];

    final impulseCategories = [
      'entertainment',
      'restaurant',
      'snack',
      'food delivery',
      'take away',
      'hobby',
      'movie',
      'cosmetic',
      'shopping',
    ];

    int safeDays = 0;
    bool failed = false;

    final duration = endDate.difference(startDate).inDays + 1;

    for (int i = 0; i < duration; i++) {
      final day = startDate.add(Duration(days: i));
      final onlyDay = DateTime(day.year, day.month, day.day);
      final onlyToday = DateTime(now.year, now.month, now.day);
      final onlyEndDate = DateTime(endDate.year, endDate.month, endDate.day);

      if (onlyDay.isAfter(onlyToday) || onlyDay.isAfter(onlyEndDate)) {
        break;
      }

      final dayStart = DateTime(onlyDay.year, onlyDay.month, onlyDay.day);
      final dayEnd = dayStart.add(const Duration(days: 1));

      final transactions = await supabase
          .from('Transaction')
          .select('''
          date,
          Category(name)
        ''')
          .eq('type', 'expense')
          .eq('refund', false)
          .inFilter('ledgerId', ledgerIds)
          .gte('date', dayStart.toIso8601String())
          .lt('date', dayEnd.toIso8601String());

      bool hasImpulse = false;

      for (final t in transactions) {
        final categoryName =
        (t['Category']?['name']?.toString() ?? '').trim().toLowerCase();

        if (impulseCategories.contains(categoryName)) {
          hasImpulse = true;
          break;
        }
      }

      if (hasImpulse) {
        failed = true;
        break;
      } else {
        safeDays++;
      }
    }

    bool isComplete = false;
    bool isWinner = false;
    final target = duration;

    if (failed) {
      isComplete = true;
      isWinner = false;
    } else if (safeDays >= target) {
      isComplete = true;
      isWinner = true;
    }

    await supabase
        .from('ChallengeParticipant')
        .update({
      'progressValue': safeDays,
      'isWinner': isWinner,
      'isComplete': isComplete,
      'coinEarned': isWinner ? 40 : 0,
    })
        .eq('challengeParticipantId', participantId);

    if (isWinner && !hasClaimed) {
      await rewardUserCoins(userId, 40);
      await awardAchievement(userId, achievementId);

      await supabase
          .from('ChallengeParticipant')
          .update({
        'hasClaimedReward': true,
      })
          .eq('challengeParticipantId', participantId);
    }


  }

  Future<void> trackSavingGoal(
      Map<String, dynamic> participant,
      String userId,
      List<String> ledgerIds,
      ) async {
    final participantId = participant['challengeParticipantId'];
    final startDate = DateTime.parse(participant['startDate']);
    final endDate = DateTime.parse(participant['endDate']);
    final now = DateTime.now();
    final hasClaimed = participant['hasClaimedReward'] ?? false;
    final achievementId = participant['Challenge']?['achievementId'];

    final incomeTransactions = await supabase
        .from('Transaction')
        .select('amount')
        .eq('type', 'income')
        .eq('refund', false)
        .inFilter('ledgerId', ledgerIds)
        .gte('date', startDate.toIso8601String())
        .lte('date', endDate.toIso8601String());

    final expenseTransactions = await supabase
        .from('Transaction')
        .select('amount')
        .eq('type', 'expense')
        .eq('refund', false)
        .inFilter('ledgerId', ledgerIds)
        .gte('date', startDate.toIso8601String())
        .lte('date', endDate.toIso8601String());

    double income = 0;
    double expense = 0;

    for (final t in incomeTransactions) {
      income += (t['amount'] as num).toDouble();
    }

    for (final t in expenseTransactions) {
      expense += (t['amount'] as num).toDouble();
    }

    final savedAmount = income - expense;

    bool isComplete = false;
    bool isWinner = false;

    if (now.isAfter(endDate) || now.isAtSameMomentAs(endDate)) {
      isComplete = true;
      isWinner = savedAmount >= 50;
    }

    await supabase
        .from('ChallengeParticipant')
        .update({
      'progressValue': savedAmount,
      'isWinner': isWinner,
      'isComplete': isComplete,
      'coinEarned': isWinner ? 50 : 0,
    })
        .eq('challengeParticipantId', participantId);

    if (isWinner && !hasClaimed) {
      await rewardUserCoins(userId, 50);
      await awardAchievement(userId, achievementId);

      await supabase
          .from('ChallengeParticipant')
          .update({
        'hasClaimedReward': true,
      })
          .eq('challengeParticipantId', participantId);
    }


  }

  Future<void> rewardUserCoins(String userId, int coins) async {
    final userData = await supabase
        .from('User')
        .select('coinbalance')
        .eq('userId', userId)
        .single();

    final currentCoins = userData['coinbalance'] ?? 0;

    await supabase
        .from('User')
        .update({'coinbalance': currentCoins + coins})
        .eq('userId', userId);
  }

  Future<void> awardAchievement(String userId, String? achievementId) async {
    if (achievementId == null) return;


    /// 2️⃣ Generate ID
    final last = await supabase
        .from('UserAchievement')
        .select('userAchievementId')
        .order('userAchievementId', ascending: false)
        .limit(1);

    String newId;

    if (last.isEmpty) {
      newId = "UA00001";
    } else {
      String lastId = last.first['userAchievementId'];
      int num = int.parse(lastId.substring(2));
      num++;
      newId = "UA${num.toString().padLeft(5, '0')}";
    }

    /// 3️⃣ Insert
    await supabase.from('UserAchievement').insert({
      'userAchievementId': newId,
      'awardedAt': DateTime.now().toIso8601String(),
      'userId': userId,
      'achievementId': achievementId,
    });

    print("🏆 Achievement awarded: $achievementId");
  }
}