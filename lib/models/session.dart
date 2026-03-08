import 'shot.dart';

class Session {
  final String? id;
  final String userId;
  final String type; // 'live', 'manual', or 'game'
  final String mode; // 'position' or 'range'
  final String selectionId;
  final String selectionLabel;
  final String? gameModeId; // e.g. 'three_point_contest'
  final Map<String, dynamic>? gameData; // Flexible stats for games
  final int targetShots;
  final int made;
  final int swishes;
  final int attempts;
  final int bestStreak;
  final int elapsedSeconds;
  final DateTime? createdAt;
  final List<Shot>? shots;

  Session({
    this.id,
    required this.userId,
    this.type = 'live',
    required this.mode,
    required this.selectionId,
    required this.selectionLabel,
    this.gameModeId,
    this.gameData,
    this.targetShots = 0,
    required this.made,
    required this.swishes,
    required this.attempts,
    required this.bestStreak,
    required this.elapsedSeconds,
    this.createdAt,
    this.shots,
  });

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'type': type,
      'mode': mode,
      'selection_id': selectionId,
      'selection_label': selectionLabel,
      if (gameModeId != null) 'game_mode_id': gameModeId,
      if (gameData != null) 'game_data': gameData,
      'target_shots': targetShots,
      'made': made,
      'swishes': swishes,
      'attempts': attempts,
      'best_streak': bestStreak,
      'elapsed_seconds': elapsedSeconds,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      id: json['id'] as String?,
      userId: json['user_id'] as String,
      type: json['type'] as String? ?? 'live',
      mode: json['mode'] as String,
      selectionId: json['selection_id'] as String,
      selectionLabel: json['selection_label'] as String,
      gameModeId: json['game_mode_id'] as String?,
      gameData: json['game_data'] as Map<String, dynamic>?,
      targetShots: json['target_shots'] as int? ?? 0,
      made: json['made'] as int,
      swishes: json['swishes'] as int? ?? 0,
      attempts: json['attempts'] as int,
      bestStreak: json['best_streak'] as int,
      elapsedSeconds: json['elapsed_seconds'] as int,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      shots: json['shots'] != null
          ? (json['shots'] as List).map((s) => Shot.fromJson(s)).toList()
          : null,
    );
  }
}
