// ============================================================================
// APP DATABASE - Main Database Manager
// ============================================================================
// This is the SINGLE entry point for all database operations.
//
// HOW IT WORKS:
// 1. This file imports all table files from tables/ folder
// 2. Uses table schemas to create database tables
// 3. Handles database version migrations
// 4. Provides methods to interact with tables
//
// TEAM EXAMPLE:
//   final db = AppDatabaseManager.instance;
//   await db.insertOrUpdateContact(contactData);
//   await db.getAllContacts();
//
// STRUCTURE:
//   app_database.dart  ← YOU ARE HERE (Reference file)
//        ↓
//   ../local_storage/app_database_manager.dart  ← Main implementation
//        ↓ imports
//   tables/
//      ├── contacts_table.dart     ← ✅ COMPLETED
//      ├── messages_table.dart     ← TODO
//      └── conversations_table.dart ← TODO
//   migrations/
//      └── (future migration files for version upgrades)
//
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
// Chat tables
import 'tables/chat/messages_table.dart';
import 'tables/chat/chat_users_table.dart';
import 'tables/chat/chat_sync_metadata_table.dart';
import 'tables/chat/follow_ups_table.dart';

// User tables
import 'tables/user/current_user_table.dart';
import 'tables/user/mobile_number_table.dart';
import 'tables/user/emoji_table.dart';
import 'tables/user/draggable_emoji_table.dart';
import 'tables/user/feature_tip_dismissals_table.dart';
import 'tables/mood_emoji_table.dart';

// Contacts tables
import 'tables/contacts/contacts_table.dart';
import 'tables/contacts/blocked_contacts_table.dart';
import 'tables/contacts/app_users_emoji_table.dart';

// Cache tables
import 'tables/cache/app_startup_snapshot_table.dart';
import 'tables/cache/profile_picture_cache_table.dart';

// Chat tables (moved from cache - persistent data)
import 'tables/chat/chat_picture_likes_table.dart';
import 'tables/chat/message_reactions_table.dart';
import 'tables/chat/status_likes_table.dart';
import 'tables/chat/my_stories_table.dart';
import 'tables/chat/contacts_stories_table.dart';
import 'tables/chat/story_viewers_table.dart';
import 'tables/chat/received_likes_table.dart';
import 'tables/chat/call_history_table.dart';

// Chat exports
export 'tables/chat/messages_table.dart';
export 'tables/chat/chat_users_table.dart';
export 'tables/chat/chat_sync_metadata_table.dart';
export 'tables/chat/follow_ups_table.dart';

// User exports
export 'tables/user/current_user_table.dart';
export 'tables/user/mobile_number_table.dart';
export 'tables/user/emoji_table.dart';
export 'tables/user/draggable_emoji_table.dart';
export 'tables/user/feature_tip_dismissals_table.dart';
export 'tables/mood_emoji_table.dart';

// Contacts exports
export 'tables/contacts/contacts_table.dart';
export 'tables/contacts/blocked_contacts_table.dart';
export 'tables/contacts/app_users_emoji_table.dart';

// Cache exports
export 'tables/cache/app_startup_snapshot_table.dart';
export 'tables/cache/profile_picture_cache_table.dart';

// Chat table exports (persistent data)
export 'tables/chat/chat_picture_likes_table.dart';
export 'tables/chat/message_reactions_table.dart';
export 'tables/chat/status_likes_table.dart';
export 'tables/chat/my_stories_table.dart';
export 'tables/chat/contacts_stories_table.dart';
export 'tables/chat/story_viewers_table.dart';
export 'tables/chat/received_likes_table.dart';
export 'tables/chat/call_history_table.dart';

// ============================================================================
// APP DATABASE MANAGER - Creates DB and executes all table schemas
// ============================================================================

class AppDatabaseManager {
  // Singleton
  AppDatabaseManager._();
  static final AppDatabaseManager _instance = AppDatabaseManager._();
  static AppDatabaseManager get instance => _instance;

  // Database config
  static const String _dbName = 'chataway_contacts.db';
  static const int _dbVersion = 41;

  Database? _database;

  /// Returns the singleton Database instance.
  /// Lazily initializes the SQLite database on first access.
  /// Use this for all DAO/table operations across the app.
  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  /// Opens the database file and wires up onCreate/onUpgrade callbacks.
  /// - onCreate: creates all v4 tables and indexes
  /// - onUpgrade: applies incremental migrations for legacy users
  /// If database is corrupted, deletes and recreates it.
  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    try {
      return await openDatabase(
        path,
        version: _dbVersion,
        onCreate: (db, version) async {
          // onCreate: invoked only when database is first created (fresh install).
          // Creates all v4 tables and indexes.
          debugPrint('📦 Creating database tables...');

          // Create contacts table (from tables/contacts_table.dart)
          await db.execute(ContactsTable.createTableSQL);
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_app_user_id ON ${ContactsTable.tableName} (app_user_id)',
          );
          debugPrint('✅ Contacts table created');

          // Create mobile number table (from tables/mobile_number_table.dart)
          await db.execute(MobileNumberTable.createTableSQL);
          debugPrint('✅ Mobile number table created');

          // Create current user profile table (from tables/current_user_table.dart)
          await db.execute(CurrentUserProfileTable.createTableSQL);
          debugPrint('✅ Current user profile table created');

          // Create Current user emoji updates table (from tables/emoji_table.dart)
          await db.execute(EmojiTable.createTableSQL);
          debugPrint('✅ Current user emoji updates table created');

          // Create app users emoji updates table (from tables/app_users_emoji_table.dart)
          await db.execute(AppUsersEmojiTable.createTableSQL);
          debugPrint('✅ App users emoji updates table created');

          // Create messages table (from tables/messages_table.dart)
          await db.execute(MessagesTable.createTableSQL);
          await db.execute(MessagesTable.createIndexSQL);
          await db.execute(MessagesTable.createStatusIndexSQL);
          await db.execute(MessagesTable.createTimeIndexSQL);
          debugPrint('✅ Messages table created with indexes');

          await db.execute(ChatUsersTable.createTableSQL);
          await db.execute(ChatUsersTable.createIndexSQL);
          debugPrint('✅ Chat users table created');

          // Create app startup snapshot table (from tables/app_startup_snapshot_table.dart)
          await db.execute(AppStartupSnapshotTable.createTableSQL);
          debugPrint('✅ App startup snapshot table created');

          // Create blocked contacts table
          await db.execute(BlockedContactsTable.createTableSQL);
          debugPrint('✅ Blocked contacts table created');

          // Create profile picture cache table
          await db.execute(ProfilePictureCacheTable.createTableSQL);
          await db.execute(ProfilePictureCacheTable.createIndexSQL);
          debugPrint('✅ Profile picture cache table created');

          await db.execute(ChatPictureLikesTable.createTableSQL);
          await db.execute(ChatPictureLikesTable.createIndexSQL);
          debugPrint('✅ Chat picture likes table created');

          await db.execute(StatusLikesTable.createTableSQL);
          await db.execute(StatusLikesTable.createIndexSQL);
          debugPrint('✅ Status likes table created');

          // Create message reactions table
          await db.execute(MessageReactionsTable.createTableSQL);
          await db.execute(MessageReactionsTable.createMessageIndexSQL);
          await db.execute(MessageReactionsTable.createUserIndexSQL);
          debugPrint('✅ Message reactions table created');

          // Create chat sync metadata table
          await db.execute(ChatSyncMetadataTable.createTableSQL);
          await db.execute(ChatSyncMetadataTable.createIndexSQL);
          debugPrint('✅ Chat sync metadata table created');

          // Create follow-ups table
          await db.execute(FollowUpsTable.createTableSQL);
          await db.execute(FollowUpsTable.createIndexSQL);
          debugPrint('✅ Follow-ups table created');

          // Create draggable emoji table
          await db.execute(DraggableEmojiTable.createTableSql);
          debugPrint('✅ Draggable emoji table created');

          // Create mood emoji table
          await db.execute(MoodEmojiTable.createTableQuery);
          debugPrint('✅ Mood emoji table created');

          await db.execute(FeatureTipDismissalsTable.createTableSQL);
          await db.execute(FeatureTipDismissalsTable.createUserIndexSQL);
          debugPrint('✅ Feature tip dismissals table created');

          // Create stories tables
          await db.execute(MyStoriesTable.createTableSQL);
          await db.execute(MyStoriesTable.createIndexSQL);
          debugPrint('✅ My stories table created');

          await db.execute(ContactsStoriesTable.createTableSQL);
          await db.execute(ContactsStoriesTable.createIndexSQL);
          debugPrint('✅ Contacts stories table created');

          await db.execute(StoryViewersTable.createTableSQL);
          await db.execute(StoryViewersTable.createIndexSQL);
          debugPrint('✅ Story viewers table created');

          await db.execute(ReceivedLikesTable.createTableSQL);
          await db.execute(ReceivedLikesTable.createIndexSQL);
          debugPrint('✅ Received likes table created');

          await db.execute(CallHistoryTable.createTableSQL);
          await db.execute(CallHistoryTable.createIndexSQL);
          await db.execute(CallHistoryTable.createContactIndexSQL);
          debugPrint('✅ Call history table created');
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          // onUpgrade: invoked when an existing DB is opened with a higher version.
          // Apply only the necessary migrations to reach the target version.
          debugPrint('📦 Upgrading database from v$oldVersion to v$newVersion');

          // Migration from version 1 to 2: Add messages table
          if (oldVersion < 2) {
            debugPrint('📦 Adding messages table...');
            await db.execute(MessagesTable.createTableSQL);
            await db.execute(MessagesTable.createIndexSQL);
            await db.execute(MessagesTable.createStatusIndexSQL);
            await db.execute(MessagesTable.createTimeIndexSQL);
            debugPrint('✅ Messages table added with indexes');
          }

          // Migration to v5: add app_startup_snapshot table
          if (oldVersion < 5) {
            debugPrint('📦 Adding app_startup_snapshot table...');
            await db.execute(AppStartupSnapshotTable.createTableSQL);
            debugPrint('✅ app_startup_snapshot table added');
          }

          // Migration to v6: add blocked_contacts table
          if (oldVersion < 6) {
            debugPrint('📦 Adding blocked_contacts table...');
            await db.execute(BlockedContactsTable.createTableSQL);
            debugPrint('✅ blocked_contacts table added');
          }

          // Migration to v7: add profile_picture_cache table
          if (oldVersion < 7) {
            debugPrint('📦 Adding profile_picture_cache table...');
            await db.execute(ProfilePictureCacheTable.createTableSQL);
            await db.execute(ProfilePictureCacheTable.createIndexSQL);
            debugPrint('✅ profile_picture_cache table added');
          }

          // Migration to v8: add chat_sync_metadata table
          if (oldVersion < 8) {
            debugPrint('📦 Adding chat_sync_metadata table...');
            await db.execute(ChatSyncMetadataTable.createTableSQL);
            await db.execute(ChatSyncMetadataTable.createIndexSQL);
            debugPrint('✅ chat_sync_metadata table added');
          }

          // Migration to v9: add draggable_emoji table
          if (oldVersion < 9) {
            debugPrint('📦 Adding draggable_emoji table...');
            await db.execute(DraggableEmojiTable.createTableSql);
            debugPrint('✅ draggable_emoji table added');
          }

          // Migration to v10: add delivery_channel column to messages table
          if (oldVersion < 10) {
            debugPrint(
              '📦 Adding delivery_channel column to messages table...',
            );
            try {
              await db.execute(
                'ALTER TABLE ${MessagesTable.tableName} ADD COLUMN ${MessagesTable.columnDeliveryChannel} TEXT DEFAULT \'socket\'',
              );
            } catch (_) {}
            debugPrint('✅ delivery_channel column added to messages table');
          }

          // Migration to v11: add receiver_delivery_channel column to messages table
          if (oldVersion < 11) {
            debugPrint(
              '📦 Adding receiver_delivery_channel column to messages table...',
            );
            try {
              await db.execute(
                'ALTER TABLE ${MessagesTable.tableName} ADD COLUMN ${MessagesTable.columnReceiverDeliveryChannel} TEXT',
              );
            } catch (_) {}
            debugPrint(
              '✅ receiver_delivery_channel column added to messages table',
            );
          }

          if (oldVersion < 12) {
            try {
              await db.execute(
                'ALTER TABLE ${MessagesTable.tableName} ADD COLUMN ${MessagesTable.columnMessageType} TEXT DEFAULT \'text\'',
              );
            } catch (_) {}
            try {
              await db.execute(
                'ALTER TABLE ${MessagesTable.tableName} ADD COLUMN ${MessagesTable.columnFileUrl} TEXT',
              );
            } catch (_) {}
            try {
              await db.execute(
                'ALTER TABLE ${MessagesTable.tableName} ADD COLUMN ${MessagesTable.columnMimeType} TEXT',
              );
            } catch (_) {}
            try {
              await db.execute(
                'ALTER TABLE ${MessagesTable.tableName} ADD COLUMN ${MessagesTable.columnFileName} TEXT',
              );
            } catch (_) {}
            try {
              await db.execute(
                'ALTER TABLE ${MessagesTable.tableName} ADD COLUMN ${MessagesTable.columnPageCount} INTEGER',
              );
            } catch (_) {}
            try {
              await db.execute(
                'ALTER TABLE ${MessagesTable.tableName} ADD COLUMN ${MessagesTable.columnFileSize} INTEGER',
              );
            } catch (_) {}
          }

          if (oldVersion < 13) {
            try {
              await db.execute(
                'ALTER TABLE ${MessagesTable.tableName} ADD COLUMN ${MessagesTable.columnIsEdited} INTEGER DEFAULT 0',
              );
            } catch (_) {}
            try {
              await db.execute(
                'ALTER TABLE ${MessagesTable.tableName} ADD COLUMN ${MessagesTable.columnEditedAt} INTEGER',
              );
            } catch (_) {}
          }

          if (oldVersion < 14) {
            try {
              await db.execute(ChatPictureLikesTable.createTableSQL);
            } catch (_) {}
            try {
              await db.execute(ChatPictureLikesTable.createIndexSQL);
            } catch (_) {}
          }

          if (oldVersion < 15) {
            try {
              await db.execute(
                'ALTER TABLE ${MessagesTable.tableName} ADD COLUMN ${MessagesTable.columnReactionsJson} TEXT',
              );
            } catch (_) {}
          }
          // Migration to v23: add cached_file_path column to messages table
          if (oldVersion < 23) {
            debugPrint(
              '📦 Adding cached_file_path column to messages table...',
            );
            try {
              await db.execute(
                'ALTER TABLE ${MessagesTable.tableName} ADD COLUMN ${MessagesTable.columnCachedFilePath} TEXT',
              );
            } catch (_) {}
            debugPrint('✅ cached_file_path column added to messages table');
          }

          if (oldVersion < 24) {
            try {
              await db.execute(
                'ALTER TABLE ${MessagesTable.tableName} ADD COLUMN ${MessagesTable.columnIsStarred} INTEGER DEFAULT 0',
              );
            } catch (_) {}
          }

          // Migration to v25: add mood_emoji table
          if (oldVersion < 25) {
            debugPrint('📦 Adding mood_emoji table...');
            try {
              await db.execute(MoodEmojiTable.createTableQuery);
              debugPrint('✅ mood_emoji table added');
            } catch (_) {}
          }

          if (oldVersion < 26) {
            debugPrint('📦 Adding feature_tip_dismissals table...');
            try {
              await db.execute(FeatureTipDismissalsTable.createTableSQL);
            } catch (_) {}
            try {
              await db.execute(FeatureTipDismissalsTable.createUserIndexSQL);
            } catch (_) {}
            debugPrint('✅ feature_tip_dismissals table added');
          }

          if (oldVersion < 41) {
            try {
              await db.execute(
                'ALTER TABLE ${MessagesTable.tableName} ADD COLUMN ${MessagesTable.columnReplyToMessageId} TEXT',
              );
            } catch (_) {}
            try {
              await db.execute(
                'ALTER TABLE ${MessagesTable.tableName} ADD COLUMN ${MessagesTable.columnReplyToMessageText} TEXT',
              );
            } catch (_) {}
            try {
              await db.execute(
                'ALTER TABLE ${MessagesTable.tableName} ADD COLUMN ${MessagesTable.columnReplyToMessageSenderId} TEXT',
              );
            } catch (_) {}
            try {
              await db.execute(
                'ALTER TABLE ${MessagesTable.tableName} ADD COLUMN ${MessagesTable.columnReplyToMessageType} TEXT',
              );
            } catch (_) {}

            try {
              await db.execute('''
UPDATE ${MessagesTable.tableName} AS m
SET
  ${MessagesTable.columnReplyToMessageText} = (
    SELECT ${MessagesTable.columnMessage}
    FROM ${MessagesTable.tableName}
    WHERE ${MessagesTable.columnId} = m.${MessagesTable.columnReplyToMessageId}
  ),
  ${MessagesTable.columnReplyToMessageSenderId} = (
    SELECT ${MessagesTable.columnSenderId}
    FROM ${MessagesTable.tableName}
    WHERE ${MessagesTable.columnId} = m.${MessagesTable.columnReplyToMessageId}
  ),
  ${MessagesTable.columnReplyToMessageType} = (
    SELECT ${MessagesTable.columnMessageType}
    FROM ${MessagesTable.tableName}
    WHERE ${MessagesTable.columnId} = m.${MessagesTable.columnReplyToMessageId}
  )
WHERE m.${MessagesTable.columnReplyToMessageId} IS NOT NULL
  AND (m.${MessagesTable.columnReplyToMessageText} IS NULL OR m.${MessagesTable.columnReplyToMessageText} = '')
''');
            } catch (_) {}
          }
          if (oldVersion < 16) {
            try {
              await db.execute(ChatUsersTable.createTableSQL);
              await db.execute(ChatUsersTable.createIndexSQL);
            } catch (_) {}
          }

          if (oldVersion < 17) {
            try {
              await db.transaction((txn) async {
                Future<bool> hasTable(String tableName) async {
                  final rows = await txn.rawQuery(
                    "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
                    [tableName],
                  );
                  return rows.isNotEmpty;
                }

                Future<bool> hasColumn(
                  String tableName,
                  String columnName,
                ) async {
                  final info = await txn.rawQuery(
                    'PRAGMA table_info($tableName)',
                  );
                  for (final row in info) {
                    if ((row['name'] as String?) == columnName) return true;
                  }
                  return false;
                }

                Future<void> rebuildEmojiTable() async {
                  final exists = await hasTable(EmojiTable.tableName);
                  if (!exists) {
                    await txn.execute(EmojiTable.createTableSQL);
                    return;
                  }

                  final hasNew = await hasColumn(
                    EmojiTable.tableName,
                    EmojiTable.columnEmoji,
                  );
                  if (hasNew) return;

                  final hasOldEmoji = await hasColumn(
                    EmojiTable.tableName,
                    'emoji',
                  );
                  final hasOldCaption = await hasColumn(
                    EmojiTable.tableName,
                    'caption',
                  );

                  final tmp = '${EmojiTable.tableName}__v17';
                  await txn.execute(
                    EmojiTable.createTableSQL.replaceFirst(
                      EmojiTable.tableName,
                      tmp,
                    ),
                  );

                  if (hasOldEmoji && hasOldCaption) {
                    await txn.execute(
                      'INSERT INTO $tmp (id, user_id, emojis_update, emojis_caption, deleted_at, created_at, updated_at, user_first_name, user_last_name, user_profile_pic) '
                      'SELECT id, user_id, emoji, caption, deleted_at, created_at, updated_at, user_first_name, user_last_name, user_profile_pic '
                      'FROM ${EmojiTable.tableName}',
                    );
                  }
                  await txn.execute('DROP TABLE ${EmojiTable.tableName}');
                  await txn.execute(
                    'ALTER TABLE $tmp RENAME TO ${EmojiTable.tableName}',
                  );
                }

                Future<void> rebuildAppUsersEmojiTable() async {
                  final exists = await hasTable(AppUsersEmojiTable.tableName);
                  if (!exists) {
                    await txn.execute(AppUsersEmojiTable.createTableSQL);
                    return;
                  }

                  final hasNew = await hasColumn(
                    AppUsersEmojiTable.tableName,
                    AppUsersEmojiTable.columnEmoji,
                  );
                  if (hasNew) return;

                  final hasOldEmoji = await hasColumn(
                    AppUsersEmojiTable.tableName,
                    'emoji',
                  );
                  final hasOldCaption = await hasColumn(
                    AppUsersEmojiTable.tableName,
                    'caption',
                  );

                  final tmp = '${AppUsersEmojiTable.tableName}__v17';
                  await txn.execute(
                    AppUsersEmojiTable.createTableSQL.replaceFirst(
                      AppUsersEmojiTable.tableName,
                      tmp,
                    ),
                  );

                  if (hasOldEmoji && hasOldCaption) {
                    await txn.execute(
                      'INSERT INTO $tmp (id, user_id, emojis_update, emojis_caption, deleted_at, created_at, updated_at, user_first_name, user_last_name, user_profile_pic) '
                      'SELECT id, user_id, emoji, caption, deleted_at, created_at, updated_at, user_first_name, user_last_name, user_profile_pic '
                      'FROM ${AppUsersEmojiTable.tableName}',
                    );
                  }
                  await txn.execute(
                    'DROP TABLE ${AppUsersEmojiTable.tableName}',
                  );
                  await txn.execute(
                    'ALTER TABLE $tmp RENAME TO ${AppUsersEmojiTable.tableName}',
                  );
                }

                Future<void> rebuildCurrentUserProfileTable() async {
                  final exists = await hasTable(
                    CurrentUserProfileTable.tableName,
                  );
                  if (!exists) {
                    await txn.execute(CurrentUserProfileTable.createTableSQL);
                    return;
                  }

                  final hasNew = await hasColumn(
                    CurrentUserProfileTable.tableName,
                    CurrentUserProfileTable.columnCurrentEmoji,
                  );
                  if (hasNew) return;

                  const oldCurrentEmoji = 'current_emoji';
                  const oldEmojiCaption = 'emoji_caption';
                  const oldEmojiUpdatedAt = 'emoji_updated_at';

                  final hasOldCurrentEmoji = await hasColumn(
                    CurrentUserProfileTable.tableName,
                    oldCurrentEmoji,
                  );
                  final hasOldEmojiCaption = await hasColumn(
                    CurrentUserProfileTable.tableName,
                    oldEmojiCaption,
                  );
                  final hasOldEmojiUpdatedAt = await hasColumn(
                    CurrentUserProfileTable.tableName,
                    oldEmojiUpdatedAt,
                  );

                  final tmp = '${CurrentUserProfileTable.tableName}__v17';
                  await txn.execute(
                    CurrentUserProfileTable.createTableSQL.replaceFirst(
                      CurrentUserProfileTable.tableName,
                      tmp,
                    ),
                  );

                  if (hasOldCurrentEmoji &&
                      hasOldEmojiCaption &&
                      hasOldEmojiUpdatedAt) {
                    await txn.execute(
                      'INSERT INTO $tmp (user_id, first_name, last_name, mobile_no, profile_pic, status_content, status_created_at, emojis_update, emojis_caption, emojis_updated_at, created_at, last_updated) '
                      'SELECT user_id, first_name, last_name, mobile_no, profile_pic, status_content, status_created_at, $oldCurrentEmoji, $oldEmojiCaption, $oldEmojiUpdatedAt, created_at, last_updated '
                      'FROM ${CurrentUserProfileTable.tableName}',
                    );
                  } else {
                    await txn.execute(
                      'INSERT INTO $tmp (user_id, first_name, last_name, mobile_no, profile_pic, status_content, status_created_at, emojis_update, emojis_caption, emojis_updated_at, created_at, last_updated) '
                      'SELECT user_id, first_name, last_name, mobile_no, profile_pic, status_content, status_created_at, NULL, NULL, NULL, created_at, last_updated '
                      'FROM ${CurrentUserProfileTable.tableName}',
                    );
                  }

                  await txn.execute(
                    'DROP TABLE ${CurrentUserProfileTable.tableName}',
                  );
                  await txn.execute(
                    'ALTER TABLE $tmp RENAME TO ${CurrentUserProfileTable.tableName}',
                  );
                }

                await rebuildEmojiTable();
                await rebuildAppUsersEmojiTable();
                await rebuildCurrentUserProfileTable();
              });
            } catch (_) {}
          }

          if (oldVersion < 18) {
            try {
              final info = await db.rawQuery(
                'PRAGMA table_info(${CurrentUserProfileTable.tableName})',
              );
              final hasColumn = info.any(
                (row) =>
                    (row['name'] as String?) ==
                    CurrentUserProfileTable.columnChatPictureVersion,
              );
              if (!hasColumn) {
                await db.execute(
                  'ALTER TABLE ${CurrentUserProfileTable.tableName} ADD COLUMN ${CurrentUserProfileTable.columnChatPictureVersion} TEXT',
                );
              }
            } catch (_) {}
          }

          if (oldVersion < 19) {
            try {
              final info = await db.rawQuery(
                'PRAGMA table_info(${BlockedContactsTable.tableName})',
              );
              bool hasColumn(String name) =>
                  info.any((row) => (row['name'] as String?) == name);

              if (!hasColumn(BlockedContactsTable.columnFirstName)) {
                await db.execute(
                  'ALTER TABLE ${BlockedContactsTable.tableName} ADD COLUMN ${BlockedContactsTable.columnFirstName} TEXT',
                );
              }
              if (!hasColumn(BlockedContactsTable.columnLastName)) {
                await db.execute(
                  'ALTER TABLE ${BlockedContactsTable.tableName} ADD COLUMN ${BlockedContactsTable.columnLastName} TEXT',
                );
              }
              if (!hasColumn(BlockedContactsTable.columnChatPicture)) {
                await db.execute(
                  'ALTER TABLE ${BlockedContactsTable.tableName} ADD COLUMN ${BlockedContactsTable.columnChatPicture} TEXT',
                );
              }
            } catch (_) {}
          }

          if (oldVersion < 20) {
            try {
              await db.execute(ChatPictureLikesTable.createTableSQL);
            } catch (_) {}
            try {
              await db.execute(ChatPictureLikesTable.createIndexSQL);
            } catch (_) {}

            try {
              await db.execute(
                'INSERT OR REPLACE INTO ${ChatPictureLikesTable.tableName} '
                '(${ChatPictureLikesTable.columnCurrentUserId}, ${ChatPictureLikesTable.columnLikedUserId}, ${ChatPictureLikesTable.columnTargetChatPictureId}, ${ChatPictureLikesTable.columnIsLiked}, ${ChatPictureLikesTable.columnLikeId}, ${ChatPictureLikesTable.columnLikeCount}, ${ChatPictureLikesTable.columnUpdatedAt}) '
                'SELECT current_user_id, profile_owner_user_id, target_profile_pic_id, is_liked, like_id, like_count, updated_at '
                'FROM profile_picture_likes',
              );
            } catch (_) {}
          }

          if (oldVersion < 21) {
            try {
              await db.execute('DROP TABLE IF EXISTS profile_picture_likes');
            } catch (_) {}
          }

          // Migration to v22: add message_reactions table
          if (oldVersion < 22) {
            debugPrint('📦 Adding message_reactions table...');
            try {
              await db.execute(MessageReactionsTable.createTableSQL);
              await db.execute(MessageReactionsTable.createMessageIndexSQL);
              await db.execute(MessageReactionsTable.createUserIndexSQL);
              debugPrint('✅ message_reactions table added with indexes');
            } catch (e) {
              debugPrint('❌ Failed to create message_reactions table: $e');
            }
          }

          // Migration to v27: add image_width and image_height columns to messages table
          if (oldVersion < 27) {
            debugPrint(
              '📦 Adding image_width and image_height columns to messages table...',
            );
            try {
              await db.execute(
                'ALTER TABLE ${MessagesTable.tableName} ADD COLUMN ${MessagesTable.columnImageWidth} INTEGER',
              );
              await db.execute(
                'ALTER TABLE ${MessagesTable.tableName} ADD COLUMN ${MessagesTable.columnImageHeight} INTEGER',
              );
              debugPrint(
                '✅ image_width and image_height columns added to messages table',
              );
            } catch (e) {
              debugPrint(
                '⚠️ image_width/image_height columns may already exist: $e',
              );
            }
          }

          if (oldVersion < 28) {
            debugPrint('📦 Adding follow_ups table...');
            try {
              await db.execute(FollowUpsTable.createTableSQL);
              await db.execute(FollowUpsTable.createIndexSQL);
              debugPrint('✅ follow_ups table added');
            } catch (e) {
              debugPrint('❌ follow_ups table migration failed: $e');
            }
          }

          if (oldVersion < 29) {
            debugPrint('📦 Adding status_likes table...');
            try {
              await db.execute(StatusLikesTable.createTableSQL);
              await db.execute(StatusLikesTable.createIndexSQL);
              debugPrint('✅ status_likes table added');
            } catch (e) {
              debugPrint('❌ status_likes table migration failed: $e');
            }
          }

          if (oldVersion < 30) {
            debugPrint('📦 Adding stories tables...');
            try {
              await db.execute(MyStoriesTable.createTableSQL);
              await db.execute(MyStoriesTable.createIndexSQL);
              debugPrint('✅ my_stories table added');

              await db.execute(ContactsStoriesTable.createTableSQL);
              await db.execute(ContactsStoriesTable.createIndexSQL);
              debugPrint('✅ contacts_stories table added');
            } catch (e) {
              debugPrint('❌ stories tables migration failed: $e');
            }
          }

          if (oldVersion < 31) {
            debugPrint(
              '📦 Adding toggle_count column to chat_picture_likes...',
            );
            try {
              await db.execute(ChatPictureLikesTable.addToggleCountColumnSQL);
              debugPrint('✅ toggle_count column added to chat_picture_likes');
            } catch (e) {
              debugPrint('⚠️ toggle_count column may already exist: $e');
            }
          }

          if (oldVersion < 32) {
            debugPrint('📦 Adding story_viewers table...');
            try {
              await db.execute(StoryViewersTable.createTableSQL);
              await db.execute(StoryViewersTable.createIndexSQL);
              debugPrint('✅ story_viewers table added');
            } catch (e) {
              debugPrint('❌ story_viewers table migration failed: $e');
            }
          }

          if (oldVersion < 33) {
            debugPrint('📦 Adding toggle_count column to status_likes...');
            try {
              await db.execute(StatusLikesTable.addToggleCountColumnSQL);
              debugPrint('✅ toggle_count column added to status_likes');
            } catch (e) {
              debugPrint('⚠️ toggle_count column may already exist: $e');
            }
          }

          if (oldVersion < 34) {
            debugPrint('📦 Adding video story columns to story tables...');
            try {
              await db.execute(
                'ALTER TABLE ${MyStoriesTable.tableName} ADD COLUMN thumbnail_url TEXT',
              );
              await db.execute(
                'ALTER TABLE ${MyStoriesTable.tableName} ADD COLUMN video_duration REAL',
              );
              debugPrint('✅ video story columns added to my_stories');
            } catch (e) {
              debugPrint('⚠️ my_stories video columns may already exist: $e');
            }
            try {
              await db.execute(
                'ALTER TABLE ${ContactsStoriesTable.tableName} ADD COLUMN thumbnail_url TEXT',
              );
              await db.execute(
                'ALTER TABLE ${ContactsStoriesTable.tableName} ADD COLUMN video_duration REAL',
              );
              debugPrint('✅ video story columns added to contacts_stories');
            } catch (e) {
              debugPrint(
                '⚠️ contacts_stories video columns may already exist: $e',
              );
            }
          }

          if (oldVersion < 35) {
            debugPrint('📦 Adding audio_duration column to messages table...');
            try {
              await db.execute(
                'ALTER TABLE ${MessagesTable.tableName} ADD COLUMN ${MessagesTable.columnAudioDuration} REAL',
              );
              debugPrint('✅ audio_duration column added to messages table');
            } catch (e) {
              debugPrint('⚠️ audio_duration column may already exist: $e');
            }
          }

          if (oldVersion < 36) {
            debugPrint('📦 Adding received_likes table...');
            try {
              await db.execute(ReceivedLikesTable.createTableSQL);
              await db.execute(ReceivedLikesTable.createIndexSQL);
              debugPrint('✅ received_likes table added');
            } catch (e) {
              debugPrint('❌ received_likes table migration failed: $e');
            }
          }

          // Migration to v37: add thumbnail_url column to messages table
          if (oldVersion < 37) {
            debugPrint('📦 Adding thumbnail_url column to messages table...');
            try {
              await db.execute(
                'ALTER TABLE ${MessagesTable.tableName} ADD COLUMN ${MessagesTable.columnThumbnailUrl} TEXT',
              );
              debugPrint('✅ thumbnail_url column added to messages table');
            } catch (e) {
              debugPrint('⚠️ thumbnail_url column may already exist: $e');
            }
          }

          // Migration to v38: add replyToMessageId column to messages table
          if (oldVersion < 38) {
            debugPrint(
              '📦 Adding replyToMessageId column to messages table...',
            );
            try {
              await db.execute(
                'ALTER TABLE ${MessagesTable.tableName} ADD COLUMN ${MessagesTable.columnReplyToMessageId} TEXT',
              );
              debugPrint('✅ replyToMessageId column added to messages table');
            } catch (e) {
              debugPrint('⚠️ replyToMessageId column may already exist: $e');
            }
          }

          // Migration to v39: add reply message data columns
          if (oldVersion < 39) {
            debugPrint(
              '📦 Adding reply message data columns to messages table...',
            );
            try {
              await db.execute(
                'ALTER TABLE ${MessagesTable.tableName} ADD COLUMN ${MessagesTable.columnReplyToMessageText} TEXT',
              );
              await db.execute(
                'ALTER TABLE ${MessagesTable.tableName} ADD COLUMN ${MessagesTable.columnReplyToMessageSenderId} TEXT',
              );
              await db.execute(
                'ALTER TABLE ${MessagesTable.tableName} ADD COLUMN ${MessagesTable.columnReplyToMessageType} TEXT',
              );
              debugPrint(
                '✅ Reply message data columns added to messages table',
              );
            } catch (e) {
              debugPrint('⚠️ Reply message data columns may already exist: $e');
            }
          }

          // Migration to v40: add call_history table
          if (oldVersion < 40) {
            debugPrint('📦 Adding call_history table...');
            try {
              await db.execute(CallHistoryTable.createTableSQL);
              await db.execute(CallHistoryTable.createIndexSQL);
              await db.execute(CallHistoryTable.createContactIndexSQL);
              debugPrint('✅ call_history table added');
            } catch (e) {
              debugPrint('❌ call_history table migration failed: $e');
            }
          }
        },
      );
    } catch (e) {
      // Database is corrupted or incompatible, delete and recreate
      debugPrint('❌ Database error: $e');
      debugPrint('🔄 Deleting corrupted database and creating fresh one...');

      try {
        await deleteDatabase(path);
      } catch (_) {}

      // Retry opening database after deletion
      return await openDatabase(
        path,
        version: _dbVersion,
        onCreate: (db, version) async {
          debugPrint(
            '📦 Creating database tables (after corruption recovery)...',
          );
          await db.execute(ContactsTable.createTableSQL);
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_app_user_id ON ${ContactsTable.tableName} (app_user_id)',
          );
          await db.execute(MobileNumberTable.createTableSQL);
          await db.execute(CurrentUserProfileTable.createTableSQL);
          await db.execute(EmojiTable.createTableSQL);
          await db.execute(AppUsersEmojiTable.createTableSQL);
          await db.execute(MessagesTable.createTableSQL);
          await db.execute(MessagesTable.createIndexSQL);
          await db.execute(MessagesTable.createStatusIndexSQL);
          await db.execute(MessagesTable.createTimeIndexSQL);
          await db.execute(ChatUsersTable.createTableSQL);
          await db.execute(ChatUsersTable.createIndexSQL);
          await db.execute(AppStartupSnapshotTable.createTableSQL);
          await db.execute(BlockedContactsTable.createTableSQL);
          await db.execute(ProfilePictureCacheTable.createTableSQL);
          await db.execute(ProfilePictureCacheTable.createIndexSQL);
          await db.execute(ChatPictureLikesTable.createTableSQL);
          await db.execute(ChatPictureLikesTable.createIndexSQL);
          await db.execute(StatusLikesTable.createTableSQL);
          await db.execute(StatusLikesTable.createIndexSQL);
          await db.execute(ChatSyncMetadataTable.createTableSQL);
          await db.execute(ChatSyncMetadataTable.createIndexSQL);
          await db.execute(FollowUpsTable.createTableSQL);
          await db.execute(FollowUpsTable.createIndexSQL);
          await db.execute(DraggableEmojiTable.createTableSql);
          await db.execute(FeatureTipDismissalsTable.createTableSQL);
          await db.execute(FeatureTipDismissalsTable.createUserIndexSQL);
          await db.execute(MyStoriesTable.createTableSQL);
          await db.execute(MyStoriesTable.createIndexSQL);
          await db.execute(ContactsStoriesTable.createTableSQL);
          await db.execute(ContactsStoriesTable.createIndexSQL);
          await db.execute(StoryViewersTable.createTableSQL);
          await db.execute(StoryViewersTable.createIndexSQL);
          await db.execute(ReceivedLikesTable.createTableSQL);
          await db.execute(ReceivedLikesTable.createIndexSQL);
          await db.execute(CallHistoryTable.createTableSQL);
          await db.execute(CallHistoryTable.createIndexSQL);
          await db.execute(CallHistoryTable.createContactIndexSQL);
          debugPrint('✅ Database recovered successfully');
        },
      );
    }
  }

  /// Closes any open connection and deletes the database file from disk.
  /// Used on logout and first-run cleanup to ensure a clean local state.
  Future<void> deleteDatabaseFile() async {
    try {
      final db = _database;
      if (db != null && db.isOpen) {
        await db.close();
      }
    } catch (_) {}
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);
    await deleteDatabase(path);
    _database = null;
  }
}
