import 'package:socket_io_client/socket_io_client.dart' as io;

import '../socket_constants/socket_event_names.dart';

class DeleteEventsHandler {
  const DeleteEventsHandler();

  void register({
    required io.Socket socket,
    void Function(Map<String, dynamic> payload)? onMessageDeleted,
    required void Function(String error) onDeleteMessageError,
  }) {
    if (onMessageDeleted != null) {
      socket.on(SocketEventNames.messageDeleted, (data) {
        try {
          final payload = data is Map
              ? Map<String, dynamic>.from(data)
              : <String, dynamic>{};
          onMessageDeleted(payload);
        } catch (_) {
          onMessageDeleted(<String, dynamic>{});
        }
      });
    }

    socket.on(SocketEventNames.deleteMessageError, (data) {
      try {
        final payload = data is Map
            ? Map<String, dynamic>.from(data)
            : <String, dynamic>{};
        final error = payload['error']?.toString();
        onDeleteMessageError(
          (error != null && error.trim().isNotEmpty)
              ? error.trim()
              : 'Failed to delete message',
        );
      } catch (_) {
        onDeleteMessageError('Failed to delete message');
      }
    });
  }
}
