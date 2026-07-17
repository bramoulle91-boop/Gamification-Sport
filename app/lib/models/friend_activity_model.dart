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
  });

  final FriendActivityType type;
  final String pseudo;
  final String gymName;
  final DateTime at;
  final String? exerciseName;

  String get message {
    if (type == FriendActivityType.checkin) {
      return '$pseudo vient de se connecter à $gymName';
    }
    return '$pseudo vient de terminer ${exerciseName ?? 'un exercice'} à $gymName';
  }
}
