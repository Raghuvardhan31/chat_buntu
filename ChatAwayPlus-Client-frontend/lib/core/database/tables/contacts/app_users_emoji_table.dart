// lib/core/database/tables/app_users_emoji_table.dart

import 'package:chataway_plus/core/database/app_database.dart';
import 'package:sqflite/sqflite.dart';

// =============================================================================
// APP USERS EMOJI UPDATES TABLE - For Voice Hub (all users' emojis)
// =============================================================================

class AppUsersEmojiTable {
  // =============================================================================
  // SCHEMA DEFINITIONS
  // =============================================================================

  /// Table name constant
  static const String tableName = 'app_users_emoji_updates';

  /// Column name constants (match API/Model keys used by EmojiUpdateModel)
  static const String columnId = 'id';
  static const String columnUserId = 'user_id';
  static const String columnEmoji = 'emojis_update';
  static const String columnCaption = 'emojis_caption';
  static const String columnDeletedAt = 'deleted_at';
  static const String columnCreatedAt = 'created_at';
  static const String columnUpdatedAt = 'updated_at';

  // User nested data
  static const String columnUserFirstName = 'user_first_name';
  static const String columnUserLastName = 'user_last_name';
  static const String columnUserProfilePic = 'user_profile_pic';

  /// SQL CREATE TABLE statement - App Users Emoji Updates Table
  static const String createTableSQL =
      '''
CREATE TABLE $tableName (
  $columnId TEXT PRIMARY KEY,
  $columnUserId TEXT NOT NULL,
  $columnEmoji TEXT NOT NULL,
  $columnCaption TEXT,
  $columnDeletedAt TEXT,
  $columnCreatedAt TEXT,
  $columnUpdatedAt TEXT,
  $columnUserFirstName TEXT,
  $columnUserLastName TEXT,
  $columnUserProfilePic TEXT
)
''';

  // =============================================================================
  // SINGLETON INSTANCE
  // =============================================================================

  AppUsersEmojiTable._();
  static final AppUsersEmojiTable _instance = AppUsersEmojiTable._();
  static AppUsersEmojiTable get instance => _instance;

  // Get database from AppDatabaseManager
  Future<Database> get _database async {
    return await AppDatabaseManager.instance.database;
  }

  // =============================================================================
  // CRUD OPERATIONS
  // =============================================================================

  /// Save or update a single emoji
  Future<void> saveEmoji(Map<String, dynamic> emojiData) async {
    final db = await _database;
    await db.insert(
      tableName,
      emojiData,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Save multiple emojis (batch)
  Future<void> saveAllEmojis(List<Map<String, dynamic>> emojiList) async {
    final db = await _database;
    final batch = db.batch();
    for (final row in emojiList) {
      batch.insert(
        tableName,
        row,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Get all emojis (most recent first if updated_at exists)
  Future<List<Map<String, dynamic>>> getAllEmojis() async {
    final db = await _database;
    return await db.query(tableName, orderBy: '$columnUpdatedAt DESC');
  }

  /// Clear all emojis
  Future<int> deleteAllEmojis() async {
    final db = await _database;
    return await db.delete(tableName);
  }
}
