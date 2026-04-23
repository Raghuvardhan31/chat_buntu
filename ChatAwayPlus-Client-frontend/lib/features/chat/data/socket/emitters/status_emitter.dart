import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../socket_constants/socket_event_names.dart';

class StatusEmitter {
  const StatusEmitter();

  static const bool _verboseLogs = false;

  bool requestUserStatus({required io.Socket socket, required String userId}) {
    try {
      socket.emit(SocketEventNames.getUserStatus, {'userId': userId});
      return true;
    } catch (e) {
      debugPrint('❌ StatusEmitter.requestUserStatus failed: $e');
      return false;
    }
  }

  bool setUserPresence({
    required io.Socket socket,
    required String userId,
    required bool isOnline,
  }) {
    try {
      final payload = <String, dynamic>{
        'userId': userId,
        'isOnline': isOnline,
        'timestamp': DateTime.now().toIso8601String(),
      };
      socket.emit(SocketEventNames.setUserPresence, payload);
      if (kDebugMode) {
        debugPrint('📤 [Presence] Set to ${isOnline ? "ONLINE" : "OFFLINE"}');
      }
      return true;
    } catch (e) {
      debugPrint('❌ StatusEmitter.setUserPresence failed: $e');
      return false;
    }
  }

  bool updateMessageStatusBatch({
    required io.Socket socket,
    required List<String> messageIds,
    required String status,
    String receiverDeliveryChannel = 'socket',
  }) {
    try {
      final payload = <String, dynamic>{
        'chatIds': messageIds,
        'status': status,
        'receiverDeliveryChannel': receiverDeliveryChannel,
      };
      socket.emit(SocketEventNames.updateMessageStatus, payload);
      return true;
    } catch (e) {
      debugPrint('❌ StatusEmitter.updateMessageStatusBatch failed: $e');
      return false;
    }
  }

  bool updateMessageStatusWithAck({
    required io.Socket socket,
    required String messageId,
    required String status,
    required bool isAuthenticated,
    String receiverDeliveryChannel = 'socket',
  }) {
    try {
      if (_verboseLogs && kDebugMode) {
        debugPrint('');
        debugPrint(
          '🚀 ═══════════════════════════════════════════════════════',
        );
        debugPrint('📤 SENDING STATUS UPDATE TO SERVER');
        debugPrint(
          '🚀 ═══════════════════════════════════════════════════════',
        );
        debugPrint('📧 Message ID: $messageId');
        debugPrint('📊 New Status: $status');
        debugPrint('⏰ Timestamp: ${DateTime.now().toIso8601String()}');
        debugPrint('🔌 Socket Connected: ${socket.connected}');
        debugPrint('🔐 Socket Authenticated: $isAuthenticated');
        debugPrint('🔌 Socket ID: ${socket.id}');
        debugPrint(
          '🚀 ═══════════════════════════════════════════════════════',
        );
      }

      final statusUpdate = {
        'chatIds': [messageId],
        'status': status,
        'receiverDeliveryChannel': receiverDeliveryChannel,
      };

      if (_verboseLogs && kDebugMode) {
        debugPrint(
          '📤 Emitting event: ${SocketEventNames.updateMessageStatus}',
        );
        debugPrint('📦 Payload: $statusUpdate');
      }

      socket.emitWithAck(
        SocketEventNames.updateMessageStatus,
        statusUpdate,
        ack: (ackData) {
          if (_verboseLogs && kDebugMode) {
            debugPrint('');
            debugPrint(
              '✅ ═══════════════════════════════════════════════════════',
            );
            debugPrint('✅ BACKEND ACKNOWLEDGED STATUS UPDATE');
            debugPrint(
              '✅ ═══════════════════════════════════════════════════════',
            );
            debugPrint('📧 Message ID: $messageId');
            debugPrint('📊 Status: $status');
            debugPrint('📨 Backend response: $ackData');
            debugPrint(
              '✅ ═══════════════════════════════════════════════════════',
            );
            debugPrint('');
          }
        },
      );

      if (_verboseLogs && kDebugMode) {
        debugPrint('✅ Status update emitted successfully via socket');
        debugPrint(
          '🚀 ═══════════════════════════════════════════════════════',
        );
        debugPrint('');
      }

      return true;
    } catch (e) {
      debugPrint('❌ StatusEmitter.updateMessageStatusWithAck failed: $e');
      return false;
    }
  }
}
