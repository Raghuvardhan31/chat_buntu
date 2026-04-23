import 'package:chataway_plus/core/notifications/firebase/fcm_token_sending.dart';
import 'package:chataway_plus/core/storage/fcm_token_storage.dart';
import 'package:chataway_plus/core/storage/token_storage.dart';
import 'package:chataway_plus/features/chat/data/services/chat_engine/index.dart';
import 'package:chataway_plus/features/contacts/data/repositories/contacts_repository.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppUpgradeManager {
  AppUpgradeManager._internal();

  static final AppUpgradeManager instance = AppUpgradeManager._internal();

  static const String _lastVersionKey = 'app_last_version_v1';
  static const String _lastBuildKey = 'app_last_build_v1';
  static const String _recoveryDoneBuildKey = 'app_upgrade_recovery_done_build_v1';

  Future<void> runIfNeeded({required String currentUserId}) async {
    try {
      final info = await PackageInfo.fromPlatform();
      final prefs = await SharedPreferences.getInstance();

      final lastVersion = prefs.getString(_lastVersionKey);
      final lastBuild = prefs.getString(_lastBuildKey);

      final currentVersion = info.version;
      final currentBuild = info.buildNumber;

      final isUpgrade =
          lastBuild != null && lastBuild.isNotEmpty && lastBuild != currentBuild;

      await prefs.setString(_lastVersionKey, currentVersion);
      await prefs.setString(_lastBuildKey, currentBuild);

      if (!isUpgrade) {
        return;
      }

      final alreadyDoneForBuild =
          prefs.getString(_recoveryDoneBuildKey) == currentBuild;
      if (alreadyDoneForBuild) {
        return;
      }

      await prefs.setString(_recoveryDoneBuildKey, currentBuild);

      if (kDebugMode) {
        debugPrint(
          '🔁 [AppUpgrade] Detected upgrade: $lastVersion+$lastBuild -> $currentVersion+$currentBuild',
        );
      }

      await _runRecovery(currentUserId: currentUserId);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ [AppUpgrade] runIfNeeded failed: $e');
      }
    }
  }

  Future<void> _runRecovery({required String currentUserId}) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        final phone = await TokenSecureStorage.instance.getPhoneNumber();
        if (phone != null && phone.isNotEmpty) {
          await FCMTokenStorage.instance.saveFCMToken(token, phone);
        } else {
          await FCMTokenStorage.instance.updateFCMToken(token);
        }
      }
    } catch (_) {}

    try {
      await FCMTokenApiService.instance.forceSendFCMTokenToBackendAndMarkSent();
    } catch (_) {}

    try {
      await ChatEngineService.instance.reconnectSocket();
    } catch (_) {}

    try {
      await ChatEngineService.instance.syncPendingMessages();
    } catch (_) {}

    try {
      await ChatEngineService.instance.syncUnreadCountAndContacts(
        reason: 'app_upgrade',
        force: true,
      );
    } catch (_) {}

    try {
      await ContactsRepository.instance.syncProfileUpdates();
    } catch (_) {}
  }
}
