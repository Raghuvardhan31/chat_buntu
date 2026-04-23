import 'package:flutter/foundation.dart';
import 'package:chataway_plus/features/chat/data/services/chat_engine/index.dart';
import '../local/status_likes_local_db.dart';

class StatusLikeToggleResult {
  final bool isLiked;
  final int? likeCount;
  final String? likeId;

  const StatusLikeToggleResult({
    required this.isLiked,
    this.likeCount,
    this.likeId,
  });
}

/// Service for managing status likes (Share Your Voice Text likes)
/// Handles toggle, check, and count operations with offline-first approach
class StatusLikesService {
  static final StatusLikesService _instance = StatusLikesService._internal();
  factory StatusLikesService() => _instance;
  StatusLikesService._internal();

  static StatusLikesService get instance => _instance;

  final ChatEngineService _hybrid = ChatEngineService.instance;
  final StatusLikesLocalDatabaseService _localDb =
      StatusLikesLocalDatabaseService.instance;

  String? _currentUserId;

  /// Initialize with current user ID for local DB operations
  void initialize({required String currentUserId}) {
    _currentUserId = currentUserId;
    if (kDebugMode) {
      debugPrint('✅ StatusLikesService: Initialized for user $currentUserId');
    }
  }

  bool _parseBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) return value == 1;
    final s = value.toString().toLowerCase().trim();
    return s == 'true' || s == '1' || s == 'yes' || s == 'liked';
  }

  /// Check if user can still toggle like (max 4 toggles per status)
  Future<bool> canToggle({required String statusId}) async {
    if (_currentUserId == null) return false;
    return _localDb.canToggle(
      currentUserId: _currentUserId!,
      statusId: statusId,
    );
  }

  /// Increment toggle count after successful toggle
  Future<void> incrementToggleCount({required String statusId}) async {
    if (_currentUserId == null) return;
    await _localDb.incrementToggleCount(
      currentUserId: _currentUserId!,
      statusId: statusId,
    );
  }

  /// Toggle like on a status — instant response.
  /// Updates local DB immediately and returns optimistic result.
  /// Socket emit happens in background (fire-and-forget).
  Future<StatusLikeToggleResult> toggle({
    required String statusId,
    String? statusOwnerId,
  }) async {
    if (_currentUserId == null) {
      throw Exception('StatusLikesService not initialized');
    }

    if (kDebugMode) {
      debugPrint(
        '❤️ [STATUS_LIKE] toggle() requested: statusId=$statusId, currentUserId=$_currentUserId',
      );
    }

    // 1. Get current local state for optimistic toggle
    final currentState = await _localDb.getLikeState(
      currentUserId: _currentUserId!,
      statusId: statusId,
    );
    final optimisticIsLiked = !(currentState ?? false);

    // 2. Optimistically update local DB — instant
    await _localDb.upsert(
      currentUserId: _currentUserId!,
      statusId: statusId,
      isLiked: optimisticIsLiked,
      statusOwnerId: statusOwnerId,
    );

    // 3. Fire socket call in background — don't block UI
    _fireSocketToggle(statusId, statusOwnerId, optimisticIsLiked);

    // 4. Return immediately with optimistic result
    return StatusLikeToggleResult(
      isLiked: optimisticIsLiked,
      likeCount: null,
      likeId: null,
    );
  }

  /// Background fire-and-forget socket toggle.
  /// Reconciles local DB with server response when it arrives.
  /// If offline, local DB already has the optimistic state — no action needed.
  void _fireSocketToggle(
    String statusId,
    String? statusOwnerId,
    bool optimisticIsLiked,
  ) {
    Future(() async {
      try {
        // Check socket readiness first — if offline, skip silently.
        // Local DB already has the optimistic state.
        final ready = await _hybrid.ensureSocketReady();
        if (!ready) {
          if (kDebugMode) {
            debugPrint(
              '📡 [STATUS_LIKE] Socket not ready (offline). Local DB has optimistic state=$optimisticIsLiked',
            );
          }
          return;
        }

        final payload = await _hybrid.toggleStatusLike(statusId: statusId);
        if (kDebugMode) {
          debugPrint('❤️ [STATUS_LIKE] Server response: $payload');
        }

        // Parse server response robustly (matching ChatPictureLikesService)
        final rawIsLikedField =
            payload['isLiked'] ?? payload['is_liked'] ?? payload['liked'];
        bool? serverIsLiked;
        if (rawIsLikedField is bool) {
          serverIsLiked = rawIsLikedField;
        } else if (rawIsLikedField is int) {
          serverIsLiked = rawIsLikedField == 1;
        } else if (rawIsLikedField != null) {
          serverIsLiked = _parseBool(rawIsLikedField);
        }

        // Fallback to action/status field
        if (serverIsLiked == null) {
          final rawAction = (payload['action'] ?? payload['status'])
              ?.toString()
              .toLowerCase();
          if (rawAction == 'liked' || rawAction == 'like') {
            serverIsLiked = true;
          } else if (rawAction == 'unliked' || rawAction == 'unlike') {
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

        // Reconcile local DB with server response
        await _localDb.upsert(
          currentUserId: _currentUserId!,
          statusId: statusId,
          isLiked: isLiked,
          statusOwnerId: statusOwnerId,
          likeId: likeId,
          likeCount: likeCount,
        );
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️ [STATUS_LIKE] Background socket toggle failed: $e');
        }
      }
    });
  }

  /// Get like count for a status
  Future<int> count({required String statusId}) async {
    final ready = await _hybrid.ensureSocketReady();
    if (!ready) {
      // Try local cache
      final cachedCount = await _localDb.getLikeCount(
        currentUserId: _currentUserId ?? '',
        statusId: statusId,
      );
      return cachedCount ?? 0;
    }

    final payload = await _hybrid.getStatusLikeCount(statusId: statusId);

    final rawCount =
        payload['likeCount'] ??
        payload['likesCount'] ??
        payload['count'] ??
        payload['total'];

    return int.tryParse(rawCount?.toString() ?? '') ?? 0;
  }

  /// Check if current user has liked a status
  Future<bool> check({required String statusId}) async {
    if (_currentUserId == null) {
      throw Exception('StatusLikesService not initialized');
    }

    if (kDebugMode) {
      debugPrint(
        '🔍 [STATUS_LIKE] check() requested: statusId=$statusId, currentUserId=$_currentUserId',
      );
    }

    // 1. Check local DB first (instant UI)
    final localState = await _localDb.getLikeState(
      currentUserId: _currentUserId!,
      statusId: statusId,
    );

    // 2. Try socket call for fresh data
    final ready = await _hybrid.ensureSocketReady();
    if (!ready) {
      if (kDebugMode) {
        debugPrint(
          '📡 [STATUS_LIKE] Socket not ready, returning localState=$localState (no server call)',
        );
      }
      return localState ?? false;
    }

    // 3. Fetch from server
    if (kDebugMode) {
      debugPrint(
        '📤 [STATUS_LIKE] Emitting ${'check-status-like-status'} for statusId=$statusId',
      );
    }
    final payload = await _hybrid.checkStatusLikeStatus(statusId: statusId);

    final raw = payload['isLiked'] ?? payload['is_liked'] ?? payload['liked'];
    final serverIsLiked = _parseBool(raw);

    // 4. Update local DB with server state
    await _localDb.upsert(
      currentUserId: _currentUserId!,
      statusId: statusId,
      isLiked: serverIsLiked,
    );

    return serverIsLiked;
  }

  /// Get cached like state from local DB (instant, no network)
  Future<bool> getCachedLikeState({required String statusId}) async {
    if (_currentUserId == null) return false;

    final state = await _localDb.getLikeState(
      currentUserId: _currentUserId!,
      statusId: statusId,
    );
    return state ?? false;
  }

  /// Get cached like state from local DB (nullable: null means unknown/not cached)
  Future<bool?> getCachedLikeStateNullable({required String statusId}) async {
    if (_currentUserId == null) return null;
    return _localDb.getLikeState(
      currentUserId: _currentUserId!,
      statusId: statusId,
    );
  }

  /// Clear all cached likes for a status owner (called on logout)
  Future<void> clearCachedLikes({required String statusOwnerId}) async {
    if (_currentUserId == null) return;

    await _localDb.clearForStatusOwnerId(
      currentUserId: _currentUserId!,
      statusOwnerId: statusOwnerId,
    );
    if (kDebugMode) {
      debugPrint('🗑️ [LOCAL] StatusLikes: Cleared cache for $statusOwnerId');
    }
  }
}
