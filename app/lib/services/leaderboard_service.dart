import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_model.dart';
import 'supabase_service.dart';

class LeaderboardService {
  final SupabaseClient _client = SupabaseService.client;

  Future<List<UserModel>> fetchTopUsers({int limit = 50}) async {
    final rows = await _client
        .from('users')
        .select()
        .order('total_points', ascending: false)
        .limit(limit);
    return (rows as List<dynamic>).map((e) => UserModel.fromMap(e as Map<String, dynamic>)).toList();
  }
}
