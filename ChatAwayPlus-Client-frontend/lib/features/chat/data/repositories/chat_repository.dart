// ============================================================================
// CHAT REPOSITORY - HTTP API Interface for Chat Operations
// ============================================================================
//
// 🎯 PURPOSE:
// Interface for HTTP-based chat operations (history, contacts, search).
// NOTE: Send/Delete messages use WebSocket (UnifiedChatService), not HTTP.
//
// 📱 OPERATIONS:
// • getChatHistory() - Fetch chat history from server (REMOTE)
// • getChatContacts() - Fetch chat contacts from server (REMOTE)
// • getUnreadCount() - Fetch unread counts from server (REMOTE)
// • searchMessages() - Search messages on server (REMOTE)
// • getLocalMessages() - Get messages from local DB (LOCAL)
// • deleteLocalMessage() - Delete from local DB only (LOCAL)
// • clearAllChats() - Clear all local data (LOCAL)
//
// ⚠️ NOTE: Send/Delete messages are handled via WebSocket in UnifiedChatService
//
// ============================================================================

import 'package:chataway_plus/features/chat/data/domain_models/responses/chat_response_models.dart';
import 'package:chataway_plus/features/chat/data/domain_models/responses/chat_result.dart';

import '../../models/chat_message_model.dart';

/// HTTP-based chat repository interface
///
/// For send/delete messages, use UnifiedChatService (WebSocket-based)
abstract class ChatRepository {
  // =========================================================================
  // 🌐 REMOTE OPERATIONS - HTTP API calls to server
  // =========================================================================

  /// Get chat history with pagination (REMOTE)
  Future<ChatResult<ChatHistoryResponseModel>> getChatHistory(
    String otherUserId, {
    int page = 1,
    int limit = 50,
  });

  /// Search messages (REMOTE)
  Future<ChatResult<ChatHistoryResponseModel>> searchMessages({
    required String query,
    String? otherUserId,
  });

  /// Get chat contacts (REMOTE)
  Future<ChatResult<ChatContactsResponseModel>> getChatContacts();

  /// Get unread message count (REMOTE)
  Future<ChatResult<UnreadCountResponseModel>> getUnreadCount();

  // =========================================================================
  // 💾 LOCAL OPERATIONS - Local database operations
  // =========================================================================

  /// Get messages from local database (LOCAL)
  Future<List<ChatMessageModel>> getLocalMessages(
    String otherUserId, {
    int limit = 50,
    int offset = 0,
  });

  /// Delete a message only from local database (LOCAL - "delete for me")
  Future<void> deleteLocalMessage(String messageId);

  /// Clear all chat data from local database (LOCAL - logout)
  Future<void> clearAllChats();
}
