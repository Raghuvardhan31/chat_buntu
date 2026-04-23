import 'package:flutter/foundation.dart';
import 'package:chataway_plus/core/database/tables/chat/story_viewers_table.dart';
import 'package:chataway_plus/features/chat_stories/data/socket/story_socket_models.dart';

/// Local database service for story viewers
/// Provides offline-first caching for story viewers
class StoryViewersLocalDatabaseService {
  static final StoryViewersLocalDatabaseService _instance =
      StoryViewersLocalDatabaseService._internal();
  factory StoryViewersLocalDatabaseService() => _instance;
  StoryViewersLocalDatabaseService._internal();

  static StoryViewersLocalDatabaseService get instance => _instance;

  /// Get cached viewers for a story
  Future<List<StoryViewerInfo>> getViewersForStory({
    required String currentUserId,
    required String storyId,
  }) async {
    try {
      final rows = await StoryViewersTable.getViewersForStory(
        currentUserId: currentUserId,
        storyId: storyId,
      );

      return rows.map((row) => _rowToViewerInfo(row)).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [StoryViewersLocalDB] getViewersForStory error: $e');
      }
      return [];
    }
  }

  /// Get total viewer count for a story
  Future<int> getViewerCount({
    required String currentUserId,
    required String storyId,
  }) async {
    try {
      return await StoryViewersTable.getViewerCount(
        currentUserId: currentUserId,
        storyId: storyId,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [StoryViewersLocalDB] getViewerCount error: $e');
      }
      return 0;
    }
  }

  /// Cache viewers for a story (replaces existing cache)
  Future<void> cacheViewers({
    required String currentUserId,
    required String storyId,
    required List<StoryViewerInfo> viewers,
  }) async {
    try {
      final viewerMaps = viewers.map((v) => {
        'viewerId': v.viewer.id,
        'firstName': v.viewer.firstName,
        'lastName': v.viewer.lastName,
        'chatPicture': v.viewer.chatPicture,
        'mobileNumber': v.viewer.mobileNumber,
        'viewedAt': v.viewedAt.millisecondsSinceEpoch,
      }).toList();

      await StoryViewersTable.replaceViewersForStory(
        currentUserId: currentUserId,
        storyId: storyId,
        viewers: viewerMaps,
      );

      if (kDebugMode) {
        debugPrint(
          '✅ [StoryViewersLocalDB] Cached ${viewers.length} viewers for story: $storyId',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [StoryViewersLocalDB] cacheViewers error: $e');
      }
    }
  }

  /// Add a single viewer to cache
  Future<void> addViewer({
    required String currentUserId,
    required String storyId,
    required StoryViewerInfo viewer,
  }) async {
    try {
      await StoryViewersTable.upsertViewer(
        currentUserId: currentUserId,
        storyId: storyId,
        viewerId: viewer.viewer.id,
        viewerFirstName: viewer.viewer.firstName,
        viewerLastName: viewer.viewer.lastName,
        viewerChatPicture: viewer.viewer.chatPicture,
        viewerMobileNumber: viewer.viewer.mobileNumber,
        viewedAt: viewer.viewedAt,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [StoryViewersLocalDB] addViewer error: $e');
      }
    }
  }

  /// Delete viewers for a story
  Future<void> deleteViewersForStory({
    required String currentUserId,
    required String storyId,
  }) async {
    try {
      await StoryViewersTable.deleteViewersForStory(
        currentUserId: currentUserId,
        storyId: storyId,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [StoryViewersLocalDB] deleteViewersForStory error: $e');
      }
    }
  }

  /// Clear all cached viewers
  Future<void> clearCache({required String currentUserId}) async {
    try {
      await StoryViewersTable.clearAllViewers(currentUserId: currentUserId);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [StoryViewersLocalDB] clearCache error: $e');
      }
    }
  }

  /// Convert database row to StoryViewerInfo
  StoryViewerInfo _rowToViewerInfo(Map<String, dynamic> row) {
    return StoryViewerInfo(
      id: row['viewer_id'] as String? ?? '',
      viewedAt: DateTime.fromMillisecondsSinceEpoch(
        row['viewed_at'] as int? ?? 0,
      ),
      viewer: StoryUserInfo(
        id: row['viewer_id'] as String? ?? '',
        firstName: row['viewer_first_name'] as String? ?? '',
        lastName: row['viewer_last_name'] as String? ?? '',
        chatPicture: row['viewer_chat_picture'] as String?,
        mobileNumber: row['viewer_mobile_number'] as String?,
      ),
    );
  }
}
