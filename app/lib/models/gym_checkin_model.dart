/// Un passage d'un utilisateur GymQuest dans une salle aujourd'hui —
/// déclenché en cochant un exercice de sa séance (voir
/// `program_exercise_completions`), validé par géolocalisation côté serveur.
class GymCheckinModel {
  GymCheckinModel({required this.userId, required this.pseudo, required this.checkedInAt});

  factory GymCheckinModel.fromMap(Map<String, dynamic> map) {
    return GymCheckinModel(
      userId: map['user_id'] as String,
      pseudo: (map['users'] as Map<String, dynamic>?)?['pseudo'] as String? ?? '?',
      checkedInAt: DateTime.parse(map['checked_in_at'] as String),
    );
  }

  final String userId;
  final String pseudo;
  final DateTime checkedInAt;
}
