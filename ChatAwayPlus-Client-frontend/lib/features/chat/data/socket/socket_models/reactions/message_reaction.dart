import 'message_reaction_user.dart';

/// Message reaction model
class MessageReaction {
  final String id;
  final String messageId;
  final String userId;
  final String emoji;
  final DateTime createdAt;
  final MessageReactionUser? user;

  // Local database fields
  final String? userFirstName;
  final String? userLastName;
  final String? userChatPicture;
  final bool isSynced;

  MessageReaction({
    required this.id,
    required this.messageId,
    required this.userId,
    required this.emoji,
    required this.createdAt,
    this.user,
    this.userFirstName,
    this.userLastName,
    this.userChatPicture,
    this.isSynced = true,
  });

  factory MessageReaction.fromJson(Map<String, dynamic> json) {
    final createdAt = json['createdAt'];
    DateTime parsedDate = DateTime.now();
    if (createdAt is String) {
      parsedDate = DateTime.tryParse(createdAt) ?? DateTime.now();
    } else if (createdAt is DateTime) {
      parsedDate = createdAt;
    }

    final userData = json['user'];
    MessageReactionUser? user;
    if (userData != null && userData is Map) {
      user = MessageReactionUser.fromJson(Map<String, dynamic>.from(userData));
    }

    return MessageReaction(
      id: json['id']?.toString() ?? '',
      messageId: json['messageId']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      emoji: json['emoji']?.toString() ?? '',
      createdAt: parsedDate,
      user: user,
      userFirstName: json['userFirstName']?.toString() ?? user?.firstName,
      userLastName: json['userLastName']?.toString() ?? user?.lastName,
      userChatPicture: json['userChatPicture']?.toString() ?? user?.chatPicture,
      isSynced: json['isSynced'] == 1 || json['isSynced'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'messageId': messageId,
      'userId': userId,
      'emoji': emoji,
      'createdAt': createdAt.toIso8601String(),
      'user': user?.toJson(),
      'userFirstName': userFirstName,
      'userLastName': userLastName,
      'userChatPicture': userChatPicture,
      'isSynced': isSynced ? 1 : 0,
    };
  }

  Map<String, dynamic> toDatabaseMap() {
    return {
      'id': id,
      'message_id': messageId,
      'user_id': userId,
      'emoji': emoji,
      'created_at': createdAt.toIso8601String(),
      'user_first_name': userFirstName ?? user?.firstName,
      'user_last_name': userLastName ?? user?.lastName,
      'user_chat_picture': userChatPicture ?? user?.chatPicture,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  MessageReaction copyWith({
    String? id,
    String? messageId,
    String? userId,
    String? emoji,
    DateTime? createdAt,
    MessageReactionUser? user,
    String? userFirstName,
    String? userLastName,
    String? userChatPicture,
    bool? isSynced,
  }) {
    return MessageReaction(
      id: id ?? this.id,
      messageId: messageId ?? this.messageId,
      userId: userId ?? this.userId,
      emoji: emoji ?? this.emoji,
      createdAt: createdAt ?? this.createdAt,
      user: user ?? this.user,
      userFirstName: userFirstName ?? this.userFirstName,
      userLastName: userLastName ?? this.userLastName,
      userChatPicture: userChatPicture ?? this.userChatPicture,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
