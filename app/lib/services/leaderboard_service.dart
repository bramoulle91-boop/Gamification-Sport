import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_model.dart';
import 'supabase_service.dart';

class LeaderboardService {
  final SupabaseClient _client = SupabaseService.client;

  Future<List<UserModel>> fetchTopUsers({int limit = 50, String? gymId}) async {
    var query = _client.from('users').select();
    if (gymId != null) {
      query = query.eq('home_gym_id', gymId);
    }
    final rows = await query.order('total_points', ascending: false).limit(limit);
    return (rows as List<dynamic>).map((e) => UserModel.fromMap(e as Map<String, dynamic>)).toList();
  }
}
