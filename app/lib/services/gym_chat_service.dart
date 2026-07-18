import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/gym_message_model.dart';
import 'supabase_service.dart';

class GymChatService {
  final SupabaseClient _client = SupabaseService.client;

  /// Flux en direct des messages d'une salle (Supabase Realtime) — se met à
  /// jour automatiquement dès qu'un message est envoyé, sans recharger.
  Stream<List<GymMessageModel>> streamMessages(String gymId) {
    return _client
        .from('gym_messages')
        .stream(primaryKey: ['id'])
        .eq('gym_id', gymId)
        .order('created_at', ascending: true)
        .map((rows) => rows.map((e) => GymMessageModel.fromMap(e)).toList());
  }

  Future<void> sendMessage({
    required String gymId,
    required String pseudo,
    required String message,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Connecte-toi pour discuter.');
    }
    final trimmed = message.trim();
    if (trimmed.isEmpty) return;
    await _client.from('gym_messages').insert({
      'gym_id': gymId,
      'user_id': userId,
      'pseudo': pseudo,
      'message': trimmed,
    });
  }
}
