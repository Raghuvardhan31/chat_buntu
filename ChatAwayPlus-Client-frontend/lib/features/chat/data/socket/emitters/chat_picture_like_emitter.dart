import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../socket_constants/socket_event_names.dart';

class ChatPictureLikeEmitter {
  const ChatPictureLikeEmitter();

  bool toggle({
    required io.Socket socket,
    required String likedUserId,
    required String targetChatPictureId,
    String? fromUserId,
    String? toUserId,
    bool? isLiked,
    String? action,
  }) {
    try {
      final payload = <String, dynamic>{
        'target_chat_picture_id': targetChatPictureId,
        'likedUserId': likedUserId,
      };
      if (kDebugMode) {
        debugPrint('📤 [ChatPictureLikeEmitter.toggle] payload=$payload');
      }
      socket.emit(SocketEventNames.toggleChatPictureLike, payload);
      return true;
    } catch (e) {
      debugPrint('❌ ChatPictureLikeEmitter.toggle failed: $e');
      return false;
    }
  }

  bool count({
    required io.Socket socket,
    required String likedUserId,
    required String targetChatPictureId,
  }) {
    try {
      final payload = <String, dynamic>{
        'likedUserId': likedUserId,
        'liked_user_id': likedUserId,
        'target_chat_picture_id': targetChatPictureId,
        'targetChatPictureId': targetChatPictureId,
      };
      socket.emit(SocketEventNames.getChatPictureLikeCount, payload);
      return true;
    } catch (e) {
      debugPrint('❌ ChatPictureLikeEmitter.count failed: $e');
      return false;
    }
  }

  bool likers({
    required io.Socket socket,
    required String likedUserId,
    required String targetChatPictureId,
    int? limit,
    int? offset,
  }) {
    try {
      final payload = <String, dynamic>{
        'likedUserId': likedUserId,
        'liked_user_id': likedUserId,
        'target_chat_picture_id': targetChatPictureId,
        'targetChatPictureId': targetChatPictureId,
        if (limit != null) 'limit': limit,
        if (offset != null) 'offset': offset,
      };
      socket.emit(SocketEventNames.getChatPictureLikers, payload);
      return true;
    } catch (e) {
      debugPrint('❌ ChatPictureLikeEmitter.likers failed: $e');
      return false;
    }
  }

  bool checkLikedStatus({
    required io.Socket socket,
    required String likedUserId,
    required String targetChatPictureId,
  }) {
    try {
      final payload = <String, dynamic>{
        'likedUserId': likedUserId,
        'liked_user_id': likedUserId,
        'target_chat_picture_id': targetChatPictureId,
        'targetChatPictureId': targetChatPictureId,
      };
      socket.emit(SocketEventNames.checkChatPictureLiked, payload);
      return true;
    } catch (e) {
      debugPrint('❌ ChatPictureLikeEmitter.checkLikedStatus failed: $e');
      return false;
    }
  }
}
