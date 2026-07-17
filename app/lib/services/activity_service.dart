import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/friend_activity_model.dart';
import 'supabase_service.dart';

class ActivityService {
  final SupabaseClient _client = SupabaseService.client;

  /// Les check-ins et exercices cochés récents des amis (par défaut les 3
  /// dernières heures), pour un fil d'activité type "X vient de se
  /// connecter" / "X vient de terminer Y" — en attendant les notifications
  /// push.
  Future<List<FriendActivityModel>> fetchFriendsActivity({
    required List<String> friendIds,
    Duration window = const Duration(hours: 3),
  }) async {
    if (friendIds.isEmpty) return [];
    final since = DateTime.now().toUtc().subtract(window).toIso8601String();

    final checkinRows = await _client
        .from('gym_checkins')
        .select('checked_in_at, users(pseudo), gyms(name)')
        .inFilter('user_id', friendIds)
        .gte('checked_in_at', since)
        .order('checked_in_at', ascending: false)
        .limit(15);

    final completionRows = await _client
        .from('program_exercise_completions')
        .select('completed_at, users(pseudo), gyms(name), program_exercises(exercise_name)')
        .inFilter('user_id', friendIds)
        .gte('completed_at', since)
        .order('completed_at', ascending: false)
        .limit(15);

    final activities = <FriendActivityModel>[
      for (final row in checkinRows as List<dynamic>)
        FriendActivityModel(
          type: FriendActivityType.checkin,
          pseudo: _pseudo(row as Map<String, dynamic>),
          gymName: _gymName(row),
          at: DateTime.parse(row['checked_in_at'] as String),
        ),
      for (final row in completionRows as List<dynamic>)
        FriendActivityModel(
          type: FriendActivityType.exerciseDone,
          pseudo: _pseudo(row as Map<String, dynamic>),
          gymName: _gymName(row),
          exerciseName: (row['program_exercises'] as Map<String, dynamic>?)?['exercise_name'] as String?,
          at: DateTime.parse(row['completed_at'] as String),
        ),
    ]..sort((a, b) => b.at.compareTo(a.at));

    return activities.take(10).toList();
  }

  String _pseudo(Map<String, dynamic> row) => (row['users'] as Map<String, dynamic>?)?['pseudo'] as String? ?? '?';
  String _gymName(Map<String, dynamic> row) =>
      (row['gyms'] as Map<String, dynamic>?)?['name'] as String? ?? 'une salle';
}
