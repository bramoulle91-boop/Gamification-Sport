enum ValidationLevel { level1, level2, level3 }

extension ValidationLevelX on ValidationLevel {
  String get dbValue => switch (this) {
        ValidationLevel.level1 => '1',
        ValidationLevel.level2 => '2',
        ValidationLevel.level3 => '3',
      };

  static ValidationLevel fromDb(String value) => switch (value) {
        '2' => ValidationLevel.level2,
        '3' => ValidationLevel.level3,
        _ => ValidationLevel.level1,
      };
}

enum ValidationStatus { pending, validated, rejected }

ValidationStatus validationStatusFromString(String value) => switch (value) {
      'VALIDATED' => ValidationStatus.validated,
      'REJECTED' => ValidationStatus.rejected,
      _ => ValidationStatus.pending,
    };

class PerformanceModel {
  PerformanceModel({
    required this.id,
    required this.userId,
    required this.machineId,
    required this.weightKg,
    required this.reps,
    required this.performedAt,
    required this.validationLevel,
    required this.validationStatus,
    this.proofPhotoPath,
    this.proofVideoPath,
  });

  factory PerformanceModel.fromMap(Map<String, dynamic> map) {
    return PerformanceModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      machineId: map['machine_id'] as String,
      weightKg: (map['weight_kg'] as num).toDouble(),
      reps: (map['reps'] as num).toInt(),
      performedAt: DateTime.parse(map['performed_at'] as String),
      validationLevel: ValidationLevelX.fromDb(map['validation_level'] as String),
      validationStatus: validationStatusFromString(map['validation_status'] as String),
      proofPhotoPath: map['proof_photo_path'] as String?,
      proofVideoPath: map['proof_video_path'] as String?,
    );
  }

  final String id;
  final String userId;
  final String machineId;
  final double weightKg;
  final int reps;
  final DateTime performedAt;
  final ValidationLevel validationLevel;
  final ValidationStatus validationStatus;
  final String? proofPhotoPath;
  final String? proofVideoPath;
}
