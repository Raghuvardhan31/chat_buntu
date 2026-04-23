import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chataway_plus/features/chat/data/socket/socket_models/index.dart';
import 'package:chataway_plus/features/chat/data/services/chat_engine/index.dart';

/// Provider for tracking specific user's online/offline status
/// This is a family provider that filters for a specific userId
final specificUserStatusProvider = StreamProvider.family<UserStatus?, String>((
  ref,
  userId,
) {
  final hybrid = ChatEngineService.instance;
  return hybrid.userStatusStream
      .where((status) => status.userId == userId)
      .map((status) => status);
});

/// State notifier for managing user status cache
class UserStatusNotifier extends StateNotifier<Map<String, UserStatus>> {
  UserStatusNotifier() : super({});

  void updateStatus(UserStatus status) {
    state = {...state, status.userId: status};
  }

  UserStatus? getStatus(String userId) {
    return state[userId];
  }

  bool isUserOnline(String userId) {
    return state[userId]?.isOnline ?? false;
  }

  String? getLastSeen(String userId) {
    final lastSeen = state[userId]?.lastSeen;
    if (lastSeen == null) return null;

    final now = DateTime.now();
    final difference = now.difference(lastSeen);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  /// Clear all cached user statuses (called on socket disconnect)
  void clearAllStatuses() {
    state = {};
  }

  /// Mark all cached users as offline (alternative to clearing)
  void markAllAsOffline() {
    final offlineStatuses = <String, UserStatus>{};
    for (final entry in state.entries) {
      offlineStatuses[entry.key] = UserStatus(
        userId: entry.key,
        isOnline: false,
        status: 'offline',
        isInChat: false,
        chattingWith: null,
        lastSeen: DateTime.now(),
      );
    }
    state = offlineStatuses;
  }
}

/// Provider for user status cache
final userStatusProvider =
    StateNotifierProvider<UserStatusNotifier, Map<String, UserStatus>>(
      (ref) => UserStatusNotifier(),
    );
