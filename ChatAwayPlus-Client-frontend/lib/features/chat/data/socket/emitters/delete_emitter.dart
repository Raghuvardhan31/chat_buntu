import 'package:socket_io_client/socket_io_client.dart' as io;

import '../socket_constants/socket_event_names.dart';

class DeleteEmitter {
  const DeleteEmitter();

  bool deleteMessage({
    required io.Socket socket,
    required String chatId,
    required String deleteType,
  }) {
    final id = chatId.trim();
    if (id.isEmpty) return false;

    final type = deleteType.trim();
    if (type != 'me' && type != 'everyone') return false;

    try {
      socket.emit(SocketEventNames.deleteMessage, <String, dynamic>{
        'chatId': id,
        'deleteType': type,
      });
      return true;
    } catch (_) {
      return false;
    }
  }
}
