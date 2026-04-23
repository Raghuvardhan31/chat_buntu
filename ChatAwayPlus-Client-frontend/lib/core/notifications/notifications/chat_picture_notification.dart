import 'package:flutter/foundation.dart';
import 'package:chataway_plus/core/notifications/local/notification_local_service.dart';
import 'package:chataway_plus/core/storage/token_storage.dart';
import 'package:chataway_plus/features/chat/data/services/chat_engine/index.dart';
import 'package:chataway_plus/features/chat/data/services/local/received_likes_local_db.dart';
import 'package:chataway_plus/features/chat/presentation/providers/chat_page_providers/notification_stream_provider.dart';

/// Unified handler for Chat Picture Like notifications (both FCM and WebSocket).
///
/// FCM Payload Structure:
/// {
///   type: 'chat_picture_like',
///   likeId: 'like_uuid_456',
///   fromUserId: 'user_789',
///   fromUserName: 'John Doe',
///   fromUserProfilePic: 'https://s3.amazonaws.com/bucket/profile789.jpg',
///   toUserId: 'user_123',
///   targetChatPictureId: 'picture_uuid_123',
///   message: 'Liked your picture',
/// }
class ChatPictureNotificationHandler {
  const ChatPictureNotificationHandler._();

  static Future<String> _resolveCurrentUserId(
    Map<String, dynamic> payload,
  ) async {
    final fromPayload =
        (payload['toUserId'] ??
                payload['to_user_id'] ??
                payload['likedUserId'] ??
                payload['liked_user_id'] ??
                payload['targetUserId'] ??
                payload['target_user_id'] ??
                payload['userId'] ??
                payload['user_id'])
            ?.toString();
    if (fromPayload != null && fromPayload.trim().isNotEmpty) {
      return fromPayload.trim();
    }
    try {
      return await TokenSecureStorage.instance.getCurrentUserIdUUID() ?? '';
    } catch (_) {
      return '';
    }
  }

  /// Handle incoming chat picture like FCM notification
  static Future<void> handle(Map<String, dynamic> data) async {
    try {
      debugPrint(
        '� [FCM] Chat picture like: ${data['fromUserName']} -> ${data['target_chat_picture_id']}',
      );

      final dynamic rawIsLiked =
          data['isLiked'] ?? data['is_liked'] ?? data['liked'];
      bool? isLiked;
      if (rawIsLiked is bool) {
        isLiked = rawIsLiked;
      } else if (rawIsLiked is int) {
        isLiked = rawIsLiked == 1;
      } else if (rawIsLiked != null) {
        final s = rawIsLiked.toString().toLowerCase().trim();
        if (s == 'true' || s == '1' || s == 'yes' || s == 'liked') {
          isLiked = true;
        } else if (s == 'false' ||
            s == '0' ||
            s == 'no' ||
            s == 'unliked' ||
            s == 'unlike') {
          isLiked = false;
        }
      }
      final action = (data['action'] ?? data['status'])
          ?.toString()
          .toLowerCase();
      final looksUnlike = action == 'unliked' || action == 'unlike';
      if (looksUnlike || isLiked == false) return;

      final fromUserId =
          (data['fromUserId'] ?? data['from_user_id'] ?? data['userId'])
              ?.toString();
      if (fromUserId == null || fromUserId.isEmpty) {
        debugPrint('⚠️ [FCM] Chat picture like missing fromUserId');
        return;
      }

      final likeId =
          (data['likeId'] ??
                  data['like_id'] ??
                  data['notification_id'] ??
                  data['notificationId'])
              ?.toString() ??
          DateTime.now().toString();

      final dedupKey = '${likeId}_${DateTime.now().millisecondsSinceEpoch}';

      final fromUserName =
          (data['fromUserName'] ?? data['from_user_name'] ?? data['senderName'])
              ?.toString() ??
          'Someone';

      final targetChatPictureId =
          (data['target_chat_picture_id'] ?? data['targetChatPictureId'])
              ?.toString();

      final message =
          (data['message'] ??
                  data['messageText'] ??
                  data['text'] ??
                  data['body'])
              ?.toString() ??
          'Liked your picture';

      final fromUserProfilePic =
          (data['fromUserProfilePic'] ??
                  data['from_user_profile_pic'] ??
                  data['from_user_chat_picture'] ??
                  data['fromUserChatPicture'] ??
                  data['profilePic'] ??
                  data['profile_pic'] ??
                  data['chatPictureUrl'] ??
                  data['chat_picture'] ??
                  data['chat_picture_url'] ??
                  data['senderProfilePic'])
              ?.toString();

      // Save to received_likes table for Likes Hub FIRST (before dedup check)
      // This ensures likes are always saved even if notification UI is skipped
      try {
        final currentUserId = await _resolveCurrentUserId(data);
        if (currentUserId.isNotEmpty) {
          await ReceivedLikesLocalDatabaseService.instance.saveLike(
            currentUserId: currentUserId,
            fromUserId: fromUserId,
            fromUserName: fromUserName,
            fromUserProfilePic: fromUserProfilePic,
            likeType: 'chat_picture',
            statusId: targetChatPictureId,
            likeId: likeId,
            message: message,
          );
          if (kDebugMode) {
            debugPrint('✅ [ChatPictureLike] Saved to Likes Hub');
          }
        }
      } catch (e) {
        debugPrint('⚠️ [ChatPictureLike] Failed to save to Likes Hub: $e');
      }

      // Check suppression - don't show if user is viewing the liker's profile
      final activeWith = ChatEngineService.instance.activeConversationUserId;
      if (activeWith != null && activeWith == fromUserId) {
        if (kDebugMode) {
          debugPrint(
            '🔕 [ChatPictureLike] Suppressed - user viewing liker profile',
          );
        }
        return;
      }

      // Dedup check for notification UI display only
      final shouldShow = ChatEngineService.instance
          .markNotificationShownIfFirst(dedupKey);
      if (!shouldShow) {
        if (kDebugMode) {
          debugPrint(
            '🔕 [ChatPictureLike] Already shown for this key - skipping UI',
          );
        }
        return;
      }

      // Notify UI stream
      NotificationStreamController().notifyNewNotification(
        senderId: fromUserId,
        message: message,
      );

      // Show local notification
      await NotificationLocalService.instance.showChatPictureLikeNotification(
        notificationId: likeId,
        fromUserId: fromUserId,
        fromUserName: fromUserName,
        messageText: message,
        targetChatPictureId: targetChatPictureId,
        fromUserProfilePic: fromUserProfilePic,
      );

      if (kDebugMode) {
        debugPrint('✅ [ChatPictureLike] FCM notification shown');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [ChatPictureLike] FCM Error: $e');
      }
    }
  }

  static Future<void> handleSocket(Map<String, dynamic> payload) async {
    try {
      final fromUserId =
          (payload['fromUserId'] ??
                  payload['from_user_id'] ??
                  payload['userId'] ??
                  payload['user_id'] ??
                  payload['senderId'] ??
                  payload['sender_id'])
              ?.toString();
      final resolvedFromUserId = (fromUserId == null || fromUserId.isEmpty)
          ? 'unknown'
          : fromUserId;

      final dynamic rawIsLiked =
          payload['isLiked'] ?? payload['is_liked'] ?? payload['liked'];
      bool? isLiked;
      if (rawIsLiked is bool) {
        isLiked = rawIsLiked;
      } else if (rawIsLiked is int) {
        isLiked = rawIsLiked == 1;
      } else if (rawIsLiked != null) {
        final s = rawIsLiked.toString().toLowerCase().trim();
        if (s == 'true' || s == '1' || s == 'yes' || s == 'liked') {
          isLiked = true;
        } else if (s == 'false' ||
            s == '0' ||
            s == 'no' ||
            s == 'unliked' ||
            s == 'unlike') {
          isLiked = false;
        }
      }
      final action = (payload['action'] ?? payload['status'])
          ?.toString()
          .toLowerCase();
      final looksUnlike = action == 'unliked' || action == 'unlike';
      if (looksUnlike || isLiked == false) return;

      final likeId =
          (payload['likeId'] ??
                  payload['like_id'] ??
                  payload['notification_id'])
              ?.toString() ??
          '';
      final fromUserName =
          (payload['fromUserName'] ?? payload['from_user_name'])?.toString() ??
          'Someone';
      final targetChatPictureId =
          (payload['target_chat_picture_id'] ?? payload['targetChatPictureId'])
              ?.toString();
      final message =
          (payload['message'] ??
                  payload['messageText'] ??
                  payload['text'] ??
                  payload['body'])
              ?.toString() ??
          'Liked your picture';

      final fromUserProfilePic =
          (payload['fromUserProfilePic'] ??
                  payload['from_user_profile_pic'] ??
                  payload['from_user_chat_picture'] ??
                  payload['fromUserChatPicture'] ??
                  payload['profilePic'] ??
                  payload['profile_pic'] ??
                  payload['chatPictureUrl'] ??
                  payload['chat_picture'] ??
                  payload['chat_picture_url'])
              ?.toString();

      NotificationStreamController().notifyNewNotification(
        senderId: resolvedFromUserId,
        message: message,
      );

      await NotificationLocalService.instance.showChatPictureLikeNotification(
        notificationId: likeId.isNotEmpty ? likeId : DateTime.now().toString(),
        fromUserId: resolvedFromUserId,
        fromUserName: fromUserName,
        messageText: message,
        targetChatPictureId: targetChatPictureId,
        fromUserProfilePic: fromUserProfilePic,
      );
      // Save to received_likes table for Likes Hub
      try {
        final currentUserId = await _resolveCurrentUserId(payload);
        if (currentUserId.isNotEmpty) {
          await ReceivedLikesLocalDatabaseService.instance.saveLike(
            currentUserId: currentUserId,
            fromUserId: resolvedFromUserId,
            fromUserName: fromUserName,
            fromUserProfilePic: fromUserProfilePic,
            likeType: 'chat_picture',
            statusId: targetChatPictureId,
            likeId: likeId.isNotEmpty ? likeId : null,
            message: message,
          );
        }
      } catch (e) {
        debugPrint('⚠️ [ChatPictureLike] Failed to save to Likes Hub: $e');
      }

      if (kDebugMode) {
        debugPrint(
          '✅ [ChatPictureLike] Socket notification shown: $fromUserName',
        );
      }
    } catch (e) {
      debugPrint('❌ [ChatPictureNotification] Error: $e');
    }
  }

  /// Check if payload is a chat picture like notification (by type field)
  static bool isChatPictureLikeByType(Map<String, dynamic> payload) {
    final rawType =
        payload['type'] ??
        payload['notificationType'] ??
        payload['notification_type'] ??
        payload['eventType'] ??
        payload['event_type'];
    final type = rawType?.toString().toLowerCase().trim();
    if (type == null || type.isEmpty) return false;

    return type == 'chat_picture_like' ||
        type == 'chatpicturelike' ||
        type == 'picture_like' ||
        type == 'profile_picture_like' ||
        type == 'chat-picture-like' ||
        type.contains('chat_picture_like') ||
        (type.contains('picture') && type.contains('like'));
  }

  /// Check if payload is a chat picture notification (by type or structure)
  static bool isChatPictureNotification(Map<String, dynamic> payload) {
    // Explicitly exclude status_like (SYVT) payloads — they must NOT be
    // handled as chat picture notifications even if they contain fields
    // like likedUserId / action that the structural fallback would match.
    final rawType = (payload['type'] ?? payload['notificationType'])
        ?.toString()
        .toLowerCase()
        .trim();
    if (rawType == 'status_like' ||
        rawType == 'statuslike' ||
        rawType == 'status-like') {
      return false;
    }

    // Also exclude by structure: has statusId but no targetChatPictureId
    final statusId = (payload['statusId'] ?? payload['status_id'])?.toString();
    final targetChatPictureId =
        (payload['target_chat_picture_id'] ?? payload['targetChatPictureId'])
            ?.toString();
    if (statusId != null &&
        statusId.isNotEmpty &&
        (targetChatPictureId == null || targetChatPictureId.isEmpty)) {
      return false;
    }

    if (isChatPictureLikeByType(payload)) return true;

    final likedUserId = (payload['likedUserId'] ?? payload['liked_user_id'])
        ?.toString();
    final action = (payload['action'] ?? payload['status'])
        ?.toString()
        .toLowerCase();

    return targetChatPictureId != null &&
        targetChatPictureId.isNotEmpty &&
        likedUserId != null &&
        likedUserId.isNotEmpty &&
        action != null &&
        action.isNotEmpty;
  }
}
