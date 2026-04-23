// ============================================================================
// GET CHAT HISTORY REPOSITORY - Fetch Chat History (REMOTE + LOCAL)
// ============================================================================
//
// 🎯 PURPOSE:
// Fetches chat history from server and caches to local database.
// Uses intelligent sync: first time = full fetch, subsequent = incremental sync.
//
// 🌐 REMOTE OPERATIONS:
// • getChatHistory() - Fetch from server via HTTP API (REMOTE)
// • syncMessages() - Incremental sync from server (REMOTE)
// • searchMessages() - Search on server (REMOTE)
//
// 💾 LOCAL OPERATIONS:
// • saveMessages() - Cache fetched messages to SQLite (LOCAL)
//
// ============================================================================

import 'package:chataway_plus/features/chat/data/domain_models/responses/chat_response_models.dart';
import 'package:chataway_plus/features/chat/data/domain_models/responses/chat_result.dart';
import 'package:flutter/foundation.dart';
import 'package:chataway_plus/core/database/tables/chat/chat_sync_metadata_table.dart';
import 'package:chataway_plus/features/chat/utils/chat_helper.dart';
import '../../datasources/chat_remote_datasource.dart';
import '../../datasources/chat_local_datasource.dart';

/// Repository for fetching chat history (REMOTE) and caching (LOCAL)
class GetChatHistoryRepository {
  final ChatRemoteDataSource remoteDataSource;
  final ChatLocalDataSource localDataSource;

  static const bool _verboseLogs = kDebugMode; // Only log in debug builds

  // Race condition protection: Track ongoing sync operations
  // Key format: "currentUserId:otherUserId"
  static final Set<String> _ongoingSyncs = {};

  GetChatHistoryRepository({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  /// Get chat history - intelligently uses sync API or full history based on local data
  ///
  /// Logic:
  /// - First time (no local messages): Use getChatHistory API to get all messages
  /// - Subsequent times (has local messages): Use syncMessages API with lastSyncTime
  /// - [sinceMessageId]: Optional - for incremental sync, only fetch messages after this ID
  Future<ChatResult<ChatHistoryResponseModel>> getChatHistory(
    String otherUserId, {
    int page = 1,
    int limit = 50,
    String? sinceMessageId,
  }) async {
    try {
      if (otherUserId.isEmpty) {
        return ChatResult.failure(
          errorMessage: 'User ID is required',
          errorCode: 'VALIDATION_ERROR',
        );
      }

      // Get current user ID
      final currentUserId = await ChatHelper.getCurrentUserId();
      if (currentUserId == null) {
        _log('GetChatHistory', '❌ Current user ID not found');
        return ChatResult.failure(
          errorMessage: 'User not authenticated',
          errorCode: 'AUTH_ERROR',
        );
      }

      // RACE CONDITION PROTECTION: Check if sync already in progress
      final syncKey = '$currentUserId:$otherUserId';
      if (_ongoingSyncs.contains(syncKey)) {
        _log(
          'GetChatHistory',
          '⏸️ Sync already in progress for this conversation, waiting...',
        );
        // Wait a bit and return error to prevent duplicate calls
        await Future.delayed(const Duration(milliseconds: 100));
        return ChatResult.failure(
          errorMessage: 'Sync already in progress',
          errorCode: 'SYNC_IN_PROGRESS',
        );
      }

      // Mark sync as in progress
      _ongoingSyncs.add(syncKey);

      try {
        // Check if we have sync metadata (indicates we've synced before)
        final lastSyncTime = await ChatSyncMetadataTable.instance
            .getLastSyncTime(
              currentUserId: currentUserId,
              otherUserId: otherUserId,
            );

        ChatHistoryResponseModel response;

        if (lastSyncTime == null) {
          // First time - use full chat history API (with optional sinceMessageId for incremental)
          response = await remoteDataSource.getChatHistory(
            otherUserId,
            page: page,
            limit: limit,
            sinceMessageId: sinceMessageId,
          );

          // Save sync time after successful first sync
          // Use server message timestamps (createdAt/updatedAt) instead of
          // client DateTime.now() to avoid clock skew issues and better match
          // WhatsApp-style server-driven sync watermarks.
          if (response.isSuccess && response.messages != null) {
            final messages = response.messages!;

            DateTime? maxTimestamp;
            for (final m in messages) {
              // Prefer updatedAt when available, otherwise fallback to createdAt
              final candidate = m.updatedAt.isAfter(m.createdAt)
                  ? m.updatedAt
                  : m.createdAt;
              if (maxTimestamp == null || candidate.isAfter(maxTimestamp)) {
                maxTimestamp = candidate;
              }
            }

            final syncTime = (maxTimestamp ?? DateTime.now()).toIso8601String();

            await ChatSyncMetadataTable.instance.saveLastSyncTime(
              currentUserId: currentUserId,
              otherUserId: otherUserId,
              lastSyncTime: syncTime,
            );
          }
        } else {
          // Subsequent syncs - use optimized sync API

          final syncResponse = await remoteDataSource.syncMessages(
            otherUserId: otherUserId,
            lastSyncTime: lastSyncTime,
            page: page,
            limit: limit,
          );

          // Update sync time if successful
          if (syncResponse.isSuccess &&
              syncResponse.syncInfo?.currentSyncTime != null) {
            await ChatSyncMetadataTable.instance.saveLastSyncTime(
              currentUserId: currentUserId,
              otherUserId: otherUserId,
              lastSyncTime: syncResponse.syncInfo!.currentSyncTime!,
            );
            _log(
              'GetChatHistory',
              '✅ Fetched ${syncResponse.messages?.length ?? 0} new messages',
            );
          }

          // Convert SyncMessagesResponseModel to ChatHistoryResponseModel for compatibility
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
            'GetChatHistory',
            '💾 Cached ${response.messages!.length} messages to local database',
          );
          _log('GetChatHistory', '✅ API call completed successfully');
          return ChatResult.success(response);
        } else {
          _log(
            'GetChatHistory',
            'Failed to get chat history: ${response.errorMessage}',
          );
          return ChatResult.failure(
            errorMessage:
                response.errorMessage ?? 'Failed to load chat history',
            errorCode: 'GET_CHAT_HISTORY_FAILED',
            statusCode: response.statusCode,
          );
        }
      } catch (e, st) {
        _log('GetChatHistory', 'Exception occurred: $e\n$st');
        return ChatResult.failure(
          errorMessage:
              'An unexpected error occurred while loading chat history',
          errorCode: 'GET_CHAT_HISTORY_EXCEPTION',
          exception: e is Exception ? e : Exception(e.toString()),
        );
      } finally {
        // RACE CONDITION PROTECTION: Always remove lock, even on error
        _ongoingSyncs.remove(syncKey);
      }
    } catch (e, st) {
      _log('GetChatHistory', 'Exception occurred: $e\n$st');
      return ChatResult.failure(
        errorMessage: 'An unexpected error occurred while loading chat history',
        errorCode: 'GET_CHAT_HISTORY_EXCEPTION',
        exception: e is Exception ? e : Exception(e.toString()),
      );
    }
  }

  Future<ChatResult<ChatHistoryResponseModel>> searchMessages({
    required String query,
    String? otherUserId,
  }) async {
    try {
      _log('SearchMessages', 'Searching messages with query: $query');

      if (query.trim().isEmpty) {
        return ChatResult.failure(
          errorMessage: 'Search query is required',
          errorCode: 'VALIDATION_ERROR',
        );
      }

      final response = await remoteDataSource.searchMessages(
        query: query,
        otherUserId: otherUserId,
      );

      if (response.isSuccess) {
        _log(
          'SearchMessages',
          'Found ${response.messages?.length ?? 0} messages',
        );
        return ChatResult.success(response);
      } else {
        _log(
          'SearchMessages',
          'Failed to search messages: ${response.errorMessage}',
        );
        return ChatResult.failure(
          errorMessage: response.errorMessage ?? 'Failed to search messages',
          errorCode: 'SEARCH_MESSAGES_FAILED',
          statusCode: response.statusCode,
        );
      }
    } catch (e, st) {
      _log('SearchMessages', 'Exception occurred: $e\n$st');
      return ChatResult.failure(
        errorMessage: 'An unexpected error occurred while searching',
        errorCode: 'SEARCH_MESSAGES_EXCEPTION',
        exception: e is Exception ? e : Exception(e.toString()),
      );
    }
  }

  void _log(String op, String message) {
    if (!kDebugMode) return;
    final isError = message.trimLeft().startsWith('❌');
    final isLocal =
        message.contains('local') ||
        message.contains('LOCAL') ||
        message.contains('Cached');
    if (_verboseLogs || isError) {
      final prefix = isLocal ? '💾 [LOCAL]' : '🌐 [REMOTE]';
      debugPrint('$prefix ChatHistory.$op: $message');
    }
  }
}
