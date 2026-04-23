// chat_page_notifier.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chataway_plus/features/chat/data/services/chat_engine/index.dart';
import '../../../data/services/local/messages_local_db.dart';
import '../../../data/cache/opened_chats_cache.dart';
import '../../../models/chat_message_model.dart';
import 'chat_page_state.dart';

class ChatPageNotifier extends StateNotifier<ChatPageState> {
  final String otherUserId;
  final String currentUserId;

  static const Duration _sendingStaleAfter = Duration(minutes: 20);

  static const bool _verboseLogs = false;

  /// Mirror of the current state that is always safe to read, even after
  /// dispose. Every write goes through _safeSetState which keeps this in sync
  /// with the real StateNotifier `state`. All reads inside this class MUST use
  /// `_safeState` instead of `state` to avoid the StateNotifier assertion.
  ChatPageState _lastState = const ChatPageState();

  /// Safe state getter — always returns _lastState (never touches the base
  /// `state` getter which throws after dispose).
  ChatPageState get _safeState => _lastState;

  /// Override the state getter so external Riverpod reads (ref.watch / ref.read)
  /// never trigger the _debugIsMounted assertion after dispose.
  @override
  ChatPageState get state => _lastState;

  /// Safe state setter — updates _lastState AND the real StateNotifier state
  /// (only when still mounted). Prevents StateError after dispose.
  void _safeSetState(ChatPageState newState) {
    _lastState = newState;
    if (!mounted) return;
    try {
      super.state = newState;
    } catch (_) {
      // Swallow StateError if dispose races between mounted check and setter
    }
  }

  /// If true: list is ascending (oldest -> newest) and newest is at end.
  /// UI using ListView(reverse: true) expects newest at bottom (reverse:true).
  bool newestLast = true;

  bool _initialLoadDone = false;
  bool _isPaginating = false;

  StreamSubscription? _newMessageSub;
  StreamSubscription? _sentMessageSub;
  StreamSubscription? _statusUpdateSub;
  StreamSubscription? _typingSub;

  bool? _lastSentTyping;
  DateTime? _lastSentTypingAt;
  Timer? _typingStopTimer;

  bool _otherUserIsTyping = false;
  bool get otherUserIsTyping => _otherUserIsTyping;

  /// broadcast stream so UI can react quickly (scroll)
  final StreamController<ChatMessageModel> _messageController =
      StreamController<ChatMessageModel>.broadcast();
  Stream<ChatMessageModel> get messageStream => _messageController.stream;

  /// Keep a set of server message ids we've already processed (prevents double-handling
  /// from hybrid + socket echoes).
  final Set<String> _processedServerMessageIds = {};

  /// Configurable thresholds:
  final int _matchWindowSeconds =
      30; // time window to match server->optimistic by seconds
  final int _duplicateRemovalWindowSeconds =
      5; // when replacing, remove very-close optimistics

  ChatPageNotifier(this.otherUserId, this.currentUserId)
    : super(const ChatPageState()) {
    _loadMessagesInstantly();
    _setupWebSocketListeners();
  }

  // -------------------------
  // WebSocket listeners
  // -------------------------
  void _setupWebSocketListeners() {
    // Listen to typing events from the other user
    _typingSub = ChatEngineService.instance.typingStream.listen((typingStatus) {
      // Only react if it's the other user in this conversation
      if (typingStatus.userId == otherUserId) {
        _otherUserIsTyping = typingStatus.isTyping;
      }
    });
  }

  int _binarySearchInsertIndexAscending(
    List<ChatMessageModel> list,
    DateTime ts,
  ) {
    int lo = 0, hi = list.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (list[mid].createdAt.isBefore(ts)) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  int _binarySearchInsertIndexDescending(
    List<ChatMessageModel> list,
    DateTime ts,
  ) {
    int lo = 0, hi = list.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (list[mid].createdAt.isAfter(ts)) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  // -------------------------
  // Message confirmation & status updates
  // -------------------------

  bool _isStatusBetter(String currentStatus, String newStatus) {
    final cur = ChatMessageModel.messageStatusPriority(currentStatus);
    final neu = ChatMessageModel.messageStatusPriority(newStatus);
    return cur > neu;
  }

  // -------------------------
  // Local cache load + background sync
  // -------------------------
  void _loadMessagesInstantly() {
    if (_initialLoadDone) return;
    _initialLoadDone = true;
    _doLoadMessages(allowDbFallback: true);
  }

  /// Force reload messages from DB (call when entering chat to get latest statuses)
  /// WHATSAPP-STYLE: Always show correct tick status when entering chat
  Future<void> forceReloadFromDB() async {
    await _doLoadMessages(allowDbFallback: true);
  }

  Future<void> _doLoadMessages({required bool allowDbFallback}) async {
    try {
      final openedCached = OpenedChatsCache.instance.getMessages(otherUserId);
      if (openedCached != null && openedCached.isNotEmpty) {
        // Mark stale 'sending' messages as 'failed' (same logic as DB path)
        final list = <ChatMessageModel>[];
        for (final m in openedCached) {
          final isStaleSending =
              m.messageStatus == 'sending' &&
              m.senderId == currentUserId &&
              DateTime.now().difference(m.createdAt) > _sendingStaleAfter;
          if (isStaleSending) {
            list.add(m.copyWith(messageStatus: 'failed'));
            MessagesLocalDatabaseService.instance
                .updateMessageStatus(messageId: m.id, newStatus: 'failed')
                .catchError((_) => null);
          } else {
            list.add(m);
          }
        }
        if (!newestLast) {
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        } else {
          list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        }
        try {
          OpenedChatsCache.instance.cacheMessages(otherUserId, list);
        } catch (_) {}
        _safeSetState(_safeState.copyWith(messages: list, loading: false));
        return;
      }

      if (!allowDbFallback) {
        _safeSetState(_safeState.copyWith(loading: false));
        return;
      }

      final cached = await MessagesLocalDatabaseService.instance
          .loadConversationHistory(
            currentUserId: currentUserId,
            otherUserId: otherUserId,
            limit: 100,
            offset: 0,
          );

      if (cached.isNotEmpty) {
        // WhatsApp-style: any message still in 'sending' status from a
        // previous session is stale — the upload was interrupted when the
        // user navigated away. Mark them as 'failed' so the retry indicator
        // shows and the user can resend.
        final list = <ChatMessageModel>[];
        for (final m in cached) {
          final isStaleSending =
              m.messageStatus == 'sending' &&
              m.senderId == currentUserId &&
              DateTime.now().difference(m.createdAt) > _sendingStaleAfter;
          if (isStaleSending) {
            list.add(m.copyWith(messageStatus: 'failed'));
            // Persist the failed status to DB in background
            MessagesLocalDatabaseService.instance
                .updateMessageStatus(messageId: m.id, newStatus: 'failed')
                .catchError((_) => null);
          } else {
            list.add(m);
          }
        }

        try {
          OpenedChatsCache.instance.cacheMessages(otherUserId, list);
        } catch (_) {}

        if (!newestLast) {
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        } else {
          list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        }
        _safeSetState(_safeState.copyWith(messages: list, loading: false));
      } else {
        // ChatEngineService handles remote sync automatically
        _safeSetState(_safeState.copyWith(loading: false));
      }
    } catch (e) {
      debugPrint('⚠️ Cache load failed: $e');
      // ChatEngineService handles remote sync automatically
      _safeSetState(_safeState.copyWith(loading: false));
    }
  }

  // -------------------------
  // Load / Pagination (throttled)
  // -------------------------
  Future<void> loadMessages({bool loadMore = false}) async {
    if (!loadMore) {
      _safeSetState(_safeState.copyWith(loading: false));
      return;
    }
    if (_isPaginating || !_safeState.hasMore) return;
    _isPaginating = true;

    try {
      final nextPage = _safeState.currentPage + 1;
      const pageSize = 50;
      final offset = (nextPage - 1) * pageSize;

      final older = await MessagesLocalDatabaseService.instance
          .loadConversationHistory(
            currentUserId: currentUserId,
            otherUserId: otherUserId,
            limit: pageSize,
            offset: offset,
          );

      if (older.isEmpty) {
        _safeSetState(_safeState.copyWith(hasMore: false));
        return;
      }

      final merged = _mergeMessages(_safeState.messages, older);
      _safeSetState(
        _safeState.copyWith(
          messages: merged,
          currentPage: nextPage,
          hasMore: older.length >= pageSize,
        ),
      );
      try {
        OpenedChatsCache.instance.cacheMessages(otherUserId, merged);
      } catch (_) {}
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Pagination error: $e');
      }
    } finally {
      _isPaginating = false;
    }
  }

  // -------------------------
  // Efficient merge (linear)
  // -------------------------
  List<ChatMessageModel> _mergeMessages(
    List<ChatMessageModel> current,
    List<ChatMessageModel> fresh,
  ) {
    final a = List.of(current);
    final b = List.of(fresh);

    if (newestLast) {
      a.sort((x, y) => x.createdAt.compareTo(y.createdAt));
      b.sort((x, y) => x.createdAt.compareTo(y.createdAt));
    } else {
      a.sort((x, y) => y.createdAt.compareTo(x.createdAt));
      b.sort((x, y) => y.createdAt.compareTo(x.createdAt));
    }

    final currentById = {for (var m in a) m.id: m};
    for (int i = 0; i < b.length; i++) {
      final cur = currentById[b[i].id];
      if (cur != null &&
          _isStatusBetter(cur.messageStatus, b[i].messageStatus)) {
        b[i] = b[i].copyWith(
          messageStatus: cur.messageStatus,
          isRead: cur.isRead,
          deliveredAt: cur.deliveredAt ?? b[i].deliveredAt,
          readAt: cur.readAt ?? b[i].readAt,
        );
      }
    }

    final merged = <ChatMessageModel>[];
    int i = 0, j = 0;
    while (i < a.length && j < b.length) {
      if (a[i].id == b[j].id) {
        merged.add(b[j]); // prefer backend copy
        i++;
        j++;
      } else {
        final chooseA = newestLast
            ? a[i].createdAt.isBefore(b[j].createdAt)
            : a[i].createdAt.isAfter(b[j].createdAt);
        if (chooseA) {
          merged.add(a[i]);
          i++;
        } else {
          merged.add(b[j]);
          j++;
        }
      }
    }
    if (i < a.length) merged.addAll(a.sublist(i));
    if (j < b.length) merged.addAll(b.sublist(j));

    // Re-add optimistic messages not present in backend yet
    final optimistic = current
        .where((m) => m.id.startsWith('temp_') || m.id.startsWith('local_'))
        .toList();
    for (final opt in optimistic) {
      final exists = merged.any(
        (x) =>
            x.message == opt.message &&
            x.senderId == opt.senderId &&
            x.createdAt.difference(opt.createdAt).abs().inSeconds < 5,
      );
      if (!exists) {
        if (newestLast) {
          final idx = _binarySearchInsertIndexAscending(merged, opt.createdAt);
          merged.insert(idx, opt);
        } else {
          final idx = _binarySearchInsertIndexDescending(merged, opt.createdAt);
          merged.insert(idx, opt);
        }
      }
    }

    return merged;
  }

  // -------------------------
  // Sending messages (optimistic)
  // -------------------------
  Future<bool> sendMessage(String message) async {
    if (message.trim().isEmpty) return false;
    if (_safeState.sending) return false;

    _safeSetState(_safeState.copyWith(sending: true, clearError: true));

    try {
      final sent = await ChatEngineService.instance.sendMessage(
        messageText: message,
        receiverId: otherUserId,
      );

      _safeSetState(_safeState.copyWith(sending: false));

      if (sent == null) {
        _safeSetState(_safeState.copyWith(error: 'Failed to send message'));
        return false;
      }

      addIncomingMessage(sent);
      return true;
    } catch (e) {
      debugPrint('Error sending message: $e');
      _safeSetState(
        _safeState.copyWith(
          error: 'An error occurred while sending message',
          sending: false,
        ),
      );
      return false;
    }
  }

  // -------------------------
  // Delete
  // -------------------------
  Future<bool> deleteMessage(String messageId) async {
    try {
      if (_verboseLogs && kDebugMode) {
        debugPrint(
          '🗑️ [ChatPageNotifier] Requesting delete for message: $messageId',
        );
      }

      return await ChatEngineService.instance.deleteMessage(
        chatId: messageId,
        deleteType: 'everyone',
      );
    } catch (e, st) {
      debugPrint(
        '❌ [ChatPageNotifier] Exception deleting message $messageId: $e\n$st',
      );
      _safeSetState(_safeState.copyWith(error: 'Failed to delete message'));
      return false;
    }
  }

  Future<bool> deleteMessageForMe(String messageId) async {
    try {
      if (_verboseLogs && kDebugMode) {
        debugPrint(
          '🗑️ [ChatPageNotifier] (local-only) Delete for me: $messageId',
        );
      }

      return await ChatEngineService.instance.deleteMessage(
        chatId: messageId,
        deleteType: 'me',
      );
    } catch (e, st) {
      debugPrint(
        '❌ [ChatPageNotifier] Exception deleting (local-only) $messageId: '
        '$e\n$st',
      );
      _safeSetState(
        _safeState.copyWith(error: 'Failed to delete message locally'),
      );
      return false;
    }
  }

  // -------------------------
  // Selection handling
  // -------------------------
  bool get hasSelection => _safeState.selectedMessageIds.isNotEmpty;

  void toggleMessageSelection(String messageId) {
    if (messageId.isEmpty) return;
    final updated = <String>{..._safeState.selectedMessageIds};
    if (updated.contains(messageId)) {
      updated.remove(messageId);
    } else {
      updated.add(messageId);
    }
    _safeSetState(_safeState.copyWith(selectedMessageIds: updated));
  }

  /// Add reaction to a message
  Future<void> addReactionToMessage(String messageId, String emoji) async {
    try {
      await ChatEngineService.instance.addReaction(
        chatId: messageId,
        emoji: emoji,
      );
    } catch (e) {
      debugPrint('❌ Failed to add reaction: $e');
    }
  }

  /// Remove reaction from a message
  /// (Backend toggles if same emoji is sent)
  Future<void> removeReactionFromMessage(String messageId) async {
    try {
      // Find the existing reaction for current user to get the emoji to toggle
      final msg = _safeState.messages.firstWhere((m) => m.id == messageId);
      final userReaction = msg.reactions.firstWhere(
        (r) => r.userId == currentUserId,
      );
      
      await ChatEngineService.instance.addReaction(
        chatId: messageId,
        emoji: userReaction.emoji,
      );
    } catch (e) {
      debugPrint('❌ Failed to remove reaction: $e');
    }
  }

  void clearSelection() {
    if (!hasSelection) return;
    _safeSetState(_safeState.copyWith(selectedMessageIds: {}));
  }

  Future<void> deleteSelectedMessages({required bool forEveryone}) async {
    if (!hasSelection) return;
    final ids = _safeState.selectedMessageIds.toList();
    if (_verboseLogs && kDebugMode) {
      debugPrint(
        '🗑️ [ChatPageNotifier] Deleting ${ids.length} selected message(s) '
        '(forEveryone=$forEveryone): $ids',
      );
    }

    for (final id in ids) {
      final ok = forEveryone
          ? await deleteMessage(id)
          : await deleteMessageForMe(id);
      if (!ok) {
        if (_verboseLogs && kDebugMode) {
          debugPrint(
            '⚠️ [ChatPageNotifier] Failed to delete selected message: $id',
          );
        }
      }
    }

    if (_verboseLogs && kDebugMode) {
      debugPrint('🗑️ [ChatPageNotifier] Finished deleting selected messages');
    }
    _safeSetState(_safeState.copyWith(selectedMessageIds: {}));
  }

  // -------------------------
  // Replace local message with server message (improved matching & cleanup)
  // -------------------------
  void replaceLocalMessageWithServer(
    ChatMessageModel serverMessage, {
    String? localMessageId,
  }) {
    // If we've already processed this server id, skip
    if (serverMessage.id.isNotEmpty &&
        _processedServerMessageIds.contains(serverMessage.id)) {
      if (_verboseLogs && kDebugMode) {
        debugPrint(
          'ℹ️ replaceLocalMessageWithServer: server ${serverMessage.id} already processed',
        );
      }
      return;
    }
    if (serverMessage.id.isNotEmpty) {
      _processedServerMessageIds.add(serverMessage.id);
    }

    // 1) Exact id match -> replace (preserve reply data from existing)
    final idxById = _safeState.messages.indexWhere(
      (m) => m.id == serverMessage.id,
    );
    if (idxById != -1) {
      final list = List<ChatMessageModel>.from(_safeState.messages);
      final mergedMessage = _preserveLocalImagePath(
        list[idxById],
        serverMessage,
      );
      list[idxById] = mergedMessage;
      _safeSetState(_safeState.copyWith(messages: list));
      try {
        OpenedChatsCache.instance.cacheMessages(otherUserId, list);
      } catch (_) {}
      try {
        _messageController.add(mergedMessage);
      } catch (_) {}
      return;
    }

    // 2) If localMessageId provided, replace that exact optimistic
    if (localMessageId != null) {
      final li = _safeState.messages.indexWhere((m) => m.id == localMessageId);
      if (_verboseLogs && kDebugMode) {
        debugPrint(
          '🔍 [ChatPageNotifier] replaceLocalMessageWithServer: looking for $localMessageId, found at index: $li',
        );
      }
      if (li != -1) {
        final list = List<ChatMessageModel>.from(_safeState.messages);
        // Preserve localImagePath from optimistic message to prevent image shift
        final optimistic = list[li];
        if (_verboseLogs && kDebugMode) {
          debugPrint(
            '🔍 [ChatPageNotifier] optimistic.replyToMessage: ${optimistic.replyToMessage?.id}',
          );
          debugPrint(
            '🔍 [ChatPageNotifier] serverMessage.replyToMessage: ${serverMessage.replyToMessage?.id}',
          );
        }
        final mergedMessage = _preserveLocalImagePath(
          optimistic,
          serverMessage,
        );
        if (_verboseLogs && kDebugMode) {
          debugPrint(
            '🔍 [ChatPageNotifier] mergedMessage.replyToMessage: ${mergedMessage.replyToMessage?.id}',
          );
        }
        list[li] = mergedMessage;
        _safeSetState(_safeState.copyWith(messages: list));
        try {
          OpenedChatsCache.instance.cacheMessages(otherUserId, list);
        } catch (_) {}
        try {
          _messageController.add(mergedMessage);
        } catch (_) {}
        _cleanupStaleOptimistics(mergedMessage, excludeIndex: li);
        return;
      }
    }

    // 3) Find optimistic candidates (temp_/local_) with same sender + same message text
    const followUpPrefix = 'Follow up Text:';
    final candidates = <int>[];
    for (int i = 0; i < _safeState.messages.length; i++) {
      final m = _safeState.messages[i];
      if ((m.id.startsWith('temp_') || m.id.startsWith('local_')) &&
          m.senderId == serverMessage.senderId) {
        // Check for exact match
        if (m.message == serverMessage.message) {
          candidates.add(i);
        }
        // Check for follow-up match: local has prefix, server has clean text
        else if (m.isFollowUp && serverMessage.isFollowUp) {
          final localClean = m.message.startsWith(followUpPrefix)
              ? m.message.substring(followUpPrefix.length).trim()
              : m.message;
          if (localClean == serverMessage.message) {
            candidates.add(i);
          }
        }
      }
    }

    if (candidates.isNotEmpty) {
      // choose candidate with minimal time delta to serverMessage.createdAt
      int bestIdx = candidates.first;
      int bestDelta = _safeState.messages[bestIdx].createdAt
          .difference(serverMessage.createdAt)
          .abs()
          .inSeconds;
      for (final idx in candidates) {
        final delta = _safeState.messages[idx].createdAt
            .difference(serverMessage.createdAt)
            .abs()
            .inSeconds;
        if (delta < bestDelta) {
          bestDelta = delta;
          bestIdx = idx;
        }
      }

      // Accept match only if within sensible window
      if (bestDelta <= _matchWindowSeconds) {
        final list = List<ChatMessageModel>.from(_safeState.messages);
        // Preserve localImagePath from optimistic message to prevent image shift
        final optimistic = list[bestIdx];
        final mergedMessage = _preserveLocalImagePath(
          optimistic,
          serverMessage,
        );
        list[bestIdx] = mergedMessage;
        _safeSetState(_safeState.copyWith(messages: list));
        try {
          OpenedChatsCache.instance.cacheMessages(otherUserId, list);
        } catch (_) {}
        try {
          _messageController.add(mergedMessage);
        } catch (_) {}
        // remove any other very-close optimistics to avoid lingering dupes
        _cleanupStaleOptimistics(mergedMessage, excludeIndex: bestIdx);
        return;
      }
    }

    // 4) No optimistic matched. Check if an existing non-optimistic duplicate (same sender+text) exists closeby -> skip
    final hasNonOptDuplicate = _safeState.messages.any((m) {
      if (m.id.startsWith('temp_') || m.id.startsWith('local_')) return false;
      if (m.senderId != serverMessage.senderId) return false;
      if (m.createdAt.difference(serverMessage.createdAt).abs().inSeconds >
          _matchWindowSeconds) {
        return false;
      }

      // Exact match
      if (m.message == serverMessage.message) return true;

      // Follow-up match: existing has prefix, server has clean text
      if (m.isFollowUp && serverMessage.isFollowUp) {
        final existingClean = m.message.startsWith(followUpPrefix)
            ? m.message.substring(followUpPrefix.length).trim()
            : m.message;
        if (existingClean == serverMessage.message) return true;
      }

      return false;
    });

    if (hasNonOptDuplicate) {
      if (_verboseLogs && kDebugMode) {
        debugPrint(
          'ℹ️ Server message ${serverMessage.id} skipped because duplicate server message exists',
        );
      }
      return;
    }

    // 5) Fallback: add as incoming message
    addIncomingMessage(serverMessage);
  }

  // Preserve localImagePath and follow-up message text from optimistic message
  // This prevents image "shift" and ensures sender sees full follow-up text
  ChatMessageModel _preserveLocalImagePath(
    ChatMessageModel optimistic,
    ChatMessageModel serverMessage,
  ) {
    ChatMessageModel result = serverMessage;

    // For follow-up messages, preserve the original message text with prefix for sender display
    // Server sends clean text, but sender should see "Follow up Text: X"
    if (optimistic.isFollowUp && serverMessage.isFollowUp) {
      const followUpPrefix = 'Follow up Text:';
      final optimisticHasPrefix = optimistic.message.startsWith(followUpPrefix);
      final serverHasPrefix = serverMessage.message.startsWith(followUpPrefix);

      // If optimistic has prefix but server doesn't, preserve optimistic's message text
      if (optimisticHasPrefix && !serverHasPrefix) {
        result = result.copyWith(message: optimistic.message);
      }
    }

    // If optimistic has localImagePath and server message is an image or video, preserve it
    final isMediaMessage =
        serverMessage.isImageMessage ||
        serverMessage.messageType == MessageType.video;
    if (optimistic.localImagePath != null &&
        optimistic.localImagePath!.isNotEmpty &&
        isMediaMessage) {
      // Prefer optimistic dimensions, but fall back to server dimensions (not null)
      final hasValidOptimisticDimensions =
          optimistic.imageWidth != null &&
          optimistic.imageHeight != null &&
          optimistic.imageWidth! > 0 &&
          optimistic.imageHeight! > 0;

      final hasValidServerDimensions =
          serverMessage.imageWidth != null &&
          serverMessage.imageHeight != null &&
          serverMessage.imageWidth! > 0 &&
          serverMessage.imageHeight! > 0;

      // Use optimistic dimensions first, then server dimensions, then leave unchanged
      final finalWidth = hasValidOptimisticDimensions
          ? optimistic.imageWidth
          : (hasValidServerDimensions ? serverMessage.imageWidth : null);
      final finalHeight = hasValidOptimisticDimensions
          ? optimistic.imageHeight
          : (hasValidServerDimensions ? serverMessage.imageHeight : null);

      result = result.copyWith(
        localImagePath: optimistic.localImagePath,
        imageWidth: finalWidth,
        imageHeight: finalHeight,
      );

      // For videos, also preserve the thumbnail URL from optimistic message
      if (serverMessage.messageType == MessageType.video &&
          optimistic.thumbnailUrl != null &&
          optimistic.thumbnailUrl!.isNotEmpty) {
        result = result.copyWith(thumbnailUrl: optimistic.thumbnailUrl);
      }
    }

    // Preserve replyToMessage from optimistic message
    // Server only returns replyToMessageId, not the full message object
    if (optimistic.replyToMessage != null && result.replyToMessage == null) {
      result = result.copyWith(replyToMessage: optimistic.replyToMessage);
    }

    return result;
  }

  // When we replace an optimistic with server message, remove other extremely close optimistics
  void _cleanupStaleOptimistics(
    ChatMessageModel serverMessage, {
    required int excludeIndex,
  }) {
    final cutoff = Duration(seconds: _duplicateRemovalWindowSeconds);
    final now = serverMessage.createdAt;
    final list = List<ChatMessageModel>.from(_safeState.messages);
    final toRemove = <int>[];

    for (int i = 0; i < list.length; i++) {
      if (i == excludeIndex) continue;
      final m = list[i];
      if ((m.id.startsWith('temp_') || m.id.startsWith('local_')) &&
          m.senderId == serverMessage.senderId &&
          m.message == serverMessage.message &&
          m.createdAt.difference(now).abs() <= cutoff) {
        toRemove.add(i);
      }
    }

    // Remove in reverse index order
    if (toRemove.isNotEmpty) {
      toRemove.sort((a, b) => b.compareTo(a));
      for (final idx in toRemove) {
        list.removeAt(idx);
      }
      _safeSetState(_safeState.copyWith(messages: list));
      try {
        OpenedChatsCache.instance.cacheMessages(otherUserId, list);
      } catch (_) {}
    }
  }

  // -------------------------
  // Add incoming message (public)
  // Improved: attempts to replace matching optimistic message first, dedupe near-duplicates
  // -------------------------
  void addIncomingMessage(ChatMessageModel newMessage) {
    if (_verboseLogs && kDebugMode) {
      debugPrint(
        '🔍 [ChatPageNotifier] addIncomingMessage: id=${newMessage.id}, replyToMessage=${newMessage.replyToMessage?.id}',
      );
    }
    // 1) Exact id exists -> skip
    if (newMessage.id.isNotEmpty &&
        _safeState.messages.any((m) => m.id == newMessage.id)) {
      if (kDebugMode) {
        debugPrint(
          'addIncomingMessage: exact id ${newMessage.id} exists, skipping',
        );
      }
      return;
    }

    // 2) Try to replace nearest optimistic candidate
    final optCandidates = <int>[];
    for (int i = 0; i < _safeState.messages.length; i++) {
      final m = _safeState.messages[i];
      if ((m.id.startsWith('temp_') || m.id.startsWith('local_')) &&
          m.senderId == newMessage.senderId &&
          m.message == newMessage.message) {
        optCandidates.add(i);
      }
    }

    if (optCandidates.isNotEmpty) {
      int bestIdx = optCandidates.first;
      int bestDelta = _safeState.messages[bestIdx].createdAt
          .difference(newMessage.createdAt)
          .abs()
          .inSeconds;
      for (final idx in optCandidates) {
        final delta = _safeState.messages[idx].createdAt
            .difference(newMessage.createdAt)
            .abs()
            .inSeconds;
        if (delta < bestDelta) {
          bestDelta = delta;
          bestIdx = idx;
        }
      }

      if (bestDelta <= _matchWindowSeconds) {
        final list = List<ChatMessageModel>.from(_safeState.messages);
        // Preserve localImagePath from optimistic message to prevent image shift
        final optimistic = list[bestIdx];
        final mergedMessage = _preserveLocalImagePath(optimistic, newMessage);
        list[bestIdx] = mergedMessage;
        _safeSetState(_safeState.copyWith(messages: list));
        try {
          OpenedChatsCache.instance.cacheMessages(otherUserId, list);
        } catch (_) {}
        try {
          _messageController.add(mergedMessage);
        } catch (_) {}
        _cleanupStaleOptimistics(mergedMessage, excludeIndex: bestIdx);
        return;
      }
    }

    // 3) If there's already a non-optimistic duplicate (server-origin) close by, skip insert
    final existingNonOpt = _safeState.messages.any(
      (m) =>
          !m.id.startsWith('temp_') &&
          !m.id.startsWith('local_') &&
          m.senderId == newMessage.senderId &&
          m.message == newMessage.message &&
          m.createdAt.difference(newMessage.createdAt).abs().inSeconds <=
              _matchWindowSeconds,
    );

    if (existingNonOpt) {
      if (kDebugMode) {
        debugPrint(
          'addIncomingMessage: skipping because a server-origin duplicate exists',
        );
      }
      return;
    }

    // 4) Normal insert respecting ordering preference
    final list = List.of(_safeState.messages);
    if (newestLast) {
      final idx = _binarySearchInsertIndexAscending(list, newMessage.createdAt);
      list.insert(idx, newMessage);
    } else {
      final idx = _binarySearchInsertIndexDescending(
        list,
        newMessage.createdAt,
      );
      list.insert(idx, newMessage);
    }
    _safeSetState(_safeState.copyWith(messages: list));
    try {
      OpenedChatsCache.instance.cacheMessages(otherUserId, list);
    } catch (_) {}
    try {
      _messageController.add(newMessage);
    } catch (_) {}
  }

  // -------------------------
  // Refresh UI from local DB messages (ONLY for initial load or fallback)
  // -------------------------
  void refreshFromLocalMessages(List<ChatMessageModel> updatedMessages) {
    if (_verboseLogs && kDebugMode) {
      debugPrint(
        '🔍 [ChatPageNotifier] refreshFromLocalMessages called with ${updatedMessages.length} messages',
      );
    }

    String baseDedupeKey(ChatMessageModel msg) {
      final type = msg.messageType.name;
      final text = msg.message.trim();
      final fileName = msg.fileName?.trim();
      final imageUrl = msg.imageUrl?.trim();
      final localPath = msg.localImagePath?.trim();
      final thumb = msg.thumbnailUrl?.trim();
      final mediaHint = (fileName != null && fileName.isNotEmpty)
          ? fileName
          : (imageUrl != null && imageUrl.isNotEmpty)
          ? imageUrl
          : (localPath != null && localPath.isNotEmpty)
          ? localPath
          : (thumb != null && thumb.isNotEmpty)
          ? thumb
          : '';
      return '${msg.senderId}|$type|$text|$mediaHint';
    }

    // Sort messages based on display order
    final sorted = List<ChatMessageModel>.from(updatedMessages);
    if (newestLast) {
      sorted.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    } else {
      sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    // Remove local_* duplicates when a server copy exists with same content
    // Build a lookup set of server messages for O(1) duplicate detection
    final serverMessageKeys = <String>{};
    for (final x in sorted) {
      if (x.id.startsWith('local_') || x.id.startsWith('temp_')) continue;
      final base = baseDedupeKey(x);
      final bucket = x.createdAt.millisecondsSinceEpoch ~/ 60000;
      serverMessageKeys.add('$base|$bucket');
      // Also add adjacent minute bucket to handle boundary cases
      serverMessageKeys.add('$base|${bucket - 1}');
      serverMessageKeys.add('$base|${bucket + 1}');
    }
    final deduped = <ChatMessageModel>[];
    for (final m in sorted) {
      final isOptimistic =
          m.id.startsWith('local_') || m.id.startsWith('temp_');
      if (isOptimistic) {
        final base = baseDedupeKey(m);
        final bucket = m.createdAt.millisecondsSinceEpoch ~/ 60000;
        final key = '$base|$bucket';
        if (serverMessageKeys.contains(key)) {
          continue;
        }
      }
      deduped.add(m);
    }

    // Merge with existing in-memory messages while preserving better statuses
    // and image dimensions (for images where DB might lack dimensions)
    final currentById = {for (final m in _safeState.messages) m.id: m};
    if (_verboseLogs && kDebugMode) {
      debugPrint(
        '🔍 [ChatPageNotifier] currentById has ${currentById.length} messages, checking for replyToMessage...',
      );
      for (final entry in currentById.entries) {
        if (entry.value.replyToMessage != null) {
          debugPrint(
            '🔍 [ChatPageNotifier] Message ${entry.key.substring(0, 8)}... has replyToMessage: ${entry.value.replyToMessage!.id.substring(0, 8)}...',
          );
        }
      }
    }
    final merged = deduped.map((m) {
      final cur = currentById[m.id];
      if (_verboseLogs &&
          kDebugMode &&
          (m.replyToMessageId != null ||
              (cur != null && cur.replyToMessage != null))) {
        debugPrint(
          '🔍 [ChatPageNotifier] Merging message ${m.id.substring(0, 8)}...: m.replyToMessage=${m.replyToMessage != null}, cur=${cur != null}, cur.replyToMessage=${cur?.replyToMessage != null}',
        );
      }
      if (cur != null) {
        // Determine which dimensions to use (prefer in-memory if DB lacks them)
        final dbHasDimensions =
            m.imageWidth != null &&
            m.imageHeight != null &&
            m.imageWidth! > 0 &&
            m.imageHeight! > 0;
        final memHasDimensions =
            cur.imageWidth != null &&
            cur.imageHeight != null &&
            cur.imageWidth! > 0 &&
            cur.imageHeight! > 0;

        final finalWidth = dbHasDimensions
            ? m.imageWidth
            : (memHasDimensions ? cur.imageWidth : null);
        final finalHeight = dbHasDimensions
            ? m.imageHeight
            : (memHasDimensions ? cur.imageHeight : null);

        // Preserve localImagePath from memory if DB doesn't have it
        final finalLocalPath =
            (m.localImagePath != null && m.localImagePath!.isNotEmpty)
            ? m.localImagePath
            : cur.localImagePath;

        if (_isStatusBetter(cur.messageStatus, m.messageStatus) ||
            (!dbHasDimensions && memHasDimensions) ||
            finalLocalPath != m.localImagePath ||
            (cur.replyToMessage != null && m.replyToMessage == null)) {
          return m.copyWith(
            messageStatus: _isStatusBetter(cur.messageStatus, m.messageStatus)
                ? cur.messageStatus
                : m.messageStatus,
            isRead: _isStatusBetter(cur.messageStatus, m.messageStatus)
                ? cur.isRead
                : m.isRead,
            deliveredAt: cur.deliveredAt ?? m.deliveredAt,
            readAt: cur.readAt ?? m.readAt,
            imageWidth: finalWidth,
            imageHeight: finalHeight,
            localImagePath: finalLocalPath,
            replyToMessage: m.replyToMessage ?? cur.replyToMessage,
          );
        }
      }
      // Also check if in-memory message has replyToMessage that DB doesn't
      final existingWithReply = currentById.values.firstWhere(
        (cur) =>
            cur.replyToMessage != null &&
            m.replyToMessage == null &&
            cur.senderId == m.senderId &&
            cur.message.trim() == m.message.trim() &&
            cur.createdAt.difference(m.createdAt).abs().inSeconds <= 60,
        orElse: () => m,
      );
      if (existingWithReply.replyToMessage != null &&
          m.replyToMessage == null) {
        if (_verboseLogs && kDebugMode) {
          debugPrint(
            '🔍 [ChatPageNotifier] Secondary lookup found replyToMessage for ${m.id.substring(0, 8)}...: ${existingWithReply.replyToMessage!.id.substring(0, 8)}...',
          );
        }
        return m.copyWith(replyToMessage: existingWithReply.replyToMessage);
      }
      return m;
    }).toList();

    if (_verboseLogs && kDebugMode) {
      for (final msg in merged) {
        if (msg.replyToMessageId != null) {
          debugPrint(
            '🔍 [ChatPageNotifier] After merge: ${msg.id.substring(0, 8)}... has replyToMessage=${msg.replyToMessage != null}',
          );
        }
      }
    }

    _safeSetState(_safeState.copyWith(messages: merged));
    try {
      OpenedChatsCache.instance.cacheMessages(otherUserId, merged);
    } catch (_) {}
  }

  // -------------------------
  // Update thumbnail URL for a message (IN-MEMORY + DB)
  // Used when video thumbnail is cached to permanent storage
  // -------------------------
  void updateThumbnailUrl(String messageId, String thumbnailUrl) {
    final index = _safeState.messages.indexWhere((m) => m.id == messageId);
    if (index == -1) return;

    final list = List<ChatMessageModel>.from(_safeState.messages);
    list[index] = list[index].copyWith(thumbnailUrl: thumbnailUrl);
    _safeSetState(_safeState.copyWith(messages: list));
    try {
      OpenedChatsCache.instance.cacheMessages(otherUserId, list);
    } catch (_) {}

    // Persist to local DB so thumbnail survives app restart / chat reload.
    MessagesLocalDatabaseService.instance
        .updateThumbnailUrl(messageId: messageId, thumbnailUrl: thumbnailUrl)
        .catchError((_) => null);
  }

  // -------------------------
  // Update single message status (IN-MEMORY, NO DB RELOAD)
  // -------------------------
  void updateMessageStatus(String messageId, String status) {
    final index = _safeState.messages.indexWhere((m) => m.id == messageId);
    if (index == -1) return; // Message not in current view

    final currentMessage = _safeState.messages[index];

    // Prevent status regression, e.g. read → delivered or delivered → sent
    if (_isStatusBetter(currentMessage.messageStatus, status)) {
      if (_verboseLogs && kDebugMode) {
        debugPrint(
          '⚠️ [Memory] Ignoring status regression for $messageId: '
          '${currentMessage.messageStatus} → $status',
        );
      }
      return;
    }

    final now = DateTime.now();
    final list = List<ChatMessageModel>.from(_safeState.messages);
    list[index] = currentMessage.copyWith(
      messageStatus: status,
      isRead: status == 'read' ? true : currentMessage.isRead,
      deliveredAt: status == 'delivered' ? now : currentMessage.deliveredAt,
      readAt: status == 'read' ? now : currentMessage.readAt,
      updatedAt: now,
    );

    _safeSetState(_safeState.copyWith(messages: list));
    try {
      OpenedChatsCache.instance.cacheMessages(otherUserId, list);
    } catch (_) {}
  }

  // -------------------------
  // Replace local message with server message
  // -------------------------
  void replaceLocalWithServerMessage(ChatMessageModel serverMessage) {
    // Skip if this is a fake/incomplete message (empty content)
    if (serverMessage.message.isEmpty) {
      if (_verboseLogs && kDebugMode) {
        debugPrint(
          '⚠️ UI: Ignoring empty server message (ID: ${serverMessage.id})',
        );
      }
      return;
    }

    bool foundAndReplaced = false;

    // Find and replace local message (by content and sender - timing is flexible)
    final updated = _safeState.messages.map((m) {
      // Match criteria: local ID + same content + same sender + reasonable time window
      if (m.id.startsWith('local_') &&
          m.message.trim() == serverMessage.message.trim() &&
          m.senderId == serverMessage.senderId &&
          m.createdAt.difference(serverMessage.createdAt).abs().inSeconds <
              60) {
        if (_verboseLogs && kDebugMode) {
          debugPrint(
            '🔄 UI: Replacing local ${m.id} with server ${serverMessage.id}',
          );
          debugPrint(
            '   Old status: ${m.messageStatus} → New status: ${serverMessage.messageStatus}',
          );
        }
        foundAndReplaced = true;
        // Preserve replyToMessage from local message (server only returns ID)
        if (m.replyToMessage != null && serverMessage.replyToMessage == null) {
          return serverMessage.copyWith(replyToMessage: m.replyToMessage);
        }
        return serverMessage;
      }
      return m;
    }).toList();

    if (foundAndReplaced) {
      _safeSetState(_safeState.copyWith(messages: updated));
      try {
        OpenedChatsCache.instance.cacheMessages(otherUserId, updated);
      } catch (_) {}
      if (_verboseLogs && kDebugMode) {
        debugPrint('✅ UI: Message list updated with server message');
      }
    } else {
      if (_verboseLogs && kDebugMode) {
        debugPrint(
          '⚠️ UI: No matching local message found for server ID ${serverMessage.id}',
        );
      }
      final preview = serverMessage.message.length > 20
          ? serverMessage.message.substring(0, 20)
          : serverMessage.message;
      if (_verboseLogs && kDebugMode) {
        debugPrint(
          '   Content: "$preview${serverMessage.message.length > 20 ? "..." : ""}"',
        );
        debugPrint('   Status: ${serverMessage.messageStatus}');
        debugPrint('   Sender: ${serverMessage.senderId}');
      }

      // Fallback: Match by content and sender only (ignore time and ID)
      final statusUpdated = _safeState.messages.map((m) {
        if (m.id.startsWith('local_') &&
            m.senderId == serverMessage.senderId &&
            m.message.trim() == serverMessage.message.trim()) {
          if (_verboseLogs && kDebugMode) {
            debugPrint(
              '🔄 Fallback: Replacing by content match ${m.id} → ${serverMessage.id}',
            );
          }
          return serverMessage;
        }
        return m;
      }).toList();

      _safeSetState(_safeState.copyWith(messages: statusUpdated));
      try {
        OpenedChatsCache.instance.cacheMessages(otherUserId, statusUpdated);
      } catch (_) {}
    }
  }

  // -------------------------
  // Upload progress tracking
  // -------------------------
  void updateUploadProgress(String messageId, double progress) {
    final newProgress = Map<String, double>.from(_safeState.uploadProgress);
    newProgress[messageId] = progress.clamp(0.0, 1.0);
    _safeSetState(_safeState.copyWith(uploadProgress: newProgress));
  }

  void clearUploadProgress(String messageId) {
    final newProgress = Map<String, double>.from(_safeState.uploadProgress);
    newProgress.remove(messageId);
    _safeSetState(_safeState.copyWith(uploadProgress: newProgress));
  }

  void markUploadFailed(String messageId) {
    // Update message status to 'failed'
    final index = _safeState.messages.indexWhere((m) => m.id == messageId);
    if (index != -1) {
      final list = List<ChatMessageModel>.from(_safeState.messages);
      list[index] = list[index].copyWith(messageStatus: 'failed');
      _safeSetState(_safeState.copyWith(messages: list));
      try {
        OpenedChatsCache.instance.cacheMessages(otherUserId, list);
      } catch (_) {}
    }
    // Clear progress
    clearUploadProgress(messageId);
  }

  // -------------------------
  // Typing indicator
  // -------------------------
  void sendTypingIndicator(bool isTyping) {
    try {
      const throttle = Duration(milliseconds: 700);
      const stopAfter = Duration(seconds: 2);

      void emit(bool v) {
        ChatEngineService.instance.sendTypingStatus(
          senderId: currentUserId,
          receiverId: otherUserId,
          isTyping: v,
        );
        _lastSentTyping = v;
        _lastSentTypingAt = DateTime.now();
      }

      if (!isTyping) {
        _typingStopTimer?.cancel();
        if (_lastSentTyping == false) return;
        emit(false);
        return;
      }

      final now = DateTime.now();
      if (_lastSentTyping == true &&
          _lastSentTypingAt != null &&
          now.difference(_lastSentTypingAt!) < throttle) {
        _typingStopTimer?.cancel();
        _typingStopTimer = Timer(stopAfter, () {
          if (_lastSentTyping == true) {
            try {
              emit(false);
            } catch (_) {}
          }
        });
        return;
      }

      emit(true);
      _typingStopTimer?.cancel();
      _typingStopTimer = Timer(stopAfter, () {
        if (_lastSentTyping == true) {
          try {
            emit(false);
          } catch (_) {}
        }
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ ChatPageNotifier: Failed to send typing indicator: $e');
      }
    }
  }

  // -------------------------
  // Clear error
  // -------------------------
  void clearError() {
    _safeSetState(_safeState.copyWith(error: null));
  }

  // -------------------------
  // Refresh
  // -------------------------
  Future<void> refresh() async {
    await loadMessages();
  }

  @override
  void dispose() {
    _newMessageSub?.cancel();
    _sentMessageSub?.cancel();
    _statusUpdateSub?.cancel();
    _typingSub?.cancel();
    _typingStopTimer?.cancel();
    if (!_messageController.isClosed) _messageController.close();
    super.dispose();
  }
}
