import 'dart:convert';
import 'package:chataway_plus/features/chat/models/chat_message_model.dart';

class NotificationModel {
  final String id;
  final String senderId;
  final String receiverId;
  final String message;
  final String type;
  final bool isRead;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final ChatUserModel? sender;

  NotificationModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.message,
    required this.type,
    required this.isRead,
    this.metadata,
    required this.createdAt,
    this.sender,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? metadataMap;
    if (json['metadata'] != null) {
      if (json['metadata'] is String) {
        try {
          metadataMap = jsonDecode(json['metadata']);
        } catch (_) {}
      } else if (json['metadata'] is Map) {
        metadataMap = Map<String, dynamic>.from(json['metadata']);
      }
    }

    return NotificationModel(
      id: json['id']?.toString() ?? '',
      senderId: json['senderId']?.toString() ?? '',
      receiverId: json['receiverId']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      isRead: json['isRead'] == true || json['isRead'] == 1,
      metadata: metadataMap,
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : DateTime.now(),
      sender: json['senderUser'] != null 
          ? ChatUserModel.fromJson(json['senderUser'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderId': senderId,
      'receiverId': receiverId,
      'message': message,
      'type': type,
      'isRead': isRead,
      'metadata': metadata,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
