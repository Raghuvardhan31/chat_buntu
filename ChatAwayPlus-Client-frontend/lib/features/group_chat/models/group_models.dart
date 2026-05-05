// Group Chat Data Models for ChatAway+

// ─────────────────────────────────────────────────────────────────────────────
// GROUP MODEL
// ─────────────────────────────────────────────────────────────────────────────
class GroupModel {
  final String id;
  final String name;
  final String? icon;
  final String createdBy;
  final String? description;
  final bool isRestricted;
  final bool isDeleted;
  final DateTime createdAt;
  final List<GroupMemberModel> members;
  final int memberCount;
  final GroupLastMessage? lastMessage;
  final String? myRole; // 'admin' or 'member'
  final int unreadCount;

  const GroupModel({
    required this.id,
    required this.name,
    this.icon,
    required this.createdBy,
    this.description,
    this.isRestricted = false,
    this.isDeleted = false,
    required this.createdAt,
    this.members = const [],
    this.memberCount = 0,
    this.lastMessage,
    this.myRole,
    this.unreadCount = 0,
  });

  bool get isAdmin => myRole == 'admin';

  factory GroupModel.fromJson(Map<String, dynamic> json) {
    return GroupModel(
      id: json['id'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String?,
      createdBy: json['createdBy'] as String? ?? '',
      description: json['description'] as String?,
      isRestricted: json['isRestricted'] == true || json['isRestricted'] == 1 || json['isRestricted'] == '1',
      isDeleted: json['isDeleted'] == true || json['isDeleted'] == 1 || json['isDeleted'] == '1',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      members: (json['members'] as List<dynamic>?)
              ?.map((m) => GroupMemberModel.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
      memberCount: json['memberCount'] as int? ?? 0,
      lastMessage: json['lastMessage'] != null
          ? GroupLastMessage.fromJson(json['lastMessage'] as Map<String, dynamic>)
          : null,
      myRole: json['role'] as String?,
      unreadCount: json['unreadCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': icon,
        'createdBy': createdBy,
        'description': description,
        'isRestricted': isRestricted,
        'isDeleted': isDeleted,
        'createdAt': createdAt.toIso8601String(),
        'memberCount': memberCount,
        'role': myRole,
      };

  GroupModel copyWith({
    String? name,
    String? icon,
    String? description,
    bool? isRestricted,
    List<GroupMemberModel>? members,
    int? memberCount,
    GroupLastMessage? lastMessage,
    String? myRole,
    int? unreadCount,
  }) {
    return GroupModel(
      id: id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      createdBy: createdBy,
      description: description ?? this.description,
      isRestricted: isRestricted ?? this.isRestricted,
      isDeleted: isDeleted,
      createdAt: createdAt,
      members: members ?? this.members,
      memberCount: memberCount ?? this.memberCount,
      lastMessage: lastMessage ?? this.lastMessage,
      myRole: myRole ?? this.myRole,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GROUP MEMBER MODEL
// ─────────────────────────────────────────────────────────────────────────────
class GroupMemberModel {
  final String id;
  final String groupId;
  final String userId;
  final String role; // 'admin' | 'member'
  final GroupMemberUser? user;

  const GroupMemberModel({
    required this.id,
    required this.groupId,
    required this.userId,
    required this.role,
    this.user,
  });

  bool get isAdmin => role == 'admin';

  factory GroupMemberModel.fromJson(Map<String, dynamic> json) {
    return GroupMemberModel(
      id: json['id'] as String? ?? '',
      groupId: json['groupId'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      role: json['role'] as String? ?? 'member',
      user: json['user'] != null
          ? GroupMemberUser.fromJson(json['user'] as Map<String, dynamic>)
          : null,
    );
  }
}

class GroupMemberUser {
  final String id;
  final String firstName;
  final String lastName;
  final String? mobileNo;
  final String? chatPicture;

  const GroupMemberUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.mobileNo,
    this.chatPicture,
  });

  String get displayName => '$firstName $lastName'.trim();

  factory GroupMemberUser.fromJson(Map<String, dynamic> json) {
    return GroupMemberUser(
      id: json['id'] as String? ?? '',
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      mobileNo: json['mobileNo'] as String?,
      chatPicture: json['chat_picture'] as String?,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GROUP LAST MESSAGE (for chat list preview)
// ─────────────────────────────────────────────────────────────────────────────
class GroupLastMessage {
  final String id;
  final String? message;
  final String messageType;
  final String senderId;
  final String senderName;
  final DateTime createdAt;

  const GroupLastMessage({
    required this.id,
    this.message,
    required this.messageType,
    required this.senderId,
    required this.senderName,
    required this.createdAt,
  });

  factory GroupLastMessage.fromJson(Map<String, dynamic> json) {
    return GroupLastMessage(
      id: json['id'] as String? ?? '',
      message: json['message'] as String?,
      messageType: json['messageType'] as String? ?? 'text',
      senderId: json['senderId'] as String? ?? '',
      senderName: json['senderName'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String get previewText {
    if (message != null && message!.isNotEmpty) return message!;
    switch (messageType) {
      case 'image':
        return '📷 Photo';
      case 'video':
        return '🎥 Video';
      case 'audio':
        return '🎤 Voice message';
      case 'pdf':
        return '📄 Document';
      case 'contact':
        return '👤 Contact';
      case 'poll':
        return '📊 Poll';
      default:
        return 'New message';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GROUP MESSAGE MODEL
// ─────────────────────────────────────────────────────────────────────────────
class GroupMessageModel {
  final String id;
  final String groupId;
  final String senderId;
  final String senderName;
  final String? senderAvatar;
  final String? message;
  final String messageType;
  final String? fileUrl;
  final String? mimeType;
  final Map<String, dynamic>? pollPayload;
  final List<Map<String, dynamic>>? contactPayload;
  final double? audioDuration;
  final String? videoThumbnailUrl;
  final double? videoDuration;
  final int? imageWidth;
  final int? imageHeight;
  final String? replyToMessageId;
  final String? replyToMessageText;
  final String? replyToMessageSenderId;
  final String? replyToMessageType;
  final String messageStatus;
  final bool isRead;
  final DateTime? deliveredAt;
  final DateTime? readAt;
  final bool isDeleted;
  final DateTime createdAt;
  final String? clientMessageId;
  final Map<String, String> statusPerUser;

  const GroupMessageModel({
    required this.id,
    required this.groupId,
    required this.senderId,
    required this.senderName,
    this.senderAvatar,
    this.message,
    required this.messageType,
    this.fileUrl,
    this.mimeType,
    this.pollPayload,
    this.contactPayload,
    this.audioDuration,
    this.videoThumbnailUrl,
    this.videoDuration,
    this.imageWidth,
    this.imageHeight,
    this.replyToMessageId,
    this.replyToMessageText,
    this.replyToMessageSenderId,
    this.messageStatus = 'sent',
    this.isRead = false,
    this.deliveredAt,
    this.readAt,
    this.isDeleted = false,
    required this.createdAt,
    this.clientMessageId,
    this.statusPerUser = const {},
    this.replyToMessageType,
  });

  bool isMine(String currentUserId) => senderId == currentUserId;

  factory GroupMessageModel.fromJson(Map<String, dynamic> json) {
    // Support both socket payload and REST response shapes
    final senderJson = json['sender'] as Map<String, dynamic>?;
    final String senderName = json['senderName'] as String? ??
        (senderJson != null
            ? '${senderJson['firstName'] ?? ''} ${senderJson['lastName'] ?? ''}'.trim()
            : '');

    return GroupMessageModel(
      id: json['id'] as String? ?? '',
      groupId: json['groupId'] as String? ?? '',
      senderId: json['senderId'] as String? ?? '',
      senderName: senderName,
      senderAvatar: json['senderAvatar'] as String? ?? senderJson?['chat_picture'] as String?,
      message: json['message'] as String?,
      messageType: json['messageType'] as String? ?? 'text',
      fileUrl: json['fileUrl'] as String?,
      mimeType: json['mimeType'] as String?,
      pollPayload: json['pollPayload'] as Map<String, dynamic>?,
      contactPayload: (json['contactPayload'] as List<dynamic>?)
          ?.map((e) => e as Map<String, dynamic>)
          .toList(),
      audioDuration: (json['audioDuration'] as num?)?.toDouble(),
      videoThumbnailUrl: json['videoThumbnailUrl'] as String?,
      videoDuration: (json['videoDuration'] as num?)?.toDouble(),
      imageWidth: json['imageWidth'] as int?,
      imageHeight: json['imageHeight'] as int?,
      replyToMessageId: json['replyToMessageId'] as String?,
      replyToMessageText: json['replyToMessageText'] as String?,
      replyToMessageSenderId: json['replyToMessageSenderId'] as String?,
      replyToMessageType: json['replyToMessageType'] as String?,
      messageStatus: json['messageStatus'] as String? ?? 'sent',
      isRead: json['isRead'] == true || json['isRead'] == 1 || json['isRead'] == '1',
      deliveredAt: json['deliveredAt'] != null ? DateTime.tryParse(json['deliveredAt'] as String) : null,
      readAt: json['readAt'] != null ? DateTime.tryParse(json['readAt'] as String) : null,
      isDeleted: json['isDeleted'] == true || json['isDeleted'] == 1 || json['isDeleted'] == '1',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      clientMessageId: json['clientMessageId'] as String?,
      statusPerUser: (json['statusPerUser'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v as String),
          ) ??
          {},
    );
  }

  GroupMessageModel copyWith({
    String? id,
    String? groupId,
    String? senderId,
    String? senderName,
    String? senderAvatar,
    String? message,
    String? messageType,
    String? fileUrl,
    String? mimeType,
    Map<String, dynamic>? pollPayload,
    List<Map<String, dynamic>>? contactPayload,
    double? audioDuration,
    String? videoThumbnailUrl,
    double? videoDuration,
    int? imageWidth,
    int? imageHeight,
    String? replyToMessageId,
    String? replyToMessageText,
    String? replyToMessageSenderId,
    String? replyToMessageType,
    String? messageStatus,
    bool? isRead,
    DateTime? deliveredAt,
    DateTime? readAt,
    bool? isDeleted,
    DateTime? createdAt,
    String? clientMessageId,
    Map<String, String>? statusPerUser,
  }) {
    return GroupMessageModel(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderAvatar: senderAvatar ?? this.senderAvatar,
      message: message ?? this.message,
      messageType: messageType ?? this.messageType,
      fileUrl: fileUrl ?? this.fileUrl,
      mimeType: mimeType ?? this.mimeType,
      pollPayload: pollPayload ?? this.pollPayload,
      contactPayload: contactPayload ?? this.contactPayload,
      audioDuration: audioDuration ?? this.audioDuration,
      videoThumbnailUrl: videoThumbnailUrl ?? this.videoThumbnailUrl,
      videoDuration: videoDuration ?? this.videoDuration,
      imageWidth: imageWidth ?? this.imageWidth,
      imageHeight: imageHeight ?? this.imageHeight,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      replyToMessageText: replyToMessageText ?? this.replyToMessageText,
      replyToMessageSenderId: replyToMessageSenderId ?? this.replyToMessageSenderId,
      replyToMessageType: replyToMessageType ?? this.replyToMessageType,
      messageStatus: messageStatus ?? this.messageStatus,
      isRead: isRead ?? this.isRead,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      readAt: readAt ?? this.readAt,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      clientMessageId: clientMessageId ?? this.clientMessageId,
      statusPerUser: statusPerUser ?? this.statusPerUser,
    );
  }

  String get previewText {
    if (message != null && message!.isNotEmpty) return message!;
    switch (messageType) {
      case 'image':
        return '📷 Photo';
      case 'video':
        return '🎥 Video';
      case 'audio':
        return '🎤 Voice message';
      case 'pdf':
        return '📄 Document';
      case 'contact':
        return '👤 Contact';
      case 'poll':
        return '📊 Poll';
      default:
        return 'New message';
    }
  }

  String getGlobalStatus(int totalMembersExcludingSender) {
    if (statusPerUser.isEmpty) return 'sent';
    final values = statusPerUser.values;
    if (values.every((s) => s == 'read')) return 'read';
    if (values.every((s) => s == 'delivered' || s == 'read')) return 'delivered';
    return 'sent';
  }

  int get readCount => statusPerUser.values.where((s) => s == 'read').length;

  List<String> get readUserIds => statusPerUser.entries
      .where((e) => e.value == 'read')
      .map((e) => e.key)
      .toList();

  Map<String, dynamic> toJson() => {
        'id': id,
        'groupId': groupId,
        'senderId': senderId,
        'senderName': senderName,
        'senderAvatar': senderAvatar,
        'message': message,
        'messageType': messageType,
        'fileUrl': fileUrl,
        'mimeType': mimeType,
        'pollPayload': pollPayload,
        'contactPayload': contactPayload,
        'audioDuration': audioDuration,
        'videoThumbnailUrl': videoThumbnailUrl,
        'videoDuration': videoDuration,
        'imageWidth': imageWidth,
        'imageHeight': imageHeight,
        'replyToMessageId': replyToMessageId,
        'replyToMessageText': replyToMessageText,
        'replyToMessageSenderId': replyToMessageSenderId,
        'replyToMessageType': replyToMessageType,
        'messageStatus': messageStatus,
        'isRead': isRead,
        'deliveredAt': deliveredAt?.toIso8601String(),
        'readAt': readAt?.toIso8601String(),
        'isDeleted': isDeleted,
        'createdAt': createdAt.toIso8601String(),
        'clientMessageId': clientMessageId,
        'statusPerUser': statusPerUser,
      };
}
