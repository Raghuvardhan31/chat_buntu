// ============================================================================
// CHAT LIST PROVIDER - Riverpod Providers for Chat Operations
// ============================================================================
//
// 🎯 PURPOSE:
// Provides Riverpod providers for chat-related dependencies.
// Wires together datasources, repositories, and notifiers.
//
// 📱 PROVIDERS:
// • chatRemoteDataSourceProvider - HTTP API datasource (REMOTE)
// • chatLocalDataSourceProvider - SQLite datasource (LOCAL)
// • getChatHistoryRepositoryProvider - Chat history HTTP API (REMOTE)
// • getChatContactsRepositoryProvider - Chat contacts HTTP API (REMOTE)
// • chatRepositoryProvider - Combined repository (REMOTE + LOCAL)
// • chatListNotifierProvider - State notifier for chat list UI
//
// ⚠️ NOTE: Send/Delete messages use WebSocket via UnifiedChatService
//
// ============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../chat_page_providers/chat_page_provider.dart';
import 'chat_list_notifier.dart';
import 'chat_list_state.dart';
import '../../../data/repositories/chat_repository_impl.dart';
import '../../../data/repositories/chat_repository.dart';
import '../../../data/datasources/chat_remote_datasource.dart';
import '../../../data/repositories/helper_repos/get_chat_history_repository.dart';
import '../../../data/repositories/helper_repos/get_chat_contacts_repository.dart';
import '../../../data/repositories/helper_repos/chat_sync_repository.dart';

// =========================================================================
// 🌐 REMOTE DATASOURCE PROVIDERS
// =========================================================================

/// Provider for chat remote datasource (HTTP API)
final chatRemoteDataSourceProvider = Provider<ChatRemoteDataSource>((ref) {
  return ChatRemoteDataSourceImpl();
});

// =========================================================================
// 🌐 REMOTE REPOSITORY PROVIDERS
// =========================================================================

/// Provider for get chat history repository (REMOTE - HTTP API)
final getChatHistoryRepositoryProvider = Provider<GetChatHistoryRepository>((
  ref,
) {
  final remoteDataSource = ref.watch(chatRemoteDataSourceProvider);
  final localDataSource = ref.watch(chatLocalDataSourceProvider);
  return GetChatHistoryRepository(
    remoteDataSource: remoteDataSource,
    localDataSource: localDataSource,
  );
});

/// Provider for get chat contacts repository (REMOTE - HTTP API)
final getChatContactsRepositoryProvider = Provider<GetChatContactsRepository>((
  ref,
) {
  final remoteDataSource = ref.watch(chatRemoteDataSourceProvider);
  final localDataSource = ref.watch(chatLocalDataSourceProvider);
  return GetChatContactsRepository(
    remoteDataSource: remoteDataSource,
    localDataSource: localDataSource,
  );
});

/// Provider for chat sync repository (REMOTE + LOCAL sync operations)
final chatSyncRepositoryProvider = Provider<ChatSyncRepository>((ref) {
  final remoteDataSource = ref.watch(chatRemoteDataSourceProvider);
  final localDataSource = ref.watch(chatLocalDataSourceProvider);
  return ChatSyncRepository(
    remoteDataSource: remoteDataSource,
    localDataSource: localDataSource,
  );
});

// =========================================================================
// 💾 COMBINED REPOSITORY PROVIDER
// =========================================================================

/// Provider for chat repository (REMOTE + LOCAL operations)
/// NOTE: Send/Delete messages use WebSocket via UnifiedChatService
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final getChatHistoryRepo = ref.watch(getChatHistoryRepositoryProvider);
  final getChatContactsRepo = ref.watch(getChatContactsRepositoryProvider);
  final localDataSource = ref.watch(chatLocalDataSourceProvider);

  return ChatRepositoryImpl(
    getChatHistoryRepo: getChatHistoryRepo,
    getChatContactsRepo: getChatContactsRepo,
    localDataSource: localDataSource,
  );
});

// =========================================================================
// 📱 UI STATE PROVIDERS
// =========================================================================

/// Provider for chat list notifier (manages chat list UI state)
final chatListNotifierProvider =
    StateNotifierProvider<ChatListNotifier, ChatListState>((ref) {
      final localDataSource = ref.watch(chatLocalDataSourceProvider);
      final chatRepository = ref.watch(chatRepositoryProvider);
      return ChatListNotifier(localDataSource, chatRepository);
    });
