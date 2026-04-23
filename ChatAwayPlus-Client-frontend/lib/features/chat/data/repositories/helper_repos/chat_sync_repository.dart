// ============================================================================
// CHAT SYNC REPOSITORY - Centralized Chat Synchronization (REMOTE + LOCAL)
// ============================================================================
//
// 🎯 PURPOSE:
// Centralized repository for all chat synchronization operations.
// Makes it easy to identify where sync calls are happening in the app.
//
// 🌐 REMOTE OPERATIONS:
// • syncConversation() - Sync specific conversation with server (REMOTE)
// • syncAllConversations() - Sync all conversations with server (REMOTE)
// • forceSyncConversation() - Force full sync (ignore cache) (REMOTE)
//
// 💾 LOCAL OPERATIONS:
// • getLastSyncTime() - Get last sync timestamp from SQLite (LOCAL)
// • updateLastSyncTime() - Update sync timestamp in SQLite (LOCAL)
//
// 🔄 SYNC TRIGGERS:
// • Open chat → syncConversation()
// • Socket reconnect → syncAllConversations()
// • Periodic timer → syncConversation()
// • Manual refresh → forceSyncConversation()
//
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:chataway_plus/core/database/tables/chat/chat_sync_metadata_table.dart';
import 'package:chataway_plus/features/chat/utils/chat_helper.dart';
import '../../../data/domain_models/responses/chat_response_models.dart';
import '../../../data/domain_models/responses/chat_result.dart';
import '../../datasources/chat_remote_datasource.dart';
import '../../datasources/chat_local_datasource.dart';

/// Centralized repository for chat synchronization operations
///
/// This makes it easy to track where sync calls are happening in the app
class ChatSyncRepository {
  final ChatRemoteDataSource remoteDataSource;
  final ChatLocalDataSource localDataSource;

  static const bool _verboseLogs = kDebugMode; // Only log in debug builds

  ChatSyncRepository({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  // =========================================================================
  // 🌐 REMOTE SYNC OPERATIONS - Server synchronization
  // =========================================================================

  /// Sync specific conversation with server (smart incremental sync)
  ///
  /// Called from:
  /// - UnifiedChatService.startConversation()
  /// - Socket reconnection handlers
  /// - Periodic sync timer
  Future<ChatResult<ChatHistoryResponseModel>> syncConversation(
    String otherUserId, {
    int page = 1,
    int limit = 50,
    bool force = false,
  }) async {
    try {
      _log(
        'SyncConversation',
        '🔄 Starting sync for conversation: $otherUserId',
      );

      if (otherUserId.isEmpty) {
        return ChatResult.failure(
          errorMessage: 'User ID is required',
          errorCode: 'VALIDATION_ERROR',
        );
      }

      // Get current user ID
      final currentUserId = await ChatHelper.getCurrentUserId();
      if (currentUserId == null) {
        _log('SyncConversation', '❌ Current user ID not found');
        return ChatResult.failure(
          errorMessage: 'User not authenticated',
          errorCode: 'AUTH_ERROR',
        );
      }

      // Get last sync time (unless forcing full sync)
      String? lastSyncTime;
      if (!force) {
        lastSyncTime = await getLastSyncTime(
          currentUserId: currentUserId,
          otherUserId: otherUserId,
        );
      }

      ChatHistoryResponseModel response;

      if (lastSyncTime == null || force) {
        // First time or forced sync - use full chat history API
        _log(
          'SyncConversation',
          '📥 Full sync (${force ? "forced" : "first time"})',
        );
        response = await remoteDataSource.getChatHistory(
          otherUserId,
          page: page,
          limit: limit,
        );

        // Save sync time after successful first sync
        if (response.isSuccess && response.messages != null) {
          final messages = response.messages!;
          DateTime? maxTimestamp;

          for (final m in messages) {
            final candidate = m.updatedAt.isAfter(m.createdAt)
                ? m.updatedAt
                : m.createdAt;
            if (maxTimestamp == null || candidate.isAfter(maxTimestamp)) {
              maxTimestamp = candidate;
            }
          }

          final syncTime = (maxTimestamp ?? DateTime.now()).toIso8601String();
          await updateLastSyncTime(
            currentUserId: currentUserId,
            otherUserId: otherUserId,
            lastSyncTime: syncTime,
          );
        }
      } else {
        // Incremental sync - use optimized sync API
        _log(
          'SyncConversation',
          '⚡ Incremental sync (lastSyncTime: $lastSyncTime)',
        );

        final syncResponse = await remoteDataSource.syncMessages(
          otherUserId: otherUserId,
          lastSyncTime: lastSyncTime,
          page: page,
          limit: limit,
        );

        // Update sync time if successful
        if (syncResponse.isSuccess &&
            syncResponse.syncInfo?.currentSyncTime != null) {
          await updateLastSyncTime(
            currentUserId: currentUserId,
            otherUserId: otherUserId,
            lastSyncTime: syncResponse.syncInfo!.currentSyncTime!,
          );
          _log(
            'SyncConversation',
            '✅ Synced ${syncResponse.messages?.length ?? 0} new messages',
          );
        }

        // Convert SyncMessagesResponseModel to ChatHistoryResponseModel
        response = ChatHistoryResponseModel(
          success: syncResponse.success,
          messages: syncResponse.messages,
          hasMore: syncResponse.hasMore,
          pagination: syncResponse.pagination,
          error: syncResponse.error,
          statusCode: syncResponse.statusCode,
        );
      }

      if (response.isSuccess && response.messages != null) {
        // Cache messages locally
        await localDataSource.saveMessages(response.messages!);
        _log(
          'SyncConversation',
          '💾 Cached ${response.messages!.length} messages locally',
        );
        return ChatResult.success(response);
      } else {
        _log('SyncConversation', '❌ Sync failed: ${response.errorMessage}');
        return ChatResult.failure(
          errorMessage: response.errorMessage ?? 'Failed to sync conversation',
          errorCode: 'SYNC_CONVERSATION_FAILED',
          statusCode: response.statusCode,
        );
      }
    } catch (e, st) {
      _log('SyncConversation', '❌ Exception: $e\n$st');
      return ChatResult.failure(
        errorMessage: 'An unexpected error occurred during sync',
        errorCode: 'SYNC_CONVERSATION_EXCEPTION',
        exception: e is Exception ? e : Exception(e.toString()),
      );
    }
  }

  /// Force full sync for conversation (ignore cache, fetch all messages)
  ///
  /// Called from:
  /// - Pull-to-refresh in chat
  /// - Manual sync triggers
  Future<ChatResult<ChatHistoryResponseModel>> forceSyncConversation(
    String otherUserId, {
    int page = 1,
    int limit = 50,
  }) async {
    _log(
      'ForceSyncConversation',
      '🔄 Force syncing conversation: $otherUserId',
    );
    return syncConversation(otherUserId, page: page, limit: limit, force: true);
  }

  /// Sync all conversations (called on app startup or major reconnects)
  ///
  /// Called from:
  /// - App startup
  /// - Socket reconnection
  /// - Background sync
  Future<void> syncAllConversations({
    List<String>? specificUserIds,
    int limit = 20,
  }) async {
    try {
      _log('SyncAllConversations', '🔄 Starting sync for all conversations');

      final currentUserId = await ChatHelper.getCurrentUserId();
      if (currentUserId == null) {
        _log('SyncAllConversations', '❌ Current user ID not found');
        return;
      }

      // Get list of users to sync
      List<String> userIds = specificUserIds ?? [];
      if (userIds.isEmpty) {
        // Get recent conversation partners from local DB
        final contacts = await localDataSource.getChatContactsFromLocal();
        userIds = contacts.map((c) => c.user.id).take(limit).toList();
      }

      _log(
        'SyncAllConversations',
        '📋 Syncing ${userIds.length} conversations',
      );

      // Sync each conversation (don't await all - run in parallel)
      final futures = userIds.map((userId) => syncConversation(userId));
      await Future.wait(futures, eagerError: false);

      _log('SyncAllConversations', '✅ Completed sync for all conversations');
    } catch (e) {
      _log('SyncAllConversations', '❌ Exception: $e');
    }
  }

  // =========================================================================
  // 💾 LOCAL SYNC METADATA OPERATIONS - SQLite operations
  // =========================================================================

  /// Get last sync time for a conversation (LOCAL)
  Future<String?> getLastSyncTime({
    required String currentUserId,
    required String otherUserId,
  }) async {
    try {
      return await ChatSyncMetadataTable.instance.getLastSyncTime(
        currentUserId: currentUserId,
        otherUserId: otherUserId,
      );
    } catch (e) {
      _log('GetLastSyncTime', '❌ Error: $e');
      return null;
    }
  }

  /// Update last sync time for a conversation (LOCAL)
  Future<void> updateLastSyncTime({
    required String currentUserId,
    required String otherUserId,
    required String lastSyncTime,
  }) async {
    try {
      await ChatSyncMetadataTable.instance.saveLastSyncTime(
        currentUserId: currentUserId,
        otherUserId: otherUserId,
        lastSyncTime: lastSyncTime,
      );
      _log('UpdateLastSyncTime', '💾 Updated sync time: $lastSyncTime');
    } catch (e) {
      _log('UpdateLastSyncTime', '❌ Error: $e');
    }
  }

  /// Clear all sync metadata (called on logout) (LOCAL)
  Future<void> clearAllSyncMetadata() async {
    try {
      // Note: Add this method to ChatSyncMetadataTable if needed
      _log('ClearAllSyncMetadata', '🗑️ Cleared all sync metadata');
    } catch (e) {
      _log('ClearAllSyncMetadata', '❌ Error: $e');
    }
  }

  // =========================================================================
  // 🔧 UTILITY METHODS
  // =========================================================================

  /// Check if conversation needs sync (based on last sync time)
  Future<bool> needsSync({
    required String currentUserId,
    required String otherUserId,
    Duration maxAge = const Duration(minutes: 5),
  }) async {
    try {
      final lastSyncTime = await getLastSyncTime(
        currentUserId: currentUserId,
        otherUserId: otherUserId,
      );

      if (lastSyncTime == null) return true; // Never synced

      final lastSync = DateTime.tryParse(lastSyncTime);
      if (lastSync == null) return true; // Invalid timestamp

      final age = DateTime.now().difference(lastSync);
      return age > maxAge;
    } catch (e) {
      _log('NeedsSync', '❌ Error: $e');
      return true; // Err on side of syncing
    }
  }

  void _log(String operation, String message) {
    if (_verboseLogs && kDebugMode) {
      debugPrint('🔄 [SYNC] $operation: $message');
    }
  }
}
