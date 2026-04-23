import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Notification Cache Manager
///
/// Manages cached notification messages for WhatsApp-style grouped notifications
/// - Stores multiple messages per sender
/// - Maintains message history for InboxStyle notifications
/// - Provides methods to add, retrieve, and clear cached messages
class NotificationCacheManager {
  static const String _cacheKeyPrefix = 'notification_cache_';
  static const String _timestampKeyPrefix = 'notification_timestamp_';
  static const int _maxMessagesPerSender = 10;

  /// Get cached messages for a specific sender
  Future<List<Map<String, dynamic>>> getCachedMessages(String senderId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // NOTE: Removed excessive reload() - only reload once at start if needed
      final cacheKey = '$_cacheKeyPrefix$senderId';
      final cachedData = prefs.getString(cacheKey);

      if (cachedData == null || cachedData.isEmpty) {
        return [];
      }

      final List<dynamic> messageList = jsonDecode(cachedData);
      final messages = messageList
          .map((msg) => msg as Map<String, dynamic>)
          .toList();

      // Only log when there are cached messages
      if (messages.isNotEmpty) {
        debugPrint(
          '📦 [NotificationCache] Found ${messages.length} cached messages for sender: $senderId',
        );
      }
      return messages;
    } catch (e) {
      debugPrint('❌ [NotificationCache] Error getting cached messages: $e');
      return [];
    }
  }

  /// Add a new message to the cache for a specific sender
  Future<void> addMessageToCache({
    required String senderId,
    required String messageText,
    required String senderName,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // IMPORTANT: Reload to ensure we have the latest cache state
      // This prevents adding to stale cache data
      await prefs.reload();

      final cacheKey = '$_cacheKeyPrefix$senderId';
      final timestampKey = '$_timestampKeyPrefix$senderId';

      // Get existing messages (after reload)
      List<Map<String, dynamic>> messages = await getCachedMessages(senderId);

      // Add new message with timestamp
      final newMessage = {
        'text': messageText,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'senderName': senderName,
      };

      messages.add(newMessage);

      // Keep only the latest messages
      if (messages.length > _maxMessagesPerSender) {
        messages = messages.sublist(messages.length - _maxMessagesPerSender);
      }

      // Save updated messages
      await prefs.setString(cacheKey, jsonEncode(messages));
      await prefs.setInt(timestampKey, DateTime.now().millisecondsSinceEpoch);
      // NOTE: Removed reload() - not needed after write
      debugPrint(
        '📦 [NotificationCache] Cached message for $senderId (Total: ${messages.length})',
      );
    } catch (e) {
      debugPrint('❌ [NotificationCache] Error adding message to cache: $e');
      rethrow; // Rethrow to let caller handle the error
    }
  }

  /// Clear cached messages for a specific sender
  Future<void> clearCacheForSender(String senderId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cacheKeyPrefix$senderId';
      final timestampKey = '$_timestampKeyPrefix$senderId';

      // Check if cache exists before clearing
      final existingData = prefs.getString(cacheKey);
      if (existingData != null) {
        final List<dynamic> messageList = jsonDecode(existingData);
        debugPrint(
          '🗑️ [NotificationCache] Removing ${messageList.length} cached messages for sender: $senderId',
        );
      }

      // Remove both cache and timestamp keys
      await prefs.remove(cacheKey);
      await prefs.remove(timestampKey);
      // NOTE: Removed excessive reload() and verification - not needed
    } catch (e) {
      debugPrint('❌ [NotificationCache] Error clearing cache: $e');
      rethrow; // Rethrow to let caller handle the error
    }
  }

  /// Clear all cached messages
  Future<void> clearAllCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Reload to get current state
      await prefs.reload();

      final keys = prefs.getKeys();

      for (final key in keys) {
        if (key.startsWith(_cacheKeyPrefix) ||
            key.startsWith(_timestampKeyPrefix)) {
          await prefs.remove(key);
        }
      }
      // NOTE: Removed excessive reload() and verification for speed
    } catch (e) {
      debugPrint('❌ [NotificationCache] Error clearing all cache: $e');
      rethrow;
    }
  }

  /// Get all sender IDs that have cached messages
  Future<List<String>> getAllCachedSenderIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // NOTE: Removed reload() - not needed for read
      final keys = prefs.getKeys();

      final senderIds = keys
          .where((key) => key.startsWith(_cacheKeyPrefix))
          .map((key) => key.replaceFirst(_cacheKeyPrefix, ''))
          .toList();

      return senderIds;
    } catch (e) {
      debugPrint('❌ [NotificationCache] Error getting cached sender IDs: $e');
      return [];
    }
  }

  /// Get the count of cached messages for a specific sender
  Future<int> getCachedMessageCount(String senderId) async {
    final messages = await getCachedMessages(senderId);
    return messages.length;
  }

  /// Get the last message timestamp for a sender
  Future<int?> getLastMessageTimestamp(String senderId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestampKey = '$_timestampKeyPrefix$senderId';
      return prefs.getInt(timestampKey);
    } catch (e) {
      debugPrint(
        '❌ [NotificationCache] Error getting last message timestamp: $e',
      );
      return null;
    }
  }
}
