class MachineModel {
  MachineModel({
    required this.id,
    required this.name,
    required this.gymId,
    required this.qrCodeHash,
    this.targetedMuscle,
  });

  factory MachineModel.fromMap(Map<String, dynamic> map) {
    return MachineModel(
      id: map['id'] as String,
      name: map['name'] as String,
      gymId: map['gym_id'] as String,
      qrCodeHash: map['qr_code_hash'] as String,
      targetedMuscle: map['targeted_muscle'] as String?,
    );
  }

  final String id;
  final String name;
  final String gymId;
  final String qrCodeHash;
  final String? targetedMuscle;
}
