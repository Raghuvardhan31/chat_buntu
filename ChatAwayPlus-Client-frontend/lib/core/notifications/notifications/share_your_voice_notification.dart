import 'package:flutter/foundation.dart';
import 'package:chataway_plus/core/notifications/local/notification_local_service.dart';
import 'package:chataway_plus/core/storage/token_storage.dart';
import 'package:chataway_plus/features/chat/data/services/chat_engine/index.dart';
import 'package:chataway_plus/features/chat/data/services/local/received_likes_local_db.dart';
import 'package:chataway_plus/features/chat/presentation/providers/chat_page_providers/notification_stream_provider.dart';

/// Unified handler for Status Like notifications (Share Your Voice Text likes).
///
/// FCM Payload Structure:
/// {
///   type: 'status_like',
///   likeId: 'like_uuid_456',
///   fromUserId: 'user_789',
///   fromUserName: 'John Doe',
///   fromUserProfilePic: 'https://s3.amazonaws.com/bucket/profile789.jpg',
///   toUserId: 'user_123',
///   statusId: 'status_uuid_123',
///   body: '❤ new Like on your SYVT Hello everyone! This is...',
///   title: 'New like on status'
/// }
class ShareYourVoiceNotificationHandler {
  const ShareYourVoiceNotificationHandler._();

  static Future<String> _resolveCurrentUserId(
    Map<String, dynamic> payload,
  ) async {
    final fromPayload =
        (payload['toUserId'] ??
                payload['to_user_id'] ??
                payload['statusOwnerId'] ??
                payload['status_owner_id'] ??
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

  /// Handle incoming status like FCM notification
  static Future<void> handle(Map<String, dynamic> data) async {
    try {
      debugPrint(
        '🔔 [FCM] Status like: ${data['fromUserName']} -> ${data['statusId']}',
      );

      final fromUserId =
          (data['fromUserId'] ?? data['from_user_id'] ?? data['userId'])
              ?.toString();
      if (fromUserId == null || fromUserId.isEmpty) {
        debugPrint('⚠️ [FCM] Status like missing fromUserId');
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
      final statusId = (data['statusId'] ?? data['status_id'])?.toString();
      final statusText =
          (data['statusText'] ??
                  data['status_text'] ??
                  data['body'] ??
                  data['message'] ??
                  data['messageText'] ??
                  data['text'])
              ?.toString();

      final message = statusText != null && statusText.trim().isNotEmpty
          ? statusText
          : 'Liked your status';

      final fromUserProfilePic =
          (data['sender_chat_picture'] ??
                  data['fromUserProfilePic'] ??
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
            likeType: 'voice',
            statusId: statusId,
            likeId: likeId,
            message: message,
          );
          if (kDebugMode) {
            debugPrint('✅ [StatusLike] Saved to Likes Hub');
          }
        }
      } catch (e) {
        debugPrint('⚠️ [StatusLike] Failed to save to Likes Hub: $e');
      }

      // Dedup check for notification UI display only
      final shouldShow = ChatEngineService.instance
          .markNotificationShownIfFirst(dedupKey);
      if (!shouldShow) {
        if (kDebugMode) {
          debugPrint(
            '🔕 [StatusLike] Already shown for this key - skipping UI',
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
      await NotificationLocalService.instance.showStatusLikeNotification(
        notificationId: likeId,
        fromUserId: fromUserId,
        fromUserName: fromUserName,
        statusId: statusId,
        statusText: statusText,
        fromUserProfilePic: fromUserProfilePic,
      );
    } catch (e) {
      debugPrint('❌ [FCM] Status like error: $e');
    }
  }

  /// Handle incoming status like WebSocket notification
  static Future<void> handleSocket(Map<String, dynamic> payload) async {
    try {
      final fromUserId = (payload['fromUserId'] ?? payload['from_user_id'])
          ?.toString();
      if (fromUserId == null || fromUserId.isEmpty) return;

      final likeId =
          (payload['likeId'] ??
                  payload['like_id'] ??
                  payload['notification_id'] ??
                  payload['notificationId'])
              ?.toString() ??
          '';
      final fromUserName =
          (payload['fromUserName'] ??
                  payload['from_user_name'] ??
                  payload['senderName'])
              ?.toString() ??
          'Someone';
      final statusId = (payload['statusId'] ?? payload['status_id'])
          ?.toString();
      final statusText =
          (payload['statusText'] ??
                  payload['status_text'] ??
                  payload['message'] ??
                  payload['messageText'] ??
                  payload['text'] ??
                  payload['body'])
              ?.toString();

      final fromUserProfilePic =
          (payload['sender_chat_picture'] ??
                  payload['fromUserProfilePic'] ??
                  payload['from_user_profile_pic'] ??
                  payload['from_user_chat_picture'] ??
                  payload['fromUserChatPicture'] ??
                  payload['profilePic'] ??
                  payload['profile_pic'] ??
                  payload['chatPictureUrl'] ??
                  payload['chat_picture'] ??
                  payload['chat_picture_url'] ??
                  payload['senderProfilePic'])
              ?.toString();

      final message = statusText != null && statusText.trim().isNotEmpty
          ? statusText
          : 'Liked your status';

      NotificationStreamController().notifyNewNotification(
        senderId: fromUserId,
        message: message,
      );

      await NotificationLocalService.instance.showStatusLikeNotification(
        notificationId: likeId.isNotEmpty ? likeId : DateTime.now().toString(),
        fromUserId: fromUserId,
        fromUserName: fromUserName,
        statusId: statusId,
        statusText: statusText,
        fromUserProfilePic: fromUserProfilePic,
      );

      // Save to received_likes table for Likes Hub
      try {
        final currentUserId = await _resolveCurrentUserId(payload);
        if (currentUserId.isNotEmpty) {
          await ReceivedLikesLocalDatabaseService.instance.saveLike(
            currentUserId: currentUserId,
            fromUserId: fromUserId,
            fromUserName: fromUserName,
            fromUserProfilePic: fromUserProfilePic,
            likeType: 'voice',
            statusId: statusId,
            likeId: likeId.isNotEmpty ? likeId : null,
            message: message,
          );
        }
      } catch (e) {
        debugPrint('⚠️ [StatusLike] Failed to save to Likes Hub: $e');
      }
    } catch (_) {}
  }

  /// Check if payload is a status like notification.
  /// Matches by explicit type OR by structural indicators (has statusId but
  /// no targetChatPictureId).
  static bool isShareYourVoiceNotification(Map<String, dynamic> payload) {
    final rawType = (payload['type'] ?? payload['notificationType'])
        ?.toString()
        .toLowerCase()
        .trim();

    // Explicit type match
    if (rawType == 'status_like' ||
        rawType == 'statuslike' ||
        rawType == 'status-like') {
      return true;
    }

    // Structural match: has statusId but NO targetChatPictureId
    // This catches backend payloads that omit the type field
    final statusId = (payload['statusId'] ?? payload['status_id'])?.toString();
    final targetChatPictureId =
        (payload['target_chat_picture_id'] ?? payload['targetChatPictureId'])
            ?.toString();
    if (statusId != null &&
        statusId.isNotEmpty &&
        (targetChatPictureId == null || targetChatPictureId.isEmpty)) {
      return true;
    }

    return false;
  }
}
