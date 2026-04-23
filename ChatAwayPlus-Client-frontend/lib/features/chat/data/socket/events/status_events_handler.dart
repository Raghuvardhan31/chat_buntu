import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../socket_constants/socket_event_names.dart';
import '../socket_models/index.dart';

class StatusEventsHandler {
  const StatusEventsHandler();

  bool _parseBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) return value == 1;
    final s = value.toString().toLowerCase();
    return s == 'true' || s == '1';
  }

  void register({
    required io.Socket socket,
    required void Function(UserStatus status) onUserStatus,
    void Function(Map<String, dynamic> payload)? onPresenceAcknowledged,
  }) {
    socket.on(SocketEventNames.userStatusChanged, (data) {
      try {
        final map = data is Map ? Map<String, dynamic>.from(data) : null;
        if (map == null) return;

        final isOnline = _parseBool(map['isOnline'] ?? map['online']);
        final timestampStr = map['timestamp'] as String?;
        final lastSeenStr = map['lastSeen'] as String?;
        final parsedTimestamp = timestampStr != null
            ? DateTime.tryParse(timestampStr)
            : DateTime.now();

        final lastSeenTime = lastSeenStr != null
            ? DateTime.tryParse(lastSeenStr)
            : (!isOnline && parsedTimestamp != null ? parsedTimestamp : null);

        final status = UserStatus(
          userId: (map['userId'] ?? map['uid'])?.toString() ?? '',
          isOnline: isOnline,
          status:
              (map['status'] as String?) ?? (isOnline ? 'online' : 'offline'),
          isInChat: _parseBool(map['isInChat']),
          chattingWith: map['chattingWith']?.toString(),
          lastSeen: lastSeenTime,
          timestamp: parsedTimestamp,
        );

        if (status.userId.isEmpty) return;
        onUserStatus(status);
      } catch (e) {
        debugPrint('❌ StatusEventsHandler parsing user-status-changed: $e');
      }
    });

    socket.on(SocketEventNames.userStatusResponse, (data) {
      try {
        final map = data is Map ? Map<String, dynamic>.from(data) : null;
        if (map == null) return;

        final isOnline = _parseBool(map['isOnline'] ?? map['online']);
        final timestampStr = map['timestamp'] as String?;
        final lastSeenStr = map['lastSeen'] as String?;
        final parsedTimestamp = timestampStr != null
            ? DateTime.tryParse(timestampStr)
            : DateTime.now();

        final lastSeenTime = lastSeenStr != null
            ? DateTime.tryParse(lastSeenStr)
            : (!isOnline && parsedTimestamp != null ? parsedTimestamp : null);

        final status = UserStatus(
          userId: (map['userId'] ?? map['uid'])?.toString() ?? '',
          isOnline: isOnline,
          status:
              (map['status'] as String?) ?? (isOnline ? 'online' : 'offline'),
          isInChat: _parseBool(map['isInChat']),
          chattingWith: map['chattingWith']?.toString(),
          lastSeen: lastSeenTime,
          timestamp: parsedTimestamp,
        );

        if (status.userId.isEmpty) return;
        onUserStatus(status);
      } catch (e) {
        debugPrint('❌ StatusEventsHandler parsing user-status-response: $e');
      }
    });

    socket.on(SocketEventNames.presenceAcknowledged, (data) {
      try {
        final map = data is Map ? Map<String, dynamic>.from(data) : null;
        if (map == null) return;
        onPresenceAcknowledged?.call(map);
      } catch (_) {}
    });
  }
}
