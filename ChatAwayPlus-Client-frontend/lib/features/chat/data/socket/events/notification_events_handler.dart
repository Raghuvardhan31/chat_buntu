import 'package:socket_io_client/socket_io_client.dart' as io;

import '../socket_constants/socket_event_names.dart';

class NotificationEventsHandler {
  const NotificationEventsHandler();

  void register({
    required io.Socket socket,
    required void Function(Map<String, dynamic> payload) onNotification,
  }) {
    socket.on(SocketEventNames.notification, (data) {
      final payload = data is Map
          ? Map<String, dynamic>.from(data)
          : <String, dynamic>{};
      onNotification(payload);
    });

    socket.on(SocketEventNames.newNotification, (data) {
      final payload = data is Map
          ? Map<String, dynamic>.from(data)
          : <String, dynamic>{};
      onNotification(payload);
    });
  }
}
