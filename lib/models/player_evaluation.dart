class PlayerEvaluation {
  final String? id;
  final String playerId;
  final String coachId;
  final String? preferredZone;
  final String? coachNotes;
  final DateTime evaluationDate;
  final int pace;
  final int shooting;
  final int passing;
  final int dribbling;
  final int defending;
  final int physical;

  PlayerEvaluation({
    this.id,
    required this.playerId,
    required this.coachId,
    this.preferredZone,
    this.coachNotes,
    required this.evaluationDate,
    required this.pace,
    required this.shooting,
    required this.passing,
    required this.dribbling,
    required this.defending,
    required this.physical,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'player_id': playerId,
      'coach_id': coachId,
      'preferred_zone': preferredZone,
      'coach_notes': coachNotes,
      'evaluation_date': evaluationDate.toIso8601String(),
      'pace': pace,
      'shooting': shooting,
      'passing': passing,
      'dribbling': dribbling,
      'defending': defending,
      'physical': physical,
    };
  }

  factory PlayerEvaluation.fromMap(Map<String, dynamic> map) {
    return PlayerEvaluation(
      id: map['id'],
      playerId: map['player_id'],
      coachId: map['coach_id'],
      preferredZone: map['preferred_zone'],
      coachNotes: map['coach_notes'],
      evaluationDate: DateTime.parse(map['evaluation_date']),
      pace: map['pace'] ?? 0,
      shooting: map['shooting'] ?? 0,
      passing: map['passing'] ?? 0,
      dribbling: map['dribbling'] ?? 0,
      defending: map['defending'] ?? 0,
      physical: map['physical'] ?? 0,
    );
  }
}
