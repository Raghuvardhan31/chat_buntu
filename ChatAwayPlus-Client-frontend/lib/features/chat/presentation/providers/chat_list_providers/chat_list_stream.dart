// lib/features/chat/presentation/providers/chat_list_providers/chat_list_stream.dart
//
// WHATSAPP-STYLE: Single Source of Truth for Chat List
//
// Industry-standard reactive architecture:
// 1. All chat list data flows through ONE stream
// 2. Any update (new message, status change) emits new state
// 3. All UI components subscribe to same stream
// 4. BehaviorSubject pattern: new subscribers get latest value immediately
//
// This eliminates race conditions and ensures UI consistency across pages

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../models/chat_message_model.dart';
import '../../../data/datasources/chat_local_datasource.dart';
import '../../../data/cache/chat_list_cache.dart';

/// WhatsApp-style reactive chat list manager
///
/// Uses BehaviorSubject pattern:
/// - Holds the latest chat list in memory
/// - Emits to all subscribers on any change
/// - New subscribers immediately get current state
class ChatListStream {
  // Singleton
  static ChatListStream? _instance;
  static ChatListStream get instance {
    _instance ??= ChatListStream._();
    return _instance!;
  }

  List<ChatContactModel> _preserveDeletedActivities(
    List<ChatContactModel> incoming,
  ) {
    if (_currentList.isEmpty) return incoming;

    final byId = <String, ChatContactModel>{
      for (final c in _currentList) c.user.id: c,
    };

    return incoming.map((c) {
      if (c.lastActivity != null) return c;
      final existing = byId[c.user.id];
      final activity = existing?.lastActivity;
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

  static const bool _verboseLogs = false;

  void applyLastActivity({
    required String otherUserId,
    required ChatLastActivityModel activity,
  }) {
    if (otherUserId.isEmpty) return;
    if (_currentList.isEmpty) return;

    final index = _currentList.indexWhere((c) => c.user.id == otherUserId);
    if (index == -1) return;

    final existing = _currentList[index];
    final updatedContact = existing.copyWith(lastActivity: activity);

    _currentList = List.from(_currentList);
    _currentList[index] = updatedContact;
    _sortByLastMessageTime();
    _emit();
  }

  void bumpWithMessage({
    required String otherUserId,
    required ChatMessageModel message,
    int unreadDelta = 0,
  }) {
    if (otherUserId.isEmpty) return;

    if (kDebugMode) {
      debugPrint(
        '📨 [ChatListStream] bumpWithMessage: otherUserId=$otherUserId msg=${message.id.substring(0, 8)}... status=${message.messageStatus}',
      );
    }

    final index = _currentList.indexWhere((c) => c.user.id == otherUserId);
    _currentList = List.from(_currentList);

    if (index != -1) {
      final existing = _currentList[index];
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
      _currentList[index] = existing.copyWith(
        lastMessage: message,
        lastActivity: shouldClearDeletedActivity ? null : existing.lastActivity,
        unreadCount: nextUnread,
      );
    } else {
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
      _currentList.insert(0, newContact);
    }

    _sortByLastMessageTime();
    _emit();
  }

  void applyUnreadCounts(Map<String, int> unreadByUserId) {
    if (unreadByUserId.isEmpty) return;
    if (_currentList.isEmpty) return;

    bool changed = false;
    final updated = _currentList.map((c) {
      final count = unreadByUserId[c.user.id];
      if (count == null) return c;
      if (c.unreadCount == count) return c;
      changed = true;
      return c.copyWith(unreadCount: count);
    }).toList();

    if (changed) {
      _currentList = updated;
      _emit();
    }
  }

  void replaceLastMessage({
    required String otherUserId,
    required String localMessageId,
    required ChatMessageModel serverMessage,
  }) {
    if (otherUserId.isEmpty) return;
    if (localMessageId.isEmpty) return;
    if (_currentList.isEmpty) return;

    final index = _currentList.indexWhere((c) => c.user.id == otherUserId);
    if (index == -1) return;

    final existing = _currentList[index];
    final last = existing.lastMessage;
    if (last == null) return;
    if (last.id != localMessageId) return;

    final localPriority = ChatMessageModel.messageStatusPriority(
      last.messageStatus,
      isRead: last.isRead,
    );
    final serverPriority = ChatMessageModel.messageStatusPriority(
      serverMessage.messageStatus,
      isRead: serverMessage.isRead,
    );
    final preserveLocalStatus = localPriority > serverPriority;
    final mergedServerMessage = preserveLocalStatus
        ? serverMessage.copyWith(
            messageStatus: last.messageStatus,
            isRead: last.isRead,
            deliveredAt: last.deliveredAt ?? serverMessage.deliveredAt,
            readAt: last.readAt ?? serverMessage.readAt,
          )
        : serverMessage.copyWith(
            deliveredAt: serverMessage.deliveredAt ?? last.deliveredAt,
            readAt: serverMessage.readAt ?? last.readAt,
            isRead: serverMessage.isRead || last.isRead,
          );

    _currentList = List.from(_currentList);
    _currentList[index] = existing.copyWith(lastMessage: mergedServerMessage);
    _sortByLastMessageTime();
    _emit();
  }

  ChatListStream._();

  bool _isDeleteTombstoneMessage(ChatMessageModel? message) {
    if (message == null) return false;
    if (message.id.trim().isEmpty) return false;
    if (message.messageType == MessageType.deleted) return false;
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

  List<ChatContactModel> _sanitizeContacts(List<ChatContactModel> contacts) {
    return contacts.map((c) {
      final last = c.lastMessage;
      if (_isDeleteTombstoneMessage(last)) {
        return ChatContactModel(
          user: c.user,
          lastMessage: null,
          lastActivity: c.lastActivity,
          unreadCount: c.unreadCount,
        );
      }
      return c;
    }).toList();
  }

  // BehaviorSubject-like: holds last value
  List<ChatContactModel> _currentList = [];

  // Broadcast stream for multiple subscribers
  final StreamController<List<ChatContactModel>> _controller =
      StreamController<List<ChatContactModel>>.broadcast();

  Timer? _reloadDebounceTimer;
  int _reloadToken = 0;

  /// Stream that emits chat list updates
  /// Subscribe to this in any UI component that needs chat list
  Stream<List<ChatContactModel>> get stream => _controller.stream;

  /// Current chat list (synchronous access)
  List<ChatContactModel> get currentList => List.unmodifiable(_currentList);

  /// Check if data is available
  bool get hasData => _currentList.isNotEmpty;

  // =========================================================================
  // INITIALIZATION
  // =========================================================================

  /// Initialize from local database
  /// Call this during app startup
  Future<void> initialize() async {
    try {
      if (_verboseLogs && kDebugMode) {
        debugPrint('📡 [ChatListStream] Initializing...');
      }

      final cached = ChatListCache.instance.contacts;
      if (cached != null && cached.isNotEmpty) {
        _currentList = List.from(cached);
        _deduplicateCurrentList();
        _sortByLastMessageTime();
        _emit();
        if (_verboseLogs && kDebugMode) {
          debugPrint(
            '📡 [ChatListStream] Initialized from memory cache with ${cached.length} contacts',
          );
        }
        return;
      }

      final dataSource = ChatLocalDataSourceImpl();
      final contacts = _sanitizeContacts(
        await dataSource.getChatContactsFromLocal(),
      );

      // Sort by last message time (most recent first)
      _currentList = List.from(contacts);

      // Ensure no duplicates on initialize
      _deduplicateCurrentList();

      _sortByLastMessageTime();
      _emit();

      if (_verboseLogs && kDebugMode) {
        debugPrint(
          '📡 [ChatListStream] Initialized with ${contacts.length} contacts',
        );
      }
    } catch (e) {
      if (_verboseLogs && kDebugMode) {
        debugPrint('❌ [ChatListStream] Init failed: $e');
      }
    }
  }

  /// Reload from database (force refresh)
  Future<void> reload({bool replaceExisting = false}) async {
    final token = ++_reloadToken;
    await _reloadInternal(token: token, replaceExisting: replaceExisting);
  }

  Future<void> reloadDebounced({
    bool replaceExisting = false,
    Duration debounce = const Duration(milliseconds: 250),
  }) async {
    _reloadDebounceTimer?.cancel();
    final token = ++_reloadToken;
    _reloadDebounceTimer = Timer(debounce, () {
      unawaited(
        _reloadInternal(token: token, replaceExisting: replaceExisting),
      );
    });
  }

  Future<void> _reloadInternal({
    required int token,
    required bool replaceExisting,
  }) async {
    try {
      if (_verboseLogs && kDebugMode) {
        debugPrint('🔄 [ChatListStream] Reloading from DB...');
      }
      final dataSource = ChatLocalDataSourceImpl();
      final contacts = _preserveDeletedActivities(
        _sanitizeContacts(await dataSource.getChatContactsFromLocal()),
      );

      if (token != _reloadToken) return;

      if (replaceExisting || _currentList.isEmpty) {
        _currentList = List.from(contacts);
      } else {
        _currentList = _mergeFromDb(contacts);
      }

      // Ensure no duplicates after reload
      _deduplicateCurrentList();

      _sortByLastMessageTime();
      _emit();

      if (_verboseLogs && kDebugMode) {
        debugPrint('🔄 [ChatListStream] Reloaded ${contacts.length} contacts');
      }
    } catch (e) {
      if (_verboseLogs && kDebugMode) {
        debugPrint('❌ [ChatListStream] Reload failed: $e');
      }
    }
  }

  /// Sync stream with external data (called when ChatListNotifier loads)
  /// This ensures stream and notifier stay in sync
  void syncFrom(List<ChatContactModel> contacts) {
    if (contacts.isEmpty) return;

    final sanitized = _sanitizeContacts(contacts);

    if (_currentList.isEmpty) {
      _currentList = List.from(sanitized);
    } else {
      _currentList = _mergeFromDb(sanitized);
    }

    // CRITICAL: Final deduplication pass to prevent any duplicate contacts
    // This handles edge cases where the same user might appear twice
    _deduplicateCurrentList();

    _sortByLastMessageTime();
    _emit();
    if (_verboseLogs && kDebugMode) {
      debugPrint(
        '🔄 [ChatListStream] Synced ${contacts.length} contacts from notifier',
      );
    }
  }

  /// Remove duplicate contacts by user ID (keeps the first occurrence)
  void _deduplicateCurrentList() {
    final seen = <String>{};
    _currentList = _currentList.where((contact) {
      final id = contact.user.id;
      if (seen.contains(id)) {
        if (kDebugMode) {
          debugPrint(
            '⚠️ [ChatListStream] Removing duplicate contact: ${contact.user.firstName} ($id)',
          );
        }
        return false;
      }
      seen.add(id);
      return true;
    }).toList();
  }

  DateTime _sortTime(ChatContactModel contact) {
    final last = contact.lastMessage;
    final msgTime = last == null
        ? DateTime(1970)
        : (last.messageType == MessageType.deleted
              ? last.updatedAt
              : last.createdAt);
    final activity = contact.lastActivity;
    if (activity == null) return msgTime;

    final normalizedType = (activity.type ?? '')
        .toLowerCase()
        .trim()
        .replaceAll('-', '_');

    if (normalizedType == 'message_deleted' &&
        activity.timestamp.isAfter(msgTime)) {
      return activity.timestamp;
    }

    return msgTime;
  }

  /// Sort current list by last message time (most recent first)
  void _sortByLastMessageTime() {
    _currentList.sort((a, b) {
      final aTime = _sortTime(a);
      final bTime = _sortTime(b);
      return bTime.compareTo(aTime);
    });
  }

  // =========================================================================
  // WHATSAPP-STYLE: IN-MEMORY UPDATES (NO DB RELOAD)
  // =========================================================================

  int _statusPriority(String status) {
    return ChatMessageModel.messageStatusPriority(status);
  }

  /// Update message status instantly in memory
  /// This is the key to WhatsApp-style instant tick updates
  void updateMessageStatus({
    required String messageId,
    required String newStatus,
    String? otherUserId,
  }) {
    final normalizedNewStatus = ChatMessageModel.normalizeMessageStatus(
      newStatus,
    );
    if (kDebugMode) {
      debugPrint(
        '✓✓ [ChatListStream] updateMessageStatus: msgId=${messageId.substring(0, 8)}... status=$normalizedNewStatus otherUserId=$otherUserId',
      );
    }

    bool updated = false;

    for (int i = 0; i < _currentList.length; i++) {
      final contact = _currentList[i];
      final lastMessage = contact.lastMessage;

      if (lastMessage == null) continue;

      // Match by message ID
      if (lastMessage.id == messageId) {
        final currentPriority = ChatMessageModel.messageStatusPriority(
          lastMessage.messageStatus,
          isRead: lastMessage.isRead,
        );
        final newPriority = ChatMessageModel.messageStatusPriority(
          normalizedNewStatus,
        );

        if (newPriority < currentPriority) {
          if (_verboseLogs && kDebugMode) {
            debugPrint(
              '⚠️ [ChatListStream] Ignoring status regression for $messageId: '
              '${lastMessage.messageStatus} → $newStatus',
            );
          }
          return;
        }

        final updatedMessage = lastMessage.copyWith(
          messageStatus: normalizedNewStatus,
          isRead: normalizedNewStatus == 'read',
          deliveredAt:
              (normalizedNewStatus == 'delivered' ||
                  normalizedNewStatus == 'read')
              ? (lastMessage.deliveredAt ?? DateTime.now())
              : lastMessage.deliveredAt,
          readAt: normalizedNewStatus == 'read'
              ? (lastMessage.readAt ?? DateTime.now())
              : lastMessage.readAt,
          updatedAt: DateTime.now(),
        );

        final updatedContact = contact.copyWith(lastMessage: updatedMessage);

        // Update list in place
        _currentList = List.from(_currentList);
        _currentList[i] = updatedContact;
        updated = true;

        if (_verboseLogs && kDebugMode) {
          debugPrint('✓✓ [ChatListStream] Status updated in memory');
        }
        break;
      }
    }

    if (!updated &&
        otherUserId != null &&
        otherUserId.isNotEmpty &&
        !messageId.startsWith('local_') &&
        !messageId.startsWith('temp_')) {
      final idx = _currentList.indexWhere((c) => c.user.id == otherUserId);
      if (idx != -1) {
        final contact = _currentList[idx];
        final lastMessage = contact.lastMessage;
        final isOptimistic =
            lastMessage != null &&
            (lastMessage.id.startsWith('local_') ||
                lastMessage.id.startsWith('temp_'));
        final isOutgoing =
            lastMessage != null && lastMessage.senderId != otherUserId;
        final isRecent =
            lastMessage != null &&
            DateTime.now().difference(lastMessage.createdAt) <
                const Duration(minutes: 5);

        if (lastMessage != null && isOptimistic && isOutgoing && isRecent) {
          final currentPriority = ChatMessageModel.messageStatusPriority(
            lastMessage.messageStatus,
            isRead: lastMessage.isRead,
          );
          final newPriority = ChatMessageModel.messageStatusPriority(
            normalizedNewStatus,
          );
          if (newPriority >= currentPriority) {
            final updatedMessage = lastMessage.copyWith(
              messageStatus: normalizedNewStatus,
              isRead: normalizedNewStatus == 'read',
              deliveredAt:
                  (normalizedNewStatus == 'delivered' ||
                      normalizedNewStatus == 'read')
                  ? (lastMessage.deliveredAt ?? DateTime.now())
                  : lastMessage.deliveredAt,
              readAt: normalizedNewStatus == 'read'
                  ? (lastMessage.readAt ?? DateTime.now())
                  : lastMessage.readAt,
              updatedAt: DateTime.now(),
            );

            final updatedContact = contact.copyWith(
              lastMessage: updatedMessage,
            );
            _currentList = List.from(_currentList);
            _currentList[idx] = updatedContact;
            updated = true;
          }
        }
      }
    }

    if (updated) {
      if (kDebugMode) {
        debugPrint(
          '✅ [ChatListStream] updateMessageStatus: SUCCESS - status updated to $newStatus',
        );
      }
      _emit();
    } else {
      if (kDebugMode) {
        debugPrint(
          '⚠️ [ChatListStream] updateMessageStatus: FAILED - message ${messageId.substring(0, 8)}... not found in currentList',
        );
      }
    }
  }

  /// Update or add a contact (for new messages)
  void updateContact(ChatContactModel contact) {
    if (_verboseLogs && kDebugMode) {
      debugPrint('📝 [ChatListStream] Updating contact: ${contact.user.id}');
    }

    final index = _currentList.indexWhere((c) => c.user.id == contact.user.id);
    _currentList = List.from(_currentList);

    if (index != -1) {
      final existingUnread = _currentList[index].unreadCount;
      _currentList[index] = contact.copyWith(
        unreadCount: contact.unreadCount != 0
            ? contact.unreadCount
            : existingUnread,
      );
    } else {
      // New contact - add to top
      _currentList.insert(0, contact);
    }

    _sortByLastMessageTime();

    _emit();
  }

  /// Remove a contact
  void removeContact(String otherUserId) {
    _currentList = _currentList.where((c) => c.user.id != otherUserId).toList();
    _emit();
  }

  // =========================================================================
  // INTERNAL
  // =========================================================================

  List<ChatContactModel> _mergeFromDb(List<ChatContactModel> contactsFromDb) {
    if (contactsFromDb.isEmpty) {
      return [];
    }

    if (_currentList.isEmpty) {
      // Sort by last message time (most recent first)
      final sorted = List<ChatContactModel>.from(contactsFromDb);
      sorted.sort((a, b) {
        final aTime = _sortTime(a);
        final bTime = _sortTime(b);
        return bTime.compareTo(aTime);
      });
      return sorted;
    }

    // DEDUPLICATION: Use Map to ensure unique contacts by user ID
    final Map<String, ChatContactModel> mergedByUserId = {};

    // First, add all existing contacts to the map
    for (final c in _currentList) {
      mergedByUserId[c.user.id] = c;
    }

    // Then, merge/update with contacts from DB
    for (final dbContact in contactsFromDb) {
      final existing = mergedByUserId[dbContact.user.id];
      if (existing == null) {
        mergedByUserId[dbContact.user.id] = dbContact;
        continue;
      }

      final existingUnreadCount = existing.unreadCount;

      final dbLast = _isDeleteTombstoneMessage(dbContact.lastMessage)
          ? null
          : dbContact.lastMessage;
      final curLast = _isDeleteTombstoneMessage(existing.lastMessage)
          ? null
          : existing.lastMessage;

      if (dbLast == null && curLast == null) {
        // Keep existing (already in map)
        continue;
      }

      if (dbLast == null && curLast != null) {
        // Keep existing (already in map)
        continue;
      }

      if (dbLast != null && curLast == null) {
        mergedByUserId[dbContact.user.id] = dbContact.copyWith(
          unreadCount: existingUnreadCount,
        );
        continue;
      }

      if (dbLast!.id == curLast!.id) {
        final dbPriority = _statusPriority(dbLast.messageStatus);
        final curPriority = _statusPriority(curLast.messageStatus);
        if (curPriority < dbPriority) {
          mergedByUserId[dbContact.user.id] = dbContact.copyWith(
            unreadCount: existingUnreadCount,
          );
        }
        // else keep existing (already in map)
        continue;
      }

      final dbTime = dbLast.createdAt;
      final curTime = curLast.createdAt;
      if (dbTime.isAfter(curTime)) {
        mergedByUserId[dbContact.user.id] = dbContact.copyWith(
          unreadCount: existingUnreadCount,
        );
      }
      // else keep existing (already in map)
    }

    // Convert map values to list
    final merged = mergedByUserId.values.toList();

    // CRITICAL: Sort by last message time (most recent first)
    // This ensures chat with latest message always appears at top
    merged.sort((a, b) {
      final aTime = _sortTime(a);
      final bTime = _sortTime(b);
      return bTime.compareTo(aTime);
    });

    return merged;
  }

  void _emit() {
    if (!_controller.isClosed) {
      _controller.add(_currentList);
      if (_verboseLogs && kDebugMode) {
        debugPrint(
          '📡 [ChatListStream] Emitted ${_currentList.length} contacts',
        );
      }
    }
  }

  /// Dispose (call on app close)
  void dispose() {
    _controller.close();
    _currentList = [];
    _instance = null;
  }
}
