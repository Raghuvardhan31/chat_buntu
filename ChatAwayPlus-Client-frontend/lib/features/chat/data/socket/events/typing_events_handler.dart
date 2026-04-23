import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../socket_constants/socket_event_names.dart';

class TypingEventsHandler {
  const TypingEventsHandler();

  bool _parseBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) return value == 1;
    final s = value.toString().toLowerCase();
    return s == 'true' || s == '1';
  }

  void register({
    required io.Socket socket,
    required void Function(String userId, bool isTyping) onTyping,
  }) {
    socket.on(SocketEventNames.userTyping, (data) {
      try {
        final map = data is Map ? Map<String, dynamic>.from(data) : null;
        if (map == null) return;

        final userId = map['userId']?.toString() ?? '';
        final isTyping = _parseBool(map['isTyping']);
        if (userId.isEmpty) return;

        onTyping(userId, isTyping);
      } catch (e) {
        debugPrint('❌ TypingEventsHandler parsing user-typing: $e');
      }
    });
  }
}
