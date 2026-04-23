import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../app_database.dart';

/// Database table for caching status like states (Share Your Voice Text likes)
class StatusLikesTable {
  static const String tableName = 'status_likes';

  static const String columnCurrentUserId = 'current_user_id';
  static const String columnStatusId = 'status_id';
  static const String columnStatusOwnerId = 'status_owner_id';
  static const String columnIsLiked = 'is_liked';
  static const String columnLikeId = 'like_id';
  static const String columnLikeCount = 'like_count';
  static const String columnToggleCount = 'toggle_count';
  static const String columnUpdatedAt = 'updated_at';

  /// Max toggles allowed per status (like + unlike = 4 toggles)
  static const int maxTogglesPerStatus = 4;

  static const String createTableSQL =
      'CREATE TABLE IF NOT EXISTS $tableName ('
      '$columnCurrentUserId TEXT NOT NULL,'
      '$columnStatusId TEXT NOT NULL,'
      '$columnStatusOwnerId TEXT,'
      '$columnIsLiked INTEGER NOT NULL DEFAULT 0,'
      '$columnLikeId TEXT,'
      '$columnLikeCount INTEGER,'
      '$columnToggleCount INTEGER NOT NULL DEFAULT 0,'
      '$columnUpdatedAt INTEGER NOT NULL,'
      'PRIMARY KEY ($columnCurrentUserId, $columnStatusId)'
      ')';

  /// Migration to add toggle_count column for existing databases
  static const String addToggleCountColumnSQL =
      'ALTER TABLE $tableName ADD COLUMN $columnToggleCount INTEGER NOT NULL DEFAULT 0';

  static const String createIndexSQL =
      'CREATE INDEX IF NOT EXISTS idx_status_likes_user_status '
      'ON $tableName ($columnCurrentUserId, $columnStatusId)';

  static Database? _dbCache;
  static Future<Database> get _database async {
    _dbCache ??= await AppDatabaseManager.instance.database;
    return _dbCache!;
  }

  /// Get the cached like state for a status
  static Future<bool?> getLikeState({
    required String currentUserId,
    required String statusId,
  }) async {
    try {
      final db = await _database;
      final rows = await db.query(
        tableName,
        columns: [columnIsLiked],
        where: '$columnCurrentUserId = ? AND $columnStatusId = ?',
        whereArgs: [currentUserId, statusId],
        limit: 1,
      );

      if (rows.isEmpty) return null;
      final raw = rows.first[columnIsLiked];
      final v = raw is int ? raw : int.tryParse(raw?.toString() ?? '');
      return v == 1;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [StatusLikes] getLikeState error: $e');
      }
      return null;
    }
  }

  /// Get toggle count for rate limiting (max 4 toggles per status)
  static Future<int> getToggleCount({
    required String currentUserId,
    required String statusId,
  }) async {
    try {
      final db = await _database;
      final rows = await db.query(
        tableName,
        columns: [columnToggleCount],
        where: '$columnCurrentUserId = ? AND $columnStatusId = ?',
        whereArgs: [currentUserId, statusId],
        limit: 1,
      );

      if (rows.isEmpty) return 0;
      final raw = rows.first[columnToggleCount];
      return raw is int ? raw : int.tryParse(raw?.toString() ?? '') ?? 0;
    } catch (e) {
      debugPrint('❌ [StatusLikes] getToggleCount error: $e');
      return 0;
    }
  }

  /// Increment toggle count when user toggles like
  static Future<int> incrementToggleCount({
    required String currentUserId,
    required String statusId,
  }) async {
    try {
      final db = await _database;
      final currentCount = await getToggleCount(
        currentUserId: currentUserId,
        statusId: statusId,
      );
      final newCount = currentCount + 1;

      await db.rawUpdate(
        'UPDATE $tableName SET $columnToggleCount = ? WHERE $columnCurrentUserId = ? AND $columnStatusId = ?',
        [newCount, currentUserId, statusId],
      );

      return newCount;
    } catch (e) {
      debugPrint('❌ [StatusLikes] incrementToggleCount error: $e');
      return 0;
    }
  }

  /// Get the cached like count for a status
  static Future<int?> getLikeCount({
    required String currentUserId,
    required String statusId,
  }) async {
    try {
      final db = await _database;
      final rows = await db.query(
        tableName,
        columns: [columnLikeCount],
        where: '$columnCurrentUserId = ? AND $columnStatusId = ?',
        whereArgs: [currentUserId, statusId],
        limit: 1,
      );

      if (rows.isEmpty) return null;
      final count = rows.first[columnLikeCount];
      return count as int?;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [StatusLikes] getLikeCount error: $e');
      }
      return null;
    }
  }

  /// Insert or update a status like state.
  /// Uses COALESCE to preserve existing toggle_count and status_owner_id
  /// when they are not explicitly provided (matches ChatPictureLikesTable pattern).
  static Future<void> upsert({
    required String currentUserId,
    required String statusId,
    required bool isLiked,
    String? statusOwnerId,
    String? likeId,
    int? likeCount,
    int? updatedAt,
  }) async {
    try {
      final db = await _database;
      final now = updatedAt ?? DateTime.now().millisecondsSinceEpoch;

      await db.execute(
        '''
        INSERT OR REPLACE INTO $tableName (
          $columnCurrentUserId, $columnStatusId, $columnStatusOwnerId,
          $columnIsLiked, $columnLikeId, $columnLikeCount, $columnToggleCount, $columnUpdatedAt
        ) VALUES (
          ?, ?, 
          COALESCE(?, (SELECT $columnStatusOwnerId FROM $tableName WHERE $columnCurrentUserId = ? AND $columnStatusId = ?)),
          ?, ?, ?,
          COALESCE((SELECT $columnToggleCount FROM $tableName WHERE $columnCurrentUserId = ? AND $columnStatusId = ?), 0),
          ?
        )
        ''',
        [
          currentUserId,
          statusId,
          statusOwnerId,
          currentUserId,
          statusId,
          isLiked ? 1 : 0,
          likeId,
          likeCount,
          currentUserId,
          statusId,
          now,
        ],
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [StatusLikes] upsert error: $e');
      }
      rethrow;
    }
  }

  /// Clear all cached likes for a specific status owner
  static Future<void> clearForStatusOwnerId({
    required String currentUserId,
    required String statusOwnerId,
  }) async {
    try {
      final db = await _database;
      await db.delete(
        tableName,
        where: '$columnCurrentUserId = ? AND $columnStatusOwnerId = ?',
        whereArgs: [currentUserId, statusOwnerId],
      );

      if (kDebugMode) {
        debugPrint('🗑️ [StatusLikes] clearForStatusOwnerId: $statusOwnerId');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [StatusLikes] clearForStatusOwnerId error: $e');
      }
    }
  }

  /// Clear all cached likes for current user (called on logout)
  static Future<void> clearAll({required String currentUserId}) async {
    try {
      final db = await _database;
      await db.delete(
        tableName,
        where: '$columnCurrentUserId = ?',
        whereArgs: [currentUserId],
      );

      if (kDebugMode) {
        debugPrint('🗑️ [StatusLikes] clearAll for user: $currentUserId');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [StatusLikes] clearAll error: $e');
      }
    }
  }
}
