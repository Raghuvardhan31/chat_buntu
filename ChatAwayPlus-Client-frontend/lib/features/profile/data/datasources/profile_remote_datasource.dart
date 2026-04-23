// lib/features/profile/data/datasources/profile_remote_datasource.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:chataway_plus/core/constants/api_url/api_urls.dart';
import 'package:chataway_plus/core/storage/token_storage.dart';

import '../models/requests/profile_request_models.dart';
import '../models/responses/profile_response_models.dart';

/// Remote datasource for profile operations
/// Handles all HTTP API calls related to profile functionality
abstract class ProfileRemoteDataSource {
  /// Get current user profile
  Future<GetProfileResponseModel> getCurrentUserProfile();

  /// Update profile name
  Future<UpdateProfileResponseModel> updateName(UpdateNameRequestModel request);

  /// Update profile status
  Future<UpdateProfileResponseModel> updateStatus(
    UpdateStatusRequestModel request,
  );

  /// Update profile picture
  Future<UpdateProfileResponseModel> updateProfilePicture(
    UpdateProfilePictureRequestModel request,
  );

  /// Delete profile picture
  Future<DeleteProfilePictureResponseModel> deleteProfilePicture();
}

/// Implementation of [ProfileRemoteDataSource] using HTTP client
class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  final http.Client httpClient;
  final TokenSecureStorage tokenStorage;

  static const int maxRetries = 2;
  static const Duration requestTimeout = Duration(seconds: 20);
  static const Duration baseRetryDelay = Duration(seconds: 2);

  ProfileRemoteDataSourceImpl({
    http.Client? httpClient,
    TokenSecureStorage? tokenStorage,
  }) : httpClient = httpClient ?? http.Client(),
       tokenStorage = tokenStorage ?? TokenSecureStorage.instance;

  void _log(String message) {
    if (kDebugMode) debugPrint(message);
  }

  @override
  Future<GetProfileResponseModel> getCurrentUserProfile() async {
    _log('[ProfileRemote] GET ${ApiUrls.getCurrentUserProfile}');
    return _executeWithRetry<GetProfileResponseModel>(
      operation: () => _getProfileRequest(),
      operationName: 'GetCurrentUserProfile',
    );
  }

  @override
  Future<UpdateProfileResponseModel> updateName(
    UpdateNameRequestModel request,
  ) async {
    if (!request.isValid()) {
      return UpdateProfileResponseModel.error(
        message: request.validationError ?? 'Invalid request',
        statusCode: 400,
      );
    }

    _log(
      '[ProfileRemote] PUT ${ApiUrls.currentUserProfileUpdate} (update name) -> firstName=${request.firstName}',
    );
    return _executeWithRetry<UpdateProfileResponseModel>(
      operation: () => _updateNameRequest(request),
      operationName: 'UpdateName',
      requestData: {'firstName': request.firstName},
    );
  }

  @override
  Future<UpdateProfileResponseModel> updateStatus(
    UpdateStatusRequestModel request,
  ) async {
    if (!request.isValid()) {
      return UpdateProfileResponseModel.error(
        message: request.validationError ?? 'Invalid request',
        statusCode: 400,
      );
    }

    _log(
      '[ProfileRemote] PUT ${ApiUrls.currentUserProfileUpdate} (update status)',
    );
    return _executeWithRetry<UpdateProfileResponseModel>(
      operation: () => _updateStatusRequest(request),
      operationName: 'UpdateStatus',
      requestData: {'content': request.content},
    );
  }

  @override
  Future<UpdateProfileResponseModel> updateProfilePicture(
    UpdateProfilePictureRequestModel request,
  ) async {
    if (!request.isValid()) {
      return UpdateProfileResponseModel.error(
        message: request.validationError ?? 'Invalid request',
        statusCode: 400,
      );
    }

    _log(
      '[ProfileRemote] PUT ${ApiUrls.currentUserProfileUpdate} (update profile picture)',
    );
    return _executeWithRetry<UpdateProfileResponseModel>(
      operation: () => _updateProfilePictureRequest(request),
      operationName: 'UpdateProfilePicture',
      requestData: {'imagePath': request.imagePath},
    );
  }

  @override
  Future<DeleteProfilePictureResponseModel> deleteProfilePicture() async {
    _log('[ProfileRemote] DELETE ${ApiUrls.deleteCurrentUserProfilePic}');
    return _executeWithRetry<DeleteProfilePictureResponseModel>(
      operation: () => _deleteProfilePictureRequest(),
      operationName: 'DeleteProfilePicture',
    );
  }

  // =============================
  // Internal Request Methods
  // =============================

  Future<GetProfileResponseModel> _getProfileRequest() async {
    final token = await tokenStorage.getToken();
    if (token == null) {
      return GetProfileResponseModel.error(
        message: 'Authentication required',
        statusCode: 401,
      );
    }

    final response = await httpClient
        .get(
          Uri.parse(ApiUrls.getCurrentUserProfile),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        )
        .timeout(requestTimeout);
    _log('[ProfileRemote] GET status=${response.statusCode}');
    _log('[ProfileRemote] GET response: ${response.body}');

    return _handleGetProfileResponse(response);
  }

  Future<UpdateProfileResponseModel> _updateNameRequest(
    UpdateNameRequestModel request,
  ) async {
    final token = await tokenStorage.getToken();
    if (token == null) {
      return UpdateProfileResponseModel.error(
        message: 'Authentication required',
        statusCode: 401,
      );
    }

    // Backend expects multipart/form-data with fields: name, optional lastName
    final uri = Uri.parse(ApiUrls.currentUserProfileUpdate);
    final multipartRequest = http.MultipartRequest('PUT', uri);
    multipartRequest.headers['Authorization'] = 'Bearer $token';
    final first = request.firstName.trim();
    final last = request.lastName?.trim();
    multipartRequest.fields['name'] = first;
    if (last != null && last.isNotEmpty) {
      multipartRequest.fields['lastName'] = last;
    }
    _log(
      '[ProfileRemote] UpdateName multipart fields: name="$first"${last != null && last.isNotEmpty ? ', lastName="$last"' : ''}',
    );

    final streamed = await multipartRequest.send().timeout(requestTimeout);
    final response = await http.Response.fromStream(streamed);
    _log('[ProfileRemote] UpdateName status=${response.statusCode}');
    _log('[ProfileRemote] UpdateName response: ${response.body}');

    return _handleUpdateProfileResponse(response);
  }

  Future<UpdateProfileResponseModel> _updateStatusRequest(
    UpdateStatusRequestModel request,
  ) async {
    final token = await tokenStorage.getToken();
    if (token == null) {
      return UpdateProfileResponseModel.error(
        message: 'Authentication required',
        statusCode: 401,
      );
    }

    // Send as multipart/form-data with multiple compatible keys for backend
    final uri = Uri.parse(ApiUrls.currentUserProfileUpdate);
    final multipartRequest = http.MultipartRequest('PUT', uri);
    multipartRequest.headers['Authorization'] = 'Bearer $token';
    final content = request.content.trim();
    // primary
    multipartRequest.fields['content'] = content;
    // alternates for compatibility
    multipartRequest.fields['statusContent'] = content;
    multipartRequest.fields['status'] = content;
    multipartRequest.fields['status_content'] = content;
    multipartRequest.fields['share_your_voice'] = content;
    _log(
      '[ProfileRemote] UpdateStatus multipart fields: content="$content", statusContent="$content", status="$content"',
    );

    final streamed = await multipartRequest.send().timeout(requestTimeout);
    final response = await http.Response.fromStream(streamed);
    _log('[ProfileRemote] UpdateStatus status=${response.statusCode}');
    _log('[ProfileRemote] UpdateStatus response: ${response.body}');
    return _handleUpdateProfileResponse(response);
  }

  Future<UpdateProfileResponseModel> _updateProfilePictureRequest(
    UpdateProfilePictureRequestModel request,
  ) async {
    final token = await tokenStorage.getToken();
    if (token == null) {
      return UpdateProfileResponseModel.error(
        message: 'Authentication required',
        statusCode: 401,
      );
    }

    final file = File(request.imagePath);
    if (!await file.exists()) {
      return UpdateProfileResponseModel.error(
        message: 'Image file not found',
        statusCode: 400,
      );
    }
    final uri = Uri.parse(ApiUrls.currentUserProfileUpdate);

    // Guess content type from file extension; default to jpeg
    final p = request.imagePath.toLowerCase();
    final subtype = p.endsWith('.png')
        ? 'png'
        : p.endsWith('.webp')
        ? 'webp'
        : p.endsWith('.heic')
        ? 'heic'
        : p.endsWith('.heif')
        ? 'heif'
        : 'jpeg';
    final mediaType = MediaType('image', subtype);
    final fileSize = await file.length();
    _log(
      '[ProfileRemote] UpdateProfilePicture request file: ${request.imagePath} ($fileSize bytes, type=${mediaType.type}/${mediaType.subtype})',
    );

    Future<http.Response> send(String method, String fieldName) async {
      final req = http.MultipartRequest(method, uri);
      req.headers['Authorization'] = 'Bearer $token';
      _log(
        '[ProfileRemote] UpdateProfilePicture attempt method=$method field="$fieldName"',
      );
      req.files.add(
        await http.MultipartFile.fromPath(
          fieldName,
          request.imagePath,
          contentType: mediaType,
        ),
      );

      final streamed = await req.send().timeout(requestTimeout);
      final resp = await http.Response.fromStream(streamed);

      _log(
        '[ProfileRemote] UpdateProfilePicture ($method:$fieldName) status=${resp.statusCode}',
      );
      _log(
        '[ProfileRemote] UpdateProfilePicture ($method:$fieldName) response: ${resp.body}',
      );
      return resp;
    }

    // Backend expects PUT to /users/profile. Do NOT try POST (endpoint returns 404).
    // Only retry alternate multipart field names when backend returns
    // "Unexpected field" (multer field mismatch). For other errors (like
    // S3 bucket endpoint/region errors), preserve and return the real error.
    final fieldCandidates = <String>[
      'chat_picture',
      // 'chatPicture',
      // 'profile_pic',
      // 'profilePic',
      // 'image',
    ];

    http.Response? lastResponse;
    for (final fieldName in fieldCandidates) {
      final response = await send('PUT', fieldName);
      lastResponse = response;

      if (response.statusCode == 200) {
        return _handleUpdateProfileResponse(response);
      }

      if (response.statusCode != 400) {
        // For non-400 responses, do not keep guessing field names.
        return _handleUpdateProfileResponse(response);
      }

      final msg = _extractErrorMessage(response);

      // Stop immediately and return the real backend/S3 error.
      if (msg.contains(
        'The bucket you are attempting to access must be addressed using the specified endpoint',
      )) {
        return _handleUpdateProfileResponse(response);
      }

      // Only then try next candidate (multer: wrong multipart field name)
      if (msg.contains('Unexpected field')) {
        continue;
      }

      // Any other 400: stop; it is not a field-name mismatch.
      return _handleUpdateProfileResponse(response);
    }

    return _handleUpdateProfileResponse(
      lastResponse ??
          http.Response(
            jsonEncode({
              'success': false,
              'message': 'Upload failed: no response',
            }),
            500,
          ),
    );
  }

  Future<DeleteProfilePictureResponseModel>
  _deleteProfilePictureRequest() async {
    final token = await tokenStorage.getToken();
    if (token == null) {
      return DeleteProfilePictureResponseModel.error(
        message: 'Authentication required',
        statusCode: 401,
      );
    }

    final response = await httpClient
        .delete(
          Uri.parse(ApiUrls.deleteCurrentUserProfilePic),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        )
        .timeout(requestTimeout);
    _log('[ProfileRemote] DeleteProfilePicture status=${response.statusCode}');
    _log(
      '[ProfileRemote] DeleteProfilePicture response: ${_short(response.body)}',
    );

    return _handleDeleteProfilePictureResponse(response);
  }

  // =============================
  // Response Handlers
  // =============================

  GetProfileResponseModel _handleGetProfileResponse(http.Response response) {
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return GetProfileResponseModel.fromJson(data);
    } else {
      return GetProfileResponseModel.error(
        message: _extractErrorMessage(response),
        statusCode: response.statusCode,
      );
    }
  }

  UpdateProfileResponseModel _handleUpdateProfileResponse(
    http.Response response,
  ) {
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return UpdateProfileResponseModel.fromJson(data);
    } else {
      return UpdateProfileResponseModel.error(
        message: _extractErrorMessage(response),
        statusCode: response.statusCode,
      );
    }
  }

  DeleteProfilePictureResponseModel _handleDeleteProfilePictureResponse(
    http.Response response,
  ) {
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return DeleteProfilePictureResponseModel.fromJson(data);
    } else {
      return DeleteProfilePictureResponseModel.error(
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

  String _short(String s, [int max = 600]) =>
      s.length <= max ? s : '${s.substring(0, max)}...(${s.length} chars)';

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
    } on SocketException {
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
