import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../socket_constants/socket_event_names.dart';

class StarMessageEmitter {
  const StarMessageEmitter();

  bool star({required io.Socket socket, required String chatId}) {
    try {
      final payload = <String, dynamic>{'chatId': chatId};
      socket.emit(SocketEventNames.starMessage, payload);
      return true;
    } catch (e) {
      debugPrint('❌ StarMessageEmitter.star failed: $e');
      return false;
    }
  }

  bool unstar({required io.Socket socket, required String chatId}) {
    try {
      final payload = <String, dynamic>{'chatId': chatId};
      socket.emit(SocketEventNames.unstarMessage, payload);
      return true;
    } catch (e) {
      debugPrint('❌ StarMessageEmitter.unstar failed: $e');
      return false;
    }
  }
}
