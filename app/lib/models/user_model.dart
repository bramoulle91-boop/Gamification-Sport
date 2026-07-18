class UserModel {
  UserModel({
    required this.id,
    required this.pseudo,
    required this.email,
    this.realName,
    this.leagueLevel = 1,
    this.totalPoints = 0,
    this.streakHistory = const [],
    this.homeGymId,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as String,
      pseudo: map['pseudo'] as String,
      email: map['email'] as String,
      realName: map['real_name'] as String?,
      leagueLevel: (map['league_level'] as num?)?.toInt() ?? 1,
      totalPoints: (map['total_points'] as num?)?.toInt() ?? 0,
      streakHistory: (map['streak_history'] as List<dynamic>? ?? const [])
          .map((e) => e as Map<String, dynamic>)
          .toList(),
      homeGymId: map['home_gym_id'] as String?,
    );
  }

  final String id;
  final String pseudo;
  final String email;
  final String? realName;
  final int leagueLevel;
  final int totalPoints;
  final List<Map<String, dynamic>> streakHistory;
  final String? homeGymId;

  Map<String, dynamic> toMap() => {
        'id': id,
        'pseudo': pseudo,
        'email': email,
        'real_name': realName,
        'league_level': leagueLevel,
        'total_points': totalPoints,
        'streak_history': streakHistory,
        'home_gym_id': homeGymId,
      };
}
