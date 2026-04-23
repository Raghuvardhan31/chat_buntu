/// User online/offline status
class UserStatus {
  final String userId;
  final bool isOnline;
  final String status; // 'online' | 'offline'
  final bool isInChat;
  final String? chattingWith;
  final DateTime? lastSeen;
  final DateTime timestamp;

  UserStatus({
    required this.userId,
    required this.isOnline,
    required this.status,
    required this.isInChat,
    this.chattingWith,
    this.lastSeen,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() =>
      'UserStatus(userId: $userId, status: $status, isOnline: $isOnline, '
      'isInChat: $isInChat, chattingWith: $chattingWith)';
}
