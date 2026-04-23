import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../socket_constants/socket_event_names.dart';

class MessageStatusEventsHandler {
  const MessageStatusEventsHandler();

  static const bool _verboseLogs = true;

  void register({
    required io.Socket socket,
    required void Function(Map<String, dynamic> statusData) onStatusUpdate,
    void Function(String? error)? onStatusUpdateError,
    void Function(dynamic data)? onStatusUpdateAcknowledged,
  }) {
    socket.on(SocketEventNames.messageStatusUpdate, (data) {
      try {
        final statusData = data is Map
            ? Map<String, dynamic>.from(data)
            : <String, dynamic>{};

        final messageObject = statusData['messageObject'];
        final incomingId =
            (messageObject is Map
                ? (messageObject['id'] ??
                      messageObject['messageId'] ??
                      messageObject['message_id'] ??
                      messageObject['statusId'] ??
                      messageObject['status_id'] ??
                      messageObject['messageUuid'] ??
                      messageObject['message_uuid'] ??
                      messageObject['chatId'])
                : null) ??
            (statusData['messageId'] ??
                    statusData['message_id'] ??
                    statusData['statusId'] ??
                    statusData['status_id'] ??
                    statusData['messageUuid'] ??
                    statusData['message_uuid'] ??
                    statusData['id'] ??
                    statusData['chatId'])
                ?.toString();
        final shortId = (incomingId != null && incomingId.length >= 8)
            ? incomingId.substring(0, 8)
            : incomingId;
        if (_verboseLogs && kDebugMode) {
          debugPrint('📊 Status: $shortId... → ${statusData['status']}');
        }

        if (incomingId != null && incomingId.isNotEmpty) {
          statusData['messageId'] = incomingId;
        }

        onStatusUpdate(statusData);
      } catch (e) {
        debugPrint('❌ Status update error: $e');
      }
    });

    socket.on(SocketEventNames.statusUpdateError, (data) {
      final errorMsg = data is Map
          ? data['error']?.toString()
          : data?.toString();

      if (kDebugMode) {
        debugPrint('❌ Status update error: $errorMsg');
      }

      onStatusUpdateError?.call(errorMsg);
    });

    socket.on(SocketEventNames.statusUpdateAcknowledged, (data) {
      if (_verboseLogs && kDebugMode) {
        debugPrint('✅ Status update acknowledged: $data');
      }
      onStatusUpdateAcknowledged?.call(data);
    });
  }
}
