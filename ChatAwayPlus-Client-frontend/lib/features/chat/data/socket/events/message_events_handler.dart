import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../../models/chat_message_model.dart';
import '../socket_constants/socket_event_names.dart';

class MessageEventsHandler {
  const MessageEventsHandler();

  static const bool _verboseLogs = false;

  void register({
    required io.Socket socket,
    required void Function(ChatMessageModel message) onIncomingMessage,
    required void Function(ChatMessageModel message) onMessageSent,
    required void Function(String error) onMessageError,
    void Function(Map<String, dynamic> payload)? onMessageEdited,
    void Function(String error)? onEditMessageError,
    void Function(String messageId)? onMessageDeleted,
    void Function(dynamic data)? onAckAcknowledged,
    void Function(dynamic data)? onAckError,
  }) {
    socket.on(SocketEventNames.newMessage, (data) {
      if (_verboseLogs && kDebugMode) {
        debugPrint('🎯 NEW-MESSAGE EVENT FIRED!');
        debugPrint('📨 ChatRepository: New message received: $data');
        debugPrint('📨 Data type: ${data.runtimeType}');
      }
      try {
        final message = ChatMessageModel.fromSocketResponse(data);
        if (_verboseLogs && kDebugMode) {
          debugPrint('✅ Message parsed successfully: ${message.message}');
        }
        onIncomingMessage(message);
        if (_verboseLogs && kDebugMode) {
          debugPrint('✅ onNewMessage callback called');
        }
      } catch (e) {
        debugPrint('❌ Error parsing new message: $e');
      }
    });

    socket.on(SocketEventNames.messageSent, (data) {
      if (kDebugMode) {
        debugPrint('✅ [Socket] message-sent raw: $data');
        // Extra debug for poll messages
        if (data is Map) {
          debugPrint(
            '📊 message-sent details: messageType=${data['messageType']}, '
            'message="${data['message']}", pollPayload=${data['pollPayload']}',
          );
        }
      }
      try {
        final message = ChatMessageModel.fromSentConfirmation(data);
        if (_verboseLogs && kDebugMode) {
          debugPrint(
            '✅ Sent confirmed: ${message.id.substring(0, 8)}... '
            'type=${message.messageType}, msg=${message.message.length > 50 ? message.message.substring(0, 50) : message.message}',
          );
        }
        onMessageSent(message);
      } catch (e) {
        debugPrint('❌ Message-sent parse error: $e');
      }
    });

    socket.on(SocketEventNames.messageError, (data) {
      if (_verboseLogs && kDebugMode) {
        debugPrint('🎯 MESSAGE-ERROR EVENT FIRED!');
      }
      debugPrint('❌ ChatRepository: Message error: $data');
      try {
        final map = data is Map ? Map<String, dynamic>.from(data) : null;
        final error = map?['error']?.toString() ?? 'Failed to send message';
        onMessageError(error);
      } catch (_) {
        onMessageError('Failed to send message');
      }
    });

    socket.on(SocketEventNames.messageEdited, (data) {
      try {
        final payload = data is Map
            ? Map<String, dynamic>.from(data)
            : <String, dynamic>{};
        onMessageEdited?.call(payload);
      } catch (e) {
        debugPrint('❌ message-edited parse error: $e');
      }
    });

    socket.on(SocketEventNames.editMessageError, (data) {
      if (_verboseLogs && kDebugMode) {
        debugPrint('🎯 EDIT-MESSAGE-ERROR EVENT FIRED!');
      }
      debugPrint('❌ ChatRepository: Edit message error: $data');
      try {
        final error = (data is Map && data['error'] != null)
            ? data['error'].toString()
            : 'Edit message failed';
        onEditMessageError?.call(error);
      } catch (_) {
        onEditMessageError?.call('Edit message failed');
      }
    });

    if (onMessageDeleted != null) {
      socket.on(SocketEventNames.messageDeleted, (data) {
        if (_verboseLogs && kDebugMode) {
          debugPrint('🗑️ Message deleted: $data');
        }

        try {
          final payload = data is Map
              ? Map<String, dynamic>.from(data)
              : <String, dynamic>{};

          final messageId =
              (payload['messageId'] ?? payload['id'] ?? payload['chatId'])
                  ?.toString();

          if (messageId == null || messageId.isEmpty) {
            if (_verboseLogs && kDebugMode) {
              debugPrint('🗑️ message-deleted missing messageId, ignoring');
            }
            return;
          }

          onMessageDeleted(messageId);
        } catch (e) {
          debugPrint('❌ Error handling message-deleted: $e');
        }
      });
    }

    socket.on(SocketEventNames.ackAcknowledged, (data) {
      if (_verboseLogs && kDebugMode) {
        debugPrint('✅ Message ack confirmed by server: $data');
      }
      onAckAcknowledged?.call(data);
    });

    socket.on(SocketEventNames.ackError, (data) {
      debugPrint('❌ Message ack error: $data');
      onAckError?.call(data);
    });
  }
}
