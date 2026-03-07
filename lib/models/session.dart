class ShootingSession {
  final String? id;
  final String position; // e.g., 'Corner 3', 'Free Throw', 'Paint'
  final String range;    // e.g., 'Mid-range', 'Three-pointer'
  int makes;
  int attempts;
  final DateTime timestamp;

  ShootingSession({
    this.id,
    required this.position,
    required this.range,
    this.makes = 0,
    this.attempts = 0,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'position': position,
      'range': range,
      'makes': makes,
      'attempts': attempts,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory ShootingSession.fromMap(Map<String, dynamic> map) {
    return ShootingSession(
      id: map['id'],
      position: map['position'],
      range: map['range'],
      makes: map['makes'],
      attempts: map['attempts'],
      timestamp: DateTime.parse(map['timestamp']),
    );
  }

  double get percentage => attempts > 0 ? (makes / attempts) * 100 : 0.0;
}
