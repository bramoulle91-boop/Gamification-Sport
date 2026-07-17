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
    required this.currentDayLabel,
  });

  final ProgramModel program;
  final String currentDayLabel;

  List<ProgramExerciseModel> get todaysExercises => program.exercisesForDay(currentDayLabel);
}
