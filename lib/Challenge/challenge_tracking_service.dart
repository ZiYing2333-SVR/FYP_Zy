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
          isWinner
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
    final alreadyRewarded = (participant['coinEarned'] ?? 0) > 0;

    int streak = 0;

    for (int i = 0; i < 7; i++) {
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
          .select('transactionId, date, ledgerId, type, refund')
          .eq('type', 'expense')
          .inFilter('ledgerId', ledgerIds)
          .gte('date', dayStart.toIso8601String())
          .lt('date', dayEnd.toIso8601String());

      if (transactions.isNotEmpty) {
        streak++;
      } else {
        break;
      }
    }

    final isWinner = streak >= 7;
    final isComplete = isWinner;

    print('final streak: $streak');

    await supabase
        .from('ChallengeParticipant')
        .update({
      'progressValue': streak,
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

    if (isWinner && !alreadyRewarded) {
      await rewardUserCoins(userId, 50);
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
    final alreadyRewarded = (participant['coinEarned'] ?? 0) > 0;

    final budgetData = await supabase
        .from('Budget')
        .select('amount')
        .eq('userId', userId)
        .order('createdAt', ascending: false)
        .limit(1)
        .maybeSingle();

    if (budgetData == null) return;

    final budgetAmount = (budgetData['amount'] as num).toDouble();

    final transactions = await supabase
        .from('Transaction')
        .select('amount')
        .eq('type', 'expense')
        .eq('refund', false)
        .inFilter('ledgerId', ledgerIds)
        .gte('date', startDate.toIso8601String())
        .lte('date', endDate.toIso8601String());

    double totalExpense = 0;
    for (final t in transactions) {
      totalExpense += (t['amount'] as num).toDouble();
    }

    bool isComplete = false;
    bool isWinner = false;

    if (now.isAfter(endDate) || now.isAtSameMomentAs(endDate)) {
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

    if (isComplete && isWinner && !alreadyRewarded) {
      await rewardUserCoins(userId, 60);
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
    final alreadyRewarded = (participant['coinEarned'] ?? 0) > 0;

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

    for (int i = 0; i < 3; i++) {
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

    if (failed) {
      isComplete = true;
      isWinner = false;
    } else if (safeDays >= 3) {
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

    if (isComplete && isWinner && !alreadyRewarded) {
      await rewardUserCoins(userId, 40);
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
    final alreadyRewarded = (participant['coinEarned'] ?? 0) > 0;

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

    if (isComplete && isWinner && !alreadyRewarded) {
      await rewardUserCoins(userId, 50);
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
}