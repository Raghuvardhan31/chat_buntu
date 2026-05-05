import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:chataway_plus/features/group_chat/data/group_chat_repository.dart';
import 'package:chataway_plus/features/group_chat/models/group_models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';

// ─────────────────────────────────────────────────────────────────────────────
// REPOSITORY PROVIDER
// ─────────────────────────────────────────────────────────────────────────────
final groupChatRepositoryProvider = Provider<GroupChatRepository>((ref) {
  return GroupChatRepository.instance;
});

// Initialize listeners globally so we get messages for ALL groups
final groupChatInitializerProvider = Provider<void>((ref) {
  final repo = ref.watch(groupChatRepositoryProvider);
  repo.registerSocketListeners();

  // Rejoin all groups whenever socket connects (handles first connect + reconnects).
  // The repository's own 'connect' listener already does this, but calling joinGroups
  // once at startup ensures groups are joined if the socket is already connected.
  Future.microtask(() async {
    try {
      final groups = await repo.getMyGroups();
      final ids = groups.map((g) => g.id).toList();
      if (ids.isNotEmpty) {
        // join_groups is idempotent on the backend — safe to call even if already joined
        repo.joinGroups(ids);
        debugPrint('🏠 [GroupChat] Initial join_groups emitted for ${ids.length} groups');
      }
    } catch (e) {
      debugPrint('❌ [GroupChat] Initial join error: $e');
    }
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// MY GROUPS LIST PROVIDER
// ─────────────────────────────────────────────────────────────────────────────
final myGroupsProvider =
    AsyncNotifierProvider<MyGroupsNotifier, List<GroupModel>>(MyGroupsNotifier.new);

class MyGroupsNotifier extends AsyncNotifier<List<GroupModel>> {
  @override
  Future<List<GroupModel>> build() async {
    final repo = ref.read(groupChatRepositoryProvider);
    
    // Ensure socket listeners are active globally for chat list updates
    repo.registerSocketListeners();
    
    // Register global listener for group list updates
    final sub = repo.onNewGroupMessage.listen((msg) {
      updateLastMessage(
        msg.groupId, 
        GroupLastMessage(
          id: msg.id,
          message: msg.message,
          messageType: msg.messageType,
          senderId: msg.senderId,
          senderName: msg.senderName,
          createdAt: msg.createdAt,
        ),
      );
    });
    
    ref.onDispose(() => sub.cancel());

    return _fetch();
  }

  Future<List<GroupModel>> _fetch() async {
    final repo = ref.read(groupChatRepositoryProvider);
    return repo.getMyGroups();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_fetch);
  }

  void addGroup(GroupModel group) {
    final current = state.valueOrNull ?? [];
    state = AsyncData([group, ...current]);
  }

  void updateGroup(GroupModel updated) {
    final current = state.valueOrNull ?? [];
    state = AsyncData(
      current.map((g) => g.id == updated.id ? updated : g).toList(),
    );
  }

  void removeGroup(String groupId) {
    final current = state.valueOrNull ?? [];
    state = AsyncData(current.where((g) => g.id != groupId).toList());
  }

  void updateLastMessage(String groupId, GroupLastMessage lastMsg) {
    final current = state.valueOrNull ?? [];
    if (!current.any((g) => g.id == groupId)) return;
    
    state = AsyncData(
      current.map((g) => g.id == groupId ? g.copyWith(lastMessage: lastMsg) : g).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GROUP DETAILS PROVIDER (per group)
// ─────────────────────────────────────────────────────────────────────────────
final groupDetailsProvider =
    AsyncNotifierProviderFamily<GroupDetailsNotifier, GroupModel, String>(
        GroupDetailsNotifier.new);

class GroupDetailsNotifier extends FamilyAsyncNotifier<GroupModel, String> {
  @override
  Future<GroupModel> build(String groupId) async {
    final repo = ref.read(groupChatRepositoryProvider);
    return repo.getGroupDetails(groupId);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(groupChatRepositoryProvider);
      return repo.getGroupDetails(arg);
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GROUP MESSAGES PROVIDER (per group)
// ─────────────────────────────────────────────────────────────────────────────
final groupMessagesProvider =
    AsyncNotifierProviderFamily<GroupMessagesNotifier, List<GroupMessageModel>, String>(
        GroupMessagesNotifier.new);

class GroupMessagesNotifier
    extends FamilyAsyncNotifier<List<GroupMessageModel>, String> {
  StreamSubscription<GroupMessageModel>? _newMsgSub;
  StreamSubscription<GroupMessageModel>? _sentSub;
  StreamSubscription<Map<String, dynamic>>? _deleteSub;
  StreamSubscription<Map<String, dynamic>>? _statusSub;
  StreamSubscription<Map<String, dynamic>>? _syncSub;
  StreamSubscription<void>? _reconnectSub;
  
  // Race condition buffer: status updates that arrive before the message
  final Map<String, List<Map<String, dynamic>>> _earlyStatusUpdates = {};

  @override
  Future<List<GroupMessageModel>> build(String groupId) async {
    final repo = ref.read(groupChatRepositoryProvider);

    // Ensure socket listeners are active
    repo.registerSocketListeners();

    // Join socket room
    repo.joinGroupRoom(groupId);

    // Listen for new incoming messages from other members
    _newMsgSub = repo.onNewGroupMessage.listen((msg) {
      if (msg.groupId == groupId) {
        _addOrReplaceMessage(msg);
      }
    });

    // Listen for our own message confirmation from server
    _sentSub = repo.onGroupMessageSent.listen((msg) {
      if (msg.groupId == groupId) {
        _replacePendingMessage(msg);
      }
    });

    // Listen for deleted messages
    _deleteSub = repo.onGroupMessageDeleted.listen((data) {
      if (data['groupId'] == groupId) {
        _markMessageDeleted(data['messageId'] as String);
      }
    });

    // Listen for status updates
    _statusSub = repo.onGroupMessageStatusUpdated.listen((data) {
      if (data['groupId'] == groupId) {
        _handleStatusUpdate(data);
      }
    });

    // Listen for missed message sync
    _syncSub = repo.onGroupMessagesSynced.listen((data) {
      if (data['groupId'] == groupId) {
        final messages = (data['messages'] as List<dynamic>)
            .map((m) => GroupMessageModel.fromJson(m as Map<String, dynamic>))
            .toList();
        _handleSyncMessages(messages);
      }
    });

    // Handle reconnection
    _reconnectSub = repo.onReconnect.listen((_) {
      debugPrint('🔄 [GroupChat] Reconnected, rejoining room and syncing...');
      repo.joinGroupRoom(groupId);
      
      final current = state.valueOrNull ?? [];
      
      // 1. Automatic Background Retry for failed messages
      final failed = current.where((m) => m.messageStatus == 'failed').toList();
      for (final m in failed) {
        debugPrint('🔁 [GroupChat] Auto-retrying failed message: ${m.clientMessageId}');
        retryMessage(m);
      }

      // 2. Sync missed messages
      if (current.isNotEmpty) {
        repo.syncGroupMessages(
          groupId: groupId,
          lastSeenTimestamp: current.last.createdAt.toIso8601String(),
        );
      }
    });

    ref.onDispose(() {
      _newMsgSub?.cancel();
      _sentSub?.cancel();
      _deleteSub?.cancel();
      _statusSub?.cancel();
      _syncSub?.cancel();
      _reconnectSub?.cancel();
      repo.leaveGroupRoom(groupId);
    });

    // 1. Load initial history from API
    final history = await repo.getGroupMessages(groupId);
    
    // 2. Load pending messages from local storage
    final pending = await _loadPendingMessages();
    
    final sorted = _deduplicateAndSort([...history, ...pending]);

    // 3. Initial Sync for missed messages (optional but good for consistency)
    if (sorted.isNotEmpty) {
      repo.syncGroupMessages(
        groupId: groupId,
        lastSeenTimestamp: sorted.last.createdAt.toIso8601String(),
      );
    }
    
    return sorted;
  }

  List<GroupMessageModel> _deduplicateAndSort(List<GroupMessageModel> list) {
    final Map<String, GroupMessageModel> deduplicated = {};
    for (var m in list) {
      deduplicated[m.id] = m;
    }
    // Clean up optimistic pending messages that match confirmed ones
    for (var m in list) {
      if (m.clientMessageId != null && m.id != m.clientMessageId) {
        deduplicated.remove(m.clientMessageId);
      }
    }
    return deduplicated.values.toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  void _addOrReplaceMessage(GroupMessageModel msg) {
    final current = state.valueOrNull ?? [];

    // 1. Replace optimistic pending message by clientMessageId first
    //    This handles: sender's own message arriving via receive_group_message
    //    (room broadcast) while an optimistic bubble is already showing.
    if (msg.clientMessageId != null) {
      final idx = current.indexWhere((m) =>
          m.id == msg.clientMessageId ||
          (m.clientMessageId != null && m.clientMessageId == msg.clientMessageId));
      if (idx != -1) {
        final updated = List<GroupMessageModel>.from(current);
        updated[idx] = msg;
        state = AsyncData(updated);
        _applyBufferedStatusUpdates(msg.id);
        return;
      }
    }

    // 2. Exact dedup by server ID — skip if already present
    final exists = current.any((m) => m.id == msg.id);
    if (exists) return;

    // 3. New message — add and sort
    state = AsyncData(_deduplicateAndSort([...current, msg]));

    // Apply buffered status updates for this message
    _applyBufferedStatusUpdates(msg.id);
  }

  void _applyBufferedStatusUpdates(String messageId) {
    if (_earlyStatusUpdates.containsKey(messageId)) {
      final updates = _earlyStatusUpdates.remove(messageId)!;
      for (var update in updates) {
        _handleStatusUpdate(update);
      }
    }
  }

  void _replacePendingMessage(GroupMessageModel confirmed) {
    final current = state.valueOrNull ?? [];
    if (confirmed.clientMessageId != null) {
      final idx = current.indexWhere((m) => m.id == confirmed.clientMessageId);
      if (idx != -1) {
        final updated = List<GroupMessageModel>.from(current);
        updated[idx] = confirmed;
        state = AsyncData(updated);
        return;
      }
    }
    // If not found as pending, add as new
    final exists = current.any((m) => m.id == confirmed.id);
    if (!exists) {
      state = AsyncData(_deduplicateAndSort([...current, confirmed]));
    }
    _persistPendingMessages();
  }

  void _markMessageDeleted(String messageId) {
    final current = state.valueOrNull ?? [];
    state = AsyncData(current.where((m) => m.id != messageId).toList());
  }

  void _handleStatusUpdate(Map<String, dynamic> data) {
    final chatIds = (data['chatIds'] as List<dynamic>).cast<String>();
    final status = data['status'] as String;
    final userId = data['userId'] as String;
    final current = state.valueOrNull ?? [];
    
    bool changed = false;
    final updated = current.map((m) {
      if (chatIds.contains(m.id)) {
        changed = true;
        final oldStatus = m.statusPerUser[userId] ?? 'sent';
        // Idempotency: only update if status is "newer" (read > delivered > sent)
        final statusPriority = {'sent': 0, 'delivered': 1, 'read': 2};
        if (statusPriority[status]! > statusPriority[oldStatus]!) {
          final newMap = Map<String, String>.from(m.statusPerUser);
          newMap[userId] = status;
          return m.copyWith(statusPerUser: newMap);
        }
      }
      return m;
    }).toList() as List<GroupMessageModel>;

    // Buffer updates for messages not yet received
    for (final id in chatIds) {
      if (!current.any((m) => m.id == id)) {
        _earlyStatusUpdates.putIfAbsent(id, () => []).add(data);
      }
    }

    if (changed) {
      state = AsyncData(updated);
    }
  }

  void _handleSyncMessages(List<GroupMessageModel> incoming) {
    final current = state.valueOrNull ?? [];
    
    final Map<String, GroupMessageModel> deduplicated = {};
    for (var m in [...current, ...incoming]) {
      // Deduplicate by ID and clientMessageId
      deduplicated[m.id] = m;
      if (m.clientMessageId != null) {
        deduplicated.remove(m.clientMessageId);
      }
    }

    final sorted = deduplicated.values.toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    state = AsyncData(sorted);
  }

  /// Mark specific messages as read
  void markMessagesAsRead(List<String> messageIds) {
    if (messageIds.isEmpty) return;
    final repo = ref.read(groupChatRepositoryProvider);
    repo.updateGroupMessageStatus(
      chatIds: messageIds,
      groupId: arg,
      status: 'read',
    );
    
    // Also update locally for immediate feedback
    final current = state.valueOrNull ?? [];
    final updated = current.map((m) {
      if (messageIds.contains(m.id)) {
        return m.copyWith(messageStatus: 'read');
      }
      return m;
    }).toList();
    state = AsyncData(updated);
  }

  /// Add an optimistic pending message immediately for snappy UI
  void addPendingMessage(GroupMessageModel msg) {
    final current = state.valueOrNull ?? [];
    state = AsyncData(_deduplicateAndSort([...current, msg]));
    _persistPendingMessages();
  }

  /// Mark a pending message as failed if send was unsuccessful
  void markMessageFailed(String clientMessageId) {
    final current = state.valueOrNull ?? [];
    final idx = current.indexWhere((m) => m.id == clientMessageId);
    if (idx != -1) {
      final updated = List<GroupMessageModel>.from(current);
      updated[idx] = updated[idx].copyWith(messageStatus: 'failed');
      state = AsyncData(updated);
      _persistPendingMessages();
    }
  }

  /// Manually retry sending a failed message
  void retryMessage(GroupMessageModel msg) {
    final repo = ref.read(groupChatRepositoryProvider);
    
    // Update status back to pending/sending
    final current = state.valueOrNull ?? [];
    final idx = current.indexWhere((m) => m.id == msg.id);
    if (idx != -1) {
      final updated = List<GroupMessageModel>.from(current);
      updated[idx] = updated[idx].copyWith(messageStatus: 'sending');
      state = AsyncData(updated);
      _persistPendingMessages();
    }

    repo.sendGroupMessage(
      groupId: arg,
      message: msg.message,
      messageType: msg.messageType,
      clientMessageId: msg.clientMessageId,
    ).catchError((e) {
      markMessageFailed(msg.clientMessageId!);
    });
  }

  // ── Local Persistence (Crash Recovery) ────────────────────────────────────
  Future<void> _persistPendingMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = state.valueOrNull ?? [];
      final pending = current.where((m) => m.id == m.clientMessageId || m.messageStatus == 'failed').toList();
      final jsonList = pending.map((m) => jsonEncode(m.toJson())).toList();
      await prefs.setStringList('pending_group_msgs_${arg}', jsonList);
    } catch (e) {
      debugPrint('❌ [GroupChat] Persist error: $e');
    }
  }

  Future<List<GroupMessageModel>> _loadPendingMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = prefs.getStringList('pending_group_msgs_${arg}') ?? [];
      return jsonList.map((j) => GroupMessageModel.fromJson(jsonDecode(j))).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> loadMoreMessages() async {
    final current = state.valueOrNull ?? [];
    if (current.isEmpty) return;
    
    try {
      final repo = ref.read(groupChatRepositoryProvider);
      final older = await repo.getGroupMessages(
        arg,
        beforeMessageId: current.first.id,
      );
      if (older.isEmpty) return;
      
      // Deduplicate and merge with strict server-time ordering
      final Map<String, GroupMessageModel> deduplicated = {};
      for (var m in [...older, ...current]) {
        // Prefer server-confirmed messages over temporary client IDs
        if (deduplicated.containsKey(m.id)) {
           // Keep the existing one if it has more info (already deduplicated)
        } else {
          deduplicated[m.id] = m;
        }
      }
      
      // Clean up optimistic pending messages that match confirmed ones
      for (var m in older) {
        if (m.clientMessageId != null) {
          deduplicated.remove(m.clientMessageId);
        }
      }

      final sorted = deduplicated.values.toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      state = AsyncData(sorted);
    } catch (e) {
      debugPrint('❌ [GroupChat] loadMoreMessages error: $e');
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GROUP TYPING PROVIDER (per group)
// ─────────────────────────────────────────────────────────────────────────────
final groupTypingProvider =
    StateNotifierProviderFamily<GroupTypingNotifier, Set<String>, String>(
        (ref, groupId) => GroupTypingNotifier(groupId, ref));

class GroupTypingNotifier extends StateNotifier<Set<String>> {
  final String groupId;
  final Ref _ref;
  StreamSubscription<Map<String, dynamic>>? _sub;
  final Map<String, Timer> _timers = {};

  GroupTypingNotifier(this.groupId, this._ref) : super({}) {
    final repo = _ref.read(groupChatRepositoryProvider);
    _sub = repo.onGroupTyping.listen((data) {
      if (data['groupId'] == groupId) {
        final userId = data['userId'] as String;
        final firstName = data['firstName'] as String? ?? 'Someone';
        final isTyping = data['isTyping'] as bool? ?? false;
        
        if (isTyping) {
          _timers[userId]?.cancel();
          state = {...state, firstName};
          _timers[userId] = Timer(const Duration(seconds: 4), () {
            state = {...state}..remove(firstName);
          });
        } else {
          _timers[userId]?.cancel();
          state = {...state}..remove(firstName);
        }
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    for (final t in _timers.values) {
      t.cancel();
    }
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CREATE GROUP PROVIDER
// ─────────────────────────────────────────────────────────────────────────────
final createGroupProvider =
    AsyncNotifierProvider<CreateGroupNotifier, void>(CreateGroupNotifier.new);

class CreateGroupNotifier extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<GroupModel> createGroup({
    required String name,
    required List<String> memberIds,
    String? description,
    String? icon,
    bool isRestricted = false,
  }) async {
    state = const AsyncValue.loading();
    final repo = ref.read(groupChatRepositoryProvider);
    try {
      final group = await repo.createGroup(
        name: name,
        memberIds: memberIds,
        description: description,
        icon: icon,
        isRestricted: isRestricted,
      );
      state = const AsyncData(null);
      // Refresh the groups list
      ref.invalidate(myGroupsProvider);
      return group;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}
