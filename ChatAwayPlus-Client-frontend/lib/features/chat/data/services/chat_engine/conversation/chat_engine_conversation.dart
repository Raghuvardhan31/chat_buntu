part of '../chat_engine_service.dart';

/// ChatEngineConversationMixin - Conversation Management
///
/// Handles conversation lifecycle:
/// - activateConversation
/// - startConversation
/// - leaveConversation
/// - sendTypingStatus
/// - markChatMessagesAsRead
mixin ChatEngineConversationMixin on ChatEngineServiceBase {
  /// Activate a conversation with smart server sync
  Future<List<ChatMessageModel>> activateConversation(
    String otherUserId,
  ) async {
    final service = this as ChatEngineService;
    try {
      if (_currentUserId == null) {
        debugPrint(
          ' ChatEngineService: Cannot activate conversation - no current user',
        );
        return [];
      }

      service._activeConversationUserId = otherUserId;
      _chatRepository.joinChat(otherUserId);
      _processedMessageIds.clear();

      // WHATSAPP-STYLE: Prefer in-memory cache for instant reopen
      final cachedMessages = _openedChatsCache.getMessages(otherUserId);
      if (cachedMessages != null) {
        _onMessagesUpdated?.call(cachedMessages);
        service.syncConversationWithServer(otherUserId);

        // IMPORTANT: Cache can be stale if a new message arrived while this chat
        // was closed. Do a cheap local DB check (limit=1). If DB is newer than
        // cache, refresh cache + UI immediately.
        unawaited(() async {
          try {
            if (_currentUserId == null || _currentUserId!.isEmpty) return;

            // If user navigated away quickly, avoid refreshing wrong chat.
            if (service._activeConversationUserId != otherUserId) return;

            final latestLocal = await _localStorage.loadConversationHistory(
              currentUserId: _currentUserId!,
              otherUserId: otherUserId,
              limit: 1,
              offset: 0,
            );
            if (latestLocal.isEmpty) return;

            final latestLocalMsg = latestLocal.first;

            // If cache already contains the latest DB message, no refresh needed.
            if (cachedMessages.isNotEmpty &&
                cachedMessages.any((m) => m.id == latestLocalMsg.id)) {
              return;
            }

            // Fallback: refresh from local DB (fast) to guarantee latest message.
            final refreshed = await service._loadConversationFromLocal(
              otherUserId,
            );
            if (service._activeConversationUserId != otherUserId) return;
            _openedChatsCache.cacheMessages(otherUserId, refreshed);
            _onMessagesUpdated?.call(refreshed);
          } catch (_) {}
        }());

        return cachedMessages;
      }

      // Load from local database (instant UI)
      final localMessages = await service._loadConversationFromLocal(
        otherUserId,
      );
      _openedChatsCache.cacheMessages(otherUserId, localMessages);
      _onMessagesUpdated?.call(localMessages);

      // Sync with server in background
      service.syncConversationWithServer(otherUserId);

      return localMessages;
    } catch (e) {
      debugPrint(' ChatEngineService: Error activating conversation: $e');
      return [];
    }
  }

  /// Start a conversation - loads messages from local DB first
  Future<List<ChatMessageModel>> startConversation(String otherUserId) async {
    final service = this as ChatEngineService;
    try {
      if (_currentUserId == null) {
        debugPrint(
          ' ChatEngineService: Cannot start conversation - no current user',
        );
        return [];
      }

      service._activeConversationUserId = otherUserId;
      _chatRepository.joinChat(otherUserId);
      _processedMessageIds.clear();

      // WHATSAPP-STYLE: Prefer in-memory cache for instant reopen
      final cachedMessages = _openedChatsCache.getMessages(otherUserId);
      if (cachedMessages != null) {
        _onMessagesUpdated?.call(cachedMessages);
        service.syncConversationWithServer(otherUserId);

        // IMPORTANT: Cache can be stale if a new message arrived while this chat
        // was closed. Do a cheap local DB check (limit=1). If DB is newer than
        // cache, refresh cache + UI immediately.
        unawaited(() async {
          try {
            if (_currentUserId == null || _currentUserId!.isEmpty) return;
            if (service._activeConversationUserId != otherUserId) return;

            final latestLocal = await _localStorage.loadConversationHistory(
              currentUserId: _currentUserId!,
              otherUserId: otherUserId,
              limit: 1,
              offset: 0,
            );
            if (latestLocal.isEmpty) return;

            final latestLocalMsg = latestLocal.first;
            if (cachedMessages.isNotEmpty &&
                cachedMessages.any((m) => m.id == latestLocalMsg.id)) {
              return;
            }

            final refreshed = await service._loadConversationFromLocal(
              otherUserId,
            );
            if (service._activeConversationUserId != otherUserId) return;
            _openedChatsCache.cacheMessages(otherUserId, refreshed);
            _onMessagesUpdated?.call(refreshed);
          } catch (_) {}
        }());

        return cachedMessages;
      }

      // Load immediately from local database
      final localMessages = await service._loadConversationFromLocal(
        otherUserId,
      );
      _openedChatsCache.cacheMessages(otherUserId, localMessages);
      _onMessagesUpdated?.call(localMessages);

      // Sync with server in background
      service.syncConversationWithServer(otherUserId);

      return localMessages;
    } catch (e) {
      debugPrint(' ChatEngineService: Error starting conversation: $e');
      return [];
    }
  }

  /// Leave conversation
  void leaveConversation(String otherUserId) {
    final service = this as ChatEngineService;

    // Send stop typing event before leaving to clear typing indicator
    if (_currentUserId != null && _currentUserId!.isNotEmpty) {
      try {
        _chatRepository.sendTypingStatus(
          senderId: _currentUserId!,
          receiverId: otherUserId,
          isTyping: false,
        );
      } catch (e) {
        debugPrint('Error sending stop typing on leave: $e');
      }
    }

    service._activeConversationUserId = null;
    _chatRepository.leaveChat(otherUserId);
  }

  /// Send typing status
  void sendTypingStatus({
    required String senderId,
    required String receiverId,
    required bool isTyping,
  }) {
    _chatRepository.sendTypingStatus(
      senderId: senderId,
      receiverId: receiverId,
      isTyping: isTyping,
    );
  }

  /// Set active conversation IMMEDIATELY for notification suppression
  void setActiveConversationImmediate(String otherUserId) {
    final service = this as ChatEngineService;
    service._activeConversationUserId = otherUserId;
  }

  /// Mark all received messages in current chat as read
  Future<void> markChatMessagesAsRead() async {
    final service = this as ChatEngineService;
    final otherUserId = service._activeConversationUserId;
    bool lockAcquired = false;
    try {
      if (_currentUserId == null || service._activeConversationUserId == null) {
        return;
      }

      if (otherUserId != null && otherUserId.isNotEmpty) {
        if (service._markReadInProgressFor.contains(otherUserId)) {
          return;
        }
        final lastAt = service._lastMarkReadAtByUser[otherUserId];
        if (lastAt != null &&
            DateTime.now().difference(lastAt) < const Duration(seconds: 2)) {
          return;
        }
        service._markReadInProgressFor.add(otherUserId);
        lockAcquired = true;

        ChatListStream.instance.applyUnreadCounts(<String, int>{
          otherUserId: 0,
        });
        ChatListCache.instance.applyUnreadCounts(<String, int>{otherUserId: 0});

        await service._addClearedUnreadOverride(otherUserId);
      }

      var messageIds = await MessagesTable.instance.getUnreadMessageIds(
        currentUserId: _currentUserId!,
        otherUserId: service._activeConversationUserId!,
      );

      if (messageIds.isEmpty) {
        return;
      }

      debugPrint('⚡ [READ] ${messageIds.length} unread → read (instant)');

      await MessagesTable.instance.markMessagesAsRead(messageIds: messageIds);

      bool socketOk = false;
      if (_chatRepository.isConnected) {
        socketOk = await _chatRepository.updateMessageStatusBatch(
          messageIds: messageIds,
          status: 'read',
        );
      }

      if (!socketOk) {
        await _enqueuePendingReadIds(messageIds);
        unawaited(service._flushPendingReadIds());
      } else {
        try {
          await service._removePendingReadIds(messageIds.toSet());
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('❌ ChatEngineService: Error marking messages as read: $e');
    } finally {
      if (lockAcquired && otherUserId != null && otherUserId.isNotEmpty) {
        service._markReadInProgressFor.remove(otherUserId);
        service._lastMarkReadAtByUser[otherUserId] = DateTime.now();
      }
    }
  }
}
