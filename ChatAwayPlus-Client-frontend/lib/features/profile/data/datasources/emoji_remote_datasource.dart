// lib/features/profile/data/datasources/emoji_remote_datasource.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:chataway_plus/core/constants/api_url/api_urls.dart';
import 'package:chataway_plus/core/storage/token_storage.dart';

import '../models/requests/emoji_request_models.dart';
import '../models/responses/emoji_response_models.dart';

/// Remote datasource for emoji operations
/// Handles all HTTP API calls related to emoji functionality
abstract class EmojiRemoteDataSource {
  /// Get current user emoji
  Future<GetEmojiResponseModel> getCurrentEmoji();

  /// Get all users' emoji updates
  Future<GetAllEmojisResponseModel> getAllEmojiUpdates();

  /// Create emoji (POST without ID, server returns resource id)
  Future<EmojiUpdateResponseModel> createEmoji(EmojiUpdateRequestModel request);

  /// Update emoji (PUT with ID)
  Future<EmojiUpdateResponseModel> updateEmoji(
    String id,
    EmojiUpdateRequestModel request,
  );

  /// Delete emoji
  Future<DeleteEmojiResponseModel> deleteEmoji(
    String id,
    DeleteEmojiRequestModel request,
  );
}

/// Implementation of [EmojiRemoteDataSource] using HTTP client
class EmojiRemoteDataSourceImpl implements EmojiRemoteDataSource {
  final http.Client httpClient;
  final TokenSecureStorage tokenStorage;

  static const int maxRetries = 2;
  static const Duration requestTimeout = Duration(seconds: 20);
  static const Duration baseRetryDelay = Duration(seconds: 2);

  EmojiRemoteDataSourceImpl({
    http.Client? httpClient,
    TokenSecureStorage? tokenStorage,
  }) : httpClient = httpClient ?? http.Client(),
       tokenStorage = tokenStorage ?? TokenSecureStorage.instance;

  void _log(String message) {
    if (kDebugMode) debugPrint(message);
  }

  @override
  Future<GetEmojiResponseModel> getCurrentEmoji() async {
    return _executeWithRetry<GetEmojiResponseModel>(
      operation: () => _getEmojiRequest(),
      operationName: 'GetCurrentEmoji',
    );
  }

  @override
  Future<GetAllEmojisResponseModel> getAllEmojiUpdates() async {
    return _executeWithRetry<GetAllEmojisResponseModel>(
      operation: () => _getAllEmojisRequest(),
      operationName: 'GetAllEmojiUpdates',
    );
  }

  @override
  Future<EmojiUpdateResponseModel> createEmoji(
    EmojiUpdateRequestModel request,
  ) async {
    if (!request.isValid()) {
      return EmojiUpdateResponseModel.error(
        message: request.validationError ?? 'Invalid request',
        statusCode: 400,
      );
    }

    return _executeWithRetry<EmojiUpdateResponseModel>(
      operation: () => _createEmojiRequest(request),
      operationName: 'CreateEmoji',
      requestData: request.toJson(),
    );
  }

  @override
  Future<EmojiUpdateResponseModel> updateEmoji(
    String id,
    EmojiUpdateRequestModel request,
  ) async {
    if (!request.isValid()) {
      return EmojiUpdateResponseModel.error(
        message: request.validationError ?? 'Invalid request',
        statusCode: 400,
      );
    }

    return _executeWithRetry<EmojiUpdateResponseModel>(
      operation: () => _updateEmojiRequest(id, request),
      operationName: 'UpdateEmoji',
      requestData: request.toJson(),
    );
  }

  @override
  Future<DeleteEmojiResponseModel> deleteEmoji(
    String id,
    DeleteEmojiRequestModel request,
  ) async {
    if (!request.isValid()) {
      return DeleteEmojiResponseModel.error(
        message: request.validationError ?? 'Invalid request',
        statusCode: 400,
      );
    }

    return _executeWithRetry<DeleteEmojiResponseModel>(
      operation: () => _deleteEmojiRequest(id, request),
      operationName: 'DeleteEmoji',
      requestData: request.toJson(),
    );
  }

  // =============================
  // Internal Request Methods
  // =============================

  Future<GetEmojiResponseModel> _getEmojiRequest() async {
    final token = await tokenStorage.getToken();
    if (token == null) {
      return GetEmojiResponseModel.error(
        message: 'Authentication required',
        statusCode: 401,
      );
    }

    final url = ApiUrls.emojiMyCurrent;
    _log('[EmojiRemote] GET $url');

    final response = await httpClient
        .get(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        )
        .timeout(requestTimeout);

    _log(
      '[EmojiRemote] <- GET $url status=${response.statusCode} bodyLen=${response.body.length}',
    );
    _log('[EmojiRemote] <- GET $url body=${response.body}');

    return _handleGetEmojiResponse(response);
  }

  Future<GetAllEmojisResponseModel> _getAllEmojisRequest() async {
    final token = await tokenStorage.getToken();
    if (token == null) {
      return GetAllEmojisResponseModel.error(
        message: 'Authentication required',
        statusCode: 401,
      );
    }

    final url = ApiUrls.emojiAllUpdates;
    _log('[EmojiRemote] GET $url');

    final response = await httpClient
        .get(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        )
        .timeout(requestTimeout);

    _log(
      '[EmojiRemote] <- GET $url status=${response.statusCode} bodyLen=${response.body.length}',
    );
    _log('[EmojiRemote] <- GET $url body=${response.body}');

    return _handleGetAllEmojisResponse(response);
  }

  Future<EmojiUpdateResponseModel> _createEmojiRequest(
    EmojiUpdateRequestModel request,
  ) async {
    final token = await tokenStorage.getToken();
    if (token == null) {
      return EmojiUpdateResponseModel.error(
        message: 'Authentication required',
        statusCode: 401,
      );
    }

    final url = ApiUrls.emojiUpdatesBase;
    final body = jsonEncode(request.toJson());
    _log('[EmojiRemote] POST (create) $url bodyLen=${body.length}');

    final response = await httpClient
        .post(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: body,
        )
        .timeout(requestTimeout);

    _log(
      '[EmojiRemote] <- POST (create) $url status=${response.statusCode} bodyLen=${response.body.length}',
    );
    _log('[EmojiRemote] <- POST (create) $url body=${response.body}');

    return _handleUpdateEmojiResponse(response);
  }

  Future<EmojiUpdateResponseModel> _updateEmojiRequest(
    String id,
    EmojiUpdateRequestModel request,
  ) async {
    final token = await tokenStorage.getToken();
    if (token == null) {
      return EmojiUpdateResponseModel.error(
        message: 'Authentication required',
        statusCode: 401,
      );
    }

    final url = ApiUrls.updateEmojiById(id);
    final body = jsonEncode(request.toJson());
    _log('[EmojiRemote] PUT $url id=$id bodyLen=${body.length}');

    final response = await httpClient
        .put(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: body,
        )
        .timeout(requestTimeout);

    _log(
      '[EmojiRemote] <- PUT $url status=${response.statusCode} bodyLen=${response.body.length}',
    );
    _log('[EmojiRemote] <- PUT $url body=${response.body}');

    return _handleUpdateEmojiResponse(response);
  }

  Future<DeleteEmojiResponseModel> _deleteEmojiRequest(
    String id,
    DeleteEmojiRequestModel request,
  ) async {
    final token = await tokenStorage.getToken();
    if (token == null) {
      return DeleteEmojiResponseModel.error(
        message: 'Authentication required',
        statusCode: 401,
      );
    }

    final url = ApiUrls.deleteEmojiById(id);
    final body = jsonEncode(request.toJson());
    _log('[EmojiRemote] DELETE $url id=$id bodyLen=${body.length}');

    final response = await httpClient
        .delete(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: body,
        )
        .timeout(requestTimeout);

    _log(
      '[EmojiRemote] <- DELETE $url status=${response.statusCode} bodyLen=${response.body.length}',
    );
    _log('[EmojiRemote] <- DELETE $url body=${response.body}');

    return _handleDeleteEmojiResponse(response);
  }

  // =============================
  // Response Handlers
  // =============================

  GetEmojiResponseModel _handleGetEmojiResponse(http.Response response) {
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return GetEmojiResponseModel.fromJson(data);
    } else {
      return GetEmojiResponseModel.error(
        message: _extractErrorMessage(response),
        statusCode: response.statusCode,
      );
    }
  }

  GetAllEmojisResponseModel _handleGetAllEmojisResponse(
    http.Response response,
  ) {
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return GetAllEmojisResponseModel.fromJson(data);
    } else {
      return GetAllEmojisResponseModel.error(
        message: _extractErrorMessage(response),
        statusCode: response.statusCode,
      );
    }
  }

  EmojiUpdateResponseModel _handleUpdateEmojiResponse(http.Response response) {
    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return EmojiUpdateResponseModel.fromJson(data);
    } else {
      return EmojiUpdateResponseModel.error(
        message: _extractErrorMessage(response),
        statusCode: response.statusCode,
      );
    }
  }

  DeleteEmojiResponseModel _handleDeleteEmojiResponse(http.Response response) {
    if (response.statusCode == 200 || response.statusCode == 204) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return DeleteEmojiResponseModel.fromJson(data);
    } else {
      return DeleteEmojiResponseModel.error(
        message: _extractErrorMessage(response),
        statusCode: response.statusCode,
      );
    }
  }

  String _extractErrorMessage(http.Response response) {
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['message'] as String? ?? 'Request failed';
    } catch (_) {
      return 'Request failed with status ${response.statusCode}';
    }
  }

  // =============================
  // Retry Logic
  // =============================

  Future<T> _executeWithRetry<T>({
    required Future<T> Function() operation,
    required String operationName,
    Map<String, dynamic>? requestData,
    int currentAttempt = 1,
  }) async {
    try {
      return await operation();
    } on TimeoutException {
      if (currentAttempt <= maxRetries) {
        await Future.delayed(baseRetryDelay * currentAttempt);
        return _executeWithRetry(
          operation: operation,
          operationName: operationName,
          requestData: requestData,
          currentAttempt: currentAttempt + 1,
        );
      }
      rethrow;
    } on http.ClientException {
      if (currentAttempt <= maxRetries) {
        await Future.delayed(baseRetryDelay * currentAttempt);
        return _executeWithRetry(
          operation: operation,
          operationName: operationName,
          requestData: requestData,
          currentAttempt: currentAttempt + 1,
        );
      }
      rethrow;
    }
  }
}
