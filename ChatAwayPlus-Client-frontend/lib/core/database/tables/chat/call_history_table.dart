/// Table definition for local call history storage
/// Stores all call records (outgoing, incoming, missed, rejected) offline
class CallHistoryTable {
  static const String tableName = 'call_history';

  // Column names
  static const String columnId = 'id';
  static const String columnCallId = 'call_id';
  static const String columnContactId = 'contact_id';
  static const String columnContactName = 'contact_name';
  static const String columnContactProfilePic = 'contact_profile_pic';
  static const String columnCallType = 'call_type'; // voice, video
  static const String columnDirection = 'direction'; // incoming, outgoing
  static const String columnStatus = 'status'; // ended, missed, rejected, failed
  static const String columnTimestamp = 'timestamp';
  static const String columnDurationSeconds = 'duration_seconds';
  static const String columnCreatedAt = 'created_at';

  /// Create table SQL statement
  static const String createTableSQL = '''
    CREATE TABLE IF NOT EXISTS $tableName (
      $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
      $columnCallId TEXT NOT NULL UNIQUE,
      $columnContactId TEXT NOT NULL,
      $columnContactName TEXT NOT NULL DEFAULT 'Unknown',
      $columnContactProfilePic TEXT,
      $columnCallType TEXT NOT NULL DEFAULT 'voice',
      $columnDirection TEXT NOT NULL DEFAULT 'outgoing',
      $columnStatus TEXT NOT NULL DEFAULT 'ended',
      $columnTimestamp INTEGER NOT NULL,
      $columnDurationSeconds INTEGER,
      $columnCreatedAt INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000)
    )
  ''';

  /// Create index on timestamp for fast sorting
  static const String createIndexSQL = '''
    CREATE INDEX IF NOT EXISTS idx_call_history_timestamp 
    ON $tableName ($columnTimestamp DESC)
  ''';

  /// Create index on contact_id for filtering
  static const String createContactIndexSQL = '''
    CREATE INDEX IF NOT EXISTS idx_call_history_contact 
    ON $tableName ($columnContactId)
  ''';

  /// Drop table SQL statement
  static const String dropTableSQL = 'DROP TABLE IF EXISTS $tableName';

  /// Table columns for queries
  static const List<String> columns = [
    columnId,
    columnCallId,
    columnContactId,
    columnContactName,
    columnContactProfilePic,
    columnCallType,
    columnDirection,
    columnStatus,
    columnTimestamp,
    columnDurationSeconds,
    columnCreatedAt,
  ];
}
