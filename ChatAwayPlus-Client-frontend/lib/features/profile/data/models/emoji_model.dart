// lib/features/profile/data/models/emoji_model.dart

import 'dart:convert';

/// Domain model for emoji updates
/// Represents user's emoji status with caption
class EmojiModel {
  final String? id;
  final String? userId;
  final String? emoji;
  final String? caption;
  final DateTime? deletedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Nested user data (comes with PUT response)
  final String? userFirstName;
  final String? userLastName;
  final String? userProfilePic;

  const EmojiModel({
    this.id,
    this.userId,
    this.emoji,
    this.caption,
    this.deletedAt,
    this.createdAt,
    this.updatedAt,
    this.userFirstName,
    this.userLastName,
    this.userProfilePic,
  });

  /// Factory for API response (both POST and PUT)
  factory EmojiModel.fromApi(Map<String, dynamic> json) {
    final data = (json['data'] as Map?)?.cast<String, dynamic>() ?? json;
    final user = (data['user'] as Map?)?.cast<String, dynamic>() ?? const {};

    DateTime? parseDateTime(dynamic value) {
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    return EmojiModel(
      id: data['id'] as String?,
      userId: data['userId'] as String?,
      emoji:
          (data['emojis_update'] as String?) ??
          (data['emoji'] as String?) ??
          (data['emojisUpdate'] as String?),
      caption:
          (data['emojis_caption'] as String?) ??
          (data['caption'] as String?) ??
          (data['emojisCaption'] as String?),
      deletedAt: parseDateTime(data['deletedAt']),
      createdAt: parseDateTime(data['createdAt']),
      updatedAt: parseDateTime(data['updatedAt']),
      userFirstName: user['firstName'] as String?,
      userLastName: user['lastName'] as String?,
      userProfilePic:
          (user['profile_pic'] as String?) ??
          user['profilePic'] as String? ??
          (user['chat_picture'] as String?) ??
          user['chatPicture'] as String?,
    );
  }

  /// Factory for local JSON storage
  factory EmojiModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDateTime(dynamic value) {
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    return EmojiModel(
      id: json['id'] as String?,
      userId: json['userId'] as String?,
      emoji: json['emoji'] as String?,
      caption: json['caption'] as String?,
      deletedAt: parseDateTime(json['deletedAt']),
      createdAt: parseDateTime(json['createdAt']),
      updatedAt: parseDateTime(json['updatedAt']),
      userFirstName: json['userFirstName'] as String?,
      userLastName: json['userLastName'] as String?,
      userProfilePic: json['userProfilePic'] as String?,
    );
  }

  /// Convert to JSON for local storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'emoji': emoji,
      'caption': caption,
      'deletedAt': deletedAt?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'userFirstName': userFirstName,
      'userLastName': userLastName,
      'userProfilePic': userProfilePic,
    };
  }

  /// Check if emoji exists (not null/empty)
  bool get hasEmoji => emoji?.trim().isNotEmpty ?? false;

  /// Check if caption exists (not null/empty)
  bool get hasCaption => caption?.trim().isNotEmpty ?? false;

  /// Check if emoji is valid (has both emoji and caption)
  bool get isValid => hasEmoji && hasCaption;

  /// Copy with method for updates
  EmojiModel copyWith({
    String? id,
    String? userId,
    String? emoji,
    String? caption,
    DateTime? deletedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? userFirstName,
    String? userLastName,
    String? userProfilePic,
  }) {
    return EmojiModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      emoji: emoji ?? this.emoji,
      caption: caption ?? this.caption,
      deletedAt: deletedAt ?? this.deletedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      userFirstName: userFirstName ?? this.userFirstName,
      userLastName: userLastName ?? this.userLastName,
      userProfilePic: userProfilePic ?? this.userProfilePic,
    );
  }

  @override
  String toString() => jsonEncode(toJson());
}
