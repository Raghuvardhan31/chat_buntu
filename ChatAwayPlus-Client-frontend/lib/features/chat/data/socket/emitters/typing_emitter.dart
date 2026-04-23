import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../socket_constants/socket_event_names.dart';

class TypingEmitter {
  const TypingEmitter();

  bool sendTyping({
    required io.Socket socket,
    required String senderId,
    required String receiverId,
    required bool isTyping,
  }) {
    try {
      final payload = <String, dynamic>{
        'senderId': senderId,
        'receiverId': receiverId,
        'isTyping': isTyping,
      };
      socket.emit(SocketEventNames.typing, payload);
      return true;
    } catch (e) {
      debugPrint('❌ TypingEmitter.sendTyping failed: $e');
      return false;
    }
  }
}
