// ============================================================================
// TOKEN STORAGE - Authentication Token Management
// ============================================================================
// This file handles storage of authentication tokens (JWT, Bearer tokens).
//
// FEATURES:
// ✅ Save authentication token after login
// ✅ Retrieve token for API requests
// ✅ Delete token on logout
// ✅ Check if user is logged in (token exists)
// ✅ User-specific token storage (multi-account support)
// ✅ Secure storage using flutter_secure_storage
//
// USAGE:
//   final storage = TokenSecureStorage.instance;
//   await storage.saveToken('token', '+1234567890');
//   final token = await storage.getToken();
//   await storage.clearUserData();
//
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenSecureStorage {
  // Singleton instance (eagerly initialized, non-nullable)
  static final TokenSecureStorage _instance = TokenSecureStorage._internal();

  // Storage instance with platform-specific security options
  final _storage = FlutterSecureStorage(
    // Android-specific options
    aOptions: const AndroidOptions(
      encryptedSharedPreferences: true,
      sharedPreferencesName: 'secure_token_storage',
      preferencesKeyPrefix: 'secure_',
    ),
    // iOS-specific options
    iOptions: const IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
      synchronizable: true,
    ),
    // Web-specific options
    webOptions: const WebOptions(publicKey: 'token_storage'),
  );

  // Factory constructor to return the singleton instance
  factory TokenSecureStorage() {
    return _instance;
  }

  // Private constructor for singleton
  TokenSecureStorage._internal();

  // Static access for legacy code
  static TokenSecureStorage get instance => _instance;

  // Key for storing the current user's phone number
  static const String _phoneNumberKey = 'current_user_phone_number';
  // Key for storing the auth token
  static const String _authTokenKey = 'auth_token';
  // Key for storing the current user ID UUID (for chat messaging)
  static const String _currentUserIdUUIDKey = 'current_user_id_uuid';
  // Legacy key for backward compatibility
  static const String _legacyPhoneKey = 'phoneNumber';
  // Preference keys for emoji display
  static const String _prefShowEmojiInProfile = 'pref_show_emoji_in_profile';
  static const String _prefShowEmojiInAppIcon = 'pref_show_emoji_in_app_icon';

  // ==========================================================================
  // TOKEN MANAGEMENT
  // ==========================================================================

  /// Saves token and phone number with proper user context
  /// This prevents token conflicts between different user accounts
  Future<void> saveToken(String token, String phoneNumber) async {
    try {
      final tokenKey = '${_authTokenKey}_$phoneNumber';
      final existingUserToken = await _storage.read(key: tokenKey);
      final existingLegacyToken = await _storage.read(key: 'token');
      final existingActivePhone = await _storage.read(key: _phoneNumberKey);
      final existingLegacyPhone = await _storage.read(key: _legacyPhoneKey);

      final alreadySavedForUser =
          existingUserToken != null && existingUserToken == token;
      final legacyMatches =
          existingLegacyToken != null && existingLegacyToken == token;
      final phoneMatches = existingActivePhone == phoneNumber;
      final legacyPhoneMatches = existingLegacyPhone == phoneNumber;

      if (alreadySavedForUser &&
          legacyMatches &&
          phoneMatches &&
          legacyPhoneMatches) {
        debugPrint(
          '[TokenSecureStorage] Token already stored for user: $phoneNumber',
        );
        return;
      }

      if (!phoneMatches) {
        await _storage.write(key: _phoneNumberKey, value: phoneNumber);
      }

      if (!legacyPhoneMatches) {
        await _storage.write(key: _legacyPhoneKey, value: phoneNumber);
      }

      if (!alreadySavedForUser) {
        await _storage.write(key: tokenKey, value: token);
      }

      if (!legacyMatches) {
        await _storage.write(key: 'token', value: token);
      }

      debugPrint('[TokenSecureStorage] Saved token for user: $phoneNumber');
    } catch (e) {
      debugPrint('[TokenSecureStorage] Error saving token: $e');
      throw Exception('Failed to save data to secure storage: $e');
    }
  }

  /// Gets token for the current active user
  /// Falls back to legacy key if user-specific token not found
  Future<String?> getToken() async {
    try {
      final phoneNumber = await getPhoneNumber();
      if (phoneNumber != null) {
        final tokenKey = '${_authTokenKey}_$phoneNumber';
        final token = await _storage.read(key: tokenKey);
        if (token != null) {
          return token;
        }
      }
      return await _storage.read(key: 'token');
    } catch (e) {
      debugPrint('❌ TokenSecureStorage: Error retrieving token: $e');
      throw Exception('Failed to retrieve token: $e');
    }
  }

  /// Check if a user has valid token stored
  Future<bool> hasValidTokenForUser(String phoneNumber) async {
    try {
      final tokenKey = '${_authTokenKey}_$phoneNumber';
      final token = await _storage.read(key: tokenKey);
      return token != null && token.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // ==========================================================================
  // PHONE NUMBER MANAGEMENT
  // ==========================================================================

  /// Gets the current active user's phone number
  Future<String?> getPhoneNumber() async {
    try {
      final current = await _storage.read(key: _phoneNumberKey);
      if (current != null) {
        return current;
      }
      return await _storage.read(key: _legacyPhoneKey);
    } catch (e) {
      debugPrint('❌ TokenSecureStorage: Error retrieving phone number: $e');
      throw Exception('Failed to retrieve phone number: $e');
    }
  }

  // ==========================================================================
  // USER ID MANAGEMENT
  // ==========================================================================

  /// Saves current user ID UUID for chat messaging
  Future<void> saveCurrentUserIdUUID(String currentUserIdUUID) async {
    try {
      await _storage.write(
        key: _currentUserIdUUIDKey,
        value: currentUserIdUUID,
      );
      debugPrint(
        '💾 TokenSecureStorage: Saved current user ID UUID: $currentUserIdUUID',
      );
    } catch (e) {
      debugPrint('❌ TokenSecureStorage: Error saving current user ID UUID: $e');
      throw Exception('Failed to save current user ID UUID: $e');
    }
  }

  /// Gets the current user ID UUID for chat messaging
  Future<String?> getCurrentUserIdUUID() async {
    try {
      final currentUserIdUUID = await _storage.read(key: _currentUserIdUUIDKey);
      return currentUserIdUUID;
    } catch (e) {
      debugPrint(
        '❌ TokenSecureStorage: Error retrieving current user ID UUID: $e',
      );
      throw Exception('Failed to retrieve current user ID UUID: $e');
    }
  }

  // ==========================================================================
  // EMOJI DISPLAY PREFERENCES
  // ==========================================================================

  Future<void> setShowEmojiInProfile(bool value) async {
    try {
      await _storage.write(
        key: _prefShowEmojiInProfile,
        value: value ? '1' : '0',
      );
    } catch (_) {}
  }

  Future<bool> getShowEmojiInProfile({bool defaultValue = true}) async {
    try {
      final v = await _storage.read(key: _prefShowEmojiInProfile);
      if (v == null) return defaultValue;
      return v == '1' || v.toLowerCase() == 'true';
    } catch (_) {
      return defaultValue;
    }
  }

  Future<void> setShowEmojiInAppIcon(bool value) async {
    try {
      await _storage.write(
        key: _prefShowEmojiInAppIcon,
        value: value ? '1' : '0',
      );
    } catch (_) {}
  }

  Future<bool> getShowEmojiInAppIcon({bool defaultValue = true}) async {
    try {
      final v = await _storage.read(key: _prefShowEmojiInAppIcon);
      if (v == null) return defaultValue;
      return v == '1' || v.toLowerCase() == 'true';
    } catch (_) {
      return defaultValue;
    }
  }

  // ==========================================================================
  // USER MANAGEMENT (LOGOUT, SWITCH USER)
  // ==========================================================================

  /// CRITICAL: Properly handles user logout by cleaning up tokens
  Future<void> clearUserData() async {
    try {
      final phoneNumber = await getPhoneNumber();
      if (phoneNumber != null) {
        debugPrint(
          '🧹 TokenSecureStorage: Clearing data for user: $phoneNumber',
        );

        // Delete user-specific token
        final tokenKey = '${_authTokenKey}_$phoneNumber';
        await _storage.delete(key: tokenKey);
      }

      // Clear current user marker, user ID UUID, and legacy keys
      await _storage.delete(key: _phoneNumberKey);
      await _storage.delete(key: _currentUserIdUUIDKey);
      await _storage.delete(key: 'token');
      await _storage.delete(key: _legacyPhoneKey);

      debugPrint('✅ TokenSecureStorage: User data cleared successfully');
    } catch (e) {
      debugPrint('❌ TokenSecureStorage: Error clearing user data: $e');
      throw Exception('Failed to clear user data: $e');
    }
  }

  /// Properly switches to a new user account
  Future<void> switchUser(String newPhoneNumber, String newToken) async {
    try {
      // First clear the current user's data
      await clearUserData();

      // Then set up the new user
      await saveToken(newToken, newPhoneNumber);

      debugPrint('🔄 TokenSecureStorage: Switched to user: $newPhoneNumber');
    } catch (e) {
      debugPrint('❌ TokenSecureStorage: Error switching user: $e');
      throw Exception('Failed to switch user: $e');
    }
  }
}
