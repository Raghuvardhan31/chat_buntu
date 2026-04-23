import 'package:firebase_messaging/firebase_messaging.dart';

class StoriesNotificationHandler {
  static bool _hasAnyNonEmpty(Map<String, dynamic> data, List<String> keys) {
    for (final k in keys) {
      final v = data[k];
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isNotEmpty) return true;
    }
    return false;
  }

  static bool _looksLikeChatMessage(Map<String, dynamic> data) {
    final hasSender = _hasAnyNonEmpty(data, const <String>[
      'sender_id',
      'senderId',
      'fromUserId',
      'from_user_id',
      'from_user_id',
      'fromUserId',
      'actor_id',
      'actorId',
      'commenterId',
      'commenter_id',
      'replyFromUserId',
      'reply_from_user_id',
      'user_id',
      'userId',
    ]);
    if (!hasSender) return false;

    final hasMessageText = _hasAnyNonEmpty(data, const <String>[
      'messageText',
      'message',
      'text',
      'body',
      'comment',
      'commentText',
      'comment_text',
      'reply',
      'replyText',
      'reply_text',
    ]);

    final hasMedia = _hasAnyNonEmpty(data, const <String>[
      'fileUrl',
      'file_url',
      'imageUrl',
      'image_url',
      'videoUrl',
      'video_url',
      'mimeType',
      'mime_type',
      'messageType',
      'message_type',
    ]);

    return hasMessageText || hasMedia;
  }

  static bool looksLikeStoryChatNotification({
    required String type,
    required Map<String, dynamic> data,
  }) {
    final lower = type.toLowerCase();
    final isStoryType = lower.contains('story') || lower == 'stories_changed';
    final hasStoryId =
        data['storyId']?.toString().trim().isNotEmpty == true ||
        data['story_id']?.toString().trim().isNotEmpty == true;
    if (!isStoryType && !hasStoryId) return false;
    return _looksLikeChatMessage(data);
  }

  static Future<bool> tryHandle({
    required RemoteMessage message,
    required String type,
    required Future<void> Function(RemoteMessage message) handleAsChatMessage,
  }) async {
    final data = message.data;
    if (data.isEmpty) return false;
    if (!looksLikeStoryChatNotification(type: type, data: data)) {
      return false;
    }
    await handleAsChatMessage(message);
    return true;
  }
}
