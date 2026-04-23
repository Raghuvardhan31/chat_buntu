// ============================================================================
// OPENED CHATS CACHE - WhatsApp-Style In-Memory Message Storage
// ============================================================================
//
// 🎯 PURPOSE:
// Keep recently opened conversation messages in RAM for instant re-access.
// When user re-opens a chat, messages load instantly (0ms) without DB queries.
//
// 📱 WHATSAPP-LIKE BEHAVIOR:
// • Open chat → Load from DB → Cache in memory
// • Leave chat → Cache stays in memory (for quick re-open)
// • Re-open chat → Instant display from cache
// • New message → Update both cache + DB simultaneously
// • Status updates → Update cache immediately (ticks appear instantly)
//
// ⚙️ CACHE FEATURES:
// • LRU Eviction: Max 10 chats (prevents memory bloat)
// • TTL Expiry: 15 minutes (auto-cleanup old chats)
// • Status Updates: In-memory tick updates (sent/delivered/read)
// • Message Operations: Add, update, delete, mark as deleted
// • Memory Management: Handles memory pressure gracefully
//
// 🔄 CACHE OPERATIONS:
// • getMessages() - Retrieve cached messages for a chat
// • cacheMessages() - Store messages in memory
// • addMessage() - Add new message to cache
// • updateMessageStatus() - Update message ticks
// • removeMessage() - Delete message from cache (delete-for-me)
// • markMessageAsDeleted() - Mark message as deleted (delete-for-everyone)
// • replaceMessageId() - Replace local ID with server ID
// • invalidate() - Remove specific chat from cache
// • clear() - Clear all caches (logout)
//
// ============================================================================

import 'package:flutter/foundation.dart';
import '../../models/chat_message_model.dart';

/// WhatsApp-style in-memory cache for opened conversation messages
///
/// Provides instant message display when re-opening recently viewed chats
/// without requiring SQLite or API calls.
class OpenedChatsCache {
  // Singleton
  static OpenedChatsCache? _instance;
  static OpenedChatsCache get instance {
    _instance ??= OpenedChatsCache._();
    return _instance!;
  }

  OpenedChatsCache._();

  // Enable only valuable logs (not verbose noise)
  static const bool _verboseLogs = false;

  // Configuration
  int _maxCachedChats = 10;
  Duration _cacheTTL = const Duration(minutes: 15);
  int _maxMessagesPerChat = 300;

  void configure({
    int? maxCachedChats,
    Duration? cacheTTL,
    int? maxMessagesPerChat,
  }) {
    if (maxCachedChats != null && maxCachedChats > 0) {
      _maxCachedChats = maxCachedChats;
    }
    if (cacheTTL != null && cacheTTL.inSeconds > 0) {
      _cacheTTL = cacheTTL;
    }
    if (maxMessagesPerChat != null && maxMessagesPerChat > 0) {
      _maxMessagesPerChat = maxMessagesPerChat;
    }
    _applyLimits();
  }

  // In-memory cache: otherUserId → List<ChatMessageModel>
  final Map<String, List<ChatMessageModel>> _messagesCache = {};

  // Cache timestamps for TTL validation
  final Map<String, DateTime> _cacheTimestamps = {};

  // Access order for LRU eviction (most recent at end)
  final List<String> _accessOrder = [];

  // =========================================================================
  // CACHE ACCESS
  // =========================================================================

  // =========================================================================
  // 📥 GET MESSAGES - Retrieve cached messages for instant display
  // =========================================================================

  /// Get cached messages for a conversation (WhatsApp-style instant loading)
  /// Returns null if cache miss or expired - caller should load from DB
  List<ChatMessageModel>? getMessages(String otherUserId) {
    if (!_messagesCache.containsKey(otherUserId)) {
      return null;
    }

    // Check TTL
    final cacheTime = _cacheTimestamps[otherUserId];
    if (cacheTime != null) {
      final age = DateTime.now().difference(cacheTime);
      if (age > _cacheTTL) {
        if (kDebugMode) {
          debugPrint('⏰ [OpenedChatsCache] EXPIRED: ${age.inMinutes}m old');
        }
        _removeFromCache(otherUserId);
        return null;
      }
    }

    // Update access order (LRU)
    _updateAccessOrder(otherUserId);

    final messages = _messagesCache[otherUserId]!;
    if (kDebugMode) {
      debugPrint('⚡ [OpenedChatsCache] HIT: ${messages.length} messages');
    }
    return List.from(messages); // Return copy to prevent mutation
  }

  /// Quick check: Is this conversation cached and ready for instant display?
  bool hasCachedMessages(String otherUserId) {
    return getMessages(otherUserId) != null;
  }

  /// Get cache statistics for debugging and monitoring
  Map<String, dynamic> get stats => {
    'cachedChats': _messagesCache.length,
    'maxChats': _maxCachedChats,
    'maxMessagesPerChat': _maxMessagesPerChat,
    'cacheTTLSeconds': _cacheTTL.inSeconds,
    'chatIds': _messagesCache.keys.toList(),
  };

  // =========================================================================
  // CACHE UPDATES
  // =========================================================================

  // =========================================================================
  // 💾 CACHE MESSAGES - Store messages in memory for instant access
  // =========================================================================

  /// Cache messages for a conversation (called after loading from DB)
  /// Preserves replyToMessage from existing cache (DB only stores replyToMessageId)
  void cacheMessages(String otherUserId, List<ChatMessageModel> messages) {
    // Enforce LRU limit
    _enforceLRULimit();

    // Build a map of existing replyToMessage objects before replacing cache
    final existingReplyMap = <String, ChatMessageModel>{};
    final existingMessages = _messagesCache[otherUserId];
    if (existingMessages != null) {
      for (final msg in existingMessages) {
        if (msg.replyToMessage != null) {
          existingReplyMap[msg.id] = msg.replyToMessage!;
        }
      }
    }

    // Copy and preserve replyToMessage from existing cache
    final copied = messages.map((msg) {
      if (msg.replyToMessage == null && existingReplyMap.containsKey(msg.id)) {
        return msg.copyWith(replyToMessage: existingReplyMap[msg.id]);
      }
      return msg;
    }).toList();

    final trimmed = _trimToMaxMessages(copied);
    _messagesCache[otherUserId] = trimmed;
    _cacheTimestamps[otherUserId] = DateTime.now();
    _updateAccessOrder(otherUserId);

    if (kDebugMode) {
      debugPrint('💾 [OpenedChatsCache] CACHED: ${messages.length} messages');
    }
  }

  // =========================================================================
  // ➕ ADD MESSAGE - Add new message to cache (real-time updates)
  // =========================================================================

  /// Add new message to cache (incoming/outgoing messages)
  /// Updates existing message if duplicate ID found
  /// Also replaces local/temp messages that match by content (for self-chat race condition)
  void addMessage(String otherUserId, ChatMessageModel message) {
    if (!_messagesCache.containsKey(otherUserId)) {
      return;
    }

    final messages = _messagesCache[otherUserId]!;

    // Check if message already exists by ID (prevent duplicates)
    final existingIndex = messages.indexWhere((m) => m.id == message.id);
    if (existingIndex != -1) {
      // Update existing message, but preserve replyToMessage if server didn't include it
      final existing = messages[existingIndex];
      ChatMessageModel updatedMessage = message;
      if (existing.replyToMessage != null && message.replyToMessage == null) {
        updatedMessage = message.copyWith(
          replyToMessage: existing.replyToMessage,
        );
      }
      messages[existingIndex] = updatedMessage;
      if (kDebugMode) {
        debugPrint(
          '🔄 [OpenedChatsCache] Updated: ${message.id.substring(0, 8)}...',
        );
      }
    } else {
      // Check for matching local/temp message (handles self-chat race condition)
      // Server message arrives but local message has different ID (local_xxx vs server UUID)
      final localIndex = messages.indexWhere(
        (m) =>
            (m.id.startsWith('local_') || m.id.startsWith('temp_')) &&
            m.message.trim() == message.message.trim() &&
            m.senderId == message.senderId &&
            m.createdAt.difference(message.createdAt).abs().inSeconds < 60,
      );

      if (localIndex != -1) {
        // Found matching local message - replace it
        final localMsg = messages[localIndex];
        ChatMessageModel updatedMessage = message;
        // Preserve replyToMessage from local message
        if (localMsg.replyToMessage != null && message.replyToMessage == null) {
          updatedMessage = message.copyWith(
            replyToMessage: localMsg.replyToMessage,
          );
        }
        messages[localIndex] = updatedMessage;
        if (kDebugMode) {
          debugPrint(
            '🔄 [OpenedChatsCache] Replaced local: ${localMsg.id.substring(0, 8)}... → ${message.id.substring(0, 8)}...',
          );
        }
      } else {
        // Add new message at the end (messages are in ascending order)
        messages.add(message);
        if (kDebugMode) {
          debugPrint(
            '➕ [OpenedChatsCache] Added: ${message.id.substring(0, 8)}...',
          );
        }
      }
    }

    // Refresh timestamp
    _cacheTimestamps[otherUserId] = DateTime.now();
    _updateAccessOrder(otherUserId);
    _enforceMaxMessagesForChat(otherUserId);
  }

  // =========================================================================
  // ✅ UPDATE STATUS - Update message ticks (sent/delivered/read)
  // =========================================================================

  /// Update message status in cache (WhatsApp-style tick updates)
  /// Prevents status regression (read → delivered is invalid)
  void updateMessageStatus({
    required String otherUserId,
    required String messageId,
    required String newStatus,
    DateTime? deliveredAt,
    DateTime? readAt,
  }) {
    if (!_messagesCache.containsKey(otherUserId)) {
      return;
    }

    final messages = _messagesCache[otherUserId]!;
    final index = messages.indexWhere((m) => m.id == messageId);

    if (index == -1) {
      return;
    }

    final oldMessage = messages[index];

    // Prevent status regression (read → delivered is invalid)
    if (!_shouldUpdateStatus(oldMessage.messageStatus, newStatus)) {
      if (kDebugMode) {
        debugPrint(
          '⚠️ [OpenedChatsCache] Status regression: ${oldMessage.messageStatus} → $newStatus',
        );
      }
      return;
    }

    final updatedMessage = oldMessage.copyWith(
      messageStatus: newStatus,
      isRead: newStatus == 'read',
      deliveredAt: deliveredAt ?? oldMessage.deliveredAt,
      readAt: readAt ?? oldMessage.readAt,
      updatedAt: DateTime.now(),
    );

    messages[index] = updatedMessage;
    if (kDebugMode) {
      debugPrint(
        '✓✓ [OpenedChatsCache] Status: ${messageId.substring(0, 8)}... → $newStatus',
      );
    }
  }

  // =========================================================================
  // 🔄 REPLACE MESSAGE ID - Replace local ID with server ID
  // =========================================================================

  /// Replace local message ID with server ID (after server confirmation)
  /// Called when optimistic message gets confirmed by server
  /// IMPORTANT: Preserves imageWidth/imageHeight from optimistic message
  /// if server message lacks these dimensions (common with some backends)
  void replaceMessageId({
    required String otherUserId,
    required String localId,
    required ChatMessageModel serverMessage,
  }) {
    if (!_messagesCache.containsKey(otherUserId)) {
      return;
    }

    final messages = _messagesCache[otherUserId]!;
    final index = messages.indexWhere((m) => m.id == localId);

    if (index != -1) {
      final optimistic = messages[index];

      final preserveLocalStatus = !_shouldUpdateStatus(
        optimistic.messageStatus,
        serverMessage.messageStatus,
      );

      final serverWithStatus = preserveLocalStatus
          ? serverMessage.copyWith(
              messageStatus: optimistic.messageStatus,
              isRead: optimistic.isRead,
              deliveredAt: optimistic.deliveredAt ?? serverMessage.deliveredAt,
              readAt: optimistic.readAt ?? serverMessage.readAt,
            )
          : serverMessage.copyWith(
              deliveredAt: serverMessage.deliveredAt ?? optimistic.deliveredAt,
              readAt: serverMessage.readAt ?? optimistic.readAt,
              isRead: serverMessage.isRead || optimistic.isRead,
            );

      // Preserve dimensions from optimistic message if server lacks them
      ChatMessageModel finalMessage = serverWithStatus;
      if (serverMessage.isImageMessage) {
        final serverHasDimensions =
            serverMessage.imageWidth != null &&
            serverMessage.imageHeight != null &&
            serverMessage.imageWidth! > 0 &&
            serverMessage.imageHeight! > 0;

        final optimisticHasDimensions =
            optimistic.imageWidth != null &&
            optimistic.imageHeight != null &&
            optimistic.imageWidth! > 0 &&
            optimistic.imageHeight! > 0;

        if (!serverHasDimensions && optimisticHasDimensions) {
          finalMessage = serverWithStatus.copyWith(
            localImagePath: optimistic.localImagePath,
            imageWidth: optimistic.imageWidth,
            imageHeight: optimistic.imageHeight,
          );
          if (kDebugMode) {
            debugPrint(
              '📐 [OpenedChatsCache] Preserved dimensions: ${optimistic.imageWidth}x${optimistic.imageHeight}',
            );
          }
        } else if (optimistic.localImagePath != null &&
            optimistic.localImagePath!.isNotEmpty) {
          // Still preserve localImagePath for smooth transition
          finalMessage = serverWithStatus.copyWith(
            localImagePath: optimistic.localImagePath,
          );
        }
      }

      // Preserve thumbnailUrl for video messages
      // Server message has S3 key, optimistic has local path - prefer server if available
      if (serverMessage.messageType == MessageType.video) {
        final serverThumbnail = serverMessage.thumbnailUrl;
        final optimisticThumbnail = optimistic.thumbnailUrl;

        // Use server thumbnail if available, otherwise keep optimistic (local path)
        final finalThumbnail =
            (serverThumbnail != null && serverThumbnail.isNotEmpty)
            ? serverThumbnail
            : optimisticThumbnail;

        if (finalThumbnail != null &&
            finalThumbnail != finalMessage.thumbnailUrl) {
          finalMessage = finalMessage.copyWith(thumbnailUrl: finalThumbnail);
          if (kDebugMode) {
            debugPrint(
              '🖼️ [OpenedChatsCache] Preserved thumbnailUrl: $finalThumbnail',
            );
          }
        }

        // Also preserve localImagePath for video files
        if (optimistic.localImagePath != null &&
            optimistic.localImagePath!.isNotEmpty &&
            (finalMessage.localImagePath == null ||
                finalMessage.localImagePath!.isEmpty)) {
          finalMessage = finalMessage.copyWith(
            localImagePath: optimistic.localImagePath,
          );
        }
      }

      // Preserve replyToMessage from optimistic message
      // Server only returns replyToMessageId, not the full message object
      if (optimistic.replyToMessage != null &&
          finalMessage.replyToMessage == null) {
        finalMessage = finalMessage.copyWith(
          replyToMessage: optimistic.replyToMessage,
        );
        if (kDebugMode) {
          debugPrint(
            '↩️ [OpenedChatsCache] Preserved replyToMessage: ${optimistic.replyToMessage!.id.substring(0, 8)}...',
          );
        }
      }

      messages[index] = finalMessage;
      if (kDebugMode) {
        debugPrint(
          '🔄 [OpenedChatsCache] ID: ${localId.substring(0, 8)}... → ${serverMessage.id.substring(0, 8)}...',
        );
      }
    }
  }

  // =========================================================================
  // 🗑️ DELETE OPERATIONS - Handle message deletion scenarios
  // =========================================================================

  /// Remove message from cache (delete-for-me scenario)
  /// Message disappears from this user's view only
  void removeMessage({required String otherUserId, required String messageId}) {
    if (!_messagesCache.containsKey(otherUserId)) {
      return;
    }

    final messages = _messagesCache[otherUserId]!;
    final beforeCount = messages.length;
    messages.removeWhere((m) => m.id == messageId);
    final afterCount = messages.length;

    if (beforeCount != afterCount) {
      _cacheTimestamps[otherUserId] = DateTime.now();
      if (kDebugMode) {
        debugPrint(
          '🗑️ [OpenedChatsCache] Removed: ${messageId.substring(0, 8)}...',
        );
      }
    }
  }

  /// Mark message as deleted in cache (delete-for-everyone scenario)
  /// Message shows "This message was deleted" for all users
  void markMessageAsDeleted({
    required String otherUserId,
    required String messageId,
    DateTime? deletedAt,
  }) {
    if (!_messagesCache.containsKey(otherUserId)) {
      return;
    }

    final messages = _messagesCache[otherUserId]!;
    final index = messages.indexWhere((m) => m.id == messageId);

    if (index == -1) {
      return;
    }

    final oldMessage = messages[index];
    final updatedMessage = oldMessage.copyWith(
      messageType: MessageType.deleted,
      message: '',
      updatedAt: deletedAt ?? DateTime.now(),
    );

    messages[index] = updatedMessage;
    _cacheTimestamps[otherUserId] = DateTime.now();

    if (kDebugMode) {
      debugPrint(
        '🗑️ [OpenedChatsCache] Deleted: ${messageId.substring(0, 8)}...',
      );
    }
  }

  // =========================================================================
  // CACHE INVALIDATION
  // =========================================================================

  // =========================================================================
  // 🧹 CACHE MANAGEMENT - Cleanup and invalidation
  // =========================================================================

  /// Invalidate specific conversation cache (force reload from DB)
  void invalidate(String otherUserId) {
    _removeFromCache(otherUserId);
    if (_verboseLogs && kDebugMode) {
      debugPrint('🗑️ [OpenedChatsCache] Invalidated: $otherUserId');
    }
  }

  /// Clear all caches (called on logout for security)
  void clear() {
    _messagesCache.clear();
    _cacheTimestamps.clear();
    _accessOrder.clear();
    if (_verboseLogs && kDebugMode) {
      debugPrint('🗑️ [OpenedChatsCache] All caches cleared');
    }
  }

  void handleMemoryPressure({bool aggressive = false}) {
    _removeExpiredEntries();
    if (_messagesCache.isEmpty) return;

    if (aggressive) {
      for (final entry in _messagesCache.entries) {
        final list = entry.value;
        final newLimit = (_maxMessagesPerChat / 2).floor();
        if (newLimit > 0 && list.length > newLimit) {
          _messagesCache[entry.key] = list.sublist(list.length - newLimit);
          _cacheTimestamps[entry.key] = DateTime.now();
        }
      }

      final keepChats = (_maxCachedChats / 2).floor().clamp(1, _maxCachedChats);
      while (_messagesCache.length > keepChats && _accessOrder.isNotEmpty) {
        final leastRecentUserId = _accessOrder.first;
        _removeFromCache(leastRecentUserId);
      }
    } else {
      _applyLimits();
    }
  }

  /// Refresh cache timestamp (extend TTL when user accesses chat)
  void touch(String otherUserId) {
    if (_messagesCache.containsKey(otherUserId)) {
      _cacheTimestamps[otherUserId] = DateTime.now();
      _updateAccessOrder(otherUserId);
    }
  }

  // =========================================================================
  // INTERNAL HELPERS
  // =========================================================================

  void _removeFromCache(String otherUserId) {
    _messagesCache.remove(otherUserId);
    _cacheTimestamps.remove(otherUserId);
    _accessOrder.remove(otherUserId);
  }

  void _updateAccessOrder(String otherUserId) {
    _accessOrder.remove(otherUserId);
    _accessOrder.add(otherUserId); // Most recent at end
  }

  void _enforceLRULimit() {
    if (_messagesCache.length > _maxCachedChats && _accessOrder.isNotEmpty) {
      final leastRecentUserId = _accessOrder.first;
      _removeFromCache(leastRecentUserId);
      if (_verboseLogs && kDebugMode) {
        debugPrint(' [OpenedChatsCache] LRU evicted: $leastRecentUserId');
      }
    }
  }

  List<ChatMessageModel> _trimToMaxMessages(List<ChatMessageModel> messages) {
    if (_maxMessagesPerChat <= 0) return messages;
    if (messages.length <= _maxMessagesPerChat) return messages;
    return messages.sublist(messages.length - _maxMessagesPerChat);
  }

  void _enforceMaxMessagesForChat(String otherUserId) {
    if (_maxMessagesPerChat <= 0) return;
    final messages = _messagesCache[otherUserId];
    if (messages == null) return;
    if (messages.length <= _maxMessagesPerChat) return;
    final start = messages.length - _maxMessagesPerChat;
    _messagesCache[otherUserId] = messages.sublist(start);
    _cacheTimestamps[otherUserId] = DateTime.now();
  }

  void _removeExpiredEntries() {
    final now = DateTime.now();
    final keys = _cacheTimestamps.keys.toList();
    for (final otherUserId in keys) {
      final cacheTime = _cacheTimestamps[otherUserId];
      if (cacheTime == null) continue;
      if (now.difference(cacheTime) > _cacheTTL) {
        _removeFromCache(otherUserId);
      }
    }
  }

  void _applyLimits() {
    _removeExpiredEntries();
    for (final otherUserId in _messagesCache.keys.toList()) {
      _enforceMaxMessagesForChat(otherUserId);
    }
    while (_messagesCache.length > _maxCachedChats && _accessOrder.isNotEmpty) {
      final leastRecentUserId = _accessOrder.first;
      _removeFromCache(leastRecentUserId);
    }
  }

  // =========================================================================
  // 🛡️ HELPER METHODS - Internal cache management
  // =========================================================================

  /// Prevent status regression (read → delivered is invalid)
  /// WhatsApp rule: Status can only move forward, never backward
  bool _shouldUpdateStatus(String currentStatus, String newStatus) {
    const statusPriority = {
      'sending': 0,
      'pending_sync': 0,
      'sent': 1,
      'delivered': 2,
      'read': 3,
    };

    final currentPriority = statusPriority[currentStatus] ?? 0;
    final newPriority = statusPriority[newStatus] ?? 0;

    return newPriority >= currentPriority;
  }
}
