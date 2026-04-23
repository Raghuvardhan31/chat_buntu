import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../socket_constants/socket_event_names.dart';

class StarMessageEventsHandler {
  const StarMessageEventsHandler();

  void register({
    required io.Socket socket,
    required void Function(Map<String, dynamic> payload) onMessageStarred,
    required void Function(Map<String, dynamic> payload) onMessageUnstarred,
    required void Function(String error) onStarMessageError,
    required void Function(String error) onUnstarMessageError,
  }) {
    socket.on(SocketEventNames.messageStarred, (data) {
      try {
        final payload = data is Map
            ? Map<String, dynamic>.from(data)
            : <String, dynamic>{};
        onMessageStarred(payload);
      } catch (e) {
        debugPrint('❌ StarMessageEventsHandler parsing message-starred: $e');
      }
    });

    socket.on(SocketEventNames.starMessageError, (data) {
      try {
        final errorMessage = data is Map
            ? (data['error']?.toString() ?? 'Failed to star message')
            : data?.toString() ?? 'Failed to star message';
        onStarMessageError(errorMessage);
      } catch (e) {
        debugPrint('❌ StarMessageEventsHandler parsing star-message-error: $e');
        onStarMessageError('Failed to star message');
      }
    });

    socket.on(SocketEventNames.messageUnstarred, (data) {
      try {
        final payload = data is Map
            ? Map<String, dynamic>.from(data)
            : <String, dynamic>{};
        onMessageUnstarred(payload);
      } catch (e) {
        debugPrint('❌ StarMessageEventsHandler parsing message-unstarred: $e');
      }
    });

    socket.on(SocketEventNames.unstarMessageError, (data) {
      try {
        final errorMessage = data is Map
            ? (data['error']?.toString() ?? 'Failed to unstar message')
            : data?.toString() ?? 'Failed to unstar message';
        onUnstarMessageError(errorMessage);
      } catch (e) {
        debugPrint(
          '❌ StarMessageEventsHandler parsing unstar-message-error: $e',
        );
        onUnstarMessageError('Failed to unstar message');
      }
    });
  }
}
