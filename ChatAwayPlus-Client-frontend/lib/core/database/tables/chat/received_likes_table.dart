import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../app_database.dart';

/// Local DB table for storing incoming like notifications (Likes Hub).
///
/// Stores both Chat Picture likes and SYVT (Share Your Voice Text) likes
/// received by the current user. Entries auto-expire after 24 hours.
class ReceivedLikesTable {
  static const String tableName = 'received_likes';

  static const String columnId = 'id';
  static const String columnCurrentUserId = 'current_user_id';
  static const String columnFromUserId = 'from_user_id';
  static const String columnFromUserName = 'from_user_name';
  static const String columnFromUserProfilePic = 'from_user_profile_pic';
  static const String columnLikeType = 'like_type'; // 'chat_picture' or 'voice'
  static const String columnStatusId = 'status_id';
  static const String columnLikeId = 'like_id';
  static const String columnMessage = 'message';
  static const String columnCreatedAt = 'created_at';

  static const String createTableSQL =
      '''
    CREATE TABLE IF NOT EXISTS $tableName (
      $columnId TEXT PRIMARY KEY,
      $columnCurrentUserId TEXT NOT NULL,
      $columnFromUserId TEXT NOT NULL,
      $columnFromUserName TEXT NOT NULL,
      $columnFromUserProfilePic TEXT,
      $columnLikeType TEXT NOT NULL,
      $columnStatusId TEXT,
      $columnLikeId TEXT,
      $columnMessage TEXT,
      $columnCreatedAt INTEGER NOT NULL
    )
  ''';

  static const String createIndexSQL =
      'CREATE INDEX IF NOT EXISTS idx_received_likes_user_time '
      'ON $tableName ($columnCurrentUserId, $columnCreatedAt DESC)';

  static Database? _dbCache;
  static Future<Database> get _database async {
    _dbCache ??= await AppDatabaseManager.instance.database;
    return _dbCache!;
  }

  /// Insert a received like notification.
  /// Deduplicates by (currentUserId, fromUserId, likeType) so that the same
  /// contact only ever has ONE entry per type within 24 hours. If the user
  /// changes their chat picture or SYVT and the same contact likes again,
  /// the old entry is replaced — no duplicates.
  static Future<void> insert({
    required String id,
    required String currentUserId,
    required String fromUserId,
    required String fromUserName,
    String? fromUserProfilePic,
    required String likeType,
    String? statusId,
    String? likeId,
    String? message,
    int? createdAt,
  }) async {
    try {
      final db = await _database;

      // Remove ALL existing entries for the same contact + same type
      // regardless of statusId. This prevents duplicates when the user
      // changes their chat picture / SYVT and the same contact likes again.
      await db.delete(
        tableName,
        where:
            '$columnCurrentUserId = ? AND $columnFromUserId = ? '
            'AND $columnLikeType = ?',
        whereArgs: [currentUserId, fromUserId, likeType],
      );

      await db.insert(tableName, {
        columnId: id,
        columnCurrentUserId: currentUserId,
        columnFromUserId: fromUserId,
        columnFromUserName: fromUserName,
        columnFromUserProfilePic: fromUserProfilePic,
        columnLikeType: likeType,
        columnStatusId: statusId,
        columnLikeId: likeId,
        columnMessage: message,
        columnCreatedAt: createdAt ?? DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [ReceivedLikes] insert error: $e');
      }
    }
  }

  /// Get all received likes for current user within last 24 hours, newest first
  static Future<List<Map<String, dynamic>>> getAll({
    required String currentUserId,
  }) async {
    try {
      final db = await _database;
      final cutoff = DateTime.now()
          .subtract(const Duration(hours: 24))
          .millisecondsSinceEpoch;

      return await db.query(
        tableName,
        where: '$columnCurrentUserId = ? AND $columnCreatedAt > ?',
        whereArgs: [currentUserId, cutoff],
        orderBy: '$columnCreatedAt DESC',
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [ReceivedLikes] getAll error: $e');
      }
      return [];
    }
  }

  /// Delete a specific like entry
  static Future<void> deleteById(String id) async {
    try {
      final db = await _database;
      await db.delete(tableName, where: '$columnId = ?', whereArgs: [id]);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [ReceivedLikes] deleteById error: $e');
      }
    }
  }

  /// Delete all expired entries (older than 24 hours)
  static Future<void> deleteExpired() async {
    try {
      final db = await _database;
      final cutoff = DateTime.now()
          .subtract(const Duration(hours: 24))
          .millisecondsSinceEpoch;

      await db.delete(
        tableName,
        where: '$columnCreatedAt <= ?',
        whereArgs: [cutoff],
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [ReceivedLikes] deleteExpired error: $e');
      }
    }
  }

  /// Clear all likes for current user
  static Future<void> clearAll({required String currentUserId}) async {
    try {
      final db = await _database;
      await db.delete(
        tableName,
        where: '$columnCurrentUserId = ?',
        whereArgs: [currentUserId],
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [ReceivedLikes] clearAll error: $e');
      }
    }
  }

  /// Get count of likes within last 24 hours
  static Future<int> getCount({required String currentUserId}) async {
    try {
      final db = await _database;
      final cutoff = DateTime.now()
          .subtract(const Duration(hours: 24))
          .millisecondsSinceEpoch;

      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $tableName '
        'WHERE $columnCurrentUserId = ? AND $columnCreatedAt > ?',
        [currentUserId, cutoff],
      );

      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [ReceivedLikes] getCount error: $e');
      }
      return 0;
    }
  }
}
