// ============================================================================
// CHAT CACHE MANAGER - WhatsApp-Style Unified Cache Coordinator
// ============================================================================
//
// 🎯 PURPOSE:
// Single point of control for all chat-related caches.
// Coordinates operations between OpenedChatsCache and ChatListCache.
//
// 📱 WHATSAPP-LIKE BEHAVIOR:
// • Message arrives → Update both opened chat + chat list caches
// • Status update → Sync ticks across all caches
// • Delete message → Handle deletion in both caches appropriately
// • Open conversation → Touch opened cache for LRU management
// • Logout → Clear all caches for security
// • Memory pressure → Coordinate cleanup across caches
//
// ⚙️ COORDINATION FEATURES:
// • Unified Operations: Single method calls update multiple caches
// • Cache Synchronization: Keeps OpenedChats + ChatList in sync
// • Lifecycle Management: Handles conversation open/close/delete
// • Memory Management: Coordinates memory pressure handling
// • Statistics: Combined cache stats for debugging
// • Configuration: Unified cache configuration
//
// 🔄 MANAGER OPERATIONS:
// • addMessage() - Add message to both caches
// • updateMessageStatus() - Update ticks in both caches
// • markMessageAsDeleted() - Handle delete-for-everyone
// • removeMessage() - Handle delete-for-me
// • replaceMessageId() - Replace local ID with server ID
// • onConversationOpened() - Handle conversation lifecycle
// • clearAll() - Clear all caches on logout
// • preload() - Coordinate cache preloading
//
// ============================================================================

import 'package:flutter/foundation.dart';
import 'opened_chats_cache.dart';
import 'chat_list_cache.dart';
import '../../models/chat_message_model.dart';

/// Unified manager for all chat-related caches
///
/// Provides centralized control for cache operations like:
/// - Clearing all caches on logout
/// - Getting combined cache statistics
/// - Coordinating cache invalidation
class ChatCacheManager {
  // Singleton
  static ChatCacheManager? _instance;
  static ChatCacheManager get instance {
    _instance ??= ChatCacheManager._();
    return _instance!;
  }

  ChatCacheManager._();

  // Cache instances
  final OpenedChatsCache _openedChatsCache = OpenedChatsCache.instance;
  final ChatListCache _chatListCache = ChatListCache.instance;

  // =========================================================================
  // CACHE ACCESS
  // =========================================================================

  // =========================================================================
  // 📋 CACHE ACCESS - Direct access to individual caches
  // =========================================================================

  /// Get opened chats cache instance (for advanced operations)
  OpenedChatsCache get openedChats => _openedChatsCache;

  /// Get chat list cache instance (for advanced operations)
  ChatListCache get chatList => _chatListCache;

  // =========================================================================
  // UNIFIED OPERATIONS
  // =========================================================================

  // =========================================================================
  // 🧹 UNIFIED OPERATIONS - Coordinate operations across all caches
  // =========================================================================

  /// Clear all caches (called on logout for security)
  /// Ensures no sensitive data remains in memory
  void clearAll() {
    _openedChatsCache.clear();
    _chatListCache.clear();
    if (kDebugMode) {
      debugPrint('🗑️ [ChatCacheManager] All caches cleared');
    }
  }

  void configure({
    int? maxCachedChats,
    Duration? openedChatCacheTTL,
    int? maxMessagesPerChat,
    Duration? chatListCacheDuration,
    int? maxChatListContacts,
  }) {
    _openedChatsCache.configure(
      maxCachedChats: maxCachedChats,
      cacheTTL: openedChatCacheTTL,
      maxMessagesPerChat: maxMessagesPerChat,
    );

    _chatListCache.configure(
      cacheDuration: chatListCacheDuration,
      maxContacts: maxChatListContacts,
    );
  }

  void handleMemoryPressure({bool aggressive = false}) {
    _openedChatsCache.handleMemoryPressure(aggressive: aggressive);
    _chatListCache.handleMemoryPressure(aggressive: aggressive);
    if (kDebugMode && aggressive) {
      debugPrint('⚠️ [ChatCacheManager] Aggressive memory cleanup');
    }
  }

  /// Get combined cache statistics for debugging and monitoring
  /// Provides unified view of all cache performance metrics
  Map<String, dynamic> get stats => {
    'openedChats': _openedChatsCache.stats,
    'chatList': _chatListCache.stats,
  };

  /// Print detailed cache statistics to debug console
  /// Useful for performance debugging and cache analysis
  void printStats() {
    debugPrint('');
    debugPrint('📊 ═══════════════════════════════════════════════════════');
    debugPrint('📊 CACHE STATISTICS');
    debugPrint('📊 ═══════════════════════════════════════════════════════');
    debugPrint('📊 Opened Chats: ${_openedChatsCache.stats}');
    debugPrint('📊 Chat List: ${_chatListCache.stats}');
    debugPrint('📊 ═══════════════════════════════════════════════════════');
    debugPrint('');
  }

  // =========================================================================
  // CONVERSATION LIFECYCLE
  // =========================================================================

  // =========================================================================
  // 👁️ CONVERSATION LIFECYCLE - Handle chat open/close/delete events
  // =========================================================================

  /// Called when user opens a conversation (WhatsApp-style)
  /// Updates LRU access patterns for optimal cache performance
  void onConversationOpened(String otherUserId) {
    // Touch opened chats cache (update LRU order)
    _openedChatsCache.touch(otherUserId);
  }

  /// Called when user closes a conversation (WhatsApp-style)
  /// Cache intentionally preserved for instant re-open experience
  void onConversationClosed(String otherUserId) {
    // Cache intentionally stays in memory for quick re-access
    // WhatsApp-style: keep recently viewed chats cached
  }

  /// Called when conversation is deleted (WhatsApp-style)
  /// Removes all traces from both caches for cleanup
  void onConversationDeleted(String otherUserId) {
    _openedChatsCache.invalidate(otherUserId);
    _chatListCache.removeContact(otherUserId);
    if (kDebugMode) {
      debugPrint('🗑️ [ChatCacheManager] Conversation deleted');
    }
  }

  // =========================================================================
  // MESSAGE UPDATES (Propagate to all relevant caches)
  // =========================================================================

  // =========================================================================
  // 📨 MESSAGE OPERATIONS - Coordinate message updates across caches
  // =========================================================================

  /// Add new message to all relevant caches (WhatsApp-style)
  /// Updates both opened chat (if cached) and chat list simultaneously
  void addMessage({
    required String otherUserId,
    required ChatMessageModel message,
    int unreadDelta = 0,
  }) {
    // Add to opened chats cache (if conversation is cached)
    _openedChatsCache.addMessage(otherUserId, message);

    // Bump in chat list cache
    _chatListCache.bumpWithMessage(
      otherUserId: otherUserId,
      message: message,
      unreadDelta: unreadDelta,
    );
  }

  /// Update message status across all caches (WhatsApp-style ticks)
  /// Ensures consistent tick display in both chat view and chat list
  void updateMessageStatus({
    required String otherUserId,
    required String messageId,
    required String newStatus,
    DateTime? deliveredAt,
    DateTime? readAt,
  }) {
    // Update opened chats cache
    _openedChatsCache.updateMessageStatus(
      otherUserId: otherUserId,
      messageId: messageId,
      newStatus: newStatus,
      deliveredAt: deliveredAt,
      readAt: readAt,
    );

    // Update chat list cache (if this is the last message)
    _chatListCache.updateMessageStatus(
      otherUserId: otherUserId,
      messageId: messageId,
      newStatus: newStatus,
    );
  }

  /// Mark message as deleted across all caches (delete-for-everyone)
  /// Shows "This message was deleted" in both chat and chat list
  void markMessageAsDeleted({
    required String otherUserId,
    required String messageId,
    DateTime? deletedAt,
  }) {
    // Mark as deleted in opened chats cache
    _openedChatsCache.markMessageAsDeleted(
      otherUserId: otherUserId,
      messageId: messageId,
      deletedAt: deletedAt,
    );

    // Mark as deleted in chat list cache (if this is the last message)
    _chatListCache.markLastMessageAsDeleted(
      otherUserId: otherUserId,
      messageId: messageId,
      deletedAt: deletedAt,
    );
  }

  /// Remove message from caches (delete-for-me scenario)
  /// Only removes from opened chat, preserves chat list with previous message
  void removeMessage({required String otherUserId, required String messageId}) {
    // Remove from opened chats cache
    _openedChatsCache.removeMessage(
      otherUserId: otherUserId,
      messageId: messageId,
    );

    // Note: For delete-for-me, we don't remove from chat list
    // The conversation should remain visible with previous message
  }

  /// Replace local message ID with server ID across all caches
  /// Called when optimistic message gets confirmed by server
  void replaceMessageId({
    required String otherUserId,
    required String localId,
    required ChatMessageModel serverMessage,
  }) {
    // Replace in opened chats cache
    _openedChatsCache.replaceMessageId(
      otherUserId: otherUserId,
      localId: localId,
      serverMessage: serverMessage,
    );

    // Update in chat list cache (if this is the last message)
    _chatListCache.bumpWithMessage(
      otherUserId: otherUserId,
      message: serverMessage,
      unreadDelta: 0,
    );
  }

  // =========================================================================
  // PRELOAD
  // =========================================================================

  // =========================================================================
  // 🚀 PRELOAD - Coordinate cache loading during app startup
  // =========================================================================

  /// Preload caches during app startup (WhatsApp-style)
  /// Ensures instant chat list display when app opens
  Future<void> preload() async {
    debugPrint('🚀 [ChatCacheManager] Preloading caches...');
    final startTime = DateTime.now();

    // Preload chat list cache (most important for initial display)
    await _chatListCache.preload();

    debugPrint(
      '✅ [ChatCacheManager] Preload complete in '
      '${DateTime.now().difference(startTime).inMilliseconds}ms',
    );
  }
}
