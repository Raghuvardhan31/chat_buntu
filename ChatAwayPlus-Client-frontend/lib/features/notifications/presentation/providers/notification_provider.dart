import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/notification_model.dart';
import '../../data/datasources/notification_remote_datasource.dart';
import 'package:chataway_plus/features/chat/presentation/providers/chat_page_providers/notification_stream_provider.dart';
import 'dart:async';

class NotificationState {
  final List<NotificationModel> notifications;
  final bool isLoading;
  final String? error;
  final int unreadCount;

  NotificationState({
    required this.notifications,
    this.isLoading = false,
    this.error,
    this.unreadCount = 0,
  });

  NotificationState copyWith({
    List<NotificationModel>? notifications,
    bool? isLoading,
    String? error,
    int? unreadCount,
  }) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}

class NotificationNotifier extends StateNotifier<NotificationState> {
  final NotificationRemoteDataSource _remoteDataSource;

  NotificationNotifier(this._remoteDataSource) : super(NotificationState(notifications: [])) {
    loadNotifications();
    _subscribeToSocketNotifications();
  }

  StreamSubscription? _socketSubscription;

  void _subscribeToSocketNotifications() {
    _socketSubscription?.cancel();
    _socketSubscription = NotificationStreamController().persistentStream.listen((notification) {
      addNotification(notification);
    });
  }

  @override
  void dispose() {
    _socketSubscription?.cancel();
    super.dispose();
  }

  Future<void> loadNotifications() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _remoteDataSource.getNotifications();
      if (response.isSuccess && response.data != null) {
        final notifications = response.data!;
        state = state.copyWith(
          notifications: notifications,
          isLoading: false,
          unreadCount: notifications.where((n) => !n.isRead).length,
        );
      } else {
        state = state.copyWith(isLoading: false, error: response.errorMessage);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void addNotification(NotificationModel notification) {
    final updatedList = [notification, ...state.notifications];
    state = state.copyWith(
      notifications: updatedList,
      unreadCount: updatedList.where((n) => !n.isRead).length,
    );
  }

  Future<void> markAsRead(String id) async {
    try {
      final response = await _remoteDataSource.markAsRead(id);
      if (response.isSuccess) {
        final updatedList = state.notifications.map((n) {
          if (n.id == id) {
            return NotificationModel(
              id: n.id,
              senderId: n.senderId,
              receiverId: n.receiverId,
              message: n.message,
              type: n.type,
              isRead: true,
              createdAt: n.createdAt,
              metadata: n.metadata,
              sender: n.sender,
            );
          }
          return n;
        }).toList();

        state = state.copyWith(
          notifications: updatedList,
          unreadCount: updatedList.where((n) => !n.isRead).length,
        );
      }
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  Future<void> markAllAsRead() async {
    try {
      final response = await _remoteDataSource.markAllAsRead();
      if (response.isSuccess) {
        final updatedList = state.notifications.map((n) {
          return NotificationModel(
            id: n.id,
            senderId: n.senderId,
            receiverId: n.receiverId,
            message: n.message,
            type: n.type,
            isRead: true,
            createdAt: n.createdAt,
            metadata: n.metadata,
            sender: n.sender,
          );
        }).toList();

        state = state.copyWith(notifications: updatedList, unreadCount: 0);
      }
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
    }
  }

  Future<void> deleteNotification(String id) async {
    try {
      final response = await _remoteDataSource.deleteNotification(id);
      if (response.isSuccess) {
        final updatedList = state.notifications.where((n) => n.id != id).toList();
        state = state.copyWith(
          notifications: updatedList,
          unreadCount: updatedList.where((n) => !n.isRead).length,
        );
      }
    } catch (e) {
      debugPrint('Error deleting notification: $e');
    }
  }
}

final notificationDataSourceProvider = Provider<NotificationRemoteDataSource>((ref) {
  return NotificationRemoteDataSourceImpl();
});

final notificationProvider = StateNotifierProvider<NotificationNotifier, NotificationState>((ref) {
  final dataSource = ref.watch(notificationDataSourceProvider);
  return NotificationNotifier(dataSource);
});
