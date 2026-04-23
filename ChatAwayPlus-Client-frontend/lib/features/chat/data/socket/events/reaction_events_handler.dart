import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../socket_constants/socket_event_names.dart';

class ReactionEventsHandler {
  const ReactionEventsHandler();

  void register({
    required io.Socket socket,
    required void Function(Map<String, dynamic>) onReactionUpdated,
    required void Function(String) onReactionError,
  }) {
    void handleReaction(dynamic data, {required String source}) {
      debugPrint('👍 $source: $data');
      try {
        final payload = data is Map
            ? Map<String, dynamic>.from(data)
            : <String, dynamic>{};
        onReactionUpdated(payload);
      } catch (e) {
        debugPrint('❌ ReactionEventsHandler parsing $source: $e');
      }
    }

    socket.on(SocketEventNames.reactionUpdated, (data) {
      handleReaction(data, source: SocketEventNames.reactionUpdated);
    });

    socket.on(SocketEventNames.reactionError, (data) {
      debugPrint('❌ reaction-error: $data');
      try {
        final errorMessage = data is Map
            ? (data['error']?.toString() ?? 'Failed to process reaction')
            : data?.toString() ?? 'Failed to process reaction';
        onReactionError(errorMessage);
      } catch (e) {
        debugPrint('❌ ReactionEventsHandler parsing reaction-error: $e');
      }
    });

    socket.on(SocketEventNames.messageReactions, (data) {
      debugPrint('📋 message-reactions: $data');
      try {
        final payload = data is Map
            ? Map<String, dynamic>.from(data)
            : <String, dynamic>{};
        onReactionUpdated(payload);
      } catch (e) {
        debugPrint('❌ ReactionEventsHandler parsing message-reactions: $e');
      }
    });
  }
}
