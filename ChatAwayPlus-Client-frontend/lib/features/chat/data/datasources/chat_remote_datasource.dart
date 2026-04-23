// ============================================================================
// CHAT REMOTE DATASOURCE - HTTP API Operations (REMOTE)
// ============================================================================
//
// 🎯 PURPOSE:
// Handles all REMOTE HTTP API operations for chat.
// Fetches data from server, implements retry logic and error handling.
//
// 🌐 REMOTE OPERATIONS:
// • sendMessage() - Send message via HTTP (REMOTE) - NOT USED, use WebSocket
// • deleteMessage() - Delete message via HTTP (REMOTE) - NOT USED, use WebSocket
// • getChatHistory() - Fetch chat history from server (REMOTE)
// • getChatContacts() - Fetch contacts from server (REMOTE)
// • getUnreadCount() - Fetch unread count from server (REMOTE)
// • searchMessages() - Search messages on server (REMOTE)
// • syncMessages() - Sync messages from server (REMOTE)
//
// ⚠️ NOTE: Send/Delete messages use WebSocket via UnifiedChatService
//
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:chataway_plus/core/constants/api_url/api_urls.dart';
import 'package:chataway_plus/core/storage/token_storage.dart';

import '../domain_models/requests/chat_request_models.dart';
import '../domain_models/responses/chat_response_models.dart';

/// Remote datasource for chat operations - HTTP API calls
/// All operations are REMOTE (network calls to server)
abstract class ChatRemoteDataSource {
  /// Send a message to another user
  Future<SendMessageResponseModel> sendMessage(SendMessageRequestModel request);

  /// Delete a message (only sender can delete their own message)
  Future<DeleteMessageResponseModel> deleteMessage(String messageId);

  /// Get message status
  Future<GetMessageStatusResponseModel> getMessageStatus(
    GetMessageStatusRequestModel request,
  );

  /// Get chat history with pagination
  /// [sinceMessageId] - Optional: Only return messages AFTER this message ID (incremental sync)
  Future<ChatHistoryResponseModel> getChatHistory(
    String otherUserId, {
    int page = 1,
    int limit = 50,
    String? sinceMessageId,
  });

  /// Sync messages from server using last sync time (optimized)
  Future<SyncMessagesResponseModel> syncMessages({
    String? otherUserId,
    required String lastSyncTime,
    int page = 1,
    int limit = 100,
  });

  /// Get chat contacts
  Future<ChatContactsResponseModel> getChatContacts();

  /// Get unread message count
  Future<UnreadCountResponseModel> getUnreadCount();

  /// Search messages
  Future<ChatHistoryResponseModel> searchMessages({
    required String query,
    String? otherUserId,
  });
}

/// Implementation of [ChatRemoteDataSource] using HTTP client
/// Provides comprehensive error handling, retry logic, and logging
class ChatRemoteDataSourceImpl implements ChatRemoteDataSource {
  final http.Client httpClient;
  final TokenSecureStorage tokenStorage;

  static const bool _verboseApiLogs = kDebugMode; // Only log in debug builds

  /// Maximum number of retry attempts for failed requests
  static const int maxRetries = 2;

  /// Request timeout duration
  static const Duration requestTimeout = Duration(seconds: 20);

  /// Base delay between retries (exponential backoff)
  static const Duration baseRetryDelay = Duration(seconds: 2);

  /// Create instance with optional HTTP client (for testing)
  ChatRemoteDataSourceImpl({
    http.Client? httpClient,
    TokenSecureStorage? tokenStorage,
  }) : httpClient = httpClient ?? http.Client(),
       tokenStorage = tokenStorage ?? TokenSecureStorage.instance;

  @override
  Future<SendMessageResponseModel> sendMessage(
    SendMessageRequestModel request,
  ) async {
    if (!request.isValid()) {
      _logError('SendMessage', 'Invalid request: ${request.validationError}');
      return SendMessageResponseModel.error(
        message: request.validationError ?? 'Invalid request',
        statusCode: 400,
      );
    }

    return _executeWithRetry<SendMessageResponseModel>(
      operation: () => _sendMessageRequest(request),
      operationName: 'SendMessage',
      requestData: {'receiverId': request.receiverId},
    );
  }

  @override
  Future<DeleteMessageResponseModel> deleteMessage(String messageId) async {
    if (messageId.isEmpty) {
      return DeleteMessageResponseModel.error(
        message: 'Message ID is required',
        statusCode: 400,
      );
    }

    return _executeWithRetry<DeleteMessageResponseModel>(
      operation: () => _deleteMessageRequest(messageId),
      operationName: 'DeleteMessage',
      requestData: {'messageId': messageId},
    );
  }

  @override
  Future<GetMessageStatusResponseModel> getMessageStatus(
    GetMessageStatusRequestModel request,
  ) async {
    if (!request.isValid()) {
      return GetMessageStatusResponseModel.error(
        message: request.validationError ?? 'Invalid request',
        statusCode: 400,
      );
    }

    return _executeWithRetry<GetMessageStatusResponseModel>(
      operation: () => _getMessageStatusRequest(request),
      operationName: 'GetMessageStatus',
      requestData: {'messageIds': request.messageIds},
    );
  }

  @override
  Future<ChatHistoryResponseModel> getChatHistory(
    String otherUserId, {
    int page = 1,
    int limit = 50,
    String? sinceMessageId,
  }) async {
    if (otherUserId.isEmpty) {
      return ChatHistoryResponseModel.error(
        message: 'User ID is required',
        statusCode: 400,
      );
    }

    return _executeWithRetry<ChatHistoryResponseModel>(
      operation: () =>
          _getChatHistoryRequest(otherUserId, page, limit, sinceMessageId),
      operationName: 'GetChatHistory',
      requestData: {
        'userId': otherUserId,
        'page': page,
        'limit': limit,
        'sinceMessageId': sinceMessageId,
      },
    );
  }

  @override
  Future<SyncMessagesResponseModel> syncMessages({
    String? otherUserId,
    required String lastSyncTime,
    int page = 1,
    int limit = 100,
  }) async {
    if (lastSyncTime.isEmpty) {
      return SyncMessagesResponseModel.error(
        message: 'lastSyncTime is required',
        statusCode: 400,
      );
    }

    return _executeWithRetry<SyncMessagesResponseModel>(
      operation: () => _syncMessagesRequest(
        otherUserId: otherUserId,
        lastSyncTime: lastSyncTime,
        page: page,
        limit: limit,
      ),
      operationName: 'SyncMessages',
      requestData: {
        'otherUserId': otherUserId,
        'lastSyncTime': lastSyncTime,
        'page': page,
        'limit': limit,
      },
    );
  }

  @override
  Future<ChatContactsResponseModel> getChatContacts() async {
    return _executeWithRetry<ChatContactsResponseModel>(
      operation: () => _getChatContactsRequest(),
      operationName: 'GetChatContacts',
      requestData: {},
    );
  }

  @override
  Future<UnreadCountResponseModel> getUnreadCount() async {
    return _executeWithRetry<UnreadCountResponseModel>(
      operation: () => _getUnreadCountRequest(),
      operationName: 'GetUnreadCount',
      requestData: {},
    );
  }

  @override
  Future<ChatHistoryResponseModel> searchMessages({
    required String query,
    String? otherUserId,
  }) async {
    if (query.isEmpty) {
      return ChatHistoryResponseModel.error(
        message: 'Search query is required',
        statusCode: 400,
      );
    }

    return _executeWithRetry<ChatHistoryResponseModel>(
      operation: () => _searchMessagesRequest(query, otherUserId),
      operationName: 'SearchMessages',
      requestData: {'query': query, 'otherUserId': otherUserId},
    );
  }

  //===========================================================================
  // PRIVATE HELPER METHODS FOR API REQUESTS
  //===========================================================================

  Future<SendMessageResponseModel> _sendMessageRequest(
    SendMessageRequestModel request,
  ) async {
    final token = await _getAuthToken();
    if (token == null) {
      return SendMessageResponseModel.error(
        message: 'Not authenticated',
        statusCode: 401,
      );
    }

    final response = await httpClient
        .post(
          Uri.parse(ApiUrls.sendMessage),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(request.toJson()),
        )
        .timeout(requestTimeout);

    // print(
    //   'ChatRemoteDataSource [_sendMessageRequest]: Response Body: ${response.body}',
    // );

    return _handleResponse<SendMessageResponseModel>(
      response,
      (json) => SendMessageResponseModel.fromJson(json),
    );
  }

  Future<DeleteMessageResponseModel> _deleteMessageRequest(
    String messageId,
  ) async {
    final token = await _getAuthToken();
    if (token == null) {
      return DeleteMessageResponseModel.error(
        message: 'Not authenticated',
        statusCode: 401,
      );
    }

    final response = await httpClient
        .delete(
          Uri.parse(ApiUrls.deleteMessage(messageId)),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        )
        .timeout(requestTimeout);

    return _handleResponse<DeleteMessageResponseModel>(
      response,
      (json) => DeleteMessageResponseModel.fromJson(json),
    );
  }

  Future<GetMessageStatusResponseModel> _getMessageStatusRequest(
    GetMessageStatusRequestModel request,
  ) async {
    final token = await _getAuthToken();
    if (token == null) {
      return GetMessageStatusResponseModel.error(
        message: 'Not authenticated',
        statusCode: 401,
      );
    }

    final response = await httpClient
        .post(
          Uri.parse(ApiUrls.getMessageStatus),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(request.toJson()),
        )
        .timeout(requestTimeout);

    return _handleResponse<GetMessageStatusResponseModel>(
      response,
      (json) => GetMessageStatusResponseModel.fromJson(json),
    );
  }

  Future<ChatHistoryResponseModel> _getChatHistoryRequest(
    String otherUserId,
    int page,
    int limit,
    String? sinceMessageId,
  ) async {
    final token = await _getAuthToken();
    if (token == null) {
      return ChatHistoryResponseModel.error(
        message: 'Not authenticated',
        statusCode: 401,
      );
    }

    // Build query parameters - include sinceMessageId for incremental sync
    final queryParams = {'page': page.toString(), 'limit': limit.toString()};
    if (sinceMessageId != null && sinceMessageId.isNotEmpty) {
      queryParams['sincechatId'] = sinceMessageId;
    }

    final uri = Uri.parse(
      ApiUrls.getChatHistoryByUserId(otherUserId),
    ).replace(queryParameters: queryParams);

    final isIncremental = sinceMessageId != null;
    if (_verboseApiLogs) {
      debugPrint('');
      debugPrint('🟦🟦🟦 CHAT HISTORY API CALL 🟦🟦🟦');
      debugPrint('🟦 Time: ${DateTime.now().toIso8601String()}');
      debugPrint('🟦 Type: ${isIncremental ? "INCREMENTAL" : "FULL"} SYNC');
      debugPrint('🟦 OtherUserId: $otherUserId');
      debugPrint('🟦 Page: $page, Limit: $limit');
      if (isIncremental) debugPrint('🟦 sinceMessageId: $sinceMessageId');
      debugPrint('🟦 URL: $uri');
    }

    final response = await httpClient
        .get(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        )
        .timeout(requestTimeout);

    if (_verboseApiLogs) {
      debugPrint(
        '🟦 CHAT HISTORY API RESPONSE: status=${response.statusCode}, bytes=${response.body.length}',
      );
      debugPrint('🟦🟦🟦 END CHAT HISTORY API 🟦🟦🟦');
      debugPrint('');
    }

    return _handleResponse<ChatHistoryResponseModel>(
      response,
      (json) => ChatHistoryResponseModel.fromJson(json),
    );
  }

  Future<SyncMessagesResponseModel> _syncMessagesRequest({
    String? otherUserId,
    required String lastSyncTime,
    required int page,
    required int limit,
  }) async {
    final token = await _getAuthToken();
    if (token == null) {
      return SyncMessagesResponseModel.error(
        message: 'Not authenticated',
        statusCode: 401,
      );
    }

    final body = {
      'lastSyncTime': lastSyncTime,
      if (otherUserId != null && otherUserId.isNotEmpty)
        'otherUserId': otherUserId,
      'page': page,
      'limit': limit,
    };

    if (_verboseApiLogs) {
      debugPrint('');
      debugPrint('🟨🟨🟨 SYNC MESSAGES API CALL 🟨🟨🟨');
      debugPrint('🟨 Time: ${DateTime.now().toIso8601String()}');
      debugPrint('🟨 OtherUserId: ${otherUserId ?? "(all)"}');
      debugPrint('🟨 LastSyncTime: $lastSyncTime');
      debugPrint('🟨 Page: $page, Limit: $limit');
      debugPrint('🟨 URL: ${ApiUrls.syncMessages}');
    }

    final response = await httpClient
        .post(
          Uri.parse(ApiUrls.syncMessages),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(body),
        )
        .timeout(requestTimeout);

    if (_verboseApiLogs) {
      debugPrint(
        '🟨 SYNC MESSAGES API RESPONSE: status=${response.statusCode}, bytes=${response.body.length}',
      );
      debugPrint('🟨🟨🟨 END SYNC MESSAGES API 🟨🟨🟨');
      debugPrint('');
    }

    return _handleResponse<SyncMessagesResponseModel>(
      response,
      (json) => SyncMessagesResponseModel.fromJson(json),
    );
  }

  Future<ChatContactsResponseModel> _getChatContactsRequest() async {
    final token = await _getAuthToken();
    if (token == null) {
      return ChatContactsResponseModel.error(
        message: 'Not authenticated',
        statusCode: 401,
      );
    }

    final url = ApiUrls.getChatContacts;
    final uri = Uri.parse(url);
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    };

    if (_verboseApiLogs) {
      debugPrint('');
      debugPrint('🟩🟩🟩 CONTACTS API CALL 🟩🟩🟩');
      debugPrint('🟩 Time: ${DateTime.now().toIso8601String()}');
      debugPrint('🟩 URL: $url');
    }

    final sw = Stopwatch()..start();
    final response = await httpClient
        .get(uri, headers: headers)
        .timeout(requestTimeout);
    sw.stop();

    if (_verboseApiLogs) {
      debugPrint(
        '🟩 CONTACTS API RESPONSE: status=${response.statusCode}, bytes=${response.body.length}, time=${sw.elapsedMilliseconds}ms',
      );
      debugPrint('🟩🟩🟩 END CONTACTS API 🟩🟩🟩');
      debugPrint('');
    }

    return _handleResponse<ChatContactsResponseModel>(
      response,
      (json) => ChatContactsResponseModel.fromJson(json),
    );
  }

  Future<UnreadCountResponseModel> _getUnreadCountRequest() async {
    final token = await _getAuthToken();
    if (token == null) {
      return UnreadCountResponseModel.error(
        message: 'Not authenticated',
        statusCode: 401,
      );
    }

    final response = await httpClient
        .get(
          Uri.parse(ApiUrls.getUnreadCount),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        )
        .timeout(requestTimeout);

    return _handleResponse<UnreadCountResponseModel>(
      response,
      (json) => UnreadCountResponseModel.fromJson(json),
    );
  }

  Future<ChatHistoryResponseModel> _searchMessagesRequest(
    String query,
    String? otherUserId,
  ) async {
    final token = await _getAuthToken();
    if (token == null) {
      return ChatHistoryResponseModel.error(
        message: 'Not authenticated',
        statusCode: 401,
      );
    }

    final queryParams = {
      'query': query,
      if (otherUserId != null) 'otherUserId': otherUserId,
    };

    final uri = Uri.parse(
      ApiUrls.searchMessages,
    ).replace(queryParameters: queryParams);

    final response = await httpClient
        .get(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        )
        .timeout(requestTimeout);

    return _handleResponse<ChatHistoryResponseModel>(
      response,
      (json) => ChatHistoryResponseModel.fromJson(json),
    );
  }

  //===========================================================================
  // UTILITY METHODS
  //===========================================================================

  /// Get authentication token from secure storage
  Future<String?> _getAuthToken() async {
    try {
      return await tokenStorage.getToken();
    } catch (e) {
      _logError('GetAuthToken', 'Failed to get auth token: $e');
      return null;
    }
  }

  /// Execute operation with retry logic
  Future<T> _executeWithRetry<T extends ChatResponseModel>({
    required Future<T> Function() operation,
    required String operationName,
    required Map<String, dynamic> requestData,
  }) async {
    int attempt = 0;

    while (attempt <= maxRetries) {
      try {
        _logInfo(operationName, 'Attempt ${attempt + 1}/${maxRetries + 1}');
        final result = await operation();
        // Only log success if the API response indicates success
        if (result.isSuccess) {
          _logInfo(operationName, 'Success');
          return result;
        }

        // Non-success response: decide whether to retry based on status code
        final sc = result.statusCode ?? 0;
        _logError(
          operationName,
          'API error: ${result.errorMessage ?? 'Unknown error'} (status $sc)',
        );

        final shouldRetry =
            sc >= 500 || sc == 0; // retry only on 5xx or unknown
        attempt++;
        if (!shouldRetry || attempt > maxRetries) {
          return result; // give back the error response
        }
        await Future.delayed(baseRetryDelay * attempt);
        continue;
      } on TimeoutException catch (e) {
        _logError(operationName, 'Timeout on attempt ${attempt + 1}: $e');
        attempt++;
        if (attempt > maxRetries) {
          return _createErrorResponse<T>(
            'Request timeout. Please check your connection.',
            408,
          );
        }
        await Future.delayed(baseRetryDelay * attempt);
      } on SocketException catch (e) {
        _logError(operationName, 'Network error on attempt ${attempt + 1}: $e');
        attempt++;
        if (attempt > maxRetries) {
          return _createErrorResponse<T>(
            'Network error. Please check your internet connection.',
            503,
          );
        }
        await Future.delayed(baseRetryDelay * attempt);
      } catch (e) {
        _logError(operationName, 'Error: $e');
        return _createErrorResponse<T>('An unexpected error occurred', 500);
      }
    }

    return _createErrorResponse<T>('Max retries exceeded', 500);
  }

  /// Handle HTTP response and parse JSON
  T _handleResponse<T>(
    http.Response response,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    try {
      if (_verboseApiLogs) {
        debugPrint(
          'ChatRemoteDataSource [HandleResponse]: Status ${response.statusCode}',
        );
        debugPrint(
          'ChatRemoteDataSource [HandleResponse]: Body: ${response.body}',
        );
      }

      final jsonData = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return fromJson(jsonData);
      } else {
        return _createErrorResponse<T>(
          jsonData['error']?.toString() ?? 'Request failed',
          response.statusCode,
        );
      }
    } catch (e, stackTrace) {
      _logError('HandleResponse', 'Parse error: $e');
      if (_verboseApiLogs) {
        debugPrint(
          'ChatRemoteDataSource [HandleResponse] StackTrace: $stackTrace',
        );
      }
      return _createErrorResponse<T>(
        'Failed to parse response',
        response.statusCode,
      );
    }
  }

  /// Create error response based on type
  T _createErrorResponse<T>(String message, int statusCode) {
    if (T == SendMessageResponseModel) {
      return SendMessageResponseModel.error(
            message: message,
            statusCode: statusCode,
          )
          as T;
    } else if (T == DeleteMessageResponseModel) {
      return DeleteMessageResponseModel.error(
            message: message,
            statusCode: statusCode,
          )
          as T;
    } else if (T == GetMessageStatusResponseModel) {
      return GetMessageStatusResponseModel.error(
            message: message,
            statusCode: statusCode,
          )
          as T;
    } else if (T == ChatHistoryResponseModel) {
      return ChatHistoryResponseModel.error(
            message: message,
            statusCode: statusCode,
          )
          as T;
    } else if (T == ChatContactsResponseModel) {
      return ChatContactsResponseModel.error(
            message: message,
            statusCode: statusCode,
          )
          as T;
    } else if (T == UnreadCountResponseModel) {
      return UnreadCountResponseModel.error(
            message: message,
            statusCode: statusCode,
          )
          as T;
    } else if (T == SyncMessagesResponseModel) {
      return SyncMessagesResponseModel.error(
            message: message,
            statusCode: statusCode,
          )
          as T;
    }

    throw UnimplementedError('Unknown response type: $T');
  }

  void _logInfo(String operation, String message) {
    if (_verboseApiLogs && kDebugMode) {
      debugPrint('🌐 [REMOTE] $operation: $message');
    }
  }

  void _logError(String operation, String message) {
    if (_verboseApiLogs && kDebugMode) {
      debugPrint('❌ [REMOTE] $operation ERROR: $message');
    }
  }
}
