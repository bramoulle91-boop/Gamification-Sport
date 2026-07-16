import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/friendship_model.dart';
import '../models/user_model.dart';
import 'supabase_service.dart';

class FriendshipService {
  final SupabaseClient _client = SupabaseService.client;

  Future<void> sendRequest(String friendUserId) async {
    final userId = _client.auth.currentUser!.id;
    await _client.from('friendships').insert({
      'user_id_1': userId,
      'user_id_2': friendUserId,
      'status': 'PENDING',
    });
  }

  Future<void> acceptRequest({required String userId1, required String userId2}) async {
    await _client
        .from('friendships')
        .update({'status': 'DEBLOCKED'})
        .eq('user_id_1', userId1)
        .eq('user_id_2', userId2);
  }

  Future<List<FriendshipModel>> fetchMyFriendships() async {
    final userId = _client.auth.currentUser!.id;
    final rows = await _client
        .from('friendships')
        .select()
        .or('user_id_1.eq.$userId,user_id_2.eq.$userId');
    return (rows as List<dynamic>)
        .map((e) => FriendshipModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<UserModel>> searchUsersByPseudo(String query) async {
    final rows = await _client.from('users').select().ilike('pseudo', '%$query%').limit(20);
    return (rows as List<dynamic>).map((e) => UserModel.fromMap(e as Map<String, dynamic>)).toList();
  }
}
