// lib/features/chat/presentation/providers/message_status_stream_provider.dart

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Message status update event
class MessageStatusEvent {
  final String messageId;
  final String status; // 'sent', 'delivered', 'read'
  final DateTime timestamp;

  MessageStatusEvent({
    required this.messageId,
    required this.status,
    required this.timestamp,
  });
}

/// Stream controller for message status updates
class MessageStatusStreamController {
  static final MessageStatusStreamController _instance =
      MessageStatusStreamController._internal();

  factory MessageStatusStreamController() => _instance;

  MessageStatusStreamController._internal();

  final StreamController<MessageStatusEvent> _controller =
      StreamController<MessageStatusEvent>.broadcast();

  Stream<MessageStatusEvent> get stream => _controller.stream;

  /// Notify that a message status was updated
  void notifyStatusUpdate({required String messageId, required String status}) {
    if (!_controller.isClosed) {
      _controller.add(
        MessageStatusEvent(
          messageId: messageId,
          status: status,
          timestamp: DateTime.now(),
        ),
      );
    }
  }

  void dispose() {
    _controller.close();
  }
}

/// Provider for message status stream
final messageStatusStreamProvider = StreamProvider<MessageStatusEvent>((ref) {
  final controller = MessageStatusStreamController();
  ref.onDispose(() {
    // Don't dispose the singleton controller
  });
  return controller.stream;
});

/// State notifier for message statuses
class MessageStatusNotifier extends StateNotifier<Map<String, String>> {
  MessageStatusNotifier() : super({});

  void updateStatus(String messageId, String status) {
    state = {...state, messageId: status};
  }

  void updateMultiple(Map<String, String> statuses) {
    state = {...state, ...statuses};
  }

  void clear() {
    state = {};
  }
}

final messageStatusProvider =
    StateNotifierProvider<MessageStatusNotifier, Map<String, String>>(
      (ref) => MessageStatusNotifier(),
    );
