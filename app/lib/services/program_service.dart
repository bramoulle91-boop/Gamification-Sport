import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/program_exercise_model.dart';
import '../models/program_model.dart';
import 'supabase_service.dart';

/// Brouillon d'exercice saisi par l'utilisateur avant la création du
/// programme personnalisé (pas encore d'ID, pas encore en base).
class ProgramExerciseDraft {
  ProgramExerciseDraft({
    required this.dayLabel,
    required this.exerciseName,
    required this.targetSets,
    required this.targetReps,
    this.targetedMuscle,
    this.targetWeightKg,
  });

  final String dayLabel;
  final String exerciseName;
  final String? targetedMuscle;
  final int targetSets;
  final int targetReps;
  final double? targetWeightKg;
}

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

  /// Les programmes personnalisés déjà créés par l'utilisateur courant,
  /// pour pouvoir en reprendre un sans le recréer.
  Future<List<ProgramModel>> fetchMyCustomPrograms() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];
    final rows = await _client.from('programs').select().eq('created_by', userId);
    final programs = <ProgramModel>[];
    for (final row in rows as List<dynamic>) {
      programs.add(await _fetchProgram((row as Map<String, dynamic>)['id'] as String));
    }
    return programs;
  }

  Future<ProgramModel> createCustomProgram({
    required String name,
    required List<ProgramExerciseDraft> exercises,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Connecte-toi pour créer un programme.');
    }
    if (exercises.isEmpty) {
      throw Exception('Ajoute au moins un exercice.');
    }

    final programRow = await _client
        .from('programs')
        .insert({'name': name, 'created_by': userId})
        .select()
        .single();
    final programId = programRow['id'] as String;

    await _client.from('program_exercises').insert([
      for (var i = 0; i < exercises.length; i++)
        {
          'program_id': programId,
          'day_label': exercises[i].dayLabel,
          'order_index': i,
          'exercise_name': exercises[i].exerciseName,
          'targeted_muscle': exercises[i].targetedMuscle,
          'target_sets': exercises[i].targetSets,
          'target_reps': exercises[i].targetReps,
          'target_weight_kg': exercises[i].targetWeightKg,
        },
    ]);

    return _fetchProgram(programId);
  }

  /// Démarre (ou change pour) ce programme — remplace le programme suivi
  /// actuel s'il y en avait déjà un.
  Future<void> enroll(ProgramModel program) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Connecte-toi pour démarrer un programme.');
    }
    await _client.from('user_programs').upsert({
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
