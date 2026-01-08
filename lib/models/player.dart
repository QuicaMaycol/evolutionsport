class Player {
  final String id;
  final String firstName;
  final String lastName;
  final String position;
  final int sessionsCompleted;
  final DateTime lastAttendance;

  Player({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.position,
    required this.sessionsCompleted,
    required this.lastAttendance,
  });

  String get fullName => '$firstName $lastName';

  factory Player.fromMap(Map<String, dynamic> map) {
    final rawAttendance = map['last_attendance'] as String?;
    return Player(
      id: map['id'] as String,
      firstName: map['first_name'] as String? ?? '',
      lastName: map['last_name'] as String? ?? '',
      position: map['position'] as String? ?? 'Sin posicion',
      sessionsCompleted: map['sessions_completed'] as int? ?? 0,
      lastAttendance: rawAttendance != null
          ? DateTime.parse(rawAttendance)
          : DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
