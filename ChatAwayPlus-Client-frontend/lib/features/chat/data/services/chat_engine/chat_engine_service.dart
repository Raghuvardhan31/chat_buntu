import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:chataway_plus/features/chat/models/chat_message_model.dart';
import 'package:chataway_plus/features/chat/data/socket/socket_models/index.dart';
import 'package:chataway_plus/features/chat/data/socket/websocket_repository/websocket_chat_repository.dart';
import 'package:chataway_plus/core/constants/api_url/api_urls.dart';
import 'package:chataway_plus/core/storage/token_storage.dart';
import '../local/messages_local_db.dart';
import 'package:chataway_plus/core/app_lifecycle/app_state_service.dart';
import 'package:chataway_plus/features/chat/data/repositories/helper_repos/get_chat_history_repository.dart';
import 'package:chataway_plus/features/chat/data/datasources/chat_remote_datasource.dart';
import 'package:chataway_plus/features/chat/data/datasources/chat_local_datasource.dart';
import 'package:chataway_plus/core/notifications/local/notification_local_service.dart';
import 'package:chataway_plus/core/database/app_database.dart';
import 'package:chataway_plus/features/contacts/data/models/contact_local.dart'
    hide UserStatus;
import 'package:chataway_plus/features/chat/presentation/providers/chat_list_providers/chat_list_stream.dart';
import 'package:chataway_plus/features/chat/data/cache/chat_list_cache.dart';
import 'package:http/http.dart' as http;
import 'package:chataway_plus/features/chat/data/cache/opened_chats_cache.dart';
import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:chataway_plus/core/realtime/services/user_profile_broadcast_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chataway_plus/features/contacts/data/datasources/profile_sync_storage.dart';
import 'package:chataway_plus/features/contacts/data/repositories/contacts_repository.dart';
import '../business/chat_picture_likes_service.dart';
import '../business/message_reaction_service.dart';
import 'package:chataway_plus/features/voice_call/data/services/call_listener_service.dart';
import 'package:chataway_plus/features/notifications/data/models/notification_model.dart';
import 'package:chataway_plus/features/chat/presentation/providers/chat_page_providers/notification_stream_provider.dart';
import 'package:chataway_plus/core/snackbar/app_snackbar.dart';
import 'package:chataway_plus/core/routes/navigation_service.dart';
import 'package:flutter/material.dart' show BuildContext, debugPrint, Color, Colors;

part 'utils/chat_engine_utils.dart';
part 'queues/chat_engine_pending_queue.dart';
part 'queues/chat_engine_unread_override.dart';
part 'streams/chat_engine_streams.dart';
part 'callbacks/chat_engine_callbacks.dart';
part 'processors/chat_engine_fcm_processor.dart';
part 'processors/chat_engine_socket_processor.dart';
part 'integration/chat_engine_socket_integration.dart';
part 'monitoring/chat_engine_connectivity_monitor.dart';
part 'monitoring/chat_engine_sync_timer.dart';

// NEW: Modular mixins for better code organization
part 'message/chat_engine_message_ops.dart';
part 'message/chat_engine_message_handlers.dart';
part 'conversation/chat_engine_conversation.dart';
part 'package:chataway_plus/core/realtime/mixins/user_profile_broadcast_mixin.dart';
part 'offline/chat_engine_offline.dart';
part 'send/chat_engine_send.dart';
part 'sync/chat_engine_sync.dart';

// unawaited helper is now in chat_engine/utils/chat_engine_utils.dart

abstract class ChatEngineServiceBase {
  WebSocketChatRepository get _chatRepository;
  MessagesLocalDatabaseService get _localStorage;
  NotificationLocalService get _notificationService;
  OpenedChatsCache get _openedChatsCache;

  String? get _currentUserId;
  String? get _activeConversationUserId;

  Set<String> get _processedMessageIds;

  Function(List<ChatMessageModel>)? get _onMessagesUpdated;
  Function(ChatMessageModel)? get _onNewMessage;

  StreamController<ChatMessageModel> get _globalNewMessageController;

  Future<void> _removeClearedUnreadOverride(String otherUserId);
  Future<List<ChatMessageModel>> _loadConversationFromLocal(String otherUserId);

  Future<void> _enqueuePendingReadIds(List<String> messageIds);
  Future<void> _enqueuePendingDeliveredIds(List<String> messageIds);

  Future<bool> _markMessagesDeliveredViaRest({
    required List<String> messageIds,
    String receiverDeliveryChannel,
  });

  bool markNotificationShownIfFirst(String? messageId);

  bool _isDeleteTombstoneMessage(ChatMessageModel message);

  Future<void> _handleMessageDeletedWithMeta(
    String messageId, {
    String? deletedBy,
    String? deleteType,
    DateTime? deletedAt,
  });
}

/// Unified Chat Service - Offline-First with Server Sync
///
/// Implements unified architecture:
/// 1. Server → Local Sync: Messages from server saved to local DB first, then served from local
/// 2. Client → Server + Local Sync: Messages saved to both local and server simultaneously
/// 3. Offline Support: Queue messages when offline, auto-sync when connection restored
class ChatEngineService extends ChatEngineServiceBase
    with
        ChatEnginePendingQueueMixin,
        ChatEngineUnreadOverrideMixin,
        ChatEngineStreamsMixin,
        ChatEngineCallbacksMixin,
        ChatEngineSocketIntegrationMixin,
        ChatEngineConnectivityMonitorMixin,
        ChatEngineSyncTimerMixin,
        ChatEngineFcmProcessorMixin,
        ChatEngineSocketProcessorMixin,
        // NEW: Modular mixins (order matters - dependencies first)
        ChatEngineOfflineMixin,
        ChatEngineSyncMixin,
        ChatEngineMessageOpsMixin,
        ChatEngineMessageHandlersMixin,
        ChatEngineSendMixin,
        ChatEngineConversationMixin,
        UserProfileBroadcastMixin {
  static const String _logPrefix = 'ChatEngineService';
  static const bool _verboseLogs = false;
  static ChatEngineService? _instance;

  // Core services
  @override
  final WebSocketChatRepository _chatRepository = WebSocketChatRepository();

  @override
  final MessagesLocalDatabaseService _localStorage =
      MessagesLocalDatabaseService.instance;

  @override
  final NotificationLocalService _notificationService =
      NotificationLocalService.instance;

  @override
  final OpenedChatsCache _openedChatsCache = OpenedChatsCache.instance;

  // Repository with sync API support
  GetChatHistoryRepository? _historyRepository;

  // Connection management
  bool _isOnline = true;
  bool _isInitialized = false;

  bool _isForceDisconnected = false;

  final List<_OutgoingSendAttempt> _pendingOutgoingSocketSends = [];

  @override
  String? _currentUserId;

  @override
  String? _activeConversationUserId;

  // Message deduplication to prevent FCM+WebSocket double processing
  @override
  final Set<String> _processedMessageIds = <String>{};

  final Set<String> _markReadInProgressFor = <String>{};
  final Map<String, DateTime> _lastMarkReadAtByUser = <String, DateTime>{};

  // Message queues for offline support
  final List<ChatMessageModel> _pendingMessages = [];
  final Map<String, int> _pendingMessageRetryCount = {};
  static const int _maxPendingRetries = 5;

  DateTime? _lastRestSyncAt;
  static const Duration _minRestSyncInterval = Duration(seconds: 30);

  bool _restSyncInProgress = false;

  DateTime? _lastProfileDeltaSyncAttemptAt;
  bool _profileDeltaSyncInProgress = false;

  static const String _pendingReadIdsPrefsKey = 'pending_read_message_ids_v1';

  static const String _pendingDeliveredIdsPrefsKey =
      'pending_delivered_message_ids_v1';

  static const String _clearedUnreadOverridesPrefsKey =
      'cleared_unread_overrides_v1';

  static const bool _enableGetChatContactsRestSync = true;

  final Set<String> _conversationSyncInProgress = <String>{};

  DateTime? _lastIncomingSyncAt;
  bool _incomingSyncInProgress = false;
  static const Duration _minIncomingSyncInterval = Duration(seconds: 30);

  // WHATSAPP-STYLE: Sync optimization (consolidated)
  // In-memory cache of last sync timestamps (loaded from DB on init)
  // This is a cache of ChatSyncMetadataTable for fast access
  final Map<String, DateTime> _lastSyncTimestamps = {};
  // Minimum time between syncs for same conversation (60 seconds)
  static const _minSyncInterval = Duration(seconds: 60);

  // Event callbacks are now in ChatEngineCallbacksMixin

  // Singleton pattern
  ChatEngineService._();
  static ChatEngineService get instance {
    _instance ??= ChatEngineService._();
    return _instance!;
  }

  // Message operations (editMessage, starMessage, deleteMessage, addReaction)
  // are now in ChatEngineMessageOpsMixin

  // Message handlers (_handleChatActivityUpdated, _handleStarredUpdated, etc.)
  // are now in ChatEngineMessageHandlersMixin

  // Reaction and message edit handlers are now in ChatEngineMessageHandlersMixin

  //=================================================================
  // INITIALIZATION
  //=================================================================

  /// Initialize hybrid chat service
  Future<bool> initialize(String currentUserId) async {
    try {
      // If already initialized for this user, avoid duplicate setup
      if (_isInitialized && _currentUserId == currentUserId) {
        return _chatRepository.isConnected;
      }

      _currentUserId = currentUserId;

      // Initialize history repository with sync API support (only if not already created)
      _historyRepository ??= GetChatHistoryRepository(
        remoteDataSource: ChatRemoteDataSourceImpl(httpClient: http.Client()),
        localDataSource: ChatLocalDataSourceImpl(),
      );

      // 1. Initialize local storage
      await _localStorage.initializeDatabase();

      // 2. Load pending messages from database (offline recovery)
      await loadPendingMessagesFromDB();

      // 3. Set up WebSocket event listeners BEFORE initializing socket
      // This ensures callbacks are registered when socket listeners are created
      _setupWebSocketListeners();

      // 4. Initialize WebSocket connection (this will use the callbacks we just set)
      final socketConnected = await _chatRepository.initializeSocket();

      // 5. Set up connectivity monitoring
      _setupConnectivityMonitoring();

      // 6. Start periodic sync timer
      _startPeriodicSync();

      // 7. Wire up app lifecycle listeners for WebSocket reconnection
      _setupAppLifecycleListeners();

      // 8. Initialize WebSocket-dependent services
      _initializeWebSocketServices(currentUserId);

      _isInitialized = true;
      return socketConnected;
    } catch (e) {
      debugPrint('❌ ChatEngineService init failed: $e');
      return false;
    }
  }

  /// Ensure socket is connected (called by native foreground service)
  /// This is triggered when native code detects network changes or heartbeat
  Future<void> ensureConnected() async {
    try {
      if (!_isInitialized || !_isOnline || _chatRepository.isConnected) return;
      await _chatRepository.initializeSocket();
    } catch (e) {
      debugPrint('❌ ensureConnected failed: $e');
    }
  }

  Future<void> reconnectSocket() async {
    _isForceDisconnected = false;
    try {
      _chatRepository.connectionManager.allowImmediateReconnect();
    } catch (_) {}
    await _chatRepository.initializeSocket();
  }

  /// Set up WebSocket event listeners
  void _setupWebSocketListeners() {
    _setupWebSocketListenersImpl(this);
  }

  /// Initialize WebSocket-dependent services
  void _initializeWebSocketServices(String currentUserId) {
    try {
      // Initialize picture likes service
      ChatPictureLikesService.instance.initialize(currentUserId: currentUserId);

      // Initialize message reaction service
      MessageReactionService.instance.initialize(currentUserId: currentUserId);

      // Initialize call signaling listener for incoming calls
      CallListenerService.instance.startListening();
    } catch (e) {
      debugPrint('❌ WebSocket services init failed: $e');
    }
  }

  @override
  Future<void> _handleMessageDeletedWithMeta(
    String messageId, {
    String? deletedBy,
    String? deleteType,
    DateTime? deletedAt,
  }) async {
    if (messageId.isEmpty) return;
    final currentUserId = _currentUserId;
    if (currentUserId == null || currentUserId.isEmpty) return;

    String? otherUserId;
    DateTime? deletedMessageTime;
    try {
      final existing = await MessagesTable.instance.getMessageById(messageId);
      if (existing != null) {
        final senderId = existing[MessagesTable.columnSenderId] as String?;
        final receiverId = existing[MessagesTable.columnReceiverId] as String?;
        if (senderId != null &&
            senderId.isNotEmpty &&
            receiverId != null &&
            receiverId.isNotEmpty) {
          otherUserId = senderId == currentUserId ? receiverId : senderId;
        }

        final createdAtRaw = existing[MessagesTable.columnCreatedAt];
        if (createdAtRaw is int) {
          deletedMessageTime = DateTime.fromMillisecondsSinceEpoch(
            createdAtRaw,
          );
        } else if (createdAtRaw is num) {
          deletedMessageTime = DateTime.fromMillisecondsSinceEpoch(
            createdAtRaw.toInt(),
          );
        }
      }
    } catch (_) {}

    otherUserId ??= _activeConversationUserId;

    final normalizedDeleteType = (deleteType ?? '').toLowerCase().trim();
    try {
      if (normalizedDeleteType == 'everyone') {
        await MessagesTable.instance.markMessageAsDeleted(
          messageId: messageId,
          deletedAt: deletedAt,
        );
      } else {
        await MessagesTable.instance.deleteMessage(messageId);
      }
    } catch (e) {
      debugPrint('❌ $_logPrefix: Failed to apply delete in DB: $e');
      return;
    }

    if (otherUserId != null && otherUserId.isNotEmpty) {
      final actorId = (deletedBy != null && deletedBy.trim().isNotEmpty)
          ? deletedBy.trim()
          : currentUserId;
      final activityTime = deletedAt ?? deletedMessageTime ?? DateTime.now();
      final activity = ChatLastActivityModel(
        type: 'message_deleted',
        actorId: actorId,
        emoji: null,
        deleteType: deleteType,
        messageId: messageId,
        timestamp: activityTime,
      );

      try {
        ChatListCache.instance.applyLastActivity(
          otherUserId: otherUserId,
          activity: activity,
        );
      } catch (_) {}

      try {
        ChatListStream.instance.applyLastActivity(
          otherUserId: otherUserId,
          activity: activity,
        );
      } catch (_) {}
    }

    if (otherUserId != null && otherUserId.isNotEmpty) {
      _openedChatsCache.invalidate(otherUserId);
    }

    final activeOtherUserId = _activeConversationUserId;
    if (activeOtherUserId != null &&
        activeOtherUserId.isNotEmpty &&
        (otherUserId == null || otherUserId == activeOtherUserId)) {
      try {
        final updatedMessages = await _loadConversationFromLocal(
          activeOtherUserId,
        );
        _openedChatsCache.cacheMessages(activeOtherUserId, updatedMessages);
        _onMessagesUpdated?.call(updatedMessages);
      } catch (e) {
        debugPrint('❌ $_logPrefix: Failed to refresh UI after delete: $e');
      }
    }

    unawaited(ChatListStream.instance.reloadDebounced(replaceExisting: true));

    try {
      _messageDeletedStreamController.add(messageId);
    } catch (_) {}
  }

  /// Set up connectivity monitoring
  void _setupConnectivityMonitoring() {
    _setupConnectivityMonitoringImpl(this);
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    _onConnectivityChangedImpl(this, results);
  }

  /// Set up app lifecycle listeners for WebSocket reconnection
  void _setupAppLifecycleListeners() {
    _setupAppLifecycleListenersImpl(this);
  }

  /// Handle app resume - reconnect WebSocket if disconnected
  /// WhatsApp-like: Mark user as ONLINE when app comes to foreground
  Future<void> _handleAppResume() async {
    return _handleAppResumeImpl(this);
  }

  // Sync methods (syncUnreadCountAndContacts, _persistContactsFromRest)
  // are now in ChatEngineSyncMixin

  /// Handle app pause - prepare for background/sleep
  /// WhatsApp-like: Mark user as OFFLINE when app goes to background
  void _handleAppPause() {
    _handleAppPauseImpl(this);
  }

  //=================================================================
  // REQUIREMENT 1: SERVER → LOCAL → UI SYNC
  //=================================================================

  /// Save FCM message to local database
  /// Used when FCM notifications contain message data that needs to be persisted
  Future<void> saveFCMMessage(ChatMessageModel fcmMessage) async {
    return _saveFCMMessageInternal(fcmMessage);
  }

  /// Handle incoming message from server
  /// Flow: Server WebSocket → Save to Local DB → Load from Local DB → Update UI
  Future<void> _handleIncomingMessage(ChatMessageModel incomingMessage) async {
    return _handleIncomingMessageInternal(incomingMessage);
  }

  // Message status updates are now in ChatEngineMessageHandlersMixin

  /// Load conversation messages from local database
  @override
  Future<List<ChatMessageModel>> _loadConversationFromLocal(
    String otherUserId,
  ) async {
    try {
      if (_currentUserId == null) {
        debugPrint(
          ' ChatEngineService: Cannot load conversation - no current user',
        );
        return [];
      }

      return await _localStorage.loadConversationHistory(
        currentUserId: _currentUserId!,
        otherUserId: otherUserId,
        limit: 200,
      );
    } catch (e) {
      debugPrint(' ChatEngineService: Error loading from local DB: $e');
      return [];
    }
  }

  //=================================================================
  // REQUIREMENT 2: CLIENT → LOCAL + SERVER SYNC
  //=================================================================

  // sendMessage and sendMessageSilently are now in ChatEngineSendMixin

  /// Send message to server asynchronously
  void _sendToServerAsync(ChatMessageModel message) {
    Future.microtask(() async {
      try {
        if (_verboseLogs && kDebugMode) {
          debugPrint(
            ' ChatEngineService: Starting async send for message: ${message.id}',
          );
        }

        if (!_isOnline || _currentUserId == null) {
          // Truly offline (or no user): queue for later.
          if (_verboseLogs && kDebugMode) {
            debugPrint(
              ' ChatEngineService: Offline/no user - queuing message for offline sync',
            );
            debugPrint('   • _isOnline: $_isOnline');
            debugPrint('   • _currentUserId: $_currentUserId');
          }
          await queueMessageForOfflineSync(message);
          try {
            _onMessageStatusChanged?.call(message.id, 'pending_sync');
          } catch (_) {}
          return;
        }

        if (_verboseLogs && kDebugMode) {
          debugPrint('');
          debugPrint(
            ' ChatEngineService: EMITTING MESSAGE TO WEBSOCKET SERVER',
          );
          debugPrint('');
        }

        final socketMessageType = () {
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
            case MessageType.location:
              return 'location';
            case MessageType.poll:
              return 'poll';
            default:
              return 'text';
          }
        }();

        final metadata = () {
          if (message.fileName == null &&
              message.fileSize == null &&
              message.pageCount == null &&
              message.imageWidth == null &&
              message.imageHeight == null) {
            return null;
          }
          final map = <String, dynamic>{
            'fileName': message.fileName,
            'fileSize': message.fileSize,
            'pageCount': message.pageCount,
            'imageWidth': message.imageWidth,
            'imageHeight': message.imageHeight,
          };
          map.removeWhere((_, v) => v == null);
          return map.isEmpty ? null : map;
        }();

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

          if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
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

        final canTrySocket = _chatRepository.isConnected;
        if (canTrySocket) {
          _pendingOutgoingSocketSends.add(
            _OutgoingSendAttempt(message: message, createdAt: DateTime.now()),
          );
        }

        if (kDebugMode) {
          debugPrint('🔍 [ChatEngineService] Pre-send validation:');
          debugPrint('   • Local ID: ${message.id}');
          debugPrint('   • Receiver ID: ${message.receiverId}');
          debugPrint('   • Socket message type: $socketMessageType');
          debugPrint(
            '   • Message content: "${message.message}" (length=${message.message.length})',
          );
          debugPrint('   • Current user ID: $_currentUserId');
          debugPrint('   • Is online: $_isOnline');
          debugPrint(
            '   • Repository connected: ${_chatRepository.isConnected}',
          );
        }

        final success = canTrySocket
            ? await _chatRepository.sendMessage(
                receiverId: message.receiverId,
                message: message.message,
                messageType: socketMessageType,
                clientMessageId: message.id,
                fileUrl: message.imageUrl,
                mimeType: message.mimeType,
                fileMetadata: metadata,
                isFollowUp: message.isFollowUp,
                audioDuration: message.audioDuration,
                imageWidth: message.imageWidth,
                imageHeight: message.imageHeight,
                videoThumbnailUrl: videoThumbnailUrl,
                replyToMessageId: message.replyToMessageId,
              )
            : false;

        if (!success && canTrySocket) {
          _pendingOutgoingSocketSends.removeWhere(
            (a) => a.message.id == message.id,
          );
        }

        if (_verboseLogs && kDebugMode) {
          debugPrint(
            ' ChatEngineService: WebSocket emit result: ${success ? "SUCCESS " : "FAILED "}',
          );
        }

        if (success) {
          if (_verboseLogs && kDebugMode) {
            debugPrint(
              ' ChatEngineService: WebSocket send successful, updating to "sent"',
            );
          }
          // Update status to 'sent' in DB only (UI will be updated by server confirmation)
          await _updateMessageStatus(message.id, 'sent', notifyUI: false);
          if (_verboseLogs && kDebugMode) {
            debugPrint(' ChatEngineService: Socket: Message SENT ');
          }
          return;
        } else {
          if (_verboseLogs && kDebugMode) {
            debugPrint(
              ' ChatEngineService: WebSocket send failed - queuing message for offline sync',
            );
          }

          await queueMessageForOfflineSync(message);
          try {
            _onMessageStatusChanged?.call(message.id, 'pending_sync');
          } catch (_) {}
          return;
        }
      } catch (e) {
        debugPrint(' ChatEngineService: Error sending to server: $e');
        await queueMessageForOfflineSync(message);
        try {
          _onMessageStatusChanged?.call(message.id, 'pending_sync');
        } catch (_) {}
      }
    });
  }

  Future<void> _handleSocketMessageError(String error) async {
    if (_pendingOutgoingSocketSends.isEmpty) return;

    final now = DateTime.now();
    _pendingOutgoingSocketSends.removeWhere(
      (a) => now.difference(a.createdAt) > const Duration(seconds: 30),
    );
    if (_pendingOutgoingSocketSends.isEmpty) return;

    final attempt = _pendingOutgoingSocketSends.removeLast();
    final message = attempt.message;

    await queueMessageForOfflineSync(message);
    try {
      _onMessageStatusChanged?.call(message.id, 'pending_sync');
    } catch (_) {}
  }

  //=================================================================
  // REQUIREMENT 3: OFFLINE SUPPORT & AUTO-SYNC
  //=================================================================

  // Offline support methods are now in ChatEngineOfflineMixin

  /// Start periodic sync timer for reliability
  /// OPTIMIZED: 5 minutes instead of 2 for better battery life
  void _startPeriodicSync() {
    _startPeriodicSyncImpl(this);
  }

  //=================================================================
  // CONVERSATION MANAGEMENT
  //=================================================================

  // activateConversation, startConversation are now in ChatEngineConversationMixin

  // Conversation sync methods are now in ChatEngineSyncMixin

  // leaveConversation, sendTypingStatus, setActiveConversationImmediate
  // are now in ChatEngineConversationMixin

  //=================================================================
  // UTILITY METHODS
  //=================================================================

  String _generateLocalMessageId() {
    final currentUserId = _currentUserId;
    final userIdSuffix = (currentUserId != null && currentUserId.isNotEmpty)
        ? currentUserId.split('-').first
        : 'user';
    return 'local_${DateTime.now().millisecondsSinceEpoch}_$userIdSuffix';
  }

  @override
  bool _isDeleteTombstoneMessage(ChatMessageModel message) {
    if (message.id.trim().isEmpty) return false;
    if (message.messageType == MessageType.contact ||
        message.messageType == MessageType.poll ||
        message.messageType == MessageType.location) {
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

  /// Update message status in local database
  Future<void> _updateMessageStatus(
    String messageId,
    String status, {
    bool notifyUI = false, // Only notify UI when we have full server message
  }) async {
    try {
      if (_currentUserId == null) return;

      if (_verboseLogs && kDebugMode) {
        debugPrint(
          '📊 $_logPrefix: Updating message $messageId status: $status',
        );
      }

      await _localStorage.updateMessageStatus(
        messageId: messageId,
        newStatus: status,
      );

      if (_verboseLogs && kDebugMode) {
        debugPrint('✅ $_logPrefix: Message status updated in local DB');
      }

      // Don't notify UI for intermediate local updates (empty message content)
      // Only notify when server confirms with full message data
      if (notifyUI) {
        if (_verboseLogs && kDebugMode) {
          debugPrint('📱 Notifying UI about status update (in-memory)');
        }
        _onMessageStatusChanged?.call(messageId, status);
      } else {
        if (_verboseLogs && kDebugMode) {
          debugPrint(
            '📊 DB updated, skipping UI notification (will be handled by server confirmation)',
          );
        }
      }
    } catch (e) {
      debugPrint('❌ $_logPrefix: Error updating message status: $e');
    }
  }

  /// Handle message sent confirmation from server
  void _handleMessageSentConfirmation(ChatMessageModel sentMessage) {
    try {
      if (kDebugMode) {
        debugPrint(
          '\n✅ SERVER CONFIRMED: ${sentMessage.id.length > 20 ? sentMessage.id.substring(0, 20) : sentMessage.id}...',
        );
        debugPrint('   📡 Channel: WebSocket (message-sent event)');
        debugPrint('   📝 Status: ${sentMessage.messageStatus}');
        debugPrint(
          '   📐 Server dimensions: w=${sentMessage.imageWidth}, h=${sentMessage.imageHeight}',
        );
      }

      if (_currentUserId == null) {
        debugPrint(
          '❌ $_logPrefix: Cannot handle confirmation - no current user',
        );
        return;
      }

      // Run in background to avoid blocking UI thread
      Future.microtask(() async {
        try {
          final correctStatus = _getCorrectMessageStatus(
            sentMessage.messageStatus,
          );

          // Some backends omit senderId in 'message-sent' events. Default to current user.
          final effectiveSenderId =
              (sentMessage.senderId.isEmpty && _currentUserId != null)
              ? _currentUserId!
              : sentMessage.senderId;

          if (_verboseLogs && kDebugMode) {
            debugPrint(
              '⚡️ Server confirmed: ${sentMessage.id} -> status: $correctStatus',
            );

            debugPrint(
              '📱 Notifying UI about confirmed message (in-memory replacement)',
            );
          }
          final confirmedMessage = sentMessage.copyWith(
            messageStatus: correctStatus,
            senderId: effectiveSenderId,
          );
          _onNewMessage?.call(confirmedMessage);

          // CRITICAL FIX: Await ID replacement to prevent race condition with status updates
          // Previously was fire-and-forget, causing "delivered" status to fail finding message
          // when status update arrived before ID was replaced in DB
          try {
            final targetConversationUserId =
                _activeConversationUserId ?? sentMessage.receiverId;

            final localMessageId = await _localStorage.findLocalMessageId(
              messageContent: sentMessage.message,
              senderId: effectiveSenderId,
              currentUserId: _currentUserId!,
              otherUserId: targetConversationUserId,
              clientMessageId: sentMessage.clientMessageId,
            );

            if (localMessageId != null) {
              _pendingOutgoingSocketSends.removeWhere(
                (a) => a.message.id == localMessageId,
              );
              await _localStorage.replaceLocalIdWithServerId(
                localMessageId: localMessageId,
                serverMessage: confirmedMessage,
              );
              _openedChatsCache.replaceMessageId(
                otherUserId: targetConversationUserId,
                localId: localMessageId,
                serverMessage: confirmedMessage,
              );
              try {
                ChatListStream.instance.replaceLastMessage(
                  otherUserId: targetConversationUserId,
                  localMessageId: localMessageId,
                  serverMessage: confirmedMessage,
                );
              } catch (_) {}
              try {
                ChatListCache.instance.replaceLastMessage(
                  otherUserId: targetConversationUserId,
                  localMessageId: localMessageId,
                  serverMessage: confirmedMessage,
                );
              } catch (_) {}
              if (_verboseLogs && kDebugMode) {
                debugPrint(
                  '✅ DB: Replaced local ID $localMessageId with server ID ${sentMessage.id}',
                );
              }
            } else {
              await _localStorage.saveMessage(
                message: confirmedMessage,
                currentUserId: _currentUserId!,
                otherUserId: targetConversationUserId,
              );

              // If it wasn't cached before, this is a no-op.
              _openedChatsCache.addMessage(
                targetConversationUserId,
                confirmedMessage,
              );
              if (_verboseLogs && kDebugMode) {
                debugPrint(
                  '✅ DB: Saved server message ${sentMessage.id} (no local match found)',
                );
              }
            }

            // Refresh messages in background (non-blocking)
            if (_activeConversationUserId == targetConversationUserId) {
              unawaited(
                _loadConversationFromLocal(targetConversationUserId).then((
                  refreshedMessages,
                ) {
                  _openedChatsCache.cacheMessages(
                    targetConversationUserId,
                    refreshedMessages,
                  );
                  _onMessagesUpdated?.call(refreshedMessages);
                }),
              );
            }
          } catch (e) {
            debugPrint('⚠️ DB: ID replacement failed (UI already updated): $e');
          }
        } catch (e) {
          debugPrint('❌ Socket: Error handling confirmation: $e');
        }

        if (_verboseLogs && kDebugMode) {
          debugPrint(
            '🔔 ═══════════════════════════════════════════════════════',
          );
        }
      });
    } catch (e) {
      debugPrint('❌ CRITICAL: _handleMessageSentConfirmation crashed: $e');
    }
  }

  /// Get correct message status (prevent regression from read -> sent)
  String _getCorrectMessageStatus(String serverStatus) {
    // If server says 'read', keep it as 'read'
    // If server says 'delivered', keep it as 'delivered'
    // Otherwise set to 'sent' as first confirmation from server
    if (serverStatus == 'read' || serverStatus == 'delivered') {
      return serverStatus;
    }
    return 'sent';
  }

  //=================================================================
  // GETTERS
  //=================================================================

  bool get isInitialized => _isInitialized;
  bool get isOnline => _isOnline;
  bool get isConnectedToServer => _chatRepository.isConnected;
  int get pendingMessagesCount => _pendingMessages.length;
  String? get currentUserId => _currentUserId;
  String? get activeConversationUserId => _activeConversationUserId;

  Future<bool> ensureSocketReady({
    Duration timeout = const Duration(seconds: 5),
  }) {
    return _chatRepository.ensureSocketReady(timeout: timeout);
  }

  Future<Map<String, dynamic>> toggleChatPictureLike({
    required String likedUserId,
    required String targetChatPictureId,
    String? fromUserId,
    String? toUserId,
    bool? isLiked,
    String? action,
  }) {
    return _chatRepository.toggleChatPictureLike(
      likedUserId: likedUserId,
      targetChatPictureId: targetChatPictureId,
      fromUserId: fromUserId,
      toUserId: toUserId,
      isLiked: isLiked,
      action: action,
    );
  }

  Future<Map<String, dynamic>> getChatPictureLikeCount({
    required String likedUserId,
    required String targetChatPictureId,
  }) {
    return _chatRepository.getChatPictureLikeCount(
      likedUserId: likedUserId,
      targetChatPictureId: targetChatPictureId,
    );
  }

  Future<Map<String, dynamic>> checkChatPictureLikedStatus({
    required String likedUserId,
    required String targetChatPictureId,
  }) {
    return _chatRepository.checkChatPictureLikedStatus(
      likedUserId: likedUserId,
      targetChatPictureId: targetChatPictureId,
    );
  }

  Future<Map<String, dynamic>> getChatPictureLikers({
    required String likedUserId,
    required String targetChatPictureId,
    int? limit,
  }) {
    return _chatRepository.getChatPictureLikers(
      likedUserId: likedUserId,
      targetChatPictureId: targetChatPictureId,
      limit: limit,
    );
  }

  //=================================================================
  // STATUS LIKE OPERATIONS (Share Your Voice Text likes)
  //=================================================================

  Future<Map<String, dynamic>> toggleStatusLike({required String statusId}) {
    return _chatRepository.toggleStatusLike(statusId: statusId);
  }

  Future<Map<String, dynamic>> getStatusLikeCount({required String statusId}) {
    return _chatRepository.getStatusLikeCount(statusId: statusId);
  }

  Future<Map<String, dynamic>> checkStatusLikeStatus({
    required String statusId,
  }) {
    return _chatRepository.checkStatusLikeStatus(statusId: statusId);
  }

  //=================================================================
  // CLEANUP
  //=================================================================

  void dispose() {
    debugPrint('🧹 $_logPrefix: Disposing hybrid chat service');
    _connectivitySubscription?.cancel();
    _typingSubscription?.cancel();
    _messageDeletedSubscription?.cancel();
    _syncTimer?.cancel();
    _isInitialized = false;
    _currentUserId = null;
    _activeConversationUserId = null;
    _disposeStreams();
    try {
      CallListenerService.instance.stopListening();
    } catch (_) {}
  }
}

/// Simple class for message status updates (for chat list sync)
class ChatMessageStatusUpdate {
  final String messageId;
  final String status;
  final String? otherUserId; // For identifying which conversation

  ChatMessageStatusUpdate({
    required this.messageId,
    required this.status,
    this.otherUserId,
  });
}

class _OutgoingSendAttempt {
  final ChatMessageModel message;
  final DateTime createdAt;
  const _OutgoingSendAttempt({required this.message, required this.createdAt});
}
