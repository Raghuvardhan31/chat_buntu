// lib/features/profile/data/models/current_user_profile_model.dart
import 'dart:convert';

/// Normalized profile model for the current user.
/// Matches your current API response:
/// { success, data: { user:{...}, status:{...} } }
/// - Uses a single field name `content` for the status text (aligns with API "content").
/// - Keep DB adapters responsible for mapping DB column `status_content` ⇄ model `content`.
class CurrentUserProfileModel {
  // ── User (data.user)
  final String? id;
  final String? email;
  final String? firstName;
  final String? lastName;
  final String? mobileNo;
  final int? isVerified; // 0/1
  final String? profilePic; // "/uploads/..."
  final String? chatPictureVersion;
  final Map<String, dynamic>? metadata; // parsed JSON map
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // ── Status (data.status)
  final String? statusId;
  final String? statusUserId;
  final String? content; // ✅ unified status text
  final int? likesCount;
  final DateTime? deletedAt;
  final DateTime? statusCreatedAt;
  final DateTime? statusUpdatedAt;

  // ── Optional nested (data.status.user)
  final String? statusUserFirstName;
  final String? statusUserLastName;
  final String? statusUserProfilePic;

  // ── Emoji update (data.emoji_update)
  final String? emojiUpdateId;
  final String? emojiUpdateUserId;
  final String? currentEmoji;
  final String? emojiCaption;
  final DateTime? emojiDeletedAt;
  final DateTime? emojiCreatedAt;
  final DateTime? emojiUpdatedAt;

  const CurrentUserProfileModel({
    // user
    this.id,
    this.email,
    this.firstName,
    this.lastName,
    this.mobileNo,
    this.isVerified,
    this.profilePic,
    this.chatPictureVersion,
    this.metadata,
    this.createdAt,
    this.updatedAt,
    // status
    this.statusId,
    this.statusUserId,
    this.content,
    this.likesCount,
    this.deletedAt,
    this.statusCreatedAt,
    this.statusUpdatedAt,
    // status.user
    this.statusUserFirstName,
    this.statusUserLastName,
    this.statusUserProfilePic,

    // emoji_update
    this.emojiUpdateId,
    this.emojiUpdateUserId,
    this.currentEmoji,
    this.emojiCaption,
    this.emojiDeletedAt,
    this.emojiCreatedAt,
    this.emojiUpdatedAt,
  });

  /// Factory for your current API response:
  /// { success, data: { user: {...}, status: {...} } }
  factory CurrentUserProfileModel.fromApi(Map<String, dynamic> root) {
    final data = (root['data'] as Map?)?.cast<String, dynamic>() ?? const {};
    final user = (data['user'] as Map?)?.cast<String, dynamic>() ?? const {};
    final status =
        (data['status'] as Map?)?.cast<String, dynamic>() ?? const {};
    final share =
        (data['share_your_voice'] as Map?)?.cast<String, dynamic>() ?? const {};
    final sUser = (status['user'] as Map?)?.cast<String, dynamic>() ?? const {};
    final shareUser =
        (share['user'] as Map?)?.cast<String, dynamic>() ?? const {};

    final emojiUpdate =
        (data['emoji_update'] as Map?)?.cast<String, dynamic>() ?? const {};

    Map<String, dynamic>? parseMetadata(dynamic v) {
      if (v is Map<String, dynamic>) return v;
      if (v is String && v.trim().isNotEmpty) {
        try {
          final d = jsonDecode(v);
          if (d is Map<String, dynamic>) return d;
        } catch (_) {}
      }
      return null;
    }

    DateTime? dt(dynamic v) =>
        (v is String && v.isNotEmpty) ? DateTime.tryParse(v) : null;

    int? toInt(dynamic v) {
      if (v is int) return v;
      if (v == null) return null;
      return int.tryParse(v.toString());
    }

    return CurrentUserProfileModel(
      // user
      id: user['id'] as String?,
      email: user['email'] as String?,
      firstName: user['firstName'] as String?,
      lastName: user['lastName'] as String?,
      mobileNo: user['mobileNo']?.toString(),
      isVerified: toInt(user['isVerified']),
      profilePic:
          (user['chat_picture'] as String?) ??
          user['chatPicture'] as String? ??
          (user['profile_pic'] as String?) ??
          user['profilePic'] as String?,
      chatPictureVersion:
          (user['chat_picture_version'] ??
                  user['chatPictureVersion'] ??
                  user['profile_pic_version'] ??
                  user['profilePicVersion'])
              ?.toString(),
      metadata: parseMetadata(user['metadata']),
      createdAt: dt(user['createdAt']),
      updatedAt: dt(user['updatedAt']),

      // status
      statusId: (share['id'] as String?) ?? (status['id'] as String?),
      statusUserId:
          (share['userId'] as String?) ?? (status['userId'] as String?),
      content:
          (share['share_your_voice'] as String?) ??
          (share['content'] as String?) ??
          (status['content'] as String?),
      likesCount: toInt(share['likesCount'] ?? status['likesCount']),
      deletedAt: dt(share['deletedAt'] ?? status['deletedAt']),
      statusCreatedAt: dt(share['createdAt'] ?? status['createdAt']),
      statusUpdatedAt: dt(share['updatedAt'] ?? status['updatedAt']),

      // status.user
      statusUserFirstName:
          (shareUser['firstName'] as String?) ??
          (sUser['firstName'] as String?),
      statusUserLastName:
          (shareUser['lastName'] as String?) ?? (sUser['lastName'] as String?),
      statusUserProfilePic:
          (shareUser['chat_picture'] as String?) ??
          shareUser['chatPicture'] as String? ??
          (shareUser['profile_pic'] as String?) ??
          shareUser['profilePic'] as String? ??
          (sUser['chat_picture'] as String?) ??
          sUser['chatPicture'] as String? ??
          (sUser['profile_pic'] as String?) ??
          sUser['profilePic'] as String?,

      // emoji_update
      emojiUpdateId: emojiUpdate['id'] as String?,
      emojiUpdateUserId: emojiUpdate['userId'] as String?,
      currentEmoji:
          (emojiUpdate['emojis_update'] as String?) ??
          (emojiUpdate['emoji'] as String?) ??
          (emojiUpdate['emojisUpdate'] as String?),
      emojiCaption:
          (emojiUpdate['emojis_caption'] as String?) ??
          (emojiUpdate['caption'] as String?) ??
          (emojiUpdate['emojisCaption'] as String?),
      emojiDeletedAt: dt(emojiUpdate['deletedAt']),
      emojiCreatedAt: dt(emojiUpdate['createdAt']),
      emojiUpdatedAt: dt(emojiUpdate['updatedAt']),
    );
  }

  /// Deserialize from locally stored JSON of this normalized model.
  factory CurrentUserProfileModel.fromJson(Map<String, dynamic> json) {
    DateTime? dt(dynamic v) =>
        (v is String && v.isNotEmpty) ? DateTime.tryParse(v) : null;

    int? toInt(dynamic v) {
      if (v is int) return v;
      if (v == null) return null;
      return int.tryParse(v.toString());
    }

    return CurrentUserProfileModel(
      id: json['id'] as String?,
      email: json['email'] as String?,
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      mobileNo: json['mobileNo'] as String?,
      isVerified: toInt(json['isVerified']),
      profilePic: json['profilePic'] as String?,
      chatPictureVersion: json['chatPictureVersion'] as String?,
      metadata: (json['metadata'] is Map<String, dynamic>)
          ? json['metadata'] as Map<String, dynamic>
          : null,
      createdAt: dt(json['createdAt']),
      updatedAt: dt(json['updatedAt']),

      statusId: json['statusId'] as String?,
      statusUserId: json['statusUserId'] as String?,
      content: json['content'] as String?, // ✅ keep "content"
      likesCount: toInt(json['likesCount']),
      deletedAt: dt(json['deletedAt']),
      statusCreatedAt: dt(json['statusCreatedAt']),
      statusUpdatedAt: dt(json['statusUpdatedAt']),

      statusUserFirstName: json['statusUserFirstName'] as String?,
      statusUserLastName: json['statusUserLastName'] as String?,
      statusUserProfilePic: json['statusUserProfilePic'] as String?,

      emojiUpdateId: json['emojiUpdateId'] as String?,
      emojiUpdateUserId: json['emojiUpdateUserId'] as String?,
      currentEmoji: json['currentEmoji'] as String?,
      emojiCaption: json['emojiCaption'] as String?,
      emojiDeletedAt: dt(json['emojiDeletedAt']),
      emojiCreatedAt: dt(json['emojiCreatedAt']),
      emojiUpdatedAt: dt(json['emojiUpdatedAt']),
    );
  }

  /// Serialize to JSON for local storage.
  Map<String, dynamic> toJson() => {
    // user
    'id': id,
    'email': email,
    'firstName': firstName,
    'lastName': lastName,
    'mobileNo': mobileNo,
    'isVerified': isVerified,
    'profilePic': profilePic,
    'chatPictureVersion': chatPictureVersion,
    'metadata': metadata,
    'createdAt': createdAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
    // status
    'statusId': statusId,
    'statusUserId': statusUserId,
    'content': content, // ✅ single source of truth
    'likesCount': likesCount,
    'deletedAt': deletedAt?.toIso8601String(),
    'statusCreatedAt': statusCreatedAt?.toIso8601String(),
    'statusUpdatedAt': statusUpdatedAt?.toIso8601String(),
    // status.user
    'statusUserFirstName': statusUserFirstName,
    'statusUserLastName': statusUserLastName,
    'statusUserProfilePic': statusUserProfilePic,

    // emoji_update
    'emojiUpdateId': emojiUpdateId,
    'emojiUpdateUserId': emojiUpdateUserId,
    'currentEmoji': currentEmoji,
    'emojiCaption': emojiCaption,
    'emojiDeletedAt': emojiDeletedAt?.toIso8601String(),
    'emojiCreatedAt': emojiCreatedAt?.toIso8601String(),
    'emojiUpdatedAt': emojiUpdatedAt?.toIso8601String(),
  };

  bool get hasCompleteProfile =>
      (firstName?.trim().isNotEmpty ?? false) &&
      (content?.trim().isNotEmpty ?? false);

  CurrentUserProfileModel copyWith({
    String? id,
    String? email,
    String? firstName,
    String? lastName,
    String? mobileNo,
    int? isVerified,
    String? profilePic,
    String? chatPictureVersion,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? statusId,
    String? statusUserId,
    String? content,
    int? likesCount,
    DateTime? deletedAt,
    DateTime? statusCreatedAt,
    DateTime? statusUpdatedAt,
    String? statusUserFirstName,
    String? statusUserLastName,
    String? statusUserProfilePic,
    String? emojiUpdateId,
    String? emojiUpdateUserId,
    String? currentEmoji,
    String? emojiCaption,
    DateTime? emojiDeletedAt,
    DateTime? emojiCreatedAt,
    DateTime? emojiUpdatedAt,
  }) {
    return CurrentUserProfileModel(
      id: id ?? this.id,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      mobileNo: mobileNo ?? this.mobileNo,
      isVerified: isVerified ?? this.isVerified,
      profilePic: profilePic ?? this.profilePic,
      chatPictureVersion: chatPictureVersion ?? this.chatPictureVersion,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      statusId: statusId ?? this.statusId,
      statusUserId: statusUserId ?? this.statusUserId,
      content: content ?? this.content, // ✅
      likesCount: likesCount ?? this.likesCount,
      deletedAt: deletedAt ?? this.deletedAt,
      statusCreatedAt: statusCreatedAt ?? this.statusCreatedAt,
      statusUpdatedAt: statusUpdatedAt ?? this.statusUpdatedAt,
      statusUserFirstName: statusUserFirstName ?? this.statusUserFirstName,
      statusUserLastName: statusUserLastName ?? this.statusUserLastName,
      statusUserProfilePic: statusUserProfilePic ?? this.statusUserProfilePic,

      emojiUpdateId: emojiUpdateId ?? this.emojiUpdateId,
      emojiUpdateUserId: emojiUpdateUserId ?? this.emojiUpdateUserId,
      currentEmoji: currentEmoji ?? this.currentEmoji,
      emojiCaption: emojiCaption ?? this.emojiCaption,
      emojiDeletedAt: emojiDeletedAt ?? this.emojiDeletedAt,
      emojiCreatedAt: emojiCreatedAt ?? this.emojiCreatedAt,
      emojiUpdatedAt: emojiUpdatedAt ?? this.emojiUpdatedAt,
    );
  }

  CurrentUserProfileModel copyWithNullProfilePic() {
    return CurrentUserProfileModel(
      id: id,
      email: email,
      firstName: firstName,
      lastName: lastName,
      mobileNo: mobileNo,
      isVerified: isVerified,
      profilePic: null, // Explicitly set to null
      chatPictureVersion: chatPictureVersion,
      metadata: metadata,
      createdAt: createdAt,
      updatedAt: updatedAt,
      statusId: statusId,
      statusUserId: statusUserId,
      content: content,
      likesCount: likesCount,
      deletedAt: deletedAt,
      statusCreatedAt: statusCreatedAt,
      statusUpdatedAt: statusUpdatedAt,
      statusUserFirstName: statusUserFirstName,
      statusUserLastName: statusUserLastName,
      statusUserProfilePic: statusUserProfilePic,

      emojiUpdateId: emojiUpdateId,
      emojiUpdateUserId: emojiUpdateUserId,
      currentEmoji: currentEmoji,
      emojiCaption: emojiCaption,
      emojiDeletedAt: emojiDeletedAt,
      emojiCreatedAt: emojiCreatedAt,
      emojiUpdatedAt: emojiUpdatedAt,
    );
  }

  @override
  String toString() => jsonEncode(toJson());
}
