import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MissionService {
  static final supabase = Supabase.instance.client;

  static Future<void> completeMission({
    required String userId,
    required String missionId,
  }) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);

    try {
      await supabase
          .from('MissionProgress')
          .update({'isComplete': true})
          .eq('userId', userId)
          .eq('assignDate', today)
          .eq('missionId', missionId);
    } catch (e) {
      debugPrint('Error completing mission: $e');
    }
  }
}