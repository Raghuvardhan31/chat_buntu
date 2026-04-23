import 'dart:async';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';

class FCMTokenService {
  // Singleton
  static final FCMTokenService _instance = FCMTokenService._internal();
  factory FCMTokenService() => _instance;
  FCMTokenService._internal();
  static FCMTokenService get instance => _instance;

  StreamSubscription<String>? _tokenRefreshSub;

  Future<bool> requestPermission() async {
    try {
      if (Platform.isIOS) {
        final settings = await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          criticalAlert: false,
          provisional: false,
        );

        final granted =
            settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;

        debugPrint(
          '📱 iOS Notification Permission: ${granted ? "✅ Granted" : "❌ Denied"}',
        );
        return granted;
      } else {
        final status = await Permission.notification.request();
        final granted = status == PermissionStatus.granted;

        debugPrint(
          '📱 Android Notification Permission: ${granted ? "✅ Granted" : "❌ Denied"}',
        );
        return granted;
      }
    } catch (e) {
      debugPrint('❌ Error requesting permission: $e');
      return false;
    }
  }

  Future<bool> isPermissionGranted() async {
    try {
      if (Platform.isIOS) {
        final settings = await FirebaseMessaging.instance
            .getNotificationSettings();
        return settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;
      } else {
        final status = await Permission.notification.status;
        return status == PermissionStatus.granted;
      }
    } catch (e) {
      debugPrint('❌ Error checking permission: $e');
      return false;
    }
  }

  Future<String?> getToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();

      if (token != null) {
        debugPrint('🔑 FCM Token Retrieved: ${token.substring(0, 20)}...');
      } else {
        debugPrint('⚠️ FCM Token is null');
      }

      return token;
    } catch (e) {
      debugPrint('❌ Error getting FCM token: $e');
      return null;
    }
  }

  Future<void> deleteToken() async {
    try {
      await FirebaseMessaging.instance.deleteToken();
      debugPrint('🗑️ FCM Token deleted');
    } catch (e) {
      debugPrint('❌ Error deleting FCM token: $e');
    }
  }

  StreamSubscription<String> registerOnTokenRefreshOnce(
    void Function(String) callback,
  ) {
    if (_tokenRefreshSub != null) {
      debugPrint('🔔 Token refresh listener already registered — reusing it');
      return _tokenRefreshSub!;
    }

    _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen((
      String newToken,
    ) {
      try {
        debugPrint('🔄 FCM Token Refreshed: ${newToken.substring(0, 20)}...');
        callback(newToken);
      } catch (e, st) {
        debugPrint('🔄 Error in token refresh callback: $e\n$st');
      }
    });

    debugPrint('🔔 Token refresh listener registered');
    return _tokenRefreshSub!;
  }

  StreamSubscription<String> onTokenRefreshAsStream(
    void Function(String) callback,
  ) {
    final sub = FirebaseMessaging.instance.onTokenRefresh.listen((
      String newToken,
    ) {
      debugPrint(
        '🔄 FCM Token Refreshed (stream): ${newToken.substring(0, 20)}...',
      );
      callback(newToken);
    });
    return sub;
  }

  Future<void> removeTokenRefreshListener() async {
    if (_tokenRefreshSub != null) {
      await _tokenRefreshSub!.cancel();
      _tokenRefreshSub = null;
      debugPrint('🔕 Token refresh listener removed');
    } else {
      debugPrint('🔕 No token refresh listener to remove');
    }
  }
}
