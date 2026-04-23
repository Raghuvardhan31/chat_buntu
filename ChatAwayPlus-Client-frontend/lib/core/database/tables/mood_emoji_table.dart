/// Database table for storing user's personal mood emoji with expiry time
/// Only visible to the user themselves - reflects their current mood/vibe
class MoodEmojiTable {
  static const String tableName = 'mood_emoji';

  // Column names
  static const String columnUserId = 'user_id';
  static const String columnEmoji = 'emoji';
  static const String columnExpiryTimestamp = 'expiry_timestamp';
  static const String columnCreatedAt = 'created_at';

  /// SQL to create the mood_emoji table
  static const String createTableQuery =
      '''
    CREATE TABLE $tableName (
      $columnUserId TEXT PRIMARY KEY,
      $columnEmoji TEXT NOT NULL,
      $columnExpiryTimestamp INTEGER NOT NULL,
      $columnCreatedAt INTEGER NOT NULL
    )
  ''';

  /// SQL to drop the table (for migrations)
  static const String dropTableQuery = 'DROP TABLE IF EXISTS $tableName';
}
