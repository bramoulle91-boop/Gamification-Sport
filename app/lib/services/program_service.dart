import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/program_exercise_model.dart';
import '../models/program_model.dart';
import 'supabase_service.dart';

class ProgramService {
  final SupabaseClient _client = SupabaseService.client;

  Future<ProgramModel> _fetchProgram(String programId) async {
    final rows = await _client
        .from('program_exercises')
        .select()
        .eq('program_id', programId)
        .order('order_index');
    final exercises = (rows as List<dynamic>)
        .map((e) => ProgramExerciseModel.fromMap(e as Map<String, dynamic>))
        .toList();
    final programRow =
        await _client.from('programs').select().eq('id', programId).single();
    return ProgramModel(
      id: programRow['id'] as String,
      name: programRow['name'] as String,
      description: programRow['description'] as String?,
      exercises: exercises,
    );
  }

  /// Le programme suivi par l'utilisateur courant, ou `null` s'il n'en a pas
  /// encore choisi (mode démo compris : aucune session -> null).
  Future<UserProgramModel?> fetchMyProgram() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    final row = await _client
        .from('user_programs')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) return null;

    final program = await _fetchProgram(row['program_id'] as String);
    return UserProgramModel(program: program, currentDayLabel: row['current_day_label'] as String);
  }

  /// Le programme de démonstration proposé aux nouveaux utilisateurs.
  Future<ProgramModel> fetchDiscoveryProgram() {
    return _fetchProgram('00000000-0000-4000-8000-000000000001');
  }

  Future<void> enroll(ProgramModel program) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Connecte-toi pour démarrer un programme.');
    }
    await _client.from('user_programs').insert({
      'user_id': userId,
      'program_id': program.id,
      'current_day_label': program.dayLabels.first,
    });
  }

  Future<UserProgramModel> advanceToNextDay(ProgramModel program) async {
    final row = await _client.rpc('advance_program_day');
    return UserProgramModel(
      program: program,
      currentDayLabel: (row as Map<String, dynamic>)['current_day_label'] as String,
    );
  }
}
