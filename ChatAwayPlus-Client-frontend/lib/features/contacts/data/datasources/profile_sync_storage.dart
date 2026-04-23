// ============================================================================
// PROFILE SYNC STORAGE - Manages Last Profile Sync Timestamp
// ============================================================================
// Purpose:
// - Stores the last time contacts' profiles were synced
// - Used for delta sync with backend (fetch only updated profiles)
// - Reduces API calls and bandwidth by fetching only changed profiles
//
// Usage:
//   final storage = ProfileSyncStorage.instance;
//   await storage.saveLastSyncTime(DateTime.now());
//   final lastSync = await storage.getLastSyncTime();
// ============================================================================

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class ProfileSyncStorage {
  // Singleton
  static final ProfileSyncStorage _instance = ProfileSyncStorage._internal();
  static ProfileSyncStorage get instance => _instance;
  ProfileSyncStorage._internal();

  // Key for storing last profile sync timestamp
  static const String _lastProfileSyncKey = 'last_profile_sync_timestamp_v1';

  SharedPreferences? _prefs;

  /// Initialize SharedPreferences
  Future<void> _ensureInitialized() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Save last profile sync timestamp
  /// Stores as ISO 8601 string for easy API communication
  Future<bool> saveLastSyncTime(DateTime timestamp) async {
    try {
      await _ensureInitialized();
      final isoString = timestamp.toUtc().toIso8601String();
      final success = await _prefs!.setString(_lastProfileSyncKey, isoString);

      if (success && kDebugMode) {
        debugPrint('✅ [ProfileSyncStorage] Saved last sync time: $isoString');
      }

      return success;
    } catch (e) {
      debugPrint('❌ [ProfileSyncStorage] Error saving sync time: $e');
      return false;
    }
  }

  /// Get last profile sync timestamp
  /// Returns null if never synced before
  Future<DateTime?> getLastSyncTime() async {
    try {
      await _ensureInitialized();
      final isoString = _prefs!.getString(_lastProfileSyncKey);

      if (isoString == null) {
        if (kDebugMode) {
          debugPrint('ℹ️ [ProfileSyncStorage] No previous sync found');
        }
        return null;
      }

      final timestamp = DateTime.parse(isoString);

      if (kDebugMode) {
        debugPrint('✅ [ProfileSyncStorage] Last sync time: $isoString');
      }

      return timestamp;
    } catch (e) {
      debugPrint('❌ [ProfileSyncStorage] Error getting sync time: $e');
      return null;
    }
  }

  /// Get last sync time as ISO 8601 string for API calls
  Future<String?> getLastSyncTimeISO() async {
    try {
      await _ensureInitialized();
      return _prefs!.getString(_lastProfileSyncKey);
    } catch (e) {
      debugPrint('❌ [ProfileSyncStorage] Error getting sync time ISO: $e');
      return null;
    }
  }

  /// Clear sync timestamp (used on logout or cache clear)
  Future<bool> clearSyncTime() async {
    try {
      await _ensureInitialized();
      final success = await _prefs!.remove(_lastProfileSyncKey);

      if (success && kDebugMode) {
        debugPrint('🗑️ [ProfileSyncStorage] Cleared sync timestamp');
      }

      return success;
    } catch (e) {
      debugPrint('❌ [ProfileSyncStorage] Error clearing sync time: $e');
      return false;
    }
  }

  /// Check if sync is needed based on time elapsed
  /// Default: sync if last sync was more than 6 hours ago
  Future<bool> needsSync({Duration maxAge = const Duration(hours: 6)}) async {
    try {
      final lastSync = await getLastSyncTime();

      if (lastSync == null) {
        debugPrint('ℹ️ [ProfileSyncStorage] Needs sync: Never synced');
        return true; // Never synced
      }

      final age = DateTime.now().difference(lastSync);
      final needs = age > maxAge;

      if (kDebugMode) {
        debugPrint(
          'ℹ️ [ProfileSyncStorage] Sync needed: $needs (age: ${age.inMinutes}m)',
        );
      }

      return needs;
    } catch (e) {
      debugPrint('❌ [ProfileSyncStorage] Error checking if sync needed: $e');
      return true; // Default to needing sync on error
    }
  }
}
