import 'package:flutter/foundation.dart';
import 'message_reaction.dart';

/// Socket reaction updated event response
class SocketReactionUpdatedResponse {
  final String messageId;
  final String userId;
  final String? emoji;
  final String action; // 'added' or 'removed'
  final List<MessageReaction> reactions;
  final DateTime timestamp;

  SocketReactionUpdatedResponse({
    required this.messageId,
    required this.userId,
    this.emoji,
    required this.action,
    required this.reactions,
    required this.timestamp,
  });

  /// Parse a list of reactions, auto-detecting flat vs grouped format.
  /// Flat: [{id, userId, emoji, createdAt, user: {...}}]
  /// Grouped: [{emoji, count, users: [{id, firstName, lastName, chat_picture}]}]
  static List<MessageReaction> _parseReactionsList(
    List<dynamic> list,
    String messageId,
  ) {
    if (list.isEmpty) return <MessageReaction>[];

    final first = list.first;
    final isGrouped = first is Map && first.containsKey('users');

    final reactions = <MessageReaction>[];

    if (isGrouped) {
      for (final group in list) {
        if (group is! Map) continue;
        final groupMap = Map<String, dynamic>.from(group);
        final emoji = groupMap['emoji']?.toString() ?? '';
        final users = (groupMap['users'] is List)
            ? List<dynamic>.from(groupMap['users'] as List)
            : <dynamic>[];

        for (final user in users) {
          if (user is! Map) continue;
          final userMap = Map<String, dynamic>.from(user);
          final userId = userMap['id']?.toString() ?? '';
          if (userId.isEmpty) continue;

          final userChatPicture =
              userMap['chat_picture']?.toString() ??
              userMap['chatPicture']?.toString() ??
              userMap['profile_pic']?.toString() ??
              userMap['profilePic']?.toString();

          reactions.add(
            MessageReaction(
              id: '${messageId}_$userId',
              messageId: messageId,
              userId: userId,
              emoji: emoji,
              createdAt: DateTime.now(),
              userFirstName: userMap['firstName']?.toString(),
              userLastName: userMap['lastName']?.toString(),
              userChatPicture: userChatPicture,
              isSynced: true,
            ),
          );
        }
      }
    } else {
      // Flat format from chat history
      for (final item in list) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final parsed = MessageReaction.fromJson(map);
        reactions.add(
          parsed.copyWith(
            messageId: parsed.messageId.isNotEmpty ? null : messageId,
            isSynced: true,
          ),
        );
      }
    }

    return reactions;
  }

  factory SocketReactionUpdatedResponse.fromJson(Map<String, dynamic> json) {
    debugPrint('🔍 Parsing reaction response: $json');

    // Backend sends: { success: true, data: { messageId: "...", reactions: [...], ... } }
    // Extract the data wrapper if present
    final dataWrapper = json['data'];
    final payload = dataWrapper is Map
        ? Map<String, dynamic>.from(dataWrapper)
        : Map<String, dynamic>.from(json);

    debugPrint('🔍 Payload after unwrapping: $payload');

    final reactionsPayload = payload['reactions'];

    final messageId =
        payload['messageId']?.toString() ?? payload['chatId']?.toString() ?? '';

    List<MessageReaction> reactions = <MessageReaction>[];

    // Chat history format (flat): reactions: [ { id, userId, emoji, createdAt, user: {...} } ]
    // reaction-updated / message-reactions format (grouped wrapper):
    //   reactions: { messageId, totalReactions, currentUserReaction,
    //     reactions: [ { emoji, count, users: [ {id, firstName, ...} ] } ] }
    if (reactionsPayload is List) {
      // Direct list — detect flat vs grouped by checking for 'users' key
      reactions = SocketReactionUpdatedResponse._parseReactionsList(
        reactionsPayload,
        messageId,
      );
    } else if (reactionsPayload is Map) {
      // Wrapper object from reaction-updated / message-reactions events
      final innerList = reactionsPayload['reactions'];
      if (innerList is List) {
        reactions = SocketReactionUpdatedResponse._parseReactionsList(
          innerList,
          messageId,
        );
      }
    }

    debugPrint('✅ Total reactions parsed: ${reactions.length}');

    final timestamp = payload['timestamp'];
    DateTime parsedTimestamp = DateTime.now();
    if (timestamp is String) {
      parsedTimestamp = DateTime.tryParse(timestamp) ?? DateTime.now();
    } else if (timestamp is DateTime) {
      parsedTimestamp = timestamp;
    }

    final response = SocketReactionUpdatedResponse(
      messageId: messageId,
      userId: payload['userId']?.toString() ?? '',
      emoji:
          payload['emoji']?.toString() ??
          (reactionsPayload is Map
              ? reactionsPayload['currentUserReaction']?.toString()
              : null) ??
          payload['currentUserReaction']?.toString(),
      action: payload['action']?.toString() ?? 'added',
      reactions: reactions,
      timestamp: parsedTimestamp,
    );

    debugPrint(
      '✅ Response created: messageId=$messageId, reactions=${reactions.length}',
    );

    return response;
  }
}
