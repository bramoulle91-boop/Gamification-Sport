import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/duel_model.dart';
import 'supabase_service.dart';

class DuelService {
  final SupabaseClient _client = SupabaseService.client;

  /// Tous les défis où l'utilisateur courant est challenger ou adversaire.
  Future<List<DuelModel>> fetchMyDuels() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];
    final rows = await _client
        .from('duels')
        .select('*, challenger:challenger_id(pseudo), opponent:opponent_id(pseudo)')
        .or('challenger_id.eq.$userId,opponent_id.eq.$userId')
        .order('created_at', ascending: false);
    return (rows as List<dynamic>).map((e) => DuelModel.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<void> createDuel({
    required String opponentId,
    required String exerciseName,
    required Duration duration,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Connecte-toi pour lancer un défi.');
    }
    await _client.from('duels').insert({
      'challenger_id': userId,
      'opponent_id': opponentId,
      'exercise_name': exerciseName,
      'ends_at': DateTime.now().toUtc().add(duration).toIso8601String(),
    });
  }

  Future<void> respondToDuel({required String duelId, required bool accept}) async {
    await _client.rpc('respond_to_duel', params: {'p_duel_id': duelId, 'p_accept': accept});
  }

  /// Calcule le gagnant si la date de fin est dépassée (sans effet sinon).
  Future<void> settleIfNeeded(String duelId) async {
    await _client.rpc('settle_duel', params: {'p_duel_id': duelId});
  }

  /// Score actuel des deux participants — consultable même avant la fin.
  Future<(double challengerBest, double opponentBest)> fetchScores(String duelId) async {
    final rows = await _client.rpc('get_duel_scores', params: {'p_duel_id': duelId});
    final row = (rows as List<dynamic>).first as Map<String, dynamic>;
    return (
      (row['challenger_best'] as num).toDouble(),
      (row['opponent_best'] as num).toDouble(),
    );
  }
}
