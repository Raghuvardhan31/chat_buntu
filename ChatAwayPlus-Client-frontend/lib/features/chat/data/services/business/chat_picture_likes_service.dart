import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:chataway_plus/features/chat/data/services/chat_engine/index.dart';
import 'package:chataway_plus/features/chat/data/socket/websocket_repository/websocket_chat_repository.dart';
import '../local/chat_picture_likes_local_db.dart';

class ChatPictureLikeToggleResult {
  final bool isLiked;
  final int? likeCount;
  final String? likeId;

  const ChatPictureLikeToggleResult({
    required this.isLiked,
    this.likeCount,
    this.likeId,
  });
}

class ChatPictureLikesService {
  static final ChatPictureLikesService _instance =
      ChatPictureLikesService._internal();
  factory ChatPictureLikesService() => _instance;
  ChatPictureLikesService._internal();

  static ChatPictureLikesService get instance => _instance;

  final ChatEngineService _hybrid = ChatEngineService.instance;
  final ChatPictureLikesDatabaseService _localDb =
      ChatPictureLikesDatabaseService.instance;

  String? _currentUserId;

  void _ensureInitialized() {
    if (_currentUserId != null && _currentUserId!.isNotEmpty) return;
    final id = _hybrid.currentUserId;
    if (id == null || id.isEmpty) return;
    _currentUserId = id;
    if (kDebugMode) {
      debugPrint('✅ ChatPictureLikesService: Lazy-initialized for user $id');
    }
  }

  /// Initialize with current user ID for local DB operations
  void initialize({required String currentUserId}) {
    _currentUserId = currentUserId;
    if (kDebugMode) {
      debugPrint(
        '✅ ChatPictureLikesService: Initialized for user $currentUserId',
      );
    }
  }

  Future<ChatPictureLikeToggleResult> toggle({
    required String likedUserId,
    required String targetChatPictureId,
    bool? currentUiState,
  }) async {
    _ensureInitialized();
    if (_currentUserId == null) {
      throw Exception('ChatPictureLikesService not initialized');
    }

    // 1. Determine optimistic state - prefer UI state if provided (more accurate)
    final bool optimisticIsLiked;
    if (currentUiState != null) {
      optimisticIsLiked = !currentUiState;
    } else {
      final currentState = await _localDb.getLikeState(
        currentUserId: _currentUserId!,
        likedUserId: likedUserId,
        targetChatPictureId: targetChatPictureId,
      );
      optimisticIsLiked = !(currentState ?? false);
    }

    // 2. Optimistically update local DB
    await _localDb.upsert(
      currentUserId: _currentUserId!,
      likedUserId: likedUserId,
      targetChatPictureId: targetChatPictureId,
      isLiked: optimisticIsLiked,
    );

    // 3. Try socket call
    final ready = await _hybrid.ensureSocketReady();
    if (!ready) {
      // Offline - return optimistic result
      return ChatPictureLikeToggleResult(
        isLiked: optimisticIsLiked,
        likeCount: null,
        likeId: null,
      );
    }

    // Diagnostic: Ask backend whether the receiver is online.
    // If receiver is online, backend should deliver WebSocket `notification`.
    // If receiver is offline, backend will typically fall back to FCM.
    if (kDebugMode) {
      final receiverOnline = await _probeExpectedDeliveryPath(
        receiverId: likedUserId,
      );
      debugPrint(
        '🔎 [ChatPictureLike] Receiver presence (userId=$likedUserId) isOnline=$receiverOnline | expectedDelivery=${receiverOnline == true
            ? "socket(notification)"
            : receiverOnline == false
            ? "FCM"
            : "unknown"}',
      );
    }

    // 4. Send to server
    final action = optimisticIsLiked ? 'liked' : 'unliked';
    final payload = await _hybrid.toggleChatPictureLike(
      likedUserId: likedUserId,
      targetChatPictureId: targetChatPictureId,
    );

    debugPrint('❤️ [LIKE] Server response: $payload');

    final rawIsLikedField =
        payload['isLiked'] ?? payload['is_liked'] ?? payload['liked'];
    bool? serverIsLiked;
    if (rawIsLikedField is bool) {
      serverIsLiked = rawIsLikedField;
    } else if (rawIsLikedField is int) {
      serverIsLiked = rawIsLikedField == 1;
    } else if (rawIsLikedField != null) {
      final s = rawIsLikedField.toString().toLowerCase().trim();
      if (s == 'true' || s == '1' || s == 'yes') {
        serverIsLiked = true;
      } else if (s == 'false' || s == '0' || s == 'no') {
        serverIsLiked = false;
      }
    }

    final rawAction = (payload['action'] ?? payload['status'])
        ?.toString()
        .toLowerCase();

    // Some backends emit broadcast events with action='liked' even when the
    // current user's request is 'unliked'. Only trust action/status when it
    // matches the expected action for this request.
    final expectedAction = action.toLowerCase().trim();
    if (serverIsLiked == null && rawAction != null && rawAction.isNotEmpty) {
      if ((rawAction == 'liked' || rawAction == 'like') &&
          expectedAction == 'liked') {
        serverIsLiked = true;
      } else if ((rawAction == 'unliked' || rawAction == 'unlike') &&
          expectedAction == 'unliked') {
        serverIsLiked = false;
      }
    }

    final isLiked = serverIsLiked ?? optimisticIsLiked;

    int? likeCount;
    final rawCount = payload['likeCount'] ?? payload['likesCount'];
    if (rawCount != null) {
      likeCount = int.tryParse(rawCount.toString());
    }

    final likeId = payload['likeId']?.toString();

    // 5. Update local DB with server response
    await _localDb.upsert(
      currentUserId: _currentUserId!,
      likedUserId: likedUserId,
      targetChatPictureId: targetChatPictureId,
      isLiked: isLiked,
      likeId: likeId,
      likeCount: likeCount,
    );

    return ChatPictureLikeToggleResult(
      isLiked: isLiked,
      likeCount: likeCount,
      likeId: likeId,
    );
  }

  Future<bool?> _probeExpectedDeliveryPath({required String receiverId}) async {
    try {
      WebSocketChatRepository.instance.requestUserStatus(receiverId);

      final status = await _hybrid.userStatusStream
          .where((s) => s.userId == receiverId)
          .timeout(const Duration(milliseconds: 800))
          .first;

      return status.isOnline;
    } catch (_) {
      return null;
    }
  }

  Future<int> count({
    required String likedUserId,
    required String targetChatPictureId,
  }) async {
    final ready = await _hybrid.ensureSocketReady();
    if (!ready) {
      throw Exception('Socket not connected');
    }

    final payload = await _hybrid.getChatPictureLikeCount(
      likedUserId: likedUserId,
      targetChatPictureId: targetChatPictureId,
    );

    final rawCount =
        payload['likeCount'] ??
        payload['likesCount'] ??
        payload['count'] ??
        payload['total'];

    return int.tryParse(rawCount?.toString() ?? '') ?? 0;
  }

  Future<bool> check({
    required String likedUserId,
    required String targetChatPictureId,
  }) async {
    _ensureInitialized();
    if (_currentUserId == null) {
      throw Exception('ChatPictureLikesService not initialized');
    }

    // 1. Check local DB first (instant UI)
    final localState = await _localDb.getLikeState(
      currentUserId: _currentUserId!,
      likedUserId: likedUserId,
      targetChatPictureId: targetChatPictureId,
    );

    // 2. Try socket call for fresh data
    final ready = await _hybrid.ensureSocketReady();
    if (!ready) {
      // Offline - return local state
      if (kDebugMode) {
        debugPrint(
          '💾 [LOCAL] PictureLikes.check: Socket offline, using local state=$localState',
        );
      }
      return localState ?? false;
    }

    // 3. Fetch from server
    final payload = await _hybrid.checkChatPictureLikedStatus(
      likedUserId: likedUserId,
      targetChatPictureId: targetChatPictureId,
    );

    final rawIsLikedField =
        payload['isLiked'] ?? payload['is_liked'] ?? payload['liked'];
    bool? serverIsLiked;
    if (rawIsLikedField is bool) {
      serverIsLiked = rawIsLikedField;
    } else if (rawIsLikedField is int) {
      serverIsLiked = rawIsLikedField == 1;
    } else if (rawIsLikedField != null) {
      final s = rawIsLikedField.toString().toLowerCase().trim();
      if (s == 'true' || s == '1' || s == 'yes') {
        serverIsLiked = true;
      } else if (s == 'false' || s == '0' || s == 'no') {
        serverIsLiked = false;
      }
    }

    // Important: do NOT infer like state from action/status strings here.
    // Some backends broadcast action='liked' even for unlike operations.
    final resolved = serverIsLiked ?? (localState ?? false);

    // 4. Update local DB with server state
    await _localDb.upsert(
      currentUserId: _currentUserId!,
      likedUserId: likedUserId,
      targetChatPictureId: targetChatPictureId,
      isLiked: resolved,
    );
    if (kDebugMode) {
      debugPrint(
        '🌐 [REMOTE] PictureLikes.check: raw=$rawIsLikedField, server=$serverIsLiked, local=$localState, resolved=$resolved',
      );
    }

    return resolved;
  }

  /// Get cached like state from local DB (instant, no network)
  Future<bool> getCachedLikeState({
    required String likedUserId,
    required String targetChatPictureId,
  }) async {
    _ensureInitialized();
    if (_currentUserId == null) return false;

    final state = await _localDb.getLikeState(
      currentUserId: _currentUserId!,
      likedUserId: likedUserId,
      targetChatPictureId: targetChatPictureId,
    );
    return state ?? false;
  }

  /// Clear all cached likes for a user (called on logout)
  Future<void> clearCachedLikes({required String likedUserId}) async {
    _ensureInitialized();
    if (_currentUserId == null) return;

    await _localDb.clearForLikedUserId(
      currentUserId: _currentUserId!,
      likedUserId: likedUserId,
    );
    if (kDebugMode) {
      debugPrint('🗑️ [LOCAL] PictureLikes: Cleared cache for $likedUserId');
    }
  }
}
