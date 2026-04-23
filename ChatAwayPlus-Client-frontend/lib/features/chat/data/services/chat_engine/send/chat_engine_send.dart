part of '../chat_engine_service.dart';

/// ChatEngineSendMixin - Message Sending Logic
///
/// Handles sending messages:
/// - sendMessage (with UI updates)
/// - sendMessageSilently (background sends)
/// - _sendToServerAsync (WebSocket emit)
mixin ChatEngineSendMixin on ChatEngineServiceBase {
  /// Send message with hybrid local + server sync
  /// Flow: User Input → Save to Local DB → Update UI → Send to Server → Update Status
  Future<ChatMessageModel?> sendMessage({
    required String messageText,
    required String receiverId,
    String messageType = 'text',
    String? fileUrl,
    String? mimeType,
    String? fileName,
    int? fileSize,
    int? pageCount,
    double? audioDuration,
    String? thumbnailUrl,
    int? imageWidth,
    int? imageHeight,
    bool? isFollowUp,
    String? replyToMessageId,
    ChatMessageModel? replyToMessage,
  }) async {
    final service = this as ChatEngineService;
    try {
      if (_currentUserId == null) {
        debugPrint(' ChatEngineService: Cannot send message - no current user');
        return null;
      }

      final shouldQueueImmediately =
          !service._isOnline || _currentUserId == null;

      // 1. Create message with local ID and timestamp
      final localMessage = ChatMessageModel(
        id: service._generateLocalMessageId(),
        senderId: _currentUserId!,
        receiverId: receiverId,
        message: messageText,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        messageStatus: shouldQueueImmediately ? 'pending_sync' : 'sending',
        isRead: false,
        messageType: ChatMessageModel.parseMessageType(messageType),
        imageUrl: fileUrl,
        mimeType: mimeType,
        fileName: fileName,
        fileSize: fileSize,
        pageCount: pageCount,
        audioDuration: audioDuration,
        thumbnailUrl: thumbnailUrl,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
        isFollowUp: isFollowUp ?? false,
        replyToMessageId: replyToMessageId,
        replyToMessage: replyToMessage,
      );

      if (kDebugMode) {
        debugPrint(
          '📤 [ChatEngineService] sendMessage prepared localId=${localMessage.id} receiverId=$receiverId messageType=$messageType',
        );
      }

      // 2. Save to LOCAL DATABASE immediately (optimistic update)
      await _localStorage.saveMessage(
        message: localMessage,
        currentUserId: _currentUserId!,
        otherUserId: receiverId,
      );

      // WHATSAPP-STYLE: Bump chat to top immediately in chat list
      if (kDebugMode) {
        debugPrint(
          '📨 [ChatEngineService] sendMessage: Bumping chat list with msg ${localMessage.id.substring(0, 8)}...',
        );
      }
      try {
        ChatListStream.instance.bumpWithMessage(
          otherUserId: receiverId,
          message: localMessage,
          unreadDelta: 0,
        );
      } catch (_) {}
      try {
        ChatListCache.instance.bumpWithMessage(
          otherUserId: receiverId,
          message: localMessage,
          unreadDelta: 0,
        );
      } catch (_) {}

      // WHATSAPP-STYLE: Update opened chat cache immediately
      try {
        _openedChatsCache.addMessage(receiverId, localMessage);
      } catch (_) {}

      // 3. Update UI immediately
      if (service._activeConversationUserId == receiverId) {
        _onNewMessage?.call(localMessage);
      } else {
        try {
          final updated = await service._loadConversationFromLocal(receiverId);
          _openedChatsCache.cacheMessages(receiverId, updated);
          _onMessagesUpdated?.call(updated);
        } catch (e) {
          debugPrint(' ChatEngineService: Fallback UI refresh failed: $e');
        }
      }

      // 4. Send to server (async)
      if (shouldQueueImmediately) {
        if (kDebugMode) {
          debugPrint(
            '\n📤 MESSAGE SEND: ${localMessage.id.substring(0, 20)}...',
          );
          debugPrint('   📡 Channel: QUEUED (offline)');
        }
        await service.queueMessageForOfflineSync(localMessage);
      } else {
        if (kDebugMode) {
          debugPrint(
            '\n📤 MESSAGE SEND: ${localMessage.id.substring(0, 20)}...',
          );
          debugPrint('   📡 Channel: WebSocket');
        }
        service._sendToServerAsync(localMessage);
      }

      return localMessage;
    } catch (e) {
      debugPrint(' ChatEngineService: Error in hybrid message send: $e');
      return null;
    }
  }

  /// Send message silently (for forwarding, background sends)
  Future<ChatMessageModel?> sendMessageSilently({
    required String messageText,
    required String receiverId,
    String messageType = 'text',
    String? fileUrl,
    String? mimeType,
    String? fileName,
    int? fileSize,
    int? pageCount,
    double? audioDuration,
    String? thumbnailUrl,
    int? imageWidth,
    int? imageHeight,
  }) async {
    final service = this as ChatEngineService;
    try {
      if (_currentUserId == null) {
        debugPrint(' ChatEngineService: Cannot send message - no current user');
        return null;
      }

      final shouldQueueImmediately =
          !service._isOnline || _currentUserId == null;

      final localMessage = ChatMessageModel(
        id: service._generateLocalMessageId(),
        senderId: _currentUserId!,
        receiverId: receiverId,
        message: messageText,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        messageStatus: shouldQueueImmediately ? 'pending_sync' : 'sending',
        isRead: false,
        messageType: ChatMessageModel.parseMessageType(messageType),
        imageUrl: fileUrl,
        mimeType: mimeType,
        fileName: fileName,
        fileSize: fileSize,
        pageCount: pageCount,
        audioDuration: audioDuration,
        thumbnailUrl: thumbnailUrl,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
      );

      await _localStorage.saveMessage(
        message: localMessage,
        currentUserId: _currentUserId!,
        otherUserId: receiverId,
      );

      // Bump chat list
      try {
        ChatListStream.instance.bumpWithMessage(
          otherUserId: receiverId,
          message: localMessage,
          unreadDelta: 0,
        );
      } catch (_) {}
      try {
        ChatListCache.instance.bumpWithMessage(
          otherUserId: receiverId,
          message: localMessage,
          unreadDelta: 0,
        );
      } catch (_) {}

      // Only notify UI if user is in this conversation
      if (service._activeConversationUserId == receiverId) {
        _onNewMessage?.call(localMessage);
      }

      try {
        _openedChatsCache.addMessage(receiverId, localMessage);
      } catch (_) {}

      if (shouldQueueImmediately) {
        await service.queueMessageForOfflineSync(localMessage);
      } else {
        service._sendToServerAsync(localMessage);
      }

      return localMessage;
    } catch (e) {
      debugPrint(' ChatEngineService: Error in hybrid message send: $e');
      return null;
    }
  }
}
