import 'package:chataway_plus/core/database/app_database.dart';
import 'package:chataway_plus/features/mood_emoji/data/models/mood_emoji_model.dart';
import 'package:sqflite/sqflite.dart';

/// Local datasource for mood emoji operations
class MoodEmojiLocalDatasource {
  static final MoodEmojiLocalDatasource instance =
      MoodEmojiLocalDatasource._internal();

  MoodEmojiLocalDatasource._internal();

  /// Get the database instance
  Future<Database> get _database async {
    return await AppDatabaseManager.instance.database;
  }

  /// Get user's current mood emoji (returns null if expired or not set)
  Future<MoodEmojiModel?> getUserMoodEmoji(String userId) async {
    try {
      final db = await _database;
      final List<Map<String, dynamic>> maps = await db.query(
        MoodEmojiTable.tableName,
        where: '${MoodEmojiTable.columnUserId} = ?',
        whereArgs: [userId],
      );

      if (maps.isEmpty) return null;

      final moodEmoji = MoodEmojiModel.fromMap(maps.first);

      // Return null if expired
      if (moodEmoji.isExpired) {
        await deleteUserMoodEmoji(userId);
        return null;
      }

      return moodEmoji;
    } catch (e) {
      return null;
    }
  }

  /// Save or update user's mood emoji
  Future<bool> saveMoodEmoji({
    required String userId,
    required String emoji,
    required DateTime expiryTimestamp,
  }) async {
    try {
      final db = await _database;
      final now = DateTime.now();

      final moodEmoji = MoodEmojiModel(
        userId: userId,
        emoji: emoji,
        expiryTimestamp: expiryTimestamp,
        createdAt: now,
      );

      await db.insert(
        MoodEmojiTable.tableName,
        moodEmoji.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Delete user's mood emoji
  Future<bool> deleteUserMoodEmoji(String userId) async {
    try {
      final db = await _database;
      await db.delete(
        MoodEmojiTable.tableName,
        where: '${MoodEmojiTable.columnUserId} = ?',
        whereArgs: [userId],
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Check if user has active (non-expired) mood emoji
  Future<bool> hasActiveMoodEmoji(String userId) async {
    final moodEmoji = await getUserMoodEmoji(userId);
    return moodEmoji != null && !moodEmoji.isExpired;
  }

  /// Clean up expired mood emojis (can be called periodically)
  Future<void> cleanupExpiredEmojis() async {
    try {
      final db = await _database;
      final now = DateTime.now().millisecondsSinceEpoch;

      await db.delete(
        MoodEmojiTable.tableName,
        where: '${MoodEmojiTable.columnExpiryTimestamp} < ?',
        whereArgs: [now],
      );
    } catch (e) {
      // Silent cleanup failure
    }
  }
}
