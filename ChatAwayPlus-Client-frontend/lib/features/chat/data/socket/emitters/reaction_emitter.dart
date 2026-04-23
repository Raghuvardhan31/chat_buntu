import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../socket_constants/socket_event_names.dart';

class ReactionEmitter {
  const ReactionEmitter();

  bool addReaction({
    required io.Socket socket,
    required String messageId,
    required String emoji,
  }) {
    try {
      final payload = <String, dynamic>{'messageId': messageId, 'emoji': emoji};
      socket.emit(SocketEventNames.addReaction, payload);
      return true;
    } catch (e) {
      debugPrint('❌ ReactionEmitter.addReaction failed: $e');
      return false;
    }
  }

  bool removeReaction({required io.Socket socket, required String messageId}) {
    try {
      final payload = <String, dynamic>{'messageId': messageId};
      socket.emit(SocketEventNames.removeReaction, payload);
      return true;
    } catch (e) {
      debugPrint('❌ ReactionEmitter.removeReaction failed: $e');
      return false;
    }
  }

  bool getMessageReactions({
    required io.Socket socket,
    required String messageId,
  }) {
    try {
      final payload = <String, dynamic>{'messageId': messageId};
      socket.emit(SocketEventNames.getMessageReactions, payload);
      return true;
    } catch (e) {
      debugPrint('❌ ReactionEmitter.getMessageReactions failed: $e');
      return false;
    }
  }
}
