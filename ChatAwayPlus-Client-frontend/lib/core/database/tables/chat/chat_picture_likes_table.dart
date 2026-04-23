import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../app_database.dart';

class ChatPictureLikesTable {
  static const String tableName = 'chat_picture_likes';

  static const String columnCurrentUserId = 'current_user_id';
  static const String columnLikedUserId = 'liked_user_id';
  static const String columnTargetChatPictureId = 'target_chat_picture_id';
  static const String columnIsLiked = 'is_liked';
  static const String columnLikeId = 'like_id';
  static const String columnLikeCount = 'like_count';
  static const String columnToggleCount = 'toggle_count';
  static const String columnUpdatedAt = 'updated_at';

  static const String createTableSQL =
      'CREATE TABLE IF NOT EXISTS $tableName ('
      '$columnCurrentUserId TEXT NOT NULL,'
      '$columnLikedUserId TEXT NOT NULL,'
      '$columnTargetChatPictureId TEXT NOT NULL,'
      '$columnIsLiked INTEGER NOT NULL DEFAULT 0,'
      '$columnLikeId TEXT,'
      '$columnLikeCount INTEGER,'
      '$columnToggleCount INTEGER NOT NULL DEFAULT 0,'
      '$columnUpdatedAt INTEGER NOT NULL,'
      'PRIMARY KEY ($columnCurrentUserId, $columnLikedUserId, $columnTargetChatPictureId)'
      ')';

  /// Migration to add toggle_count column for existing databases
  static const String addToggleCountColumnSQL =
      'ALTER TABLE $tableName ADD COLUMN $columnToggleCount INTEGER NOT NULL DEFAULT 0';

  static const String createIndexSQL =
      'CREATE INDEX IF NOT EXISTS idx_chat_picture_likes_liked_user '
      'ON $tableName ($columnLikedUserId)';

  static Database? _dbCache;
  static Future<Database> get _database async {
    _dbCache ??= await AppDatabaseManager.instance.database;
    return _dbCache!;
  }

  static Future<bool?> getLikeState({
    required String currentUserId,
    required String likedUserId,
    required String targetChatPictureId,
  }) async {
    try {
      final db = await _database;
      final rows = await db.query(
        tableName,
        columns: [columnIsLiked],
        where:
            '$columnCurrentUserId = ? AND $columnLikedUserId = ? AND $columnTargetChatPictureId = ?',
        whereArgs: [currentUserId, likedUserId, targetChatPictureId],
        limit: 1,
      );

      if (rows.isEmpty) return null;
      final raw = rows.first[columnIsLiked];
      final v = raw is int ? raw : int.tryParse(raw?.toString() ?? '');
      return v == 1;
    } catch (e) {
      debugPrint('❌ [DB] getLikeState error: $e');
      return null;
    }
  }

  /// Get toggle count for rate limiting (max 4 toggles per picture)
  static Future<int> getToggleCount({
    required String currentUserId,
    required String likedUserId,
    required String targetChatPictureId,
  }) async {
    try {
      final db = await _database;
      final rows = await db.query(
        tableName,
        columns: [columnToggleCount],
        where:
            '$columnCurrentUserId = ? AND $columnLikedUserId = ? AND $columnTargetChatPictureId = ?',
        whereArgs: [currentUserId, likedUserId, targetChatPictureId],
        limit: 1,
      );

      if (rows.isEmpty) return 0;
      final raw = rows.first[columnToggleCount];
      return raw is int ? raw : int.tryParse(raw?.toString() ?? '') ?? 0;
    } catch (e) {
      debugPrint('❌ [DB] getToggleCount error: $e');
      return 0;
    }
  }

  static Future<void> upsert({
    required String currentUserId,
    required String likedUserId,
    required String targetChatPictureId,
    required bool isLiked,
    String? likeId,
    int? likeCount,
    int? toggleCount,
  }) async {
    try {
      final db = await _database;
      final now = DateTime.now().toIso8601String();

      await db.execute(
        '''
        INSERT OR REPLACE INTO $tableName (
          $columnCurrentUserId, $columnLikedUserId, $columnTargetChatPictureId,
          $columnIsLiked, $columnLikeId, $columnLikeCount, $columnToggleCount, $columnUpdatedAt
        ) VALUES (
          ?, ?, ?, ?, ?, ?,
          COALESCE(?, (SELECT $columnToggleCount FROM $tableName WHERE $columnCurrentUserId = ? AND $columnLikedUserId = ? AND $columnTargetChatPictureId = ?), 0),
          ?
        )
        ''',
        [
          currentUserId,
          likedUserId,
          targetChatPictureId,
          isLiked ? 1 : 0,
          likeId,
          likeCount,
          toggleCount,
          currentUserId,
          likedUserId,
          targetChatPictureId,
          now,
        ],
      );
    } catch (e) {
      debugPrint('❌ [DB] upsert error: $e');
    }
  }

  /// Increment toggle count when user toggles like
  static Future<int> incrementToggleCount({
    required String currentUserId,
    required String likedUserId,
    required String targetChatPictureId,
  }) async {
    try {
      final db = await _database;
      final currentCount = await getToggleCount(
        currentUserId: currentUserId,
        likedUserId: likedUserId,
        targetChatPictureId: targetChatPictureId,
      );
      final newCount = currentCount + 1;

      await db.execute(
        '''
        INSERT OR REPLACE INTO $tableName (
          $columnCurrentUserId, $columnLikedUserId, $columnTargetChatPictureId,
          $columnToggleCount, $columnIsLiked, $columnLikeId, $columnLikeCount, $columnUpdatedAt
        ) VALUES (
          ?, ?, ?, ?,
          COALESCE((SELECT $columnIsLiked FROM $tableName WHERE $columnCurrentUserId = ? AND $columnLikedUserId = ? AND $columnTargetChatPictureId = ?), 0),
          COALESCE((SELECT $columnLikeId FROM $tableName WHERE $columnCurrentUserId = ? AND $columnLikedUserId = ? AND $columnTargetChatPictureId = ?), NULL),
          COALESCE((SELECT $columnLikeCount FROM $tableName WHERE $columnCurrentUserId = ? AND $columnLikedUserId = ? AND $columnTargetChatPictureId = ?), NULL),
          ?
        )
        ''',
        [
          currentUserId,
          likedUserId,
          targetChatPictureId,
          newCount,
          currentUserId,
          likedUserId,
          targetChatPictureId,
          currentUserId,
          likedUserId,
          targetChatPictureId,
          currentUserId,
          likedUserId,
          targetChatPictureId,
          DateTime.now().toIso8601String(),
        ],
      );

      return newCount;
    } catch (e) {
      debugPrint('❌ [DB] incrementToggleCount error: $e');
      return 0;
    }
  }

  static Future<void> clearForLikedUserId({
    required String currentUserId,
    required String likedUserId,
  }) async {
    try {
      final db = await _database;
      await db.delete(
        tableName,
        where: '$columnCurrentUserId = ? AND $columnLikedUserId = ?',
        whereArgs: [currentUserId, likedUserId],
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [ChatPictureLikes] clearForLikedUserId error: $e');
      }
    }
  }
}
