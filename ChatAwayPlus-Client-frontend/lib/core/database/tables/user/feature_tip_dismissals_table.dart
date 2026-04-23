import 'package:chataway_plus/core/database/app_database.dart';
import 'package:sqflite/sqflite.dart';

class FeatureTipDismissalsTable {
  static const String tableName = 'feature_tip_dismissals';

  static const String columnUserId = 'user_id';
  static const String columnTipKey = 'tip_key';
  static const String columnDismissedAt = 'dismissed_at';

  static const String createTableSQL =
      'CREATE TABLE IF NOT EXISTS $tableName ('
      '$columnUserId TEXT NOT NULL,'
      '$columnTipKey TEXT NOT NULL,'
      '$columnDismissedAt INTEGER NOT NULL,'
      'PRIMARY KEY ($columnUserId, $columnTipKey)'
      ')';

  static const String createUserIndexSQL =
      'CREATE INDEX IF NOT EXISTS idx_feature_tip_dismissals_user '
      'ON $tableName ($columnUserId)';

  FeatureTipDismissalsTable._();
  static final FeatureTipDismissalsTable _instance =
      FeatureTipDismissalsTable._();
  static FeatureTipDismissalsTable get instance => _instance;

  Future<Database> get _database async {
    return await AppDatabaseManager.instance.database;
  }

  Future<bool> isDismissed({
    required String userId,
    required String tipKey,
  }) async {
    try {
      final db = await _database;
      final rows = await db.query(
        tableName,
        columns: [columnTipKey],
        where: '$columnUserId = ? AND $columnTipKey = ?',
        whereArgs: [userId, tipKey],
        limit: 1,
      );
      return rows.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> dismiss({required String userId, required String tipKey}) async {
    try {
      final db = await _database;
      await db.insert(tableName, {
        columnUserId: userId,
        columnTipKey: tipKey,
        columnDismissedAt: DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (_) {}
  }

  Future<void> dismissAll({
    required String userId,
    required List<String> tipKeys,
  }) async {
    if (tipKeys.isEmpty) return;
    try {
      final db = await _database;
      final batch = db.batch();
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final tipKey in tipKeys) {
        batch.insert(tableName, {
          columnUserId: userId,
          columnTipKey: tipKey,
          columnDismissedAt: now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    } catch (_) {}
  }
}
