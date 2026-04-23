import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Battery Optimization Helper
///
/// Helps users disable battery optimization for faster notifications.
/// WhatsApp and other major apps are whitelisted by OEMs, but our app isn't.
/// This helper prompts users to manually disable battery optimization.
///
/// Why this matters:
/// - Android's Doze mode can delay notifications by minutes
/// - Battery optimization can kill background processes
/// - OEMs (Xiaomi, Samsung, Oppo, etc.) have aggressive battery saving
class BatteryOptimizationHelper {
  static const MethodChannel _channel = MethodChannel(
    'com.chatawayplus.app/battery',
  );

  /// Check if battery optimization is ignored (disabled) for our app
  static Future<bool> isIgnoringBatteryOptimizations() async {
    if (!Platform.isAndroid) return true;

    try {
      final result = await _channel.invokeMethod<bool>(
        'isIgnoringBatteryOptimizations',
      );
      return result ?? false;
    } catch (e) {
      debugPrint('⚠️ [Battery] Could not check battery optimization: $e');
      return true; // Assume it's fine if we can't check
    }
  }

  /// Request to disable battery optimization
  /// Opens system settings for the user to manually disable
  static Future<bool> requestIgnoreBatteryOptimizations() async {
    if (!Platform.isAndroid) return true;

    try {
      final result = await _channel.invokeMethod<bool>(
        'requestIgnoreBatteryOptimizations',
      );
      return result ?? false;
    } catch (e) {
      debugPrint('⚠️ [Battery] Could not request battery optimization: $e');
      return false;
    }
  }

  /// Open battery optimization settings directly
  static Future<void> openBatteryOptimizationSettings() async {
    if (!Platform.isAndroid) return;

    try {
      await _channel.invokeMethod('openBatterySettings');
    } catch (e) {
      debugPrint('⚠️ [Battery] Could not open battery settings: $e');
    }
  }

  /// Show dialog to prompt user to disable battery optimization
  static Future<void> showBatteryOptimizationDialog(
    BuildContext context,
  ) async {
    if (!Platform.isAndroid) return;

    final isIgnoring = await isIgnoringBatteryOptimizations();
    if (isIgnoring) {
      debugPrint('✅ [Battery] Already ignoring battery optimizations');
      return;
    }

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.battery_alert, color: Colors.orange),
            SizedBox(width: 8),
            Text('Faster Notifications'),
          ],
        ),
        content: const Text(
          'For instant message notifications like WhatsApp, please disable battery optimization for ChatAway+.\n\n'
          'This ensures notifications arrive immediately even when the app is closed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await requestIgnoreBatteryOptimizations();
            },
            child: const Text('Enable'),
          ),
        ],
      ),
    );
  }

  /// Show one-time prompt (with SharedPreferences check)
  /// Call this from settings or after login
  static Future<void> showOneTimePrompt(BuildContext context) async {
    // You can add SharedPreferences check here to show only once
    await showBatteryOptimizationDialog(context);
  }
}
