class MachineKingModel {
  MachineKingModel({
    required this.machineId,
    required this.machineName,
    this.targetedMuscle,
    this.kingPseudo,
    this.kingWeightKg,
    this.myBestWeightKg,
  });

  final String machineId;
  final String machineName;
  final String? targetedMuscle;
  final String? kingPseudo;
  final double? kingWeightKg;
  final double? myBestWeightKg;

  bool get hasKing => kingPseudo != null;
  bool get isMeTheKing => myBestWeightKg != null && kingWeightKg != null && myBestWeightKg! >= kingWeightKg!;
}
