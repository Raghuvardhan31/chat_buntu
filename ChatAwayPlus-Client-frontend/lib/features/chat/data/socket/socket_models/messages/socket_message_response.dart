import 'dart:convert';

/// Socket message response model
class SocketMessageResponse {
  final String id;
  final String senderId;
  final String receiverId;
  final String message;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String messageStatus;
  final bool isRead;
  final DateTime? deliveredAt;
  final DateTime? readAt;
  final String deliveryChannel;
  final String? receiverDeliveryChannel;

  // Media fields
  final String messageType;
  final String? fileUrl;
  final String? mimeType;
  final String? fileName;
  final int? fileSize;
  final Map<String, dynamic>? fileMetadata;

  // Advanced fields
  final String? reactionsJson;
  final bool isStarred;
  final bool isEdited;
  final DateTime? editedAt;

  // User objects
  final Map<String, dynamic>? sender;
  final Map<String, dynamic>? receiver;

  SocketMessageResponse({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.message,
    required this.createdAt,
    DateTime? updatedAt,
    this.messageStatus = 'sent',
    this.isRead = false,
    this.deliveredAt,
    this.readAt,
    this.deliveryChannel = 'socket',
    this.receiverDeliveryChannel,
    this.messageType = 'text',
    this.fileUrl,
    this.mimeType,
    this.fileName,
    this.fileSize,
    this.fileMetadata,
    this.reactionsJson,
    this.isStarred = false,
    this.isEdited = false,
    this.editedAt,
    this.sender,
    this.receiver,
  }) : updatedAt = updatedAt ?? createdAt;

  static bool _tryParseBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) return value == 1;
    final s = value.toString().toLowerCase();
    return s == 'true' || s == '1';
  }

  static DateTime _tryParseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return DateTime.tryParse(value.toString()) ?? DateTime.now();
  }

  factory SocketMessageResponse.fromJson(Map<String, dynamic> json) {
    final fileMetadataRaw = json['fileMetadata'];
    Map<String, dynamic>? fileMetadata;
    if (fileMetadataRaw != null) {
      if (fileMetadataRaw is Map) {
        fileMetadata = Map<String, dynamic>.from(fileMetadataRaw);
      } else if (fileMetadataRaw is String) {
        try {
          final decoded = jsonDecode(fileMetadataRaw);
          if (decoded is Map) {
            fileMetadata = Map<String, dynamic>.from(decoded);
          }
        } catch (_) {}
      }
    }

    final reactionsRaw = json['reactionsJson'] ?? json['reactions'];
    final reactionsJson = reactionsRaw == null
        ? null
        : (reactionsRaw is String ? reactionsRaw : jsonEncode(reactionsRaw));

    return SocketMessageResponse(
      id:
          json['id'] as String? ??
          json['messageId'] as String? ??
          json['chatId'] as String? ??
          '',
      senderId: json['senderId'] as String? ?? '',
      receiverId: json['receiverId'] as String? ?? '',
      message:
          (json['message'] ?? json['messageText'] ?? json['body'])
              ?.toString() ??
          '',
      createdAt: _tryParseDateTime(json['createdAt']),
      updatedAt: _tryParseDateTime(json['updatedAt']),
      messageStatus:
          json['messageStatus'] as String? ??
          json['status'] as String? ??
          'sent',
      isRead: _tryParseBool(json['isRead']),
      deliveredAt: _tryParseDateTime(json['deliveredAt']),
      readAt: _tryParseDateTime(json['readAt']),
      deliveryChannel: json['deliveryChannel'] as String? ?? 'socket',
      receiverDeliveryChannel: json['receiverDeliveryChannel'] as String?,
      messageType: json['messageType'] as String? ?? 'text',
      fileUrl: (json['fileUrl'] ?? json['imageUrl'])?.toString(),
      mimeType: json['mimeType'] as String?,
      fileName:
          json['fileName'] as String? ?? fileMetadata?['fileName']?.toString(),
      fileSize: _tryParseInt(json['fileSize'] ?? fileMetadata?['fileSize']),
      fileMetadata: fileMetadata,
      reactionsJson: reactionsJson,
      isStarred: _tryParseBool(json['isStarred'] ?? json['starred']),
      isEdited: _tryParseBool(json['isEdited']),
      editedAt: _tryParseDateTime(json['editedAt']),
      sender: json['sender'] is Map
          ? Map<String, dynamic>.from(json['sender'])
          : null,
      receiver: json['receiver'] is Map
          ? Map<String, dynamic>.from(json['receiver'])
          : null,
    );
  }

  static int? _tryParseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderId': senderId,
      'receiverId': receiverId,
      'message': message,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'messageStatus': messageStatus,
      'isRead': isRead,
      'deliveredAt': deliveredAt?.toIso8601String(),
      'readAt': readAt?.toIso8601String(),
      'deliveryChannel': deliveryChannel,
      'receiverDeliveryChannel': receiverDeliveryChannel,
      'messageType': messageType,
      'fileUrl': fileUrl,
      'mimeType': mimeType,
      'fileName': fileName,
      'fileSize': fileSize,
      'fileMetadata': fileMetadata,
      'reactionsJson': reactionsJson,
      'isStarred': isStarred,
      'isEdited': isEdited,
      'editedAt': editedAt?.toIso8601String(),
      'sender': sender,
      'receiver': receiver,
    };
  }
}
