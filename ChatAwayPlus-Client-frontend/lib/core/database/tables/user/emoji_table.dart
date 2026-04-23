// lib/core/database/tables/emoji_table.dart

import 'package:sqflite/sqflite.dart';
import '../../app_database.dart';

// ============================================================================
// EMOJI UPDATES TABLE - Schema Definition & CRUD Operations
// ============================================================================

class EmojiTable {
  // ============================================================================
  // SCHEMA DEFINITIONS
  // ============================================================================

  /// Table name constant
  static const String tableName = 'emoji_updates';

  /// Column name constants
  static const String columnId = 'id'; // Server emoji-update UUID
  static const String columnUserId = 'user_id'; // User UUID
  static const String columnEmoji = 'emojis_update'; // Emoji string
  static const String columnCaption = 'emojis_caption'; // Caption text
  static const String columnDeletedAt = 'deleted_at'; // Soft delete timestamp
  static const String columnCreatedAt = 'created_at'; // Creation timestamp
  static const String columnUpdatedAt = 'updated_at'; // Last update timestamp

  // User nested data (from PUT response)
  static const String columnUserFirstName = 'user_first_name';
  static const String columnUserLastName = 'user_last_name';
  static const String columnUserProfilePic = 'user_profile_pic';

  /// SQL CREATE TABLE statement - Emoji Updates Table
  static const String createTableSQL =
      '''
CREATE TABLE $tableName (
  $columnId TEXT PRIMARY KEY,
  $columnUserId TEXT NOT NULL,
  $columnEmoji TEXT NOT NULL,
  $columnCaption TEXT,
  $columnDeletedAt TEXT,
  $columnCreatedAt TEXT NOT NULL,
  $columnUpdatedAt TEXT NOT NULL,
  $columnUserFirstName TEXT,
  $columnUserLastName TEXT,
  $columnUserProfilePic TEXT
)
''';

  // ============================================================================
  // SINGLETON INSTANCE
  // ============================================================================

  EmojiTable._();
  static final EmojiTable _instance = EmojiTable._();
  static EmojiTable get instance => _instance;

  // Get database from AppDatabaseManager
  Future<Database> get _database async {
    return await AppDatabaseManager.instance.database;
  }

  // ============================================================================
  // CRUD OPERATIONS
  // ============================================================================

  /// Save or update emoji
  Future<void> saveEmoji(Map<String, dynamic> emojiData) async {
    final db = await _database;
    await db.insert(
      tableName,
      emojiData,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Save multiple emojis (batch operation)
  Future<void> saveAllEmojis(List<Map<String, dynamic>> emojiList) async {
    final db = await _database;
    final batch = db.batch();

    for (final emoji in emojiList) {
      batch.insert(
        tableName,
        emoji,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  /// Get all emojis
  Future<List<Map<String, dynamic>>> getAllEmojis() async {
    final db = await _database;
    return await db.query(tableName, orderBy: '$columnUpdatedAt DESC');
  }

  /// Get current emoji (first row)
  Future<Map<String, dynamic>?> getEmoji() async {
    final db = await _database;
    final List<Map<String, dynamic>> maps = await db.query(tableName, limit: 1);
    return maps.isEmpty ? null : maps.first;
  }

  /// Get emoji by ID
  Future<Map<String, dynamic>?> getEmojiById(String id) async {
    final db = await _database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableName,
      where: '$columnId = ?',
      whereArgs: [id],
      limit: 1,
    );
    return maps.isEmpty ? null : maps.first;
  }

  /// Update emoji fields
  Future<int> updateEmoji(Map<String, dynamic> emojiData) async {
    final db = await _database;
    return await db.update(
      tableName,
      emojiData,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Delete all emojis (clear table)
  Future<int> deleteAllEmojis() async {
    final db = await _database;
    return await db.delete(tableName);
  }

  /// Delete emoji by ID
  Future<int> deleteEmojiById(String id) async {
    final db = await _database;
    return await db.delete(tableName, where: '$columnId = ?', whereArgs: [id]);
  }

  /// Delete all emojis that do NOT belong to the specified user
  Future<int> deleteOtherUsersEmojis(String userId) async {
    final db = await _database;
    return await db.delete(
      tableName,
      where: '$columnUserId <> ?',
      whereArgs: [userId],
    );
  }

  /// Check if emoji exists
  Future<bool> emojiExists() async {
    final db = await _database;
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM $tableName'),
    );
    return (count ?? 0) > 0;
  }

  /// Get total emoji count
  Future<int> getEmojiCount() async {
    final db = await _database;
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM $tableName'),
    );
    return count ?? 0;
  }
}
