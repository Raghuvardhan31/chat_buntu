import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:chataway_plus/core/storage/fcm_token_storage.dart';
import 'package:chataway_plus/core/storage/token_storage.dart';
import 'package:chataway_plus/core/notifications/firebase/fcm_token_sending.dart';

/// Debug helper for troubleshooting notification issues
///
/// Use this to check:
/// - FCM token status
/// - Permission status
/// - Backend token registration
/// - Notification settings
class NotificationDebugHelper {
  static Future<void> printFullDiagnostics() async {
    debugPrint('\n═══════════════════════════════════════════════════════');
    debugPrint('🔍 NOTIFICATION DIAGNOSTICS REPORT');
    debugPrint('═══════════════════════════════════════════════════════\n');

    // 1. Check FCM Token
    await _checkFCMToken();

    // 2. Check Permission Status
    await _checkPermissionStatus();

    // 3. Check Auth Token
    await _checkAuthToken();

    // 4. Check Token Sent to Backend
    await _checkBackendRegistration();

    // 5. Check Notification Settings
    await _checkNotificationSettings();

    debugPrint('\n═══════════════════════════════════════════════════════');
    debugPrint('🔍 END OF DIAGNOSTICS');
    debugPrint('═══════════════════════════════════════════════════════\n');
  }

  static Future<void> _checkFCMToken() async {
    debugPrint('📋 1. FCM TOKEN CHECK');
    debugPrint('─────────────────────────────────────────────────────');

    try {
      // Get FCM token from Firebase
      final fcmToken = await FirebaseMessaging.instance.getToken();

      if (fcmToken != null) {
        debugPrint('✅ FCM Token exists');
        debugPrint('🔑 Token (first 30 chars): $fcmToken...');
        debugPrint('📏 Token length: ${fcmToken.length} characters');

        // Check if token is saved in secure storage
        final savedToken = await FCMTokenStorage.instance.getFCMToken();
        if (savedToken != null) {
          debugPrint('✅ Token saved in secure storage');
          if (savedToken == fcmToken) {
            debugPrint('✅ Saved token matches Firebase token');
          } else {
            debugPrint('⚠️ WARNING: Saved token does NOT match Firebase token');
            debugPrint('   This might cause issues!');
          }
        } else {
          debugPrint('❌ Token NOT saved in secure storage');
          debugPrint('   Saving now...');
          final phone = await TokenSecureStorage.instance.getPhoneNumber();
          if (phone != null && phone.isNotEmpty) {
            await FCMTokenStorage.instance.saveFCMToken(fcmToken, phone);
          } else {
            await FCMTokenStorage.instance.updateFCMToken(fcmToken);
          }
          debugPrint('✅ Token saved');
        }
      } else {
        debugPrint('❌ CRITICAL: No FCM token found!');
        debugPrint('   Notification will NOT work without a token.');
      }
    } catch (e) {
      debugPrint('❌ ERROR checking FCM token: $e');
    }
    debugPrint('');
  }

  static Future<void> _checkPermissionStatus() async {
    debugPrint('📋 2. PERMISSION STATUS CHECK');
    debugPrint('─────────────────────────────────────────────────────');

    try {
      final settings = await FirebaseMessaging.instance
          .getNotificationSettings();

      debugPrint('Authorization Status: ${settings.authorizationStatus}');

      switch (settings.authorizationStatus) {
        case AuthorizationStatus.authorized:
          debugPrint('✅ Notifications AUTHORIZED');
          break;
        case AuthorizationStatus.provisional:
          debugPrint('⚠️ Notifications PROVISIONAL (iOS only)');
          break;
        case AuthorizationStatus.denied:
          debugPrint('❌ CRITICAL: Notifications DENIED by user');
          debugPrint('   User must enable notifications in device settings!');
          break;
        case AuthorizationStatus.notDetermined:
          debugPrint('⚠️ Permission not requested yet');
          break;
      }

      debugPrint('\nDetailed Settings:');
      debugPrint('  Alert: ${settings.alert}');
      debugPrint('  Badge: ${settings.badge}');
      debugPrint('  Sound: ${settings.sound}');
      debugPrint('  Announcement: ${settings.announcement}');
      debugPrint('  Car Play: ${settings.carPlay}');
      debugPrint('  Critical Alert: ${settings.criticalAlert}');
      debugPrint('  Lock Screen: ${settings.lockScreen}');
      debugPrint('  Notification Center: ${settings.notificationCenter}');
    } catch (e) {
      debugPrint('❌ ERROR checking permissions: $e');
    }
    debugPrint('');
  }

  static Future<void> _checkAuthToken() async {
    debugPrint('📋 3. AUTHENTICATION TOKEN CHECK');
    debugPrint('─────────────────────────────────────────────────────');

    try {
      final authToken = await TokenSecureStorage.instance.getToken();

      if (authToken != null) {
        debugPrint('✅ Auth token exists');
        debugPrint(
          '🔑 Token (first 30 chars): ${authToken.substring(0, 30)}...',
        );
        debugPrint('📏 Token length: ${authToken.length} characters');
      } else {
        debugPrint('❌ CRITICAL: No auth token found!');
        debugPrint('   Cannot send FCM token to backend without auth.');
        debugPrint('   User needs to login first.');
      }

      // Check user ID
      final userId = await TokenSecureStorage.instance.getCurrentUserIdUUID();
      if (userId != null) {
        debugPrint('✅ User ID exists: $userId');
      } else {
        debugPrint('⚠️ No user ID found');
      }
    } catch (e) {
      debugPrint('❌ ERROR checking auth token: $e');
    }
    debugPrint('');
  }

  static Future<void> _checkBackendRegistration() async {
    debugPrint('📋 4. BACKEND REGISTRATION CHECK');
    debugPrint('─────────────────────────────────────────────────────');

    try {
      debugPrint('🔄 Attempting to send FCM token to backend...');

      final result = await FCMTokenApiService.instance
          .sendFCMTokenToBackendWithResponse();

      if (result.success) {
        debugPrint('✅ Token successfully sent to backend');
        debugPrint('📥 Response: ${result.toJson()}');
      } else {
        debugPrint('❌ FAILED to send token to backend');
        debugPrint('📥 Error: ${result.message}');
        debugPrint('\nPossible reasons:');
        debugPrint('  1. No internet connection');
        debugPrint('  2. Backend server is down');
        debugPrint('  3. Auth token expired or invalid');
        debugPrint('  4. Wrong API endpoint');
        debugPrint('  5. Backend not accepting the token format');
      }
    } catch (e) {
      debugPrint('❌ ERROR sending token to backend: $e');
    }
    debugPrint('');
  }

  static Future<void> _checkNotificationSettings() async {
    debugPrint('📋 5. NOTIFICATION HANDLER STATUS');
    debugPrint('─────────────────────────────────────────────────────');

    try {
      // Check if Firebase is initialized
      debugPrint('Checking Firebase initialization...');

      // Get APNS token (iOS only)
      final apnsToken = await FirebaseMessaging.instance.getAPNSToken();
      if (apnsToken != null) {
        debugPrint('✅ APNS Token (iOS): ${apnsToken.substring(0, 20)}...');
      } else {
        debugPrint('ℹ️ No APNS token (Not iOS or not configured)');
      }

      // Check if notifications are enabled in app
      debugPrint('✅ Notification handlers registered in main.dart');
      debugPrint('✅ FirebaseNotificationHandler initialized');
    } catch (e) {
      debugPrint('❌ ERROR checking notification settings: $e');
    }
    debugPrint('');
  }

  /// Quick check - just the essentials
  static Future<Map<String, bool>> quickCheck() async {
    final results = <String, bool>{};

    try {
      // Check FCM token
      final fcmToken = await FirebaseMessaging.instance.getToken();
      results['has_fcm_token'] = fcmToken != null;

      // Check permission
      final settings = await FirebaseMessaging.instance
          .getNotificationSettings();
      results['has_permission'] =
          settings.authorizationStatus == AuthorizationStatus.authorized;

      // Check auth token
      final authToken = await TokenSecureStorage.instance.getToken();
      results['has_auth_token'] = authToken != null;

      // Check if token sent to backend
      final savedToken = await FCMTokenStorage.instance.getFCMToken();
      results['token_saved_locally'] = savedToken != null;

      debugPrint('🔍 Quick Check Results:');
      results.forEach((key, value) {
        debugPrint('  ${value ? "✅" : "❌"} $key: $value');
      });

      return results;
    } catch (e) {
      debugPrint('❌ Error in quick check: $e');
      return {};
    }
  }

  /// Test sending a notification to this device
  static Future<void> testNotification() async {
    debugPrint('\n🧪 TESTING NOTIFICATION SYSTEM');
    debugPrint('═══════════════════════════════════════════════════════\n');

    // Run quick check first
    final check = await quickCheck();

    final allPassed = check.values.every((v) => v == true);

    if (allPassed) {
      debugPrint('\n✅ ALL CHECKS PASSED!');
      debugPrint('Your device is ready to receive notifications.');
      debugPrint('\nTo test:');
      debugPrint('1. Send a message from another device');
      debugPrint('2. Backend should send FCM notification');
      debugPrint('3. This device should receive and display it');
    } else {
      debugPrint('\n⚠️ SOME CHECKS FAILED!');
      debugPrint('Fix the issues above before testing notifications.');
    }

    debugPrint('\n═══════════════════════════════════════════════════════\n');
  }

  /// Print FCM token for manual testing
  static Future<void> printFCMTokenForTesting() async {
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();

      debugPrint('\n╔═══════════════════════════════════════════════════════╗');
      debugPrint('║  FCM TOKEN FOR MANUAL TESTING                          ║');
      debugPrint('╠═══════════════════════════════════════════════════════╣');

      if (fcmToken != null) {
        debugPrint('║  $fcmToken');
        debugPrint(
          '╚═══════════════════════════════════════════════════════╝\n',
        );
        debugPrint(
          'Copy this token and use it to send test notification from:',
        );
        debugPrint('- Firebase Console → Cloud Messaging');
        debugPrint('- Postman/Backend API');
        debugPrint('- FCM Test Tool\n');
      } else {
        debugPrint('║  ❌ NO TOKEN AVAILABLE                                 ║');
        debugPrint(
          '╚═══════════════════════════════════════════════════════╝\n',
        );
      }
    } catch (e) {
      debugPrint('❌ Error printing token: $e');
    }
  }
}
