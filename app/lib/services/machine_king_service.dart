import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/machine_king_model.dart';
import 'supabase_service.dart';

class MachineKingService {
  final SupabaseClient _client = SupabaseService.client;

  /// Une ligne par machine : le détenteur actuel du record (le "King"), et le
  /// record personnel de l'utilisateur courant s'il en a un — pour que
  /// chacun voie sa propre progression, pas seulement l'écart avec le King.
  Future<List<MachineKingModel>> fetchMachineKings() async {
    final machinesRows = await _client.from('machines').select();
    final kingsRows = await _client.from('machine_kings').select();
    final kingsByMachine = {
      for (final row in kingsRows as List<dynamic>)
        (row as Map<String, dynamic>)['machine_id'] as String: row,
    };

    final userId = _client.auth.currentUser?.id;
    Map<String, double> myBests = {};
    if (userId != null) {
      final myRows = await _client
          .from('performances')
          .select('machine_id, weight_kg')
          .eq('user_id', userId)
          .eq('validation_status', 'VALIDATED');
      for (final row in myRows as List<dynamic>) {
        final map = row as Map<String, dynamic>;
        final machineId = map['machine_id'] as String;
        final weight = (map['weight_kg'] as num).toDouble();
        if (!myBests.containsKey(machineId) || weight > myBests[machineId]!) {
          myBests[machineId] = weight;
        }
      }
    }

    return (machinesRows as List<dynamic>).map((m) {
      final machine = m as Map<String, dynamic>;
      final machineId = machine['id'] as String;
      final king = kingsByMachine[machineId];
      return MachineKingModel(
        machineId: machineId,
        machineName: machine['name'] as String,
        targetedMuscle: machine['targeted_muscle'] as String?,
        kingPseudo: king?['pseudo'] as String?,
        kingWeightKg: (king?['weight_kg'] as num?)?.toDouble(),
        myBestWeightKg: myBests[machineId],
      );
    }).toList();
  }
}
