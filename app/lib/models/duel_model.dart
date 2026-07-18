enum DuelStatus { pending, active, declined, finished }

DuelStatus duelStatusFromString(String value) {
  switch (value) {
    case 'PENDING':
      return DuelStatus.pending;
    case 'ACTIVE':
      return DuelStatus.active;
    case 'DECLINED':
      return DuelStatus.declined;
    default:
      return DuelStatus.finished;
  }
}

/// Un défi entre deux amis sur un exercice : qui soulève le plus lourd
/// pendant la période, calculé à partir des vraies performances/exercices
/// validés (pas une déclaration manuelle).
class DuelModel {
  DuelModel({
    required this.id,
    required this.challengerId,
    required this.opponentId,
    required this.exerciseName,
    required this.status,
    required this.endsAt,
    required this.createdAt,
    this.winnerId,
    this.challengerPseudo,
    this.opponentPseudo,
  });

  factory DuelModel.fromMap(Map<String, dynamic> map) {
    final challenger = map['challenger'] as Map<String, dynamic>?;
    final opponent = map['opponent'] as Map<String, dynamic>?;
    return DuelModel(
      id: map['id'] as String,
      challengerId: map['challenger_id'] as String,
      opponentId: map['opponent_id'] as String,
      exerciseName: map['exercise_name'] as String,
      status: duelStatusFromString(map['status'] as String),
      endsAt: DateTime.parse(map['ends_at'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      winnerId: map['winner_id'] as String?,
      challengerPseudo: challenger?['pseudo'] as String?,
      opponentPseudo: opponent?['pseudo'] as String?,
    );
  }

  final String id;
  final String challengerId;
  final String opponentId;
  final String exerciseName;
  final DuelStatus status;
  final DateTime endsAt;
  final DateTime createdAt;
  final String? winnerId;
  final String? challengerPseudo;
  final String? opponentPseudo;

  bool get isPastDue => DateTime.now().toUtc().isAfter(endsAt.toUtc());

  String opponentPseudoFor(String myId) => myId == challengerId ? (opponentPseudo ?? '?') : (challengerPseudo ?? '?');
  String myRoleFor(String myId) => myId == challengerId ? 'challenger' : 'opponent';
}
