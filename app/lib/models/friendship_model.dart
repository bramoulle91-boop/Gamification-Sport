enum FriendshipStatus { pending, unlocked }

FriendshipStatus friendshipStatusFromString(String value) {
  return value == 'DEBLOCKED' ? FriendshipStatus.unlocked : FriendshipStatus.pending;
}

class FriendshipModel {
  FriendshipModel({
    required this.userId1,
    required this.userId2,
    required this.status,
    required this.connectedAt,
    this.user1Pseudo,
    this.user1TotalPoints,
    this.user1StreakDays,
    this.user2Pseudo,
    this.user2TotalPoints,
    this.user2StreakDays,
  });

  factory FriendshipModel.fromMap(Map<String, dynamic> map) {
    final user1 = map['user_1'] as Map<String, dynamic>?;
    final user2 = map['user_2'] as Map<String, dynamic>?;
    return FriendshipModel(
      userId1: map['user_id_1'] as String,
      userId2: map['user_id_2'] as String,
      status: friendshipStatusFromString(map['status'] as String),
      connectedAt: DateTime.parse(map['connected_at'] as String),
      user1Pseudo: user1?['pseudo'] as String?,
      user1TotalPoints: (user1?['total_points'] as num?)?.toInt(),
      user1StreakDays: (user1?['streak_history'] as List<dynamic>?)?.length,
      user2Pseudo: user2?['pseudo'] as String?,
      user2TotalPoints: (user2?['total_points'] as num?)?.toInt(),
      user2StreakDays: (user2?['streak_history'] as List<dynamic>?)?.length,
    );
  }

  final String userId1;
  final String userId2;
  final FriendshipStatus status;
  final DateTime connectedAt;
  final String? user1Pseudo;
  final int? user1TotalPoints;
  final int? user1StreakDays;
  final String? user2Pseudo;
  final int? user2TotalPoints;
  final int? user2StreakDays;

  String pseudoForOther(String myId) => myId == userId1 ? (user2Pseudo ?? userId2) : (user1Pseudo ?? userId1);
  int pointsForOther(String myId) => myId == userId1 ? (user2TotalPoints ?? 0) : (user1TotalPoints ?? 0);
  int streakForOther(String myId) => myId == userId1 ? (user2StreakDays ?? 0) : (user1StreakDays ?? 0);
}
