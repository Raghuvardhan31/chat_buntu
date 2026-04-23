import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:chataway_plus/core/database/app_database.dart';

class FollowUpEntry {
  const FollowUpEntry({required this.text, required this.createdAt});

  final String text;
  final DateTime createdAt;
}

class FollowUpsTable {
  static const bool _verboseDbLogs = false;

  static const String tableName = 'follow_ups';

  static const String columnId = 'id';
  static const String columnCurrentUserId = 'current_user_id';
  static const String columnContactId = 'contact_id';
  static const String columnText = 'text';
  static const String columnCreatedAt = 'created_at';

  static const String createTableSQL =
      '''
CREATE TABLE $tableName (
  $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
  $columnCurrentUserId TEXT NOT NULL,
  $columnContactId TEXT NOT NULL,
  $columnText TEXT NOT NULL,
  $columnCreatedAt INTEGER NOT NULL
)
''';

  static const String createIndexSQL =
      '''
CREATE INDEX IF NOT EXISTS idx_follow_ups_contact
ON $tableName ($columnCurrentUserId, $columnContactId, $columnCreatedAt DESC)
''';

  FollowUpsTable._();
  static final FollowUpsTable _instance = FollowUpsTable._();
  static FollowUpsTable get instance => _instance;

  Future<Database> get _database async {
    return await AppDatabaseManager.instance.database;
  }

  Future<void> insertFollowUp({
    required String currentUserId,
    required String contactId,
    required String text,
    DateTime? createdAt,
  }) async {
    final userId = currentUserId.trim();
    final otherUserId = contactId.trim();
    final trimmedText = text.trim();
    if (userId.isEmpty || otherUserId.isEmpty || trimmedText.isEmpty) return;

    final db = await _database;
    final timestamp = (createdAt ?? DateTime.now()).millisecondsSinceEpoch;
    try {
      await db.insert(tableName, {
        columnCurrentUserId: userId,
        columnContactId: otherUserId,
        columnText: trimmedText,
        columnCreatedAt: timestamp,
      });
    } catch (e) {
      if (_verboseDbLogs && kDebugMode) {
        debugPrint('❌ FollowUpsTable insert failed: $e');
      }
      rethrow;
    }
  }

  Future<List<String>> getFollowUps({
    required String currentUserId,
    required String contactId,
    int limit = 20,
  }) async {
    final userId = currentUserId.trim();
    final otherUserId = contactId.trim();
    if (userId.isEmpty || otherUserId.isEmpty) return [];

    final db = await _database;
    try {
      final rows = await db.query(
        tableName,
        columns: [columnText],
        where: '$columnCurrentUserId = ? AND $columnContactId = ?',
        whereArgs: [userId, otherUserId],
        orderBy: '$columnCreatedAt DESC',
        limit: limit,
      );
      return rows
          .map((row) => (row[columnText] as String?)?.trim() ?? '')
          .where((text) => text.isNotEmpty)
          .toList();
    } catch (e) {
      if (_verboseDbLogs && kDebugMode) {
        debugPrint('❌ FollowUpsTable query failed: $e');
      }
      return [];
    }
  }

  Future<List<FollowUpEntry>> getFollowUpEntries({
    required String currentUserId,
    required String contactId,
    int limit = 50,
  }) async {
    final userId = currentUserId.trim();
    final otherUserId = contactId.trim();
    if (userId.isEmpty || otherUserId.isEmpty) return [];

    final db = await _database;
    try {
      final rows = await db.query(
        tableName,
        columns: [columnText, columnCreatedAt],
        where: '$columnCurrentUserId = ? AND $columnContactId = ?',
        whereArgs: [userId, otherUserId],
        orderBy: '$columnCreatedAt DESC',
        limit: limit,
      );
      return rows
          .map((row) {
            final text = (row[columnText] as String?)?.trim() ?? '';
            final createdMs = row[columnCreatedAt] as int?;
            if (text.isEmpty || createdMs == null) return null;
            return FollowUpEntry(
              text: text,
              createdAt: DateTime.fromMillisecondsSinceEpoch(createdMs),
            );
          })
          .whereType<FollowUpEntry>()
          .toList();
    } catch (e) {
      if (_verboseDbLogs && kDebugMode) {
        debugPrint('❌ FollowUpsTable entries query failed: $e');
      }
      return [];
    }
  }

  Future<bool> deleteFollowUp({
    required String currentUserId,
    required String contactId,
    required String text,
    required DateTime createdAt,
  }) async {
    final userId = currentUserId.trim();
    final otherUserId = contactId.trim();
    final followUpText = text.trim();

    if (userId.isEmpty || otherUserId.isEmpty || followUpText.isEmpty) {
      return false;
    }

    final db = await _database;
    try {
      final createdMs = createdAt.millisecondsSinceEpoch;
      final deletedRows = await db.delete(
        tableName,
        where:
            '$columnCurrentUserId = ? AND $columnContactId = ? AND $columnText = ? AND $columnCreatedAt = ?',
        whereArgs: [userId, otherUserId, followUpText, createdMs],
      );

      if (_verboseDbLogs && kDebugMode) {
        debugPrint('✅ FollowUpsTable deleted $deletedRows follow-up entry');
      }

      return deletedRows > 0;
    } catch (e) {
      if (_verboseDbLogs && kDebugMode) {
        debugPrint('❌ FollowUpsTable delete failed: $e');
      }
      return false;
    }
  }
}
