// ============================================================================
// FCM TOKEN SENDING - Send FCM Token to Backend Server
// ============================================================================
// This service handles sending FCM tokens to the backend for push notifications.
//
// RESPONSIBILITIES:
// ✅ Send FCM token to backend API
// ✅ Retry logic for failed requests
// ✅ Handle authentication
// ✅ Support for user-specific tokens
//
// USAGE:
//   final service = FCMTokenApiService.instance;
//
//   // Send FCM token to backend
//   final success = await service.sendFCMTokenToBackend();
//
//   // Send with response data
//   final result = await service.sendFCMTokenToBackendWithResponse();
//   print('Success: ${result['success']}');
//   print('Response: ${result['response']}');
//
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:chataway_plus/core/constants/api_url/api_urls.dart';
import 'package:chataway_plus/core/notifications/firebase/fcm_token_api_models.dart';
import 'package:chataway_plus/core/services/device_id_service.dart';
import 'package:chataway_plus/core/storage/token_storage.dart';
import 'package:chataway_plus/core/storage/fcm_token_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for sending FCM tokens to the backend server
///
/// This handles registering FCM tokens with the server so backend can send push notifications
class FCMTokenApiService {
  static final FCMTokenApiService _instance = FCMTokenApiService._internal();
  factory FCMTokenApiService() => _instance;
  FCMTokenApiService._internal();

  static FCMTokenApiService get instance => _instance;

  final TokenSecureStorage _tokenStorage = TokenSecureStorage.instance;
  final FCMTokenStorage _fcmTokenStorage = FCMTokenStorage.instance;

  // Maximum number of retry attempts for API calls
  static const int maxRetries = 2;

  static const bool _verboseFcmLogs = false;

  static const String _lastSentAtKeyPrefix = 'fcm_token_last_sent_at_ms_v1_';
  static const Duration _minResendInterval = Duration(hours: 24);

  // ==========================================================================
  // PUBLIC API METHODS
  // ==========================================================================

  /// Send FCM token to backend for push notification registration
  Future<bool> sendFCMTokenToBackend() async {
    final result = await sendFCMTokenToBackendWithResponse();
    return result.success;
  }

  /// Send FCM token to backend with response data
  Future<StoreFcmTokenResponseModel> sendFCMTokenToBackendWithResponse() async {
    return _sendFCMTokenWithRetryAndResponse(retryCount: 0);
  }

  /// Send FCM token silently (no error logging, for background operations)
  Future<bool> sendFCMTokenSilently() async {
    try {
      return await ensureFCMTokenSentToBackend();
    } catch (e) {
      // Silent failure - don't log errors for background operations
      return false;
    }
  }

  /// Send FCM token silently with response (no error logging, for background operations)
  Future<StoreFcmTokenResponseModel> sendFCMTokenSilentlyWithResponse() async {
    try {
      return await sendFCMTokenToBackendWithResponse();
    } catch (e) {
      return StoreFcmTokenResponseModel.error(
        message: 'Error: ${e.toString()}',
      );
    }
  }

  /// Send FCM token for a specific user (when switching users)
  Future<bool> sendFCMTokenForUser(String phoneNumber) async {
    try {
      // Get FCM token for specific user
      final fcmToken = await _fcmTokenStorage.getFCMToken();
      if (fcmToken == null) {
        debugPrint(' No FCM token available for user: $phoneNumber');
        return false;
      }

      // Save FCM token with user context first (local storage)
      await _fcmTokenStorage.saveFCMToken(fcmToken, phoneNumber);

      // Then send to backend
      return sendFCMTokenToBackend();
    } catch (e) {
      debugPrint(' Error sending FCM token for user: $e');
      return false;
    }
  }

  /// Ensure FCM token is sent to backend (used during app initialization)
  Future<bool> ensureFCMTokenSentToBackend() async {
    try {
      final fcmToken = await _fcmTokenStorage.getFCMToken();
      if (fcmToken == null) {
        debugPrint(' No FCM token available to send to backend');
        return false;
      }

      final userPhone = await _tokenStorage.getPhoneNumber();
      if (userPhone != null && userPhone.isNotEmpty) {
        try {
          final prefs = await SharedPreferences.getInstance();
          final key = '$_lastSentAtKeyPrefix$userPhone';
          final last = prefs.getInt(key);
          if (last != null) {
            final ageMs = DateTime.now().millisecondsSinceEpoch - last;
            if (ageMs >= 0 && ageMs < _minResendInterval.inMilliseconds) {
              return true;
            }
          }

          final ok = await sendFCMTokenToBackend();
          if (ok) {
            await prefs.setInt(key, DateTime.now().millisecondsSinceEpoch);
          }
          return ok;
        } catch (_) {
          // If throttling fails, fall back to normal send.
          return await sendFCMTokenToBackend();
        }
      }

      return await sendFCMTokenToBackend();
    } catch (e) {
      debugPrint(' Error ensuring FCM token sent: $e');
      return false;
    }
  }

  Future<bool> forceSendFCMTokenToBackendAndMarkSent() async {
    try {
      final fcmToken = await _fcmTokenStorage.getFCMToken();
      if (fcmToken == null) {
        return false;
      }

      final ok = await sendFCMTokenToBackend();

      final userPhone = await _tokenStorage.getPhoneNumber();
      if (ok && userPhone != null && userPhone.isNotEmpty) {
        try {
          final prefs = await SharedPreferences.getInstance();
          final key = '$_lastSentAtKeyPrefix$userPhone';
          await prefs.setInt(key, DateTime.now().millisecondsSinceEpoch);
        } catch (_) {}
      }

      return ok;
    } catch (_) {
      return false;
    }
  }

  // ==========================================================================
  // PRIVATE HELPER METHODS
  // ==========================================================================

  /// Private helper method to implement retry logic for FCM token sending with response data
  Future<StoreFcmTokenResponseModel> _sendFCMTokenWithRetryAndResponse({
    required int retryCount,
  }) async {
    try {
      // Get authentication token
      final authToken = await _tokenStorage.getToken();
      if (authToken == null) {
        debugPrint(' No auth token available for FCM token API call');
        return StoreFcmTokenResponseModel.error(
          message: 'No auth token available',
        );
      }

      // Get FCM token from secure storage
      final fcmToken = await _fcmTokenStorage.getFCMToken();
      if (fcmToken == null) {
        debugPrint(' No FCM token available in storage');
        return StoreFcmTokenResponseModel.error(
          message: 'No FCM token available in storage',
        );
      }

      // Prepare API request
      final url = Uri.parse(ApiUrls.sendingFcmToken);
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
        'Accept': '*/*',
      };

      final deviceId = await DeviceIdService.instance.getOrCreateDeviceId();

      final platform = Platform.isIOS
          ? 'ios'
          : (Platform.isAndroid ? 'android' : 'web');

      String appVersion = '';
      try {
        final info = await PackageInfo.fromPlatform();
        appVersion = info.version;
      } catch (_) {
        appVersion = '';
      }

      final body = jsonEncode({
        'fcmToken': fcmToken,
        'deviceId': deviceId,
        'platform': platform,
        'appVersion': appVersion,
      });

      if (_verboseFcmLogs && kDebugMode) {
        debugPrint(' Sending FCM token to backend...');
        debugPrint(' Token preview: ${fcmToken.substring(0, 20)}...');
      }

      // Make API call with timeout
      final response = await http
          .post(url, headers: headers, body: body)
          .timeout(const Duration(seconds: 15));

      StoreFcmTokenResponseModel parsedResponse;
      try {
        parsedResponse = StoreFcmTokenResponseModel.fromJson(
          jsonDecode(response.body),
          statusCode: response.statusCode,
        );
      } catch (e) {
        if (kDebugMode) {
          debugPrint(' Error parsing response: $e');
        }
        return StoreFcmTokenResponseModel.error(
          message: 'Error parsing response: ${e.toString()}',
          statusCode: response.statusCode,
        );
      }

      // Handle response
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (parsedResponse.success) {
          if (_verboseFcmLogs && kDebugMode) {
            debugPrint(' FCM token sent to backend successfully');
          }
          return parsedResponse;
        }

        if (kDebugMode) {
          debugPrint(' Failed to send FCM token: ${response.statusCode}');
          if (_verboseFcmLogs) {
            debugPrint(' Response body: ${response.body}');
          }
        }
        return StoreFcmTokenResponseModel.error(
          message: parsedResponse.message.isNotEmpty
              ? parsedResponse.message
              : 'Failed to send FCM token: ${response.statusCode} - ${response.body}',
          statusCode: response.statusCode,
        );
      } else {
        if (kDebugMode) {
          debugPrint(' Failed to send FCM token: ${response.statusCode}');
          if (_verboseFcmLogs) {
            debugPrint(' Response body: ${response.body}');
          }
        }

        // Check if we should retry
        if (retryCount < maxRetries && _shouldRetry(response.statusCode)) {
          debugPrint(' Retrying... (attempt ${retryCount + 1}/$maxRetries)');
          await Future.delayed(Duration(seconds: (retryCount + 1) * 2));
          return _sendFCMTokenWithRetryAndResponse(retryCount: retryCount + 1);
        }

        return StoreFcmTokenResponseModel.error(
          message:
              'Failed to send FCM token: ${response.statusCode} - ${response.body}',
          statusCode: response.statusCode,
        );
      }
    } on TimeoutException catch (e) {
      debugPrint(' Timeout sending FCM token: $e');

      // Retry on timeout
      if (retryCount < maxRetries) {
        debugPrint(
          '🔄 Retrying after timeout... (attempt ${retryCount + 1}/$maxRetries)',
        );
        await Future.delayed(Duration(seconds: (retryCount + 1) * 2));
        return _sendFCMTokenWithRetryAndResponse(retryCount: retryCount + 1);
      }

      return StoreFcmTokenResponseModel.error(
        message: 'Request timed out: ${e.toString()}',
      );
    } on SocketException catch (e) {
      debugPrint('🌐 Network error sending FCM token: $e');

      // Retry on network error
      if (retryCount < maxRetries) {
        debugPrint(
          '🔄 Retrying after network error... (attempt ${retryCount + 1}/$maxRetries)',
        );
        await Future.delayed(Duration(seconds: (retryCount + 1) * 2));
        return _sendFCMTokenWithRetryAndResponse(retryCount: retryCount + 1);
      }

      return StoreFcmTokenResponseModel.error(
        message: 'Network error: ${e.toString()}',
      );
    } catch (e) {
      debugPrint('❌ Unexpected error sending FCM token: $e');

      // Retry on unexpected errors
      if (retryCount < maxRetries && _isNetworkError(e)) {
        debugPrint('🔄 Retrying... (attempt ${retryCount + 1}/$maxRetries)');
        await Future.delayed(Duration(seconds: (retryCount + 1) * 2));
        return _sendFCMTokenWithRetryAndResponse(retryCount: retryCount + 1);
      }

      return StoreFcmTokenResponseModel.error(
        message: 'Error: ${e.toString()}',
      );
    }
  }

  /// Check if the error is a network-related error that should be retried
  bool _isNetworkError(dynamic error) {
    return error is SocketException ||
        error is TimeoutException ||
        error is HttpException ||
        (error is Exception && error.toString().contains('timeout'));
  }

  /// Check if the HTTP status code should trigger a retry
  bool _shouldRetry(int statusCode) {
    // Retry on server errors (5xx) and some client errors
    return statusCode >= 500 || statusCode == 429; // 429 = Too Many Requests
  }
}
