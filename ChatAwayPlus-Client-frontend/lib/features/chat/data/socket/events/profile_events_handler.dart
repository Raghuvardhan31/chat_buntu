import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../socket_constants/socket_event_names.dart';
import '../socket_models/index.dart';

class ProfileEventsHandler {
  const ProfileEventsHandler();

  void register({
    required io.Socket socket,
    required void Function(ProfileUpdate update) onProfileUpdated,
  }) {
    socket.on(SocketEventNames.profileUpdated, (data) {
      if (kDebugMode) {
        debugPrint('👤 PROFILE UPDATE RECEIVED FROM CONTACT');
      }

      try {
        final payload = <String, dynamic>{};
        if (data is Map) {
          for (final entry in data.entries) {
            payload[entry.key.toString()] = entry.value;
          }
        }

        final profileUpdate = ProfileUpdate.fromJson(payload);

        if (profileUpdate.hasUpdates) {
          if (kDebugMode) {
            debugPrint('👤 Parsed: $profileUpdate');
          }
          onProfileUpdated(profileUpdate);
        } else {
          if (kDebugMode) {
            debugPrint('👤 No fields updated, ignoring');
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('❌ Error parsing profile update: $e');
        }
      }
    });
  }
}
