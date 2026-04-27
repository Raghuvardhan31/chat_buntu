import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:chataway_plus/core/constants/api_url/api_urls.dart';
import 'package:chataway_plus/core/routes/navigation_service.dart';
import 'package:chataway_plus/core/storage/token_storage.dart';
import 'package:chataway_plus/core/notifications/notifications/chat_picture_notification.dart';
import 'package:chataway_plus/core/notifications/notifications/share_your_voice_notification.dart';
import 'package:chataway_plus/features/chat/data/cache/index.dart';
import 'package:chataway_plus/features/chat/data/socket/core/socket_auth_manager.dart';
import 'package:chataway_plus/features/chat/data/socket/core/socket_connection_manager.dart';
import 'package:chataway_plus/features/chat/data/socket/emitters/chat_picture_like_emitter.dart';
import 'package:chataway_plus/features/chat/data/socket/emitters/status_like_emitter.dart';
import 'package:chataway_plus/features/chat/data/socket/emitters/delete_emitter.dart';
import 'package:chataway_plus/features/chat/data/socket/emitters/message_emitter.dart';
import 'package:chataway_plus/features/chat/data/socket/emitters/reaction_emitter.dart';
import 'package:chataway_plus/features/chat/data/socket/emitters/star_message_emitter.dart';
import 'package:chataway_plus/features/chat/data/socket/emitters/status_emitter.dart';
import 'package:chataway_plus/features/chat/data/socket/emitters/typing_emitter.dart';
import 'package:chataway_plus/features/chat/data/socket/events/auth_events_handler.dart';
import 'package:chataway_plus/features/chat/data/socket/events/connection_events_handler.dart';
import 'package:chataway_plus/features/chat/data/socket/events/delete_events_handler.dart';
import 'package:chataway_plus/features/chat/data/socket/events/message_events_handler.dart';
import 'package:chataway_plus/features/chat/data/socket/events/message_status_events_handler.dart';
import 'package:chataway_plus/features/chat/data/socket/events/notification_events_handler.dart';
import 'package:chataway_plus/features/chat/data/socket/events/profile_events_handler.dart';
import 'package:chataway_plus/features/chat/data/socket/events/reaction_events_handler.dart';
import 'package:chataway_plus/features/chat/data/socket/events/star_message_events_handler.dart';
import 'package:chataway_plus/features/chat/data/socket/events/status_events_handler.dart';
import 'package:chataway_plus/features/chat/data/socket/events/typing_events_handler.dart';
import 'package:chataway_plus/features/chat/data/socket/socket_constants/socket_event_names.dart';
import 'package:chataway_plus/features/chat/data/socket/socket_models/index.dart';
import '../../../models/chat_message_model.dart';

/// WebSocket Chat Repository for ChatAway+ Real-time Messaging
///
/// Handles Socket.IO real-time communication for chat features
/// including messages, reactions, typing indicators, and user status.
///
/// ## File Organization:
/// 1. SINGLETON PATTERN - Instance management
/// 2. CORE STATE - Authentication, user ID, connection state
/// 3. EMITTERS - Send events to server (one per feature)
/// 4. EVENT HANDLERS - Receive events from server (one per feature)
/// 5. CALLBACKS - App-level event listeners
/// 6. STREAMS - Reactive data streams for UI
/// 7. SOCKET LIFECYCLE - Initialize, connect, disconnect
/// 8. MESSAGE OPERATIONS - Send, edit, delete messages
/// 9. REACTION OPERATIONS - Add, remove, get reactions
/// 10. STAR MESSAGE OPERATIONS - Star/unstar messages
/// 11. CHAT PICTURE LIKE OPERATIONS - Like profile pictures
/// 12. STATUS OPERATIONS - Message status, user presence
/// 13. TYPING OPERATIONS - Typing indicators
/// 14. CHAT ROOM OPERATIONS - Join/leave chat
/// 15. CALLBACK REGISTRATION - Register event callbacks
/// 16. CLEANUP - Dispose and clear resources
class WebSocketChatRepository {
  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 1: SINGLETON PATTERN
  // ═══════════════════════════════════════════════════════════════════════════

  static final WebSocketChatRepository _instance =
      WebSocketChatRepository._internal();
  factory WebSocketChatRepository() => _instance;
  static WebSocketChatRepository get instance => _instance;
  WebSocketChatRepository._internal();

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 2: CORE STATE
  // ═══════════════════════════════════════════════════════════════════════════

  static const bool _verboseLogs = false;

  final TokenSecureStorage _tokenStorage = TokenSecureStorage();
  String? _currentUserId;
  bool _isAuthenticated = false;

  bool? _pendingPresenceIsOnline;

  /// Queue for status updates that need to wait for authentication
  final List<_PendingStatusUpdate> _pendingStatusUpdates = [];

  /// Chain for serializing chat picture like operations (no requestId support)
  Future<void> _chatPictureLikeOperationChain = Future.value();

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 3: EMITTERS (Send events to server)
  // ═══════════════════════════════════════════════════════════════════════════

  final ReactionEmitter _reactionEmitter = const ReactionEmitter();
  final StarMessageEmitter _starMessageEmitter = const StarMessageEmitter();
  final TypingEmitter _typingEmitter = const TypingEmitter();
  final StatusEmitter _statusEmitter = const StatusEmitter();
  final MessageEmitter _messageEmitter = const MessageEmitter();
  final DeleteEmitter _deleteEmitter = const DeleteEmitter();
  final ChatPictureLikeEmitter _chatPictureLikeEmitter =
      const ChatPictureLikeEmitter();
  final StatusLikeEmitter _statusLikeEmitter = const StatusLikeEmitter();

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 4: CORE MANAGERS
  // ═══════════════════════════════════════════════════════════════════════════

  final SocketAuthManager _socketAuthManager = SocketAuthManager();
  final SocketConnectionManager _socketConnectionManager =
      SocketConnectionManager();

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 5: EVENT HANDLERS (Receive events from server)
  // ═══════════════════════════════════════════════════════════════════════════

  final ReactionEventsHandler _reactionEventsHandler =
      const ReactionEventsHandler();
  final StarMessageEventsHandler _starMessageEventsHandler =
      const StarMessageEventsHandler();
  final TypingEventsHandler _typingEventsHandler = const TypingEventsHandler();
  final NotificationEventsHandler _notificationEventsHandler =
      const NotificationEventsHandler();
  final AuthEventsHandler _authEventsHandler = const AuthEventsHandler();
  final ConnectionEventsHandler _connectionEventsHandler =
      const ConnectionEventsHandler();
  final MessageEventsHandler _messageEventsHandler =
      const MessageEventsHandler();
  final DeleteEventsHandler _deleteEventsHandler = const DeleteEventsHandler();
  final StatusEventsHandler _statusEventsHandler = const StatusEventsHandler();
  final MessageStatusEventsHandler _messageStatusEventsHandler =
      const MessageStatusEventsHandler();
  final ProfileEventsHandler _profileEventsHandler =
      const ProfileEventsHandler();

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 6: PUBLIC GETTERS
  // ═══════════════════════════════════════════════════════════════════════════

  bool get isAuthenticated => _isAuthenticated;

  /// Expose connection manager for exponential backoff access
  SocketConnectionManager get connectionManager => _socketConnectionManager;

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 7: SOCKET LIFECYCLE (Initialize, connect, ensure ready)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<bool> ensureSocketReady({
    Duration timeout = const Duration(seconds: 20),
  }) async {
    debugPrint('🔄 ensureSocketReady: checking...');
    debugPrint('   • isConnected: ${_socketConnectionManager.isConnected}');
    debugPrint(
      '   • socket?.connected: ${_socketConnectionManager.socket?.connected}',
    );
    debugPrint('   • _isAuthenticated: $_isAuthenticated');

    if (!_socketConnectionManager.isConnected ||
        _socketConnectionManager.socket?.connected != true) {
      debugPrint('🔄 ensureSocketReady: Socket not connected, initializing...');
      final connected = await initializeSocket();
      if (!connected) {
        debugPrint('❌ ensureSocketReady: Failed to initialize socket');
        return false;
      }
    }

    final start = DateTime.now();
    while (!_isAuthenticated) {
      final socket = _socketConnectionManager.socket;
      if (!_socketConnectionManager.isConnected || socket?.connected != true) {
        debugPrint(
          '❌ ensureSocketReady: Socket disconnected while waiting for authentication',
        );
        return false;
      }
      if (DateTime.now().difference(start) > timeout) {
        debugPrint(
          '❌ ensureSocketReady: TIMEOUT waiting for authentication (${timeout.inSeconds}s)',
        );
        return false;
      }
      await Future.delayed(const Duration(milliseconds: 50));
    }

    debugPrint('✅ ensureSocketReady: Socket ready and authenticated!');
    return true;
  }

  Future<Map<String, dynamic>> editMessage({
    required String chatId,
    required String newMessage,
    Duration timeout = const Duration(seconds: 6),
  }) async {
    final ready = await ensureSocketReady(timeout: timeout);
    if (!ready) {
      throw Exception('Socket not ready');
    }

    final socket = _socketConnectionManager.socket;
    if (socket == null ||
        !_socketConnectionManager.isConnected ||
        _currentUserId == null) {
      throw Exception('Socket not connected');
    }

    final completer = Completer<Map<String, dynamic>>();
    Timer? timer;

    late final dynamic successHandler;
    late final dynamic errorHandler;

    void cleanup() {
      timer?.cancel();
      try {
        socket.off(SocketEventNames.messageEdited, successHandler);
      } catch (_) {}
      try {
        socket.off(SocketEventNames.editMessageError, errorHandler);
      } catch (_) {}
    }

    String extractIncomingChatId(Map<String, dynamic> map) {
      return (map['chatId'] ?? map['id'] ?? map['messageId'])?.toString() ?? '';
    }

    successHandler = (dynamic data) {
      try {
        final payload = data is Map
            ? Map<String, dynamic>.from(data)
            : <String, dynamic>{};
        if (extractIncomingChatId(payload) != chatId) return;
        if (completer.isCompleted) return;
        cleanup();
        completer.complete(payload);
      } catch (e) {
        if (completer.isCompleted) return;
        cleanup();
        completer.completeError(e);
      }
    };

    errorHandler = (dynamic data) {
      try {
        final payload = data is Map
            ? Map<String, dynamic>.from(data)
            : <String, dynamic>{};
        final error = payload['error']?.toString() ?? 'Failed to edit message';
        if (completer.isCompleted) return;
        cleanup();
        completer.completeError(Exception(error));
      } catch (e) {
        if (completer.isCompleted) return;
        cleanup();
        completer.completeError(e);
      }
    };

    timer = Timer(timeout, () {
      if (completer.isCompleted) return;
      cleanup();
      completer.completeError(TimeoutException('Edit message timed out'));
    });

    socket.on(SocketEventNames.messageEdited, successHandler);
    socket.on(SocketEventNames.editMessageError, errorHandler);

    socket.emit(SocketEventNames.editMessage, {
      'chatId': chatId,
      'newMessage': newMessage,
    });

    return completer.future;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 9: DELETE MESSAGE OPERATIONS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<bool> deleteMessage({
    required String chatId,
    required String deleteType,
    Duration timeout = const Duration(seconds: 6),
  }) async {
    final ready = await ensureSocketReady(timeout: timeout);
    if (!ready) {
      return false;
    }

    final socket = _socketConnectionManager.socket;
    if (socket == null ||
        !_socketConnectionManager.isConnected ||
        _currentUserId == null) {
      return false;
    }

    return _deleteEmitter.deleteMessage(
      socket: socket,
      chatId: chatId,
      deleteType: deleteType,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 10: REACTION OPERATIONS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<bool> addReaction({
    required String messageId,
    required String emoji,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    debugPrint('📤 ═══════════════════════════════════════════════════════');
    debugPrint('📤 ChatRepository: ADD REACTION EMIT START');
    debugPrint('📤 MessageId: $messageId');
    debugPrint('📤 Emoji: $emoji');
    debugPrint('📤 ═══════════════════════════════════════════════════════');

    final ready = await ensureSocketReady(timeout: timeout);
    if (!ready) {
      debugPrint('⚠️ ChatRepository: addReaction - socket not ready');
      debugPrint('📤 ═══════════════════════════════════════════════════════');
      return false;
    }

    final socket = _socketConnectionManager.socket;
    if (socket == null ||
        !_socketConnectionManager.isConnected ||
        _currentUserId == null) {
      debugPrint('⚠️ ChatRepository: addReaction - socket not connected');
      debugPrint('  - Socket: ${socket != null}');
      debugPrint('  - Connected: ${_socketConnectionManager.isConnected}');
      debugPrint('  - UserId: $_currentUserId');
      debugPrint('📤 ═══════════════════════════════════════════════════════');
      return false;
    }

    final ok = _reactionEmitter.addReaction(
      socket: socket,
      messageId: messageId,
      emoji: emoji,
    );
    debugPrint('✅ add-reaction emitted successfully');
    debugPrint('📤 ═══════════════════════════════════════════════════════');
    return ok;
  }

  Future<bool> starMessage({
    required String chatId,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final ready = await ensureSocketReady(timeout: timeout);
    if (!ready) {
      debugPrint('⚠️ ChatRepository: starMessage - socket not ready');
      return false;
    }

    final socket = _socketConnectionManager.socket;
    if (socket == null ||
        !_socketConnectionManager.isConnected ||
        _currentUserId == null) {
      debugPrint('⚠️ ChatRepository: starMessage - socket not connected');
      return false;
    }

    return _starMessageEmitter.star(socket: socket, chatId: chatId);
  }

  Future<bool> unstarMessage({
    required String chatId,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final ready = await ensureSocketReady(timeout: timeout);
    if (!ready) {
      debugPrint('⚠️ ChatRepository: unstarMessage - socket not ready');
      return false;
    }

    final socket = _socketConnectionManager.socket;
    if (socket == null ||
        !_socketConnectionManager.isConnected ||
        _currentUserId == null) {
      debugPrint('⚠️ ChatRepository: unstarMessage - socket not connected');
      return false;
    }

    return _starMessageEmitter.unstar(socket: socket, chatId: chatId);
  }

  Future<bool> removeReaction({
    required String messageId,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final ready = await ensureSocketReady(timeout: timeout);
    if (!ready) {
      debugPrint('⚠️ ChatRepository: removeReaction - socket not ready');
      return false;
    }

    final socket = _socketConnectionManager.socket;
    if (socket == null ||
        !_socketConnectionManager.isConnected ||
        _currentUserId == null) {
      debugPrint('⚠️ ChatRepository: removeReaction - socket not connected');
      return false;
    }

    final ok = _reactionEmitter.removeReaction(
      socket: socket,
      messageId: messageId,
    );
    if (ok) {
      debugPrint(
        '✅ ChatRepository: removeReaction emitted - messageId: $messageId',
      );
    }
    return ok;
  }

  Future<bool> getMessageReactions({
    required String messageId,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final ready = await ensureSocketReady(timeout: timeout);
    if (!ready) {
      debugPrint('⚠️ ChatRepository: getMessageReactions - socket not ready');
      return false;
    }

    final socket = _socketConnectionManager.socket;
    if (socket == null || !_socketConnectionManager.isConnected) {
      debugPrint(
        '⚠️ ChatRepository: getMessageReactions - socket not connected',
      );
      return false;
    }

    final ok = _reactionEmitter.getMessageReactions(
      socket: socket,
      messageId: messageId,
    );
    if (ok) {
      debugPrint(
        '✅ ChatRepository: getMessageReactions emitted - messageId: $messageId',
      );
    }
    return ok;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 11: CHAT PICTURE LIKE OPERATIONS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<T> _enqueueChatPictureLikeOperation<T>(
    Future<T> Function() operation,
  ) {
    final completer = Completer<T>();

    _chatPictureLikeOperationChain = _chatPictureLikeOperationChain.then((
      _,
    ) async {
      try {
        completer.complete(await operation());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });

    return completer.future;
  }

  Future<Map<String, dynamic>> _emitAndWaitForChatPictureLikeResponse({
    required bool Function() emitFunction,
    required String successEvent,
    required bool Function(Map<String, dynamic> data) matches,
    Duration timeout = const Duration(seconds: 5),
  }) {
    return _enqueueChatPictureLikeOperation(() async {
      final socket = _socketConnectionManager.socket;
      if (socket == null ||
          !_socketConnectionManager.isConnected ||
          !_isAuthenticated) {
        throw Exception('Socket not ready');
      }

      final completer = Completer<Map<String, dynamic>>();

      void completeWithError(Object error) {
        if (completer.isCompleted) return;
        completer.completeError(error);
      }

      Timer? timer;

      late final dynamic successHandler;
      late final dynamic errorHandler;

      void cleanup() {
        timer?.cancel();
        try {
          socket.off(successEvent, successHandler);
        } catch (_) {}
        try {
          socket.off(SocketEventNames.chatPictureLikeError, errorHandler);
        } catch (_) {}
      }

      successHandler = (dynamic data) {
        try {
          debugPrint('🔔 [ChatPictureLike] Received $successEvent: $data');
          final map = data is Map
              ? Map<String, dynamic>.from(data)
              : <String, dynamic>{};
          debugPrint(
            '🔔 [ChatPictureLike] Parsed map keys: ${map.keys.toList()}',
          );
          if (!matches(map)) {
            debugPrint(
              '⚠️ [ChatPictureLike] Response did not match expected IDs',
            );
            return;
          }

          if (completer.isCompleted) return;
          cleanup();
          completer.complete(map);
        } catch (e) {
          cleanup();
          completeWithError(e);
        }
      };

      errorHandler = (dynamic data) {
        try {
          final map = data is Map
              ? Map<String, dynamic>.from(data)
              : <String, dynamic>{};
          final message =
              map['error']?.toString() ??
              map['message']?.toString() ??
              'Chat picture like error';
          cleanup();
          completeWithError(Exception(message));
        } catch (e) {
          cleanup();
          completeWithError(e);
        }
      };

      timer = Timer(timeout, () {
        cleanup();
        completeWithError(
          TimeoutException('Chat picture like request timed out'),
        );
      });

      socket.on(successEvent, successHandler);
      socket.on(SocketEventNames.chatPictureLikeError, errorHandler);

      // Use emitter function instead of inline emit
      final emitSuccess = emitFunction();
      if (!emitSuccess) {
        cleanup();
        throw Exception('Failed to emit chat picture like event');
      }

      return completer.future;
    });
  }

  Future<Map<String, dynamic>> toggleChatPictureLike({
    required String likedUserId,
    required String targetChatPictureId,
    String? fromUserId,
    String? toUserId,
    bool? isLiked,
    String? action,
  }) {
    return _emitAndWaitForChatPictureLikeResponse(
      emitFunction: () {
        final emitResult = _chatPictureLikeEmitter.toggle(
          socket: _socketConnectionManager.socket!,
          likedUserId: likedUserId,
          targetChatPictureId: targetChatPictureId,
          fromUserId: fromUserId,
          toUserId: toUserId,
          isLiked: isLiked,
          action: action,
        );
        return emitResult;
      },
      successEvent: SocketEventNames.chatPictureLikeToggled,
      matches: (data) {
        final incomingLikedUserId =
            (data['likedUserId'] ?? data['liked_user_id'])?.toString();
        final incomingTarget =
            (data['target_chat_picture_id'] ?? data['targetChatPictureId'])
                ?.toString();
        final incomingFromUserId = (data['fromUserId'] ?? data['from_user_id'])
            ?.toString();
        final incomingToUserId = (data['toUserId'] ?? data['to_user_id'])
            ?.toString();

        final fromUserIdExpected = fromUserId?.trim() ?? '';
        if (fromUserIdExpected.isNotEmpty) {
          if (incomingFromUserId != null &&
              incomingFromUserId.isNotEmpty &&
              incomingFromUserId != fromUserIdExpected) {
            return false;
          }
        }

        final toUserIdExpected = toUserId?.trim() ?? '';
        if (toUserIdExpected.isNotEmpty) {
          if (incomingToUserId != null &&
              incomingToUserId.isNotEmpty &&
              incomingToUserId != toUserIdExpected) {
            return false;
          }
        }

        return incomingLikedUserId == likedUserId &&
            incomingTarget == targetChatPictureId;
      },
    );
  }

  Future<Map<String, dynamic>> getChatPictureLikeCount({
    required String likedUserId,
    required String targetChatPictureId,
  }) {
    return _emitAndWaitForChatPictureLikeResponse(
      emitFunction: () => _chatPictureLikeEmitter.count(
        socket: _socketConnectionManager.socket!,
        likedUserId: likedUserId,
        targetChatPictureId: targetChatPictureId,
      ),
      successEvent: SocketEventNames.chatPictureLikeCount,
      matches: (data) {
        final incomingLikedUserId = data['likedUserId']?.toString();
        final incomingTarget =
            (data['target_chat_picture_id'] ?? data['targetChatPictureId'])
                ?.toString();
        return incomingLikedUserId == likedUserId &&
            incomingTarget == targetChatPictureId;
      },
    );
  }

  Future<Map<String, dynamic>> checkChatPictureLikedStatus({
    required String likedUserId,
    required String targetChatPictureId,
  }) {
    return _emitAndWaitForChatPictureLikeResponse(
      emitFunction: () => _chatPictureLikeEmitter.checkLikedStatus(
        socket: _socketConnectionManager.socket!,
        likedUserId: likedUserId,
        targetChatPictureId: targetChatPictureId,
      ),
      successEvent: SocketEventNames.chatPictureLikedStatus,
      matches: (data) {
        final incomingLikedUserId = data['likedUserId']?.toString();
        final incomingTarget =
            (data['target_chat_picture_id'] ?? data['targetChatPictureId'])
                ?.toString();
        return incomingLikedUserId == likedUserId &&
            incomingTarget == targetChatPictureId;
      },
    );
  }

  Future<Map<String, dynamic>> getChatPictureLikers({
    required String likedUserId,
    required String targetChatPictureId,
    int? limit,
  }) {
    return _emitAndWaitForChatPictureLikeResponse(
      emitFunction: () => _chatPictureLikeEmitter.likers(
        socket: _socketConnectionManager.socket!,
        likedUserId: likedUserId,
        targetChatPictureId: targetChatPictureId,
        limit: limit,
      ),
      successEvent: SocketEventNames.chatPictureLikers,
      matches: (data) {
        final incomingLikedUserId = data['likedUserId']?.toString();
        final incomingTarget =
            (data['target_chat_picture_id'] ?? data['targetChatPictureId'])
                ?.toString();
        return incomingLikedUserId == likedUserId &&
            incomingTarget == targetChatPictureId;
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 11B: STATUS LIKE OPERATIONS (Share Your Voice Text likes)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Chain for serializing status like operations (no requestId support)
  Future<void> _statusLikeOperationChain = Future.value();

  Future<T> _enqueueStatusLikeOperation<T>(Future<T> Function() operation) {
    final completer = Completer<T>();

    _statusLikeOperationChain = _statusLikeOperationChain.then((_) async {
      try {
        completer.complete(await operation());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });

    return completer.future;
  }

  Future<Map<String, dynamic>> _emitAndWaitForStatusLikeResponse({
    required bool Function() emitFunction,
    required String successEvent,
    required bool Function(Map<String, dynamic> data) matches,
    Duration timeout = const Duration(seconds: 5),
  }) {
    return _enqueueStatusLikeOperation(() async {
      final socket = _socketConnectionManager.socket;
      if (socket == null ||
          !_socketConnectionManager.isConnected ||
          !_isAuthenticated) {
        throw Exception('Socket not ready');
      }

      final completer = Completer<Map<String, dynamic>>();

      void completeWithError(Object error) {
        if (completer.isCompleted) return;
        completer.completeError(error);
      }

      Timer? timer;

      late final dynamic successHandler;
      late final dynamic errorHandler;

      void cleanup() {
        timer?.cancel();
        try {
          socket.off(successEvent, successHandler);
        } catch (_) {}
        try {
          socket.off(SocketEventNames.statusLikeError, errorHandler);
        } catch (_) {}
      }

      successHandler = (dynamic data) {
        try {
          final map = data is Map
              ? Map<String, dynamic>.from(data)
              : <String, dynamic>{};
          if (!matches(map)) return;

          if (completer.isCompleted) return;
          cleanup();
          completer.complete(map);
        } catch (e) {
          cleanup();
          completeWithError(e);
        }
      };

      errorHandler = (dynamic data) {
        try {
          final map = data is Map
              ? Map<String, dynamic>.from(data)
              : <String, dynamic>{};
          final message =
              map['error']?.toString() ??
              map['message']?.toString() ??
              'Status like error';
          cleanup();
          completeWithError(Exception(message));
        } catch (e) {
          cleanup();
          completeWithError(e);
        }
      };

      timer = Timer(timeout, () {
        cleanup();
        completeWithError(TimeoutException('Status like request timed out'));
      });

      socket.on(successEvent, successHandler);
      socket.on(SocketEventNames.statusLikeError, errorHandler);

      final emitSuccess = emitFunction();
      if (!emitSuccess) {
        cleanup();
        throw Exception('Failed to emit status like event');
      }

      return completer.future;
    });
  }

  Future<Map<String, dynamic>> toggleStatusLike({required String statusId}) {
    return _emitAndWaitForStatusLikeResponse(
      emitFunction: () => _statusLikeEmitter.toggle(
        socket: _socketConnectionManager.socket!,
        statusId: statusId,
      ),
      successEvent: SocketEventNames.statusLikeToggled,
      matches: (data) {
        final incomingStatusId = data['statusId']?.toString();
        return incomingStatusId == statusId;
      },
    );
  }

  Future<Map<String, dynamic>> getStatusLikeCount({required String statusId}) {
    return _emitAndWaitForStatusLikeResponse(
      emitFunction: () => _statusLikeEmitter.getLikeCount(
        socket: _socketConnectionManager.socket!,
        statusId: statusId,
      ),
      successEvent: SocketEventNames.statusLikeCount,
      matches: (data) {
        final incomingStatusId = data['statusId']?.toString();
        return incomingStatusId == statusId;
      },
    );
  }

  Future<Map<String, dynamic>> checkStatusLikeStatus({
    required String statusId,
  }) {
    return _emitAndWaitForStatusLikeResponse(
      emitFunction: () => _statusLikeEmitter.checkLikeStatus(
        socket: _socketConnectionManager.socket!,
        statusId: statusId,
      ),
      successEvent: SocketEventNames.statusLikeStatus,
      matches: (data) {
        final incomingStatusId = data['statusId']?.toString();
        return incomingStatusId == statusId;
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 12: CALLBACKS (App-level event listeners)
  // ═══════════════════════════════════════════════════════════════════════════

  Function(ChatMessageModel)? _onNewMessage;
  Function(ChatMessageModel)? _onMessageSent;
  Function(String)? _onMessageError;
  Function(Map<String, dynamic>)? _onMessageEdited;
  Function(String)? _onEditMessageError;
  Function(Map<String, dynamic>)? _onReactionUpdated;
  Function(String)? _onReactionError;
  Function(Map<String, dynamic>)? _onChatActivityUpdated;
  Function(Map<String, dynamic>)? _onMessageStarred;
  Function(Map<String, dynamic>)? _onMessageUnstarred;
  Function(String)? _onStarMessageError;
  Function(String)? _onUnstarMessageError;
  Function()? _onConnected;
  Function()? _onDisconnected;
  Function(Map<String, dynamic>)? _onMessageStatusUpdate;
  Function(UserStatus)? _onUserStatusChanged;
  Function(Map<String, dynamic>)? _onForceDisconnect;
  Function(ProfileUpdate)? _onProfileUpdated;
  Function(String)? _onDeleteMessageError;
  Function(Map<String, dynamic>)? _onNewNotification;
  Function(Map<String, dynamic>)? _onReactionAdded;

  final StreamController<Map<String, dynamic>> _messageDeletedController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get messageDeletedStream =>
      _messageDeletedController.stream;

  // Stream controller for poll vote updates
  final StreamController<Map<String, dynamic>> _pollVoteController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get pollVoteStream => _pollVoteController.stream;

  // Stream controller for typing events
  final _typingController = StreamController<TypingStatus>.broadcast();
  Stream<TypingStatus> get onTyping => _typingController.stream;

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 14: SOCKET INITIALIZATION & AUTHENTICATION
  // ═══════════════════════════════════════════════════════════════════════════

  Future<bool> initializeSocket() async {
    if (_socketConnectionManager.isConnected &&
        _socketConnectionManager.socket?.connected == true) {
      if (!_isAuthenticated) {
        try {
          _authenticateUser();
        } catch (_) {}
      }
      return true;
    }

    return _initializeSocketInternal();
  }

  Future<bool> _initializeSocketInternal() async {
    try {
      // Always reset authentication state when initializing a new socket
      // This ensures we don't use stale auth state from a previous connection
      _isAuthenticated = false;
      _socketAuthManager.setAuthenticated(false);

      // Get auth token for authentication
      // Get current user ID UUID for messaging
      // Use the current user ID UUID as the user ID for messaging
      // Create socket connection to WebSocket server
      // Set up socket event listeners
      // Manually connect after event listeners are set up
      final initResult = await _socketConnectionManager.initializeSocket(
        getAuthToken: _tokenStorage.getToken,
        getCurrentUserIdUUID: _tokenStorage.getCurrentUserIdUUID,
        serverUrl: ApiUrls.chatServerUrl,
        setupListeners: (socket) {
          _currentUserId = _socketConnectionManager.currentUserId;
          _setupSocketListeners();
        },
      );

      _currentUserId = initResult.currentUserId;
      return initResult.connected;
    } catch (e, stackTrace) {
      debugPrint('');
      debugPrint(
        '💥 ═══════════════════════════════════════════════════════════════',
      );
      debugPrint('💥 SOCKET INITIALIZATION EXCEPTION');
      debugPrint('💥 Error: $e');
      debugPrint('💥 Stack Trace:');
      debugPrint('$stackTrace');
      debugPrint(
        '💥 ═══════════════════════════════════════════════════════════════',
      );
      debugPrint('');
      return false;
    }
  }

  /// Set up socket event listeners matching backend events
  void _setupSocketListeners() {
    final socket = _socketConnectionManager.socket;
    if (socket == null) return;

    // Clear any existing listeners to prevent double registration
    socket.clearListeners();

    // Connection events
    _connectionEventsHandler.register(
      socket: socket,
      onConnect: () {
        _socketConnectionManager.setConnected(true);
        _isAuthenticated = false;
        _socketAuthManager.setAuthenticated(false);
        _onConnected?.call();
        _authenticateUser();
      },
      onConnectError: (error) {
        debugPrint('❌ Socket connection error: $error');
        _socketConnectionManager.setConnected(false);
        _isAuthenticated = false;
        _socketAuthManager.setAuthenticated(false);
      },
      onDisconnect: (reason) {
        debugPrint('🔌 Socket disconnected: $reason');
        _socketConnectionManager.setConnected(false);
        _isAuthenticated = false;
        _socketAuthManager.setAuthenticated(false);
        _onDisconnected?.call();
      },
      onError: (error) {
        debugPrint('❌ ChatRepository: Socket error: $error');
      },
    );

    // Presence: user status changed (broadcast)
    // Presence: direct response to get-user-status
    // Presence acknowledgment from backend (confirms if presence was accepted)
    _statusEventsHandler.register(
      socket: socket,
      onUserStatus: (status) {
        _onUserStatusChanged?.call(status);
      },
      onPresenceAcknowledged: (data) {
        if (kDebugMode) {
          debugPrint('✅ presence-acknowledged: $data');
        }
      },
    );

    _typingEventsHandler.register(
      socket: socket,
      onTyping: (userId, isTyping) {
        try {
          final status = TypingStatus(userId: userId, isTyping: isTyping);
          _typingController.add(status);
        } catch (e) {
          debugPrint('❌ ChatRepository: Error parsing user-typing: $e');
        }
      },
    );

    _reactionEventsHandler.register(
      socket: socket,
      onReactionUpdated: (payload) {
        _onReactionUpdated?.call(payload);
      },
      onReactionError: (error) {
        _onReactionError?.call(error);
      },
    );

    socket.on(SocketEventNames.chatActivityUpdated, (data) {
      try {
        final payload = data is Map
            ? Map<String, dynamic>.from(data)
            : <String, dynamic>{};
        if (payload.isEmpty) return;
        _onChatActivityUpdated?.call(payload);
      } catch (e) {
        debugPrint('❌ chat-activity-updated parsing: $e');
      }
    });

    _starMessageEventsHandler.register(
      socket: socket,
      onMessageStarred: (payload) {
        _onMessageStarred?.call(payload);
      },
      onMessageUnstarred: (payload) {
        _onMessageUnstarred?.call(payload);
      },
      onStarMessageError: (error) {
        _onStarMessageError?.call(error);
      },
      onUnstarMessageError: (error) {
        _onUnstarMessageError?.call(error);
      },
    );

    _notificationEventsHandler.register(
      socket: socket,
      onNotification: (payload) {
        try {
          final nested = payload['data'];
          final normalizedPayload = nested is Map
              ? <String, dynamic>{
                  ...Map<String, dynamic>.from(nested),
                  ...payload,
                }
              : payload;

          // Handle status like notifications
          if (ShareYourVoiceNotificationHandler.isShareYourVoiceNotification(
            normalizedPayload,
          )) {
            unawaited(
              ShareYourVoiceNotificationHandler.handleSocket(normalizedPayload),
            );
            return;
          }

          // Handle chat picture like notifications
          final isChatPicture =
              ChatPictureNotificationHandler.isChatPictureNotification(
                normalizedPayload,
              );
          if (!isChatPicture) return;

          final toUserId =
              (normalizedPayload['toUserId'] ??
                      normalizedPayload['to_user_id'] ??
                      normalizedPayload['likedUserId'] ??
                      normalizedPayload['liked_user_id'])
                  ?.toString();

          if (_currentUserId != null &&
              toUserId != null &&
              toUserId.isNotEmpty &&
              toUserId != _currentUserId) {
            return;
          }

          unawaited(
            ChatPictureNotificationHandler.handleSocket(normalizedPayload),
          );
        } catch (e) {
          debugPrint('❌ [WS_NOTIFY] Notification event error: $e');
        }
      },
    );

    // Chat picture like broadcast event
    socket.on(SocketEventNames.chatPictureLikeToggled, (data) {
      try {
        final payload = data is Map
            ? Map<String, dynamic>.from(data)
            : <String, dynamic>{};
        if (payload.isEmpty) return;

        // Skip if this is actually a status like (backend may reuse event)
        if (ShareYourVoiceNotificationHandler.isShareYourVoiceNotification(
          payload,
        )) {
          return;
        }

        final targetUserId =
            (payload['likedUserId'] ??
                    payload['liked_user_id'] ??
                    payload['toUserId'] ??
                    payload['to_user_id'])
                ?.toString();

        if (_currentUserId != null &&
            targetUserId != null &&
            targetUserId.isNotEmpty &&
            targetUserId == _currentUserId) {
          unawaited(ChatPictureNotificationHandler.handleSocket(payload));
        }
      } catch (e) {
        debugPrint('❌ [WS_NOTIFY] Error: $e');
      }
    });

    // Status like (SYVT) broadcast event
    socket.on(SocketEventNames.statusLikeToggled, (data) {
      try {
        final payload = data is Map
            ? Map<String, dynamic>.from(data)
            : <String, dynamic>{};
        if (payload.isEmpty) return;

        final targetUserId =
            (payload['likedUserId'] ??
                    payload['liked_user_id'] ??
                    payload['toUserId'] ??
                    payload['to_user_id'] ??
                    payload['statusOwnerId'] ??
                    payload['status_owner_id'])
                ?.toString();

        if (_currentUserId != null &&
            targetUserId != null &&
            targetUserId.isNotEmpty &&
            targetUserId == _currentUserId) {
          unawaited(ShareYourVoiceNotificationHandler.handleSocket(payload));
        }
      } catch (e) {
        debugPrint('❌ [WS_NOTIFY] Status like broadcast error: $e');
      }
    });

    _authEventsHandler.register(
      socket: socket,
      onAuthenticated: (data) {
        final payload = (data is Map)
            ? Map<String, dynamic>.from(data)
            : <String, dynamic>{};
        final success = payload['success'];
        if (success != null && success != true) {
          debugPrint(
            '❌ Socket authenticated event received with success=false: $payload',
          );
          _isAuthenticated = false;
          _socketAuthManager.setAuthenticated(false);
          return;
        }

        if (kDebugMode) {
          debugPrint('✅ socket authenticated');
        }

        // Check if userId matches
        final backendUserId = data['userId'] as String?;
        if (backendUserId != null && backendUserId != _currentUserId) {
          debugPrint(
            '⚠️ userId mismatch: backend=$backendUserId, local=$_currentUserId',
          );
        }

        _isAuthenticated = true;
        _socketAuthManager.setAuthenticated(true);
        _processPendingStatusUpdates();
        _pendingPresenceIsOnline ??= true;
        _flushPendingPresence();
      },
      onAuthenticationError: (data) {
        _isAuthenticated = false;
        _socketAuthManager.setAuthenticated(false);

        final payload = (data is Map)
            ? Map<String, dynamic>.from(data)
            : <String, dynamic>{};
        debugPrint(
          '❌ Socket authentication failed: ${payload['error'] ?? data}',
        );

        // Auto-logout user if token is invalid
        Future.microtask(() async {
          disconnect();
          ChatCacheManager.instance.clearAll();
          await _tokenStorage.clearUserData();
          await NavigationService.goToPhoneNumberEntry();
        });
      },
      onInvalidToken: (_) {
        _isAuthenticated = false;
        _socketAuthManager.setAuthenticated(false);
        Future.microtask(() async {
          disconnect();
          ChatCacheManager.instance.clearAll();
          await _tokenStorage.clearUserData();
          await NavigationService.goToPhoneNumberEntry();
        });
      },
      onAuthError: (_) {
        _isAuthenticated = false;
        _socketAuthManager.setAuthenticated(false);
        Future.microtask(() async {
          disconnect();
          ChatCacheManager.instance.clearAll();
          await _tokenStorage.clearUserData();
          await NavigationService.goToPhoneNumberEntry();
        });
      },
      onForceDisconnect: (data) {
        debugPrint('⚠️ Force disconnect: ${data['reason']}');

        // Update local connection state and notify listeners
        _socketConnectionManager.setConnected(false);
        _isAuthenticated = false;
        _socketAuthManager.setAuthenticated(false);
        _onDisconnected?.call();

        // Ensure the underlying socket is actually disconnected
        // (backend asked us to terminate this session)
        disconnect();

        // Propagate force-disconnect to higher layers (e.g., UnifiedChatService)
        if (_onForceDisconnect != null) {
          try {
            final payload = (data is Map<String, dynamic>)
                ? data
                : <String, dynamic>{};
            Future.microtask(() => _onForceDisconnect!(payload));
          } catch (_) {}
        }
      },
    );

    // Message events matching backend
    // Listen for multiple possible event names
    // Also listen for 'message' event (alternative backend event name)
    // Also listen for 'receive-message' event (another alternative)
    _messageEventsHandler.register(
      socket: socket,
      onIncomingMessage: (message) {
        _onNewMessage?.call(message);
      },
      onMessageSent: (message) {
        _onMessageSent?.call(message);
      },
      onMessageError: (error) {
        _onMessageError?.call(error);
      },
      onMessageEdited: (payload) {
        _onMessageEdited?.call(payload);
      },
      onEditMessageError: (error) {
        _onEditMessageError?.call(error);
      },
      onAckAcknowledged: (data) {
        if (_verboseLogs && kDebugMode) {
          debugPrint('✅ ack-acknowledged: $data');
        }
      },
      onAckError: (data) {
        final payload = (data is Map)
            ? Map<String, dynamic>.from(data)
            : <String, dynamic>{};
        final msg = payload['error']?.toString() ?? data?.toString();
        debugPrint('❌ ack-error: ${msg ?? "Unknown ack error"}');
      },
    );

    _deleteEventsHandler.register(
      socket: socket,
      onMessageDeleted: (payload) {
        try {
          final messageId =
              (payload['chatId'] ??
                      payload['messageId'] ??
                      payload['id'] ??
                      payload['chat_id'] ??
                      payload['message_id'])
                  ?.toString();
          if (messageId == null || messageId.trim().isEmpty) return;

          final deleteType = (payload['deleteType'] ?? payload['delete_type'])
              ?.toString();
          final deletedBy = (payload['deletedBy'] ?? payload['deleted_by'])
              ?.toString();
          final deletedAt = payload['deletedAt'] ?? payload['deleted_at'];

          // Contract: deleteType='me' should only apply on the deleting user's
          // devices. If another user receives it, ignore.
          if (deleteType == 'me' &&
              deletedBy != null &&
              deletedBy.isNotEmpty &&
              _currentUserId != null &&
              deletedBy != _currentUserId) {
            return;
          }

          _messageDeletedController.add(<String, dynamic>{
            'messageId': messageId,
            'deletedBy': deletedBy,
            'deleteType': deleteType,
            'deletedAt': deletedAt,
          });
        } catch (_) {}
      },
      onDeleteMessageError: (error) {
        _onDeleteMessageError?.call(error);
      },
    );

    _messageStatusEventsHandler.register(
      socket: socket,
      onStatusUpdate: (statusData) {
        _onMessageStatusUpdate?.call(statusData);
      },
    );

    _profileEventsHandler.register(
      socket: socket,
      onProfileUpdated: (update) {
        _onProfileUpdated?.call(update);
      },
    );

    // Poll vote data events
    socket.on(SocketEventNames.pollVoteData, (data) {
      try {
        if (kDebugMode) {
          debugPrint('📊 [Socket] poll-vote-data received: $data');
        }
        final payload = data is Map
            ? Map<String, dynamic>.from(data)
            : <String, dynamic>{};
        if (payload.isNotEmpty) {
          _pollVoteController.add(payload);
        }
      } catch (e) {
        debugPrint('❌ poll-vote-data parsing: $e');
      }
    });

    socket.on(SocketEventNames.pollError, (data) {
      if (kDebugMode) {
        debugPrint('❌ [Socket] poll-error: $data');
      }
    });

    // NOTE: Removed onAny listener - it was causing duplicate logs
    // Specific event handlers above are sufficient for production

    socket.on(SocketEventNames.newNotification, (data) {
      try {
        final payload = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
        if (payload.isNotEmpty) {
          _onNewNotification?.call(payload);
        }
      } catch (e) {
        debugPrint('❌ new_notification parsing: $e');
      }
    });

    socket.on(SocketEventNames.reactionAdded, (data) {
      try {
        final payload = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
        if (payload.isNotEmpty) {
          _onReactionAdded?.call(payload);
        }
      } catch (e) {
        debugPrint('❌ reaction_added parsing: $e');
      }
    });

    // Error handling
  }

  /// Authenticate user with backend (matches backend 'authenticate' event)
  void _authenticateUser() async {
    final socket = _socketConnectionManager.socket;
    final userId = _currentUserId;
    if (socket == null || userId == null) {
      debugPrint('❌ Cannot authenticate - socket or userId is null');
      return;
    }

    if (socket.connected != true) {
      debugPrint('❌ Cannot authenticate - socket is not connected');
      return;
    }

    debugPrint('');
    debugPrint(
      '🔐 ═══════════════════════════════════════════════════════════════',
    );
    debugPrint('🔐 AUTHENTICATING USER WITH BACKEND');
    debugPrint(
      '🔐 ═══════════════════════════════════════════════════════════════',
    );

    // Get fresh token from storage
    final authToken = await _tokenStorage.getToken() ?? '';

    if (!identical(socket, _socketConnectionManager.socket) ||
        socket.connected != true) {
      debugPrint('❌ Authentication aborted - socket changed/disconnected');
      return;
    }

    // Decode JWT to check expiry (basic check without verification)
    if (authToken.isNotEmpty) {
      try {
        final parts = authToken.split('.');
        if (parts.length == 3) {
          // Decode payload (second part)
          final payload = parts[1];
          // Add padding if needed for base64 decoding
          final normalizedPayload = base64.normalize(payload);
          final decoded = utf8.decode(base64.decode(normalizedPayload));
          final jsonPayload = jsonDecode(decoded);

          debugPrint('🔍 JWT Token Analysis:');
          debugPrint('   Token length: ${authToken.length}');
          debugPrint('   User ID in token: ${jsonPayload['userId']}');
          debugPrint(
            '   Issued at: ${jsonPayload['iat'] != null ? DateTime.fromMillisecondsSinceEpoch(jsonPayload['iat'] * 1000) : 'N/A'}',
          );
          debugPrint(
            '   Expires at: ${jsonPayload['exp'] != null ? DateTime.fromMillisecondsSinceEpoch(jsonPayload['exp'] * 1000) : 'N/A'}',
          );

          if (jsonPayload['exp'] != null) {
            final expiryTime = DateTime.fromMillisecondsSinceEpoch(
              jsonPayload['exp'] * 1000,
            );
            final now = DateTime.now();
            final isExpired = now.isAfter(expiryTime);
            final timeLeft = expiryTime.difference(now);

            if (isExpired) {
              // Note: Backend may not enforce JWT expiry - this is just informational
              debugPrint(
                '   ℹ️ JWT exp claim passed (backend may not enforce expiry)',
              );
            } else {
              debugPrint(
                '   ✅ Token valid for: ${timeLeft.inDays}d ${timeLeft.inHours % 24}h ${timeLeft.inMinutes % 60}m',
              );
            }
          }

          // Check if userId matches
          if (jsonPayload['userId'] != _currentUserId) {
            debugPrint('');
            debugPrint(
              '⚠️ ═══════════════════════════════════════════════════════════════',
            );
            debugPrint('⚠️ USER ID MISMATCH!');
            debugPrint('⚠️ Token userId: ${jsonPayload['userId']}');
            debugPrint('⚠️ Current userId: $_currentUserId');
            debugPrint(
              '⚠️ ═══════════════════════════════════════════════════════════════',
            );
            debugPrint('');
          }
        }
      } catch (e) {
        debugPrint('⚠️ Could not decode JWT token: $e');
      }
    }

    debugPrint('');
    debugPrint('📋 Authentication Payload:');
    debugPrint('   userId: $_currentUserId');
    debugPrint(
      '   token: ${authToken.isNotEmpty ? "${authToken.substring(0, 20)}..." : "EMPTY"}',
    );
    debugPrint('   loadHistory: false');
    debugPrint('');

    debugPrint('📤 Emitting "authenticate" event to backend...');

    _socketAuthManager.emitAuthenticate(
      socket: socket,
      userId: userId,
      token: authToken,
      loadHistory: false,
    );

    debugPrint('✅ Authentication request sent');
    debugPrint(
      '🔐 ═══════════════════════════════════════════════════════════════',
    );
    debugPrint('');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 15: MESSAGE OPERATIONS (Send messages)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<bool> sendMessage({
    required String receiverId,
    required String message,
    String messageType = 'text',
    String? clientMessageId,
    String? fileUrl,
    String? mimeType,
    int? imageWidth,
    int? imageHeight,
    Map<String, dynamic>? fileMetadata,
    bool? isFollowUp,
    double? audioDuration,
    String? videoThumbnailUrl,
    double? videoDuration,
    String? replyToMessageId,
  }) async {
    // Wait for socket to be connected AND authenticated before sending
    debugPrint('🔐 [WebSocketChatRepository] Authentication check:');
    debugPrint('   • Current user ID: $_currentUserId');
    debugPrint(
      '   • Socket exists: ${_socketConnectionManager.socket != null}',
    );
    debugPrint(
      '   • Socket connected: ${_socketConnectionManager.socket?.connected}',
    );
    debugPrint('   • Is authenticated: $_isAuthenticated');
    debugPrint(
      '   • Socket auth manager authenticated: ${_socketAuthManager.isAuthenticated}',
    );

    final ready = await ensureSocketReady(timeout: const Duration(seconds: 5));
    if (!ready) {
      debugPrint(
        '❌ ChatRepository: Cannot send message - socket not ready (not authenticated)',
      );
      debugPrint(
        '❌ Final auth state: _isAuthenticated=$_isAuthenticated, authManager=${_socketAuthManager.isAuthenticated}',
      );
      return false;
    }

    debugPrint(
      '✅ [WebSocketChatRepository] Socket ready - proceeding with message send',
    );

    final socket = _socketConnectionManager.socket;
    if (socket == null ||
        !_socketConnectionManager.isConnected ||
        _currentUserId == null) {
      debugPrint(
        '❌ ChatRepository: Cannot send message - socket not connected',
      );
      debugPrint('❌ Socket exists: ${_socketConnectionManager.socket != null}');
      debugPrint('❌ Socket connected: ${_socketConnectionManager.isConnected}');
      debugPrint('❌ Current user ID: $_currentUserId');
      return false;
    }

    try {
      final messageData = {
        'clientMessageId': clientMessageId,
        'senderId': _currentUserId!,
        'receiverId': receiverId,
        'messageType': messageType,
        'message': message,
        'fileUrl': fileUrl,
        'mimeType': mimeType,
        if (imageWidth != null) 'imageWidth': imageWidth,
        if (imageHeight != null) 'imageHeight': imageHeight,
        if (audioDuration != null) 'audioDuration': audioDuration,
        'fileMetadata': fileMetadata,
      };

      if (_verboseLogs && kDebugMode) {
        debugPrint('📤 ChatRepository: Sending message...');
        debugPrint('📤 Sender ID: ${_currentUserId!}');
        debugPrint('📤 Receiver ID: $receiverId');
        debugPrint('📤 Message: $message');
        debugPrint('📤 Socket connected: ${socket.connected}');
        if (imageWidth != null && imageHeight != null) {
          debugPrint('📤 Image dimensions: ${imageWidth}x$imageHeight');
        }
      }

      if (kDebugMode) {
        debugPrint(
          '📤 [WebSocketChatRepository] sendMessage receiverId=$receiverId clientMessageId=$clientMessageId messageType=$messageType',
        );
        debugPrint(
          '📤 [WebSocketChatRepository] message param: "$message" (length=${message.length})',
        );
      }

      final ok = _messageEmitter.sendPrivateMessage(
        socket: socket,
        senderId: _currentUserId!,
        receiverId: receiverId,
        message: message,
        messageType: messageType,
        clientMessageId: clientMessageId,
        fileUrl: fileUrl,
        mimeType: mimeType,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
        fileMetadata: fileMetadata,
        isFollowUp: isFollowUp,
        audioDuration: audioDuration,
        videoThumbnailUrl: videoThumbnailUrl,
        videoDuration: videoDuration,
        replyToMessageId: replyToMessageId,
      );

      if (!ok) return false;

      if (_verboseLogs && kDebugMode) {
        debugPrint('✅ ChatRepository: Message emitted successfully');
        debugPrint('✅ Message data: $messageData');
      }
      return true;
    } catch (e) {
      debugPrint('❌ ChatRepository: Failed to send message: $e');
      return false;
    }
  }

  /// Send contact message with correct API format
  Future<bool> sendContactMessage({
    required String receiverId,
    required List<Map<String, dynamic>> contactPayload,
    String? clientMessageId,
  }) async {
    debugPrint('📤 [WebSocketChatRepository] Sending contact message...');
    debugPrint('   • Receiver ID: $receiverId');
    debugPrint('   • Contact payload: $contactPayload');
    debugPrint('   • Client message ID: $clientMessageId');

    final ready = await ensureSocketReady(timeout: const Duration(seconds: 5));
    if (!ready) {
      debugPrint(
        '❌ ChatRepository: Cannot send contact message - socket not ready',
      );
      return false;
    }

    final socket = _socketConnectionManager.socket;
    if (socket == null ||
        !_socketConnectionManager.isConnected ||
        _currentUserId == null) {
      debugPrint(
        '❌ ChatRepository: Cannot send contact message - socket not connected',
      );
      return false;
    }

    try {
      final payload = {
        'senderId': _currentUserId!,
        'receiverId': receiverId,
        'messageType': 'contact',
        'contactPayload': contactPayload,
        if (clientMessageId != null) 'clientMessageId': clientMessageId,
      };

      debugPrint(
        '📤 [WebSocketChatRepository] Contact message payload: $payload',
      );

      socket.emit(SocketEventNames.privateMessage, payload);

      debugPrint('✅ Contact message emitted successfully');
      return true;
    } catch (e) {
      debugPrint('❌ ChatRepository: Failed to send contact message: $e');
      return false;
    }
  }

  /// Send poll message with correct API format
  Future<bool> sendPollMessage({
    required String receiverId,
    required Map<String, dynamic> pollPayload,
    String? clientMessageId,
  }) async {
    debugPrint('📤 [WebSocketChatRepository] Sending poll message...');
    debugPrint('   • Receiver ID: $receiverId');
    debugPrint('   • Poll payload: $pollPayload');
    debugPrint('   • Client message ID: $clientMessageId');

    final ready = await ensureSocketReady(timeout: const Duration(seconds: 5));
    if (!ready) {
      debugPrint(
        '❌ ChatRepository: Cannot send poll message - socket not ready',
      );
      return false;
    }

    final socket = _socketConnectionManager.socket;
    if (socket == null ||
        !_socketConnectionManager.isConnected ||
        _currentUserId == null) {
      debugPrint(
        '❌ ChatRepository: Cannot send poll message - socket not connected',
      );
      return false;
    }

    try {
      final payload = {
        'senderId': _currentUserId!,
        'receiverId': receiverId,
        'messageType': 'poll',
        'pollPayload': pollPayload,
        if (clientMessageId != null) 'clientMessageId': clientMessageId,
      };

      debugPrint('📤 [WebSocketChatRepository] Poll message payload: $payload');

      socket.emit(SocketEventNames.privateMessage, payload);

      debugPrint('✅ Poll message emitted successfully');
      return true;
    } catch (e) {
      debugPrint('❌ ChatRepository: Failed to send poll message: $e');
      return false;
    }
  }

  /// Add vote to a poll via WebSocket
  Future<bool> addPollVote({
    required String pollMessageId,
    required String optionId,
  }) async {
    debugPrint('📤 [WebSocketChatRepository] Adding poll vote...');
    debugPrint('   • Poll Message ID: $pollMessageId');
    debugPrint('   • Option ID: $optionId');

    final ready = await ensureSocketReady(timeout: const Duration(seconds: 5));
    if (!ready) {
      debugPrint('❌ ChatRepository: Cannot add poll vote - socket not ready');
      return false;
    }

    final socket = _socketConnectionManager.socket;
    if (socket == null ||
        !_socketConnectionManager.isConnected ||
        _currentUserId == null) {
      debugPrint(
        '❌ ChatRepository: Cannot add poll vote - socket not connected',
      );
      return false;
    }

    try {
      final payload = {'pollMessageId': pollMessageId, 'optionId': optionId};

      debugPrint(
        '📤 [WebSocketChatRepository] Poll add vote payload: $payload',
      );

      socket.emit(SocketEventNames.pollAddVote, payload);

      debugPrint('✅ Poll vote added successfully');
      return true;
    } catch (e) {
      debugPrint('❌ ChatRepository: Failed to add poll vote: $e');
      return false;
    }
  }

  /// Remove vote from a poll via WebSocket
  Future<bool> removePollVote({required String pollMessageId}) async {
    debugPrint('📤 [WebSocketChatRepository] Removing poll vote...');
    debugPrint('   • Poll Message ID: $pollMessageId');

    final ready = await ensureSocketReady(timeout: const Duration(seconds: 5));
    if (!ready) {
      debugPrint(
        '❌ ChatRepository: Cannot remove poll vote - socket not ready',
      );
      return false;
    }

    final socket = _socketConnectionManager.socket;
    if (socket == null ||
        !_socketConnectionManager.isConnected ||
        _currentUserId == null) {
      debugPrint(
        '❌ ChatRepository: Cannot remove poll vote - socket not connected',
      );
      return false;
    }

    try {
      final payload = {'pollMessageId': pollMessageId};

      debugPrint(
        '📤 [WebSocketChatRepository] Poll remove vote payload: $payload',
      );

      socket.emit(SocketEventNames.pollRemoveVote, payload);

      debugPrint('✅ Poll vote removed successfully');
      return true;
    } catch (e) {
      debugPrint('❌ ChatRepository: Failed to remove poll vote: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 16: MESSAGE STATUS OPERATIONS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<bool> updateMessageStatusViaSocket({
    required String messageId,
    required String status, // 'delivered' or 'read'
  }) async {
    if (!_socketConnectionManager.isConnected ||
        _socketConnectionManager.socket == null) {
      debugPrint(
        '⚠️ ChatRepository: Socket not connected, cannot update status via socket',
      );
      return false;
    }

    // If connected but not authenticated, queue the update
    if (!_isAuthenticated) {
      debugPrint(
        '⏳ ChatRepository: Socket connected but NOT authenticated yet - queuing status update',
      );
      debugPrint('📦 Queued: messageId=$messageId, status=$status');
      _pendingStatusUpdates.add(
        _PendingStatusUpdate(messageId: messageId, status: status),
      );
      debugPrint('📦 Queue size: ${_pendingStatusUpdates.length}');
      return true; // Return true as it will be sent after auth
    }

    return _emitStatusUpdate(messageId: messageId, status: status);
  }

  /// Internal method to actually emit the status update
  Future<bool> _emitStatusUpdate({
    required String messageId,
    required String status,
  }) async {
    final socket = _socketConnectionManager.socket;
    if (!_socketConnectionManager.isConnected ||
        socket == null ||
        !_isAuthenticated) {
      debugPrint(
        '⚠️ ChatRepository: Cannot emit status - not connected or not authenticated',
      );
      return false;
    }

    try {
      return _statusEmitter.updateMessageStatusWithAck(
        socket: socket,
        messageId: messageId,
        status: status,
        isAuthenticated: _isAuthenticated,
      );
    } catch (e) {
      debugPrint('❌ ChatRepository: Error updating status via socket: $e');
      return false;
    }
  }

  /// WHATSAPP-STYLE: Batch update message status for instant blue ticks
  /// Sends all message IDs in ONE socket emit for maximum speed
  Future<bool> updateMessageStatusBatch({
    required List<String> messageIds,
    required String status, // 'delivered' or 'read'
  }) async {
    if (messageIds.isEmpty) return true;

    final socket = _socketConnectionManager.socket;
    if (!_socketConnectionManager.isConnected ||
        socket == null ||
        !_isAuthenticated) {
      debugPrint('⚠️ ChatRepository: Socket not ready for batch status update');
      return false;
    }

    try {
      debugPrint(
        '⚡ BATCH STATUS UPDATE: ${messageIds.length} messages → $status',
      );

      final ok = _statusEmitter.updateMessageStatusBatch(
        socket: socket,
        messageIds: messageIds,
        status: status,
      );

      if (!ok) return false;

      debugPrint('⚡ Batch emit complete: ${messageIds.length} → $status');
      return true;
    } catch (e) {
      debugPrint('❌ Batch status update failed: $e');
      return false;
    }
  }

  /// Process all pending status updates after authentication completes
  void _processPendingStatusUpdates() {
    if (_pendingStatusUpdates.isEmpty) return;

    // Copy and clear the queue to avoid issues during iteration
    final updates = List<_PendingStatusUpdate>.from(_pendingStatusUpdates);
    _pendingStatusUpdates.clear();

    for (final update in updates) {
      _emitStatusUpdate(messageId: update.messageId, status: update.status);
    }
  }

  /// Send message received acknowledgment to server
  /// Used when a message is received to confirm delivery
  void sendMessageReceivedAck({
    required String messageId,
    String? receiverDeliveryChannel,
  }) {
    final socket = _socketConnectionManager.socket;
    if (socket == null ||
        !_socketConnectionManager.isConnected ||
        !_isAuthenticated) {
      debugPrint(
        '⚠️ ChatRepository: Cannot send ack - not connected/authenticated',
      );
      return;
    }

    try {
      if (_verboseLogs && kDebugMode) {
        debugPrint('📤 Sending message-received-ack for: $messageId');
      }

      _messageEmitter.sendMessageReceivedAck(
        socket: socket,
        messageId: messageId,
        receiverDeliveryChannel: receiverDeliveryChannel,
      );
    } catch (e) {
      debugPrint('❌ Failed to send message-received-ack: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 17: CALLBACK REGISTRATION
  // ═══════════════════════════════════════════════════════════════════════════

  void onNewMessage(Function(ChatMessageModel) callback) {
    if (_verboseLogs && kDebugMode) {
      debugPrint('📞 ChatRepository: onNewMessage callback REGISTERED');
    }
    _onNewMessage = callback;
    if (_verboseLogs && kDebugMode) {
      debugPrint('📞 _onNewMessage is now null? ${_onNewMessage == null}');
    }
  }

  /// Register callback for message sent confirmation
  void onMessageSent(Function(ChatMessageModel) callback) {
    _onMessageSent = callback;
  }

  /// Register callback for message errors
  void onMessageError(Function(String) callback) {
    _onMessageError = callback;
  }

  void onMessageEdited(Function(Map<String, dynamic>) callback) {
    _onMessageEdited = callback;
  }

  void onEditMessageError(Function(String) callback) {
    _onEditMessageError = callback;
  }

  void onDeleteMessageError(Function(String) callback) {
    _onDeleteMessageError = callback;
  }

  void onReactionUpdated(Function(Map<String, dynamic>) callback) {
    _onReactionUpdated = callback;
  }

  void onReactionError(Function(String) callback) {
    _onReactionError = callback;
  }

  void onMessageStarred(Function(Map<String, dynamic>) callback) {
    _onMessageStarred = callback;
  }

  void onMessageUnstarred(Function(Map<String, dynamic>) callback) {
    _onMessageUnstarred = callback;
  }

  void onStarMessageError(Function(String) callback) {
    _onStarMessageError = callback;
  }

  void onUnstarMessageError(Function(String) callback) {
    _onUnstarMessageError = callback;
  }

  /// Register callback for connection status
  void onConnectionChanged({
    Function()? onConnected,
    Function()? onDisconnected,
  }) {
    _onConnected = onConnected;
    _onDisconnected = onDisconnected;
  }

  /// Clear all callbacks to prevent duplicate processing
  void clearCallbacks() {
    debugPrint('🧹 ChatRepository: Clearing all callbacks');
    _onNewMessage = null;
    _onMessageSent = null;
    _onMessageError = null;
    _onMessageEdited = null;
    _onEditMessageError = null;
    _onReactionUpdated = null;
    _onReactionError = null;
    _onChatActivityUpdated = null;
    _onMessageStarred = null;
    _onMessageUnstarred = null;
    _onStarMessageError = null;
    _onUnstarMessageError = null;
    _onConnected = null;
    _onDisconnected = null;
    _onMessageStatusUpdate = null;
    _onUserStatusChanged = null;
    _onNewNotification = null;
    _onReactionAdded = null;
  }

  /// Set status update callback
  void setOnMessageStatusUpdate(Function(Map<String, dynamic>) callback) {
    _onMessageStatusUpdate = callback;
  }

  /// Register callback for user status (presence) changes
  void onUserStatusChanged(Function(UserStatus) callback) {
    _onUserStatusChanged = callback;
  }

  /// Register callback for force-disconnect event
  /// Allows higher layers to perform cleanup and navigation when backend
  /// explicitly terminates this session (e.g., login from another device).
  void onForceDisconnect(Function(Map<String, dynamic>) callback) {
    _onForceDisconnect = callback;
  }

  /// Register callback for profile updates from contacts (WhatsApp-style)
  /// Called when a contact updates their name, profile pic, or status
  void onProfileUpdated(Function(ProfileUpdate) callback) {
    _onProfileUpdated = callback;
    debugPrint('👤 ChatRepository: onProfileUpdated callback REGISTERED');
  }

  void onChatActivityUpdated(Function(Map<String, dynamic>) callback) {
    _onChatActivityUpdated = callback;
  }

  void onNewNotification(Function(Map<String, dynamic>) callback) {
    _onNewNotification = callback;
  }

  void onReactionAdded(Function(Map<String, dynamic>) callback) {
    _onReactionAdded = callback;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 18: CONNECTION STATE & CHAT ROOM OPERATIONS
  // ═══════════════════════════════════════════════════════════════════════════

  bool get isConnected => _socketConnectionManager.isConnected;
  String? get currentUserId => _currentUserId;
  bool get isConnectionHealthy =>
      _socketConnectionManager.isConnected &&
      _socketConnectionManager.socket?.connected == true;

  /// Join chat room
  /// Note: Backend doesn't use rooms - it routes messages via connectedUsers Map (userId -> socketId)
  /// Emit to backend that this user is now actively in chat with receiverId
  /// Global socket connection is already managed by app lifecycle - no need to check/reconnect here
  void joinChat(String receiverId) {
    final socket = _socketConnectionManager.socket;

    // Only check for critical nulls - global connection manager handles reconnection
    if (_currentUserId == null) {
      debugPrint('❌ ChatRepository: Cannot join chat - no current user');
      return;
    }

    // Emit to backend that this user is now in chat with receiverId
    // If socket is temporarily disconnected, the global reconnection will handle it
    if (socket != null && _socketConnectionManager.isConnected) {
      try {
        _messageEmitter.enterChat(
          socket: socket,
          userId: _currentUserId!,
          otherUserId: receiverId,
        );
      } catch (e) {
        debugPrint('❌ enter-chat failed: $e');
      }

      // Request the receiver's status when joining chat
      requestUserStatus(receiverId);
    }
  }

  /// Request user status for a specific user
  void requestUserStatus(String userId) {
    final socket = _socketConnectionManager.socket;
    if (socket == null || !_socketConnectionManager.isConnected) return;
    _statusEmitter.requestUserStatus(socket: socket, userId: userId);
  }

  /// Send typing indicator to server
  void sendTypingStatus({
    required String senderId,
    required String receiverId,
    required bool isTyping,
  }) {
    final socket = _socketConnectionManager.socket;
    if (socket == null || !_socketConnectionManager.isConnected) {
      debugPrint('❌ ChatRepository: Cannot send typing status - not connected');
      return;
    }
    if (_verboseLogs && kDebugMode) {
      debugPrint(
        '⌨️ ChatRepository: Sending typing status: $senderId -> $receiverId ($isTyping)',
      );
    }
    _typingEmitter.sendTyping(
      socket: socket,
      senderId: senderId,
      receiverId: receiverId,
      isTyping: isTyping,
    );
  }

  /// Leave chat room
  void leaveChat(String receiverId) {
    debugPrint('🚪 ChatRepository: Left chat with user: $receiverId');

    // Emit to backend that this user has left the chat
    final socket = _socketConnectionManager.socket;
    if (socket != null &&
        _socketConnectionManager.isConnected &&
        _currentUserId != null) {
      try {
        _messageEmitter.leaveChat(socket: socket, userId: _currentUserId!);
        debugPrint(
          '📡 Emitted leave-chat: $_currentUserId left chat with $receiverId',
        );
      } catch (e) {
        debugPrint('❌ Failed to emit leave-chat: $e');
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 19: USER PRESENCE & TYPING OPERATIONS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Set user presence status (online/offline/away)
  /// Called when app goes to foreground/background
  /// WhatsApp-like: user is "online" only when app is in foreground
  void setUserPresence({required bool isOnline}) {
    final socket = _socketConnectionManager.socket;
    if (socket == null || !_socketConnectionManager.isConnected) {
      _pendingPresenceIsOnline = isOnline;
      return;
    }

    if (!_isAuthenticated || _currentUserId == null) {
      _pendingPresenceIsOnline = isOnline;
      return;
    }

    try {
      _statusEmitter.setUserPresence(
        socket: socket,
        userId: _currentUserId!,
        isOnline: isOnline,
      );
    } catch (e) {
      debugPrint('❌ Failed to set presence: $e');
    }
  }

  void _flushPendingPresence() {
    final pending = _pendingPresenceIsOnline;
    if (pending == null) return;

    _pendingPresenceIsOnline = null;

    final socket = _socketConnectionManager.socket;
    if (socket == null ||
        !_socketConnectionManager.isConnected ||
        !_isAuthenticated ||
        _currentUserId == null) {
      _pendingPresenceIsOnline = pending;
      return;
    }

    try {
      _statusEmitter.setUserPresence(
        socket: socket,
        userId: _currentUserId!,
        isOnline: pending,
      );
    } catch (e) {
      debugPrint('❌ Failed to flush presence: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 20: CLEANUP & DISPOSE
  // ═══════════════════════════════════════════════════════════════════════════

  void disconnect() {
    final socket = _socketConnectionManager.socket;
    if (socket != null) {
      socket.clearListeners();
      socket.disconnect();
      _isAuthenticated = false;
      _pendingPresenceIsOnline = null;
      _socketConnectionManager.setConnected(false);
      _socketConnectionManager.detachSocket();
      _socketAuthManager.setAuthenticated(false);
      _onDisconnected?.call();
    }
  }

  /// Dispose repository resources
  void dispose() {
    disconnect();
    _onNewMessage = null;
    _onMessageSent = null;
    _onMessageError = null;
    _onConnected = null;
    _onDisconnected = null;
    _pendingStatusUpdates.clear();

    try {
      _messageDeletedController.close();
    } catch (_) {}
  }
}

/// Helper class for queuing status updates until authentication completes
class _PendingStatusUpdate {
  final String messageId;
  final String status;
  final DateTime queuedAt;

  _PendingStatusUpdate({
    required this.messageId,
    required this.status,
    DateTime? queuedAt,
  }) : queuedAt = queuedAt ?? DateTime.now();
}
