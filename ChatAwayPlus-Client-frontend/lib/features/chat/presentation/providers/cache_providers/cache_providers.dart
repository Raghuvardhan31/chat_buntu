// lib/features/chat/presentation/providers/cache_providers/cache_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/cache/chat_cache_manager.dart';
import '../../../data/cache/opened_chats_cache.dart';
import '../../../data/cache/chat_list_cache.dart';

import 'cache_notifier.dart';
import 'cache_state.dart';

final chatCacheManagerProvider = Provider<ChatCacheManager>((ref) {
  return ChatCacheManager.instance;
});

final openedChatsCacheProvider = Provider<OpenedChatsCache>((ref) {
  return OpenedChatsCache.instance;
});

final chatListCacheProvider = Provider<ChatListCache>((ref) {
  return ChatListCache.instance;
});

final openedChatCacheNotifierProvider =
    StateNotifierProvider<OpenedChatCacheNotifier, OpenedChatCacheState?>((
      ref,
    ) {
      final cache = ref.watch(openedChatsCacheProvider);
      return OpenedChatCacheNotifier(cache);
    });

final chatListCacheNotifierProvider =
    StateNotifierProvider<ChatListCacheNotifier, ChatListCacheState>((ref) {
      final cache = ref.watch(chatListCacheProvider);
      return ChatListCacheNotifier(cache);
    });
