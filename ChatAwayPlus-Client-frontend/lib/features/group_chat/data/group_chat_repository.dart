import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:chataway_plus/core/constants/api_url/api_urls.dart';
import 'package:chataway_plus/core/storage/token_storage.dart';
import 'package:chataway_plus/features/chat/data/socket/core/socket_connection_manager.dart';
import 'package:chataway_plus/features/group_chat/models/group_models.dart';

/// GroupChatRepository
///
/// Handles:
/// - REST calls to /api/groups/*
/// - Socket.IO events: join_group, send_group_message, receive_group_message, etc.
class GroupChatRepository {
  // ─── Singleton ────────────────────────────────────────────────────────────
  static final GroupChatRepository _instance = GroupChatRepository._internal();
  factory GroupChatRepository() => _instance;
  static GroupChatRepository get instance => _instance;
  GroupChatRepository._internal();

  final TokenSecureStorage _tokenStorage = TokenSecureStorage();
  final SocketConnectionManager _socketManager = SocketConnectionManager();

  // ─── Streams ──────────────────────────────────────────────────────────────
  final StreamController<GroupMessageModel> _newMessageController =
      StreamController<GroupMessageModel>.broadcast();
  final StreamController<GroupMessageModel> _messageSentController =
      StreamController<GroupMessageModel>.broadcast();
  final StreamController<Map<String, dynamic>> _typingController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _messageDeletedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _statusUpdateController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _messagesSyncedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<void> _reconnectController =
      StreamController<void>.broadcast();

  Stream<GroupMessageModel> get onNewGroupMessage =>
      _newMessageController.stream;
  Stream<GroupMessageModel> get onGroupMessageSent =>
      _messageSentController.stream;
  Stream<Map<String, dynamic>> get onGroupTyping => _typingController.stream;
  Stream<Map<String, dynamic>> get onGroupMessageDeleted =>
      _messageDeletedController.stream;
  Stream<Map<String, dynamic>> get onGroupMessageStatusUpdated =>
      _statusUpdateController.stream;
  Stream<Map<String, dynamic>> get onGroupMessagesSynced =>
      _messagesSyncedController.stream;
  Stream<void> get onReconnect => _reconnectController.stream;

  bool _isStreamListening = false;
  bool _listenersRegistered = false;

  // ─── Socket Listener Setup ─────────────────────────────────────────────────
  void registerSocketListeners() {
    // 1. Ensure we only set up the stream listener once
    if (!_isStreamListening) {
      _socketManager.onConnected.listen((_) {
        debugPrint('📡 [GroupChat] Socket connected stream triggered');
        _registerActualListeners();
      });
      _isStreamListening = true;
    }

    // 2. If already connected, register immediately
    if (_socketManager.isConnected && _socketManager.socket != null) {
      _registerActualListeners();
    }
  }

  void _registerActualListeners() {
    final socket = _socketManager.socket;
    if (socket == null) return;

    // Always call off first to prevent duplicate listeners
    _removeAllSocketListeners();

    socket.on('receive_group_message', (data) {
      try {
        final map =
            data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
        final msg = GroupMessageModel.fromJson(map);
        _newMessageController.add(msg);
        debugPrint('📩 [GroupChat] receive_group_message: ${msg.id}');
      } catch (e) {
        debugPrint('❌ [GroupChat] receive_group_message parse error: $e');
      }
    });

    socket.on('group_message_sent', (data) {
      try {
        final map =
            data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
        final msg = GroupMessageModel.fromJson(map);
        _messageSentController.add(msg);
        debugPrint('✅ [GroupChat] group_message_sent: ${msg.id}');
      } catch (e) {
        debugPrint('❌ [GroupChat] group_message_sent parse error: $e');
      }
    });

    socket.on('group_user_typing', (data) {
      try {
        final map =
            data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
        _typingController.add(map);
      } catch (e) {
        debugPrint('❌ [GroupChat] group_user_typing parse error: $e');
      }
    });

    socket.on('group-message-deleted', (data) {
      try {
        final map =
            data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
        _messageDeletedController.add(map);
      } catch (e) {
        debugPrint('❌ [GroupChat] group-message-deleted parse error: $e');
      }
    });

    socket.on('group-message-status-updated', (data) {
      try {
        final map =
            data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
        _statusUpdateController.add(map);
      } catch (e) {
        debugPrint(
            '❌ [GroupChat] group-message-status-updated parse error: $e');
      }
    });

    socket.on('group-messages-synced', (data) {
      try {
        final map =
            data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
        _messagesSyncedController.add(map);
      } catch (e) {
        debugPrint('❌ [GroupChat] group-messages-synced parse error: $e');
      }
    });

    _listenersRegistered = true;
    debugPrint('✅ [GroupChat] Socket listeners registered');

    // Signal reconnection to all active providers (room rejoin + sync)
    _reconnectController.add(null);

    // Auto-rejoin all groups for this user (Bulk Join)
    Future.microtask(() async {
      try {
        final groups = await getMyGroups();
        final ids = groups.map((g) => g.id).toList();
        if (ids.isNotEmpty) {
          socket.emit('join_groups', ids);
          debugPrint('🏠 [GroupChat] Sent bulk join_groups for ${ids.length} groups');
        }
      } catch (e) {
        debugPrint('❌ [GroupChat] Failed to bulk-rejoin groups: $e');
      }
    });
  }

  /// Remove ALL socket listeners managed by this repository.
  void _removeAllSocketListeners() {
    final socket = _socketManager.socket;
    if (socket == null) return;
    socket.off('receive_group_message');
    socket.off('group_message_sent');
    socket.off('group_user_typing');
    socket.off('group-message-deleted');
    socket.off('group-message-status-updated');
    socket.off('group-messages-synced');
    socket.off('connect');
  }

  void unregisterSocketListeners() {
    _removeAllSocketListeners();
    _listenersRegistered = false;
    debugPrint('🔌 [GroupChat] Socket listeners unregistered');
  }

  // ─── Join / Leave Group Room ──────────────────────────────────────────────
  void joinGroupRoom(String groupId) {
    final socket = _socketManager.socket;
    if (socket == null || !socket.connected) return;
    socket.emit('join_group', groupId);
    debugPrint('📡 [GroupChat] Emitted join_group: $groupId');
  }

  void joinGroups(List<String> groupIds) {
    final socket = _socketManager.socket;
    if (socket == null || !socket.connected) return;
    socket.emit('join_groups', groupIds);
    debugPrint(
        '📡 [GroupChat] Emitted join_groups for ${groupIds.length} groups');
  }

  void leaveGroupRoom(String groupId) {
    final socket = _socketManager.socket;
    if (socket == null) return;
    // Use the correct backend event name
    socket.emit('leave_group', groupId);
    debugPrint('📡 [GroupChat] Emitted leave_group: $groupId');
  }

  // ─── Send Group Message via Socket ────────────────────────────────────────
  Future<void> sendGroupMessage({
    required String groupId,
    String? message,
    String messageType = 'text',
    String? fileUrl,
    String? mimeType,
    Map<String, dynamic>? pollPayload,
    List<Map<String, dynamic>>? contactPayload,
    int? imageWidth,
    int? imageHeight,
    double? audioDuration,
    String? videoThumbnailUrl,
    double? videoDuration,
    String? replyToMessageId,
    String? clientMessageId,
  }) async {
    final socket = _socketManager.socket;
    if (socket == null || !socket.connected) {
      debugPrint('⚠️ [GroupChat] Socket not connected, cannot send message');
      throw Exception('Socket disconnected');
    }

    final payload = <String, dynamic>{
      'groupId': groupId,
      if (message != null) 'message': message,
      'messageType': messageType,
      if (fileUrl != null) 'fileUrl': fileUrl,
      if (mimeType != null) 'mimeType': mimeType,
      if (pollPayload != null) 'pollPayload': pollPayload,
      if (contactPayload != null) 'contactPayload': contactPayload,
      if (imageWidth != null) 'imageWidth': imageWidth,
      if (imageHeight != null) 'imageHeight': imageHeight,
      if (audioDuration != null) 'audioDuration': audioDuration,
      if (videoThumbnailUrl != null) 'videoThumbnailUrl': videoThumbnailUrl,
      if (videoDuration != null) 'videoDuration': videoDuration,
      if (replyToMessageId != null) 'replyToMessageId': replyToMessageId,
      if (clientMessageId != null) 'clientMessageId': clientMessageId,
    };

    final completer = Completer<void>();

    socket.emitWithAck('send_group_message', payload, ack: (response) {
      try {
        final map = response is Map
            ? Map<String, dynamic>.from(response)
            : <String, dynamic>{};
        if (map['success'] == true && map['message'] != null) {
          final msg = GroupMessageModel.fromJson(
              Map<String, dynamic>.from(map['message']));
          _messageSentController.add(msg);
          debugPrint(
              '✅ [GroupChat] Message acknowledged by server: ${msg.id}');
          if (!completer.isCompleted) completer.complete();
        } else {
          final error = map['error'] ?? 'Unknown error';
          debugPrint('❌ [GroupChat] Message rejected by server: $error');
          if (clientMessageId != null) {
            _messageDeletedController.add({
              'messageId': clientMessageId,
              'groupId': groupId,
              'error': error,
            });
          }
          if (!completer.isCompleted) completer.completeError(error);
        }
      } catch (e) {
        if (!completer.isCompleted) completer.completeError(e);
      }
    });

    debugPrint(
        '📤 [GroupChat] Emitted send_group_message → $groupId (clientId: $clientMessageId)');
    return completer.future;
  }

  // ─── Typing Indicator ─────────────────────────────────────────────────────
  void sendTyping(String groupId, {required bool isTyping}) {
    final socket = _socketManager.socket;
    if (socket == null || !socket.connected) return;
    socket.emit('group_typing', {'groupId': groupId, 'isTyping': isTyping});
  }

  void startTyping(String groupId) => sendTyping(groupId, isTyping: true);
  void stopTyping(String groupId) => sendTyping(groupId, isTyping: false);

  // ─── Message Status ────────────────────────────────────────────────────────
  void updateGroupMessageStatus({
    required List<String> chatIds,
    required String groupId,
    required String status,
  }) {
    final socket = _socketManager.socket;
    if (socket == null || !socket.connected) return;
    socket.emit('update-group-message-status', {
      'chatIds': chatIds,
      'groupId': groupId,
      'status': status,
    });
  }

  // ─── Sync Messages ─────────────────────────────────────────────────────────
  void syncGroupMessages(
      {required String groupId, String? lastSeenTimestamp}) {
    final socket = _socketManager.socket;
    if (socket == null || !socket.connected) return;
    socket.emit('sync-group-messages', {
      'groupId': groupId,
      if (lastSeenTimestamp != null) 'lastSeenTimestamp': lastSeenTimestamp,
    });
  }

  // ─── REST: Create Group ────────────────────────────────────────────────────
  Future<GroupModel> createGroup({
    required String name,
    required List<String> memberIds,
    String? description,
    String? icon,
    bool isRestricted = false,
  }) async {
    final token = await _tokenStorage.getToken();
    final response = await http.post(
      Uri.parse('${ApiUrls.apiBaseUrl}/groups'),
      headers: _headers(token),
      body: jsonEncode({
        'name': name,
        'memberIds': memberIds,
        if (description != null) 'description': description,
        if (icon != null) 'icon': icon,
        'isRestricted': isRestricted,
      }),
    );

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 201 && body['success'] == true) {
      return GroupModel.fromJson(body['data'] as Map<String, dynamic>);
    }
    throw Exception(body['error'] ?? 'Failed to create group');
  }

  // ─── REST: Get My Groups ───────────────────────────────────────────────────
  Future<List<GroupModel>> getMyGroups() async {
    final token = await _tokenStorage.getToken();
    final response = await http.get(
      Uri.parse('${ApiUrls.apiBaseUrl}/groups/my'),
      headers: _headers(token),
    );

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200 && body['success'] == true) {
      final list = body['data'] as List<dynamic>;
      return list
          .map((e) => GroupModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception(body['error'] ?? 'Failed to fetch groups');
  }

  // ─── REST: Get Group Details ───────────────────────────────────────────────
  Future<GroupModel> getGroupDetails(String groupId) async {
    final token = await _tokenStorage.getToken();
    final response = await http.get(
      Uri.parse('${ApiUrls.apiBaseUrl}/groups/$groupId'),
      headers: _headers(token),
    );

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200 && body['success'] == true) {
      return GroupModel.fromJson(body['data'] as Map<String, dynamic>);
    }
    throw Exception(body['error'] ?? 'Failed to fetch group details');
  }

  // ─── REST: Get Group Messages ──────────────────────────────────────────────
  Future<List<GroupMessageModel>> getGroupMessages(
    String groupId, {
    int page = 1,
    int limit = 50,
    String? sinceMessageId,
    String? beforeMessageId,
  }) async {
    final token = await _tokenStorage.getToken();
    final queryParams = {
      'page': '$page',
      'limit': '$limit',
      if (sinceMessageId != null) 'sinceMessageId': sinceMessageId,
      if (beforeMessageId != null) 'beforeMessageId': beforeMessageId,
    };
    final uri =
        Uri.parse('${ApiUrls.apiBaseUrl}/groups/$groupId/messages')
            .replace(queryParameters: queryParams);

    final response = await http.get(uri, headers: _headers(token));
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200 && body['success'] == true) {
      final data = body['data'] as Map<String, dynamic>;
      final list = data['messages'] as List<dynamic>;
      return list
          .map((e) => GroupMessageModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception(body['error'] ?? 'Failed to fetch group messages');
  }

  // ─── REST: Update Group ────────────────────────────────────────────────────
  Future<GroupModel> updateGroup(
    String groupId, {
    String? name,
    String? description,
    String? icon,
    bool? isRestricted,
  }) async {
    final token = await _tokenStorage.getToken();
    final response = await http.put(
      Uri.parse('${ApiUrls.apiBaseUrl}/groups/$groupId'),
      headers: _headers(token),
      body: jsonEncode({
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (icon != null) 'icon': icon,
        if (isRestricted != null) 'isRestricted': isRestricted,
      }),
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200 && body['success'] == true) {
      return GroupModel.fromJson(body['data'] as Map<String, dynamic>);
    }
    throw Exception(body['error'] ?? 'Failed to update group');
  }

  // ─── REST: Add Members ─────────────────────────────────────────────────────
  Future<GroupModel> addMembers(String groupId, List<String> memberIds) async {
    final token = await _tokenStorage.getToken();
    final response = await http.post(
      Uri.parse('${ApiUrls.apiBaseUrl}/groups/$groupId/members'),
      headers: _headers(token),
      body: jsonEncode({'memberIds': memberIds}),
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200 && body['success'] == true) {
      return GroupModel.fromJson(body['data'] as Map<String, dynamic>);
    }
    throw Exception(body['error'] ?? 'Failed to add members');
  }

  // ─── REST: Remove Member / Leave Group ────────────────────────────────────
  Future<void> removeMember(String groupId, String targetUserId) async {
    final token = await _tokenStorage.getToken();
    final response = await http.delete(
      Uri.parse(
          '${ApiUrls.apiBaseUrl}/groups/$groupId/members/$targetUserId'),
      headers: _headers(token),
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200 || body['success'] != true) {
      throw Exception(body['error'] ?? 'Failed to remove member');
    }
  }

  // ─── REST: Update Member Role ──────────────────────────────────────────────
  Future<void> updateMemberRole(
      String groupId, String targetUserId, String role) async {
    final token = await _tokenStorage.getToken();
    final response = await http.patch(
      Uri.parse(
          '${ApiUrls.apiBaseUrl}/groups/$groupId/members/$targetUserId/role'),
      headers: _headers(token),
      body: jsonEncode({'role': role}),
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200 || body['success'] != true) {
      throw Exception(body['error'] ?? 'Failed to update role');
    }
  }

  // ─── REST: Delete Group ────────────────────────────────────────────────────
  Future<void> deleteGroup(String groupId) async {
    final token = await _tokenStorage.getToken();
    final response = await http.delete(
      Uri.parse('${ApiUrls.apiBaseUrl}/groups/$groupId'),
      headers: _headers(token),
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200 || body['success'] != true) {
      throw Exception(body['error'] ?? 'Failed to delete group');
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────
  Map<String, String> _headers(String? token) => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  void dispose() {
    unregisterSocketListeners();
    _newMessageController.close();
    _messageSentController.close();
    _typingController.close();
    _messageDeletedController.close();
    _statusUpdateController.close();
    _messagesSyncedController.close();
    _reconnectController.close();
  }
}
