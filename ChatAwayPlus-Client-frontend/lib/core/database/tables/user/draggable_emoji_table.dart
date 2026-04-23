/// Table definition for draggable emoji storage
class DraggableEmojiTable {
  static const String tableName = 'draggable_emoji';
  
  // Column names
  static const String columnUserId = 'user_id';
  static const String columnEmoji = 'emoji';
  static const String columnUpdatedAt = 'updated_at';
  
  /// Create table SQL statement
  static const String createTableSql = '''
    CREATE TABLE $tableName (
      $columnUserId TEXT PRIMARY KEY,
      $columnEmoji TEXT NOT NULL DEFAULT '😊',
      $columnUpdatedAt INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
    )
  ''';
  
  /// Drop table SQL statement
  static const String dropTableSql = 'DROP TABLE IF EXISTS $tableName';
  
  /// Table columns for queries
  static const List<String> columns = [
    columnUserId,
    columnEmoji,
    columnUpdatedAt,
  ];
}
