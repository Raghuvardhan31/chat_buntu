import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chataway_plus/features/chat/data/services/chat_engine/index.dart';
import '../socket_models/index.dart';
import '../../../models/chat_message_model.dart';

/// Provider for the socket service singleton
///
/// This provider manages the WebSocket connection lifecycle
final socketServiceProvider = Provider<ChatEngineService>((ref) {
  return ChatEngineService.instance;
});

/// Provider for socket connection status stream
///
/// Use this to reactively listen to connection changes
/// Example:
/// ```dart
/// final connectionState = ref.watch(socketConnectionProvider);
/// connectionState.when(
///   data: (isConnected) => Text(isConnected ? 'Online' : 'Offline'),
///   loading: () => CircularProgressIndicator(),
///   error: (e, _) => Text('Error: $e'),
/// );
/// ```
final socketConnectionProvider = StreamProvider<bool>((ref) {
  return ChatEngineService.instance.connectionStream;
});

/// Provider for new messages stream
///
/// Listens to incoming messages from WebSocket
final newMessageStreamProvider = StreamProvider<ChatMessageModel>((ref) {
  return ChatEngineService.instance.globalNewMessageStream;
});

/// Provider for message sent confirmations stream
///
/// Listens to server confirmations of sent messages
final messageSentStreamProvider = StreamProvider<ChatMessageModel>((ref) {
  return ChatEngineService.instance.messageSentStream;
});

/// Provider for message status updates stream
///
/// Listens to delivered/read status changes
final messageStatusUpdateStreamProvider =
    StreamProvider<ChatMessageStatusUpdate>((ref) {
      return ChatEngineService.instance.messageStatusStream;
    });

/// Provider for user status changes stream
///
/// Listens to online/offline status of other users
final userStatusStreamProvider = StreamProvider<UserStatus>((ref) {
  return ChatEngineService.instance.userStatusStream;
});

/// Provider for typing indicators stream
///
/// Listens to when other users are typing
final typingStatusStreamProvider = StreamProvider<TypingStatus>((ref) {
  return ChatEngineService.instance.typingStream;
});

/// Provider for message deletion events stream
final messageDeletedStreamProvider = StreamProvider<String>((ref) {
  return ChatEngineService.instance.messageDeletedStream;
});

/// Provider for socket errors stream
final socketErrorStreamProvider = StreamProvider<String>((ref) {
  return Stream<String>.empty();
});
