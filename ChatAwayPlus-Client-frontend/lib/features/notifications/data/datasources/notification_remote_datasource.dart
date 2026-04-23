import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:chataway_plus/core/constants/api_url/api_urls.dart';
import 'package:chataway_plus/core/storage/token_storage.dart';
import '../domain_models/notification_response_models.dart';

abstract class NotificationRemoteDataSource {
  Future<GetNotificationsResponseModel> getNotifications({int limit = 50, int offset = 0});
  Future<NotificationActionResponseModel> markAsRead(String id);
  Future<NotificationActionResponseModel> markAllAsRead();
  Future<NotificationActionResponseModel> deleteNotification(String id);
}

class NotificationRemoteDataSourceImpl implements NotificationRemoteDataSource {
  final http.Client httpClient;
  final TokenSecureStorage tokenStorage;

  NotificationRemoteDataSourceImpl({
    http.Client? httpClient,
    TokenSecureStorage? tokenStorage,
  }) : httpClient = httpClient ?? http.Client(),
       tokenStorage = tokenStorage ?? TokenSecureStorage.instance;

  static const Duration requestTimeout = Duration(seconds: 20);

  @override
  Future<GetNotificationsResponseModel> getNotifications({int limit = 50, int offset = 0}) async {
    return _executeRequest<GetNotificationsResponseModel>(
      operation: () async {
        final token = await _getAuthToken();
        final uri = Uri.parse(ApiUrls.getNotifications).replace(
          queryParameters: {'limit': limit.toString(), 'offset': offset.toString()},
        );
        final response = await httpClient.get(
          uri,
          headers: _getHeaders(token),
        ).timeout(requestTimeout);

        return _handleResponse<GetNotificationsResponseModel>(
          response,
          (json) => GetNotificationsResponseModel.fromJson(json),
          (msg, code) => GetNotificationsResponseModel.error(message: msg, statusCode: code),
        );
      },
    );
  }

  @override
  Future<NotificationActionResponseModel> markAsRead(String id) async {
    return _executeRequest<NotificationActionResponseModel>(
      operation: () async {
        final token = await _getAuthToken();
        final response = await httpClient.patch(
          Uri.parse(ApiUrls.markNotificationRead(id)),
          headers: _getHeaders(token),
        ).timeout(requestTimeout);

        return _handleResponse<NotificationActionResponseModel>(
          response,
          (json) => NotificationActionResponseModel.fromJson(json),
          (msg, code) => NotificationActionResponseModel.error(message: msg, statusCode: code),
        );
      },
    );
  }

  @override
  Future<NotificationActionResponseModel> markAllAsRead() async {
    return _executeRequest<NotificationActionResponseModel>(
      operation: () async {
        final token = await _getAuthToken();
        final response = await httpClient.post(
          Uri.parse(ApiUrls.markAllNotificationsRead),
          headers: _getHeaders(token),
        ).timeout(requestTimeout);

        return _handleResponse<NotificationActionResponseModel>(
          response,
          (json) => NotificationActionResponseModel.fromJson(json),
          (msg, code) => NotificationActionResponseModel.error(message: msg, statusCode: code),
        );
      },
    );
  }

  @override
  Future<NotificationActionResponseModel> deleteNotification(String id) async {
    return _executeRequest<NotificationActionResponseModel>(
      operation: () async {
        final token = await _getAuthToken();
        final response = await httpClient.delete(
          Uri.parse(ApiUrls.deleteNotificationById(id)),
          headers: _getHeaders(token),
        ).timeout(requestTimeout);

        return _handleResponse<NotificationActionResponseModel>(
          response,
          (json) => NotificationActionResponseModel.fromJson(json),
          (msg, code) => NotificationActionResponseModel.error(message: msg, statusCode: code),
        );
      },
    );
  }

  // --- Helpers ---

  Future<String?> _getAuthToken() async => await tokenStorage.getToken();

  Map<String, String> _getHeaders(String? token) => {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  Future<T> _executeRequest<T>({required Future<T> Function() operation}) async {
    try {
      return await operation();
    } on TimeoutException {
      return _errorResponse<T>('Request timeout', 408);
    } on SocketException {
      return _errorResponse<T>('No internet connection', 503);
    } catch (e) {
      return _errorResponse<T>('Unexpected error: $e', 500);
    }
  }

  T _handleResponse<T>(
    http.Response response,
    T Function(Map<String, dynamic>) fromJson,
    T Function(String, int) errorFactory,
  ) {
    try {
      final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return fromJson(jsonData);
      } else {
        return errorFactory(jsonData['error']?.toString() ?? 'Request failed', response.statusCode);
      }
    } catch (e) {
      return errorFactory('Failed to parse response', response.statusCode);
    }
  }

  T _errorResponse<T>(String message, int code) {
    if (T == GetNotificationsResponseModel) {
      return GetNotificationsResponseModel.error(message: message, statusCode: code) as T;
    } else {
      return NotificationActionResponseModel.error(message: message, statusCode: code) as T;
    }
  }
}
