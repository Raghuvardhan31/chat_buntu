// ============================================================================
// CHAT LIST CACHE - WhatsApp-Style Contact List Memory Storage
// ============================================================================
//
// 🎯 PURPOSE:
// Instant chat list display without DB queries on every app open.
// Provides immediate WhatsApp-like chat list experience.
//
// 📱 WHATSAPP-LIKE BEHAVIOR:
// • App startup → Preload from DB during splash screen
// • Chat list opens → Instant display from memory (0ms)
// • New message → Bump conversation to top immediately
// • Status updates → Update last message ticks in real-time
// • Delete message → Update preview or show "You deleted this message"
// • Background sync → Keep cache fresh with server data
//
// ⚙️ CACHE FEATURES:
// • Memory Storage: 500 contacts max (prevents memory bloat)
// • TTL Management: 5-minute cache validity
// • Real-time Updates: Message bumping, status updates, activity tracking
// • Sorting Logic: Most recent interaction first (like WhatsApp)
// • Delete Handling: Proper "deleted message" preview display
// • Server Sync: Background refresh with TTL-based freshness
//
// 🔄 CACHE OPERATIONS:
// • preload() - Load contacts from DB during app startup
// • bumpWithMessage() - Move conversation to top with new message
// • updateMessageStatus() - Update last message ticks
// • applyLastActivity() - Handle delete/reaction activities
// • applyUnreadCounts() - Update badge counts
// • markLastMessageAsDeleted() - Handle message deletion
// • updateContact() - Real-time contact updates
// • clear() - Clear cache on logout
//
// ============================================================================

import 'package:flutter/foundation.dart';
import '../../models/chat_message_model.dart';
import '../datasources/chat_local_datasource.dart';

/// WhatsApp-style memory cache for chat list
///
/// Provides instant chat list display without DB query on every page open
class ChatListCache {
  // Singleton
  static ChatListCache? _instance;
  static ChatListCache get instance {
    _instance ??= ChatListCache._();
    return _instance!;
  }

  ChatListCache._();

  // In-memory cache
  List<ChatContactModel>? _cachedContacts;
  DateTime? _cacheTime;
  DateTime? _lastServerSyncTime;
  Future<void>? _preloadFuture;

  // Cache validity duration (5 minutes in memory)
  Duration _cacheDuration = const Duration(minutes: 5);
  int _maxContacts = 500;

  void configure({Duration? cacheDuration, int? maxContacts}) {
    if (cacheDuration != null && cacheDuration.inSeconds > 0) {
      _cacheDuration = cacheDuration;
    }
    if (maxContacts != null && maxContacts > 0) {
      _maxContacts = maxContacts;
    }
    _enforceMaxContacts();
  }

  void replaceLastMessage({
    required String otherUserId,
    required String localMessageId,
    required ChatMessageModel serverMessage,
  }) {
    if (_cachedContacts == null) return;
    if (otherUserId.isEmpty) return;
    if (localMessageId.isEmpty) return;

    final index = _cachedContacts!.indexWhere((c) => c.user.id == otherUserId);
    if (index == -1) return;

    final contact = _cachedContacts![index];
    final last = contact.lastMessage;
    if (last == null) return;
    if (last.id != localMessageId) return;

    final normalizedLocalStatus = ChatMessageModel.normalizeMessageStatus(
      last.messageStatus,
      isRead: last.isRead,
    );
    final normalizedServerStatus = ChatMessageModel.normalizeMessageStatus(
      serverMessage.messageStatus,
      isRead: serverMessage.isRead,
    );

    final preserveLocalStatus =
        ChatMessageModel.messageStatusPriority(
          normalizedLocalStatus,
          isRead: last.isRead,
        ) >
        ChatMessageModel.messageStatusPriority(
          normalizedServerStatus,
          isRead: serverMessage.isRead,
        );

    final normalizedServerMessage = serverMessage.copyWith(
      messageStatus: normalizedServerStatus,
      isRead: serverMessage.isRead || normalizedServerStatus == 'read',
    );

    final mergedServerMessage = preserveLocalStatus
        ? normalizedServerMessage.copyWith(
            messageStatus: normalizedLocalStatus,
            isRead: last.isRead,
            deliveredAt: last.deliveredAt ?? serverMessage.deliveredAt,
            readAt: last.readAt ?? serverMessage.readAt,
          )
        : normalizedServerMessage.copyWith(
            deliveredAt:
                normalizedServerMessage.deliveredAt ?? last.deliveredAt,
            readAt: normalizedServerMessage.readAt ?? last.readAt,
            isRead: normalizedServerMessage.isRead || last.isRead,
          );

    _cachedContacts![index] = contact.copyWith(
      lastMessage: mergedServerMessage,
    );
    touch();
    _sortByLastMessageTime();
    _enforceMaxContacts();
  }

  // =========================================================================
  // CACHE ACCESS
  // =========================================================================

  // =========================================================================
  // 📋 GET CONTACTS - Retrieve cached chat list for instant display
  // =========================================================================

  /// Get cached contacts (WhatsApp-style instant chat list)
  /// Returns null if cache is stale/empty - caller should preload from DB
  List<ChatContactModel>? get contacts {
    if (_cachedContacts != null && _cacheTime != null) {
      final age = DateTime.now().difference(_cacheTime!);
      if (age < _cacheDuration) {
        if (kDebugMode) {
          debugPrint(
            '⚡ [ChatListCache] HIT: ${_cachedContacts!.length} contacts from memory',
          );
        }
        return _cachedContacts;
      }
      if (kDebugMode) {
        debugPrint('⏰ [ChatListCache] STALE: cache is ${age.inSeconds}s old');
      }
    }
    return null;
  }

  /// Quick check: Is chat list cache ready for instant display?
  bool get hasValidCache => contacts != null;

  bool isServerSyncFresh({Duration? ttl}) {
    final t = ttl ?? _cacheDuration;
    final last = _lastServerSyncTime;
    if (last == null) return false;
    return DateTime.now().difference(last) < t;
  }

  /// Get cache statistics for debugging and performance monitoring
  Map<String, dynamic> get stats => {
    'contactCount': _cachedContacts?.length ?? 0,
    'maxContacts': _maxContacts,
    'cacheDurationSeconds': _cacheDuration.inSeconds,
    'cacheAge': _cacheTime != null
        ? DateTime.now().difference(_cacheTime!).inSeconds
        : null,
    'isValid': hasValidCache,
  };

  // =========================================================================
  // CACHE UPDATES
  // =========================================================================

  // =========================================================================
  // 💾 CACHE CONTACTS - Store chat list in memory for instant access
  // =========================================================================

  /// Cache contacts in memory (called after DB load or server sync)
  /// Preserves existing lastActivity for proper delete message handling
  void cache(List<ChatContactModel> contacts) {
    final existing = _cachedContacts;
    if (existing == null || existing.isEmpty) {
      _cachedContacts = List.from(contacts);
    } else {
      final byId = <String, ChatContactModel>{
        for (final c in existing) c.user.id: c,
      };

      _cachedContacts = contacts.map((c) {
        if (c.lastActivity != null) return c;
        final prev = byId[c.user.id];
        final activity = prev?.lastActivity;
        if (activity == null) return c;

        final normalizedType = (activity.type ?? '')
            .toLowerCase()
            .trim()
            .replaceAll('-', '_');
        if (normalizedType != 'message_deleted') return c;

        final lastTime = c.lastMessage?.createdAt ?? DateTime(1970);
        if (!activity.timestamp.isAfter(lastTime)) return c;

        return c.copyWith(lastActivity: activity);
      }).toList();
    }
    _cacheTime = DateTime.now();
    _sortByLastMessageTime();
    _enforceMaxContacts();
    if (kDebugMode) {
      debugPrint('💾 [ChatListCache] CACHED: ${contacts.length} contacts');
    }
  }

  void cacheFromServer(List<ChatContactModel> contacts) {
    cache(contacts);
    _lastServerSyncTime = _cacheTime;
  }

  // =========================================================================
  // 🔔 UNREAD COUNTS - Update chat list badge counts
  // =========================================================================

  /// Apply unread counts to cached contacts (real-time badge updates)
  void applyUnreadCounts(Map<String, int> unreadByUserId) {
    if (_cachedContacts == null) return;
    if (unreadByUserId.isEmpty) return;

    bool changed = false;
    int updatedCount = 0;
    for (int i = 0; i < _cachedContacts!.length; i++) {
      final c = _cachedContacts![i];
      final count = unreadByUserId[c.user.id];
      if (count == null) continue;
      if (c.unreadCount == count) continue;
      _cachedContacts![i] = c.copyWith(unreadCount: count);
      changed = true;
      updatedCount++;
    }

    if (changed) {
      touch();
      if (kDebugMode) {
        debugPrint('🔔 [ChatListCache] Unread: $updatedCount contacts updated');
      }
    }
  }

  // =========================================================================
  // 📌 LAST ACTIVITY - Handle delete/reaction activities
  // =========================================================================

  /// Apply last activity (message deleted, reaction, etc.)
  /// Updates chat list preview and sorting
  void applyLastActivity({
    required String otherUserId,
    required ChatLastActivityModel activity,
  }) {
    final contacts = _cachedContacts;
    if (contacts == null) return;
    if (otherUserId.isEmpty) return;

    final index = contacts.indexWhere((c) => c.user.id == otherUserId);
    if (index == -1) return;

    contacts[index] = contacts[index].copyWith(lastActivity: activity);
    touch();
    _sortByLastMessageTime();
    _enforceMaxContacts();

    if (kDebugMode) {
      debugPrint('📌 [ChatListCache] Activity: ${activity.type}');
    }
  }

  // =========================================================================
  // 📨 BUMP MESSAGE - Move conversation to top (WhatsApp-style)
  // =========================================================================

  /// Bump conversation to top with new message (WhatsApp-style behavior)
  /// Creates new contact if not in cache, updates existing contact
  void bumpWithMessage({
    required String otherUserId,
    required ChatMessageModel message,
    int unreadDelta = 0,
  }) {
    if (_cachedContacts == null) return;
    if (otherUserId.isEmpty) return;

    final index = _cachedContacts!.indexWhere((c) => c.user.id == otherUserId);

    if (index != -1) {
      final existing = _cachedContacts![index];
      final nextUnread = (existing.unreadCount + unreadDelta).clamp(0, 1 << 30);
      final activity = existing.lastActivity;
      final normalizedType = (activity?.type ?? '')
          .toLowerCase()
          .trim()
          .replaceAll('-', '_');
      final shouldClearDeletedActivity =
          activity != null &&
          normalizedType == 'message_deleted' &&
          message.createdAt.isAfter(activity.timestamp);

      _cachedContacts![index] = existing.copyWith(
        lastMessage: message,
        lastActivity: shouldClearDeletedActivity ? null : existing.lastActivity,
        unreadCount: nextUnread,
      );
      if (kDebugMode) {
        debugPrint(
          '📨 [ChatListCache] Bump: ${message.id.substring(0, 8)}... ${message.messageStatus}',
        );
      }
    } else {
      // Contact not in cache yet - add placeholder
      final newContact = ChatContactModel(
        user: ChatUserModel(
          id: otherUserId,
          firstName: '',
          lastName: '',
          mobileNo: '',
          chatPictureUrl: null,
        ),
        lastMessage: message,
        unreadCount: unreadDelta > 0 ? unreadDelta : 0,
      );
      _cachedContacts!.insert(0, newContact);
      if (kDebugMode) {
        debugPrint('📨 [ChatListCache] New contact added');
      }
    }

    touch();
    _sortByLastMessageTime();
    _enforceMaxContacts();
  }

  // =========================================================================
  // 🔄 UPDATE CONTACT - Real-time contact updates
  // =========================================================================

  /// Update single contact in cache (real-time profile/message updates)
  /// Handles complex lastActivity preservation logic
  void updateContact(ChatContactModel updatedContact) {
    if (_cachedContacts == null) return;

    final index = _cachedContacts!.indexWhere(
      (c) => c.user.id == updatedContact.user.id,
    );
    if (index != -1) {
      final previous = _cachedContacts![index];
      final existingUnread = previous.unreadCount;

      ChatLastActivityModel? nextActivity = updatedContact.lastActivity;

      if (nextActivity == null && previous.lastActivity != null) {
        final prevActivity = previous.lastActivity!;
        final normalizedType = (prevActivity.type ?? '')
            .toLowerCase()
            .trim()
            .replaceAll('-', '_');
        if (normalizedType == 'message_deleted') {
          final lastTime =
              updatedContact.lastMessage?.createdAt ?? DateTime(1970);
          if (prevActivity.timestamp.isAfter(lastTime)) {
            nextActivity = prevActivity;
          }
        }
      }

      if (nextActivity != null) {
        final normalizedType = (nextActivity.type ?? '')
            .toLowerCase()
            .trim()
            .replaceAll('-', '_');
        if (normalizedType == 'message_deleted') {
          final lastTime =
              updatedContact.lastMessage?.createdAt ?? DateTime(1970);
          if (lastTime.isAfter(nextActivity.timestamp)) {
            nextActivity = null;
          }
        }
      }

      _cachedContacts![index] = updatedContact.copyWith(
        unreadCount: updatedContact.unreadCount != 0
            ? updatedContact.unreadCount
            : existingUnread,
        lastActivity: nextActivity,
      );
      if (kDebugMode) {
        debugPrint(
          '🔄 [ChatListCache] Updated contact: ${updatedContact.user.firstName}',
        );
      }
    } else {
      // New contact - add to top
      _cachedContacts!.insert(0, updatedContact);
      if (kDebugMode) {
        debugPrint(
          '➕ [ChatListCache] Added new contact: ${updatedContact.user.firstName}',
        );
      }
    }

    // Sort by last message time (most recent first)
    _sortByLastMessageTime();
    _enforceMaxContacts();
  }

  // =========================================================================
  // ✅ UPDATE STATUS - Update last message ticks (sent/delivered/read)
  // =========================================================================

  /// Update last message status (WhatsApp-style tick updates)
  /// Only updates if messageId matches the actual last message
  void updateMessageStatus({
    required String otherUserId,
    required String messageId,
    required String newStatus,
  }) {
    if (_cachedContacts == null) return;

    final index = _cachedContacts!.indexWhere((c) => c.user.id == otherUserId);
    if (index == -1) return;

    final contact = _cachedContacts![index];
    final lastMessage = contact.lastMessage;

    if (lastMessage == null) return;

    final normalizedNewStatus = ChatMessageModel.normalizeMessageStatus(
      newStatus,
    );

    final matchesById = lastMessage.id == messageId;
    final isOptimistic =
        lastMessage.id.startsWith('local_') ||
        lastMessage.id.startsWith('temp_');
    final isOutgoing = lastMessage.senderId != otherUserId;
    final isRecent =
        DateTime.now().difference(lastMessage.createdAt) <
        const Duration(minutes: 5);

    if (!matchesById && !(isOptimistic && isOutgoing && isRecent)) {
      return;
    }

    final currentPriority = ChatMessageModel.messageStatusPriority(
      lastMessage.messageStatus,
      isRead: lastMessage.isRead,
    );
    final newPriority = ChatMessageModel.messageStatusPriority(
      normalizedNewStatus,
    );

    // Prevent status regression (read → delivered is invalid)
    if (newPriority < currentPriority) {
      if (kDebugMode) {
        debugPrint(
          '⚠️ [ChatListCache] Status regression: ${lastMessage.messageStatus} → $normalizedNewStatus',
        );
      }
      return;
    }

    // Create updated message with new status (preserve all fields)
    final updatedMessage = lastMessage.copyWith(
      messageStatus: normalizedNewStatus,
      isRead: normalizedNewStatus == 'read',
      deliveredAt:
          (normalizedNewStatus == 'delivered' || normalizedNewStatus == 'read')
          ? (lastMessage.deliveredAt ?? DateTime.now())
          : lastMessage.deliveredAt,
      readAt: normalizedNewStatus == 'read'
          ? (lastMessage.readAt ?? DateTime.now())
          : lastMessage.readAt,
      updatedAt: DateTime.now(),
    );

    final updatedContact = contact.copyWith(lastMessage: updatedMessage);

    _cachedContacts![index] = updatedContact;
    touch(); // Refresh cache timestamp
    if (kDebugMode) {
      debugPrint(
        '✓✓ [ChatListCache] Status: ${messageId.substring(0, 8)}... → $normalizedNewStatus',
      );
    }
  }

  // =========================================================================
  // 🗑️ DELETE OPERATIONS - Handle message deletion scenarios
  // =========================================================================

  /// Mark last message as deleted (delete-for-everyone scenario)
  /// Updates message to show "This message was deleted"
  void markLastMessageAsDeleted({
    required String otherUserId,
    required String messageId,
    DateTime? deletedAt,
  }) {
    if (_cachedContacts == null) return;

    final index = _cachedContacts!.indexWhere((c) => c.user.id == otherUserId);
    if (index == -1) return;

    final contact = _cachedContacts![index];
    final lastMessage = contact.lastMessage;

    if (lastMessage == null || lastMessage.id != messageId) return;

    final updatedMessage = lastMessage.copyWith(
      messageType: MessageType.deleted,
      message: '',
      updatedAt: deletedAt ?? DateTime.now(),
    );

    _cachedContacts![index] = contact.copyWith(lastMessage: updatedMessage);
    touch();
    _sortByLastMessageTime();

    if (kDebugMode) {
      debugPrint(
        '🗑️ [ChatListCache] Deleted: ${messageId.substring(0, 8)}...',
      );
    }
  }

  /// Remove contact from cache (conversation deleted)
  /// Called when entire conversation is deleted
  void removeContact(String otherUserId) {
    if (_cachedContacts == null) return;
    _cachedContacts!.removeWhere((c) => c.user.id == otherUserId);
    if (kDebugMode) {
      debugPrint('🗑️ [ChatListCache] Removed contact: $otherUserId');
    }
  }

  void handleMemoryPressure({bool aggressive = false}) {
    if (_cachedContacts == null) return;
    if (aggressive) {
      clear();
      return;
    }
    _enforceMaxContacts();
  }

  // =========================================================================
  // CACHE INVALIDATION
  // =========================================================================

  // =========================================================================
  // 🧹 CACHE MANAGEMENT - Cleanup and invalidation
  // =========================================================================

  /// Clear cache (called on logout for security)
  void clear() {
    _cachedContacts = null;
    _cacheTime = null;
    _lastServerSyncTime = null;
    if (kDebugMode) {
      debugPrint('🗑️ [ChatListCache] Cache cleared');
    }
  }

  /// Refresh cache timestamp (extend TTL when cache is accessed)
  void touch() {
    if (_cachedContacts != null) {
      _cacheTime = DateTime.now();
    }
  }

  // =========================================================================
  // PRELOAD
  // =========================================================================

  // =========================================================================
  // 🚀 PRELOAD - Load chat list during app startup
  // =========================================================================

  /// Preload chat list from DB during splash screen (WhatsApp-style)
  /// Ensures instant chat list display when user opens the app
  Future<void> preload() async {
    final inFlight = _preloadFuture;
    if (inFlight != null) {
      if (kDebugMode) {
        debugPrint('⏳ [ChatListCache] Preload already in progress');
      }
      return inFlight;
    }

    // Skip if cache is still valid
    if (hasValidCache) {
      if (kDebugMode) {
        debugPrint('✅ [ChatListCache] Cache still valid, skip preload');
      }
      return;
    }

    final startTime = DateTime.now();

    _preloadFuture = () async {
      try {
        if (kDebugMode) {
          debugPrint('🚀 [ChatListCache] PRELOADING from local DB...');
        }

        final localDataSource = ChatLocalDataSourceImpl();
        final contacts = await localDataSource.getChatContactsFromLocal();

        if (contacts.isNotEmpty) {
          cache(contacts);
          if (kDebugMode) {
            debugPrint(
              '⚡ [ChatListCache] PRELOADED ${contacts.length} contacts in '
              '${DateTime.now().difference(startTime).inMilliseconds}ms',
            );
          }
        } else {
          if (kDebugMode) {
            debugPrint('📭 [ChatListCache] No contacts to preload');
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('❌ [ChatListCache] Preload failed: $e');
        }
      } finally {
        _preloadFuture = null;
      }
    }();

    return _preloadFuture!;
  }

  // =========================================================================
  // INTERNAL HELPERS
  // =========================================================================

  void _sortByLastMessageTime() {
    if (_cachedContacts == null) return;
    _cachedContacts!.sort((a, b) {
      final aLast = a.lastMessage;
      final bLast = b.lastMessage;
      final aMsgTime = aLast == null
          ? DateTime(1970)
          : (aLast.messageType == MessageType.deleted
                ? aLast.updatedAt
                : aLast.createdAt);
      final bMsgTime = bLast == null
          ? DateTime(1970)
          : (bLast.messageType == MessageType.deleted
                ? bLast.updatedAt
                : bLast.createdAt);

      DateTime aTime = aMsgTime;
      final aAct = a.lastActivity;
      if (aAct != null) {
        final normalizedType = (aAct.type ?? '')
            .toLowerCase()
            .trim()
            .replaceAll('-', '_');
        if (normalizedType == 'message_deleted' &&
            aAct.timestamp.isAfter(aMsgTime)) {
          aTime = aAct.timestamp;
        }
      }

      DateTime bTime = bMsgTime;
      final bAct = b.lastActivity;
      if (bAct != null) {
        final normalizedType = (bAct.type ?? '')
            .toLowerCase()
            .trim()
            .replaceAll('-', '_');
        if (normalizedType == 'message_deleted' &&
            bAct.timestamp.isAfter(bMsgTime)) {
          bTime = bAct.timestamp;
        }
      }
      return bTime.compareTo(aTime); // Most recent first
    });
  }

  void _enforceMaxContacts() {
    final contacts = _cachedContacts;
    if (contacts == null) return;
    if (_maxContacts <= 0) return;
    if (contacts.length <= _maxContacts) return;
    _cachedContacts = contacts.sublist(0, _maxContacts);
  }
}
