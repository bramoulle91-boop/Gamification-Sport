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
  });

  factory FriendshipModel.fromMap(Map<String, dynamic> map) {
    return FriendshipModel(
      userId1: map['user_id_1'] as String,
      userId2: map['user_id_2'] as String,
      status: friendshipStatusFromString(map['status'] as String),
      connectedAt: DateTime.parse(map['connected_at'] as String),
    );
  }

  final String userId1;
  final String userId2;
  final FriendshipStatus status;
  final DateTime connectedAt;
}
