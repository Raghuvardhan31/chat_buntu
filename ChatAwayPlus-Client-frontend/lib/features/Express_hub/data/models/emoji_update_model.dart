// lib/features/voice_hub/data/models/emoji_update_model.dart

/// Model for emoji updates from other users
class EmojiUpdateModel {
  final String id;
  final String userId;
  final String emoji;
  final String? caption;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // User info
  final String? userFirstName;
  final String? userLastName;
  final String? userProfilePic;

  const EmojiUpdateModel({
    required this.id,
    required this.userId,
    required this.emoji,
    this.caption,
    this.createdAt,
    this.updatedAt,
    this.userFirstName,
    this.userLastName,
    this.userProfilePic,
  });

  /// Factory from API response
  factory EmojiUpdateModel.fromJson(Map<String, dynamic> json) {
    final user = (json['user'] as Map<String, dynamic>?) ?? {};

    DateTime? parseDateTime(dynamic value) {
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    return EmojiUpdateModel(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      emoji:
          (json['emojis_update'] as String?) ??
          (json['emoji'] as String?) ??
          (json['emojisUpdate'] as String?) ??
          '',
      caption:
          (json['emojis_caption'] as String?) ??
          (json['caption'] as String?) ??
          (json['emojisCaption'] as String?),
      createdAt: parseDateTime(json['createdAt']),
      updatedAt: parseDateTime(json['updatedAt']),
      userFirstName: user['firstName'] as String?,
      userLastName: user['lastName'] as String?,
      userProfilePic:
          (user['profile_pic'] as String?) ??
          (user['profilePic'] as String?) ??
          (user['chat_picture'] as String?) ??
          (user['chatPicture'] as String?),
    );
  }

  /// Convert to map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'emojis_update': emoji,
      'emojis_caption': caption,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'user_first_name': userFirstName,
      'user_last_name': userLastName,
      'user_profile_pic': userProfilePic,
    };
  }

  /// Get full name
  String get fullName {
    final first = userFirstName ?? '';
    final last = userLastName ?? '';
    return '$first $last'.trim().isEmpty
        ? 'Unknown User'
        : '$first $last'.trim();
  }

  /// Check if has caption
  bool get hasCaption => caption?.trim().isNotEmpty ?? false;
}
