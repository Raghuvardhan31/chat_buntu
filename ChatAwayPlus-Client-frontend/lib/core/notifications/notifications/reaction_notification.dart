import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:chataway_plus/core/notifications/local/notification_local_service.dart';
import 'package:chataway_plus/core/database/tables/chat/messages_table.dart';
import 'package:chataway_plus/features/chat/data/services/chat_engine/index.dart';
import 'package:chataway_plus/features/chat/data/services/local/message_reactions_local_db.dart';
import 'package:chataway_plus/features/chat/data/socket/socket_models/reactions/message_reaction.dart';
import 'package:chataway_plus/features/contacts/data/datasources/contacts_database_service.dart';
import 'package:chataway_plus/core/app_lifecycle/app_state_service.dart';

/// Unified handler for Message Reaction notifications (FCM).
///
/// FCM Payload Structure (from backend sendReactionNotificationToUser):
/// {
///   type: 'message_reaction',
///   messageUuid: 'reaction-chat-uuid-abc-1707400000000',
///   messageId: 'chat-uuid-abc',
///   reactorId: 'user-uuid-111',
///   reactorName: 'Raju Naidu',
///   emoji: '❤️',
///   messageText: 'Hello how are you',
///   body: 'Raju Naidu: hit emoji ❤️ to "Hello how are you"',
///   title: 'New Reaction',
/// }
class ReactionNotificationHandler {
  const ReactionNotificationHandler._();

  static const List<String> supportedTypes = <String>[
    'reaction',
    'message_reaction',
    'message-reaction',
    'reaction_updated',
    'reaction-updated',
  ];

  /// Check if FCM type matches a reaction notification
  static bool isReactionType(String type) {
    final t = type.toLowerCase().trim();
    for (final v in supportedTypes) {
      if (t == v) return true;
    }
    return false;
  }

  /// Handle incoming reaction FCM notification.
  /// 1. Syncs reaction to message_reactions local DB table
  /// 2. Updates reactionsJson on the messages table
  /// 3. Shows local notification
  static Future<void> handle(
    Map<String, dynamic> data, {
    String? fcmMessageId,
  }) async {
    try {
      // ── Extract actor (reactor) info ──
      final actorId =
          data['reactorId']?.toString() ??
          data['reactor_id']?.toString() ??
          data['sender_id']?.toString() ??
          data['senderId']?.toString() ??
          data['from_user_id']?.toString() ??
          data['fromUserId']?.toString() ??
          data['userId']?.toString() ??
          data['actorId']?.toString() ??
          data['actor_id']?.toString() ??
          '';

      if (actorId.trim().isEmpty) {
        debugPrint('⚠️ [ReactionNotification] Missing actorId — skipping');
        return;
      }

      final emoji =
          data['emoji']?.toString() ??
          data['reaction']?.toString() ??
          data['emojis_update']?.toString() ??
          '';

      // The messageId of the chat message that was reacted to
      final reactedMessageId =
          data['messageId']?.toString() ??
          data['message_id']?.toString() ??
          data['chatId']?.toString() ??
          '';

      // ── Resolve display name ──
      String displayName =
          data['reactorName']?.toString() ??
          data['reactor_name']?.toString() ??
          data['senderName']?.toString() ??
          data['sender_name']?.toString() ??
          data['senderFirstName']?.toString() ??
          data['from_user_name']?.toString() ??
          data['fromUserName']?.toString() ??
          'ChatAway User';
      String? chatPictureUrl =
          data['senderProfilePic']?.toString() ??
          data['sender_profile_pic']?.toString() ??
          data['profile_pic']?.toString() ??
          data['profilePic']?.toString() ??
          data['chat_picture']?.toString();

      try {
        final contact = await ContactsDatabaseService.instance
            .getContactByUserId(actorId);
        if (contact != null) {
          displayName = contact.preferredDisplayName;
          chatPictureUrl ??= contact.userDetails?.chatPictureUrl;
        }
      } catch (_) {}

      // ── Sync reaction to local DB ──
      if (reactedMessageId.isNotEmpty && emoji.isNotEmpty) {
        await _syncReactionToLocalDb(
          reactedMessageId: reactedMessageId,
          actorId: actorId,
          emoji: emoji,
          displayName: displayName,
          chatPictureUrl: chatPictureUrl,
        );
      }

      // ── Notification suppression checks ──
      final shouldShowByAppState = AppStateService.instance
          .shouldShowNotification(actorId);
      final activeWith = ChatEngineService.instance.activeConversationUserId;
      final isActiveChat = activeWith != null && activeWith == actorId;
      if (!shouldShowByAppState || isActiveChat) {
        debugPrint(
          '🔕 [ReactionNotification] Suppressed (active chat or app state)',
        );
        return;
      }

      // ── Dedup check ──
      final rawReactionId =
          data['messageUuid']?.toString() ??
          data['reaction_id']?.toString() ??
          data['reactionId']?.toString() ??
          data['notification_id']?.toString() ??
          data['notificationId']?.toString() ??
          (reactedMessageId.isNotEmpty
              ? '${reactedMessageId}_$actorId'
              : fcmMessageId);

      final shouldShow = ChatEngineService.instance
          .markNotificationShownIfFirst(rawReactionId);
      if (!shouldShow) {
        debugPrint('🔕 [ReactionNotification] Already shown — skipping');
        return;
      }

      // ── Notification text ──
      // Prefer backend's body field ("Raju: hit emoji ❤️ to "Hello"")
      final backendBody = data['body']?.toString();
      final notificationText = (backendBody != null && backendBody.isNotEmpty)
          ? backendBody
          : (emoji.trim().isNotEmpty
                ? 'reacted ${emoji.trim()}'
                : 'reacted to a message');

      // ── Show local notification ──
      await NotificationLocalService.instance.showChatMessageNotification(
        notificationId:
            rawReactionId ?? fcmMessageId ?? DateTime.now().toString(),
        senderName: displayName,
        messageText: notificationText,
        conversationId: actorId,
        senderId: actorId,
        senderProfilePic: chatPictureUrl,
        messageType: 'reaction',
      );

      debugPrint(
        '✅ [ReactionNotification] Shown: $displayName $notificationText',
      );
    } catch (e) {
      debugPrint('❌ [ReactionNotification] Error: $e');
    }
  }

  /// Sync the reaction from FCM to local DB tables so it's available offline.
  static Future<void> _syncReactionToLocalDb({
    required String reactedMessageId,
    required String actorId,
    required String emoji,
    required String displayName,
    String? chatPictureUrl,
  }) async {
    try {
      final reactionsDb = MessageReactionsDatabaseService.instance;

      // Split display name into first/last
      final nameParts = displayName.split(' ');
      final firstName = nameParts.first;
      final lastName = nameParts.length > 1
          ? nameParts.sublist(1).join(' ')
          : null;

      final reaction = MessageReaction(
        id: '${reactedMessageId}_$actorId',
        messageId: reactedMessageId,
        userId: actorId,
        emoji: emoji,
        createdAt: DateTime.now(),
        userFirstName: firstName,
        userLastName: lastName,
        userChatPicture: chatPictureUrl,
        isSynced: true,
      );

      await reactionsDb.upsertReactions([reaction]);

      // Also update reactionsJson on the messages table for offline consistency
      final allReactions = await reactionsDb.getReactionsForMessage(
        reactedMessageId,
      );
      final reactionsJsonList = allReactions.map((r) => r.toJson()).toList();
      final reactionsJsonStr = reactionsJsonList.isEmpty
          ? ''
          : jsonEncode(reactionsJsonList);

      await MessagesTable.instance.updateMessageReactions(
        messageId: reactedMessageId,
        reactionsJson: reactionsJsonStr,
      );

      debugPrint(
        '✅ [ReactionNotification] Synced reaction to local DB: '
        '$emoji by $actorId on $reactedMessageId',
      );
    } catch (e) {
      debugPrint('⚠️ [ReactionNotification] DB sync error: $e');
    }
  }
}
