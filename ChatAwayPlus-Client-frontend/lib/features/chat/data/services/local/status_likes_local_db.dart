import '../../../../../core/database/tables/chat/status_likes_table.dart';

/// Local database service for caching status like states
/// Provides offline-first functionality for status likes
class StatusLikesLocalDatabaseService {
  static final StatusLikesLocalDatabaseService _instance =
      StatusLikesLocalDatabaseService._internal();
  factory StatusLikesLocalDatabaseService() => _instance;
  StatusLikesLocalDatabaseService._internal();

  static StatusLikesLocalDatabaseService get instance => _instance;

  /// Max toggles allowed per status (like + unlike = 2 toggles)
  static const int maxTogglesPerStatus = 2;

  Future<bool?> getLikeState({
    required String currentUserId,
    required String statusId,
  }) {
    return StatusLikesTable.getLikeState(
      currentUserId: currentUserId,
      statusId: statusId,
    );
  }

  Future<int?> getLikeCount({
    required String currentUserId,
    required String statusId,
  }) {
    return StatusLikesTable.getLikeCount(
      currentUserId: currentUserId,
      statusId: statusId,
    );
  }

  Future<int> getToggleCount({
    required String currentUserId,
    required String statusId,
  }) {
    return StatusLikesTable.getToggleCount(
      currentUserId: currentUserId,
      statusId: statusId,
    );
  }

  Future<int> incrementToggleCount({
    required String currentUserId,
    required String statusId,
  }) {
    return StatusLikesTable.incrementToggleCount(
      currentUserId: currentUserId,
      statusId: statusId,
    );
  }

  /// Check if user can still toggle like (max 4 toggles per status)
  Future<bool> canToggle({
    required String currentUserId,
    required String statusId,
  }) async {
    final count = await getToggleCount(
      currentUserId: currentUserId,
      statusId: statusId,
    );
    return count < maxTogglesPerStatus;
  }

  Future<void> upsert({
    required String currentUserId,
    required String statusId,
    required bool isLiked,
    String? statusOwnerId,
    String? likeId,
    int? likeCount,
  }) {
    return StatusLikesTable.upsert(
      currentUserId: currentUserId,
      statusId: statusId,
      isLiked: isLiked,
      statusOwnerId: statusOwnerId,
      likeId: likeId,
      likeCount: likeCount,
    );
  }

  Future<void> clearForStatusOwnerId({
    required String currentUserId,
    required String statusOwnerId,
  }) {
    return StatusLikesTable.clearForStatusOwnerId(
      currentUserId: currentUserId,
      statusOwnerId: statusOwnerId,
    );
  }

  Future<void> clearAll({required String currentUserId}) {
    return StatusLikesTable.clearAll(currentUserId: currentUserId);
  }
}
