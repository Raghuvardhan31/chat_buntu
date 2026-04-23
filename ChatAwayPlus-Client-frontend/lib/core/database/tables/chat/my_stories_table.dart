import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../app_database.dart';

/// Database table for caching current user's stories (offline-first)
/// Stores stories created by the logged-in user for offline viewing
class MyStoriesTable {
  static const String tableName = 'my_stories';

  static const String columnCurrentUserId = 'current_user_id';
  static const String columnStoryId = 'story_id';
  static const String columnMediaUrl = 'media_url';
  static const String columnMediaType = 'media_type';
  static const String columnCaption = 'caption';
  static const String columnDuration = 'duration';
  static const String columnViewsCount = 'views_count';
  static const String columnExpiresAt = 'expires_at';
  static const String columnBackgroundColor = 'background_color';
  static const String columnCreatedAt = 'created_at';
  static const String columnUpdatedAt = 'updated_at';
  static const String columnIsViewed = 'is_viewed';
  static const String columnThumbnailUrl = 'thumbnail_url';
  static const String columnVideoDuration = 'video_duration';
  static const String columnCachedAt = 'cached_at';

  static const String createTableSQL =
      '''
    CREATE TABLE IF NOT EXISTS $tableName (
      $columnCurrentUserId TEXT NOT NULL,
      $columnStoryId TEXT NOT NULL,
      $columnMediaUrl TEXT NOT NULL,
      $columnMediaType TEXT NOT NULL DEFAULT 'image',
      $columnCaption TEXT,
      $columnDuration INTEGER NOT NULL DEFAULT 5,
      $columnViewsCount INTEGER NOT NULL DEFAULT 0,
      $columnExpiresAt INTEGER NOT NULL,
      $columnBackgroundColor TEXT,
      $columnCreatedAt INTEGER NOT NULL,
      $columnUpdatedAt INTEGER NOT NULL,
      $columnIsViewed INTEGER NOT NULL DEFAULT 0,
      $columnThumbnailUrl TEXT,
      $columnVideoDuration REAL,
      $columnCachedAt INTEGER NOT NULL,
      PRIMARY KEY ($columnCurrentUserId, $columnStoryId)
    )
  ''';

  static const String createIndexSQL =
      '''
    CREATE INDEX IF NOT EXISTS idx_my_stories_user_expires 
    ON $tableName ($columnCurrentUserId, $columnExpiresAt)
  ''';

  static Database? _dbCache;
  static Future<Database> get _database async {
    _dbCache ??= await AppDatabaseManager.instance.database;
    return _dbCache!;
  }

  /// Get all cached stories for current user (not expired)
  static Future<List<Map<String, dynamic>>> getMyStories({
    required String currentUserId,
  }) async {
    try {
      final db = await _database;
      final now = DateTime.now().millisecondsSinceEpoch;

      final rows = await db.query(
        tableName,
        where: '$columnCurrentUserId = ? AND $columnExpiresAt > ?',
        whereArgs: [currentUserId, now],
        orderBy: '$columnCreatedAt DESC',
      );

      return rows;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [MyStoriesTable] getMyStories error: $e');
      }
      return [];
    }
  }

  /// Get a single story by ID
  static Future<Map<String, dynamic>?> getStoryById({
    required String currentUserId,
    required String storyId,
  }) async {
    try {
      final db = await _database;
      final rows = await db.query(
        tableName,
        where: '$columnCurrentUserId = ? AND $columnStoryId = ?',
        whereArgs: [currentUserId, storyId],
        limit: 1,
      );

      return rows.isNotEmpty ? rows.first : null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [MyStoriesTable] getStoryById error: $e');
      }
      return null;
    }
  }

  /// Insert or update a story
  static Future<void> upsertStory({
    required String currentUserId,
    required String storyId,
    required String mediaUrl,
    required String mediaType,
    String? caption,
    required int duration,
    required int viewsCount,
    required DateTime expiresAt,
    String? backgroundColor,
    required DateTime createdAt,
    required DateTime updatedAt,
    bool isViewed = false,
    String? thumbnailUrl,
    double? videoDuration,
  }) async {
    try {
      final db = await _database;
      final now = DateTime.now().millisecondsSinceEpoch;

      await db.insert(tableName, {
        columnCurrentUserId: currentUserId,
        columnStoryId: storyId,
        columnMediaUrl: mediaUrl,
        columnMediaType: mediaType,
        columnCaption: caption,
        columnDuration: duration,
        columnViewsCount: viewsCount,
        columnExpiresAt: expiresAt.millisecondsSinceEpoch,
        columnBackgroundColor: backgroundColor,
        columnCreatedAt: createdAt.millisecondsSinceEpoch,
        columnUpdatedAt: updatedAt.millisecondsSinceEpoch,
        columnIsViewed: isViewed ? 1 : 0,
        columnThumbnailUrl: thumbnailUrl,
        columnVideoDuration: videoDuration,
        columnCachedAt: now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      if (kDebugMode) {
        debugPrint('✅ [MyStoriesTable] Upserted story: $storyId');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [MyStoriesTable] upsertStory error: $e');
      }
    }
  }

  /// Update views count for a story
  static Future<void> updateViewsCount({
    required String currentUserId,
    required String storyId,
    required int viewsCount,
  }) async {
    try {
      final db = await _database;
      await db.update(
        tableName,
        {columnViewsCount: viewsCount},
        where: '$columnCurrentUserId = ? AND $columnStoryId = ?',
        whereArgs: [currentUserId, storyId],
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [MyStoriesTable] updateViewsCount error: $e');
      }
    }
  }

  /// Delete a story
  static Future<void> deleteStory({
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
        debugPrint('✅ [MyStoriesTable] Deleted story: $storyId');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [MyStoriesTable] deleteStory error: $e');
      }
    }
  }

  /// Delete all expired stories
  static Future<void> deleteExpiredStories({
    required String currentUserId,
  }) async {
    try {
      final db = await _database;
      final now = DateTime.now().millisecondsSinceEpoch;

      final count = await db.delete(
        tableName,
        where: '$columnCurrentUserId = ? AND $columnExpiresAt <= ?',
        whereArgs: [currentUserId, now],
      );

      if (kDebugMode && count > 0) {
        debugPrint('🗑️ [MyStoriesTable] Deleted $count expired stories');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [MyStoriesTable] deleteExpiredStories error: $e');
      }
    }
  }

  /// Clear all stories for current user
  static Future<void> clearAllStories({required String currentUserId}) async {
    try {
      final db = await _database;
      await db.delete(
        tableName,
        where: '$columnCurrentUserId = ?',
        whereArgs: [currentUserId],
      );

      if (kDebugMode) {
        debugPrint('🗑️ [MyStoriesTable] Cleared all stories for user');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [MyStoriesTable] clearAllStories error: $e');
      }
    }
  }

  /// Bulk insert stories (replaces all existing)
  static Future<void> replaceAllStories({
    required String currentUserId,
    required List<Map<String, dynamic>> stories,
  }) async {
    try {
      final db = await _database;
      final now = DateTime.now().millisecondsSinceEpoch;

      await db.transaction((txn) async {
        // Clear existing stories
        await txn.delete(
          tableName,
          where: '$columnCurrentUserId = ?',
          whereArgs: [currentUserId],
        );

        // Insert new stories
        for (final story in stories) {
          await txn.insert(tableName, {
            columnCurrentUserId: currentUserId,
            columnStoryId: story['id'] ?? story['storyId'],
            columnMediaUrl: story['mediaUrl'] ?? '',
            columnMediaType: story['mediaType'] ?? 'image',
            columnCaption: story['caption'],
            columnDuration: story['duration'] ?? 5,
            columnViewsCount: story['viewsCount'] ?? 0,
            columnExpiresAt: _parseTimestamp(story['expiresAt']),
            columnBackgroundColor: story['backgroundColor'],
            columnCreatedAt: _parseTimestamp(story['createdAt']),
            columnUpdatedAt: _parseTimestamp(story['updatedAt']),
            columnIsViewed: (story['isViewed'] == true) ? 1 : 0,
            columnThumbnailUrl: story['thumbnailUrl'],
            columnVideoDuration: (story['videoDuration'] as num?)?.toDouble(),
            columnCachedAt: now,
          });
        }
      });

      if (kDebugMode) {
        debugPrint(
          '✅ [MyStoriesTable] Replaced all stories: ${stories.length} items',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [MyStoriesTable] replaceAllStories error: $e');
      }
    }
  }

  static int _parseTimestamp(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is DateTime) return value.millisecondsSinceEpoch;
    if (value is num) return value.toInt();
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return 0;
      // Try parsing as int first (milliseconds)
      final asInt = int.tryParse(trimmed);
      if (asInt != null) return asInt;
      // Try parsing as ISO8601 date string
      final dt = DateTime.tryParse(trimmed);
      if (dt != null) return dt.millisecondsSinceEpoch;
      return 0;
    }
    return 0;
  }
}
