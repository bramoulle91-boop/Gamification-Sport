import 'program_exercise_model.dart';

class ProgramModel {
  ProgramModel({
    required this.id,
    required this.name,
    required this.exercises,
    this.description,
  });

  final String id;
  final String name;
  final String? description;
  final List<ProgramExerciseModel> exercises;

  List<String> get dayLabels {
    final seen = <String>{};
    final ordered = <String>[];
    for (final exercise in exercises) {
      if (seen.add(exercise.dayLabel)) ordered.add(exercise.dayLabel);
    }
    return ordered;
  }

  List<ProgramExerciseModel> exercisesForDay(String dayLabel) {
    final list = exercises.where((e) => e.dayLabel == dayLabel).toList()
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    return list;
  }
}

class UserProgramModel {
  UserProgramModel({
    required this.program,
    required this.todaysDayLabel,
    required this.weeklySchedule,
  });

  final ProgramModel program;

  /// La séance prévue aujourd'hui d'après le calendrier hebdomadaire, ou
  /// `null` si c'est un jour de repos (ou si le calendrier n'est pas encore
  /// configuré et qu'aucun repli n'a été trouvé).
  final String? todaysDayLabel;

  /// Le calendrier hebdomadaire complet : jour ISO (1=lundi..7=dimanche) ->
  /// day_label du programme, ou `null` pour repos.
  final Map<int, String?> weeklySchedule;

  bool get isRestDayToday => todaysDayLabel == null;

  List<ProgramExerciseModel> get todaysExercises =>
      todaysDayLabel == null ? const [] : program.exercisesForDay(todaysDayLabel!);
}
