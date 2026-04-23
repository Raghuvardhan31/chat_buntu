part of '../chat_engine_service.dart';

mixin ChatEngineSocketIntegrationMixin {
  StreamSubscription<TypingStatus>? _typingSubscription;
  StreamSubscription<Map<String, dynamic>>? _messageDeletedSubscription;
}

void _setupWebSocketListenersImpl(ChatEngineService service) {
  final verboseLogs = ChatEngineService._verboseLogs;

  if (verboseLogs && kDebugMode) {
    debugPrint('');
    debugPrint(' ChatEngineService: SETTING UP WEBSOCKET EVENT LISTENERS');
    debugPrint('');
  }

  // Don't clear callbacks - just set them up
  // Clearing callbacks here was causing messages to not be received

  service._chatRepository.onNewMessage((dynamic incomingMessage) {
    if (verboseLogs && kDebugMode) {
      debugPrint(' ChatEngineService: onNewMessage CALLBACK TRIGGERED!');
    }
    if (incomingMessage is ChatMessageModel) {
      // Run in background to avoid blocking UI thread
      Future.microtask(() => service._handleIncomingMessage(incomingMessage));
    } else {
      if (verboseLogs && kDebugMode) {
        debugPrint(
          ' ChatEngineService: Received non-ChatMessageModel: ${incomingMessage.runtimeType}',
        );
      }
    }
  });
  if (verboseLogs && kDebugMode) {
    debugPrint(' ChatEngineService: onNewMessage callback REGISTERED');
  }

  service._chatRepository.onMessageSent((dynamic sentMessage) {
    if (verboseLogs && kDebugMode) {
      debugPrint(' ChatEngineService: onMessageSent CALLBACK TRIGGERED!');
      debugPrint('   Type: ${sentMessage.runtimeType}');
      debugPrint('   Is ChatMessageModel: ${sentMessage is ChatMessageModel}');
    }
    if (sentMessage is ChatMessageModel) {
      if (verboseLogs && kDebugMode) {
        debugPrint(
          '   ChatEngineService: Calling _handleMessageSentConfirmation...',
        );
      }
      service._handleMessageSentConfirmation(sentMessage);
      try {
        service._messageSentStreamController.add(sentMessage);
      } catch (_) {}
    } else {
      if (verboseLogs && kDebugMode) {
        debugPrint(
          '   ChatEngineService: NOT a ChatMessageModel, skipping confirmation handler',
        );
      }
    }
  });
  if (verboseLogs && kDebugMode) {
    debugPrint(' ChatEngineService: onMessageSent callback REGISTERED');
  }

  service._chatRepository.onMessageError((error) {
    Future.microtask(() => service._handleSocketMessageError(error));
  });

  service._chatRepository.onForceDisconnect((payload) {
    service._isForceDisconnected = true;
    try {
      service._forceDisconnectController.add(payload);
    } catch (_) {}
  });

  service._chatRepository.setOnMessageStatusUpdate((statusUpdate) {
    if (verboseLogs && kDebugMode) {
      debugPrint(
        ' ChatEngineService: onMessageStatusUpdate CALLBACK TRIGGERED!',
      );
    }
    service.handleMessageStatusUpdate(statusUpdate);
  });
  if (verboseLogs && kDebugMode) {
    debugPrint(' ChatEngineService: onMessageStatusUpdate callback REGISTERED');
  }

  service._chatRepository.onMessageEdited((payload) {
    Future.microtask(() => service.handleMessageEdited(payload));
  });

  service._chatRepository.onEditMessageError((error) {
    debugPrint(' ChatEngineService: edit-message-error: $error');
    try {
      service._onEditMessageError?.call(error);
    } catch (_) {}
  });

  service._chatRepository.onDeleteMessageError((error) {
    debugPrint(' ChatEngineService: delete-message-error: $error');
    try {
      service._onDeleteMessageError?.call(error);
    } catch (_) {}
  });

  service._chatRepository.onReactionUpdated((payload) {
    Future.microtask(() => service.handleReactionUpdated(payload));
  });

  service._chatRepository.onChatActivityUpdated((payload) {
    Future.microtask(() => service.handleChatActivityUpdated(payload));
  });

  service._chatRepository.onReactionError((error) {
    debugPrint(' ChatEngineService: reaction-error: $error');
    try {
      service._onReactionError?.call(error);
    } catch (_) {}
  });

  service._chatRepository.onMessageStarred((payload) {
    Future.microtask(() => service.handleStarredUpdated(payload));
  });

  service._chatRepository.onMessageUnstarred((payload) {
    Future.microtask(() => service.handleStarredUpdated(payload));
  });

  service._chatRepository.onStarMessageError((error) {
    debugPrint(' ChatEngineService: star-message-error: $error');
    try {
      service._onStarMessageError?.call(error);
    } catch (_) {}
  });

  service._chatRepository.onUnstarMessageError((error) {
    debugPrint(' ChatEngineService: unstar-message-error: $error');
    try {
      service._onUnstarMessageError?.call(error);
    } catch (_) {}
  });

  // NEW: Handle WhatsApp-style persistent notifications and reactions
  service._chatRepository.onReactionAdded((payload) {
    if (verboseLogs && kDebugMode) {
      debugPrint(' ChatEngineService: onReactionAdded CALLBACK TRIGGERED!');
    }
    Future.microtask(() => service.handleReactionUpdated(payload));
  });

  service._chatRepository.onNewNotification((payload) {
    if (verboseLogs && kDebugMode) {
      debugPrint(' ChatEngineService: onNewNotification CALLBACK TRIGGERED!');
    }
    try {
      final notification = NotificationModel.fromJson(payload);
      
      // 1. Update UI Notification Provider via Stream
      NotificationStreamController().notifyNewPersistentNotification(notification);

      // 2. Show In-App SnackBar if context available
      final context = NavigationService.currentContext;
      if (context != null) {
        AppSnackbar.showTopInfo(context, notification.message);
      }
    } catch (e) {
      debugPrint('❌ ChatEngineService: Error handling new-notification: $e');
    }
  });

  service._chatRepository.onUserStatusChanged((status) {
    try {
      service._onUserStatusChanged?.call(status);
    } catch (_) {}
    try {
      service._userStatusStreamController.add(status);
    } catch (_) {}
  });

  service._typingSubscription?.cancel();
  service._typingSubscription = service._chatRepository.onTyping.listen((
    typingStatus,
  ) {
    try {
      service._typingStreamController.add(typingStatus);
    } catch (_) {}
  });

  service._messageDeletedSubscription?.cancel();
  service._messageDeletedSubscription = service
      ._chatRepository
      .messageDeletedStream
      .listen((payload) {
        final messageId = payload['messageId']?.toString() ?? '';
        if (messageId.trim().isEmpty) return;
        final deletedBy = payload['deletedBy']?.toString();
        final deleteType = payload['deleteType']?.toString();
        DateTime? deletedAt;
        try {
          final raw = payload['deletedAt'];
          if (raw is DateTime) {
            deletedAt = raw;
          } else if (raw is int) {
            deletedAt = DateTime.fromMillisecondsSinceEpoch(raw);
          } else if (raw is num) {
            deletedAt = DateTime.fromMillisecondsSinceEpoch(raw.toInt());
          } else if (raw != null) {
            deletedAt = DateTime.tryParse(raw.toString());
          }
        } catch (_) {}
        Future.microtask(
          () => service._handleMessageDeletedWithMeta(
            messageId,
            deletedBy: deletedBy,
            deleteType: deleteType,
            deletedAt: deletedAt,
          ),
        );
      });

  // WHATSAPP-STYLE: Listen for profile updates from contacts
  service._chatRepository.onProfileUpdated((profileUpdate) {
    service.handleProfileUpdateInternal(profileUpdate);
  });
  service._chatRepository.onConnectionChanged(
    onConnected: () {
      service._isOnline = true;
      service._isForceDisconnected = false;
      service._onConnectionChanged?.call(true);
      try {
        service._connectionStreamController.add(true);
      } catch (_) {}

      // CRITICAL: Set user presence to online so backend knows we can receive notifications
      try {
        service._chatRepository.setUserPresence(isOnline: true);
      } catch (e) {
        debugPrint('❌ [ChatEngine] Failed to set user presence: $e');
      }

      service.syncPendingMessages(); // Auto-sync queued OUTGOING messages

      // Flush queued delivered/read acknowledgements (WhatsApp-style)
      unawaited(service._flushPendingDeliveredIds());
      unawaited(service._flushPendingReadIds());

      // CRITICAL: Fetch ALL pending INCOMING messages from server
      // This is what WhatsApp does when device comes online
      final allowIncomingSync =
          !AppStateService.instance.isAppInBackground ||
          (service._activeConversationUserId != null &&
              service._activeConversationUserId!.isNotEmpty);
      if (allowIncomingSync) {
        unawaited(
          Future<void>.delayed(const Duration(seconds: 2), () async {
            service.syncAllPendingIncomingMessages();
          }),
        );
      }

      // Re-join active chat and refresh user status after reconnection
      if (service._activeConversationUserId != null) {
        final activeUserId = service._activeConversationUserId!;
        service._chatRepository.joinChat(activeUserId);
        service.syncConversationWithServer(activeUserId);

        // SAFETY SYNC: After reconnection, if a chat is open, ensure any
        // unread messages in this conversation are marked as READ. This
        // self-heals cases where read acks were missed during offline window.
        Future.microtask(() async {
          try {
            await service.markChatMessagesAsRead();
          } catch (_) {}
        });
      }
    },
    onDisconnected: () {
      service._onConnectionChanged?.call(false);
      try {
        service._connectionStreamController.add(false);
      } catch (_) {}

      if (service._isForceDisconnected) return;
      if (!service._isOnline) return;

      // DON'T auto-reconnect when app is in background (screen locked)
      // The socket will reconnect automatically when app resumes via _handleAppResume
      // This prevents spam of failed reconnect attempts when network is unavailable
      if (AppStateService.instance.isAppInBackground) {
        if (kDebugMode) {
          debugPrint(
            '💤 App in background - skipping auto-reconnect (will reconnect on resume)',
          );
        }
        return;
      }

      // EXPONENTIAL BACKOFF: Smart auto-reconnect with increasing delays
      // Uses backoff from SocketConnectionManager: 1s, 2s, 4s, 8s, 16s (max 30s)
      final connectionManager = service._chatRepository.connectionManager;
      if (connectionManager.canAttemptReconnect) {
        final delay = connectionManager.nextReconnectDelay;
        if (kDebugMode) {
          debugPrint(
            '🔄 Auto-reconnect scheduled in ${delay.inSeconds}s (attempt ${connectionManager.reconnectAttempts + 1})',
          );
        }
        unawaited(
          Future<void>.delayed(delay, () async {
            // Double-check app is still in foreground before reconnecting
            if (!service._chatRepository.isConnected &&
                service._isOnline &&
                AppStateService.instance.isAppInForeground) {
              await service._chatRepository.initializeSocket();
            }
          }),
        );
      } else {
        if (kDebugMode) {
          debugPrint(
            '⚠️ Max reconnect attempts reached - manual reconnect required',
          );
        }
      }
    },
  );
}

void _setupAppLifecycleListenersImpl(ChatEngineService service) {
  // Register callback for app resume (wake from sleep)
  AppStateService.instance.onAppResumed(() {
    service._handleAppResume();
  });

  // Register callback for app pause (going to sleep)
  AppStateService.instance.onAppPaused(() {
    service._handleAppPause();
  });
}

Future<void> _handleAppResumeImpl(ChatEngineService service) async {
  try {
    if (service._isForceDisconnected) {
      return;
    }
    try {
      service._chatRepository.connectionManager.allowImmediateReconnect();
    } catch (_) {}

    final needsReconnect =
        !service._chatRepository.isConnectionHealthy ||
        !service._chatRepository.isAuthenticated;

    if (needsReconnect) {
      final reconnected = await service._chatRepository.initializeSocket();

      if (reconnected) {
        service._isOnline = true;
        service._onConnectionChanged?.call(true);
        service._chatRepository.setUserPresence(isOnline: true);
        service.syncPendingMessages();

        // Refresh user status for active conversation
        if (service._activeConversationUserId != null) {
          service._chatRepository.requestUserStatus(
            service._activeConversationUserId!,
          );
          final otherUserId = service._activeConversationUserId!;
          final lastSync = service._lastSyncTimestamps[otherUserId];
          final now = DateTime.now();
          if (lastSync == null ||
              now.difference(lastSync) > const Duration(minutes: 2)) {
            service.syncConversationWithServer(otherUserId);
          }
        }
      }
    } else {
      try {
        service._chatRepository.setUserPresence(isOnline: true);
      } catch (_) {}
      if (service._activeConversationUserId != null) {
        service._chatRepository.requestUserStatus(
          service._activeConversationUserId!,
        );
        final otherUserId = service._activeConversationUserId!;
        final lastSync = service._lastSyncTimestamps[otherUserId];
        final now = DateTime.now();
        if (lastSync == null ||
            now.difference(lastSync) > const Duration(minutes: 2)) {
          service.syncConversationWithServer(otherUserId);
        }
      }
    }

    // REST fallback sync (unread count + contacts) on app foreground
    unawaited(service.syncUnreadCountAndContacts(reason: 'app_resume'));

    try {
      unawaited(ChatListStream.instance.reloadDebounced(replaceExisting: true));
    } catch (_) {}

    final activeOtherUserId = service._activeConversationUserId;
    if (activeOtherUserId != null && activeOtherUserId.isNotEmpty) {
      unawaited(
        Future(() async {
          try {
            final updatedMessages = await service._loadConversationFromLocal(
              activeOtherUserId,
            );
            service._openedChatsCache.cacheMessages(
              activeOtherUserId,
              updatedMessages,
            );
            service._onMessagesUpdated?.call(updatedMessages);
          } catch (_) {}
        }),
      );
    }

    try {
      if (!service._profileDeltaSyncInProgress) {
        final now = DateTime.now();
        final lastAttempt = service._lastProfileDeltaSyncAttemptAt;
        final shouldAttempt =
            lastAttempt == null ||
            now.difference(lastAttempt) > const Duration(minutes: 5);

        if (shouldAttempt) {
          service._lastProfileDeltaSyncAttemptAt = now;
          service._profileDeltaSyncInProgress = true;

          unawaited(
            Future(() async {
                  final shouldSync = await ProfileSyncStorage.instance
                      .needsSync(maxAge: const Duration(minutes: 5));
                  if (!shouldSync) return;

                  final count = await ContactsRepository.instance
                      .syncProfileUpdates();
                  if (kDebugMode) {
                    debugPrint(
                      '🔄 [ProfileDeltaSync] App resume delta sync complete - updated $count contact(s)',
                    );
                  }
                })
                .catchError((e) {
                  debugPrint(
                    '❌ [ProfileDeltaSync] App resume delta sync failed: $e',
                  );
                })
                .whenComplete(() {
                  service._profileDeltaSyncInProgress = false;
                }),
          );
        }
      }
    } catch (_) {
      service._profileDeltaSyncInProgress = false;
    }
  } catch (e) {
    debugPrint('❌ App resume error: $e');
  }
}

void _handleAppPauseImpl(ChatEngineService service) {
  // KEEP SOCKET ALIVE: Don't emit offline status when app goes to background
  // The socket connection stays alive - user remains "online" while app is running
  // This prevents unnecessary disconnect/reconnect cycles
  // Socket will only disconnect when:
  // 1. App is terminated/killed by OS
  // 2. Network is truly unavailable
  // 3. Server forces disconnect
  if (kDebugMode) {
    debugPrint('💤 App paused - keeping socket alive (no offline emission)');
  }
}
