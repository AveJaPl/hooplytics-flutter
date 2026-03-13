class Shot {
  final String? id;
  final String sessionId;
  final String userId;
  final int orderIdx;
  final bool isMake;
  final bool isSwish;
  final DateTime? createdAt;

  Shot({
    this.id,
    required this.sessionId,
    required this.userId,
    required this.orderIdx,
    required this.isMake,
    required this.isSwish,
    this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'session_id': sessionId,
      'user_id': userId,
      'order_idx': orderIdx,
      'is_make': isMake,
      'is_swish': isSwish,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  factory Shot.fromJson(Map<String, dynamic> json) {
    return Shot(
      id: json['id'] as String?,
      sessionId: json['session_id'] as String,
      userId: json['user_id'] as String,
      orderIdx: json['order_idx'] as int,
      isMake: json['is_make'] as bool,
      isSwish: json['is_swish'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }
}

enum ShotResult { miss, make, swish }
