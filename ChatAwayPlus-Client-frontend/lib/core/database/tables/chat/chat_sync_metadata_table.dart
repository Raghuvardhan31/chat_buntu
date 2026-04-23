// ============================================================================
// CHAT SYNC METADATA TABLE - Schema Definition & CRUD Operations
// ============================================================================
// This file stores last sync time for each user conversation to optimize
// message fetching using the sync API
// ============================================================================

import 'package:chataway_plus/core/database/app_database.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

// ============================================================================
// CHAT SYNC METADATA TABLE
// ============================================================================

class ChatSyncMetadataTable {
  static const bool _verboseLogs = false;

  // ============================================================================
  // SCHEMA DEFINITIONS
  // ============================================================================

  /// Table name constant
  static const String tableName = 'chat_sync_metadata';

  /// Column name constants
  static const String columnId = 'id';
  static const String columnCurrentUserId = 'current_user_id';
  static const String columnOtherUserId = 'other_user_id';
  static const String columnLastSyncTime = 'last_sync_time';
  static const String columnUpdatedAt = 'updated_at';

  /// SQL CREATE TABLE statement - Chat Sync Metadata Table
  ///
  /// Stores last sync time for each conversation to optimize message fetching
  static const String createTableSQL =
      '''
CREATE TABLE $tableName (
  $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
  $columnCurrentUserId TEXT NOT NULL,        -- Current user's UUID
  $columnOtherUserId TEXT NOT NULL,          -- Other user's UUID
  $columnLastSyncTime TEXT NOT NULL,         -- ISO 8601 datetime string
  $columnUpdatedAt INTEGER NOT NULL,         -- Timestamp when last updated
  UNIQUE($columnCurrentUserId, $columnOtherUserId)
)
''';

  /// Index for faster queries by user pair
  static const String createIndexSQL =
      '''
CREATE INDEX IF NOT EXISTS idx_sync_user_pair
ON $tableName ($columnCurrentUserId, $columnOtherUserId)
''';

  // ============================================================================
  // SINGLETON INSTANCE
  // ============================================================================

  ChatSyncMetadataTable._();
  static final ChatSyncMetadataTable _instance = ChatSyncMetadataTable._();
  static ChatSyncMetadataTable get instance => _instance;

  // Get database from AppDatabaseManager
  Future<Database> get _database async {
    return await AppDatabaseManager.instance.database;
  }

  // ============================================================================
  // CRUD OPERATIONS
  // ============================================================================

  /// Get last sync time for a specific conversation
  /// Returns null if no sync has been performed yet
  Future<String?> getLastSyncTime({
    required String currentUserId,
    required String otherUserId,
  }) async {
    final db = await _database;

    try {
      final results = await db.query(
        tableName,
        where: '$columnCurrentUserId = ? AND $columnOtherUserId = ?',
        whereArgs: [currentUserId, otherUserId],
        limit: 1,
      );

      if (results.isEmpty) {
        if (_verboseLogs && kDebugMode) {
          debugPrint(
            '📅 No sync metadata found for conversation: $currentUserId <-> $otherUserId',
          );
        }
        return null;
      }

      return results.first[columnLastSyncTime] as String?;
    } catch (e) {
      debugPrint('❌ Error getting last sync time: $e');
      return null;
    }
  }

  /// Save/update last sync time for a specific conversation
  Future<void> saveLastSyncTime({
    required String currentUserId,
    required String otherUserId,
    required String lastSyncTime,
  }) async {
    final db = await _database;

    try {
      await db.insert(tableName, {
        columnCurrentUserId: currentUserId,
        columnOtherUserId: otherUserId,
        columnLastSyncTime: lastSyncTime,
        columnUpdatedAt: DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      if (_verboseLogs && kDebugMode) {
        debugPrint(
          '💾 Saved last sync time for $currentUserId <-> $otherUserId: $lastSyncTime',
        );
      }
    } catch (e) {
      debugPrint('❌ Error saving last sync time: $e');
      rethrow;
    }
  }

  /// Check if sync metadata exists for a conversation
  Future<bool> hasSyncMetadata({
    required String currentUserId,
    required String otherUserId,
  }) async {
    final syncTime = await getLastSyncTime(
      currentUserId: currentUserId,
      otherUserId: otherUserId,
    );
    return syncTime != null;
  }

  /// Delete sync metadata for a specific conversation
  Future<void> deleteSyncMetadata({
    required String currentUserId,
    required String otherUserId,
  }) async {
    final db = await _database;

    try {
      await db.delete(
        tableName,
        where: '$columnCurrentUserId = ? AND $columnOtherUserId = ?',
        whereArgs: [currentUserId, otherUserId],
      );

      if (_verboseLogs && kDebugMode) {
        debugPrint(
          '🗑️ Deleted sync metadata for $currentUserId <-> $otherUserId',
        );
      }
    } catch (e) {
      debugPrint('❌ Error deleting sync metadata: $e');
      rethrow;
    }
  }

  /// Clear all sync metadata (e.g., during logout)
  Future<void> clearAllSyncMetadata() async {
    final db = await _database;

    try {
      await db.delete(tableName);
      if (_verboseLogs && kDebugMode) {
        debugPrint('🗑️ Cleared all sync metadata');
      }
    } catch (e) {
      debugPrint('❌ Error clearing sync metadata: $e');
      rethrow;
    }
  }
}
