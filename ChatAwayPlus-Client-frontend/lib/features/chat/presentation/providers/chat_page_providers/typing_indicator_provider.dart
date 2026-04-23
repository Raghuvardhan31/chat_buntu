import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chataway_plus/features/chat/data/services/chat_engine/index.dart';

/// Manages typing indicators for all conversations (WhatsApp-style)
class TypingIndicatorNotifier extends StateNotifier<Map<String, bool>> {
  TypingIndicatorNotifier(this._chatEngineService) : super({}) {
    _listenToTypingEvents();
  }

  final ChatEngineService _chatEngineService;
  StreamSubscription? _typingSubscription;

  /// Listen to typing events from socket
  void _listenToTypingEvents() {
    _typingSubscription = _chatEngineService.typingStream.listen((
      typingStatus,
    ) {
      final userId = typingStatus.userId;
      final isTyping = typingStatus.isTyping;

      // Update state directly from socket event
      state = {...state, userId: isTyping};
    });
  }

  @override
  void dispose() {
    _typingSubscription?.cancel();
    super.dispose();
  }
}

/// Provider for typing indicator state
final typingIndicatorProvider =
    StateNotifierProvider<TypingIndicatorNotifier, Map<String, bool>>((ref) {
      final hybrid = ChatEngineService.instance;
      return TypingIndicatorNotifier(hybrid);
    });

/// Helper provider to check if a specific user is typing
final isUserTypingProvider = Provider.family<bool, String>((ref, userId) {
  final typingState = ref.watch(typingIndicatorProvider);
  return typingState[userId] ?? false;
});
