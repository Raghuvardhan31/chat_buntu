// ============================================================================
// FCM TOKEN STORAGE - Firebase Cloud Messaging Token Management
// ============================================================================
// This file handles storage of Firebase Cloud Messaging (FCM) tokens.
//
// FEATURES:
// ✅ Save FCM token received from Firebase
// ✅ Retrieve FCM token to send to backend
// ✅ Update FCM token when it refreshes
// ✅ Delete FCM token on logout
// ✅ User-specific token storage (multi-account support)
//
// USAGE:
//   final storage = FCMTokenStorage.instance;
//
//   // Save FCM token
//   await storage.saveFCMToken('fcm_token_here', '+1234567890');
//
//   // Get FCM token
//   final token = await storage.getFCMToken();
//
//   // Update when Firebase refreshes
//   await storage.updateFCMToken('new_fcm_token');
//
//   // Delete on logout
//   await storage.deleteFCMToken();
//
// WHY SEPARATE FROM AUTH TOKEN:
// - FCM token has different lifecycle than auth token
// - FCM token can refresh independently (Firebase does this automatically)
// - Backend needs FCM token for push notifications
//
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class FCMTokenStorage {
  // Singleton instance
  static final FCMTokenStorage _instance = FCMTokenStorage._internal();

  // Storage instance with platform-specific security options
  final _storage = FlutterSecureStorage(
    aOptions: const AndroidOptions(
      encryptedSharedPreferences: true,
      sharedPreferencesName: 'fcm_token_storage',
      preferencesKeyPrefix: 'fcm_',
    ),
    iOptions: const IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
      synchronizable: true,
    ),
    webOptions: const WebOptions(publicKey: 'fcm_token_storage'),
  );

  // Factory constructor to return singleton
  factory FCMTokenStorage() {
    return _instance;
  }

  // Private constructor for singleton
  FCMTokenStorage._internal();

  // Static access
  static FCMTokenStorage get instance => _instance;

  // Storage keys
  static const String _fcmTokenKey = 'fcm_token';
  static const String _phoneNumberKey = 'fcm_phone_number';
  static const String _lastUpdatedKey = 'fcm_last_updated';

  // ==========================================================================
  // FCM TOKEN MANAGEMENT
  // ==========================================================================

  /// Save FCM token with user context (phone number)
  /// This prevents token conflicts between different user accounts
  Future<void> saveFCMToken(String fcmToken, String phoneNumber) async {
    try {
      final tokenKey = '${_fcmTokenKey}_$phoneNumber';
      final existingToken = await _storage.read(key: tokenKey);
      final existingPhone = await _storage.read(key: _phoneNumberKey);

      final alreadySaved = existingToken == fcmToken;
      final phoneMatches = existingPhone == phoneNumber;

      if (alreadySaved && phoneMatches) {
        if (kDebugMode) {
          debugPrint(
            '[FCMTokenStorage] Token already stored for user: $phoneNumber',
          );
        }
        return;
      }

      // Save user-specific FCM token
      if (!alreadySaved) {
        await _storage.write(key: tokenKey, value: fcmToken);
      }

      // Save current active user's phone number
      if (!phoneMatches) {
        await _storage.write(key: _phoneNumberKey, value: phoneNumber);
      }

      // Save legacy FCM token for backward compatibility
      await _storage.write(key: _fcmTokenKey, value: fcmToken);

      // Save timestamp
      await _storage.write(
        key: _lastUpdatedKey,
        value: DateTime.now().toIso8601String(),
      );

      if (kDebugMode) {
        debugPrint('[FCMTokenStorage] Saved FCM token for user: $phoneNumber');
        debugPrint(
          '[FCMTokenStorage] Token preview: ${fcmToken.substring(0, 20)}...',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FCMTokenStorage] Error saving FCM token: $e');
      }
      throw Exception('Failed to save FCM token: $e');
    }
  }

  /// Get FCM token for the current active user
  /// Falls back to legacy key if user-specific token not found
  Future<String?> getFCMToken() async {
    try {
      // Get current active user's phone number
      final phoneNumber = await _storage.read(key: _phoneNumberKey);

      if (phoneNumber != null) {
        // Try to get user-specific FCM token first
        final tokenKey = '${_fcmTokenKey}_$phoneNumber';
        final token = await _storage.read(key: tokenKey);

        if (token != null) {
          return token;
        }
      }

      // Fall back to legacy key if needed
      final legacyToken = await _storage.read(key: _fcmTokenKey);
      return legacyToken;
    } catch (e) {
      debugPrint('❌ FCMTokenStorage: Error retrieving FCM token: $e');
      throw Exception('Failed to retrieve FCM token: $e');
    }
  }

  /// Update FCM token when Firebase refreshes it
  /// This happens automatically when Firebase detects token needs refresh
  Future<void> updateFCMToken(String newFcmToken) async {
    try {
      final phoneNumber = await _storage.read(key: _phoneNumberKey);

      if (phoneNumber != null) {
        debugPrint(
          '🔄 FCMTokenStorage: Updating FCM token for user: $phoneNumber',
        );
        await saveFCMToken(newFcmToken, phoneNumber);
      } else {
        debugPrint(
          '🔄 FCMTokenStorage: Updating legacy FCM token (no user context)',
        );
        await _storage.write(key: _fcmTokenKey, value: newFcmToken);
        await _storage.write(
          key: _lastUpdatedKey,
          value: DateTime.now().toIso8601String(),
        );
      }

      debugPrint('✅ FCMTokenStorage: FCM token updated successfully');
      debugPrint(
        '🔑 FCMTokenStorage: New token preview: ${newFcmToken.substring(0, 20)}...',
      );
    } catch (e) {
      debugPrint('❌ FCMTokenStorage: Error updating FCM token: $e');
      throw Exception('Failed to update FCM token: $e');
    }
  }

  /// Delete FCM token on logout
  /// Cleans up all user-specific and legacy FCM token data
  Future<void> deleteFCMToken() async {
    try {
      final phoneNumber = await _storage.read(key: _phoneNumberKey);

      if (phoneNumber != null) {
        debugPrint(
          '🗑️ FCMTokenStorage: Deleting FCM token for user: $phoneNumber',
        );

        // Delete user-specific FCM token
        final tokenKey = '${_fcmTokenKey}_$phoneNumber';
        await _storage.delete(key: tokenKey);
      }

      // Delete legacy keys
      await _storage.delete(key: _fcmTokenKey);
      await _storage.delete(key: _phoneNumberKey);
      await _storage.delete(key: _lastUpdatedKey);

      debugPrint('✅ FCMTokenStorage: FCM token deleted successfully');
    } catch (e) {
      debugPrint('❌ FCMTokenStorage: Error deleting FCM token: $e');
      throw Exception('Failed to delete FCM token: $e');
    }
  }

  // ==========================================================================
  // UTILITY METHODS
  // ==========================================================================

  /// Check if FCM token exists for current user
  Future<bool> hasFCMToken() async {
    try {
      final token = await getFCMToken();
      return token != null && token.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Check if a user has valid FCM token stored
  Future<bool> hasValidFCMTokenForUser(String phoneNumber) async {
    try {
      final tokenKey = '${_fcmTokenKey}_$phoneNumber';
      final token = await _storage.read(key: tokenKey);
      return token != null && token.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Get the last time FCM token was updated
  Future<DateTime?> getLastUpdated() async {
    try {
      final timestamp = await _storage.read(key: _lastUpdatedKey);
      if (timestamp != null) {
        return DateTime.parse(timestamp);
      }
      return null;
    } catch (e) {
      debugPrint('❌ FCMTokenStorage: Error getting last updated time: $e');
      return null;
    }
  }

  /// Get the phone number associated with current FCM token
  Future<String?> getPhoneNumber() async {
    try {
      return await _storage.read(key: _phoneNumberKey);
    } catch (e) {
      debugPrint('❌ FCMTokenStorage: Error getting phone number: $e');
      return null;
    }
  }
}
