import 'package:flutter/foundation.dart';
import 'package:chataway_plus/core/database/tables/chat/messages_table.dart';
import 'package:chataway_plus/features/chat/models/chat_message_model.dart';

import 'dart:convert';

/// Messages Local Database Service
/// Handles local database operations for chat messages
class MessagesLocalDatabaseService {
  static final MessagesLocalDatabaseService _instance =
      MessagesLocalDatabaseService._internal();
  factory MessagesLocalDatabaseService() => _instance;
  static MessagesLocalDatabaseService get instance => _instance;
  MessagesLocalDatabaseService._internal();

  static const bool _verboseLogs = false;

  bool _looksLikeContactJson(String raw) {
    final t = raw.trim();
    if (!t.startsWith('{') || !t.endsWith('}')) return false;
    try {
      final decoded = jsonDecode(t);
      if (decoded is! Map) return false;
      final map = Map<String, dynamic>.from(decoded);
      final hasName =
          map.containsKey('name') ||
          map.containsKey('contact_name') ||
          map.containsKey('contactName');
      final hasPhone =
          map.containsKey('phone') ||
          map.containsKey('contact_mobile_number') ||
          map.containsKey('mobile');
      return hasName && hasPhone;
    } catch (_) {
      return false;
    }
  }

  bool _looksLikeLocationJson(String raw) {
    final t = raw.trim();
    if (!t.startsWith('{') || !t.endsWith('}')) return false;
    try {
      final decoded = jsonDecode(t);
      if (decoded is! Map) return false;
      final map = Map<String, dynamic>.from(decoded);
      final hasLat = map.containsKey('latitude') || map.containsKey('lat');
      final hasLng =
          map.containsKey('longitude') ||
          map.containsKey('lng') ||
          map.containsKey('lon');
      if (!hasLat || !hasLng) return false;
      final latRaw = map['latitude'] ?? map['lat'];
      final lngRaw = map['longitude'] ?? map['lng'] ?? map['lon'];
      final lat = double.tryParse(latRaw?.toString() ?? '');
      final lng = double.tryParse(lngRaw?.toString() ?? '');
      return lat != null && lng != null;
    } catch (_) {
      return false;
    }
  }

  String _normalizeLocationJsonString(String raw) {
    final t = raw.trim();
    try {
      final decoded = jsonDecode(t);
      if (decoded is! Map) return raw;
      final map = Map<String, dynamic>.from(decoded);
      final latRaw = map['latitude'] ?? map['lat'];
      final lngRaw = map['longitude'] ?? map['lng'] ?? map['lon'];
      final lat = double.tryParse(latRaw?.toString() ?? '');
      final lng = double.tryParse(lngRaw?.toString() ?? '');
      if (lat == null || lng == null) return raw;
      final normalized = <String, dynamic>{
        'latitude': lat,
        'longitude': lng,
        'address': map['address']?.toString(),
        'placeName': map['placeName']?.toString(),
        'timestamp': map['timestamp']?.toString(),
      };
      normalized.removeWhere(
        (_, v) => v == null || v.toString().trim().isEmpty,
      );
      return jsonEncode(normalized);
    } catch (_) {
      return raw;
    }
  }

  String _normalizeContactJsonString(String raw) {
    final t = raw.trim();
    try {
      final decoded = jsonDecode(t);
      if (decoded is! Map) return raw;
      final map = Map<String, dynamic>.from(decoded);
      final normalized = <String, dynamic>{
        'name':
            map['name']?.toString() ??
            map['contact_name']?.toString() ??
            map['contactName']?.toString() ??
            'Unknown',
        'phone':
            map['phone']?.toString() ??
            map['contact_mobile_number']?.toString() ??
            map['mobile']?.toString() ??
            '',
      };
      return jsonEncode(normalized);
    } catch (_) {
      return raw;
    }
  }

  final MessagesTable _messagesTable = MessagesTable.instance;
  bool _isInitialized = false;

  final Map<String, Future<List<ChatMessageModel>>>
  _inflightConversationHistoryLoads = {};

  String _toDbMessageType(ChatMessageModel message) {
    if (message.messageType == MessageType.deleted) {
      return 'deleted';
    }
    final name = message.fileName;
    final mt = message.mimeType;
    if (mt == 'application/pdf' ||
        message.pageCount != null ||
        (name != null && name.toLowerCase().endsWith('.pdf'))) {
      return 'pdf';
    }
    return message.messageType.name;
  }

  /// Initialize database
  Future<void> initializeDatabase() async {
    if (_isInitialized) {
      if (_verboseLogs && kDebugMode) {
        debugPrint('💾 ChatLocalStorage: Already initialized');
      }
      return;
    }

    try {
      // Database is initialized automatically via AppDatabaseManager
      _isInitialized = true;
      if (_verboseLogs && kDebugMode) {
        debugPrint('✅ ChatLocalStorage: Initialized successfully');
      }
    } catch (e) {
      debugPrint('❌ ChatLocalStorage: Failed to initialize: $e');
      rethrow;
    }
  }

  Future<void> updateThumbnailUrl({
    required String messageId,
    required String thumbnailUrl,
    DateTime? updatedAt,
  }) async {
    try {
      await _messagesTable.updateThumbnailUrl(
        messageId: messageId,
        thumbnailUrl: thumbnailUrl,
        updatedAt: updatedAt,
      );
    } catch (e) {
      debugPrint('❌ ChatLocalStorage: Error updating thumbnailUrl: $e');
      rethrow;
    }
  }

  /// Save message to local database
  Future<void> saveMessage({
    required ChatMessageModel message,
    required String currentUserId,
    required String otherUserId,
  }) async {
    try {
      final normalizedStatus = ChatMessageModel.normalizeMessageStatus(
        message.messageStatus,
        isRead: message.isRead,
      );

      // Resolve reply message data for persistence
      String? replyText = message.replyToMessage?.message;
      String? replySenderId = message.replyToMessage?.senderId;
      String? replyType = message.replyToMessage?.messageType.name;

      // If replyToMessageId is set but reply data is missing, look up from DB
      if (message.replyToMessageId != null &&
          message.replyToMessageId!.isNotEmpty &&
          replyText == null) {
        try {
          final replyRow = await _messagesTable.getMessageById(
            message.replyToMessageId!,
          );
          if (replyRow != null) {
            replyText = replyRow[MessagesTable.columnMessage] as String?;
            replySenderId = replyRow[MessagesTable.columnSenderId] as String?;
            replyType = replyRow[MessagesTable.columnMessageType] as String?;
          }
        } catch (_) {}
      }

      await _messagesTable.insertOrUpdateMessage({
        MessagesTable.columnId: message.id,
        MessagesTable.columnSenderId: message.senderId,
        MessagesTable.columnReceiverId: message.receiverId,
        MessagesTable.columnMessage: message.message,
        MessagesTable.columnReactionsJson: message.reactionsJson,
        MessagesTable.columnIsStarred: message.isStarred ? 1 : 0,
        MessagesTable.columnIsEdited: message.isEdited ? 1 : 0,
        MessagesTable.columnEditedAt: message.editedAt?.millisecondsSinceEpoch,
        MessagesTable.columnMessageType: _toDbMessageType(message),
        MessagesTable.columnFileUrl: message.imageUrl,
        MessagesTable.columnMimeType: message.mimeType,
        MessagesTable.columnFileName: message.fileName,
        MessagesTable.columnPageCount: message.pageCount,
        MessagesTable.columnFileSize: message.fileSize,
        MessagesTable.columnCachedFilePath: message.localImagePath,
        MessagesTable.columnThumbnailUrl: message.thumbnailUrl,
        MessagesTable.columnMessageStatus: normalizedStatus,
        MessagesTable.columnIsRead:
            (message.isRead || normalizedStatus == 'read') ? 1 : 0,
        MessagesTable.columnDeliveredAt:
            message.deliveredAt?.millisecondsSinceEpoch,
        MessagesTable.columnReadAt: message.readAt?.millisecondsSinceEpoch,
        MessagesTable.columnCreatedAt: message.createdAt.millisecondsSinceEpoch,
        MessagesTable.columnUpdatedAt: message.updatedAt.millisecondsSinceEpoch,
        MessagesTable.columnDeliveryChannel: message.deliveryChannel,
        MessagesTable.columnReceiverDeliveryChannel:
            message.receiverDeliveryChannel,
        MessagesTable.columnImageWidth: message.imageWidth,
        MessagesTable.columnImageHeight: message.imageHeight,
        MessagesTable.columnAudioDuration: message.audioDuration,
        MessagesTable.columnIsFollowUp: message.isFollowUp ? 1 : 0,
        MessagesTable.columnReplyToMessageId: message.replyToMessageId,
        // Store reply message data directly for persistence
        MessagesTable.columnReplyToMessageText: replyText,
        MessagesTable.columnReplyToMessageSenderId: replySenderId,
        MessagesTable.columnReplyToMessageType: replyType,
      });

      // debugPrint('💾 ChatLocalStorage: Message saved to local DB');
    } catch (e) {
      debugPrint('❌ ChatLocalStorage: Error saving message: $e');
      rethrow;
    }
  }

  /// Save incoming message to local database
  Future<void> receiveMessage({
    required ChatMessageModel incomingMessage,
    required String currentUserId,
  }) async {
    try {
      await saveMessage(
        message: incomingMessage,
        currentUserId: currentUserId,
        otherUserId: incomingMessage.senderId,
      );

      if (_verboseLogs && kDebugMode) {
        debugPrint('📥 ChatLocalStorage: Incoming message saved');
      }
    } catch (e) {
      debugPrint('❌ ChatLocalStorage: Error receiving message: $e');
      rethrow;
    }
  }

  /// Load conversation history from local database
  Future<List<ChatMessageModel>> loadConversationHistory({
    required String currentUserId,
    required String otherUserId,
    int limit = 100,
    int offset = 0,
  }) async {
    final key = '$currentUserId|$otherUserId|$limit|$offset';
    final inflight = _inflightConversationHistoryLoads[key];
    if (inflight != null) {
      return inflight;
    }

    final Future<List<ChatMessageModel>> future = () async {
      try {
        final page = (offset ~/ limit) + 1;
        final rawMessages = await _messagesTable.getChatHistory(
          currentUserId: currentUserId,
          otherUserId: otherUserId,
          page: page,
          limit: limit,
        );

        final messages = rawMessages.map((raw) {
          final messageTypeRaw =
              raw[MessagesTable.columnMessageType] as String?;
          final rawMessage = raw[MessagesTable.columnMessage] as String;

          var parsedType = ChatMessageModel.parseMessageType(messageTypeRaw);
          var parsedMessage = rawMessage;

          // Legacy fix: some contact messages were stored as 'text' with JSON body.
          // Detect them and render as contact bubbles.
          if (parsedType == MessageType.text &&
              _looksLikeContactJson(rawMessage)) {
            parsedType = MessageType.contact;
            parsedMessage = _normalizeContactJsonString(rawMessage);
          }

          // Legacy fix: some location messages might be stored as 'text' with JSON body.
          if (parsedType == MessageType.text &&
              _looksLikeLocationJson(rawMessage)) {
            parsedType = MessageType.location;
            parsedMessage = _normalizeLocationJsonString(rawMessage);
          }

          final rawStatus =
              raw[MessagesTable.columnMessageStatus] as String? ?? 'sent';
          final isRead = (raw[MessagesTable.columnIsRead] as int? ?? 0) == 1;
          final normalizedStatus = ChatMessageModel.normalizeMessageStatus(
            rawStatus,
            isRead: isRead,
          );
          return ChatMessageModel(
            id: raw[MessagesTable.columnId] as String,
            senderId: raw[MessagesTable.columnSenderId] as String,
            receiverId: raw[MessagesTable.columnReceiverId] as String,
            message: parsedMessage,
            reactionsJson: raw.containsKey(MessagesTable.columnReactionsJson)
                ? raw[MessagesTable.columnReactionsJson] as String?
                : null,
            isStarred: (raw[MessagesTable.columnIsStarred] as int? ?? 0) == 1,
            isEdited: (raw[MessagesTable.columnIsEdited] as int? ?? 0) == 1,
            editedAt: raw[MessagesTable.columnEditedAt] != null
                ? DateTime.fromMillisecondsSinceEpoch(
                    raw[MessagesTable.columnEditedAt] as int,
                  )
                : null,
            messageType: parsedType,
            imageUrl: raw[MessagesTable.columnFileUrl] as String?,
            localImagePath: raw[MessagesTable.columnCachedFilePath] as String?,
            mimeType: raw[MessagesTable.columnMimeType] as String?,
            fileName: raw[MessagesTable.columnFileName] as String?,
            pageCount: raw[MessagesTable.columnPageCount] as int?,
            fileSize: raw[MessagesTable.columnFileSize] as int?,
            messageStatus: normalizedStatus,
            isRead: isRead || normalizedStatus == 'read',
            deliveredAt: raw[MessagesTable.columnDeliveredAt] != null
                ? DateTime.fromMillisecondsSinceEpoch(
                    raw[MessagesTable.columnDeliveredAt] as int,
                  )
                : null,
            readAt: raw[MessagesTable.columnReadAt] != null
                ? DateTime.fromMillisecondsSinceEpoch(
                    raw[MessagesTable.columnReadAt] as int,
                  )
                : null,
            createdAt: DateTime.fromMillisecondsSinceEpoch(
              raw[MessagesTable.columnCreatedAt] as int,
            ),
            updatedAt: DateTime.fromMillisecondsSinceEpoch(
              raw[MessagesTable.columnUpdatedAt] as int,
            ),
            deliveryChannel:
                (raw[MessagesTable.columnDeliveryChannel] as String?) ??
                'socket',
            receiverDeliveryChannel:
                raw[MessagesTable.columnReceiverDeliveryChannel] as String?,
            imageWidth: raw[MessagesTable.columnImageWidth] as int?,
            imageHeight: raw[MessagesTable.columnImageHeight] as int?,
            audioDuration: raw.containsKey(MessagesTable.columnAudioDuration)
                ? (raw[MessagesTable.columnAudioDuration] as num?)?.toDouble()
                : null,
            isFollowUp: (raw[MessagesTable.columnIsFollowUp] as int? ?? 0) == 1,
            thumbnailUrl: raw[MessagesTable.columnThumbnailUrl] as String?,
            replyToMessageId:
                raw[MessagesTable.columnReplyToMessageId] as String?,
            // Build replyToMessage from stored data if available
            replyToMessage: _buildReplyToMessageFromRaw(raw),
          );
        }).toList();

        // Fetch replied-to messages and attach them (for messages that don't have stored reply data)
        final messagesWithReplies = await _attachReplyToMessages(messages);

        // Messages are returned in DESC order, reverse for ascending (oldest first)
        return messagesWithReplies.reversed.toList();
      } catch (e) {
        debugPrint('❌ ChatLocalStorage: Error loading conversation: $e');
        return <ChatMessageModel>[];
      }
    }();

    _inflightConversationHistoryLoads[key] = future;
    try {
      return await future;
    } finally {
      _inflightConversationHistoryLoads.remove(key);
    }
  }

  /// Update message status
  Future<void> updateMessageStatus({
    required String messageId,
    required String newStatus,
    DateTime? deliveredAt,
    DateTime? readAt,
    DateTime? updatedAt,
    String? receiverDeliveryChannel,
  }) async {
    try {
      final normalizedStatus = ChatMessageModel.normalizeMessageStatus(
        newStatus,
      );
      await _messagesTable.updateMessageStatus(
        messageId: messageId,
        status: normalizedStatus,
        deliveredAt:
            deliveredAt ??
            (normalizedStatus == 'delivered' ? DateTime.now() : null),
        readAt: readAt ?? (normalizedStatus == 'read' ? DateTime.now() : null),
        updatedAt: updatedAt,
        receiverDeliveryChannel: receiverDeliveryChannel,
      );
      if (_verboseLogs && kDebugMode) {
        debugPrint(
          '💾 ChatLocalStorage: Message status updated to: $normalizedStatus',
        );
      }
    } catch (e) {
      debugPrint('❌ ChatLocalStorage: Error updating message status: $e');
      rethrow;
    }
  }

  /// Get unread message count for a conversation
  Future<int> getUnreadCount({
    required String currentUserId,
    required String otherUserId,
  }) async {
    try {
      return await _messagesTable.getUnreadCount(
        currentUserId: currentUserId,
        otherUserId: otherUserId,
      );
    } catch (e) {
      debugPrint('❌ ChatLocalStorage: Error getting unread count: $e');
      return 0;
    }
  }

  /// Replace local message ID with server ID (WhatsApp approach)
  /// Instead of creating duplicate, update existing message with server ID
  Future<void> replaceLocalIdWithServerId({
    required String localMessageId,
    required ChatMessageModel serverMessage,
  }) async {
    try {
      if (_verboseLogs && kDebugMode) {
        debugPrint('🔄 ChatLocalStorage: Replacing local ID with server ID');
        debugPrint('   Local: $localMessageId → Server: ${serverMessage.id}');
      }

      int statusPriority(String status) {
        return ChatMessageModel.messageStatusPriority(status);
      }

      final localData = await _messagesTable.getMessageById(localMessageId);

      var finalStatus = ChatMessageModel.normalizeMessageStatus(
        serverMessage.messageStatus,
        isRead: serverMessage.isRead,
      );
      var finalIsRead = serverMessage.isRead || finalStatus == 'read';
      DateTime? finalDeliveredAt = serverMessage.deliveredAt;
      DateTime? finalReadAt = serverMessage.readAt;

      var finalIsFollowUp = serverMessage.isFollowUp;

      if (localData != null) {
        final localStatus =
            (localData[MessagesTable.columnMessageStatus] as String?) ?? '';
        final normalizedLocalStatus = ChatMessageModel.normalizeMessageStatus(
          localStatus,
          isRead: (localData[MessagesTable.columnIsRead] as int? ?? 0) == 1,
        );
        final localDeliveredMs =
            localData[MessagesTable.columnDeliveredAt] as int?;
        final localReadMs = localData[MessagesTable.columnReadAt] as int?;
        final localDeliveredAt = localDeliveredMs != null
            ? DateTime.fromMillisecondsSinceEpoch(localDeliveredMs)
            : null;
        final localReadAt = localReadMs != null
            ? DateTime.fromMillisecondsSinceEpoch(localReadMs)
            : null;

        final localP = statusPriority(normalizedLocalStatus);
        final serverP = statusPriority(finalStatus);
        if (localP > serverP) {
          finalStatus = normalizedLocalStatus;
          finalIsRead =
              (localData[MessagesTable.columnIsRead] as int? ?? 0) == 1;
          finalDeliveredAt = localDeliveredAt ?? finalDeliveredAt;
          finalReadAt = localReadAt ?? finalReadAt;
        } else {
          finalDeliveredAt ??= localDeliveredAt;
          finalReadAt ??= localReadAt;
          finalIsRead =
              finalIsRead ||
              ((localData[MessagesTable.columnIsRead] as int? ?? 0) == 1);
        }

        final localIsFollowUp =
            (localData[MessagesTable.columnIsFollowUp] as int? ?? 0) == 1;
        if (localIsFollowUp && !finalIsFollowUp) {
          finalIsFollowUp = true;
        }
      }

      // PRESERVE DIMENSIONS: Keep imageWidth/Height from local if server misses them
      int? finalWidth = serverMessage.imageWidth;
      int? finalHeight = serverMessage.imageHeight;

      if (kDebugMode) {
        debugPrint(
          '🔍 Dimension check: isImage=${serverMessage.isImageMessage}, w=$finalWidth, h=$finalHeight',
        );
      }

      if (serverMessage.isImageMessage &&
          (finalWidth == null || finalHeight == null)) {
        try {
          if (localData != null) {
            final localWidth =
                localData[MessagesTable.columnImageWidth] as int?;
            final localHeight =
                localData[MessagesTable.columnImageHeight] as int?;

            finalWidth ??= localWidth;
            finalHeight ??= localHeight;

            if (kDebugMode) {
              debugPrint(
                '📐 Preserved local dimensions: ${finalWidth}x$finalHeight',
              );
            }
          }
        } catch (e) {
          debugPrint('⚠️ Error preserving dimensions: $e');
        }
      }

      // PRESERVE AUDIO DURATION: Keep local audioDuration if server doesn't return it
      double? finalAudioDuration = serverMessage.audioDuration;
      if (finalAudioDuration == null && localData != null) {
        final localAudioDuration =
            localData.containsKey(MessagesTable.columnAudioDuration)
            ? (localData[MessagesTable.columnAudioDuration] as num?)?.toDouble()
            : null;
        if (localAudioDuration != null) {
          finalAudioDuration = localAudioDuration;
          if (kDebugMode) {
            debugPrint('🎤 Preserved local audioDuration: $localAudioDuration');
          }
        }
      }

      // PRESERVE MESSAGE CONTENT: For poll/contact types, keep local message if server's is empty
      String finalMessage = serverMessage.message;
      String finalMessageType = _toDbMessageType(serverMessage);

      // PRESERVE CACHED FILE PATH: Keep local file path so sender can open without re-downloading
      String? finalCachedFilePath = serverMessage.localImagePath;

      if (kDebugMode) {
        debugPrint(
          '🔍 ID Replace Debug: serverMsgType=${serverMessage.messageType.name}, '
          'finalType=$finalMessageType, serverMsg="${serverMessage.message.length > 50 ? serverMessage.message.substring(0, 50) : serverMessage.message}..."',
        );
      }

      if (localData != null) {
        final localMessage =
            (localData[MessagesTable.columnMessage] as String?) ?? '';
        final localMessageType =
            (localData[MessagesTable.columnMessageType] as String?) ?? 'text';

        if (kDebugMode) {
          debugPrint(
            '🔍 Local Data: localMsgType=$localMessageType, '
            'localMsg="${localMessage.length > 50 ? localMessage.substring(0, 50) : localMessage}..."',
          );
        }

        // Preserve local message content if server's is empty
        if (finalMessage.isEmpty && localMessage.isNotEmpty) {
          finalMessage = localMessage;
          if (kDebugMode) {
            debugPrint(
              '📝 Preserved local message content for ${serverMessage.messageType.name}',
            );
          }
        }

        // Preserve local messageType if server returned 'text' or 'deleted' but local was specific type
        if ((finalMessageType == 'text' || finalMessageType == 'deleted') &&
            (localMessageType == 'poll' || localMessageType == 'contact')) {
          finalMessageType = localMessageType;
          if (kDebugMode) {
            debugPrint(
              '📝 Preserved local messageType: $localMessageType (server sent: ${_toDbMessageType(serverMessage)})',
            );
          }
        }

        // PRESERVE CACHED FILE PATH: Keep local file path so sender can open PDF/document without re-downloading
        final localCachedPath =
            localData[MessagesTable.columnCachedFilePath] as String?;
        if ((finalCachedFilePath == null || finalCachedFilePath.isEmpty) &&
            localCachedPath != null &&
            localCachedPath.isNotEmpty) {
          finalCachedFilePath = localCachedPath;
          if (kDebugMode) {
            debugPrint('📁 Preserved local cached file path: $localCachedPath');
          }
        }
      }

      // PRESERVE REPLY DATA: Keep replyToMessageId and reply message data from local
      String? finalReplyToMessageId = serverMessage.replyToMessageId;
      String? finalReplyToMessageText;
      String? finalReplyToMessageSenderId;
      String? finalReplyToMessageType;

      if (localData != null) {
        finalReplyToMessageId ??=
            localData[MessagesTable.columnReplyToMessageId] as String?;
        finalReplyToMessageText =
            localData[MessagesTable.columnReplyToMessageText] as String?;
        finalReplyToMessageSenderId =
            localData[MessagesTable.columnReplyToMessageSenderId] as String?;
        finalReplyToMessageType =
            localData[MessagesTable.columnReplyToMessageType] as String?;
      }
      // Also use in-memory replyToMessage if available
      finalReplyToMessageText ??= serverMessage.replyToMessage?.message;
      finalReplyToMessageSenderId ??= serverMessage.replyToMessage?.senderId;
      finalReplyToMessageType ??=
          serverMessage.replyToMessage?.messageType.name;

      if (kDebugMode && finalReplyToMessageId != null) {
        final previewText = finalReplyToMessageText ?? '';
        final previewClip = previewText.isEmpty
            ? ''
            : previewText.substring(0, previewText.length.clamp(0, 20));
        debugPrint(
          '💬 Reply data preserved: id=$finalReplyToMessageId, text=$previewClip...',
        );
      }

      // Delete old local message (ID replacement, not actual deletion)
      await _messagesTable.deleteMessage(localMessageId, isIdReplacement: true);

      // PRESERVE THUMBNAIL URL: Keep local thumbnail if server doesn't return one
      String? finalThumbnailUrl = serverMessage.thumbnailUrl;
      if (finalThumbnailUrl == null && localData != null) {
        final localThumbnailUrl =
            localData[MessagesTable.columnThumbnailUrl] as String?;
        if (localThumbnailUrl != null && localThumbnailUrl.isNotEmpty) {
          finalThumbnailUrl = localThumbnailUrl;
          if (kDebugMode) {
            debugPrint('🖼️ Preserved local thumbnailUrl: $localThumbnailUrl');
          }
        }
      }

      // Insert server message (effectively replacing the local one)
      await _messagesTable.insertOrUpdateMessage({
        MessagesTable.columnId: serverMessage.id,
        MessagesTable.columnSenderId: serverMessage.senderId,
        MessagesTable.columnReceiverId: serverMessage.receiverId,
        MessagesTable.columnMessage: finalMessage,
        MessagesTable.columnReactionsJson: serverMessage.reactionsJson,
        MessagesTable.columnIsStarred: serverMessage.isStarred ? 1 : 0,
        MessagesTable.columnIsEdited: serverMessage.isEdited ? 1 : 0,
        MessagesTable.columnEditedAt:
            serverMessage.editedAt?.millisecondsSinceEpoch,
        MessagesTable.columnMessageType: finalMessageType,
        MessagesTable.columnFileUrl: serverMessage.imageUrl,
        MessagesTable.columnMimeType: serverMessage.mimeType,
        MessagesTable.columnFileName: serverMessage.fileName,
        MessagesTable.columnPageCount: serverMessage.pageCount,
        MessagesTable.columnFileSize: serverMessage.fileSize,
        MessagesTable.columnCachedFilePath: finalCachedFilePath,
        MessagesTable.columnImageWidth: finalWidth,
        MessagesTable.columnImageHeight: finalHeight,
        MessagesTable.columnAudioDuration: finalAudioDuration,
        MessagesTable.columnIsFollowUp: finalIsFollowUp ? 1 : 0,
        MessagesTable.columnThumbnailUrl: finalThumbnailUrl,
        MessagesTable.columnMessageStatus: finalStatus,
        MessagesTable.columnIsRead: finalIsRead ? 1 : 0,
        MessagesTable.columnDeliveredAt:
            finalDeliveredAt?.millisecondsSinceEpoch,
        MessagesTable.columnReadAt: finalReadAt?.millisecondsSinceEpoch,
        MessagesTable.columnCreatedAt:
            serverMessage.createdAt.millisecondsSinceEpoch,
        MessagesTable.columnUpdatedAt:
            serverMessage.updatedAt.millisecondsSinceEpoch,
        MessagesTable.columnDeliveryChannel: serverMessage.deliveryChannel,
        MessagesTable.columnReceiverDeliveryChannel:
            serverMessage.receiverDeliveryChannel,
        MessagesTable.columnReplyToMessageId: finalReplyToMessageId,
        MessagesTable.columnReplyToMessageText: finalReplyToMessageText,
        MessagesTable.columnReplyToMessageSenderId: finalReplyToMessageSenderId,
        MessagesTable.columnReplyToMessageType: finalReplyToMessageType,
      });

      if (_verboseLogs && kDebugMode) {
        debugPrint('✅ ChatLocalStorage: Message ID replaced (WhatsApp style)');
      }
    } catch (e) {
      debugPrint('❌ ChatLocalStorage: Error replacing message ID: $e');
      // Fallback: try to save server message anyway
      await _messagesTable.insertOrUpdateMessage({
        MessagesTable.columnId: serverMessage.id,
        MessagesTable.columnSenderId: serverMessage.senderId,
        MessagesTable.columnReceiverId: serverMessage.receiverId,
        MessagesTable.columnMessage: serverMessage.message,
        MessagesTable.columnReactionsJson: serverMessage.reactionsJson,
        MessagesTable.columnIsStarred: serverMessage.isStarred ? 1 : 0,
        MessagesTable.columnIsEdited: serverMessage.isEdited ? 1 : 0,
        MessagesTable.columnEditedAt:
            serverMessage.editedAt?.millisecondsSinceEpoch,
        MessagesTable.columnMessageType: _toDbMessageType(serverMessage),
        MessagesTable.columnFileUrl: serverMessage.imageUrl,
        MessagesTable.columnMimeType: serverMessage.mimeType,
        MessagesTable.columnFileName: serverMessage.fileName,
        MessagesTable.columnPageCount: serverMessage.pageCount,
        MessagesTable.columnFileSize: serverMessage.fileSize,
        MessagesTable.columnCachedFilePath: serverMessage.localImagePath,
        MessagesTable.columnImageWidth: serverMessage.imageWidth,
        MessagesTable.columnImageHeight: serverMessage.imageHeight,
        MessagesTable.columnAudioDuration: serverMessage.audioDuration,
        MessagesTable.columnIsFollowUp: serverMessage.isFollowUp ? 1 : 0,
        MessagesTable.columnMessageStatus: serverMessage.messageStatus,
        MessagesTable.columnIsRead: serverMessage.isRead ? 1 : 0,
        MessagesTable.columnDeliveredAt:
            serverMessage.deliveredAt?.millisecondsSinceEpoch,
        MessagesTable.columnReadAt:
            serverMessage.readAt?.millisecondsSinceEpoch,
        MessagesTable.columnCreatedAt:
            serverMessage.createdAt.millisecondsSinceEpoch,
        MessagesTable.columnUpdatedAt:
            serverMessage.updatedAt.millisecondsSinceEpoch,
        MessagesTable.columnDeliveryChannel: serverMessage.deliveryChannel,
        MessagesTable.columnReceiverDeliveryChannel:
            serverMessage.receiverDeliveryChannel,
        MessagesTable.columnReplyToMessageId: serverMessage.replyToMessageId,
        MessagesTable.columnReplyToMessageText:
            serverMessage.replyToMessage?.message,
        MessagesTable.columnReplyToMessageSenderId:
            serverMessage.replyToMessage?.senderId,
        MessagesTable.columnReplyToMessageType:
            serverMessage.replyToMessage?.messageType.name,
      });
    }
  }

  /// Find local message ID that matches server message
  /// If clientMessageId is provided, it will be used for direct matching (more reliable)
  Future<String?> findLocalMessageId({
    required String messageContent,
    required String senderId,
    required String currentUserId,
    required String otherUserId,
    String? clientMessageId,
  }) async {
    try {
      final allMessages = await loadConversationHistory(
        currentUserId: currentUserId,
        otherUserId: otherUserId,
        limit: 100,
      );

      // PRIORITY 1: If clientMessageId is provided, match by ID directly
      // This is more reliable for contact/poll messages where JSON structure may differ
      if (clientMessageId != null && clientMessageId.isNotEmpty) {
        for (final msg in allMessages.reversed) {
          if (msg.id == clientMessageId) {
            if (_verboseLogs && kDebugMode) {
              debugPrint(
                '🔍 Found matching local message by clientMessageId: ${msg.id}',
              );
            }
            return msg.id;
          }
        }
      }

      // PRIORITY 2: Find most recent matching local message by content
      // Check for both local_ and temp_ prefixes
      for (final msg in allMessages.reversed) {
        final isLocalMessage =
            msg.id.startsWith('local_') || msg.id.startsWith('temp_');
        if (isLocalMessage &&
            msg.message.trim() == messageContent.trim() &&
            msg.senderId == senderId) {
          if (_verboseLogs && kDebugMode) {
            debugPrint('🔍 Found matching local message by content: ${msg.id}');
          }
          return msg.id;
        }
      }

      if (_verboseLogs && kDebugMode) {
        debugPrint('⚠️ No matching local message found');
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error finding local message: $e');
      return null;
    }
  }

  /// Load pending messages (status='pending_sync') for offline recovery
  Future<List<ChatMessageModel>> loadPendingMessages({
    required String currentUserId,
  }) async {
    try {
      final rawMessages = await _messagesTable.getMessagesByStatus(
        currentUserId: currentUserId,
        status: 'pending_sync',
      );

      final pendingMessages = rawMessages.map((raw) {
        final messageTypeRaw = raw[MessagesTable.columnMessageType] as String?;
        return ChatMessageModel(
          id: raw[MessagesTable.columnId] as String,
          senderId: raw[MessagesTable.columnSenderId] as String,
          receiverId: raw[MessagesTable.columnReceiverId] as String,
          message: raw[MessagesTable.columnMessage] as String,
          reactionsJson: raw.containsKey(MessagesTable.columnReactionsJson)
              ? raw[MessagesTable.columnReactionsJson] as String?
              : null,
          isStarred: (raw[MessagesTable.columnIsStarred] as int? ?? 0) == 1,
          isEdited: (raw[MessagesTable.columnIsEdited] as int? ?? 0) == 1,
          editedAt: raw[MessagesTable.columnEditedAt] != null
              ? DateTime.fromMillisecondsSinceEpoch(
                  raw[MessagesTable.columnEditedAt] as int,
                )
              : null,
          messageType: ChatMessageModel.parseMessageType(messageTypeRaw),
          imageUrl: raw[MessagesTable.columnFileUrl] as String?,
          localImagePath: raw[MessagesTable.columnCachedFilePath] as String?,
          mimeType: raw[MessagesTable.columnMimeType] as String?,
          fileName: raw[MessagesTable.columnFileName] as String?,
          pageCount: raw[MessagesTable.columnPageCount] as int?,
          fileSize: raw[MessagesTable.columnFileSize] as int?,
          imageWidth: raw[MessagesTable.columnImageWidth] as int?,
          imageHeight: raw[MessagesTable.columnImageHeight] as int?,
          audioDuration: raw.containsKey(MessagesTable.columnAudioDuration)
              ? (raw[MessagesTable.columnAudioDuration] as num?)?.toDouble()
              : null,
          messageStatus:
              raw[MessagesTable.columnMessageStatus] as String? ??
              'pending_sync',
          isRead: (raw[MessagesTable.columnIsRead] as int? ?? 0) == 1,
          deliveredAt: raw[MessagesTable.columnDeliveredAt] != null
              ? DateTime.fromMillisecondsSinceEpoch(
                  raw[MessagesTable.columnDeliveredAt] as int,
                )
              : null,
          readAt: raw[MessagesTable.columnReadAt] != null
              ? DateTime.fromMillisecondsSinceEpoch(
                  raw[MessagesTable.columnReadAt] as int,
                )
              : null,
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            raw[MessagesTable.columnCreatedAt] as int,
          ),
          updatedAt: DateTime.fromMillisecondsSinceEpoch(
            raw[MessagesTable.columnUpdatedAt] as int,
          ),
          deliveryChannel:
              (raw[MessagesTable.columnDeliveryChannel] as String?) ?? 'socket',
          receiverDeliveryChannel:
              raw[MessagesTable.columnReceiverDeliveryChannel] as String?,
          isFollowUp: (raw[MessagesTable.columnIsFollowUp] as int? ?? 0) == 1,
          thumbnailUrl: raw[MessagesTable.columnThumbnailUrl] as String?,
        );
      }).toList();

      debugPrint(
        '📋 ChatLocalStorage: Loaded ${pendingMessages.length} pending messages from DB',
      );

      return pendingMessages;
    } catch (e) {
      debugPrint('❌ ChatLocalStorage: Error loading pending messages: $e');
      return [];
    }
  }

  Future<List<ChatMessageModel>> loadStuckSendingMessages({
    required String currentUserId,
  }) async {
    try {
      final rawMessages = await _messagesTable.getMessagesByStatus(
        currentUserId: currentUserId,
        status: 'sending',
      );

      final stuckMessages = rawMessages
          .map((raw) {
            final messageTypeRaw =
                raw[MessagesTable.columnMessageType] as String?;
            return ChatMessageModel(
              id: raw[MessagesTable.columnId] as String,
              senderId: raw[MessagesTable.columnSenderId] as String,
              receiverId: raw[MessagesTable.columnReceiverId] as String,
              message: raw[MessagesTable.columnMessage] as String,
              reactionsJson: raw.containsKey(MessagesTable.columnReactionsJson)
                  ? raw[MessagesTable.columnReactionsJson] as String?
                  : null,
              isStarred: (raw[MessagesTable.columnIsStarred] as int? ?? 0) == 1,
              isEdited: (raw[MessagesTable.columnIsEdited] as int? ?? 0) == 1,
              editedAt: raw[MessagesTable.columnEditedAt] != null
                  ? DateTime.fromMillisecondsSinceEpoch(
                      raw[MessagesTable.columnEditedAt] as int,
                    )
                  : null,
              messageType: ChatMessageModel.parseMessageType(messageTypeRaw),
              imageUrl: raw[MessagesTable.columnFileUrl] as String?,
              localImagePath:
                  raw[MessagesTable.columnCachedFilePath] as String?,
              mimeType: raw[MessagesTable.columnMimeType] as String?,
              fileName: raw[MessagesTable.columnFileName] as String?,
              pageCount: raw[MessagesTable.columnPageCount] as int?,
              fileSize: raw[MessagesTable.columnFileSize] as int?,
              imageWidth: raw[MessagesTable.columnImageWidth] as int?,
              imageHeight: raw[MessagesTable.columnImageHeight] as int?,
              audioDuration: raw.containsKey(MessagesTable.columnAudioDuration)
                  ? (raw[MessagesTable.columnAudioDuration] as num?)?.toDouble()
                  : null,
              messageStatus:
                  raw[MessagesTable.columnMessageStatus] as String? ??
                  'sending',
              isRead: (raw[MessagesTable.columnIsRead] as int? ?? 0) == 1,
              deliveredAt: raw[MessagesTable.columnDeliveredAt] != null
                  ? DateTime.fromMillisecondsSinceEpoch(
                      raw[MessagesTable.columnDeliveredAt] as int,
                    )
                  : null,
              readAt: raw[MessagesTable.columnReadAt] != null
                  ? DateTime.fromMillisecondsSinceEpoch(
                      raw[MessagesTable.columnReadAt] as int,
                    )
                  : null,
              createdAt: DateTime.fromMillisecondsSinceEpoch(
                raw[MessagesTable.columnCreatedAt] as int,
              ),
              updatedAt: DateTime.fromMillisecondsSinceEpoch(
                raw[MessagesTable.columnUpdatedAt] as int,
              ),
              deliveryChannel:
                  (raw[MessagesTable.columnDeliveryChannel] as String?) ??
                  'socket',
              receiverDeliveryChannel:
                  raw[MessagesTable.columnReceiverDeliveryChannel] as String?,
              isFollowUp:
                  (raw[MessagesTable.columnIsFollowUp] as int? ?? 0) == 1,
              thumbnailUrl: raw[MessagesTable.columnThumbnailUrl] as String?,
            );
          })
          .where((m) => m.id.startsWith('local_'))
          .toList();

      if (_verboseLogs && kDebugMode) {
        debugPrint(
          '📋 ChatLocalStorage: Loaded ${stuckMessages.length} stuck sending messages from DB',
        );
      }

      return stuckMessages;
    } catch (e) {
      debugPrint(
        '❌ ChatLocalStorage: Error loading stuck sending messages: $e',
      );
      return [];
    }
  }

  Future<void> updateMessageEdit({
    required String messageId,
    required String newMessage,
    DateTime? editedAt,
  }) async {
    try {
      await _messagesTable.updateMessageEdit(
        messageId: messageId,
        newMessage: newMessage,
        editedAt: editedAt,
      );
    } catch (e) {
      debugPrint('❌ ChatLocalStorage: Error updating message edit: $e');
      rethrow;
    }
  }

  /// Clear conversation history
  Future<void> clearConversation({
    required String currentUserId,
    required String otherUserId,
  }) async {
    try {
      await _messagesTable.deleteConversation(
        currentUserId: currentUserId,
        otherUserId: otherUserId,
      );
      debugPrint('🗑️ ChatLocalStorage: Conversation cleared');
    } catch (e) {
      debugPrint('❌ ChatLocalStorage: Error clearing conversation: $e');
      rethrow;
    }
  }

  /// Fetch replied-to messages and attach them to the messages
  /// (only for messages that don't already have replyToMessage from stored data)
  Future<List<ChatMessageModel>> _attachReplyToMessages(
    List<ChatMessageModel> messages,
  ) async {
    // Collect all unique replyToMessageIds that don't already have replyToMessage
    final replyIds = messages
        .where(
          (m) =>
              m.replyToMessageId != null &&
              m.replyToMessageId!.isNotEmpty &&
              m.replyToMessage == null, // Only fetch if not already built
        )
        .map((m) => m.replyToMessageId!)
        .toSet()
        .toList();

    debugPrint(
      '🔍 [_attachReplyToMessages] Found ${replyIds.length} unique replyToMessageIds needing fetch: $replyIds',
    );

    if (replyIds.isEmpty) return messages;

    try {
      // Fetch all replied-to messages in bulk
      final replyRawMessages = await _messagesTable.getMessagesByIds(replyIds);
      debugPrint(
        '🔍 [_attachReplyToMessages] Fetched ${replyRawMessages.length} reply messages from DB',
      );

      // Build a map of id -> ChatMessageModel for quick lookup
      final replyMap = <String, ChatMessageModel>{};
      for (final raw in replyRawMessages) {
        final messageTypeRaw = raw[MessagesTable.columnMessageType] as String?;
        final rawMessage = raw[MessagesTable.columnMessage] as String;
        var parsedType = ChatMessageModel.parseMessageType(messageTypeRaw);
        var parsedMessage = rawMessage;

        if (parsedType == MessageType.text &&
            _looksLikeContactJson(rawMessage)) {
          parsedType = MessageType.contact;
          parsedMessage = _normalizeContactJsonString(rawMessage);
        }

        final id = raw[MessagesTable.columnId] as String;
        replyMap[id] = ChatMessageModel(
          id: id,
          senderId: raw[MessagesTable.columnSenderId] as String,
          receiverId: raw[MessagesTable.columnReceiverId] as String,
          message: parsedMessage,
          messageType: parsedType,
          imageUrl: raw[MessagesTable.columnFileUrl] as String?,
          thumbnailUrl: raw[MessagesTable.columnThumbnailUrl] as String?,
          fileName: raw[MessagesTable.columnFileName] as String?,
          mimeType: raw[MessagesTable.columnMimeType] as String?,
          messageStatus:
              raw[MessagesTable.columnMessageStatus] as String? ?? 'sent',
          isRead: (raw[MessagesTable.columnIsRead] as int? ?? 0) == 1,
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            raw[MessagesTable.columnCreatedAt] as int,
          ),
          updatedAt: DateTime.fromMillisecondsSinceEpoch(
            raw[MessagesTable.columnUpdatedAt] as int,
          ),
        );
      }

      debugPrint(
        '🔍 [_attachReplyToMessages] Built replyMap with ${replyMap.length} entries: ${replyMap.keys.toList()}',
      );

      // Attach replyToMessage to each message that has a replyToMessageId and doesn't already have one
      var attachedCount = 0;
      final result = messages.map((msg) {
        if (msg.replyToMessage != null) {
          return msg; // Already has replyToMessage from stored data
        }
        if (msg.replyToMessageId != null &&
            replyMap.containsKey(msg.replyToMessageId)) {
          attachedCount++;
          return msg.copyWith(replyToMessage: replyMap[msg.replyToMessageId]);
        }
        return msg;
      }).toList();
      debugPrint(
        '🔍 [_attachReplyToMessages] Attached replyToMessage to $attachedCount messages',
      );
      return result;
    } catch (e) {
      debugPrint('❌ ChatLocalStorage: Error attaching reply messages: $e');
      return messages;
    }
  }

  /// Build replyToMessage from stored columns in raw data
  ChatMessageModel? _buildReplyToMessageFromRaw(Map<String, dynamic> raw) {
    final replyToMessageId =
        raw[MessagesTable.columnReplyToMessageId] as String?;
    final replyToMessageText =
        raw[MessagesTable.columnReplyToMessageText] as String?;
    final replyToMessageSenderId =
        raw[MessagesTable.columnReplyToMessageSenderId] as String?;
    final replyToMessageTypeStr =
        raw[MessagesTable.columnReplyToMessageType] as String?;

    // If we have the essential data, construct the replyToMessage
    if (replyToMessageId != null &&
        replyToMessageId.isNotEmpty &&
        replyToMessageText != null &&
        replyToMessageSenderId != null) {
      debugPrint(
        '🔍 [_buildReplyToMessageFromRaw] Building replyToMessage from stored data: id=$replyToMessageId',
      );
      return ChatMessageModel(
        id: replyToMessageId,
        senderId: replyToMessageSenderId,
        receiverId: '', // Not needed for display
        message: replyToMessageText,
        messageType: ChatMessageModel.parseMessageType(replyToMessageTypeStr),
        messageStatus: 'sent', // Not needed for display
        isRead: true,
        createdAt: DateTime.now(), // Not needed for display
        updatedAt: DateTime.now(),
      );
    }
    return null;
  }
}
