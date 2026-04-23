import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../app_database.dart';

/// Database table for caching contacts' stories (offline-first)
/// Stores stories from contacts for offline viewing
class ContactsStoriesTable {
  static const String tableName = 'contacts_stories';

  static const String columnCurrentUserId = 'current_user_id';
  static const String columnStoryId = 'story_id';
  static const String columnStoryOwnerId = 'story_owner_id';
  static const String columnOwnerFirstName = 'owner_first_name';
  static const String columnOwnerLastName = 'owner_last_name';
  static const String columnOwnerChatPicture = 'owner_chat_picture';
  static const String columnOwnerMobileNumber = 'owner_mobile_number';
  static const String columnMediaUrl = 'media_url';
  static const String columnMediaType = 'media_type';
  static const String columnCaption = 'caption';
  static const String columnDuration = 'duration';
  static const String columnViewsCount = 'views_count';
  static const String columnExpiresAt = 'expires_at';
  static const String columnBackgroundColor = 'background_color';
  static const String columnCreatedAt = 'created_at';
  static const String columnUpdatedAt = 'updated_at';
  static const String columnIsViewed = 'is_viewed';
  static const String columnHasUnviewed = 'has_unviewed';
  static const String columnThumbnailUrl = 'thumbnail_url';
  static const String columnVideoDuration = 'video_duration';
  static const String columnCachedAt = 'cached_at';

  static const String createTableSQL =
      '''
    CREATE TABLE IF NOT EXISTS $tableName (
      $columnCurrentUserId TEXT NOT NULL,
      $columnStoryId TEXT NOT NULL,
      $columnStoryOwnerId TEXT NOT NULL,
      $columnOwnerFirstName TEXT,
      $columnOwnerLastName TEXT,
      $columnOwnerChatPicture TEXT,
      $columnOwnerMobileNumber TEXT,
      $columnMediaUrl TEXT NOT NULL,
      $columnMediaType TEXT NOT NULL DEFAULT 'image',
      $columnCaption TEXT,
      $columnDuration INTEGER NOT NULL DEFAULT 5,
      $columnViewsCount INTEGER NOT NULL DEFAULT 0,
      $columnExpiresAt INTEGER NOT NULL,
      $columnBackgroundColor TEXT,
      $columnCreatedAt INTEGER NOT NULL,
      $columnUpdatedAt INTEGER NOT NULL,
      $columnIsViewed INTEGER NOT NULL DEFAULT 0,
      $columnHasUnviewed INTEGER NOT NULL DEFAULT 1,
      $columnThumbnailUrl TEXT,
      $columnVideoDuration REAL,
      $columnCachedAt INTEGER NOT NULL,
      PRIMARY KEY ($columnCurrentUserId, $columnStoryId)
    )
  ''';

  static const String createIndexSQL =
      '''
    CREATE INDEX IF NOT EXISTS idx_contacts_stories_user_owner 
    ON $tableName ($columnCurrentUserId, $columnStoryOwnerId, $columnExpiresAt)
  ''';

  static Database? _dbCache;
  static Future<Database> get _database async {
    _dbCache ??= await AppDatabaseManager.instance.database;
    return _dbCache!;
  }

  /// Get all cached contacts stories grouped by owner (not expired)
  static Future<List<Map<String, dynamic>>> getContactsStories({
    required String currentUserId,
  }) async {
    try {
      final db = await _database;
      final now = DateTime.now().millisecondsSinceEpoch;

      final rows = await db.query(
        tableName,
        where: '$columnCurrentUserId = ? AND $columnExpiresAt > ?',
        whereArgs: [currentUserId, now],
        orderBy: '$columnStoryOwnerId, $columnCreatedAt DESC',
      );

      return rows;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [ContactsStoriesTable] getContactsStories error: $e');
      }
      return [];
    }
  }

  static Future<void> markAsViewedAndUpdateHasUnviewed({
    required String currentUserId,
    required String storyId,
  }) async {
    try {
      final db = await _database;

      await db.transaction((txn) async {
        await txn.update(
          tableName,
          {columnIsViewed: 1},
          where: '$columnCurrentUserId = ? AND $columnStoryId = ?',
          whereArgs: [currentUserId, storyId],
        );

        final ownerRows = await txn.query(
          tableName,
          columns: [columnStoryOwnerId],
          where: '$columnCurrentUserId = ? AND $columnStoryId = ?',
          whereArgs: [currentUserId, storyId],
          limit: 1,
        );
        if (ownerRows.isEmpty) return;

        final ownerId = ownerRows.first[columnStoryOwnerId] as String? ?? '';
        if (ownerId.isEmpty) return;

        final now = DateTime.now().millisecondsSinceEpoch;
        final unviewedCount =
            Sqflite.firstIntValue(
              await txn.rawQuery(
                'SELECT COUNT(1) FROM $tableName '
                'WHERE $columnCurrentUserId = ? '
                'AND $columnStoryOwnerId = ? '
                'AND $columnExpiresAt > ? '
                'AND $columnIsViewed = 0',
                [currentUserId, ownerId, now],
              ),
            ) ??
            0;

        final hasUnviewed = unviewedCount > 0;
        await txn.update(
          tableName,
          {columnHasUnviewed: hasUnviewed ? 1 : 0},
          where: '$columnCurrentUserId = ? AND $columnStoryOwnerId = ?',
          whereArgs: [currentUserId, ownerId],
        );
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '❌ [ContactsStoriesTable] markAsViewedAndUpdateHasUnviewed error: $e',
        );
      }
    }
  }

  /// Get stories for a specific contact
  static Future<List<Map<String, dynamic>>> getStoriesForContact({
    required String currentUserId,
    required String contactId,
  }) async {
    try {
      final db = await _database;
      final now = DateTime.now().millisecondsSinceEpoch;

      final rows = await db.query(
        tableName,
        where:
            '$columnCurrentUserId = ? AND $columnStoryOwnerId = ? AND $columnExpiresAt > ?',
        whereArgs: [currentUserId, contactId, now],
        orderBy: '$columnCreatedAt DESC',
      );

      return rows;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [ContactsStoriesTable] getStoriesForContact error: $e');
      }
      return [];
    }
  }

  /// Get unique contact IDs who have stories
  static Future<List<String>> getContactsWithStories({
    required String currentUserId,
  }) async {
    try {
      final db = await _database;
      final now = DateTime.now().millisecondsSinceEpoch;

      final rows = await db.rawQuery(
        '''
        SELECT DISTINCT $columnStoryOwnerId 
        FROM $tableName 
        WHERE $columnCurrentUserId = ? AND $columnExpiresAt > ?
        ORDER BY MAX($columnCreatedAt) DESC
        ''',
        [currentUserId, now],
      );

      return rows.map((r) => r[columnStoryOwnerId] as String).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [ContactsStoriesTable] getContactsWithStories error: $e');
      }
      return [];
    }
  }

  /// Insert or update a story
  static Future<void> upsertStory({
    required String currentUserId,
    required String storyId,
    required String storyOwnerId,
    String? ownerFirstName,
    String? ownerLastName,
    String? ownerChatPicture,
    String? ownerMobileNumber,
    required String mediaUrl,
    required String mediaType,
    String? caption,
    required int duration,
    required int viewsCount,
    required DateTime expiresAt,
    String? backgroundColor,
    required DateTime createdAt,
    required DateTime updatedAt,
    bool isViewed = false,
    bool hasUnviewed = true,
    String? thumbnailUrl,
    double? videoDuration,
  }) async {
    try {
      final db = await _database;
      final now = DateTime.now().millisecondsSinceEpoch;

      await db.insert(tableName, {
        columnCurrentUserId: currentUserId,
        columnStoryId: storyId,
        columnStoryOwnerId: storyOwnerId,
        columnOwnerFirstName: ownerFirstName,
        columnOwnerLastName: ownerLastName,
        columnOwnerChatPicture: ownerChatPicture,
        columnOwnerMobileNumber: ownerMobileNumber,
        columnMediaUrl: mediaUrl,
        columnMediaType: mediaType,
        columnCaption: caption,
        columnDuration: duration,
        columnViewsCount: viewsCount,
        columnExpiresAt: expiresAt.millisecondsSinceEpoch,
        columnBackgroundColor: backgroundColor,
        columnCreatedAt: createdAt.millisecondsSinceEpoch,
        columnUpdatedAt: updatedAt.millisecondsSinceEpoch,
        columnIsViewed: isViewed ? 1 : 0,
        columnHasUnviewed: hasUnviewed ? 1 : 0,
        columnThumbnailUrl: thumbnailUrl,
        columnVideoDuration: videoDuration,
        columnCachedAt: now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      if (kDebugMode) {
        debugPrint('✅ [ContactsStoriesTable] Upserted story: $storyId');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [ContactsStoriesTable] upsertStory error: $e');
      }
    }
  }

  /// Mark a story as viewed
  static Future<void> markAsViewed({
    required String currentUserId,
    required String storyId,
  }) async {
    try {
      final db = await _database;
      await db.update(
        tableName,
        {columnIsViewed: 1},
        where: '$columnCurrentUserId = ? AND $columnStoryId = ?',
        whereArgs: [currentUserId, storyId],
      );

      if (kDebugMode) {
        debugPrint('✅ [ContactsStoriesTable] Marked story as viewed: $storyId');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [ContactsStoriesTable] markAsViewed error: $e');
      }
    }
  }

  /// Delete a story
  static Future<void> deleteStory({
    required String currentUserId,
    required String storyId,
  }) async {
    try {
      final db = await _database;
      await db.delete(
        tableName,
        where: '$columnCurrentUserId = ? AND $columnStoryId = ?',
        whereArgs: [currentUserId, storyId],
      );

      if (kDebugMode) {
        debugPrint('✅ [ContactsStoriesTable] Deleted story: $storyId');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [ContactsStoriesTable] deleteStory error: $e');
      }
    }
  }

  /// Delete all stories for a contact
  static Future<void> deleteStoriesForContact({
    required String currentUserId,
    required String contactId,
  }) async {
    try {
      final db = await _database;
      await db.delete(
        tableName,
        where: '$columnCurrentUserId = ? AND $columnStoryOwnerId = ?',
        whereArgs: [currentUserId, contactId],
      );

      if (kDebugMode) {
        debugPrint(
          '✅ [ContactsStoriesTable] Deleted all stories for contact: $contactId',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '❌ [ContactsStoriesTable] deleteStoriesForContact error: $e',
        );
      }
    }
  }

  /// Delete all expired stories
  static Future<void> deleteExpiredStories({
    required String currentUserId,
  }) async {
    try {
      final db = await _database;
      final now = DateTime.now().millisecondsSinceEpoch;

      final count = await db.delete(
        tableName,
        where: '$columnCurrentUserId = ? AND $columnExpiresAt <= ?',
        whereArgs: [currentUserId, now],
      );

      if (kDebugMode && count > 0) {
        debugPrint('🗑️ [ContactsStoriesTable] Deleted $count expired stories');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [ContactsStoriesTable] deleteExpiredStories error: $e');
      }
    }
  }

  /// Clear all contacts stories for current user
  static Future<void> clearAllStories({required String currentUserId}) async {
    try {
      final db = await _database;
      await db.delete(
        tableName,
        where: '$columnCurrentUserId = ?',
        whereArgs: [currentUserId],
      );

      if (kDebugMode) {
        debugPrint('🗑️ [ContactsStoriesTable] Cleared all stories for user');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [ContactsStoriesTable] clearAllStories error: $e');
      }
    }
  }

  /// Bulk insert stories from contacts (replaces all existing)
  static Future<void> replaceAllStories({
    required String currentUserId,
    required List<Map<String, dynamic>> storiesWithOwner,
  }) async {
    try {
      final db = await _database;
      final now = DateTime.now().millisecondsSinceEpoch;

      await db.transaction((txn) async {
        // Snapshot locally-viewed story IDs BEFORE deleting so we can
        // preserve the viewed state even if the server hasn't processed
        // the view event yet.
        final viewedRows = await txn.query(
          tableName,
          columns: [columnStoryId],
          where: '$columnCurrentUserId = ? AND $columnIsViewed = 1',
          whereArgs: [currentUserId],
        );
        final locallyViewedIds = <String>{
          for (final r in viewedRows)
            if (r[columnStoryId] is String) r[columnStoryId] as String,
        };

        // Clear existing stories
        await txn.delete(
          tableName,
          where: '$columnCurrentUserId = ?',
          whereArgs: [currentUserId],
        );

        // Insert new stories
        for (final item in storiesWithOwner) {
          final owner = item['user'] as Map<String, dynamic>?;
          final stories = item['stories'] as List<dynamic>? ?? [];
          final hasUnviewed = item['hasUnviewed'] as bool? ?? false;

          // Track how many stories in this group are actually unviewed
          // after merging local viewed state.
          int groupUnviewedCount = 0;
          final insertedRows = <Map<String, dynamic>>[];

          for (final story in stories) {
            final storyMap = story as Map<String, dynamic>;
            final storyId = (storyMap['id'] ?? storyMap['storyId']) as String?;
            final createdAtRaw = storyMap['createdAt'];
            final updatedAtRaw = storyMap['updatedAt'];
            final createdAtParsed = _parseTimestamp(createdAtRaw);
            final updatedAtParsed = _parseTimestamp(updatedAtRaw);

            // Merge: if local DB had this story as viewed, keep it viewed
            // even if the server says isViewed=false (race condition).
            final serverViewed = storyMap['isViewed'] == true;
            final localViewed =
                storyId != null && locallyViewedIds.contains(storyId);
            final isViewed = serverViewed || localViewed;

            if (!isViewed) groupUnviewedCount++;

            final row = {
              columnCurrentUserId: currentUserId,
              columnStoryId: storyId,
              columnStoryOwnerId: owner?['id'] ?? storyMap['userId'],
              columnOwnerFirstName: owner?['firstName'] ?? owner?['first_name'],
              columnOwnerLastName: owner?['lastName'] ?? owner?['last_name'],
              columnOwnerChatPicture:
                  owner?['chatPicture'] ?? owner?['chat_picture'],
              columnOwnerMobileNumber:
                  owner?['mobileNumber'] ?? owner?['mobile_number'],
              columnMediaUrl: storyMap['mediaUrl'] ?? '',
              columnMediaType: storyMap['mediaType'] ?? 'image',
              columnCaption: storyMap['caption'],
              columnDuration: storyMap['duration'] ?? 5,
              columnViewsCount: storyMap['viewsCount'] ?? 0,
              columnExpiresAt: _parseTimestamp(storyMap['expiresAt']),
              columnBackgroundColor: storyMap['backgroundColor'],
              columnCreatedAt: createdAtParsed,
              columnUpdatedAt: updatedAtParsed,
              columnIsViewed: isViewed ? 1 : 0,
              columnHasUnviewed: hasUnviewed ? 1 : 0,
              columnThumbnailUrl: storyMap['thumbnailUrl'],
              columnVideoDuration: (storyMap['videoDuration'] as num?)
                  ?.toDouble(),
              columnCachedAt: now,
            };
            insertedRows.add(row);
            await txn.insert(tableName, row);
          }

          // Correct hasUnviewed based on merged viewed state
          final mergedHasUnviewed = groupUnviewedCount > 0;
          if (mergedHasUnviewed != hasUnviewed && insertedRows.isNotEmpty) {
            final ownerId = owner?['id'] ?? '';
            if ((ownerId as String).isNotEmpty) {
              await txn.update(
                tableName,
                {columnHasUnviewed: mergedHasUnviewed ? 1 : 0},
                where: '$columnCurrentUserId = ? AND $columnStoryOwnerId = ?',
                whereArgs: [currentUserId, ownerId],
              );
            }
          }
        }
      });

      if (kDebugMode) {
        debugPrint(
          '✅ [ContactsStoriesTable] Replaced all stories: ${storiesWithOwner.length} contacts',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [ContactsStoriesTable] replaceAllStories error: $e');
      }
    }
  }

  static int _parseTimestamp(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is DateTime) return value.millisecondsSinceEpoch;
    if (value is num) return value.toInt();
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return 0;
      // Try parsing as int first (milliseconds)
      final asInt = int.tryParse(trimmed);
      if (asInt != null) return asInt;
      // Try parsing as ISO8601 date string
      final dt = DateTime.tryParse(trimmed);
      if (dt != null) return dt.millisecondsSinceEpoch;
      return 0;
    }
    return 0;
  }
}
