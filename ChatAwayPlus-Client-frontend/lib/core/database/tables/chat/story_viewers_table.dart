import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../app_database.dart';

/// Database table for caching story viewers (offline-first)
/// Stores viewers for each story owned by the current user
class StoryViewersTable {
  static const String tableName = 'story_viewers';

  static const String columnCurrentUserId = 'current_user_id';
  static const String columnStoryId = 'story_id';
  static const String columnViewerId = 'viewer_id';
  static const String columnViewerFirstName = 'viewer_first_name';
  static const String columnViewerLastName = 'viewer_last_name';
  static const String columnViewerChatPicture = 'viewer_chat_picture';
  static const String columnViewerMobileNumber = 'viewer_mobile_number';
  static const String columnViewedAt = 'viewed_at';
  static const String columnCachedAt = 'cached_at';

  static const String createTableSQL = '''
    CREATE TABLE IF NOT EXISTS $tableName (
      $columnCurrentUserId TEXT NOT NULL,
      $columnStoryId TEXT NOT NULL,
      $columnViewerId TEXT NOT NULL,
      $columnViewerFirstName TEXT,
      $columnViewerLastName TEXT,
      $columnViewerChatPicture TEXT,
      $columnViewerMobileNumber TEXT,
      $columnViewedAt INTEGER NOT NULL,
      $columnCachedAt INTEGER NOT NULL,
      PRIMARY KEY ($columnCurrentUserId, $columnStoryId, $columnViewerId)
    )
  ''';

  static const String createIndexSQL = '''
    CREATE INDEX IF NOT EXISTS idx_story_viewers_story 
    ON $tableName ($columnCurrentUserId, $columnStoryId)
  ''';

  static Database? _dbCache;
  static Future<Database> get _database async {
    _dbCache ??= await AppDatabaseManager.instance.database;
    return _dbCache!;
  }

  /// Get all cached viewers for a story
  static Future<List<Map<String, dynamic>>> getViewersForStory({
    required String currentUserId,
    required String storyId,
  }) async {
    try {
      final db = await _database;

      final rows = await db.query(
        tableName,
        where: '$columnCurrentUserId = ? AND $columnStoryId = ?',
        whereArgs: [currentUserId, storyId],
        orderBy: '$columnViewedAt DESC',
      );

      return rows;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [StoryViewersTable] getViewersForStory error: $e');
      }
      return [];
    }
  }

  /// Get total viewer count for a story
  static Future<int> getViewerCount({
    required String currentUserId,
    required String storyId,
  }) async {
    try {
      final db = await _database;

      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $tableName WHERE $columnCurrentUserId = ? AND $columnStoryId = ?',
        [currentUserId, storyId],
      );

      return (result.first['count'] as int?) ?? 0;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [StoryViewersTable] getViewerCount error: $e');
      }
      return 0;
    }
  }

  /// Insert or update a viewer
  static Future<void> upsertViewer({
    required String currentUserId,
    required String storyId,
    required String viewerId,
    String? viewerFirstName,
    String? viewerLastName,
    String? viewerChatPicture,
    String? viewerMobileNumber,
    required DateTime viewedAt,
  }) async {
    try {
      final db = await _database;
      final now = DateTime.now().millisecondsSinceEpoch;

      await db.insert(
        tableName,
        {
          columnCurrentUserId: currentUserId,
          columnStoryId: storyId,
          columnViewerId: viewerId,
          columnViewerFirstName: viewerFirstName,
          columnViewerLastName: viewerLastName,
          columnViewerChatPicture: viewerChatPicture,
          columnViewerMobileNumber: viewerMobileNumber,
          columnViewedAt: viewedAt.millisecondsSinceEpoch,
          columnCachedAt: now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [StoryViewersTable] upsertViewer error: $e');
      }
    }
  }

  /// Replace all viewers for a story (bulk update)
  static Future<void> replaceViewersForStory({
    required String currentUserId,
    required String storyId,
    required List<Map<String, dynamic>> viewers,
  }) async {
    try {
      final db = await _database;
      final now = DateTime.now().millisecondsSinceEpoch;

      await db.transaction((txn) async {
        // Clear existing viewers for this story
        await txn.delete(
          tableName,
          where: '$columnCurrentUserId = ? AND $columnStoryId = ?',
          whereArgs: [currentUserId, storyId],
        );

        // Insert new viewers
        for (final viewer in viewers) {
          await txn.insert(tableName, {
            columnCurrentUserId: currentUserId,
            columnStoryId: storyId,
            columnViewerId: viewer['viewerId'] ?? '',
            columnViewerFirstName: viewer['firstName'],
            columnViewerLastName: viewer['lastName'],
            columnViewerChatPicture: viewer['chatPicture'],
            columnViewerMobileNumber: viewer['mobileNumber'],
            columnViewedAt: _parseTimestamp(viewer['viewedAt']),
            columnCachedAt: now,
          });
        }
      });

      if (kDebugMode) {
        debugPrint(
          '✅ [StoryViewersTable] Replaced ${viewers.length} viewers for story: $storyId',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [StoryViewersTable] replaceViewersForStory error: $e');
      }
    }
  }

  /// Delete all viewers for a story
  static Future<void> deleteViewersForStory({
    required String currentUserId,
    required String storyId,
  }) async {
    try {
      final db = await _database;
      await db.delete(
        tableName,
        where: '$columnCurrentUserId = ? AND $columnStoryId = ?',
        whereArgs: [currentUserId, storyId],
      );

      if (kDebugMode) {
        debugPrint('✅ [StoryViewersTable] Deleted viewers for story: $storyId');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [StoryViewersTable] deleteViewersForStory error: $e');
      }
    }
  }

  /// Clear all cached viewers for current user
  static Future<void> clearAllViewers({required String currentUserId}) async {
    try {
      final db = await _database;
      await db.delete(
        tableName,
        where: '$columnCurrentUserId = ?',
        whereArgs: [currentUserId],
      );

      if (kDebugMode) {
        debugPrint('🗑️ [StoryViewersTable] Cleared all viewers for user');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [StoryViewersTable] clearAllViewers error: $e');
      }
    }
  }

  static int _parseTimestamp(dynamic value) {
    if (value == null) return DateTime.now().millisecondsSinceEpoch;
    if (value is int) return value;
    if (value is DateTime) return value.millisecondsSinceEpoch;
    if (value is String) {
      try {
        return DateTime.parse(value).millisecondsSinceEpoch;
      } catch (_) {
        return DateTime.now().millisecondsSinceEpoch;
      }
    }
    return DateTime.now().millisecondsSinceEpoch;
  }
}
