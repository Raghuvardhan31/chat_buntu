/// Model for draggable emoji data
class DraggableEmojiModel {
  final String userId;
  final String emoji;
  final int updatedAt;

  const DraggableEmojiModel({
    required this.userId,
    required this.emoji,
    required this.updatedAt,
  });

  /// Create from database map
  factory DraggableEmojiModel.fromMap(Map<String, dynamic> map) {
    return DraggableEmojiModel(
      userId: map['user_id'] as String,
      emoji: map['emoji'] as String,
      updatedAt: map['updated_at'] as int,
    );
  }

  /// Convert to database map
  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'emoji': emoji,
      'updated_at': updatedAt,
    };
  }

  /// Create copy with updated values
  DraggableEmojiModel copyWith({
    String? userId,
    String? emoji,
    int? updatedAt,
  }) {
    return DraggableEmojiModel(
      userId: userId ?? this.userId,
      emoji: emoji ?? this.emoji,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DraggableEmojiModel &&
        other.userId == userId &&
        other.emoji == emoji &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => userId.hashCode ^ emoji.hashCode ^ updatedAt.hashCode;

  @override
  String toString() {
    return 'DraggableEmojiModel(userId: $userId, emoji: $emoji, updatedAt: $updatedAt)';
  }
}
