import 'package:socket_io_client/socket_io_client.dart' as io;

import '../socket_constants/socket_event_names.dart';

class AuthEventsHandler {
  const AuthEventsHandler();

  void register({
    required io.Socket socket,
    required void Function(dynamic data) onAuthenticated,
    required void Function(dynamic data) onAuthenticationError,
    required void Function(dynamic data) onInvalidToken,
    required void Function(dynamic data) onAuthError,
    required void Function(dynamic data) onForceDisconnect,
  }) {
    socket.on(SocketEventNames.authenticated, onAuthenticated);
    socket.on(SocketEventNames.authenticationError, onAuthenticationError);
    socket.on(SocketEventNames.invalidToken, onInvalidToken);
    socket.on(SocketEventNames.authError, onAuthError);
    socket.on(SocketEventNames.forceDisconnect, onForceDisconnect);
  }
}
