import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/reward_model.dart';
import 'supabase_service.dart';

class RewardsService {
  final SupabaseClient _client = SupabaseService.client;

  Future<List<RewardModel>> fetchRewards() async {
    final rows = await _client.from('rewards').select().order('points_cost');
    return (rows as List<dynamic>).map((e) => RewardModel.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<void> redeem(RewardModel reward) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Connecte-toi pour échanger des points.');
    }
    await _client.from('reward_redemptions').insert({
      'reward_id': reward.id,
      'user_id': userId,
    });
  }
}
