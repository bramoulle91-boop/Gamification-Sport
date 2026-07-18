/// Un message du tchat d'une salle.
class GymMessageModel {
  GymMessageModel({
    required this.id,
    required this.gymId,
    required this.userId,
    required this.pseudo,
    required this.message,
    required this.createdAt,
  });

  factory GymMessageModel.fromMap(Map<String, dynamic> map) {
    return GymMessageModel(
      id: map['id'] as String,
      gymId: map['gym_id'] as String,
      userId: map['user_id'] as String,
      pseudo: map['pseudo'] as String,
      message: map['message'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  final String id;
  final String gymId;
  final String userId;
  final String pseudo;
  final String message;
  final DateTime createdAt;
}
