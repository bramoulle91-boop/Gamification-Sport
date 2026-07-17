import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/gym_model.dart';
import 'supabase_service.dart';

class GymService {
  final SupabaseClient _client = SupabaseService.client;

  Future<List<GymModel>> fetchAllGyms() async {
    final rows = await _client.from('gyms').select();
    return (rows as List<dynamic>).map((e) => GymModel.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<GymModel?> fetchGymById(String gymId) async {
    final row = await _client.from('gyms').select().eq('id', gymId).maybeSingle();
    if (row == null) return null;
    return GymModel.fromMap(row);
  }

  Future<void> setHomeGym(String gymId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Connecte-toi pour choisir ta salle.');
    }
    await _client.from('users').update({'home_gym_id': gymId}).eq('id', userId);
  }
}
