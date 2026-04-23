// ============================================================================
// GET CHAT CONTACTS REPOSITORY - Fetch Chat Contacts (REMOTE + LOCAL)
// ============================================================================
//
// 🎯 PURPOSE:
// Fetches chat contacts from server with local database fallback.
// Provides offline support when server is unavailable.
//
// 🌐 REMOTE OPERATIONS:
// • getChatContacts() - Fetch from server via HTTP API (REMOTE)
// • getUnreadCount() - Fetch unread count from server (REMOTE)
//
// 💾 LOCAL OPERATIONS:
// • getChatContactsFromLocal() - Fallback to SQLite when API fails (LOCAL)
//
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:chataway_plus/features/chat/data/domain_models/responses/chat_response_models.dart';
import 'package:chataway_plus/features/chat/data/domain_models/responses/chat_result.dart';
import '../../datasources/chat_remote_datasource.dart';
import '../../datasources/chat_local_datasource.dart';

/// Repository for fetching chat contacts (REMOTE with LOCAL fallback)
class GetChatContactsRepository {
  final ChatRemoteDataSource remoteDataSource;
  final ChatLocalDataSource localDataSource;

  static const bool _verboseLogs = true; // Enable for API debugging

  GetChatContactsRepository({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  Future<ChatResult<ChatContactsResponseModel>> getChatContacts() async {
    try {
      _log('GetChatContacts', 'Fetching chat contacts from API');

      final response = await remoteDataSource.getChatContacts();

      if (response.isSuccess) {
        _log(
          'GetChatContacts',
          'Retrieved ${response.data?.length ?? 0} contacts from API',
        );
        return ChatResult.success(response);
      } else {
        // API failed, try local database as fallback
        _log(
          'GetChatContacts',
          'API failed: ${response.errorMessage}, trying local database',
        );
        return await _getChatContactsFromLocal();
      }
    } catch (e) {
      // Exception occurred, try local database as fallback
      _log('GetChatContacts', 'API exception: $e, trying local database');
      return await _getChatContactsFromLocal();
    }
  }

  /// Get chat contacts from local database (fallback when API fails)
  Future<ChatResult<ChatContactsResponseModel>>
  _getChatContactsFromLocal() async {
    try {
      _log('GetChatContactsFromLocal', 'Fetching from local database');

      final contacts = await localDataSource.getChatContactsFromLocal();

      _log(
        'GetChatContactsFromLocal',
        'Retrieved ${contacts.length} contacts from local DB',
      );

      // Create response model from local data
      final response = ChatContactsResponseModel(
        success: true,
        data: contacts,
        error: null,
        statusCode: 200,
      );

      return ChatResult.success(response);
    } catch (e, st) {
      _log('GetChatContactsFromLocal', 'Failed to get from local DB: $e\n$st');
      return ChatResult.failure(
        errorMessage: 'Failed to load contacts from local database',
        errorCode: 'GET_LOCAL_CONTACTS_FAILED',
        exception: e is Exception ? e : Exception(e.toString()),
      );
    }
  }

  Future<ChatResult<UnreadCountResponseModel>> getUnreadCount() async {
    try {
      _log('GetUnreadCount', 'Fetching unread count');

      final response = await remoteDataSource.getUnreadCount();

      if (response.isSuccess) {
        _log('GetUnreadCount', 'Unread count: ${response.unreadCount ?? 0}');
        return ChatResult.success(response);
      } else {
        _log(
          'GetUnreadCount',
          'Failed to get unread count: ${response.errorMessage}',
        );
        return ChatResult.failure(
          errorMessage: response.errorMessage ?? 'Failed to load unread count',
          errorCode: 'GET_UNREAD_COUNT_FAILED',
          statusCode: response.statusCode,
        );
      }
    } catch (e, st) {
      _log('GetUnreadCount', 'Exception occurred: $e\n$st');
      return ChatResult.failure(
        errorMessage: 'An unexpected error occurred',
        errorCode: 'GET_UNREAD_COUNT_EXCEPTION',
        exception: e is Exception ? e : Exception(e.toString()),
      );
    }
  }

  void _log(String op, String message) {
    if (_verboseLogs && kDebugMode) {
      final isLocal = op.contains('Local');
      final prefix = isLocal ? '💾 [LOCAL]' : '🌐 [REMOTE]';
      debugPrint('$prefix Contacts.$op: $message');
    }
  }
}
