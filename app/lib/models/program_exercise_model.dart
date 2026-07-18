class ProgramExerciseModel {
  ProgramExerciseModel({
    required this.id,
    required this.dayLabel,
    required this.orderIndex,
    required this.exerciseName,
    required this.targetSets,
    required this.targetReps,
    this.targetedMuscle,
    this.targetWeightKg,
  });

  factory ProgramExerciseModel.fromMap(Map<String, dynamic> map) {
    return ProgramExerciseModel(
      id: map['id'] as String,
      dayLabel: map['day_label'] as String,
      orderIndex: (map['order_index'] as num).toInt(),
      exerciseName: map['exercise_name'] as String,
      targetedMuscle: map['targeted_muscle'] as String?,
      targetSets: (map['target_sets'] as num).toInt(),
      targetReps: (map['target_reps'] as num).toInt(),
      targetWeightKg: (map['target_weight_kg'] as num?)?.toDouble(),
    );
  }

  final String id;
  final String dayLabel;
  final int orderIndex;
  final String exerciseName;
  final String? targetedMuscle;
  final int targetSets;
  final int targetReps;
  final double? targetWeightKg;
}
