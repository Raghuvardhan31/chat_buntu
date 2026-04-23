import 'package:socket_io_client/socket_io_client.dart' as io;

class ConnectionEventsHandler {
  const ConnectionEventsHandler();

  void register({
    required io.Socket socket,
    required void Function() onConnect,
    required void Function(dynamic error) onConnectError,
    required void Function(dynamic reason) onDisconnect,
    required void Function(dynamic error) onError,
  }) {
    socket.onConnect((_) => onConnect());
    socket.onConnectError((error) => onConnectError(error));
    socket.onDisconnect((reason) => onDisconnect(reason));
    socket.onError((error) => onError(error));
  }
}
