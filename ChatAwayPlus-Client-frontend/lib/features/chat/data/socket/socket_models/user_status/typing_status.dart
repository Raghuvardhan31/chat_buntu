/// Typing indicator status
class TypingStatus {
  final String userId;
  final bool isTyping;

  TypingStatus({required this.userId, required this.isTyping});

  @override
  String toString() => 'TypingStatus(userId: $userId, typing: $isTyping)';
}
