import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../socket_constants/socket_event_names.dart';

class MessageEmitter {
  const MessageEmitter();

  bool sendPrivateMessage({
    required io.Socket socket,
    required String senderId,
    required String receiverId,
    required String message,
    required String messageType,
    String? clientMessageId,
    String? fileUrl,
    String? mimeType,
    int? imageWidth,
    int? imageHeight,
    Map<String, dynamic>? fileMetadata,
    bool? isFollowUp,
    double? audioDuration,
    String? videoThumbnailUrl,
    double? videoDuration,
    String? replyToMessageId,
  }) {
    try {
      final payload = <String, dynamic>{
        'senderId': senderId,
        'receiverId': receiverId,
        'message': message,
        'messageType': messageType,
        'fileUrl': fileUrl,
        'mimeType': mimeType,
        'fileMetadata': fileMetadata,
        if (clientMessageId != null) 'clientMessageId': clientMessageId,
        if (imageWidth != null) 'imageWidth': imageWidth,
        if (imageHeight != null) 'imageHeight': imageHeight,
        if (audioDuration != null) 'audioDuration': audioDuration,
        if (isFollowUp != null) 'isFollowUp': isFollowUp,
        if (videoThumbnailUrl != null) 'videoThumbnailUrl': videoThumbnailUrl,
        if (videoDuration != null) 'videoDuration': videoDuration,
        if (replyToMessageId != null) 'replyToMessageId': replyToMessageId,
      };

      if (kDebugMode) {
        debugPrint('📤 [MessageEmitter] Pre-emit validation:');
        debugPrint('   • Socket connected: ${socket.connected}');
        debugPrint('   • Socket ID: ${socket.id}');
        debugPrint('   • Event name: ${SocketEventNames.privateMessage}');
        debugPrint('   • Sender ID: $senderId');
        debugPrint('   • Receiver ID: $receiverId');
        debugPrint('   • Message: "$message" (length=${message.length})');
        debugPrint('   • Message type: $messageType');
        debugPrint('   • Client message ID: $clientMessageId');

        try {
          debugPrint(
            '📤 [MessageEmitter] Full payload: ${jsonEncode(payload)}',
          );
        } catch (_) {
          debugPrint('📤 [MessageEmitter] Full payload (raw): $payload');
        }
      }

      debugPrint(
        '🚀 [MessageEmitter] Emitting ${SocketEventNames.privateMessage} event to server...',
      );
      socket.emit(SocketEventNames.privateMessage, payload);
      debugPrint('✅ [MessageEmitter] Event emitted successfully');
      return true;
    } catch (e) {
      debugPrint('❌ MessageEmitter.sendPrivateMessage failed: $e');
      return false;
    }
  }

  bool sendMessageReceivedAck({
    required io.Socket socket,
    required String messageId,
    String? receiverDeliveryChannel,
  }) {
    try {
      final payload = <String, dynamic>{
        'chatId': messageId,
        'receiverDeliveryChannel': receiverDeliveryChannel ?? 'socket',
      };
      socket.emit(SocketEventNames.messageReceivedAck, payload);
      return true;
    } catch (e) {
      debugPrint('❌ MessageEmitter.sendMessageReceivedAck failed: $e');
      return false;
    }
  }

  bool enterChat({
    required io.Socket socket,
    required String userId,
    required String otherUserId,
  }) {
    try {
      socket.emit(SocketEventNames.enterChat, {
        'userId': userId,
        'otherUserId': otherUserId,
      });
      return true;
    } catch (e) {
      debugPrint('❌ MessageEmitter.enterChat failed: $e');
      return false;
    }
  }

  bool leaveChat({required io.Socket socket, required String userId}) {
    try {
      socket.emit(SocketEventNames.leaveChat, {'userId': userId});
      return true;
    } catch (e) {
      debugPrint('❌ MessageEmitter.leaveChat failed: $e');
      return false;
    }
  }
}
