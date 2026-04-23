// ============================================================================
// CHAT REPOSITORY IMPL - HTTP API Implementation for Chat Operations
// ============================================================================
//
// 🎯 PURPOSE:
// Implementation of ChatRepository using HTTP APIs for history/contacts/search.
// NOTE: Send/Delete messages use WebSocket (UnifiedChatService), not this class.
//
// 📱 OPERATIONS:
// • getChatHistory() - Fetch from server via HTTP (REMOTE)
// • getChatContacts() - Fetch from server via HTTP (REMOTE)
// • getUnreadCount() - Fetch from server via HTTP (REMOTE)
// • searchMessages() - Search on server via HTTP (REMOTE)
// • getLocalMessages() - Read from local SQLite DB (LOCAL)
// • deleteLocalMessage() - Delete from local SQLite DB (LOCAL)
// • clearAllChats() - Clear local SQLite DB (LOCAL)
//
// ============================================================================

import 'package:chataway_plus/features/chat/data/domain_models/responses/chat_response_models.dart';
import 'package:chataway_plus/features/chat/data/domain_models/responses/chat_result.dart';

import '../../models/chat_message_model.dart';

import '../datasources/chat_local_datasource.dart';
import 'chat_repository.dart';
import 'helper_repos/get_chat_history_repository.dart';
import 'helper_repos/get_chat_contacts_repository.dart';

/// Implementation of [ChatRepository]
///
/// Uses HTTP APIs for remote operations, SQLite for local operations.
/// For send/delete messages, use UnifiedChatService (WebSocket-based).
class ChatRepositoryImpl implements ChatRepository {
  final GetChatHistoryRepository getChatHistoryRepo;
  final GetChatContactsRepository getChatContactsRepo;
  final ChatLocalDataSource localDataSource;

  ChatRepositoryImpl({
    required this.getChatHistoryRepo,
    required this.getChatContactsRepo,
    required this.localDataSource,
  });

  // =========================================================================
  // 🌐 REMOTE OPERATIONS - HTTP API calls to server
  // =========================================================================

  @override
  Future<ChatResult<ChatHistoryResponseModel>> getChatHistory(
    String otherUserId, {
    int page = 1,
    int limit = 50,
  }) =>
      getChatHistoryRepo.getChatHistory(otherUserId, page: page, limit: limit);

  @override
  Future<ChatResult<ChatHistoryResponseModel>> searchMessages({
    required String query,
    String? otherUserId,
  }) =>
      getChatHistoryRepo.searchMessages(query: query, otherUserId: otherUserId);

  @override
  Future<ChatResult<ChatContactsResponseModel>> getChatContacts() =>
      getChatContactsRepo.getChatContacts();

  @override
  Future<ChatResult<UnreadCountResponseModel>> getUnreadCount() =>
      getChatContactsRepo.getUnreadCount();

  // =========================================================================
  // 💾 LOCAL OPERATIONS - Local SQLite database operations
  // =========================================================================

  @override
  Future<List<ChatMessageModel>> getLocalMessages(
    String otherUserId, {
    int limit = 50,
    int offset = 0,
  }) async {
    return await localDataSource.getMessages(
      otherUserId,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<void> deleteLocalMessage(String messageId) async {
    await localDataSource.deleteMessage(messageId);
  }

  @override
  Future<void> clearAllChats() async {
    await localDataSource.clearAllChats();
  }
}
