enum FriendActivityType { checkin, exerciseDone }

/// Un événement récent d'un ami : arrivée en salle ou exercice de son
/// programme coché — reconstitué à partir de `gym_checkins` et
/// `program_exercise_completions`, en attendant les vraies notifications
/// push.
class FriendActivityModel {
  FriendActivityModel({
    required this.type,
    required this.pseudo,
    required this.gymName,
    required this.at,
    this.exerciseName,
    this.weightKg,
    this.isRecord = false,
  });

  final FriendActivityType type;
  final String pseudo;
  final String gymName;
  final DateTime at;
  final String? exerciseName;
  final double? weightKg;
  final bool isRecord;

  String get message {
    if (type == FriendActivityType.checkin) {
      return '$pseudo vient de se connecter à $gymName';
    }
    final weightText = weightKg != null && weightKg! > 0 ? ' à ${weightKg!.toStringAsFixed(0)}kg' : '';
    if (isRecord) {
      return '$pseudo a battu son record : ${exerciseName ?? 'un exercice'}$weightText à $gymName 🏆';
    }
    return '$pseudo vient de terminer ${exerciseName ?? 'un exercice'}$weightText à $gymName';
  }
}
