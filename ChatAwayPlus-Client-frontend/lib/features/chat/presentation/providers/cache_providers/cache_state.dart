// lib/features/chat/presentation/providers/cache_providers/cache_state.dart

import '../../../models/chat_message_model.dart';

class OpenedChatCacheState {
  final String otherUserId;
  final List<ChatMessageModel> messages;
  final bool isFromCache;
  final DateTime? cacheTime;

  const OpenedChatCacheState({
    required this.otherUserId,
    required this.messages,
    this.isFromCache = false,
    this.cacheTime,
  });

  OpenedChatCacheState copyWith({
    String? otherUserId,
    List<ChatMessageModel>? messages,
    bool? isFromCache,
    DateTime? cacheTime,
  }) {
    return OpenedChatCacheState(
      otherUserId: otherUserId ?? this.otherUserId,
      messages: messages ?? this.messages,
      isFromCache: isFromCache ?? this.isFromCache,
      cacheTime: cacheTime ?? this.cacheTime,
    );
  }
}

class ChatListCacheState {
  final List<ChatContactModel> contacts;
  final bool isFromCache;
  final DateTime? cacheTime;
  final bool isLoading;

  const ChatListCacheState({
    required this.contacts,
    this.isFromCache = false,
    this.cacheTime,
    this.isLoading = false,
  });

  ChatListCacheState copyWith({
    List<ChatContactModel>? contacts,
    bool? isFromCache,
    DateTime? cacheTime,
    bool? isLoading,
  }) {
    return ChatListCacheState(
      contacts: contacts ?? this.contacts,
      isFromCache: isFromCache ?? this.isFromCache,
      cacheTime: cacheTime ?? this.cacheTime,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  static const empty = ChatListCacheState(contacts: []);
}
