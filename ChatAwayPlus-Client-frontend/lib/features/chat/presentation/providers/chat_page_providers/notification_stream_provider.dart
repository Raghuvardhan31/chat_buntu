// lib/features/chat/presentation/providers/notification_stream_provider.dart

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chataway_plus/features/notifications/data/models/notification_model.dart';

/// Notification update event model
class NotificationUpdateEvent {
  final String senderId;
  final String message;
  final DateTime timestamp;

  NotificationUpdateEvent({
    required this.senderId,
    required this.message,
    required this.timestamp,
  });
}

/// Stream controller for notification updates
class NotificationStreamController {
  static final NotificationStreamController _instance =
      NotificationStreamController._internal();

  factory NotificationStreamController() => _instance;

  NotificationStreamController._internal();

  final StreamController<NotificationUpdateEvent> _controller =
      StreamController<NotificationUpdateEvent>.broadcast();

  final StreamController<NotificationModel> _persistentController =
      StreamController<NotificationModel>.broadcast();

  Stream<NotificationUpdateEvent> get stream => _controller.stream;
  Stream<NotificationModel> get persistentStream => _persistentController.stream;

  /// Notify that a new notification was received
  void notifyNewNotification({
    required String senderId,
    required String message,
  }) {
    if (!_controller.isClosed) {
      _controller.add(
        NotificationUpdateEvent(
          senderId: senderId,
          message: message,
          timestamp: DateTime.now(),
        ),
      );
    }
  }

  /// Notify that a new persistent notification was received from socket
  void notifyNewPersistentNotification(NotificationModel notification) {
    if (!_persistentController.isClosed) {
      _persistentController.add(notification);
    }
  }

  /// Notify that notifications were cleared for a sender
  void notifyNotificationsCleared(String senderId) {
    if (!_controller.isClosed) {
      _controller.add(
        NotificationUpdateEvent(
          senderId: senderId,
          message: '',
          timestamp: DateTime.now(),
        ),
      );
    }
  }

  void dispose() {
    _controller.close();
    _persistentController.close();
  }
}

/// Provider for notification stream
final notificationStreamProvider = StreamProvider<NotificationUpdateEvent>((
  ref,
) {
  final controller = NotificationStreamController();
  ref.onDispose(() {
    // Don't dispose the singleton controller
  });
  return controller.stream;
});

/// Provider for notification counts state
class NotificationCountsNotifier
    extends StateNotifier<Map<String, NotificationData>> {
  NotificationCountsNotifier() : super({});

  void updateNotification(String senderId, int count, String lastMessage) {
    state = {
      ...state,
      senderId: NotificationData(count: count, lastMessage: lastMessage),
    };
  }

  void clearNotification(String senderId) {
    final newState = Map<String, NotificationData>.from(state);
    newState.remove(senderId);
    state = newState;
  }

  void clearAll() {
    state = {};
  }

  void setAll(Map<String, NotificationData> data) {
    state = data;
  }
}

class NotificationData {
  final int count;
  final String lastMessage;

  NotificationData({required this.count, required this.lastMessage});
}

final notificationCountsProvider =
    StateNotifierProvider<
      NotificationCountsNotifier,
      Map<String, NotificationData>
    >((ref) => NotificationCountsNotifier());
