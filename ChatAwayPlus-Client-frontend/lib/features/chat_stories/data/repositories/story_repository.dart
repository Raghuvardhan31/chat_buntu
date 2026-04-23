import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:chataway_plus/features/chat/data/socket/websocket_repository/websocket_chat_repository.dart';
import 'package:chataway_plus/features/chat/data/services/chat_engine/index.dart';
import 'package:chataway_plus/features/chat/data/media/media_upload_service.dart';
import 'package:chataway_plus/core/storage/token_storage.dart';
import 'package:chataway_plus/features/chat_stories/data/services/local/contacts_stories_local_db.dart';
import 'package:chataway_plus/features/chat_stories/data/services/local/my_stories_local_db.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../socket/story_socket_exports.dart';

/// Repository for Chat Stories WebSocket operations
///
/// Handles all story-related socket communication including:
/// - Creating stories
/// - Fetching contacts' stories
/// - Fetching my stories
/// - Marking stories as viewed
/// - Getting story viewers
/// - Deleting stories
///
/// Follows the same patterns as WebSocketChatRepository.
class StoryRepository {
  // ═══════════════════════════════════════════════════════════════════════════
  // SINGLETON PATTERN
  // ═══════════════════════════════════════════════════════════════════════════

  static final StoryRepository _instance = StoryRepository._internal();
  factory StoryRepository() => _instance;
  static StoryRepository get instance => _instance;
  StoryRepository._internal();

  // ═══════════════════════════════════════════════════════════════════════════
  // EMITTERS & HANDLERS
  // ═══════════════════════════════════════════════════════════════════════════

  final StoryEmitter _storyEmitter = const StoryEmitter();
  final StoryEventsHandler _storyEventsHandler = const StoryEventsHandler();
  final MediaUploadService _mediaUploadService = MediaUploadService.instance;

  /// Get the WebSocket chat repository instance
  WebSocketChatRepository get _chatRepository =>
      WebSocketChatRepository.instance;

  // ═══════════════════════════════════════════════════════════════════════════
  // PENDING REQUESTS TRACKING
  // ═══════════════════════════════════════════════════════════════════════════

  final Map<String, Completer<StoryAckResponse>> _pendingRequests = {};

  static const String _pendingViewedStoriesPrefsKey =
      'pending_viewed_story_ids_v1';
  bool _pendingViewedFlushInProgress = false;
  Timer? _pendingViewedRetryTimer;
  int _pendingViewedRetryAttempt = 0;

  // ═══════════════════════════════════════════════════════════════════════════
  // STREAM CONTROLLERS
  // ═══════════════════════════════════════════════════════════════════════════

  final StreamController<StoryCreatedEvent> _storyCreatedController =
      StreamController<StoryCreatedEvent>.broadcast();
  final StreamController<StoryViewedEvent> _storyViewedController =
      StreamController<StoryViewedEvent>.broadcast();
  final StreamController<StoryDeletedEvent> _storyDeletedController =
      StreamController<StoryDeletedEvent>.broadcast();
  final StreamController<List<UserStoriesGroup>> _contactsStoriesController =
      StreamController<List<UserStoriesGroup>>.broadcast();
  final StreamController<List<StoryModel>> _myStoriesController =
      StreamController<List<StoryModel>>.broadcast();

  // ═══════════════════════════════════════════════════════════════════════════
  // PUBLIC STREAMS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Stream of new stories from contacts
  Stream<StoryCreatedEvent> get storyCreatedStream =>
      _storyCreatedController.stream;

  /// Stream of story view events (when someone views my story)
  Stream<StoryViewedEvent> get storyViewedStream =>
      _storyViewedController.stream;

  /// Stream of story deleted events
  Stream<StoryDeletedEvent> get storyDeletedStream =>
      _storyDeletedController.stream;

  /// Stream of contacts' stories (grouped by user)
  Stream<List<UserStoriesGroup>> get contactsStoriesStream =>
      _contactsStoriesController.stream;

  /// Stream of my stories
  Stream<List<StoryModel>> get myStoriesStream => _myStoriesController.stream;

  // ═══════════════════════════════════════════════════════════════════════════
  // STATE
  // ═══════════════════════════════════════════════════════════════════════════

  bool _isInitialized = false;
  bool _isListeningToConnection = false;
  StreamSubscription<bool>? _connectionSubscription;

  /// Cached contacts stories
  List<UserStoriesGroup> _cachedContactsStories = [];
  List<UserStoriesGroup> get contactsStories => _cachedContactsStories;

  /// Cached my stories
  List<StoryModel> _cachedMyStories = [];
  List<StoryModel> get myStories => _cachedMyStories;

  // ═══════════════════════════════════════════════════════════════════════════
  // SOCKET ACCESS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get the socket from WebSocketChatRepository's connection manager
  io.Socket? get socket => _chatRepository.connectionManager.socket;

  /// Check if socket is connected
  bool get isConnected => _chatRepository.isConnected;

  // ═══════════════════════════════════════════════════════════════════════════
  // INITIALIZATION
  // ═══════════════════════════════════════════════════════════════════════════

  /// Initialize story event listeners
  ///
  /// This should be called after the main socket is connected.
  /// It will also listen for connection changes to re-initialize when reconnected.
  void initialize() {
    // Start listening to connection changes if not already
    _setupConnectionListener();

    // Try to initialize if socket is already connected
    _tryInitializeSocket();
  }

  /// Set up listener for connection state changes
  void _setupConnectionListener() {
    if (_isListeningToConnection) return;
    _isListeningToConnection = true;

    // Listen to ChatEngineService connection stream
    _connectionSubscription = ChatEngineService.instance.connectionStream.listen(
      (isConnected) {
        if (kDebugMode) {
          debugPrint(
            '📡 StoryRepository: Connection changed - isConnected=$isConnected',
          );
        }
        if (isConnected) {
          // Small delay to ensure socket is fully ready
          Future.delayed(const Duration(milliseconds: 500), () {
            _tryInitializeSocket();
            _flushPendingViewedStories();
          });
        } else {
          try {
            _pendingViewedRetryTimer?.cancel();
            _pendingViewedRetryTimer = null;
            _pendingViewedRetryAttempt = 0;
          } catch (_) {}
          // Mark as not initialized so we re-register on reconnect
          _isInitialized = false;
        }
      },
      onError: (e) {
        if (kDebugMode) {
          debugPrint('⚠️ StoryRepository: Connection stream error - $e');
        }
      },
    );
  }

  Future<void> enqueuePendingViewedStoryId(String storyId) async {
    final id = storyId.trim();
    if (id.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing =
          prefs.getStringList(_pendingViewedStoriesPrefsKey) ?? <String>[];
      final merged = <String>{...existing, id}.toList();
      await prefs.setStringList(_pendingViewedStoriesPrefsKey, merged);

      if (isConnected) {
        Future<void>.delayed(const Duration(milliseconds: 500), () {
          _flushPendingViewedStories();
        });
      }
    } catch (_) {}
  }

  Future<List<String>> _getPendingViewedStoryIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_pendingViewedStoriesPrefsKey) ?? <String>[];
    } catch (_) {
      return <String>[];
    }
  }

  Future<void> _removePendingViewedStoryIds(Set<String> idsToRemove) async {
    if (idsToRemove.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing =
          prefs.getStringList(_pendingViewedStoriesPrefsKey) ?? <String>[];
      if (existing.isEmpty) return;
      final updated = existing
          .where((id) => !idsToRemove.contains(id))
          .toList();
      await prefs.setStringList(_pendingViewedStoriesPrefsKey, updated);
    } catch (_) {}
  }

  Future<void> _flushPendingViewedStories() async {
    if (_pendingViewedFlushInProgress) return;
    _pendingViewedFlushInProgress = true;
    try {
      if (!isConnected) return;
      const maxLoops = 10;
      for (var i = 0; i < maxLoops; i++) {
        final pending = await _getPendingViewedStoryIds();
        if (pending.isEmpty) return;
        if (!isConnected) return;

        final id = pending.first.trim();
        if (id.isEmpty) {
          await _removePendingViewedStoryIds({pending.first});
          continue;
        }

        try {
          final response = await markStoryViewed(
            storyId: id,
            timeout: const Duration(seconds: 5),
          );
          if (response.success) {
            await _removePendingViewedStoryIds({id});
            _pendingViewedRetryAttempt = 0;
            try {
              _pendingViewedRetryTimer?.cancel();
              _pendingViewedRetryTimer = null;
            } catch (_) {}
            continue;
          }

          _schedulePendingViewedRetry();
          return;
        } catch (_) {
          _schedulePendingViewedRetry();
          return;
        }
      }
    } finally {
      _pendingViewedFlushInProgress = false;
    }
  }

  void _schedulePendingViewedRetry() {
    if (!isConnected) return;
    if (_pendingViewedRetryTimer != null) return;

    _pendingViewedRetryAttempt = (_pendingViewedRetryAttempt + 1).clamp(1, 6);
    final delaySeconds = (2 << _pendingViewedRetryAttempt).clamp(5, 60).toInt();
    _pendingViewedRetryTimer = Timer(Duration(seconds: delaySeconds), () {
      _pendingViewedRetryTimer = null;
      _flushPendingViewedStories();
    });
  }

  /// Try to initialize socket event handlers
  void _tryInitializeSocket() {
    if (_isInitialized) return;

    final currentSocket = socket;
    if (currentSocket == null || !isConnected) {
      if (kDebugMode) {
        debugPrint(
          '⚠️ StoryRepository: Cannot initialize - socket is null or not connected',
        );
      }
      return;
    }

    _storyEventsHandler.register(
      socket: currentSocket,
      onStoryAck: _handleStoryAck,
      onStoryCreated: _handleStoryCreated,
      onStoryViewed: _handleStoryViewed,
      onStoryDeleted: _handleStoryDeleted,
    );

    _isInitialized = true;
    if (kDebugMode) {
      debugPrint('✅ StoryRepository: Initialized');
    }
  }

  /// Dispose resources
  void dispose() {
    _connectionSubscription?.cancel();
    _connectionSubscription = null;
    _isListeningToConnection = false;

    final currentSocket = socket;
    if (currentSocket != null) {
      _storyEventsHandler.unregister(currentSocket);
    }

    _storyCreatedController.close();
    _storyViewedController.close();
    _storyDeletedController.close();
    _contactsStoriesController.close();
    _myStoriesController.close();

    _pendingRequests.clear();
    _isInitialized = false;
    if (kDebugMode) {
      debugPrint('✅ StoryRepository: Disposed');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // EVENT HANDLERS
  // ═══════════════════════════════════════════════════════════════════════════

  void _handleStoryAck(StoryAckResponse ack) {
    if (kDebugMode) {
      debugPrint(
        '📥 StoryRepository: Received ack - action=${ack.action}, success=${ack.success}',
      );
    }

    // Complete pending request if exists
    final completer = _pendingRequests.remove(ack.requestId);
    if (completer != null && !completer.isCompleted) {
      completer.complete(ack);
    }

    // Update cached data based on action
    switch (ack.action) {
      case 'get-contacts':
        if (ack.success) {
          _cachedContactsStories = ack.contactsStories;
          _contactsStoriesController.add(_cachedContactsStories);
        }
        break;

      case 'get-my':
        if (ack.success) {
          // Sort stories by createdAt ascending (oldest first) to maintain upload order
          // Story 1 stays as 1, Story 2 stays as 2, etc.
          final stories = ack.storyList;
          stories.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          _cachedMyStories = stories;
          _myStoriesController.add(_cachedMyStories);
        }
        break;

      case 'create':
        if (ack.success && ack.story != null) {
          // Add new story to end of my stories cache (maintain upload order)
          _cachedMyStories = [..._cachedMyStories, ack.story!];
          _myStoriesController.add(_cachedMyStories);
        }
        break;

      case 'delete':
        // Refresh my stories after delete
        if (ack.success) {
          fetchMyStories();
        }
        break;
    }
  }

  void _handleStoryCreated(StoryCreatedEvent event) {
    if (kDebugMode) {
      debugPrint('📥 StoryRepository: Story created by ${event.userName}');
    }
    _storyCreatedController.add(event);

    // Refresh contacts stories
    fetchContactsStories();
  }

  void _handleStoryViewed(StoryViewedEvent event) {
    if (kDebugMode) {
      debugPrint(
        '📥 StoryRepository: Story ${event.storyId} viewed by ${event.viewerName}',
      );
    }
    _storyViewedController.add(event);

    // Update view count in cached my stories
    final index = _cachedMyStories.indexWhere((s) => s.id == event.storyId);
    if (index != -1) {
      final story = _cachedMyStories[index];
      _cachedMyStories[index] = story.copyWith(
        viewsCount: story.viewsCount + 1,
      );
      _myStoriesController.add(_cachedMyStories);
    }
  }

  void _handleStoryDeleted(StoryDeletedEvent event) {
    if (kDebugMode) {
      debugPrint('📥 StoryRepository: Story ${event.storyId} deleted');
    }
    _storyDeletedController.add(event);

    // Remove from contacts stories in-memory cache
    for (var group in _cachedContactsStories) {
      group.stories.removeWhere((s) => s.id == event.storyId);
    }
    _cachedContactsStories.removeWhere((g) => g.stories.isEmpty);
    _contactsStoriesController.add(_cachedContactsStories);

    // Also remove from local DB so it doesn't reappear from cache
    _deleteStoryFromLocalDb(event.storyId);
  }

  /// Remove a deleted story from both contacts and my-stories local DB tables
  Future<void> _deleteStoryFromLocalDb(String storyId) async {
    try {
      final currentUserId = await TokenSecureStorage.instance
          .getCurrentUserIdUUID();
      if (currentUserId == null || currentUserId.isEmpty) return;

      await ContactsStoriesLocalDatabaseService.instance.deleteStory(
        currentUserId: currentUserId,
        storyId: storyId,
      );
      await MyStoriesLocalDatabaseService.instance.deleteStory(
        currentUserId: currentUserId,
        storyId: storyId,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '⚠️ StoryRepository: Failed to delete story from local DB: $e',
        );
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PUBLIC API METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Create a new story via socket
  ///
  /// Upload media to S3 first, then create story with the returned URL via socket.
  Future<StoryAckResponse> createStory({
    required File mediaFile,
    File? thumbnailFile,
    String? caption,
    int? duration,
    String? backgroundColor,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (!_isInitialized) initialize();

    try {
      _chatRepository.connectionManager.allowImmediateReconnect();
    } catch (_) {}

    final ready = await _chatRepository.ensureSocketReady(
      timeout: const Duration(seconds: 6),
    );
    if (!ready) {
      throw Exception('Socket not ready');
    }

    final currentSocket = socket;
    if (currentSocket == null || !isConnected) {
      throw Exception('Socket not connected');
    }

    // Step 1: Upload media to S3 via story upload endpoint
    // Client-generated thumbnail is sent along with video
    if (kDebugMode) {
      debugPrint('📤 StoryRepository: Uploading story media...');
    }
    final uploadResponse = await _mediaUploadService.uploadStoryMedia(
      mediaFile: mediaFile,
      thumbnailFile: thumbnailFile,
    );
    if (kDebugMode) {
      debugPrint(
        '✅ StoryRepository: Media uploaded - ${uploadResponse.mediaUrl}',
      );
      debugPrint('✅ StoryRepository: Media type - ${uploadResponse.mediaType}');
      if (uploadResponse.thumbnailUrl != null) {
        debugPrint(
          '✅ StoryRepository: Thumbnail - ${uploadResponse.thumbnailUrl}',
        );
      }
      if (uploadResponse.videoDuration != null) {
        debugPrint(
          '✅ StoryRepository: Video duration - ${uploadResponse.videoDuration}s',
        );
      }
    }

    // Step 2: Create story via socket with video fields
    final requestId = _storyEmitter.createStory(
      socket: currentSocket,
      mediaUrl: uploadResponse.mediaUrl,
      mediaType: uploadResponse.mediaType,
      caption: caption,
      duration: duration,
      backgroundColor: backgroundColor,
      thumbnailUrl: uploadResponse.thumbnailUrl,
      videoDuration: uploadResponse.videoDuration,
    );

    return _waitForResponse(requestId, timeout);
  }

  /// Fetch stories from all contacts
  Future<StoryAckResponse> fetchContactsStories({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (!_isInitialized) initialize();

    final currentSocket = socket;
    if (currentSocket == null || !isConnected) {
      throw Exception('Socket not connected');
    }

    final requestId = _storyEmitter.getContactsStories(socket: currentSocket);
    return _waitForResponse(requestId, timeout);
  }

  /// Fetch my own stories
  Future<StoryAckResponse> fetchMyStories({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (!_isInitialized) initialize();

    final currentSocket = socket;
    if (currentSocket == null || !isConnected) {
      throw Exception('Socket not connected');
    }

    final requestId = _storyEmitter.getMyStories(socket: currentSocket);
    return _waitForResponse(requestId, timeout);
  }

  /// Fetch a specific user's stories
  Future<StoryAckResponse> fetchUserStories({
    required String userId,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (!_isInitialized) initialize();

    final currentSocket = socket;
    if (currentSocket == null || !isConnected) {
      throw Exception('Socket not connected');
    }

    final requestId = _storyEmitter.getUserStories(
      socket: currentSocket,
      userId: userId,
    );
    return _waitForResponse(requestId, timeout);
  }

  /// Mark a story as viewed
  Future<StoryAckResponse> markStoryViewed({
    required String storyId,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (!_isInitialized) initialize();

    final currentSocket = socket;
    if (currentSocket == null || !isConnected) {
      throw Exception('Socket not connected');
    }

    final requestId = _storyEmitter.markStoryViewed(
      socket: currentSocket,
      storyId: storyId,
    );
    return _waitForResponse(requestId, timeout);
  }

  /// Get viewers for a story (owner only)
  Future<StoryAckResponse> getStoryViewers({
    required String storyId,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (!_isInitialized) initialize();

    final currentSocket = socket;
    if (currentSocket == null || !isConnected) {
      throw Exception('Socket not connected');
    }

    final requestId = _storyEmitter.getStoryViewers(
      socket: currentSocket,
      storyId: storyId,
    );
    return _waitForResponse(requestId, timeout);
  }

  /// Delete a story (owner only)
  Future<StoryAckResponse> deleteStory({
    required String storyId,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (!_isInitialized) initialize();

    final currentSocket = socket;
    if (currentSocket == null || !isConnected) {
      throw Exception('Socket not connected');
    }

    final requestId = _storyEmitter.deleteStory(
      socket: currentSocket,
      storyId: storyId,
    );
    return _waitForResponse(requestId, timeout);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPER METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Wait for a response matching the request ID
  Future<StoryAckResponse> _waitForResponse(
    String requestId,
    Duration timeout,
  ) async {
    final completer = Completer<StoryAckResponse>();
    _pendingRequests[requestId] = completer;

    // Set up timeout
    Timer(timeout, () {
      if (!completer.isCompleted) {
        _pendingRequests.remove(requestId);
        completer.completeError(
          TimeoutException('Story request timed out', timeout),
        );
      }
    });

    return completer.future;
  }

  /// Refresh all story data
  Future<void> refreshAll() async {
    try {
      await Future.wait([fetchContactsStories(), fetchMyStories()]);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ StoryRepository: Error refreshing stories - $e');
      }
    }
  }
}
