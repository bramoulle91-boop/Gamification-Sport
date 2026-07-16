class RewardModel {
  RewardModel({
    required this.id,
    required this.name,
    required this.pointsCost,
    this.partnerName,
    this.stock = 0,
  });

  factory RewardModel.fromMap(Map<String, dynamic> map) {
    return RewardModel(
      id: map['id'] as String,
      name: map['name'] as String,
      pointsCost: (map['points_cost'] as num).toInt(),
      partnerName: map['partner_name'] as String?,
      stock: (map['stock'] as num?)?.toInt() ?? 0,
    );
  }

  final String id;
  final String name;
  final int pointsCost;
  final String? partnerName;
  final int stock;
}
