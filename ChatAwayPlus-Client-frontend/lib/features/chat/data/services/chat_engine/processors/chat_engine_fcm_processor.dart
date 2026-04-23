part of '../chat_engine_service.dart';

mixin ChatEngineFcmProcessorMixin on ChatEngineServiceBase {
  Future<void> _saveFCMMessageInternal(ChatMessageModel fcmMessage) async {
    try {
      // Always show incoming FCM message channel for debugging
      if (kDebugMode) {
        final preview = fcmMessage.message.length > 30
            ? '${fcmMessage.message.substring(0, 30)}...'
            : fcmMessage.message;
        debugPrint(
          '\n📥 INCOMING MESSAGE: ${fcmMessage.id.length > 20 ? fcmMessage.id.substring(0, 20) : fcmMessage.id}...',
        );
        debugPrint('   📡 Channel: FCM (Push Notification)');
        debugPrint(
          '   👤 From: ${fcmMessage.senderId.length > 8 ? fcmMessage.senderId.substring(0, 8) : fcmMessage.senderId}...',
        );
        debugPrint('   💬 Preview: $preview');
      }
      // Use receiverId as a safe fallback for current user during FCM flows
      final effectiveCurrentUserId = _currentUserId ?? fcmMessage.receiverId;
      if (effectiveCurrentUserId.isEmpty) {
        debugPrint(
          ' ChatEngineService: Cannot save FCM message - no current user',
        );
        return;
      }

      // Also check DB - if a socket-sourced message already exists, prefer socket and skip FCM save
      if (fcmMessage.id.isNotEmpty) {
        try {
          final existing = await MessagesTable.instance.getMessageById(
            fcmMessage.id,
          );
          if (existing != null) {
            final existingChannel =
                existing[MessagesTable.columnDeliveryChannel] as String?;
            if (existingChannel != null &&
                existingChannel.toLowerCase() == 'socket') {
              debugPrint(
                ' ChatEngineService: FCM: Duplicate exists from socket - skipping FCM save for ${fcmMessage.id}',
              );
              return;
            }
          }
        } catch (e) {
          debugPrint(' ChatEngineService: DB check failed for FCM save: $e');
          // continue - will attempt to save
        }
      }

      // Check if message already processed to prevent FCM+WebSocket duplicates
      final idKey = (fcmMessage.id).isNotEmpty ? 'id:${fcmMessage.id}' : null;
      if (idKey != null && _processedMessageIds.contains(idKey)) {
        debugPrint(
          ' ChatEngineService: FCM: Message ID already processed - skipping: ${fcmMessage.id}',
        );
        return;
      }
      if (idKey != null) {
        _processedMessageIds.add(idKey);
      } else {
        final messageKey =
            '${fcmMessage.senderId}_${fcmMessage.message}_${fcmMessage.createdAt.millisecondsSinceEpoch}';
        if (_processedMessageIds.contains(messageKey)) {
          debugPrint(
            ' ChatEngineService: FCM: Message already processed via WebSocket - skipping: ${fcmMessage.message.substring(0, 20)}...',
          );
          return;
        }
        _processedMessageIds.add(messageKey);
      }
      // Prevent unbounded memory growth
      if (_processedMessageIds.length > 1000) {
        final toRemove = _processedMessageIds.take(500).toList();
        _processedMessageIds.removeAll(toRemove);
      }
      debugPrint(
        ' ChatEngineService: FCM: Processing message from ${fcmMessage.senderId}',
      );
      debugPrint(
        ' ChatEngineService: [RECEIVED] Device message received via FCM: id=${fcmMessage.id}, '
        'sender=${fcmMessage.senderId}, receiver=${fcmMessage.receiverId}',
      );

      final isActiveConversation =
          _activeConversationUserId == fcmMessage.senderId;

      try {
        ChatListStream.instance.bumpWithMessage(
          otherUserId: fcmMessage.senderId,
          message: fcmMessage,
          unreadDelta: isActiveConversation ? 0 : 1,
        );
      } catch (_) {}
      try {
        ChatListCache.instance.bumpWithMessage(
          otherUserId: fcmMessage.senderId,
          message: fcmMessage,
          unreadDelta: isActiveConversation ? 0 : 1,
        );
      } catch (_) {}

      try {
        _openedChatsCache.addMessage(fcmMessage.senderId, fcmMessage);
      } catch (_) {}

      _onNewMessage?.call(fcmMessage);
      _globalNewMessageController.add(fcmMessage);

      await _localStorage.receiveMessage(
        incomingMessage: fcmMessage,
        currentUserId: effectiveCurrentUserId,
      );

      if (!isActiveConversation) {
        unawaited(_removeClearedUnreadOverride(fcmMessage.senderId));
      }
      debugPrint(
        ' ChatEngineService: [DeliveryPath] Source: FCM/NOTIFICATION | Active chat open: '
        '$isActiveConversation',
      );
      if (isActiveConversation) {
        debugPrint(
          ' ChatEngineService: [DeliveryPath] Chat already open → suppress notification banner, '
          'mark read immediately.',
        );
      } else {
        debugPrint(
          ' ChatEngineService: [DeliveryPath] User is outside chat → rely on local '
          'notification/badge.',
        );
      }

      // WhatsApp-like: immediately acknowledge delivery/read
      // Use backend 'both' status when chat is open to minimize races.
      if ((fcmMessage.id).isNotEmpty) {
        if (_chatRepository.isConnected) {
          try {
            if (isActiveConversation) {
              debugPrint(
                ' ChatEngineService: [Scenario] FCM path: active chat open → BOTH (delivered+read) via SOCKET for ${fcmMessage.id}',
              );
              await _chatRepository.updateMessageStatusViaSocket(
                messageId: fcmMessage.id,
                status: 'both',
              );
            } else {
              // Delivered ack via socket only
              debugPrint(
                ' ChatEngineService: [Scenario] FCM path: ack DELIVERED via SOCKET for ${fcmMessage.id}',
              );
              await _chatRepository.updateMessageStatusViaSocket(
                messageId: fcmMessage.id,
                status: 'delivered',
              );
            }
          } catch (e) {
            debugPrint(
              ' ChatEngineService: Failed to emit FCM delivery/read ack via socket: $e',
            );
          }
        } else {
          // Socket-only: queue delivery/read acks to flush after reconnection
          final ok = await _markMessagesDeliveredViaRest(
            messageIds: [fcmMessage.id],
            receiverDeliveryChannel: 'fcm',
          );
          if (!ok) {
            unawaited(_enqueuePendingDeliveredIds([fcmMessage.id]));
          }
          if (isActiveConversation) {
            unawaited(_enqueuePendingReadIds([fcmMessage.id]));
          }
          debugPrint(
            ' ChatEngineService: Socket offline during FCM; queued delivered/read ack for later flush',
          );
        }
      }

      if (_activeConversationUserId == fcmMessage.senderId) {
        unawaited(() async {
          final updatedMessages = await _loadConversationFromLocal(
            fcmMessage.senderId,
          );
          _openedChatsCache.cacheMessages(fcmMessage.senderId, updatedMessages);
          _onMessagesUpdated?.call(updatedMessages);
        }());
      }

      debugPrint(' ChatEngineService: FCM message saved successfully');
    } catch (e) {
      debugPrint(' ChatEngineService: Error saving FCM message: $e');
    }
  }
}
