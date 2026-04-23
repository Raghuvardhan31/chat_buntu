/// Model for user's personal mood emoji with expiry time
class MoodEmojiModel {
  final String userId;
  final String emoji;
  final DateTime expiryTimestamp;
  final DateTime createdAt;

  const MoodEmojiModel({
    required this.userId,
    required this.emoji,
    required this.expiryTimestamp,
    required this.createdAt,
  });

  /// Check if the mood emoji has expired
  bool get isExpired => DateTime.now().isAfter(expiryTimestamp);

  /// Convert from database map
  factory MoodEmojiModel.fromMap(Map<String, dynamic> map) {
    return MoodEmojiModel(
      userId: map['user_id'] as String,
      emoji: map['emoji'] as String,
      expiryTimestamp: DateTime.fromMillisecondsSinceEpoch(
        map['expiry_timestamp'] as int,
      ),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  /// Convert to database map
  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'emoji': emoji,
      'expiry_timestamp': expiryTimestamp.millisecondsSinceEpoch,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  /// Create a copy with updated fields
  MoodEmojiModel copyWith({
    String? userId,
    String? emoji,
    DateTime? expiryTimestamp,
    DateTime? createdAt,
  }) {
    return MoodEmojiModel(
      userId: userId ?? this.userId,
      emoji: emoji ?? this.emoji,
      expiryTimestamp: expiryTimestamp ?? this.expiryTimestamp,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
