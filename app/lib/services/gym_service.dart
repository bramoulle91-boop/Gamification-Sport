import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/gym_model.dart';
import '../models/machine_model.dart';
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

  Future<List<MachineModel>> fetchMachinesForGym(String gymId) async {
    final rows = await _client.from('machines').select().eq('gym_id', gymId);
    return (rows as List<dynamic>).map((e) => MachineModel.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<void> setHomeGym(String gymId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Connecte-toi pour choisir ta salle.');
    }
    await _client.from('users').update({'home_gym_id': gymId}).eq('id', userId);
  }

  /// Ajoute une nouvelle salle sur la carte à l'endroit tapé par
  /// l'utilisateur — n'importe qui de connecté peut enrichir la carte.
  Future<GymModel> createGym({
    required String name,
    required double latitude,
    required double longitude,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Connecte-toi pour ajouter une salle.');
    }
    final row = await _client
        .from('gyms')
        .insert({
          'name': name,
          // Format texte natif du type `point` de Postgres : "(x,y)".
          'gps_coordinates': '($latitude,$longitude)',
          'geofencing_radius_m': 200,
          'created_by': userId,
        })
        .select()
        .single();
    return GymModel.fromMap(row);
  }
}
