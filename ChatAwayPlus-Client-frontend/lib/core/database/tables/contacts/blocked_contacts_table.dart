import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:chataway_plus/core/database/app_database.dart';

class BlockedContactsTable {
  static const String tableName = 'blocked_contacts';

  static const String columnUserId = 'user_id'; // current logged-in user (UUID)
  static const String columnBlockedUserId =
      'blocked_user_id'; // blocked user's app UUID
  static const String columnIsBlocked =
      'is_blocked'; // 1 = blocked, 0 = unblocked
  static const String columnBlockedAt =
      'blocked_at'; // epoch ms when last set to blocked
  static const String columnFirstName = 'first_name';
  static const String columnLastName = 'last_name';
  static const String columnChatPicture = 'chat_picture';

  static const String createTableSQL =
      'CREATE TABLE IF NOT EXISTS $tableName ('
      '$columnUserId TEXT NOT NULL,'
      '$columnBlockedUserId TEXT NOT NULL,'
      '$columnIsBlocked INTEGER NOT NULL DEFAULT 1,'
      '$columnBlockedAt INTEGER NOT NULL,'
      '$columnFirstName TEXT,'
      '$columnLastName TEXT,'
      '$columnChatPicture TEXT,'
      'PRIMARY KEY ($columnUserId, $columnBlockedUserId)'
      ')';

  static Database? _dbCache;
  static Future<Database> get _database async {
    _dbCache ??= await AppDatabaseManager.instance.database;
    return _dbCache!;
  }

  static Future<void> upsert({
    required String userId,
    required String blockedUserId,
    required bool isBlocked,
    int? blockedAt,
    String? firstName,
    String? lastName,
    String? chatPicture,
  }) async {
    try {
      final db = await _database;

      final values = <String, Object?>{
        columnUserId: userId,
        columnBlockedUserId: blockedUserId,
        columnIsBlocked: isBlocked ? 1 : 0,
        columnBlockedAt: blockedAt ?? DateTime.now().millisecondsSinceEpoch,
        if (firstName != null) columnFirstName: firstName,
        if (lastName != null) columnLastName: lastName,
        if (chatPicture != null) columnChatPicture: chatPicture,
      };

      await db.transaction((txn) async {
        final updated = await txn.update(
          tableName,
          values,
          where: '$columnUserId = ? AND $columnBlockedUserId = ?',
          whereArgs: [userId, blockedUserId],
        );
        if (updated == 0) {
          await txn.insert(
            tableName,
            values,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });
      if (kDebugMode) {
        debugPrint(
          '✅ BlockedContacts upsert: user=$userId target=$blockedUserId -> ${isBlocked ? 'BLOCKED' : 'UNBLOCKED'}',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ BlockedContacts upsert error: $e');
      }
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> getBlockedUsers(
    String userId,
  ) async {
    try {
      final db = await _database;
      final rows = await db.query(
        tableName,
        where: '$columnUserId = ? AND $columnIsBlocked = 1',
        whereArgs: [userId],
        orderBy: '$columnBlockedAt DESC',
      );
      return rows;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ BlockedContacts getBlockedUsers error: $e');
      }
      return <Map<String, dynamic>>[];
    }
  }

  static Future<List<Map<String, dynamic>>> getAllRows(String userId) async {
    try {
      final db = await _database;
      final rows = await db.query(
        tableName,
        where: '$columnUserId = ?',
        whereArgs: [userId],
        orderBy: '$columnBlockedAt DESC',
      );
      return rows;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ BlockedContacts getAllRows error: $e');
      }
      return <Map<String, dynamic>>[];
    }
  }

  static Future<Set<String>> getBlockedUserIds(String userId) async {
    try {
      final db = await _database;
      final rows = await db.query(
        tableName,
        columns: [columnBlockedUserId],
        where: '$columnUserId = ? AND $columnIsBlocked = 1',
        whereArgs: [userId],
      );
      return rows.map((r) => r[columnBlockedUserId] as String).toSet();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ BlockedContacts getBlockedUserIds error: $e');
      }
      return <String>{};
    }
  }

  static Future<void> markUnblockedForMissing(
    String userId,
    Set<String> serverBlocked,
  ) async {
    try {
      final db = await _database;
      // Find existing blocked to compare
      final existing = await getBlockedUserIds(userId);
      final toUnblock = existing.difference(serverBlocked);
      final batch = db.batch();
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final id in toUnblock) {
        batch.update(
          tableName,
          {columnIsBlocked: 0, columnBlockedAt: now},
          where: '$columnUserId = ? AND $columnBlockedUserId = ?',
          whereArgs: [userId, id],
        );
      }
      await batch.commit(noResult: true);
      if (kDebugMode && toUnblock.isNotEmpty) {
        debugPrint(
          '↩️ BlockedContacts: marked ${toUnblock.length} as UNBLOCKED',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ BlockedContacts markUnblockedForMissing error: $e');
      }
    }
  }
}
