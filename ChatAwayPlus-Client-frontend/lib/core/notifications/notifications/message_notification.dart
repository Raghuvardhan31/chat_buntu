import 'package:firebase_messaging/firebase_messaging.dart';

class MessageNotificationHandler {
  static const List<String> supportedTypes = <String>[
    'chat_message',
    'message',
    'private_message',
  ];

  static bool isMessageType(String type) {
    final t = type.toLowerCase();
    for (final v in supportedTypes) {
      if (t == v) return true;
    }
    return false;
  }

  static Future<bool> tryHandle({
    required RemoteMessage message,
    required String type,
    required Future<void> Function(RemoteMessage message) handle,
  }) async {
    if (!isMessageType(type)) return false;
    await handle(message);
    return true;
  }
}
