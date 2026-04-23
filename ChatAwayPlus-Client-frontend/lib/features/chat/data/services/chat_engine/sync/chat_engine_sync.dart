part of '../chat_engine_service.dart';

/// ChatEngineSyncMixin - Sync Methods
///
/// Handles synchronization:
/// - syncUnreadCountAndContacts
/// - _syncConversationWithServer
/// - _syncAllPendingIncomingMessages
/// - _persistContactsFromRest
mixin ChatEngineSyncMixin on ChatEngineServiceBase {
  /// Sync unread counts and contacts with server
  Future<void> syncUnreadCountAndContacts({
    required String reason,
    bool force = false,
  }) async {
    final service = this as ChatEngineService;
    if (service._restSyncInProgress) return;
    service._restSyncInProgress = true;
    try {
      await _syncUnreadCountAndContactsInternal(reason: reason, force: force);
    } finally {
      service._restSyncInProgress = false;
    }
  }

  Future<void> _syncUnreadCountAndContactsInternal({
    required String reason,
    bool force = false,
  }) async {
    final service = this as ChatEngineService;
    await service._flushPendingDeliveredIds();
    await service._flushPendingReadIds();

    final now = DateTime.now();
    if (!force &&
        service._lastRestSyncAt != null &&
        now.difference(service._lastRestSyncAt!) <
            ChatEngineService._minRestSyncInterval) {
      return;
    }
    service._lastRestSyncAt = now;

    final currentUserId = _currentUserId;
    final localUnreadBySender =
        currentUserId != null && currentUserId.isNotEmpty
        ? await MessagesTable.instance.getUnreadCountsBySender(
            currentUserId: currentUserId,
          )
        : <String, int>{};

    final unreadBySender = <String, int>{};
    try {
      for (final c in ChatListStream.instance.currentList) {
        final id = c.user.id;
        if (id.isEmpty) continue;
        unreadBySender[id] = 0;
      }
      final cached = ChatListCache.instance.contacts;
      if (cached != null) {
        for (final c in cached) {
          final id = c.user.id;
          if (id.isEmpty) continue;
          unreadBySender[id] = 0;
        }
      }
    } catch (_) {}

    if (unreadBySender.isEmpty) {
      unreadBySender.addAll(localUnreadBySender);
    } else {
      for (final entry in localUnreadBySender.entries) {
        unreadBySender[entry.key] = entry.value;
      }
    }

    try {
      final total = unreadBySender.values.fold<int>(0, (a, b) => a + b);
      await AppBadgePlus.updateBadge(total);
    } catch (_) {}

    ChatListStream.instance.applyUnreadCounts(unreadBySender);
    ChatListCache.instance.applyUnreadCounts(unreadBySender);

    if (!ChatEngineService._enableGetChatContactsRestSync) {
      return;
    }

    const contactsTtl = Duration(minutes: 5);
    if (!force && ChatListCache.instance.isServerSyncFresh(ttl: contactsTtl)) {
      return;
    }

    final client = http.Client();
    try {
      final remote = ChatRemoteDataSourceImpl(httpClient: client);

      final contactsResponse = await remote.getChatContacts();
      if (contactsResponse.isSuccess) {
        final contacts = contactsResponse.data ?? const [];
        await _persistContactsFromRest(contacts);
      }
    } catch (e) {
      debugPrint(
        '⚠️ [ChatEngineService] REST contacts sync failed ($reason): $e',
      );
    } finally {
      client.close();
    }
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

  Future<void> _persistContactsFromRest(List<ChatContactModel> contacts) async {
    if (contacts.isEmpty) return;
    final currentUserId = _currentUserId;
    if (currentUserId == null || currentUserId.isEmpty) return;

    try {
      final users = <Map<String, dynamic>>[];
      final messages = <Map<String, dynamic>>[];
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      for (final c in contacts) {
        final u = c.user;
        final firstName = u.firstName.isNotEmpty ? u.firstName : 'ChatAway';
        final lastName = u.lastName.isNotEmpty ? u.lastName : 'user';

        users.add({
          ChatUsersTable.columnUserId: u.id,
          ChatUsersTable.columnFirstName: firstName,
          ChatUsersTable.columnLastName: lastName,
          ChatUsersTable.columnMobileNo: u.mobileNo,
          ChatUsersTable.columnChatPictureUrl: u.chatPictureUrl,
          ChatUsersTable.columnUpdatedAt: nowMs,
        });

        final last = c.lastMessage;
        if (last == null) continue;
        if (last.id.isEmpty) continue;

        final otherUserId = u.id;
        final resolvedReceiverId = last.receiverId.isNotEmpty
            ? last.receiverId
            : (last.senderId == currentUserId ? otherUserId : currentUserId);

        messages.add({
          MessagesTable.columnId: last.id,
          MessagesTable.columnSenderId: last.senderId,
          MessagesTable.columnReceiverId: resolvedReceiverId,
          MessagesTable.columnMessage: last.message,
          MessagesTable.columnReactionsJson: last.reactionsJson,
          MessagesTable.columnIsStarred: last.isStarred ? 1 : 0,
          MessagesTable.columnIsEdited: last.isEdited ? 1 : 0,
          MessagesTable.columnEditedAt: last.editedAt?.millisecondsSinceEpoch,
          MessagesTable.columnMessageType: _toDbMessageType(last),
          MessagesTable.columnFileUrl: last.imageUrl,
          MessagesTable.columnThumbnailUrl: last.thumbnailUrl,
          MessagesTable.columnMimeType: last.mimeType,
          MessagesTable.columnFileName: last.fileName,
          MessagesTable.columnPageCount: last.pageCount,
          MessagesTable.columnFileSize: last.fileSize,
          MessagesTable.columnMessageStatus: last.messageStatus,
          MessagesTable.columnIsRead: last.isRead ? 1 : 0,
          MessagesTable.columnDeliveredAt:
              last.deliveredAt?.millisecondsSinceEpoch,
          MessagesTable.columnReadAt: last.readAt?.millisecondsSinceEpoch,
          MessagesTable.columnCreatedAt: last.createdAt.millisecondsSinceEpoch,
          MessagesTable.columnUpdatedAt: last.updatedAt.millisecondsSinceEpoch,
          MessagesTable.columnDeliveryChannel: last.deliveryChannel,
          MessagesTable.columnReceiverDeliveryChannel:
              last.receiverDeliveryChannel,
          MessagesTable.columnImageWidth: last.imageWidth,
          MessagesTable.columnImageHeight: last.imageHeight,
          MessagesTable.columnAudioDuration: last.audioDuration,
          MessagesTable.columnIsFollowUp: last.isFollowUp ? 1 : 0,
          MessagesTable.columnReplyToMessageId:
              last.replyToMessageId ?? last.replyToMessage?.id,
          MessagesTable.columnReplyToMessageText: last.replyToMessage?.message,
          MessagesTable.columnReplyToMessageSenderId:
              last.replyToMessage?.senderId,
          MessagesTable.columnReplyToMessageType:
              last.replyToMessage?.messageType.name,
        });
      }

      await ChatUsersTable.instance.upsertUsers(users);
      if (messages.isNotEmpty) {
        await MessagesTable.instance.insertOrUpdateMessages(messages);
      }

      final local = ChatLocalDataSourceImpl();
      final dbContacts = await local.getChatContactsFromLocal();
      if (dbContacts.isNotEmpty) {
        ChatListStream.instance.syncFrom(dbContacts);
        ChatListCache.instance.cacheFromServer(dbContacts);
      }
    } catch (e) {
      debugPrint('⚠️ [ChatEngineService] Persist contacts failed: $e');
    }
  }

  /// Sync conversation with server in background
  void syncConversationWithServer(String otherUserId, {bool force = false}) {
    final service = this as ChatEngineService;
    Future.microtask(() async {
      try {
        if (!service._isOnline || !_chatRepository.isConnected) {
          return;
        }

        // Skip if synced recently
        final lastSync = service._lastSyncTimestamps[otherUserId];
        if (!force && lastSync != null) {
          final timeSinceLastSync = DateTime.now().difference(lastSync);
          if (timeSinceLastSync < ChatEngineService._minSyncInterval) return;
        }

        if (service._conversationSyncInProgress.contains(otherUserId)) {
          return;
        }
        service._conversationSyncInProgress.add(otherUserId);

        try {
          if (service._historyRepository == null) {
            service._conversationSyncInProgress.remove(otherUserId);
            return;
          }
          final result = await service._historyRepository!.getChatHistory(
            otherUserId,
            page: 1,
            limit: 100,
          );

          service._lastSyncTimestamps[otherUserId] = DateTime.now();

          if (!result.isSuccess || result.data == null) {
            if (result.errorCode != 'SYNC_IN_PROGRESS') {
              debugPrint(
                ' ChatEngineService: Failed to sync with server: ${result.errorMessage}',
              );
            }
            return;
          }

          final serverMessages = result.data!.messages ?? [];

          if (serverMessages.isNotEmpty) {
            final cached = _openedChatsCache.getMessages(otherUserId);
            if (cached != null && cached.isNotEmpty) {
              final mergedById = <String, ChatMessageModel>{};
              for (final m in cached) {
                mergedById[m.id] = m;
              }
              for (final m in serverMessages) {
                if (_isDeleteTombstoneMessage(m)) {
                  mergedById[m.id] = m.copyWith(
                    message: '',
                    messageType: MessageType.deleted,
                    isEdited: false,
                  );
                  continue;
                }
                mergedById[m.id] = m;
              }
              final merged = mergedById.values.toList()
                ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
              _openedChatsCache.cacheMessages(otherUserId, merged);
              _onMessagesUpdated?.call(merged);
            } else {
              final syncedMessages = await service._loadConversationFromLocal(
                otherUserId,
              );
              _openedChatsCache.cacheMessages(otherUserId, syncedMessages);
              _onMessagesUpdated?.call(syncedMessages);
            }
          }

          if (service._activeConversationUserId == otherUserId) {
            try {
              await service.markChatMessagesAsRead();
            } catch (e) {
              debugPrint(
                ' ChatEngineService: markChatMessagesAsRead after sync failed: $e',
              );
            }
          }
        } finally {
          service._conversationSyncInProgress.remove(otherUserId);
        }
      } catch (e) {
        debugPrint(' ChatEngineService: Sync error: $e');
      }
    });
  }

  /// Sync ALL pending incoming messages when device comes online
  Future<void> syncAllPendingIncomingMessages() async {
    final service = this as ChatEngineService;
    try {
      if (_currentUserId == null) return;

      final now = DateTime.now();
      if (service._incomingSyncInProgress) return;
      if (service._lastIncomingSyncAt != null &&
          now.difference(service._lastIncomingSyncAt!) <
              ChatEngineService._minIncomingSyncInterval) {
        return;
      }
      service._incomingSyncInProgress = true;
      service._lastIncomingSyncAt = now;

      try {
        final latestMessages = await MessagesTable.instance.getLatestMessages(
          currentUserId: _currentUserId!,
        );

        if (latestMessages.isEmpty) return;

        const maxChatsToSync = 3;
        final currentUserId = _currentUserId;

        final recentPartners = <String>[];
        final seen = <String>{};
        for (final msg in latestMessages) {
          if (recentPartners.length >= maxChatsToSync) break;

          final senderId = msg['sender_id'] as String?;
          final receiverId = msg['receiver_id'] as String?;

          String? otherUserId;
          if (senderId != null && senderId != currentUserId) {
            otherUserId = senderId;
          } else if (receiverId != null && receiverId != currentUserId) {
            otherUserId = receiverId;
          }

          if (otherUserId == null || otherUserId.isEmpty) continue;
          if (seen.contains(otherUserId)) continue;
          seen.add(otherUserId);
          recentPartners.add(otherUserId);
        }

        final active = service._activeConversationUserId;
        final targets = <String>[];
        if (active != null && active.isNotEmpty) {
          targets.add(active);
        }
        for (final id in recentPartners) {
          if (id.isEmpty) continue;
          if (id == active) continue;
          targets.add(id);
        }

        for (final otherUserId in targets) {
          syncConversationWithServer(otherUserId, force: otherUserId == active);
        }
      } finally {
        service._incomingSyncInProgress = false;
      }
    } catch (e) {
      debugPrint('❌ Global sync error: $e');
    }
  }
}
