// ============================================================================
// FIRST RUN CLEANER - Cleans persisted secrets and local DB on fresh install
// ============================================================================
// Purpose:
// - Some secure storage (iOS Keychain) can survive app uninstall via backups.
// - On first run after (re)install, we ensure all sensitive tokens and local
//   database are cleared to avoid account mix-ups.
// - Also cleans data when upgrading from old incompatible versions.
//
// Usage:
//   await FirstRunCleaner.run();
// ============================================================================

import 'package:shared_preferences/shared_preferences.dart';
import 'package:chataway_plus/core/storage/token_storage.dart';
import 'package:chataway_plus/core/storage/fcm_token_storage.dart';
import 'package:chataway_plus/core/database/app_database.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

const bool _enableFirstRunCleanerLogs =
    false; // Disable verbose logs by default

void _log(String message) {
  if (!kDebugMode || !_enableFirstRunCleanerLogs) return;
  debugPrint(message);
}

class FirstRunCleaner {
  static const _sentinelKey = 'install_sentinel_v1';
  static const _lastVersionKey = 'last_app_version';

  static Future<void> run() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasRunBefore = prefs.getBool(_sentinelKey) ?? false;

      // Get current app version
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final lastVersion = prefs.getString(_lastVersionKey);

      // Check if we need to clean:
      // 1. First install (fresh install) - ONLY clean on first install
      // 2. DO NOT clean on version upgrades - user data should persist
      final isFirstInstall = !hasRunBefore;

      if (isFirstInstall) {
        _log('[FirstRunCleaner] 🆕 Fresh install detected - cleaning data');

        // Clear secure tokens
        try {
          await TokenSecureStorage.instance.clearUserData();
          _log('[FirstRunCleaner] ✅ Cleared secure tokens');
        } catch (e) {
          _log('[FirstRunCleaner] ⚠️ Failed to clear tokens: $e');
        }

        try {
          await FCMTokenStorage.instance.deleteFCMToken();
          _log('[FirstRunCleaner] ✅ Cleared FCM token');
        } catch (e) {
          _log('[FirstRunCleaner] ⚠️ Failed to clear FCM token: $e');
        }

        // Clear local database
        try {
          await AppDatabaseManager.instance.deleteDatabaseFile();
          _log('[FirstRunCleaner] ✅ Cleared local database');
        } catch (e) {
          _log('[FirstRunCleaner] ⚠️ Failed to clear database: $e');
        }

        // Mark as completed and store current version
        await prefs.setBool(_sentinelKey, true);
        await prefs.setString(_lastVersionKey, currentVersion);

        _log(
          '[FirstRunCleaner] ✅ Cleanup completed for version $currentVersion',
        );
      } else {
        // Just update version tracking, don't clean anything
        if (lastVersion != currentVersion) {
          await prefs.setString(_lastVersionKey, currentVersion);
        }
      }
    } catch (e) {
      _log('[FirstRunCleaner] ❌ Error during cleanup: $e');
    }
  }
}
