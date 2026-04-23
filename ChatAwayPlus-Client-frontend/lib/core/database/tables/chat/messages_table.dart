// ============================================================================
// MESSAGES TABLE - Schema Definition & CRUD Operations
// ============================================================================
// This file defines the structure of the messages table.
// Stores chat messages locally for offline access and quick loading
// ============================================================================

import 'package:chataway_plus/core/database/app_database.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

// ============================================================================
// MESSAGES TABLE - Schema Definition & CRUD Operations
// ============================================================================

class MessagesTable {
  static const bool _verboseDbLogs = false;

  // ============================================================================
  // SCHEMA DEFINITIONS
  // ============================================================================

  /// Table name constant
  static const String tableName = 'messages';

  /// Column name constants
  static const String columnId = 'id';
  static const String columnSenderId = 'sender_id';
  static const String columnReceiverId = 'receiver_id';
  static const String columnMessage = 'message';
  static const String columnMessageStatus = 'message_status';
  static const String columnIsRead = 'is_read';
  static const String columnDeliveredAt = 'delivered_at';
  static const String columnReadAt = 'read_at';
  static const String columnIsEdited = 'is_edited';
  static const String columnEditedAt = 'edited_at';
  static const String columnCreatedAt = 'created_at';
  static const String columnUpdatedAt = 'updated_at';
  static const String columnDeliveryChannel = 'delivery_channel';
  static const String columnReceiverDeliveryChannel =
      'receiver_delivery_channel';

  static const String columnMessageType = 'message_type';
  static const String columnFileUrl = 'file_url';
  static const String columnMimeType = 'mime_type';
  static const String columnFileName = 'file_name';
  static const String columnPageCount = 'page_count';
  static const String columnFileSize = 'file_size';
  static const String columnCachedFilePath = 'cached_file_path';
  static const String columnReactionsJson = 'reactions_json';
  static const String columnIsStarred = 'is_starred';
  static const String columnImageWidth = 'image_width';
  static const String columnImageHeight = 'image_height';
  static const String columnIsFollowUp = 'is_follow_up';
  static const String columnAudioDuration = 'audio_duration';
  static const String columnThumbnailUrl = 'thumbnail_url';
  static const String columnReplyToMessageId = 'replyToMessageId';
  static const String columnReplyToMessageText = 'replyToMessageText';
  static const String columnReplyToMessageSenderId = 'replyToMessageSenderId';
  static const String columnReplyToMessageType = 'replyToMessageType';

  /// SQL CREATE TABLE statement - Messages Table
  ///
  /// Stores chat messages locally for offline access
  /// Message status values: 'sent', 'delivered', 'read'
  /// Delivery channel values: 'socket', 'fcm'
  static const String createTableSQL =
      '''
CREATE TABLE $tableName (
  $columnId TEXT PRIMARY KEY,                   -- Message UUID from backend
  $columnSenderId TEXT NOT NULL,                -- Sender user UUID
  $columnReceiverId TEXT NOT NULL,              -- Receiver user UUID
  $columnMessage TEXT NOT NULL,                 -- Message content
  $columnMessageType TEXT DEFAULT 'text',        -- 'text', 'image', 'video', 'audio', 'document', 'pdf'
  $columnFileUrl TEXT,                           -- media url (S3)
  $columnMimeType TEXT,                          -- e.g. application/pdf
  $columnFileName TEXT,                          -- e.g. Invoice.pdf
  $columnPageCount INTEGER,                      -- pdf page count
  $columnFileSize INTEGER,                       -- bytes
  $columnCachedFilePath TEXT,                    -- local cached file path for offline access
  $columnReactionsJson TEXT,
  $columnIsStarred INTEGER DEFAULT 0,
  $columnImageWidth INTEGER,                       -- image width in pixels
  $columnImageHeight INTEGER,                      -- image height in pixels
  $columnIsFollowUp INTEGER DEFAULT 0,             -- 1 = follow-up message, 0 = regular message
  $columnAudioDuration REAL,                         -- audio duration in seconds (for voice messages)
  $columnThumbnailUrl TEXT,                          -- thumbnail URL for video messages (S3 key)
  $columnReplyToMessageId TEXT,                       -- UUID of the message being replied to (nullable)
  $columnReplyToMessageText TEXT,                     -- Text content of the replied message (nullable)
  $columnReplyToMessageSenderId TEXT,                 -- Sender ID of the replied message (nullable)
  $columnReplyToMessageType TEXT,                     -- Message type of the replied message (nullable)
  $columnMessageStatus TEXT NOT NULL,           -- 'sent', 'delivered', 'read'
  $columnIsRead INTEGER DEFAULT 0,              -- 1 = read, 0 = unread
  $columnDeliveredAt INTEGER,                   -- Timestamp when delivered (nullable)
  $columnReadAt INTEGER,                        -- Timestamp when read (nullable)
  $columnIsEdited INTEGER DEFAULT 0,            -- 1 = edited, 0 = not edited
  $columnEditedAt INTEGER,                      -- Timestamp when edited (nullable)
  $columnCreatedAt INTEGER NOT NULL,            -- Timestamp when created
  $columnUpdatedAt INTEGER NOT NULL,            -- Timestamp when last updated
  $columnDeliveryChannel TEXT DEFAULT 'socket', -- 'socket' or 'fcm'
  $columnReceiverDeliveryChannel TEXT           -- 'socket', 'fcm', or null
)
''';

  /// Index for faster queries by chat participants
  static const String createIndexSQL =
      '''
CREATE INDEX IF NOT EXISTS idx_chat_participants
ON $tableName ($columnSenderId, $columnReceiverId)
''';

  /// Index for faster queries by message status
  static const String createStatusIndexSQL =
      '''
CREATE INDEX IF NOT EXISTS idx_message_status
ON $tableName ($columnMessageStatus)
''';

  /// Index for faster queries by created_at (for sorting)
  static const String createTimeIndexSQL =
      '''
CREATE INDEX IF NOT EXISTS idx_created_at
ON $tableName ($columnCreatedAt DESC)
''';

  // ============================================================================
  // SINGLETON INSTANCE
  // ============================================================================

  MessagesTable._();
  static final MessagesTable _instance = MessagesTable._();
  static MessagesTable get instance => _instance;

  // Get database from AppDatabaseManager
  Future<Database> get _database async {
    return await AppDatabaseManager.instance.database;
  }

  static bool _isEmptyString(Object? value) {
    if (value == null) return true;
    return value.toString().trim().isEmpty;
  }

  static void _preserveRicherFields(
    Map<String, dynamic> messageData,
    Map<String, dynamic> existing,
  ) {
    final existingType = existing[columnMessageType] as String?;
    final newType = messageData[columnMessageType] as String?;
    if ((newType == null || newType == 'text') &&
        existingType != null &&
        existingType.isNotEmpty &&
        existingType != 'text') {
      messageData[columnMessageType] = existingType;
    }

    final existingMessage = existing[columnMessage] as String?;
    final newMessage = messageData[columnMessage] as String?;
    if ((newMessage == null || newMessage.isEmpty) &&
        existingMessage != null &&
        existingMessage.isNotEmpty) {
      messageData[columnMessage] = existingMessage;
    }

    final preserveStringColumns = <String>[
      columnFileUrl,
      columnMimeType,
      columnFileName,
      columnReceiverDeliveryChannel,
      columnReactionsJson,
      columnCachedFilePath,
      columnThumbnailUrl,
      columnReplyToMessageId,
      columnReplyToMessageText,
      columnReplyToMessageSenderId,
      columnReplyToMessageType,
    ];

    if (!messageData.containsKey(columnIsStarred) &&
        existing.containsKey(columnIsStarred)) {
      messageData[columnIsStarred] = existing[columnIsStarred];
    }

    for (final col in preserveStringColumns) {
      final existingVal = existing[col];
      final newVal = messageData[col];
      if (_isEmptyString(newVal) && !_isEmptyString(existingVal)) {
        messageData[col] = existingVal;
      }
    }

    final preserveNullableIntColumns = <String>[
      columnPageCount,
      columnFileSize,
      columnImageWidth,
      columnImageHeight,
    ];

    for (final col in preserveNullableIntColumns) {
      final newVal = messageData[col];
      final existingVal = existing[col];
      if (newVal == null && existingVal != null) {
        messageData[col] = existingVal;
      }
    }

    final existingEdited = existing[columnIsEdited] as int?;
    final newEdited = messageData[columnIsEdited] as int?;
    if ((newEdited ?? 0) == 0 && (existingEdited ?? 0) == 1) {
      messageData[columnIsEdited] = 1;
      if (existing[columnEditedAt] != null &&
          messageData[columnEditedAt] == null) {
        messageData[columnEditedAt] = existing[columnEditedAt];
      }
    }

    // Preserve isFollowUp flag - preserve both set (1) and explicitly deleted (0) states
    // This prevents server sync from overwriting local follow-up deletion
    if (existing.containsKey(columnIsFollowUp)) {
      final existingIsFollowUp = existing[columnIsFollowUp] as int?;
      final newIsFollowUp = messageData[columnIsFollowUp] as int?;

      // If existing has explicit value (0 or 1) and new doesn't specify, preserve existing
      if (existingIsFollowUp != null &&
          (newIsFollowUp == null || newIsFollowUp == 0)) {
        messageData[columnIsFollowUp] = existingIsFollowUp;
      }
    }
  }

  // --------------------------------------------------------------------------
  // STATUS PRIORITY HELPER
  // --------------------------------------------------------------------------

  /// Status priority: read > delivered > sent > sending/pending_sync
  /// Higher number = higher priority (should not be overwritten by lower)
  static int _getStatusPriority(String? status) {
    switch (status) {
      case 'read':
        return 4;
      case 'delivered':
        return 3;
      case 'sent':
        return 2;
      case 'sending':
      case 'pending_sync':
        return 1;
      default:
        return 0;
    }
  }

  // --------------------------------------------------------------------------
  // INSERT/UPDATE OPERATIONS
  // --------------------------------------------------------------------------

  /// Insert or update a single message
  /// WHATSAPP-STYLE: Preserves higher-priority status (prevents read→delivered regression)
  Future<void> insertOrUpdateMessage(Map<String, dynamic> messageData) async {
    final db = await _database;

    try {
      final messageId = messageData[columnId] as String?;
      if (messageId == null) {
        debugPrint('❌ Cannot save message without ID');
        return;
      }

      // Check existing message status to prevent regression
      final existing = await getMessageById(messageId);
      if (existing != null) {
        _preserveRicherFields(messageData, existing);
        final existingStatus = existing[columnMessageStatus] as String?;
        final newStatus = messageData[columnMessageStatus] as String?;
        final existingPriority = _getStatusPriority(existingStatus);
        final newPriority = _getStatusPriority(newStatus);

        // If existing status has higher priority, preserve it
        if (existingPriority > newPriority) {
          messageData[columnMessageStatus] = existingStatus;
          // Also preserve read/delivered timestamps
          if (existing[columnIsRead] == 1) {
            messageData[columnIsRead] = 1;
          }
          if (existing[columnReadAt] != null) {
            messageData[columnReadAt] = existing[columnReadAt];
          }
          if (existing[columnDeliveredAt] != null) {
            messageData[columnDeliveredAt] = existing[columnDeliveredAt];
          }
        }
      }

      final replyId = messageData[columnReplyToMessageId] as String?;
      if (replyId != null && replyId.trim().isNotEmpty) {
        final hasText = !_isEmptyString(messageData[columnReplyToMessageText]);
        final hasSenderId = !_isEmptyString(
          messageData[columnReplyToMessageSenderId],
        );
        final hasType = !_isEmptyString(messageData[columnReplyToMessageType]);
        if (!hasText || !hasSenderId || !hasType) {
          final replied = await getMessageById(replyId);
          if (replied != null) {
            if (!hasText && !_isEmptyString(replied[columnMessage])) {
              messageData[columnReplyToMessageText] = replied[columnMessage];
            }
            if (!hasSenderId && !_isEmptyString(replied[columnSenderId])) {
              messageData[columnReplyToMessageSenderId] =
                  replied[columnSenderId];
            }
            if (!hasType && !_isEmptyString(replied[columnMessageType])) {
              messageData[columnReplyToMessageType] =
                  replied[columnMessageType];
            }
          }
        }
      }

      await db.insert(
        tableName,
        messageData,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('❌ Error saving message: $e');
      rethrow;
    }
  }

  /// Insert or update multiple messages in a batch
  /// WHATSAPP-STYLE: Preserves higher-priority status for each message
  Future<void> insertOrUpdateMessages(
    List<Map<String, dynamic>> messages,
  ) async {
    if (messages.isEmpty) return;

    final db = await _database;

    try {
      final replyIdsNeedingBackfill = <String>{};
      for (final message in messages) {
        final replyId = message[columnReplyToMessageId] as String?;
        if (replyId == null || replyId.trim().isEmpty) continue;
        final hasText = !_isEmptyString(message[columnReplyToMessageText]);
        final hasSenderId = !_isEmptyString(
          message[columnReplyToMessageSenderId],
        );
        final hasType = !_isEmptyString(message[columnReplyToMessageType]);
        if (!hasText || !hasSenderId || !hasType) {
          replyIdsNeedingBackfill.add(replyId);
        }
      }

      final repliedById = <String, Map<String, dynamic>>{};
      if (replyIdsNeedingBackfill.isNotEmpty) {
        final ids = replyIdsNeedingBackfill.toList();
        final placeholders = List.filled(ids.length, '?').join(',');
        final repliedRows = await db.query(
          tableName,
          columns: [columnId, columnMessage, columnSenderId, columnMessageType],
          where: '$columnId IN ($placeholders)',
          whereArgs: ids,
        );
        for (final row in repliedRows) {
          final id = row[columnId] as String?;
          if (id != null) {
            repliedById[id] = row;
          }
        }
      }

      // Get all message IDs to check existing statuses
      final messageIds = messages
          .map((m) => m[columnId] as String?)
          .where((id) => id != null)
          .toList();

      // Fetch existing messages in one query for efficiency
      final existingMap = <String, Map<String, dynamic>>{};
      if (messageIds.isNotEmpty) {
        final placeholders = List.filled(messageIds.length, '?').join(',');
        final existing = await db.query(
          tableName,
          where: '$columnId IN ($placeholders)',
          whereArgs: messageIds,
        );
        for (final msg in existing) {
          final id = msg[columnId] as String?;
          if (id != null) existingMap[id] = msg;
        }
      }

      // Process messages with status priority check
      final batch = db.batch();
      for (final message in messages) {
        final messageId = message[columnId] as String?;
        if (messageId == null) continue;

        final existing = existingMap[messageId];
        if (existing != null) {
          _preserveRicherFields(message, existing);
          final existingStatus = existing[columnMessageStatus] as String?;
          final newStatus = message[columnMessageStatus] as String?;
          final existingPriority = _getStatusPriority(existingStatus);
          final newPriority = _getStatusPriority(newStatus);

          // Preserve higher-priority status
          if (existingPriority > newPriority) {
            message[columnMessageStatus] = existingStatus;
            if (existing[columnIsRead] == 1) {
              message[columnIsRead] = 1;
            }
            if (existing[columnReadAt] != null) {
              message[columnReadAt] = existing[columnReadAt];
            }
            if (existing[columnDeliveredAt] != null) {
              message[columnDeliveredAt] = existing[columnDeliveredAt];
            }
          }
        }

        final replyId = message[columnReplyToMessageId] as String?;
        if (replyId != null && replyId.trim().isNotEmpty) {
          final replied = repliedById[replyId];
          if (replied != null) {
            if (_isEmptyString(message[columnReplyToMessageText]) &&
                !_isEmptyString(replied[columnMessage])) {
              message[columnReplyToMessageText] = replied[columnMessage];
            }
            if (_isEmptyString(message[columnReplyToMessageSenderId]) &&
                !_isEmptyString(replied[columnSenderId])) {
              message[columnReplyToMessageSenderId] = replied[columnSenderId];
            }
            if (_isEmptyString(message[columnReplyToMessageType]) &&
                !_isEmptyString(replied[columnMessageType])) {
              message[columnReplyToMessageType] = replied[columnMessageType];
            }
          }
        }

        batch.insert(
          tableName,
          message,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await batch.commit(noResult: true);
      if (_verboseDbLogs && kDebugMode) {
        debugPrint(
          '💾 ${messages.length} messages saved in batch (status-aware)',
        );
      }
    } catch (e) {
      debugPrint('❌ Error saving messages batch: $e');
      rethrow;
    }
  }

  // --------------------------------------------------------------------------
  // QUERY OPERATIONS
  // --------------------------------------------------------------------------

  /// Get chat history between two users with pagination
  Future<List<Map<String, dynamic>>> getChatHistory({
    required String currentUserId,
    required String otherUserId,
    int page = 1,
    int limit = 50,
  }) async {
    final db = await _database;
    final offset = (page - 1) * limit;

    try {
      final results = await db.query(
        tableName,
        where:
            '''
          ($columnSenderId = ? AND $columnReceiverId = ?)
          OR
          ($columnSenderId = ? AND $columnReceiverId = ?)
        ''',
        whereArgs: [currentUserId, otherUserId, otherUserId, currentUserId],
        orderBy: '$columnCreatedAt DESC',
        limit: limit,
        offset: offset,
      );

      if (_verboseDbLogs && kDebugMode) {
        debugPrint('📖 Retrieved ${results.length} messages from page $page');
      }
      return results;
    } catch (e) {
      debugPrint('❌ Error getting chat history: $e');
      rethrow;
    }
  }

  /// Get a single message by ID
  Future<Map<String, dynamic>?> getMessageById(String messageId) async {
    final db = await _database;

    try {
      final results = await db.query(
        tableName,
        where: '$columnId = ?',
        whereArgs: [messageId],
        limit: 1,
      );

      return results.isNotEmpty ? results.first : null;
    } catch (e) {
      debugPrint('❌ Error getting message by ID: $e');
      rethrow;
    }
  }

  /// Get multiple messages by IDs (for fetching replied-to messages)
  Future<List<Map<String, dynamic>>> getMessagesByIds(
    List<String> messageIds,
  ) async {
    if (messageIds.isEmpty) return [];

    final db = await _database;

    try {
      final placeholders = messageIds.map((_) => '?').join(',');
      debugPrint(
        '🔍 [MessagesTable] getMessagesByIds: querying for ${messageIds.length} IDs: $messageIds',
      );
      final results = await db.query(
        tableName,
        where: '$columnId IN ($placeholders)',
        whereArgs: messageIds,
      );
      debugPrint(
        '🔍 [MessagesTable] getMessagesByIds: found ${results.length} messages',
      );

      return results;
    } catch (e) {
      debugPrint('❌ Error getting messages by IDs: $e');
      return [];
    }
  }

  /// Get unread message count for a specific user
  Future<int> getUnreadCount({
    required String currentUserId,
    String? otherUserId,
  }) async {
    final db = await _database;

    try {
      String whereClause =
          '$columnReceiverId = ? AND ($columnIsRead = 0 OR $columnMessageStatus != \'read\')';
      List<dynamic> whereArgs = [currentUserId];

      if (otherUserId != null) {
        whereClause += ' AND $columnSenderId = ?';
        whereArgs.add(otherUserId);
      }

      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $tableName WHERE $whereClause',
        whereArgs,
      );

      final count = Sqflite.firstIntValue(result) ?? 0;
      if (_verboseDbLogs && kDebugMode) {
        debugPrint('📊 Unread count: $count');
      }
      return count;
    } catch (e) {
      debugPrint('❌ Error getting unread count: $e');
      return 0;
    }
  }

  Future<Map<String, int>> getUnreadCountsBySender({
    required String currentUserId,
  }) async {
    final db = await _database;

    try {
      final rows = await db.rawQuery(
        '''
        SELECT $columnSenderId as sender_id, COUNT(*) as count
        FROM $tableName
        WHERE $columnReceiverId = ?
          AND ($columnIsRead = 0 OR $columnMessageStatus != 'read')
        GROUP BY $columnSenderId
        ''',
        [currentUserId],
      );

      final map = <String, int>{};
      for (final row in rows) {
        final senderId = row['sender_id']?.toString();
        if (senderId == null || senderId.isEmpty) continue;
        final raw = row['count'];
        final count = raw is int ? raw : (raw is num ? raw.toInt() : 0);
        map[senderId] = count;
      }
      return map;
    } catch (e) {
      debugPrint('❌ Error getting unread counts by sender: $e');
      return <String, int>{};
    }
  }

  /// Get latest message for each conversation
  Future<List<Map<String, dynamic>>> getLatestMessages({
    required String currentUserId,
  }) async {
    final db = await _database;

    try {
      // Get latest message for each unique conversation partner
      final results = await db.rawQuery(
        '''
        SELECT m.*
        FROM $tableName m
        INNER JOIN (
          SELECT
            CASE
              WHEN $columnSenderId = ? THEN $columnReceiverId
              ELSE $columnSenderId
            END as other_user_id,
            MAX($columnCreatedAt) as max_time
          FROM $tableName
          WHERE ($columnSenderId = ? OR $columnReceiverId = ?)
            AND (
              $columnMessageType = 'deleted'
              OR
              LENGTH(TRIM(COALESCE($columnMessage, ''))) > 0
              OR LENGTH(TRIM(COALESCE($columnFileUrl, ''))) > 0
              OR LENGTH(TRIM(COALESCE($columnMimeType, ''))) > 0
              OR LENGTH(TRIM(COALESCE($columnFileName, ''))) > 0
              OR $columnPageCount IS NOT NULL
              OR $columnFileSize IS NOT NULL
            )
          GROUP BY other_user_id
        ) latest
        ON (
          (m.$columnSenderId = ? AND m.$columnReceiverId = latest.other_user_id)
          OR
          (m.$columnReceiverId = ? AND m.$columnSenderId = latest.other_user_id)
        )
        AND m.$columnCreatedAt = latest.max_time
        AND m.$columnId = (
          SELECT m2.$columnId
          FROM $tableName m2
          WHERE (
            (m2.$columnSenderId = ? AND m2.$columnReceiverId = latest.other_user_id)
            OR
            (m2.$columnReceiverId = ? AND m2.$columnSenderId = latest.other_user_id)
          )
          AND m2.$columnCreatedAt = latest.max_time
          AND (
            m2.$columnMessageType = 'deleted'
            OR
            LENGTH(TRIM(COALESCE(m2.$columnMessage, ''))) > 0
            OR LENGTH(TRIM(COALESCE(m2.$columnFileUrl, ''))) > 0
            OR LENGTH(TRIM(COALESCE(m2.$columnMimeType, ''))) > 0
            OR LENGTH(TRIM(COALESCE(m2.$columnFileName, ''))) > 0
            OR m2.$columnPageCount IS NOT NULL
            OR m2.$columnFileSize IS NOT NULL
          )
          ORDER BY m2.$columnUpdatedAt DESC, m2.$columnId DESC
          LIMIT 1
        )
        ORDER BY m.$columnCreatedAt DESC
      ''',
        [
          currentUserId,
          currentUserId,
          currentUserId,
          currentUserId,
          currentUserId,
          currentUserId,
          currentUserId,
        ],
      );

      if (_verboseDbLogs && kDebugMode) {
        debugPrint('📖 Retrieved ${results.length} latest messages');
      }
      return results;
    } catch (e) {
      debugPrint('❌ Error getting latest messages: $e');
      rethrow;
    }
  }

  /// Check if current user has sent at least one message to another user
  /// Used to filter chat list - only show conversations where user has sent a message
  Future<bool> hasUserSentMessage({
    required String currentUserId,
    required String otherUserId,
  }) async {
    final db = await _database;

    try {
      // Check if there are ANY messages in this conversation
      // (either sent by current user OR received from other user)
      // This ensures chat list shows conversations with real message activity
      final result = await db.rawQuery(
        '''
        SELECT COUNT(*) as count
        FROM $tableName
        WHERE ($columnSenderId = ? AND $columnReceiverId = ?)
           OR ($columnSenderId = ? AND $columnReceiverId = ?)
        LIMIT 1
      ''',
        [currentUserId, otherUserId, otherUserId, currentUserId],
      );

      final count = Sqflite.firstIntValue(result) ?? 0;
      return count > 0;
    } catch (e) {
      debugPrint('❌ Error checking if user sent message: $e');
      return false;
    }
  }

  /// Get messages by status (for offline recovery)
  /// Used to load pending messages that need to be sent when connection is restored
  Future<List<Map<String, dynamic>>> getMessagesByStatus({
    required String currentUserId,
    required String status,
  }) async {
    final db = await _database;

    try {
      final results = await db.query(
        tableName,
        where: '$columnSenderId = ? AND $columnMessageStatus = ?',
        whereArgs: [currentUserId, status],
        orderBy: '$columnCreatedAt ASC',
      );

      if (_verboseDbLogs && kDebugMode) {
        debugPrint(
          '📋 Retrieved ${results.length} messages with status: $status',
        );
      }
      return results;
    } catch (e) {
      debugPrint('❌ Error getting messages by status: $e');
      rethrow;
    }
  }

  // --------------------------------------------------------------------------
  // UPDATE OPERATIONS
  // --------------------------------------------------------------------------

  /// Update message status (sent -> delivered -> read)
  Future<void> updateMessageStatus({
    required String messageId,
    required String status,
    DateTime? deliveredAt,
    DateTime? readAt,
    DateTime? updatedAt,
    String? receiverDeliveryChannel,
  }) async {
    final db = await _database;

    try {
      final updateData = <String, dynamic>{
        columnMessageStatus: status,
        columnUpdatedAt: (updatedAt ?? DateTime.now()).millisecondsSinceEpoch,
      };

      if (status == 'delivered' && deliveredAt != null) {
        updateData[columnDeliveredAt] = deliveredAt.millisecondsSinceEpoch;
      }

      if (status == 'read' && readAt != null) {
        updateData[columnReadAt] = readAt.millisecondsSinceEpoch;
        updateData[columnIsRead] = 1;
      }

      if (receiverDeliveryChannel != null) {
        updateData[columnReceiverDeliveryChannel] = receiverDeliveryChannel;
      }

      await db.update(
        tableName,
        updateData,
        where: '$columnId = ?',
        whereArgs: [messageId],
      );

      if (_verboseDbLogs && kDebugMode) {
        debugPrint('✅ Message status updated: $messageId -> $status');
      }
    } catch (e) {
      debugPrint('❌ Error updating message status: $e');
      rethrow;
    }
  }

  Future<void> updateThumbnailUrl({
    required String messageId,
    required String thumbnailUrl,
    DateTime? updatedAt,
  }) async {
    final db = await _database;

    try {
      await db.update(
        tableName,
        {
          columnThumbnailUrl: thumbnailUrl,
          columnUpdatedAt: (updatedAt ?? DateTime.now()).millisecondsSinceEpoch,
        },
        where: '$columnId = ?',
        whereArgs: [messageId],
      );
    } catch (e) {
      debugPrint('❌ Error updating thumbnailUrl: $e');
      rethrow;
    }
  }

  Future<void> updateMessageEdit({
    required String messageId,
    required String newMessage,
    DateTime? editedAt,
  }) async {
    final db = await _database;

    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final editedAtMs = (editedAt ?? DateTime.now()).millisecondsSinceEpoch;

      await db.update(
        tableName,
        {
          columnMessage: newMessage,
          columnIsEdited: 1,
          columnEditedAt: editedAtMs,
          columnUpdatedAt: now,
        },
        where: '$columnId = ?',
        whereArgs: [messageId],
      );
    } catch (e) {
      debugPrint('❌ Error updating message edit: $e');
      rethrow;
    }
  }

  Future<void> updateMessageReactions({
    required String messageId,
    required String reactionsJson,
    DateTime? updatedAt,
  }) async {
    final db = await _database;

    try {
      final updateData = <String, dynamic>{
        columnReactionsJson: reactionsJson,
        columnUpdatedAt: (updatedAt ?? DateTime.now()).millisecondsSinceEpoch,
      };

      await db.update(
        tableName,
        updateData,
        where: '$columnId = ?',
        whereArgs: [messageId],
      );
    } catch (e) {
      debugPrint('❌ Error updating message reactions: $e');
      rethrow;
    }
  }

  Future<void> updateMessageStarred({
    required String messageId,
    required bool isStarred,
    DateTime? updatedAt,
  }) async {
    final db = await _database;

    try {
      final updateData = <String, dynamic>{
        columnIsStarred: isStarred ? 1 : 0,
        columnUpdatedAt: (updatedAt ?? DateTime.now()).millisecondsSinceEpoch,
      };

      await db.update(
        tableName,
        updateData,
        where: '$columnId = ?',
        whereArgs: [messageId],
      );
    } catch (e) {
      debugPrint('❌ Error updating message star status: $e');
      rethrow;
    }
  }

  /// WHATSAPP-STYLE: Get unread message IDs in ONE SQL query
  /// Much faster than loading all messages and filtering in Dart
  Future<List<String>> getUnreadMessageIds({
    required String currentUserId,
    required String otherUserId,
  }) async {
    final db = await _database;

    try {
      // Direct SQL query - O(1) vs O(n) filtering
      final results = await db.query(
        tableName,
        columns: [columnId],
        where:
            '''
          $columnReceiverId = ? AND
          $columnSenderId = ? AND
          ($columnIsRead = 0 OR $columnMessageStatus != 'read')
        ''',
        whereArgs: [currentUserId, otherUserId],
      );

      return results.map((r) => r[columnId] as String).toList();
    } catch (e) {
      debugPrint('❌ Error getting unread message IDs: $e');
      return [];
    }
  }

  Future<List<String>> getRecentIncomingMessageIds({
    required String currentUserId,
    required String otherUserId,
    int limit = 100,
  }) async {
    final db = await _database;

    try {
      final results = await db.query(
        tableName,
        columns: [columnId],
        where: '$columnReceiverId = ? AND $columnSenderId = ?',
        whereArgs: [currentUserId, otherUserId],
        orderBy: '$columnCreatedAt DESC',
        limit: limit,
      );

      return results.map((r) => r[columnId] as String).toList();
    } catch (e) {
      debugPrint('❌ Error getting recent incoming message IDs: $e');
      return [];
    }
  }

  /// WHATSAPP-STYLE: Mark messages as read in ONE SQL statement
  /// Uses WHERE IN clause - single DB operation for any number of messages
  Future<void> markMessagesAsRead({required List<String> messageIds}) async {
    if (messageIds.isEmpty) return;

    final db = await _database;

    try {
      final now = DateTime.now().millisecondsSinceEpoch;

      // Single UPDATE with WHERE IN - O(1) instead of O(n) batch operations
      final placeholders = List.filled(messageIds.length, '?').join(',');
      await db.rawUpdate('''
        UPDATE $tableName
        SET $columnMessageStatus = 'read',
            $columnIsRead = 1,
            $columnReadAt = $now,
            $columnUpdatedAt = $now
        WHERE $columnId IN ($placeholders)
        ''', messageIds);

      debugPrint(
        '⚡ ${messageIds.length} messages marked as read (single query)',
      );
    } catch (e) {
      debugPrint('❌ Error marking messages as read: $e');
      rethrow;
    }
  }

  Future<void> markConversationAsRead({
    required String currentUserId,
    required String otherUserId,
  }) async {
    final db = await _database;

    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.rawUpdate(
        '''
        UPDATE $tableName
        SET $columnMessageStatus = 'read',
            $columnIsRead = 1,
            $columnReadAt = $now,
            $columnUpdatedAt = $now
        WHERE $columnReceiverId = ?
          AND $columnSenderId = ?
          AND ($columnIsRead = 0 OR $columnMessageStatus != 'read')
        ''',
        [currentUserId, otherUserId],
      );
    } catch (e) {
      debugPrint('❌ Error marking conversation as read: $e');
      rethrow;
    }
  }

  /// Mark multiple messages as delivered
  Future<void> markMessagesAsDelivered({
    required List<String> messageIds,
  }) async {
    final db = await _database;
    final batch = db.batch();

    try {
      final now = DateTime.now().millisecondsSinceEpoch;

      for (final messageId in messageIds) {
        batch.update(
          tableName,
          {
            columnMessageStatus: 'delivered',
            columnDeliveredAt: now,
            columnUpdatedAt: now,
          },
          where: '$columnId = ?',
          whereArgs: [messageId],
        );
      }

      await batch.commit(noResult: true);
      debugPrint('✅ ${messageIds.length} messages marked as delivered');
    } catch (e) {
      debugPrint('❌ Error marking messages as delivered: $e');
      rethrow;
    }
  }

  // --------------------------------------------------------------------------
  // DELETE OPERATIONS
  // --------------------------------------------------------------------------

  /// Delete a single message
  /// [isIdReplacement] - set true when deleting local message during local→server ID swap
  Future<void> deleteMessage(
    String messageId, {
    bool isIdReplacement = false,
  }) async {
    final db = await _database;

    try {
      await db.delete(
        tableName,
        where: '$columnId = ?',
        whereArgs: [messageId],
      );

      if (_verboseDbLogs && kDebugMode) {
        if (isIdReplacement) {
          debugPrint(
            '🔄 DB: Removed local message (ID replacement): $messageId',
          );
        } else {
          debugPrint('🗑️ DB: Message deleted: $messageId');
        }
      }
    } catch (e) {
      debugPrint('❌ Error deleting message: $e');
      rethrow;
    }
  }

  Future<void> markMessageAsDeleted({
    required String messageId,
    DateTime? deletedAt,
  }) async {
    final db = await _database;

    try {
      final ts = (deletedAt ?? DateTime.now()).millisecondsSinceEpoch;
      await db.update(
        tableName,
        {
          columnMessageType: 'deleted',
          columnMessage: '',
          columnFileUrl: null,
          columnMimeType: null,
          columnFileName: null,
          columnPageCount: null,
          columnFileSize: null,
          columnCachedFilePath: null,
          columnReactionsJson: null,
          columnIsEdited: 0,
          columnEditedAt: null,
          columnUpdatedAt: ts,
        },
        where: '$columnId = ?',
        whereArgs: [messageId],
      );
    } catch (e) {
      debugPrint('❌ Error marking message deleted: $e');
      rethrow;
    }
  }

  Future<void> deleteMessages(List<String> messageIds) async {
    if (messageIds.isEmpty) return;
    final db = await _database;

    try {
      final ids = messageIds.where((id) => id.trim().isNotEmpty).toList();
      if (ids.isEmpty) return;

      final placeholders = List.filled(ids.length, '?').join(',');
      await db.delete(
        tableName,
        where: '$columnId IN ($placeholders)',
        whereArgs: ids,
      );
    } catch (e) {
      debugPrint('❌ Error deleting messages: $e');
      rethrow;
    }
  }

  /// Delete all messages in a conversation
  Future<void> deleteConversation({
    required String currentUserId,
    required String otherUserId,
  }) async {
    final db = await _database;

    try {
      await db.delete(
        tableName,
        where:
            '''
          ($columnSenderId = ? AND $columnReceiverId = ?)
          OR
          ($columnSenderId = ? AND $columnReceiverId = ?)
        ''',
        whereArgs: [currentUserId, otherUserId, otherUserId, currentUserId],
      );

      debugPrint(
        '🗑️ Conversation deleted between $currentUserId and $otherUserId',
      );
    } catch (e) {
      debugPrint('❌ Error deleting conversation: $e');
      rethrow;
    }
  }

  /// Delete all messages
  Future<void> deleteAllMessages() async {
    final db = await _database;

    try {
      await db.delete(tableName);
      debugPrint('🗑️ All messages deleted');
    } catch (e) {
      debugPrint('❌ Error deleting all messages: $e');
      rethrow;
    }
  }

  // --------------------------------------------------------------------------
  // SEARCH OPERATIONS
  // --------------------------------------------------------------------------

  /// Search messages by content
  Future<List<Map<String, dynamic>>> searchMessages({
    required String query,
    required String currentUserId,
    String? otherUserId,
  }) async {
    final db = await _database;

    try {
      String whereClause =
          '''
        ($columnSenderId = ? OR $columnReceiverId = ?)
        AND $columnMessage LIKE ?
      ''';

      List<dynamic> whereArgs = [currentUserId, currentUserId, '%$query%'];

      if (otherUserId != null) {
        whereClause +=
            '''
          AND (
            ($columnSenderId = ? AND $columnReceiverId = ?)
            OR
            ($columnSenderId = ? AND $columnReceiverId = ?)
          )
        ''';
        whereArgs.addAll([
          currentUserId,
          otherUserId,
          otherUserId,
          currentUserId,
        ]);
      }

      final results = await db.query(
        tableName,
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: '$columnCreatedAt DESC',
        limit: 100,
      );

      debugPrint('🔍 Found ${results.length} messages matching "$query"');
      return results;
    } catch (e) {
      debugPrint('❌ Error searching messages: $e');
      rethrow;
    }
  }

  /// Reset is_follow_up flag for messages matching the follow-up text and timestamp
  /// Used when a follow-up entry is deleted from Connection Insight Hub
  Future<bool> resetFollowUpFlag({
    required String currentUserId,
    required String contactId,
    required String followUpText,
    required DateTime createdAt,
  }) async {
    final db = await _database;

    try {
      // Find messages matching the follow-up text within time window
      // Message could have prefix (local) OR clean text (after server sync)
      final followUpPrefix = 'Follow up Text:';
      final textWithPrefix = '$followUpPrefix $followUpText';

      // Search within a 5-minute window around the createdAt time
      final startTime = createdAt.subtract(const Duration(minutes: 5));
      final endTime = createdAt.add(const Duration(minutes: 5));

      final updatedRows = await db.update(
        tableName,
        {columnIsFollowUp: 0},
        where:
            '''
          (($columnSenderId = ? AND $columnReceiverId = ?) OR
           ($columnSenderId = ? AND $columnReceiverId = ?)) AND
          ($columnMessage LIKE ? OR $columnMessage LIKE ?) AND
          $columnCreatedAt BETWEEN ? AND ? AND
          $columnIsFollowUp = 1
        ''',
        whereArgs: [
          currentUserId, contactId,
          contactId, currentUserId,
          '%$textWithPrefix%', // Match with prefix
          '%$followUpText%', // Match clean text (after server sync)
          startTime.millisecondsSinceEpoch,
          endTime.millisecondsSinceEpoch,
        ],
      );

      if (_verboseDbLogs && kDebugMode) {
        debugPrint(
          '✅ MessagesTable reset is_follow_up for $updatedRows messages',
        );
      }

      return updatedRows > 0;
    } catch (e) {
      debugPrint('❌ Error resetting follow-up flag: $e');
      return false;
    }
  }
}
