import 'package:chataway_plus/core/database/app_database.dart';
import 'package:sqflite/sqflite.dart';

class ChatUsersTable {
  static const String tableName = 'chat_users';

  static const String columnUserId = 'user_id';
  static const String columnFirstName = 'first_name';
  static const String columnLastName = 'last_name';
  static const String columnMobileNo = 'mobile_no';
  static const String columnChatPictureUrl = 'profile_pic_url';
  static const String columnUpdatedAt = 'updated_at';

  static const String createTableSQL =
      '''
CREATE TABLE $tableName (
  $columnUserId TEXT PRIMARY KEY,
  $columnFirstName TEXT NOT NULL,
  $columnLastName TEXT NOT NULL,
  $columnMobileNo TEXT NOT NULL,
  $columnChatPictureUrl TEXT,
  $columnUpdatedAt INTEGER NOT NULL
)
''';

  static const String createIndexSQL =
      '''
CREATE INDEX IF NOT EXISTS idx_chat_users_updated_at
ON $tableName ($columnUpdatedAt DESC)
''';

  ChatUsersTable._();
  static final ChatUsersTable _instance = ChatUsersTable._();
  static ChatUsersTable get instance => _instance;

  Future<Database> get _database async {
    return await AppDatabaseManager.instance.database;
  }

  Future<void> upsertUser({
    required String userId,
    required String firstName,
    required String lastName,
    required String mobileNo,
    String? chatPictureUrl,
    int? updatedAt,
  }) async {
    final db = await _database;

    final now = updatedAt ?? DateTime.now().millisecondsSinceEpoch;
    final normalizedUrl = (chatPictureUrl ?? '').trim();
    final urlToSave = normalizedUrl.isEmpty ? null : normalizedUrl;

    // Check if user exists to preserve profile_pic_url if new value is null
    final existing = await getUserById(userId);
    final finalUrl = urlToSave ?? existing?[columnChatPictureUrl];

    await db.rawInsert(
      'INSERT OR REPLACE INTO $tableName '
      '($columnUserId, $columnFirstName, $columnLastName, $columnMobileNo, $columnChatPictureUrl, $columnUpdatedAt) '
      'VALUES (?, ?, ?, ?, ?, ?)',
      [userId, firstName, lastName, mobileNo, finalUrl, now],
    );
  }

  Future<void> upsertUsers(List<Map<String, dynamic>> users) async {
    if (users.isEmpty) return;
    final db = await _database;
    final now = DateTime.now().millisecondsSinceEpoch;

    final batch = db.batch();

    for (final u in users) {
      final userId = u[columnUserId]?.toString() ?? '';
      if (userId.isEmpty) continue;

      final firstName = (u[columnFirstName] ?? '').toString();
      final lastName = (u[columnLastName] ?? '').toString();
      final mobileNo = (u[columnMobileNo] ?? '').toString();
      final rawUrl = u[columnChatPictureUrl]?.toString();
      final normalizedUrl = (rawUrl ?? '').trim();
      final urlToSave = normalizedUrl.isEmpty ? null : normalizedUrl;
      final updatedAt = u[columnUpdatedAt] ?? now;

      batch.rawInsert(
        'INSERT OR REPLACE INTO $tableName '
        '($columnUserId, $columnFirstName, $columnLastName, $columnMobileNo, $columnChatPictureUrl, $columnUpdatedAt) '
        'VALUES (?, ?, ?, ?, ?, ?)',
        [userId, firstName, lastName, mobileNo, urlToSave, updatedAt],
      );
    }

    await batch.commit(noResult: true);
  }

  Future<Map<String, dynamic>?> getUserById(String userId) async {
    final db = await _database;

    final rows = await db.query(
      tableName,
      where: '$columnUserId = ?',
      whereArgs: [userId],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<void> deleteByUserId(String userId) async {
    final db = await _database;

    await db.delete(tableName, where: '$columnUserId = ?', whereArgs: [userId]);
  }

  Future<void> clearAll() async {
    final db = await _database;
    await db.delete(tableName);
  }
}
