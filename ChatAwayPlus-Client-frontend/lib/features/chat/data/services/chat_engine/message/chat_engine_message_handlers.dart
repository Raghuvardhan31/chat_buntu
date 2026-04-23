part of '../chat_engine_service.dart';

/// ChatEngineMessageHandlersMixin - Message Event Handlers
///
/// Handles WebSocket/FCM message events:
/// - _handleChatActivityUpdated
/// - _handleStarredUpdated
/// - _handleReactionUpdated
/// - _handleMessageEdited
/// - _handleMessageStatusUpdate
mixin ChatEngineMessageHandlersMixin on ChatEngineServiceBase {
  bool _parseStarred(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) return value == 1;
    final s = value.toString().toLowerCase().trim();
    return s == 'true' || s == '1' || s == 'yes' || s == 'starred';
  }

  /// Handle chat activity updates (reactions, edits, etc.)
  Future<void> handleChatActivityUpdated(Map<String, dynamic> payload) async {
    try {
      final activity = ChatLastActivityModel.tryFromJson(payload);
      if (activity == null) return;

      String? otherUserId = (payload['otherUserId'] ?? payload['other_user_id'])
          ?.toString();
      otherUserId ??= (payload['userId'] ?? payload['user_id'])?.toString();

      if (otherUserId == null || otherUserId.isEmpty) {
        try {
          final current = ChatListStream.instance.currentList;
          for (final c in current) {
            if (c.lastMessage?.id == activity.messageId) {
              otherUserId = c.user.id;
              break;
            }
          }
        } catch (_) {}
      }

      if ((otherUserId == null || otherUserId.isEmpty) &&
          _currentUserId != null) {
        final messageId =
            (payload['messageId'] ??
                    payload['message_id'] ??
                    payload['chatId'] ??
                    payload['chat_id'] ??
                    payload['id'])
                ?.toString();
        if (messageId != null && messageId.isNotEmpty) {
          try {
            final row = await MessagesTable.instance.getMessageById(messageId);
            if (row != null) {
              final senderId = row[MessagesTable.columnSenderId]?.toString();
              final receiverId = row[MessagesTable.columnReceiverId]
                  ?.toString();
              if (senderId == _currentUserId) {
                otherUserId = receiverId;
              } else if (receiverId == _currentUserId) {
                otherUserId = senderId;
              }
            }
          } catch (_) {}
        }
      }

      if (otherUserId == null || otherUserId.isEmpty) return;

      ChatListCache.instance.applyLastActivity(
        otherUserId: otherUserId,
        activity: activity,
      );
      ChatListStream.instance.applyLastActivity(
        otherUserId: otherUserId,
        activity: activity,
      );
    } catch (e) {
      debugPrint(
        ' ChatEngineService: Error handling chat-activity-updated: $e',
      );
    }
  }

  /// Handle starred status updates
  Future<void> handleStarredUpdated(Map<String, dynamic> payload) async {
    try {
      final chatId =
          (payload['chatId'] ?? payload['id'] ?? payload['messageId'])
              ?.toString();
      if (chatId == null || chatId.isEmpty) return;

      final starredRaw =
          payload['starred'] ??
          payload['isStarred'] ??
          payload['is_starred'] ??
          payload['isStar'];
      final isStarred = _parseStarred(starredRaw);

      await MessagesTable.instance.updateMessageStarred(
        messageId: chatId,
        isStarred: isStarred,
      );

      final currentUserId = _currentUserId;
      if (currentUserId == null || currentUserId.isEmpty) {
        return;
      }

      String? otherUserId;
      try {
        final row = await MessagesTable.instance.getMessageById(chatId);
        if (row != null) {
          final senderId = row[MessagesTable.columnSenderId]?.toString();
          final receiverId = row[MessagesTable.columnReceiverId]?.toString();
          if (senderId != null && receiverId != null) {
            otherUserId = senderId == currentUserId ? receiverId : senderId;
          }
        }
      } catch (_) {}

      otherUserId ??= _activeConversationUserId;
      if (otherUserId == null || otherUserId.isEmpty) return;

      if (_activeConversationUserId == otherUserId) {
        final updatedMessages = await _loadConversationFromLocal(otherUserId);
        _openedChatsCache.cacheMessages(otherUserId, updatedMessages);
        _onMessagesUpdated?.call(updatedMessages);
      } else {
        _openedChatsCache.invalidate(otherUserId);
      }
    } catch (e) {
      debugPrint(' ChatEngineService: Error handling starred update: $e');
    }
  }

  /// Handle reaction updates
  Future<void> handleReactionUpdated(Map<String, dynamic> payload) async {
    try {
      final chatId =
          (payload['chatId'] ?? payload['id'] ?? payload['messageId'])
              ?.toString();
      if (chatId == null || chatId.isEmpty) return;

      dynamic reactionsRaw =
          payload['reactionsJson'] ??
          payload['reactions_json'] ??
          payload['reactions'];

      if (reactionsRaw == null) {
        final messageRaw =
            payload['message'] ??
            payload['messageObject'] ??
            payload['messageData'];
        if (messageRaw is Map) {
          final msg = Map<String, dynamic>.from(messageRaw);
          reactionsRaw =
              msg['reactionsJson'] ?? msg['reactions_json'] ?? msg['reactions'];
        }
      }

      final reactionsJson = reactionsRaw == null
          ? null
          : (reactionsRaw is String ? reactionsRaw : jsonEncode(reactionsRaw));
      if (reactionsJson == null) return;

      final updatedAtRaw = payload['updatedAt'] ?? payload['updated_at'];
      final updatedAt = updatedAtRaw != null
          ? DateTime.tryParse(updatedAtRaw.toString())
          : null;

      await MessagesTable.instance.updateMessageReactions(
        messageId: chatId,
        reactionsJson: reactionsJson,
        updatedAt: updatedAt,
      );

      final senderId = payload['senderId']?.toString();
      final receiverId = payload['receiverId']?.toString();

      String? otherUserId;
      if (_currentUserId != null) {
        if (senderId == _currentUserId) {
          otherUserId = receiverId;
        } else if (receiverId == _currentUserId) {
          otherUserId = senderId;
        }
      }

      otherUserId ??= payload['otherUserId']?.toString();
      otherUserId ??= payload['conversationWith']?.toString();
      otherUserId ??= _activeConversationUserId;

      if (otherUserId == null || otherUserId.isEmpty) return;

      if (_activeConversationUserId == otherUserId) {
        final updatedMessages = await _loadConversationFromLocal(otherUserId);
        _openedChatsCache.cacheMessages(otherUserId, updatedMessages);
        _onMessagesUpdated?.call(updatedMessages);
      } else {
        _openedChatsCache.invalidate(otherUserId);
      }
    } catch (e) {
      debugPrint(' ChatEngineService: Error handling reaction-updated: $e');
    }
  }

  /// Handle message edited events
  Future<void> handleMessageEdited(Map<String, dynamic> payload) async {
    try {
      final chatId =
          (payload['chatId'] ?? payload['id'] ?? payload['messageId'])
              ?.toString();
      if (chatId == null || chatId.isEmpty) return;

      final newMessage = (payload['newMessage'] ?? payload['message'])
          ?.toString();
      if (newMessage == null) return;

      final editedAtRaw = payload['editedAt'] ?? payload['edited_at'];
      final editedAt = editedAtRaw != null
          ? DateTime.tryParse(editedAtRaw.toString())
          : null;

      await _localStorage.updateMessageEdit(
        messageId: chatId,
        newMessage: newMessage,
        editedAt: editedAt,
      );

      final senderId = payload['senderId']?.toString();
      final receiverId = payload['receiverId']?.toString();

      String? otherUserId;
      if (_currentUserId != null) {
        if (senderId == _currentUserId) {
          otherUserId = receiverId;
        } else if (receiverId == _currentUserId) {
          otherUserId = senderId;
        }
      }

      otherUserId ??= payload['otherUserId']?.toString();
      otherUserId ??= payload['conversationWith']?.toString();

      if ((otherUserId == null || otherUserId.isEmpty) &&
          _currentUserId != null) {
        try {
          final row = await MessagesTable.instance.getMessageById(chatId);
          if (row != null) {
            final dbSenderId = row[MessagesTable.columnSenderId]?.toString();
            final dbReceiverId = row[MessagesTable.columnReceiverId]
                ?.toString();

            if (dbSenderId == _currentUserId) {
              otherUserId = dbReceiverId;
            } else if (dbReceiverId == _currentUserId) {
              otherUserId = dbSenderId;
            }
          }
        } catch (_) {}
      }

      otherUserId ??= _activeConversationUserId;

      if (otherUserId == null || otherUserId.isEmpty) return;

      unawaited(ChatListStream.instance.reloadDebounced());

      if (_activeConversationUserId == otherUserId) {
        final updatedMessages = await _loadConversationFromLocal(otherUserId);
        _openedChatsCache.cacheMessages(otherUserId, updatedMessages);
        _onMessagesUpdated?.call(updatedMessages);
      } else {
        _openedChatsCache.invalidate(otherUserId);
      }
    } catch (e) {
      debugPrint(' ChatEngineService: Error handling message-edited: $e');
    }
  }

  /// Handle message status updates from server
  Future<void> handleMessageStatusUpdate(
    Map<String, dynamic> statusUpdate,
  ) async {
    final service = this as ChatEngineService;
    try {
      final messageId =
          (statusUpdate['messageId'] ??
                  statusUpdate['chatId'] ??
                  statusUpdate['message_id'] ??
                  statusUpdate['chat_id'] ??
                  statusUpdate['statusId'] ??
                  statusUpdate['status_id'] ??
                  statusUpdate['id'])
              ?.toString();
      final status = statusUpdate['status'] as String?;
      final updatedAt =
          (statusUpdate['updatedAt'] ?? statusUpdate['timestamp']) as String?;
      final messageObject =
          statusUpdate['messageObject'] as Map<String, dynamic>?;

      if (messageId == null || status == null) {
        debugPrint(' ChatEngineService: Invalid status update data');
        return;
      }

      if (kDebugMode) {
        final shortId = messageId.length > 20
            ? messageId.substring(0, 20)
            : messageId;
        debugPrint('\n📊 STATUS UPDATE: $shortId...');
        debugPrint('   📡 Channel: WebSocket');
        debugPrint('   📝 New Status: $status');
      }

      String effectiveStatus = ChatMessageModel.normalizeMessageStatus(status);
      DateTime? deliveredAt;
      DateTime? readAt;
      DateTime? updatedAtDt = updatedAt != null
          ? DateTime.tryParse(updatedAt)
          : null;
      String? receiverDeliveryChannel;
      String? statusOtherUserId;

      if (messageObject != null) {
        try {
          final updatedMessage = ChatMessageModel.fromJson(messageObject);
          effectiveStatus = updatedMessage.messageStatus;
          deliveredAt = updatedMessage.deliveredAt;
          readAt = updatedMessage.readAt;
          updatedAtDt = updatedMessage.updatedAt;
          receiverDeliveryChannel = updatedMessage.receiverDeliveryChannel;

          if (_currentUserId != null) {
            statusOtherUserId = updatedMessage.senderId == _currentUserId!
                ? updatedMessage.receiverId
                : updatedMessage.senderId;

            await _localStorage.saveMessage(
              message: updatedMessage,
              currentUserId: _currentUserId!,
              otherUserId: statusOtherUserId,
            );
          }
        } catch (e) {
          debugPrint(
            ' ChatEngineService: Failed to parse/save messageObject: $e',
          );
        }
      } else {
        if (effectiveStatus == 'delivered' && updatedAtDt != null) {
          deliveredAt = updatedAtDt;
        }
        if (effectiveStatus == 'read' && updatedAtDt != null) {
          readAt = updatedAtDt;
        }
      }

      statusOtherUserId ??= _activeConversationUserId;

      if ((statusOtherUserId == null || statusOtherUserId.isEmpty) &&
          _currentUserId != null) {
        try {
          final row = await MessagesTable.instance.getMessageById(messageId);
          if (row != null) {
            final senderId = row[MessagesTable.columnSenderId]?.toString();
            final receiverId = row[MessagesTable.columnReceiverId]?.toString();
            if (senderId != null && receiverId != null) {
              if (senderId == _currentUserId) {
                statusOtherUserId = receiverId;
              } else if (receiverId == _currentUserId) {
                statusOtherUserId = senderId;
              }
            }
          }
        } catch (_) {}
      }

      service._onMessageStatusChanged?.call(messageId, effectiveStatus);

      // Update opened chat cache for the correct conversation user
      // Previously only updated for _activeConversationUserId, causing stale
      // ticks when re-opening a non-active chat after status updates arrived.
      final cacheTargetUserId = statusOtherUserId ?? _activeConversationUserId;
      if (cacheTargetUserId != null && cacheTargetUserId.isNotEmpty) {
        _openedChatsCache.updateMessageStatus(
          otherUserId: cacheTargetUserId,
          messageId: messageId,
          newStatus: effectiveStatus,
          deliveredAt: deliveredAt,
          readAt: readAt,
        );
      }

      if (kDebugMode) {
        debugPrint(
          '✓✓ [ChatEngineService] updateMessageStatus: msgId=${messageId.substring(0, 8)}... status=$effectiveStatus',
        );
      }
      try {
        ChatListStream.instance.updateMessageStatus(
          messageId: messageId,
          newStatus: effectiveStatus,
          otherUserId: statusOtherUserId,
        );
      } catch (_) {}
      try {
        if (statusOtherUserId != null) {
          ChatListCache.instance.updateMessageStatus(
            otherUserId: statusOtherUserId,
            messageId: messageId,
            newStatus: effectiveStatus,
          );
        }
      } catch (_) {}

      try {
        await _localStorage.updateMessageStatus(
          messageId: messageId,
          newStatus: effectiveStatus,
          deliveredAt: deliveredAt,
          readAt: readAt,
          updatedAt: updatedAtDt,
          receiverDeliveryChannel: receiverDeliveryChannel,
        );
      } catch (dbError) {
        try {
          await Future.delayed(Duration(milliseconds: 100));
          await _localStorage.updateMessageStatus(
            messageId: messageId,
            newStatus: effectiveStatus,
            deliveredAt: deliveredAt,
            readAt: readAt,
            updatedAt: updatedAtDt,
            receiverDeliveryChannel: receiverDeliveryChannel,
          );
        } catch (_) {}
      }

      try {
        service._messageStatusController.add(
          ChatMessageStatusUpdate(
            messageId: messageId,
            status: effectiveStatus,
            otherUserId: _activeConversationUserId,
          ),
        );
      } catch (_) {}
    } catch (e) {
      debugPrint(' ChatEngineService: Error handling status update: $e');
    }
  }
}
