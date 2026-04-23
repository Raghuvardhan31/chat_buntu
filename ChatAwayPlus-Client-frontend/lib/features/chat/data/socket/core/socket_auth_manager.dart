import 'package:socket_io_client/socket_io_client.dart' as io;

import '../socket_constants/socket_event_names.dart';

class SocketAuthManager {
  bool _isAuthenticated = false;

  bool get isAuthenticated => _isAuthenticated;

  void setAuthenticated(bool value) {
    _isAuthenticated = value;
  }

  void emitAuthenticate({
    required io.Socket socket,
    required String userId,
    required String token,
    bool loadHistory = false,
  }) {
    final payload = <String, dynamic>{
      'userId': userId,
      'loadHistory': loadHistory,
      'token': token,
    };

    socket.emit(SocketEventNames.authenticate, payload);
  }
}
