// ============================================================================
// CHAT LOCAL DATASOURCE - SQLite Database Operations (LOCAL)
// ============================================================================
//
// 🎯 PURPOSE:
// Handles all LOCAL database operations for chat messages.
// Provides offline support and faster message loading from SQLite.
//
// 💾 LOCAL OPERATIONS:
// • saveMessage() - Save message to SQLite (LOCAL)
// • saveMessages() - Batch save messages to SQLite (LOCAL)
// • getMessages() - Get messages from SQLite (LOCAL)
// • getMessageById() - Get single message from SQLite (LOCAL)
// • updateMessageStatus() - Update status in SQLite (LOCAL)
// • deleteMessage() - Delete from SQLite (LOCAL)
// • getChatContactsFromLocal() - Get contacts from SQLite (LOCAL)
// • saveChatContacts() - Save contacts to SQLite (LOCAL)
// • clearAllChats() - Clear all SQLite data (LOCAL)
//
// ============================================================================

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:chataway_plus/core/database/app_database.dart';
import 'package:chataway_plus/features/chat/utils/chat_helper.dart';
import '../../models/chat_message_model.dart';

/// Local datasource for chat - handles message caching in SQLite database
/// All operations are LOCAL (no network calls)
abstract class ChatLocalDataSource {
  /// Save a message to local database
  Future<void> saveMessage(ChatMessageModel message);

  /// Save multiple messages to local database
  Future<void> saveMessages(List<ChatMessageModel> messages);

  /// Get messages for a specific conversation
  Future<List<ChatMessageModel>> getMessages(
    String otherUserId, {
    int limit = 50,
    int offset = 0,
  });

  /// Get a single message by ID
  Future<ChatMessageModel?> getMessageById(String messageId);

  /// Update message status (sent, delivered, read)
  Future<void> updateMessageStatus(
    String messageId,
    String status, {
    DateTime? deliveredAt,
    DateTime? readAt,
  });

  /// Delete a message from local database
  Future<void> deleteMessage(String messageId);

  /// Clear all messages for a conversation
  Future<void> clearConversation(String otherUserId);

  /// Get unread count from local database
  Future<int> getUnreadCount();

  /// Get chat contacts with last messages from local database
  Future<List<ChatContactModel>> getChatContactsFromLocal();

  /// Save chat contacts from API to local database
  /// This persists both user info (chat_users table) and last messages (messages table)
  Future<void> saveChatContacts(List<ChatContactModel> contacts);

  /// Clear all chat data (logout)
  Future<void> clearAllChats();
}

/// Implementation of [ChatLocalDataSource] using local database
/// TODO: Integrate with your database manager when ready
class ChatLocalDataSourceImpl implements ChatLocalDataSource {
  ChatLocalDataSourceImpl();

  static const bool _verboseLogs = true; // Enable for LOCAL DB debugging

  bool _isDeleteTombstone(ChatMessageModel message) {
    if (message.id.trim().isEmpty) return false;
    if (message.messageType == MessageType.contact ||
        message.messageType == MessageType.poll) {
      return false;
    }
    if (message.message.trim().isNotEmpty) return false;

    final hasFileUrl =
        (message.imageUrl != null && message.imageUrl!.trim().isNotEmpty);
    final hasLocalPath =
        (message.localImagePath != null &&
        message.localImagePath!.trim().isNotEmpty);
    final hasThumbnail =
        (message.thumbnailUrl != null &&
        message.thumbnailUrl!.trim().isNotEmpty);
    final hasMimeType =
        (message.mimeType != null && message.mimeType!.trim().isNotEmpty);
    final hasFileName =
        (message.fileName != null && message.fileName!.trim().isNotEmpty);
    final hasPageCount = message.pageCount != null;
    final hasFileSize = message.fileSize != null;
    return !(hasFileUrl ||
        hasLocalPath ||
        hasThumbnail ||
        hasMimeType ||
        hasFileName ||
        hasPageCount ||
        hasFileSize);
  }

  String _toDbMessageType(ChatMessageModel message) {
    final name = message.fileName;
    final mt = message.mimeType;
    if (mt == 'application/pdf' ||
        message.pageCount != null ||
        (name != null && name.toLowerCase().endsWith('.pdf'))) {
      return 'pdf';
    }
    return message.messageType.name;
  }

  ChatMessageModel? _buildReplyToMessageFromRow(Map<String, dynamic> data) {
    final replyToMessageId =
        data[MessagesTable.columnReplyToMessageId] as String?;
    final replyToMessageText =
        data[MessagesTable.columnReplyToMessageText] as String?;
    final replyToMessageSenderId =
        data[MessagesTable.columnReplyToMessageSenderId] as String?;
    final replyToMessageTypeStr =
        data[MessagesTable.columnReplyToMessageType] as String?;

    if (replyToMessageId != null &&
        replyToMessageId.isNotEmpty &&
        replyToMessageText != null &&
        replyToMessageSenderId != null) {
      return ChatMessageModel(
        id: replyToMessageId,
        senderId: replyToMessageSenderId,
        receiverId: '',
        message: replyToMessageText,
        messageType: ChatMessageModel.parseMessageType(replyToMessageTypeStr),
        messageStatus: 'sent',
        isRead: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
    return null;
  }

  @override
  Future<void> saveMessage(ChatMessageModel message) async {
    try {
      _logInfo('SaveMessage', 'Saving message: ${message.id}');

      if (_isDeleteTombstone(message)) {
        await MessagesTable.instance.markMessageAsDeleted(
          messageId: message.id,
          deletedAt: message.createdAt,
        );
        return;
      }

      String finalMessage = message.message;
      if (finalMessage.isEmpty &&
          (message.messageType == MessageType.poll ||
              message.messageType == MessageType.contact)) {
        try {
          final existingMessage = await getMessageById(message.id);
          if (existingMessage != null && existingMessage.message.isNotEmpty) {
            finalMessage = existingMessage.message;
          }
        } catch (_) {}
      }

      // Convert message to database format
      final messageData = {
        MessagesTable.columnId: message.id,
        MessagesTable.columnSenderId: message.senderId,
        MessagesTable.columnReceiverId: message.receiverId,
        MessagesTable.columnMessage: finalMessage,
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
        MessagesTable.columnMessageStatus: message.messageStatus,
        MessagesTable.columnIsRead: message.isRead ? 1 : 0,
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
        MessagesTable.columnThumbnailUrl: message.thumbnailUrl,
        MessagesTable.columnReplyToMessageId:
            message.replyToMessageId ?? message.replyToMessage?.id,
        MessagesTable.columnReplyToMessageText: message.replyToMessage?.message,
        MessagesTable.columnReplyToMessageSenderId:
            message.replyToMessage?.senderId,
        MessagesTable.columnReplyToMessageType:
            message.replyToMessage?.messageType.name,
      };

      await MessagesTable.instance.insertOrUpdateMessage(messageData);

      _logInfo('SaveMessage', 'Message saved successfully');
    } catch (e) {
      _logError('SaveMessage', 'Failed to save message: $e');
      rethrow;
    }
  }

  @override
  Future<void> saveMessages(List<ChatMessageModel> messages) async {
    try {
      _logInfo('SaveMessages', 'Saving ${messages.length} messages');

      final tombstones = <ChatMessageModel>[];
      final messagesData = <Map<String, dynamic>>[];

      for (final message in messages) {
        if (_isDeleteTombstone(message)) {
          tombstones.add(message);
          continue;
        }

        // PRESERVE DIMENSIONS: If API message lacks dimensions, preserve existing ones
        int? finalWidth = message.imageWidth;
        int? finalHeight = message.imageHeight;

        if (message.isImageMessage &&
            (finalWidth == null || finalHeight == null)) {
          try {
            final existingMessage = await getMessageById(message.id);
            if (existingMessage != null) {
              finalWidth ??= existingMessage.imageWidth;
              finalHeight ??= existingMessage.imageHeight;

              if (kDebugMode && (finalWidth != null || finalHeight != null)) {
                debugPrint(
                  '📐 API Sync: Preserved dimensions ${finalWidth}x$finalHeight for ${message.id}',
                );
              }
            }
          } catch (e) {
            debugPrint('⚠️ Error preserving dimensions during API sync: $e');
          }
        }

        // PRESERVE MESSAGE CONTENT: For poll/contact types, if API returns empty message,
        // preserve existing local content (API sync often doesn't include pollPayload/contactPayload)
        String finalMessage = message.message;
        if (finalMessage.isEmpty &&
            (message.messageType == MessageType.poll ||
                message.messageType == MessageType.contact)) {
          try {
            final existingMessage = await getMessageById(message.id);
            if (existingMessage != null && existingMessage.message.isNotEmpty) {
              finalMessage = existingMessage.message;
              if (kDebugMode) {
                debugPrint(
                  '📝 API Sync: Preserved ${message.messageType.name} content for ${message.id}',
                );
              }
            }
          } catch (e) {
            debugPrint(
              '⚠️ Error preserving message content during API sync: $e',
            );
          }
        }

        messagesData.add({
          MessagesTable.columnId: message.id,
          MessagesTable.columnSenderId: message.senderId,
          MessagesTable.columnReceiverId: message.receiverId,
          MessagesTable.columnMessage: finalMessage,
          MessagesTable.columnReactionsJson: message.reactionsJson,
          MessagesTable.columnIsStarred: message.isStarred ? 1 : 0,
          MessagesTable.columnIsEdited: message.isEdited ? 1 : 0,
          MessagesTable.columnEditedAt:
              message.editedAt?.millisecondsSinceEpoch,
          MessagesTable.columnMessageType: _toDbMessageType(message),
          MessagesTable.columnFileUrl: message.imageUrl,
          MessagesTable.columnMimeType: message.mimeType,
          MessagesTable.columnFileName: message.fileName,
          MessagesTable.columnPageCount: message.pageCount,
          MessagesTable.columnFileSize: message.fileSize,
          MessagesTable.columnMessageStatus: message.messageStatus,
          MessagesTable.columnIsRead: message.isRead ? 1 : 0,
          MessagesTable.columnDeliveredAt:
              message.deliveredAt?.millisecondsSinceEpoch,
          MessagesTable.columnReadAt: message.readAt?.millisecondsSinceEpoch,
          MessagesTable.columnCreatedAt:
              message.createdAt.millisecondsSinceEpoch,
          MessagesTable.columnUpdatedAt:
              message.updatedAt.millisecondsSinceEpoch,
          MessagesTable.columnDeliveryChannel: message.deliveryChannel,
          MessagesTable.columnReceiverDeliveryChannel:
              message.receiverDeliveryChannel,
          MessagesTable.columnImageWidth: finalWidth,
          MessagesTable.columnImageHeight: finalHeight,
          MessagesTable.columnAudioDuration: message.audioDuration,
          MessagesTable.columnIsFollowUp: message.isFollowUp ? 1 : 0,
          MessagesTable.columnThumbnailUrl: message.thumbnailUrl,
          MessagesTable.columnReplyToMessageId:
              message.replyToMessageId ?? message.replyToMessage?.id,
          MessagesTable.columnReplyToMessageText:
              message.replyToMessage?.message,
          MessagesTable.columnReplyToMessageSenderId:
              message.replyToMessage?.senderId,
          MessagesTable.columnReplyToMessageType:
              message.replyToMessage?.messageType.name,
        });
      }

      if (tombstones.isNotEmpty) {
        for (final tombstone in tombstones) {
          await MessagesTable.instance.markMessageAsDeleted(
            messageId: tombstone.id,
            deletedAt: tombstone.createdAt,
          );
        }
      }

      if (messagesData.isNotEmpty) {
        await MessagesTable.instance.insertOrUpdateMessages(messagesData);
      }

      _logInfo(
        'SaveMessages',
        '${messages.length} messages saved successfully',
      );
    } catch (e) {
      _logError('SaveMessages', 'Failed to save messages: $e');
      rethrow;
    }
  }

  @override
  Future<List<ChatMessageModel>> getMessages(
    String otherUserId, {
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      _logInfo('GetMessages', 'Retrieving messages for user: $otherUserId');

      // Get current user ID
      final currentUserId = await ChatHelper.getCurrentUserId();
      if (currentUserId == null) {
        _logError('GetMessages', 'Current user ID not found');
        return [];
      }

      // Calculate page from offset
      final page = (offset ~/ limit) + 1;

      // Get messages from database
      final messagesData = await MessagesTable.instance.getChatHistory(
        currentUserId: currentUserId,
        otherUserId: otherUserId,
        page: page,
        limit: limit,
      );

      // Convert database format to ChatMessageModel
      final messages = messagesData.map((data) {
        final messageTypeRaw = data[MessagesTable.columnMessageType] as String?;
        return ChatMessageModel(
          id: data[MessagesTable.columnId] as String,
          senderId: data[MessagesTable.columnSenderId] as String,
          receiverId: data[MessagesTable.columnReceiverId] as String,
          message: data[MessagesTable.columnMessage] as String,
          reactionsJson: data.containsKey(MessagesTable.columnReactionsJson)
              ? data[MessagesTable.columnReactionsJson] as String?
              : null,
          isStarred: (data[MessagesTable.columnIsStarred] as int? ?? 0) == 1,
          isEdited: (data[MessagesTable.columnIsEdited] as int? ?? 0) == 1,
          editedAt: data[MessagesTable.columnEditedAt] != null
              ? DateTime.fromMillisecondsSinceEpoch(
                  data[MessagesTable.columnEditedAt] as int,
                )
              : null,
          messageType: ChatMessageModel.parseMessageType(messageTypeRaw),
          imageUrl: data[MessagesTable.columnFileUrl] as String?,
          localImagePath: data[MessagesTable.columnCachedFilePath] as String?,
          mimeType: data[MessagesTable.columnMimeType] as String?,
          fileName: data[MessagesTable.columnFileName] as String?,
          pageCount: data[MessagesTable.columnPageCount] as int?,
          fileSize: data[MessagesTable.columnFileSize] as int?,
          messageStatus: data[MessagesTable.columnMessageStatus] as String,
          isRead: (data[MessagesTable.columnIsRead] as int) == 1,
          deliveredAt: data[MessagesTable.columnDeliveredAt] != null
              ? DateTime.fromMillisecondsSinceEpoch(
                  data[MessagesTable.columnDeliveredAt] as int,
                )
              : null,
          readAt: data[MessagesTable.columnReadAt] != null
              ? DateTime.fromMillisecondsSinceEpoch(
                  data[MessagesTable.columnReadAt] as int,
                )
              : null,
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            data[MessagesTable.columnCreatedAt] as int,
          ),
          updatedAt: DateTime.fromMillisecondsSinceEpoch(
            data[MessagesTable.columnUpdatedAt] as int,
          ),
          deliveryChannel:
              (data[MessagesTable.columnDeliveryChannel] as String?) ??
              'socket',
          receiverDeliveryChannel:
              data[MessagesTable.columnReceiverDeliveryChannel] as String?,
          imageWidth: data[MessagesTable.columnImageWidth] as int?,
          imageHeight: data[MessagesTable.columnImageHeight] as int?,
          audioDuration: data.containsKey(MessagesTable.columnAudioDuration)
              ? (data[MessagesTable.columnAudioDuration] as num?)?.toDouble()
              : null,
          isFollowUp: (data[MessagesTable.columnIsFollowUp] as int? ?? 0) == 1,
          thumbnailUrl: data[MessagesTable.columnThumbnailUrl] as String?,
          replyToMessageId:
              data[MessagesTable.columnReplyToMessageId] as String?,
          replyToMessage: _buildReplyToMessageFromRow(data),
        );
      }).toList();

      _logInfo('GetMessages', 'Retrieved ${messages.length} messages');
      return messages;
    } catch (e) {
      _logError('GetMessages', 'Failed to retrieve messages: $e');
      return [];
    }
  }

  @override
  Future<ChatMessageModel?> getMessageById(String messageId) async {
    try {
      _logInfo('GetMessageById', 'Retrieving message: $messageId');

      final messageData = await MessagesTable.instance.getMessageById(
        messageId,
      );

      if (messageData == null) {
        _logInfo('GetMessageById', 'Message not found');
        return null;
      }

      final message = ChatMessageModel(
        id: messageData[MessagesTable.columnId] as String,
        senderId: messageData[MessagesTable.columnSenderId] as String,
        receiverId: messageData[MessagesTable.columnReceiverId] as String,
        message: messageData[MessagesTable.columnMessage] as String,
        reactionsJson:
            messageData.containsKey(MessagesTable.columnReactionsJson)
            ? messageData[MessagesTable.columnReactionsJson] as String?
            : null,
        isStarred:
            (messageData[MessagesTable.columnIsStarred] as int? ?? 0) == 1,
        isEdited: (messageData[MessagesTable.columnIsEdited] as int? ?? 0) == 1,
        editedAt: messageData[MessagesTable.columnEditedAt] != null
            ? DateTime.fromMillisecondsSinceEpoch(
                messageData[MessagesTable.columnEditedAt] as int,
              )
            : null,
        messageType: ChatMessageModel.parseMessageType(
          messageData[MessagesTable.columnMessageType] as String?,
        ),
        imageUrl: messageData[MessagesTable.columnFileUrl] as String?,
        localImagePath:
            messageData[MessagesTable.columnCachedFilePath] as String?,
        mimeType: messageData[MessagesTable.columnMimeType] as String?,
        fileName: messageData[MessagesTable.columnFileName] as String?,
        pageCount: messageData[MessagesTable.columnPageCount] as int?,
        fileSize: messageData[MessagesTable.columnFileSize] as int?,
        messageStatus: messageData[MessagesTable.columnMessageStatus] as String,
        isRead: (messageData[MessagesTable.columnIsRead] as int) == 1,
        deliveredAt: messageData[MessagesTable.columnDeliveredAt] != null
            ? DateTime.fromMillisecondsSinceEpoch(
                messageData[MessagesTable.columnDeliveredAt] as int,
              )
            : null,
        readAt: messageData[MessagesTable.columnReadAt] != null
            ? DateTime.fromMillisecondsSinceEpoch(
                messageData[MessagesTable.columnReadAt] as int,
              )
            : null,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          messageData[MessagesTable.columnCreatedAt] as int,
        ),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          messageData[MessagesTable.columnUpdatedAt] as int,
        ),
        deliveryChannel:
            (messageData[MessagesTable.columnDeliveryChannel] as String?) ??
            'socket',
        receiverDeliveryChannel:
            messageData[MessagesTable.columnReceiverDeliveryChannel] as String?,
        imageWidth: messageData[MessagesTable.columnImageWidth] as int?,
        imageHeight: messageData[MessagesTable.columnImageHeight] as int?,
        audioDuration:
            messageData.containsKey(MessagesTable.columnAudioDuration)
            ? (messageData[MessagesTable.columnAudioDuration] as num?)
                  ?.toDouble()
            : null,
        isFollowUp:
            (messageData[MessagesTable.columnIsFollowUp] as int? ?? 0) == 1,
        thumbnailUrl: messageData[MessagesTable.columnThumbnailUrl] as String?,
        replyToMessageId:
            messageData[MessagesTable.columnReplyToMessageId] as String?,
        replyToMessage: _buildReplyToMessageFromRow(messageData),
      );

      _logInfo('GetMessageById', 'Message found');
      return message;
    } catch (e) {
      _logError('GetMessageById', 'Failed to retrieve message: $e');
      return null;
    }
  }

  @override
  Future<void> updateMessageStatus(
    String messageId,
    String status, {
    DateTime? deliveredAt,
    DateTime? readAt,
  }) async {
    try {
      _logInfo('UpdateMessageStatus', 'Updating message $messageId to $status');

      await MessagesTable.instance.updateMessageStatus(
        messageId: messageId,
        status: status,
        deliveredAt: deliveredAt,
        readAt: readAt,
      );

      _logInfo('UpdateMessageStatus', 'Message status updated successfully');
    } catch (e) {
      _logError('UpdateMessageStatus', 'Failed to update message status: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteMessage(String messageId) async {
    try {
      _logInfo('DeleteMessage', 'Deleting message: $messageId');

      await MessagesTable.instance.deleteMessage(messageId);

      _logInfo('DeleteMessage', 'Message deleted successfully');
    } catch (e) {
      _logError('DeleteMessage', 'Failed to delete message: $e');
      rethrow;
    }
  }

  @override
  Future<void> clearConversation(String otherUserId) async {
    try {
      _logInfo('ClearConversation', 'Clearing conversation with: $otherUserId');

      // Get current user ID
      final currentUserId = await ChatHelper.getCurrentUserId();
      if (currentUserId == null) {
        _logError('ClearConversation', 'Current user ID not found');
        return;
      }

      await MessagesTable.instance.deleteConversation(
        currentUserId: currentUserId,
        otherUserId: otherUserId,
      );

      _logInfo('ClearConversation', 'Conversation cleared successfully');
    } catch (e) {
      _logError('ClearConversation', 'Failed to clear conversation: $e');
      rethrow;
    }
  }

  @override
  Future<int> getUnreadCount() async {
    try {
      _logInfo('GetUnreadCount', 'Retrieving unread count');

      // Get current user ID
      final currentUserId = await ChatHelper.getCurrentUserId();
      if (currentUserId == null) {
        _logError('GetUnreadCount', 'Current user ID not found');
        return 0;
      }

      final count = await MessagesTable.instance.getUnreadCount(
        currentUserId: currentUserId,
      );

      _logInfo('GetUnreadCount', 'Unread count: $count');
      return count;
    } catch (e) {
      _logError('GetUnreadCount', 'Failed to get unread count: $e');
      return 0;
    }
  }

  @override
  Future<List<ChatContactModel>> getChatContactsFromLocal() async {
    try {
      _logInfo(
        'GetChatContactsFromLocal',
        'Retrieving chat contacts from local DB',
      );

      // Get current user ID
      final currentUserId = await ChatHelper.getCurrentUserId();
      if (currentUserId == null) {
        _logError('GetChatContactsFromLocal', 'Current user ID not found');
        return [];
      }

      // Get latest messages for each conversation
      final latestMessagesData = await MessagesTable.instance.getLatestMessages(
        currentUserId: currentUserId,
      );

      final unreadBySender = await MessagesTable.instance
          .getUnreadCountsBySender(currentUserId: currentUserId);

      if (latestMessagesData.isEmpty) {
        _logInfo('GetChatContactsFromLocal', 'No conversations found');
        return [];
      }

      final List<ChatContactModel> contacts = [];

      // Get contacts database
      final contactsDb = await AppDatabaseManager.instance.database;

      for (final messageData in latestMessagesData) {
        // Determine the other user ID
        final senderId = messageData[MessagesTable.columnSenderId] as String;
        final receiverId =
            messageData[MessagesTable.columnReceiverId] as String;
        final otherUserId = senderId == currentUserId ? receiverId : senderId;

        // FILTER: Only show conversations with real message activity
        // Check if there are ANY messages exchanged (sent OR received)
        // This prevents empty conversations from appearing when just opening a chat
        final hasMessages = await MessagesTable.instance.hasUserSentMessage(
          currentUserId: currentUserId,
          otherUserId: otherUserId,
        );

        if (!hasMessages) {
          if (_verboseLogs && kDebugMode) {
            debugPrint(
              '🚫 ChatList: Skipping $otherUserId - no messages exchanged yet',
            );
          }
          continue; // Skip this contact
        }

        // Get contact details from contacts table
        final contactResult = await contactsDb.query(
          ContactsTable.tableName,
          where: '${ContactsTable.columnAppUserId} = ?',
          whereArgs: [otherUserId],
          limit: 1,
        );

        // Fallback: search by user_details JSON if app_user_id is not populated
        Map<String, Object?>? contactData;
        if (contactResult.isNotEmpty) {
          contactData = contactResult.first;
        } else {
          final likeResult = await contactsDb.query(
            ContactsTable.tableName,
            where: '${ContactsTable.columnUserDetails} LIKE ?',
            whereArgs: ['%$otherUserId%'],
            limit: 1,
          );
          if (likeResult.isNotEmpty) {
            contactData = likeResult.first;
            // Backfill app_user_id for future fast lookups
            try {
              await contactsDb.update(
                ContactsTable.tableName,
                {ContactsTable.columnAppUserId: otherUserId},
                where: '${ContactsTable.columnContactHash} = ?',
                whereArgs: [contactData[ContactsTable.columnContactHash]],
              );
            } catch (_) {}
          }
        }

        Map<String, Object?>? chatUserData;
        if (contactData == null) {
          final chatUserRows = await contactsDb.query(
            ChatUsersTable.tableName,
            where: '${ChatUsersTable.columnUserId} = ?',
            whereArgs: [otherUserId],
            limit: 1,
          );
          if (chatUserRows.isNotEmpty) {
            chatUserData = chatUserRows.first;
          }
        }

        // Resolve contact name + picture
        String firstName = 'Unknown';
        String lastName = 'User';
        String mobileNo = '';
        String? chatPictureUrl;

        if (contactData != null) {
          String fullName =
              (contactData[ContactsTable.columnContactName] as String?)
                  ?.trim() ??
              '';
          final nameParts = fullName.split(' ');
          firstName = nameParts.first;
          lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
          mobileNo =
              (contactData[ContactsTable.columnContactMobileNumber]
                  as String?) ??
              '';

          // Extract profile pic from user_details JSON
          final userDetailsJson =
              contactData[ContactsTable.columnUserDetails] as String?;
          if (userDetailsJson != null && userDetailsJson.isNotEmpty) {
            try {
              final userDetailsMap =
                  json.decode(userDetailsJson) as Map<String, dynamic>;

              if (fullName.isEmpty) {
                fullName =
                    (userDetailsMap['contact_name'] ??
                            userDetailsMap['name'] ??
                            '')
                        .toString()
                        .trim();
                if (fullName.isNotEmpty) {
                  final p = fullName.split(' ');
                  firstName = p.first;
                  lastName = p.length > 1 ? p.sublist(1).join(' ') : '';
                }
              }

              if (fullName.isEmpty) {
                fullName = 'Unknown User';
                firstName = 'Unknown';
                lastName = 'User';
              }

              chatPictureUrl =
                  (userDetailsMap['chat_picture'] ??
                          userDetailsMap['profile_pic'])
                      as String?;
            } catch (e) {
              _logError(
                'GetChatContactsFromLocal',
                'Failed to parse user_details JSON: $e',
              );
              if (fullName.isEmpty) {
                firstName = 'Unknown';
                lastName = 'User';
              }
            }
          }

          if (fullName.isEmpty) {
            firstName = 'Unknown';
            lastName = 'User';
          }
        } else if (chatUserData != null) {
          firstName =
              (chatUserData[ChatUsersTable.columnFirstName] as String?) ??
              'ChatAway';
          lastName =
              (chatUserData[ChatUsersTable.columnLastName] as String?) ??
              'user';
          mobileNo =
              (chatUserData[ChatUsersTable.columnMobileNo] as String?) ?? '';
          chatPictureUrl =
              chatUserData[ChatUsersTable.columnChatPictureUrl] as String?;
        } else {
          // If contact not found in contacts table, use a generic ChatAway label
          // This only happens when the user is not yet present in the contacts
          // cache (e.g., new app user on another device). Normal scenarios will
          // still show the phone's contact name via ContactsTable.
          firstName = 'ChatAway';
          lastName = 'user';
        }

        // Create ChatUserModel
        final user = ChatUserModel(
          id: otherUserId,
          firstName: firstName,
          lastName: lastName,
          mobileNo: mobileNo,
          chatPictureUrl: chatPictureUrl,
        );

        // Create ChatMessageModel from database data
        final lastMessage = ChatMessageModel(
          id: messageData[MessagesTable.columnId] as String,
          senderId: senderId,
          receiverId: receiverId,
          message: messageData[MessagesTable.columnMessage] as String,
          reactionsJson:
              messageData[MessagesTable.columnReactionsJson] as String?,
          isStarred:
              (messageData[MessagesTable.columnIsStarred] as int? ?? 0) == 1,
          isEdited:
              (messageData[MessagesTable.columnIsEdited] as int? ?? 0) == 1,
          editedAt: messageData[MessagesTable.columnEditedAt] != null
              ? DateTime.fromMillisecondsSinceEpoch(
                  messageData[MessagesTable.columnEditedAt] as int,
                )
              : null,
          messageType: ChatMessageModel.parseMessageType(
            messageData[MessagesTable.columnMessageType] as String?,
          ),
          imageUrl: messageData[MessagesTable.columnFileUrl] as String?,
          mimeType: messageData[MessagesTable.columnMimeType] as String?,
          fileName: messageData[MessagesTable.columnFileName] as String?,
          pageCount: messageData[MessagesTable.columnPageCount] as int?,
          fileSize: messageData[MessagesTable.columnFileSize] as int?,
          messageStatus:
              messageData[MessagesTable.columnMessageStatus] as String,
          isRead: (messageData[MessagesTable.columnIsRead] as int) == 1,
          deliveredAt: messageData[MessagesTable.columnDeliveredAt] != null
              ? DateTime.fromMillisecondsSinceEpoch(
                  messageData[MessagesTable.columnDeliveredAt] as int,
                )
              : null,
          readAt: messageData[MessagesTable.columnReadAt] != null
              ? DateTime.fromMillisecondsSinceEpoch(
                  messageData[MessagesTable.columnReadAt] as int,
                )
              : null,
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            messageData[MessagesTable.columnCreatedAt] as int,
          ),
          updatedAt: DateTime.fromMillisecondsSinceEpoch(
            messageData[MessagesTable.columnUpdatedAt] as int,
          ),
          deliveryChannel:
              (messageData[MessagesTable.columnDeliveryChannel] as String?) ??
              'socket',
          receiverDeliveryChannel:
              messageData[MessagesTable.columnReceiverDeliveryChannel]
                  as String?,
          imageWidth: messageData[MessagesTable.columnImageWidth] as int?,
          imageHeight: messageData[MessagesTable.columnImageHeight] as int?,
          audioDuration:
              messageData.containsKey(MessagesTable.columnAudioDuration)
              ? (messageData[MessagesTable.columnAudioDuration] as num?)
                    ?.toDouble()
              : null,
          isFollowUp:
              (messageData[MessagesTable.columnIsFollowUp] as int? ?? 0) == 1,
          thumbnailUrl:
              messageData[MessagesTable.columnThumbnailUrl] as String?,
        );

        // Create ChatContactModel
        final contact = ChatContactModel(
          user: user,
          lastMessage: lastMessage,
          unreadCount: unreadBySender[otherUserId] ?? 0,
        );

        contacts.add(contact);
      }

      if (kDebugMode) {
        if (_verboseLogs) {
          debugPrint('💾 ChatList DB: Loaded ${contacts.length} conversations');
        }
      }
      return contacts;
    } catch (e, stackTrace) {
      _logError('GetChatContactsFromLocal', 'Failed to get contacts: $e');
      if (_verboseLogs && kDebugMode) {
        debugPrint('Stack trace: $stackTrace');
      }
      return [];
    }
  }

  @override
  Future<void> saveChatContacts(List<ChatContactModel> contacts) async {
    if (contacts.isEmpty) {
      if (_verboseLogs && kDebugMode) {
        debugPrint('💾 SaveChatContacts: No contacts to save');
      }
      return;
    }

    try {
      if (_verboseLogs && kDebugMode) {
        debugPrint(
          '💾 SaveChatContacts: Saving ${contacts.length} contacts to local DB',
        );
      }

      // Get current user ID
      final currentUserId = await ChatHelper.getCurrentUserId();
      if (currentUserId == null) {
        _logError('SaveChatContacts', 'Current user ID not found');
        return;
      }

      // Prepare user data for batch insert to chat_users table
      final List<Map<String, dynamic>> usersToSave = [];
      final List<ChatMessageModel> messagesToSave = [];

      for (final contact in contacts) {
        final user = contact.user;

        // Add user to batch (will be saved to chat_users table)
        usersToSave.add({
          ChatUsersTable.columnUserId: user.id,
          ChatUsersTable.columnFirstName: user.firstName,
          ChatUsersTable.columnLastName: user.lastName,
          ChatUsersTable.columnMobileNo: user.mobileNo,
          ChatUsersTable.columnChatPictureUrl: user.chatPictureUrl,
          ChatUsersTable.columnUpdatedAt: DateTime.now().millisecondsSinceEpoch,
        });

        // Add last message to batch if present
        if (contact.lastMessage != null) {
          // Ensure receiverId is set correctly for the message
          final msg = contact.lastMessage!;
          final correctedMessage = ChatMessageModel(
            id: msg.id,
            senderId: msg.senderId,
            // If senderId is current user, receiver is the contact; otherwise, receiver is current user
            receiverId: msg.senderId == currentUserId ? user.id : currentUserId,
            message: msg.message,
            reactionsJson: msg.reactionsJson,
            isStarred: msg.isStarred,
            isEdited: msg.isEdited,
            editedAt: msg.editedAt,
            messageType: msg.messageType,
            imageUrl: msg.imageUrl,
            mimeType: msg.mimeType,
            fileName: msg.fileName,
            pageCount: msg.pageCount,
            fileSize: msg.fileSize,
            imageWidth: msg.imageWidth,
            imageHeight: msg.imageHeight,
            audioDuration: msg.audioDuration,
            messageStatus: msg.messageStatus,
            isRead: msg.isRead,
            deliveredAt: msg.deliveredAt,
            readAt: msg.readAt,
            createdAt: msg.createdAt,
            updatedAt: msg.updatedAt,
            deliveryChannel: msg.deliveryChannel,
            receiverDeliveryChannel: msg.receiverDeliveryChannel,
            isFollowUp: msg.isFollowUp,
            thumbnailUrl: msg.thumbnailUrl,
          );
          messagesToSave.add(correctedMessage);
        }
      }

      // Save users to chat_users table
      if (usersToSave.isNotEmpty) {
        await ChatUsersTable.instance.upsertUsers(usersToSave);
        debugPrint(
          '💾 SaveChatContacts: Saved ${usersToSave.length} users to chat_users table',
        );
      }

      // Save last messages to messages table
      if (messagesToSave.isNotEmpty) {
        await saveMessages(messagesToSave);
        debugPrint(
          '💾 SaveChatContacts: Saved ${messagesToSave.length} last messages to messages table',
        );
      }

      debugPrint(
        '✅ SaveChatContacts: Successfully persisted ${contacts.length} contacts to local DB',
      );
    } catch (e, stackTrace) {
      _logError('SaveChatContacts', 'Failed to save contacts: $e');
      if (kDebugMode) {
        print('Stack trace: $stackTrace');
      }
      // Don't rethrow - saving to local is not critical, app can still work with API data
    }
  }

  @override
  Future<void> clearAllChats() async {
    try {
      _logInfo('ClearAllChats', 'Clearing all chat data');

      await MessagesTable.instance.deleteAllMessages();

      _logInfo('ClearAllChats', 'All chat data cleared successfully');
    } catch (e) {
      _logError('ClearAllChats', 'Failed to clear chat data: $e');
      rethrow;
    }
  }

  void _logInfo(String operation, String message) {
    if (_verboseLogs && kDebugMode) {
      debugPrint('💾 [LOCAL] DB.$operation: $message');
    }
  }

  void _logError(String operation, String message) {
    if (kDebugMode) {
      debugPrint('❌ [LOCAL] DB.$operation ERROR: $message');
    }
  }
}
