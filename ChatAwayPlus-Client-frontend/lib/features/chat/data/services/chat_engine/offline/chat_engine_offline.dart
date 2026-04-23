part of '../chat_engine_service.dart';

/// ChatEngineOfflineMixin - Offline Queue Management
///
/// Handles offline message queuing:
/// - _loadPendingMessagesFromDB
/// - _queueMessageForOfflineSync
/// - _syncPendingMessages
mixin ChatEngineOfflineMixin on ChatEngineServiceBase {
  /// Load pending messages from database on app startup
  Future<void> loadPendingMessagesFromDB() async {
    final service = this as ChatEngineService;
    try {
      if (_currentUserId == null) {
        debugPrint(
          ' ChatEngineService: Cannot load pending messages - no current user',
        );
        return;
      }

      final pendingMessages = await _localStorage.loadPendingMessages(
        currentUserId: _currentUserId!,
      );

      final stuckSendingMessages = await _localStorage.loadStuckSendingMessages(
        currentUserId: _currentUserId!,
      );

      final alreadyQueuedIds = <String>{};
      for (final m in pendingMessages) {
        alreadyQueuedIds.add(m.id);
      }

      final recoveredFromSending = <ChatMessageModel>[];
      for (final m in stuckSendingMessages) {
        if (alreadyQueuedIds.contains(m.id)) continue;
        try {
          await _localStorage.updateMessageStatus(
            messageId: m.id,
            newStatus: 'pending_sync',
          );
        } catch (_) {}
        recoveredFromSending.add(m.copyWith(messageStatus: 'pending_sync'));
      }

      if (pendingMessages.isNotEmpty) {
        service._pendingMessages.addAll(pendingMessages);
        debugPrint(
          ' ChatEngineService: Loaded ${pendingMessages.length} pending messages from DB',
        );
      }

      if (recoveredFromSending.isNotEmpty) {
        service._pendingMessages.addAll(recoveredFromSending);
        debugPrint(
          ' ChatEngineService: Recovered ${recoveredFromSending.length} stuck sending messages',
        );
      }
    } catch (e) {
      debugPrint(
        ' ChatEngineService: Error loading pending messages from DB: $e',
      );
    }
  }

  /// Queue message for offline sync when no internet connection
  Future<void> queueMessageForOfflineSync(ChatMessageModel message) async {
    final service = this as ChatEngineService;
    try {
      if (_currentUserId == null) {
        debugPrint(
          ' ChatEngineService: Cannot queue message - no current user',
        );
        return;
      }

      await _localStorage.updateMessageStatus(
        messageId: message.id,
        newStatus: 'pending_sync',
      );

      if (!service._pendingMessages.any((m) => m.id == message.id)) {
        service._pendingMessages.add(message);
      }

      debugPrint(
        ' ChatEngineService: Message queued for offline sync (${service._pendingMessages.length} pending)',
      );
    } catch (e) {
      debugPrint(' ChatEngineService: Error queuing message: $e');
    }
  }

  /// Sync pending messages when connection is restored
  Future<void> syncPendingMessages() async {
    final service = this as ChatEngineService;
    if (service._pendingMessages.isEmpty || _currentUserId == null) {
      return;
    }

    try {
      debugPrint(
        ' ChatEngineService: Syncing ${service._pendingMessages.length} pending messages...',
      );

      final messagesToSync = List<ChatMessageModel>.from(
        service._pendingMessages,
      );
      service._pendingMessages.clear();

      for (final message in messagesToSync) {
        try {
          // Check retry limit before attempting
          final retries = service._pendingMessageRetryCount[message.id] ?? 0;
          if (retries >= ChatEngineService._maxPendingRetries) {
            debugPrint(
              '⚠️ ChatEngineService: Message ${message.id} exceeded max retries ($retries) - marking as failed',
            );
            await service._updateMessageStatus(message.id, 'failed');
            service._pendingMessageRetryCount.remove(message.id);
            try {
              service._onMessageStatusChanged?.call(message.id, 'failed');
            } catch (_) {}
            continue;
          }

          final socketMessageType = _getSocketMessageType(message);
          final metadata = _buildFileMetadata(message);

          final rawVideoThumb = message.thumbnailUrl;
          final looksLocalThumb = rawVideoThumb == null
              ? false
              : (rawVideoThumb.startsWith('file://') ||
                    (rawVideoThumb.startsWith('/') &&
                        !rawVideoThumb.startsWith('/api/') &&
                        !rawVideoThumb.startsWith('/uploads/')) ||
                    rawVideoThumb.contains('media_cache'));

          final normalizedVideoThumb = () {
            if (rawVideoThumb == null) return null;
            final trimmed = rawVideoThumb.trim();
            if (trimmed.isEmpty) return null;

            const streamPrefix = '/api/images/stream/';
            const chatsFilePrefix = '/chats/file/';

            if (trimmed.startsWith('http://') ||
                trimmed.startsWith('https://')) {
              final uri = Uri.tryParse(trimmed);
              final path = uri?.path;
              if (path != null) {
                final streamIndex = path.indexOf(streamPrefix);
                if (streamIndex >= 0) {
                  return path.substring(streamIndex + streamPrefix.length);
                }
                final chatsIndex = path.indexOf(chatsFilePrefix);
                if (chatsIndex >= 0) {
                  return path.substring(chatsIndex + chatsFilePrefix.length);
                }
              }
              return null;
            }

            if (trimmed.startsWith(streamPrefix)) {
              return trimmed.substring(streamPrefix.length);
            }

            if (trimmed.startsWith(chatsFilePrefix)) {
              return trimmed.substring(chatsFilePrefix.length);
            }

            final absoluteStreamPrefix = '${ApiUrls.mediaBaseUrl}$streamPrefix';
            if (trimmed.startsWith(absoluteStreamPrefix)) {
              return trimmed.substring(absoluteStreamPrefix.length);
            }

            final absoluteChatsFilePrefix =
                '${ApiUrls.apiBaseUrl}$chatsFilePrefix';
            if (trimmed.startsWith(absoluteChatsFilePrefix)) {
              return trimmed.substring(absoluteChatsFilePrefix.length);
            }

            return trimmed;
          }();

          final videoThumbnailUrl =
              socketMessageType == 'video' &&
                  normalizedVideoThumb != null &&
                  normalizedVideoThumb.trim().isNotEmpty &&
                  !looksLocalThumb
              ? normalizedVideoThumb.trim()
              : null;

          if (kDebugMode) {
            debugPrint(
              '📤 [ChatEngineService] syncPendingMessages localId=${message.id} receiverId=${message.receiverId} socketMessageType=$socketMessageType retry=$retries',
            );
          }

          final success = await _chatRepository.sendMessage(
            receiverId: message.receiverId,
            message: message.message,
            messageType: socketMessageType,
            clientMessageId: message.id,
            fileUrl: message.imageUrl,
            mimeType: message.mimeType,
            imageWidth: message.imageWidth,
            imageHeight: message.imageHeight,
            audioDuration: message.audioDuration,
            fileMetadata: metadata,
            videoThumbnailUrl: videoThumbnailUrl,
          );

          if (success) {
            await service._updateMessageStatus(message.id, 'sent');
            service._pendingMessageRetryCount.remove(message.id);
            debugPrint(' ChatEngineService: Synced message ${message.id}');
          } else {
            service._pendingMessageRetryCount[message.id] = retries + 1;
            service._pendingMessages.add(message);
          }

          await Future.delayed(Duration(milliseconds: 100));
        } catch (e) {
          debugPrint(
            ' ChatEngineService: Error syncing message ${message.id}: $e',
          );
          final retries = service._pendingMessageRetryCount[message.id] ?? 0;
          service._pendingMessageRetryCount[message.id] = retries + 1;
          service._pendingMessages.add(message);
        }
      }

      debugPrint(
        ' ChatEngineService: Sync completed. Remaining pending: ${service._pendingMessages.length}',
      );
    } catch (e) {
      debugPrint(' ChatEngineService: Error during pending message sync: $e');
    }
  }

  String _getSocketMessageType(ChatMessageModel message) {
    final mt = message.mimeType;
    final name = message.fileName;
    if (mt == 'application/pdf' ||
        message.pageCount != null ||
        (name != null && name.toLowerCase().endsWith('.pdf'))) {
      return 'pdf';
    }
    if (mt != null) {
      if (mt.startsWith('image/')) return 'image';
      if (mt.startsWith('video/')) return 'video';
      if (mt.startsWith('audio/')) return 'audio';
    }
    switch (message.messageType) {
      case MessageType.image:
        return 'image';
      case MessageType.video:
        return 'video';
      case MessageType.audio:
        return 'audio';
      case MessageType.document:
        return 'document';
      case MessageType.poll:
        return 'poll';
      default:
        return 'text';
    }
  }

  Map<String, dynamic>? _buildFileMetadata(ChatMessageModel message) {
    if (message.fileName == null &&
        message.fileSize == null &&
        message.pageCount == null) {
      return null;
    }
    final map = <String, dynamic>{
      'fileName': message.fileName,
      'fileSize': message.fileSize,
      'pageCount': message.pageCount,
    };
    map.removeWhere((_, v) => v == null);
    return map.isEmpty ? null : map;
  }
}
