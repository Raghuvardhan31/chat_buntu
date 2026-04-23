part of '../chat_engine_service.dart';

mixin ChatEngineSocketProcessorMixin on ChatEngineServiceBase {
  Future<void> _handleIncomingMessageInternal(
    ChatMessageModel incomingMessage,
  ) async {
    try {
      final verboseLogs = ChatEngineService._verboseLogs;

      // Always show incoming message channel for debugging
      if (kDebugMode) {
        final preview = incomingMessage.message.length > 30
            ? '${incomingMessage.message.substring(0, 30)}...'
            : incomingMessage.message;
        debugPrint(
          '\n📥 INCOMING MESSAGE: ${incomingMessage.id.length > 20 ? incomingMessage.id.substring(0, 20) : incomingMessage.id}...',
        );
        debugPrint('   📡 Channel: WebSocket');
        debugPrint(
          '   👤 From: ${incomingMessage.senderId.length > 8 ? incomingMessage.senderId.substring(0, 8) : incomingMessage.senderId}...',
        );
        debugPrint('   💬 Preview: $preview');
      }

      if (_isDeleteTombstoneMessage(incomingMessage)) {
        await _handleMessageDeletedWithMeta(
          incomingMessage.id,
          deletedBy: incomingMessage.senderId,
          deleteType: 'everyone',
          deletedAt: incomingMessage.createdAt,
        );
        return;
      }

      if (verboseLogs && kDebugMode) {
        debugPrint('');
        debugPrint(' ChatEngineService: [WEBSOCKET] NEW MESSAGE RECEIVED!');
        debugPrint('');

        debugPrint(' ChatEngineService: Message ID: ${incomingMessage.id}');
        debugPrint(' ChatEngineService: From: ${incomingMessage.senderId}');
        debugPrint(' ChatEngineService: Message: ${incomingMessage.message}');
        debugPrint(
          ' ChatEngineService: [RECEIVED] Device message received via SOCKET: id=${incomingMessage.id}, '
          'sender=${incomingMessage.senderId}, receiver=${incomingMessage.receiverId}',
        );
        debugPrint(
          ' ChatEngineService: Active conversation: ${_activeConversationUserId ?? "NONE"}',
        );
        debugPrint('');

        debugPrint(
          ' ChatEngineService: [Scenario] SOCKET path: _handleIncomingMessage(id: ${incomingMessage.id}, sender: ${incomingMessage.senderId})',
        );
      }

      // WHATSAPP-STYLE: Start foreground service temporarily when receiving message

      final isActiveConversation =
          _activeConversationUserId == incomingMessage.senderId;

      if (!isActiveConversation) {
        unawaited(_removeClearedUnreadOverride(incomingMessage.senderId));
      }
      if (verboseLogs && kDebugMode) {
        debugPrint(
          ' ChatEngineService: [DeliveryPath] Source: SOCKET | Active chat open: '
          '$isActiveConversation',
        );
        if (isActiveConversation) {
          debugPrint(
            ' ChatEngineService: [DeliveryPath] Chat open → update UI instantly, suppress notification.',
          );
        } else {
          debugPrint(
            ' ChatEngineService: [DeliveryPath] Chat closed → notification/badge should alert the user.',
          );
        }
      }

      if (_currentUserId == null) {
        if (verboseLogs && kDebugMode) {
          debugPrint(
            ' ChatEngineService: Cannot handle incoming message - no current user',
          );
        }
        return;
      }

      // Check if message already exists in DB to prevent duplicate processing
      if (incomingMessage.id.isNotEmpty) {
        try {
          final existing = await MessagesTable.instance.getMessageById(
            incomingMessage.id,
          );
          if (existing != null) {
            // If an FCM-sourced record exists, prefer the socket-sourced message
            final existingChannel =
                existing[MessagesTable.columnDeliveryChannel] as String?;
            if (existingChannel != null &&
                existingChannel.toLowerCase() == 'fcm') {
              if (verboseLogs && kDebugMode) {
                debugPrint(
                  ' ChatEngineService: Socket: Existing DB record is from FCM - prefer socket and continue: ${incomingMessage.id}',
                );
              }
              // Proceed and replace/overwrite via normal flow below
            } else {
              if (verboseLogs && kDebugMode) {
                debugPrint(
                  ' ChatEngineService: Socket: Message already present in DB (socket path) - skipping: ${incomingMessage.id}',
                );
              }
              return;
            }
          }
        } catch (e) {
          if (verboseLogs && kDebugMode) {
            debugPrint(
              ' ChatEngineService: Failed to check DB for message existence: $e',
            );
          }
          // continue - fall back to in-memory dedupe
        }
      }

      final idKey = (incomingMessage.id).isNotEmpty
          ? 'id:${incomingMessage.id}'
          : null;
      if (idKey != null && _processedMessageIds.contains(idKey)) {
        if (verboseLogs && kDebugMode) {
          debugPrint(
            ' ChatEngineService: Socket: Message ID already processed - skipping: ${incomingMessage.id}',
          );
        }
        return;
      }
      if (idKey != null) {
        _processedMessageIds.add(idKey);
      }

      // Check if message already processed to prevent FCM+WebSocket duplicates
      final messageKey =
          '${incomingMessage.senderId}_${incomingMessage.message}_${incomingMessage.createdAt.millisecondsSinceEpoch}';
      if (_processedMessageIds.contains(messageKey)) {
        if (verboseLogs && kDebugMode) {
          debugPrint(
            ' ChatEngineService: Socket: Message already processed via FCM - skipping: ${incomingMessage.message.substring(0, 20)}...',
          );
        }
        return;
      }

      _processedMessageIds.add(messageKey);
      // Prevent unbounded memory growth
      if (_processedMessageIds.length > 1000) {
        final toRemove = _processedMessageIds.take(500).toList();
        _processedMessageIds.removeAll(toRemove);
      }
      if (verboseLogs && kDebugMode) {
        debugPrint(
          ' ChatEngineService: Socket: Processing NEW message from ${incomingMessage.senderId}',
        );
      }

      // WHATSAPP-STYLE: Update UI immediately (no DB wait)
      // 1) Bump chat list in memory so last message updates instantly
      try {
        ChatListStream.instance.bumpWithMessage(
          otherUserId: incomingMessage.senderId,
          message: incomingMessage,
          unreadDelta: isActiveConversation ? 0 : 1,
        );
      } catch (_) {}
      try {
        ChatListCache.instance.bumpWithMessage(
          otherUserId: incomingMessage.senderId,
          message: incomingMessage,
          unreadDelta: isActiveConversation ? 0 : 1,
        );
      } catch (_) {}

      // 2) Keep opened chat cache fresh (instant re-open + smooth scrolling)
      try {
        _openedChatsCache.addMessage(incomingMessage.senderId, incomingMessage);
      } catch (_) {}

      // 3) Notify open chat UI instantly (ChatPageNotifier listens to this)
      _onNewMessage?.call(incomingMessage);
      _globalNewMessageController.add(incomingMessage);

      // 4) Persist to local DB (await, but UI is already updated)
      await _localStorage.receiveMessage(
        incomingMessage: incomingMessage,
        currentUserId: _currentUserId!,
      );

      // 2. Status acks (WebSocket path)
      // Use backend 'both' status when chat is open to send delivered+read
      // together, minimizing race windows.
      if ((incomingMessage.id).isNotEmpty) {
        if (_chatRepository.isConnected) {
          try {
            if (isActiveConversation) {
              if (verboseLogs && kDebugMode) {
                debugPrint(
                  ' ChatEngineService: [Scenario] SOCKET path: active chat open → BOTH (delivered+read) via SOCKET for ${incomingMessage.id}',
                );
              }
              await _chatRepository.updateMessageStatusViaSocket(
                messageId: incomingMessage.id,
                status: 'both',
              );
            } else {
              if (verboseLogs && kDebugMode) {
                debugPrint(
                  ' ChatEngineService: [Scenario] SOCKET path: ack DELIVERED via SOCKET for ${incomingMessage.id}',
                );
              }
              await _chatRepository.updateMessageStatusViaSocket(
                messageId: incomingMessage.id,
                status: 'delivered',
              );
            }
          } catch (e) {
            debugPrint(
              ' ChatEngineService: Failed to emit SOCKET delivery/read ack: $e',
            );
          }
        } else {
          // Socket-only: queue delivery/read acks to flush after reconnection
          unawaited(_enqueuePendingDeliveredIds(<String>[incomingMessage.id]));
          if (isActiveConversation) {
            unawaited(_enqueuePendingReadIds(<String>[incomingMessage.id]));
          }
        }
      }

      if (!isActiveConversation) {
        final shouldShowNotification = markNotificationShownIfFirst(
          incomingMessage.id,
        );
        if (shouldShowNotification) {
          unawaited(() async {
            try {
              // Look up contact from local DB to get device saved name (like WhatsApp)
              String senderName =
                  incomingMessage.sender?.fullName ?? 'ChatAway User';
              String? profilePic = incomingMessage.sender?.chatPictureUrl;
              final backendName =
                  senderName; // Keep original for fallback check

              final senderId = incomingMessage.senderId;
              final senderPhone = incomingMessage.sender?.mobileNo;
              if (verboseLogs && kDebugMode) {
                debugPrint(
                  ' ChatEngineService: [Socket] Looking up contact for senderId: $senderId, phone: $senderPhone',
                );
              }

              try {
                final db = await AppDatabaseManager.instance.database;

                // Method 1: Direct app_user_id lookup
                var rows = await db.query(
                  'contacts',
                  where: 'app_user_id = ?',
                  whereArgs: [senderId],
                  limit: 1,
                );

                // Method 2: Search in user_details JSON if Method 1 fails
                if (rows.isEmpty) {
                  rows = await db.rawQuery(
                    "SELECT * FROM contacts WHERE user_details LIKE ? LIMIT 1",
                    ['%"id":"$senderId"%'],
                  );
                }

                // Method 3: Try with "userId" key in JSON
                if (rows.isEmpty) {
                  rows = await db.rawQuery(
                    "SELECT * FROM contacts WHERE user_details LIKE ? LIMIT 1",
                    ['%"userId":"$senderId"%'],
                  );
                }

                // Method 4: Try by phone number (WHATSAPP-STYLE)
                if (rows.isEmpty &&
                    senderPhone != null &&
                    senderPhone.isNotEmpty) {
                  final normalizedPhone = senderPhone.replaceAll(
                    RegExp(r'[^\d]'),
                    '',
                  );
                  final lastDigits = normalizedPhone.length >= 10
                      ? normalizedPhone.substring(normalizedPhone.length - 10)
                      : normalizedPhone;
                  rows = await db.rawQuery(
                    "SELECT * FROM contacts WHERE mobile_no LIKE ? LIMIT 1",
                    ['%$lastDigits%'],
                  );
                  if (verboseLogs && kDebugMode) {
                    debugPrint(
                      ' ChatEngineService: [Socket] Method 4 (phone): ${rows.length} results',
                    );
                  }
                }

                // Method 5: Search by backend name in contacts
                final isUuidName =
                    backendName.contains('-') && backendName.length > 30;
                if (rows.isEmpty &&
                    backendName != 'ChatAway User' &&
                    !isUuidName) {
                  final lowerName = backendName.toLowerCase().trim();
                  rows = await db.rawQuery(
                    "SELECT * FROM contacts WHERE LOWER(name) LIKE ? LIMIT 1",
                    ['%$lowerName%'],
                  );
                  if (verboseLogs && kDebugMode) {
                    debugPrint(
                      ' ChatEngineService: [Socket] Method 5 (name): ${rows.length} results',
                    );
                  }
                }

                if (rows.isNotEmpty) {
                  final contact = ContactLocal.fromMap(rows.first);
                  senderName =
                      contact.preferredDisplayName; // Device saved name!
                  profilePic =
                      contact.userDetails?.chatPictureUrl ?? profilePic;
                  if (verboseLogs && kDebugMode) {
                    debugPrint(
                      ' ChatEngineService: [Socket] Found contact: $senderName',
                    );
                  }

                  // Auto-update app_user_id mapping for faster future lookups
                  if (contact.appUserId == null || contact.appUserId!.isEmpty) {
                    try {
                      await db.update(
                        'contacts',
                        {'app_user_id': senderId},
                        where: 'contact_hash = ?',
                        whereArgs: [contact.contactHash],
                      );
                    } catch (_) {}
                  }
                } else {
                  if (verboseLogs && kDebugMode) {
                    debugPrint(
                      ' ChatEngineService: [Socket] No contact found for $senderId',
                    );
                  }
                }
              } catch (e) {
                if (verboseLogs && kDebugMode) {
                  debugPrint(
                    ' ChatEngineService: [Socket] Contact lookup failed: $e',
                  );
                }
              }

              if (verboseLogs && kDebugMode) {
                debugPrint(
                  ' ChatEngineService: [Socket] Final senderName: $senderName',
                );
              }

              await _notificationService.showChatMessageNotification(
                notificationId: incomingMessage.id,
                senderName: senderName,
                messageText: incomingMessage.message,
                conversationId: incomingMessage.id,
                senderId: incomingMessage.senderId,
                senderProfilePic: profilePic,
                messageType: incomingMessage.messageType.name,
              );
            } catch (e) {
              debugPrint(
                ' ChatEngineService: Failed to show socket-based notification: $e',
              );
            }
          }());
        }
      }

      // Refresh from local DB in background (keeps cache/UI consistent without delaying)
      if (isActiveConversation) {
        unawaited(() async {
          final updatedMessages = await _loadConversationFromLocal(
            incomingMessage.senderId,
          );
          _openedChatsCache.cacheMessages(
            incomingMessage.senderId,
            updatedMessages,
          );
          _onMessagesUpdated?.call(updatedMessages);
        }());
      }

      if (verboseLogs && kDebugMode) {
        debugPrint(
          ' ChatEngineService: Incoming message flow: Server → Local DB → Delivered → Read → UI ',
        );
      }
    } catch (e) {
      debugPrint(' ChatEngineService: Error handling incoming message: $e');
    }
  }
}
