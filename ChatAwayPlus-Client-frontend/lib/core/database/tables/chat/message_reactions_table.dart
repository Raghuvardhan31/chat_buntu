import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../app_database.dart';
import '../../../../features/chat/data/socket/socket_models/index.dart';

/// Database table for message reactions
/// Stores reactions for offline access and sync management
class MessageReactionsTable {
  static const String tableName = 'message_reactions';

  static const String columnId = 'id';
  static const String columnMessageId = 'message_id';
  static const String columnUserId = 'user_id';
  static const String columnEmoji = 'emoji';
  static const String columnCreatedAt = 'created_at';
  static const String columnUserFirstName = 'user_first_name';
  static const String columnUserLastName = 'user_last_name';
  static const String columnUserChatPicture = 'user_chat_picture';
  static const String columnIsSynced = 'is_synced';

  static const String createTableSQL =
      'CREATE TABLE IF NOT EXISTS $tableName ('
      '$columnId TEXT PRIMARY KEY,'
      '$columnMessageId TEXT NOT NULL,'
      '$columnUserId TEXT NOT NULL,'
      '$columnEmoji TEXT NOT NULL,'
      '$columnCreatedAt TEXT NOT NULL,'
      '$columnUserFirstName TEXT,'
      '$columnUserLastName TEXT,'
      '$columnUserChatPicture TEXT,'
      '$columnIsSynced INTEGER DEFAULT 1,'
      'UNIQUE($columnMessageId, $columnUserId)'
      ')';

  static const String createMessageIndexSQL =
      'CREATE INDEX IF NOT EXISTS idx_reactions_message '
      'ON $tableName ($columnMessageId)';

  static const String createUserIndexSQL =
      'CREATE INDEX IF NOT EXISTS idx_reactions_user '
      'ON $tableName ($columnUserId)';

  static Database? _dbCache;
  static Future<Database> get _database async {
    _dbCache ??= await AppDatabaseManager.instance.database;
    return _dbCache!;
  }

  /// Get all reactions for a specific message
  static Future<List<MessageReaction>> getReactionsForMessage(
    String messageId,
  ) async {
    try {
      final db = await _database;
      final rows = await db.query(
        tableName,
        where: '$columnMessageId = ?',
        whereArgs: [messageId],
        orderBy: '$columnCreatedAt ASC',
      );

      return rows.map((row) {
        return MessageReaction(
          id: row[columnId] as String,
          messageId: row[columnMessageId] as String,
          userId: row[columnUserId] as String,
          emoji: row[columnEmoji] as String,
          createdAt: DateTime.parse(row[columnCreatedAt] as String),
          userFirstName: row[columnUserFirstName] as String?,
          userLastName: row[columnUserLastName] as String?,
          userChatPicture: row[columnUserChatPicture] as String?,
          isSynced: (row[columnIsSynced] as int?) == 1,
        );
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [MessageReactions] getReactionsForMessage error: $e');
      }
      return [];
    }
  }

  /// Get user's reaction for a specific message
  static Future<MessageReaction?> getUserReactionForMessage({
    required String messageId,
    required String userId,
  }) async {
    try {
      final db = await _database;
      final rows = await db.query(
        tableName,
        where: '$columnMessageId = ? AND $columnUserId = ?',
        whereArgs: [messageId, userId],
        limit: 1,
      );

      if (rows.isEmpty) return null;

      final row = rows.first;
      return MessageReaction(
        id: row[columnId] as String,
        messageId: row[columnMessageId] as String,
        userId: row[columnUserId] as String,
        emoji: row[columnEmoji] as String,
        createdAt: DateTime.parse(row[columnCreatedAt] as String),
        userFirstName: row[columnUserFirstName] as String?,
        userLastName: row[columnUserLastName] as String?,
        userChatPicture: row[columnUserChatPicture] as String?,
        isSynced: (row[columnIsSynced] as int?) == 1,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [MessageReactions] getUserReactionForMessage error: $e');
      }
      return null;
    }
  }

  /// Insert or update a reaction
  static Future<void> upsertReaction(MessageReaction reaction) async {
    if (kDebugMode) {
      debugPrint('💾 [MessageReactions] upsertReaction START');
      debugPrint('  - MessageId: ${reaction.messageId}');
      debugPrint('  - UserId: ${reaction.userId}');
      debugPrint('  - Emoji: ${reaction.emoji}');
      debugPrint('  - IsSynced: ${reaction.isSynced}');
    }

    try {
      final db = await _database;
      final data = reaction.toDatabaseMap();

      if (kDebugMode) {
        debugPrint('  - Database map: $data');
      }

      await db.insert(
        tableName,
        data,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      if (kDebugMode) {
        debugPrint('✅ [MessageReactions] Reaction stored successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [MessageReactions] upsertReaction error: $e');
      }
      rethrow;
    }
  }

  /// Batch insert or update reactions
  static Future<void> upsertReactions(List<MessageReaction> reactions) async {
    if (reactions.isEmpty) return;

    try {
      final db = await _database;
      final batch = db.batch();

      for (final reaction in reactions) {
        batch.insert(
          tableName,
          reaction.toDatabaseMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await batch.commit(noResult: true);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [MessageReactions] upsertReactions error: $e');
      }
      rethrow;
    }
  }

  /// Remove a reaction
  static Future<void> removeReaction({
    required String messageId,
    required String userId,
  }) async {
    try {
      final db = await _database;
      await db.delete(
        tableName,
        where: '$columnMessageId = ? AND $columnUserId = ?',
        whereArgs: [messageId, userId],
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [MessageReactions] removeReaction error: $e');
      }
      rethrow;
    }
  }

  /// Remove all reactions for a message (when message is deleted)
  static Future<void> removeAllReactionsForMessage(String messageId) async {
    try {
      final db = await _database;
      await db.delete(
        tableName,
        where: '$columnMessageId = ?',
        whereArgs: [messageId],
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '❌ [MessageReactions] removeAllReactionsForMessage error: $e',
        );
      }
    }
  }

  /// Get count of reactions for a message
  static Future<int> getReactionCount(String messageId) async {
    try {
      final db = await _database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $tableName WHERE $columnMessageId = ?',
        [messageId],
      );

      if (result.isEmpty) return 0;
      return (result.first['count'] as int?) ?? 0;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [MessageReactions] getReactionCount error: $e');
      }
      return 0;
    }
  }

  /// Clear all reactions (for logout or data reset)
  static Future<void> clearAll() async {
    try {
      final db = await _database;
      await db.delete(tableName);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [MessageReactions] clearAll error: $e');
      }
    }
  }
}
