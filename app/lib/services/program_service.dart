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

  /// Les exercices déjà cochés aujourd'hui par l'utilisateur courant, pour
  /// que les cases à cocher de la séance survivent à un rechargement.
  Future<Set<String>> fetchTodaysCompletions() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return {};
    final today = DateTime.now().toUtc().toIso8601String().split('T').first;
    final rows = await _client
        .from('program_exercise_completions')
        .select('program_exercise_id')
        .eq('user_id', userId)
        .eq('completed_on', today);
    return (rows as List<dynamic>)
        .map((e) => (e as Map<String, dynamic>)['program_exercise_id'] as String)
        .toSet();
  }

  /// Coche un exercice de la séance du jour — validé par géolocalisation
  /// côté serveur (comme le niveau 1), et déclenche un check-in visible par
  /// les amis si c'est la première validation du jour dans cette salle. En
  /// attendant que toutes les machines aient un QR code, c'est ce geste qui
  /// sert de preuve de présence.
  Future<void> completeExercise({
    required String programExerciseId,
    required String gymId,
    required double lat,
    required double lon,
  }) async {
    await _client.rpc('complete_program_exercise', params: {
      'p_program_exercise_id': programExerciseId,
      'p_gym_id': gymId,
      'p_user_lat': lat,
      'p_user_lon': lon,
    });
  }

  /// Décoche un exercice précédemment validé aujourd'hui.
  Future<void> uncompleteExercise(String programExerciseId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    final today = DateTime.now().toUtc().toIso8601String().split('T').first;
    await _client
        .from('program_exercise_completions')
        .delete()
        .eq('user_id', userId)
        .eq('program_exercise_id', programExerciseId)
        .eq('completed_on', today);
  }
}
