import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../socket_constants/socket_event_names.dart';

/// Emitter for status like WebSocket events (Share Your Voice Text likes)
class StatusLikeEmitter {
  const StatusLikeEmitter();

  /// Toggle like on a status
  bool toggle({required io.Socket socket, required String statusId}) {
    try {
      final payload = <String, dynamic>{'statusId': statusId};
      if (kDebugMode) {
        debugPrint('📤 [StatusLikeEmitter.toggle] payload=$payload');
      }
      socket.emit(SocketEventNames.toggleStatusLike, payload);
      return true;
    } catch (e) {
      debugPrint('❌ StatusLikeEmitter.toggle failed: $e');
      return false;
    }
  }

  /// Unlike a status
  bool unlike({required io.Socket socket, required String statusId}) {
    try {
      final payload = <String, dynamic>{'statusId': statusId};
      if (kDebugMode) {
        debugPrint('📤 [StatusLikeEmitter.unlike] payload=$payload');
      }
      socket.emit(SocketEventNames.unlikeStatus, payload);
      return true;
    } catch (e) {
      debugPrint('❌ StatusLikeEmitter.unlike failed: $e');
      return false;
    }
  }

  /// Get like count for a status
  bool getLikeCount({required io.Socket socket, required String statusId}) {
    try {
      final payload = <String, dynamic>{'statusId': statusId};
      if (kDebugMode) {
        debugPrint('📤 [StatusLikeEmitter.getLikeCount] payload=$payload');
      }
      socket.emit(SocketEventNames.getStatusLikeCount, payload);
      return true;
    } catch (e) {
      debugPrint('❌ StatusLikeEmitter.getLikeCount failed: $e');
      return false;
    }
  }

  /// Check if current user has liked a status
  bool checkLikeStatus({required io.Socket socket, required String statusId}) {
    try {
      final payload = <String, dynamic>{'statusId': statusId};
      if (kDebugMode) {
        debugPrint('📤 [StatusLikeEmitter.checkLikeStatus] payload=$payload');
      }
      socket.emit(SocketEventNames.checkStatusLikeStatus, payload);
      return true;
    } catch (e) {
      debugPrint('❌ StatusLikeEmitter.checkLikeStatus failed: $e');
      return false;
    }
  }
}
