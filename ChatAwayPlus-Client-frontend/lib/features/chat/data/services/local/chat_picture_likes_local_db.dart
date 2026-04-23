import 'package:chataway_plus/core/database/tables/chat/chat_picture_likes_table.dart';

class ChatPictureLikesDatabaseService {
  static final ChatPictureLikesDatabaseService _instance =
      ChatPictureLikesDatabaseService._internal();
  factory ChatPictureLikesDatabaseService() => _instance;
  ChatPictureLikesDatabaseService._internal();

  static ChatPictureLikesDatabaseService get instance => _instance;

  /// Max toggles allowed per picture (like + unlike = 4 toggles)
  static const int maxTogglesPerPicture = 4;

  Future<bool?> getLikeState({
    required String currentUserId,
    required String likedUserId,
    required String targetChatPictureId,
  }) {
    return ChatPictureLikesTable.getLikeState(
      currentUserId: currentUserId,
      likedUserId: likedUserId,
      targetChatPictureId: targetChatPictureId,
    );
  }

  Future<int> getToggleCount({
    required String currentUserId,
    required String likedUserId,
    required String targetChatPictureId,
  }) {
    return ChatPictureLikesTable.getToggleCount(
      currentUserId: currentUserId,
      likedUserId: likedUserId,
      targetChatPictureId: targetChatPictureId,
    );
  }

  Future<int> incrementToggleCount({
    required String currentUserId,
    required String likedUserId,
    required String targetChatPictureId,
  }) {
    return ChatPictureLikesTable.incrementToggleCount(
      currentUserId: currentUserId,
      likedUserId: likedUserId,
      targetChatPictureId: targetChatPictureId,
    );
  }

  /// Check if user can still toggle like (max 4 toggles per picture)
  Future<bool> canToggle({
    required String currentUserId,
    required String likedUserId,
    required String targetChatPictureId,
  }) async {
    final count = await getToggleCount(
      currentUserId: currentUserId,
      likedUserId: likedUserId,
      targetChatPictureId: targetChatPictureId,
    );
    return count < maxTogglesPerPicture;
  }

  Future<void> upsert({
    required String currentUserId,
    required String likedUserId,
    required String targetChatPictureId,
    required bool isLiked,
    String? likeId,
    int? likeCount,
    int? toggleCount,
  }) {
    return ChatPictureLikesTable.upsert(
      currentUserId: currentUserId,
      likedUserId: likedUserId,
      targetChatPictureId: targetChatPictureId,
      isLiked: isLiked,
      likeId: likeId,
      likeCount: likeCount,
      toggleCount: toggleCount,
    );
  }

  Future<void> clearForLikedUserId({
    required String currentUserId,
    required String likedUserId,
  }) {
    return ChatPictureLikesTable.clearForLikedUserId(
      currentUserId: currentUserId,
      likedUserId: likedUserId,
    );
  }
}
