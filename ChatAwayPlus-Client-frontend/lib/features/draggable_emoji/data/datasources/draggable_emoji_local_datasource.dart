import 'package:sqflite/sqflite.dart';
import 'package:chataway_plus/core/database/app_database.dart';
import '../models/draggable_emoji_model.dart';

/// Local data source for draggable emoji using SQLite
class DraggableEmojiLocalDataSource {
  /// Get user's emoji from local database
  /// Returns default emoji '😊' if not found
  static Future<String> getUserEmoji(String userId) async {
    try {
      final db = await AppDatabaseManager.instance.database;
      final result = await db.query(
        DraggableEmojiTable.tableName,
        where: '${DraggableEmojiTable.columnUserId} = ?',
        whereArgs: [userId],
        limit: 1,
      );

      if (result.isNotEmpty) {
        return result[0][DraggableEmojiTable.columnEmoji] as String? ?? '😊';
      }
      return '😊';
    } catch (e) {
      // Return default emoji on any error
      return '😊';
    }
  }

  /// Save user's emoji to local database
  static Future<void> saveUserEmoji(String emoji, String userId) async {
    try {
      final db = await AppDatabaseManager.instance.database;
      final now = DateTime.now().millisecondsSinceEpoch;

      await db.insert(
        DraggableEmojiTable.tableName,
        {
          DraggableEmojiTable.columnUserId: userId,
          DraggableEmojiTable.columnEmoji: emoji,
          DraggableEmojiTable.columnUpdatedAt: now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      // Log error but don't throw to avoid breaking UI
      print('Error saving emoji: $e');
    }
  }

  /// Get full emoji model for user
  static Future<DraggableEmojiModel?> getUserEmojiModel(String userId) async {
    try {
      final db = await AppDatabaseManager.instance.database;
      final result = await db.query(
        DraggableEmojiTable.tableName,
        where: '${DraggableEmojiTable.columnUserId} = ?',
        whereArgs: [userId],
        limit: 1,
      );

      if (result.isNotEmpty) {
        return DraggableEmojiModel.fromMap(result.first);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Delete user's emoji from local database
  static Future<void> deleteUserEmoji(String userId) async {
    try {
      final db = await AppDatabaseManager.instance.database;
      await db.delete(
        DraggableEmojiTable.tableName,
        where: '${DraggableEmojiTable.columnUserId} = ?',
        whereArgs: [userId],
      );
    } catch (e) {
      // Log error but don't throw
      print('Error deleting emoji: $e');
    }
  }

  /// Check if user has saved emoji
  static Future<bool> hasUserEmoji(String userId) async {
    try {
      final db = await AppDatabaseManager.instance.database;
      final result = await db.query(
        DraggableEmojiTable.tableName,
        where: '${DraggableEmojiTable.columnUserId} = ?',
        whereArgs: [userId],
        columns: ['COUNT(*) as count'],
      );

      return (result.first['count'] as int? ?? 0) > 0;
    } catch (e) {
      return false;
    }
  }
}
