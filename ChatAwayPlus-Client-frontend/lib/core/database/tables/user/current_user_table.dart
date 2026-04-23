// ============================================================================
// CURRENT USER TABLES - Profile & Emoji Updates
// ============================================================================
// Stores logged-in user's profile information and emoji update history
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../../app_database.dart';

// ============================================================================
// CURRENT USER PROFILE TABLE - Schema Definition & CRUD Operations
// ============================================================================

class CurrentUserProfileTable {
  // ============================================================================
  // SCHEMA DEFINITIONS
  // ============================================================================

  /// Table name constant
  static const String tableName = 'current_user_profile';

  /// Column name constants
  static const String columnUserId =
      'user_id'; // ChatAway+ user UUID (PRIMARY KEY)
  static const String columnFirstName = 'first_name'; // User's first name
  static const String columnLastName = 'last_name'; // User's last name
  static const String columnMobileNo = 'mobile_no'; // User's mobile number
  static const String columnProfilePic =
      'profile_pic'; // Profile picture URL/path
  static const String columnChatPictureVersion =
      'chat_picture_version'; // Cache-busting version for chat/profile picture
  static const String columnStatusContent =
      'status_content'; // Current status text
  static const String columnStatusCreatedAt =
      'status_created_at'; // Status timestamp
  static const String columnCurrentEmoji =
      'emojis_update'; // Current emoji (single emoji string)
  static const String columnEmojiCaption =
      'emojis_caption'; // Emoji caption text
  static const String columnEmojiUpdatedAt =
      'emojis_updated_at'; // Emoji update timestamp
  static const String columnCreatedAt =
      'created_at'; // Account creation timestamp
  static const String columnLastUpdated = 'last_updated'; // Last sync timestamp

  /// SQL CREATE TABLE statement - Current User Profile Table
  static const String createTableSQL =
      '''
CREATE TABLE $tableName (
  $columnUserId TEXT PRIMARY KEY,           -- ChatAway+ user UUID (unique identifier)
  $columnFirstName TEXT,                     -- User's first name
  $columnLastName TEXT,                      -- User's last name
  $columnMobileNo TEXT NOT NULL,             -- User's mobile number
  $columnProfilePic TEXT,                    -- Profile picture URL (/uploads/profile/...)
  $columnChatPictureVersion TEXT,            -- Profile picture version (cache-busting)
  $columnStatusContent TEXT,                 -- Current status message content
  $columnStatusCreatedAt INTEGER,            -- Status creation timestamp (milliseconds)
  $columnCurrentEmoji TEXT,                  -- Current emoji (single emoji string, no spaces)
  $columnEmojiCaption TEXT,                  -- Emoji caption text
  $columnEmojiUpdatedAt INTEGER,             -- Emoji update timestamp (milliseconds)
  $columnCreatedAt INTEGER NOT NULL,         -- Account creation timestamp (milliseconds)
  $columnLastUpdated INTEGER NOT NULL        -- Last sync timestamp (milliseconds)
)
''';

  // ============================================================================
  // SINGLETON INSTANCE
  // ============================================================================

  CurrentUserProfileTable._();
  static final CurrentUserProfileTable _instance = CurrentUserProfileTable._();
  static CurrentUserProfileTable get instance => _instance;

  // Get database from AppDatabaseManager
  Future<Database> get _database async {
    return await AppDatabaseManager.instance.database;
  }

  // ============================================================================
  // CRUD OPERATIONS
  // ============================================================================

  // TODO: Add CRUD methods for current user profile
  // - Save/update profile
  // - Get profile by user ID
  // - Update profile fields
  // - Delete profile

  Future<Map<String, Object?>?> getByUserId(String userId) async {
    try {
      final db = await _database;
      final rows = await db.query(
        tableName,
        where: '$columnUserId = ?',
        whereArgs: [userId],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return rows.first;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[CurrentUserProfileTable] getByUserId error: $e');
      }
      return null;
    }
  }

  Future<Map<String, Object?>?> getAny() async {
    try {
      final db = await _database;
      final rows = await db.query(tableName, limit: 1);
      if (rows.isEmpty) return null;
      return rows.first;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[CurrentUserProfileTable] getAny error: $e');
      }
      return null;
    }
  }
}
