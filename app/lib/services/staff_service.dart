import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/gym_model.dart';
import 'supabase_service.dart';

class StaffService {
  final SupabaseClient _client = SupabaseService.client;

  /// Salles où l'utilisateur courant a un compte "Staff" (gérant / coach).
  Future<List<GymModel>> fetchMyStaffGyms() async {
    final userId = _client.auth.currentUser!.id;
    final rows = await _client.from('gym_staff').select('gyms(*)').eq('user_id', userId);
    return (rows as List<dynamic>)
        .map((e) => GymModel.fromMap((e as Map<String, dynamic>)['gyms'] as Map<String, dynamic>))
        .toList();
  }
}
