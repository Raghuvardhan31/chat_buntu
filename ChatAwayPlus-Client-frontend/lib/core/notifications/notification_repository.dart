import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:chataway_plus/core/database/app_database.dart';
import 'package:sqflite/sqflite.dart';

/// Repository for handling notification-related database operations
///
/// 🔔 NOTIFICATION OPERATIONS:
/// • Preferences: Save/get user notification settings
/// • Chat Notifications: Store/retrieve Firebase notifications
/// • Read Status: Mark notifications as read/unread
/// • Statistics: Get notification counts and analytics
///
/// 📱 FIREBASE INTEGRATION:
/// • Save Firebase messages locally for offline access
/// • Store notification payloads and metadata
/// • Track notification display and read status
/// • Clean up old notifications automatically
class NotificationRepository {
  final AppDatabaseManager _databaseManager = AppDatabaseManager.instance;

  //=================================================================
  // NOTIFICATION PREFERENCES - User Settings Management
  //=================================================================

  /// Save user notification preference
  Future<bool> saveNotificationPreference({
    required String userId,
    required String notificationType,
    bool isEnabled = true,
    bool soundEnabled = true,
    bool vibrationEnabled = true,
    bool ledEnabled = true,
    String? customTone,
    String? quietHoursStart,
    String? quietHoursEnd,
  }) async {
    try {
      final db = await _databaseManager.database;
      final preferenceId = '${userId}_$notificationType';
      final now = DateTime.now().millisecondsSinceEpoch;

      final preferenceData = {
        'preference_id': preferenceId,
        'user_id': userId,
        'notification_type': notificationType,
        'is_enabled': isEnabled ? 1 : 0,
        'sound_enabled': soundEnabled ? 1 : 0,
        'vibration_enabled': vibrationEnabled ? 1 : 0,
        'led_enabled': ledEnabled ? 1 : 0,
        'custom_tone': customTone,
        'quiet_hours_start': quietHoursStart,
        'quiet_hours_end': quietHoursEnd,
        'created_at': now,
        'updated_at': now,
      };

      await db.insert(
        'notification_preferences',
        preferenceData,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return true;
    } catch (e) {
      debugPrint('❌ NotificationRepository: Failed to save preference: $e');
      return false;
    }
  }

  /// Get user notification preferences
  Future<List<Map<String, dynamic>>> getUserNotificationPreferences(
    String userId,
  ) async {
    try {
      final db = await _databaseManager.database;
      return await db.query(
        'notification_preferences',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
    } catch (e) {
      debugPrint('❌ NotificationRepository: Failed to get preferences: $e');
      return [];
    }
  }

  /// Update specific notification preference
  Future<bool> updateNotificationPreference(
    String preferenceId,
    Map<String, dynamic> updates,
  ) async {
    try {
      final db = await _databaseManager.database;
      updates['updated_at'] = DateTime.now().millisecondsSinceEpoch;

      await db.update(
        'notification_preferences',
        updates,
        where: 'preference_id = ?',
        whereArgs: [preferenceId],
      );
      return true;
    } catch (e) {
      debugPrint('❌ NotificationRepository: Failed to update preference: $e');
      return false;
    }
  }

  /// Check if notifications are enabled for a specific type
  Future<bool> isNotificationEnabled(
    String userId,
    String notificationType,
  ) async {
    try {
      final preferences = await getUserNotificationPreferences(userId);
      final preference = preferences.firstWhere(
        (pref) => pref['notification_type'] == notificationType,
        orElse: () => <String, dynamic>{},
      );

      if (preference.isEmpty) {
        return true; // Default to enabled
      }

      return preference['is_enabled'] == 1;
    } catch (e) {
      debugPrint('❌ NotificationRepository: Failed to check if enabled: $e');
      return true;
    }
  }

  //=================================================================
  // FIREBASE CHAT NOTIFICATIONS - Message Notifications Management
  //=================================================================

  /// Save Firebase chat notification
  Future<bool> saveChatNotification({
    required String notificationId,
    required String userId,
    required String senderId,
    required String messageContent,
    required String conversationId,
    String? notificationTitle,
    String? notificationBody,
    Map<String, dynamic>? dataPayload,
    String? firebaseMessageId,
  }) async {
    try {
      final db = await _databaseManager.database;
      final now = DateTime.now().millisecondsSinceEpoch;

      final notificationData = {
        'notification_id': notificationId,
        'user_id': userId,
        'sender_id': senderId,
        'message_content': messageContent,
        'conversation_id': conversationId,
        'notification_title': notificationTitle,
        'notification_body': notificationBody,
        'data_payload': dataPayload != null ? jsonEncode(dataPayload) : null,
        'is_read': 0,
        'is_displayed': 1,
        'firebase_message_id': firebaseMessageId,
        'received_at': now,
        'created_at': now,
      };

      await db.insert(
        'chat_notifications',
        notificationData,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return true;
    } catch (e) {
      debugPrint(
        '❌ NotificationRepository: Failed to save chat notification: $e',
      );
      return false;
    }
  }

  /// Get unread chat notifications for user
  Future<List<Map<String, dynamic>>> getUnreadChatNotifications(
    String userId,
  ) async {
    try {
      final db = await _databaseManager.database;
      return await db.query(
        'chat_notifications',
        where: 'user_id = ? AND is_read = ?',
        whereArgs: [userId, 0],
        orderBy: 'created_at DESC',
      );
    } catch (e) {
      debugPrint(
        '❌ NotificationRepository: Failed to get unread notifications: $e',
      );
      return [];
    }
  }

  /// Get chat notifications for specific conversation
  Future<List<Map<String, dynamic>>> getConversationNotifications(
    String conversationId,
  ) async {
    try {
      final db = await _databaseManager.database;
      return await db.query(
        'chat_notifications',
        where: 'conversation_id = ?',
        whereArgs: [conversationId],
        orderBy: 'created_at DESC',
      );
    } catch (e) {
      debugPrint(
        '❌ NotificationRepository: Failed to get conversation notifications: $e',
      );
      return [];
    }
  }

  /// Mark chat notification as read
  Future<bool> markChatNotificationAsRead(String notificationId) async {
    try {
      final db = await _databaseManager.database;
      await db.update(
        'chat_notifications',
        {'is_read': 1, 'updated_at': DateTime.now().millisecondsSinceEpoch},
        where: 'notification_id = ?',
        whereArgs: [notificationId],
      );
      return true;
    } catch (e) {
      debugPrint('❌ NotificationRepository: Failed to mark as read: $e');
      return false;
    }
  }

  /// Mark all chat notifications as read for user
  Future<bool> markAllChatNotificationsAsRead(String userId) async {
    try {
      final db = await _databaseManager.database;
      await db.update(
        'chat_notifications',
        {'is_read': 1, 'updated_at': DateTime.now().millisecondsSinceEpoch},
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      return true;
    } catch (e) {
      debugPrint('❌ NotificationRepository: Failed to mark all as read: $e');
      return false;
    }
  }

  /// Mark notification as displayed
  Future<bool> markNotificationAsDisplayed(String notificationId) async {
    try {
      final db = await _databaseManager.database;
      await db.update(
        'chat_notifications',
        {
          'is_displayed': 1,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'notification_id = ?',
        whereArgs: [notificationId],
      );
      return true;
    } catch (e) {
      debugPrint('❌ NotificationRepository: Failed to mark as displayed: $e');
      return false;
    }
  }

  //=================================================================
  // NOTIFICATION UTILITIES - Statistics and Cleanup
  //=================================================================

  /// Get notification statistics for user
  Future<Map<String, int>> getNotificationStats(String userId) async {
    try {
      final db = await _databaseManager.database;

      final unreadResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM chat_notifications WHERE user_id = ? AND is_read = 0',
        [userId],
      );

      final totalResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM chat_notifications WHERE user_id = ?',
        [userId],
      );

      final preferencesResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM notification_preferences WHERE user_id = ?',
        [userId],
      );

      return {
        'unread_notifications': unreadResult.first['count'] as int? ?? 0,
        'total_notifications': totalResult.first['count'] as int? ?? 0,
        'preferences_count': preferencesResult.first['count'] as int? ?? 0,
      };
    } catch (e) {
      debugPrint('❌ NotificationRepository: Failed to get stats: $e');
      return {
        'unread_notifications': 0,
        'total_notifications': 0,
        'preferences_count': 0,
      };
    }
  }

  /// Delete old notifications
  Future<bool> deleteOldNotifications({int daysOld = 30}) async {
    try {
      final db = await _databaseManager.database;
      final cutoffTime = DateTime.now()
          .subtract(Duration(days: daysOld))
          .millisecondsSinceEpoch;

      await db.delete(
        'chat_notifications',
        where: 'created_at < ?',
        whereArgs: [cutoffTime],
      );
      return true;
    } catch (e) {
      debugPrint(
        '❌ NotificationRepository: Failed to delete old notifications: $e',
      );
      return false;
    }
  }

  /// Clear all notification data
  Future<bool> clearAllNotificationData() async {
    try {
      final db = await _databaseManager.database;
      await db.delete('chat_notifications');
      await db.delete('notification_preferences');
      return true;
    } catch (e) {
      debugPrint('❌ NotificationRepository: Failed to clear all data: $e');
      return false;
    }
  }

  /// Initialize default notification preferences for new user
  Future<bool> initializeDefaultPreferences(String userId) async {
    try {
      final defaultTypes = [
        'chat_messages',
        'friend_requests',
        'voice_calls',
        'group_messages',
      ];

      bool allSuccess = true;

      for (final type in defaultTypes) {
        final success = await saveNotificationPreference(
          userId: userId,
          notificationType: type,
          isEnabled: true,
          soundEnabled: true,
          vibrationEnabled: true,
          ledEnabled: true,
        );

        if (!success) {
          allSuccess = false;
        }
      }

      return allSuccess;
    } catch (e) {
      debugPrint('❌ NotificationRepository: Failed to initialize defaults: $e');
      return false;
    }
  }

  /// Check if notification should be shown (considering quiet hours)
  Future<bool> shouldShowNotification(
    String userId,
    String notificationType,
  ) async {
    try {
      final preferences = await getUserNotificationPreferences(userId);
      final preference = preferences.firstWhere(
        (pref) => pref['notification_type'] == notificationType,
        orElse: () => <String, dynamic>{},
      );

      if (preference.isEmpty || preference['is_enabled'] != 1) {
        return false;
      }

      // Check quiet hours
      final quietStart = preference['quiet_hours_start'] as String?;
      final quietEnd = preference['quiet_hours_end'] as String?;

      if (quietStart != null && quietEnd != null) {
        final now = DateTime.now();
        final currentTime =
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

        if (quietStart.compareTo(currentTime) <= 0 &&
            currentTime.compareTo(quietEnd) <= 0) {
          return false; // In quiet hours
        }
      }

      return true;
    } catch (e) {
      debugPrint(
        '❌ NotificationRepository: Failed to check if should show: $e',
      );
      return false;
    }
  }

  /// Ensure notification tables exist
  Future<void> ensureNotificationTables() async {
    try {
      final db = await _databaseManager.database;

      // Create chat_notifications table if not exists
      await db.execute('''
        CREATE TABLE IF NOT EXISTS chat_notifications (
          notification_id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          sender_id TEXT NOT NULL,
          message_content TEXT NOT NULL,
          conversation_id TEXT NOT NULL,
          notification_title TEXT,
          notification_body TEXT,
          data_payload TEXT,
          is_read INTEGER DEFAULT 0,
          is_displayed INTEGER DEFAULT 0,
          firebase_message_id TEXT,
          received_at INTEGER,
          created_at INTEGER NOT NULL,
          updated_at INTEGER
        )
      ''');

      // Create notification_preferences table if not exists
      await db.execute('''
        CREATE TABLE IF NOT EXISTS notification_preferences (
          preference_id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          notification_type TEXT NOT NULL,
          is_enabled INTEGER DEFAULT 1,
          sound_enabled INTEGER DEFAULT 1,
          vibration_enabled INTEGER DEFAULT 1,
          led_enabled INTEGER DEFAULT 1,
          custom_tone TEXT,
          quiet_hours_start TEXT,
          quiet_hours_end TEXT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');

      if (kDebugMode) {
        debugPrint('✅ NotificationRepository: Tables ensured');
      }
    } catch (e) {
      debugPrint('❌ NotificationRepository: Failed to ensure tables: $e');
    }
  }
}
