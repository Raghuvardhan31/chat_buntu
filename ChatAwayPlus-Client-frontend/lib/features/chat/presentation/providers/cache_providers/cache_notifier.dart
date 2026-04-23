// lib/features/chat/presentation/providers/cache_providers/cache_notifier.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/cache/opened_chats_cache.dart';
import '../../../data/cache/chat_list_cache.dart';
import '../../../models/chat_message_model.dart';
import 'cache_state.dart';

class OpenedChatCacheNotifier extends StateNotifier<OpenedChatCacheState?> {
  final OpenedChatsCache _cache;

  OpenedChatCacheNotifier(this._cache) : super(null);

  void setMessages({
    required String otherUserId,
    required List<ChatMessageModel> messages,
    required bool isFromCache,
  }) {
    _cache.cacheMessages(otherUserId, messages);
    state = OpenedChatCacheState(
      otherUserId: otherUserId,
      messages: messages,
      isFromCache: isFromCache,
      cacheTime: DateTime.now(),
    );
  }

  void addMessage(ChatMessageModel message) {
    final current = state;
    if (current == null) return;

    final updated = List<ChatMessageModel>.from(current.messages);
    final index = updated.indexWhere((m) => m.id == message.id);

    if (index == -1) {
      updated.add(message);
    } else {
      updated[index] = message;
    }

    state = current.copyWith(messages: updated);
    _cache.cacheMessages(current.otherUserId, updated);
  }

  void clear() {
    state = null;
  }
}

class ChatListCacheNotifier extends StateNotifier<ChatListCacheState> {
  final ChatListCache _cache;

  ChatListCacheNotifier(this._cache) : super(ChatListCacheState.empty);

  Future<void> load() async {
    state = state.copyWith(isLoading: true);

    try {
      final cached = _cache.contacts;
      if (cached != null) {
        state = ChatListCacheState(
          contacts: cached,
          isFromCache: true,
          cacheTime: DateTime.now(),
          isLoading: false,
        );
        return;
      }

      await _cache.preload();
      final contacts = _cache.contacts ?? [];

      state = ChatListCacheState(
        contacts: contacts,
        isFromCache: false,
        cacheTime: DateTime.now(),
        isLoading: false,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [ChatListCacheNotifier] Load failed: $e');
      }
      state = state.copyWith(isLoading: false);
    }
  }

  void clear() {
    _cache.clear();
    state = ChatListCacheState.empty;
  }
}
