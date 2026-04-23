import 'package:flutter/foundation.dart';
import 'package:chataway_plus/core/database/tables/chat/my_stories_table.dart';
import 'package:chataway_plus/features/chat_stories/data/socket/story_socket_models.dart';

/// Local database service for current user's stories
/// Provides offline-first caching for my stories
class MyStoriesLocalDatabaseService {
  static final MyStoriesLocalDatabaseService _instance =
      MyStoriesLocalDatabaseService._internal();
  factory MyStoriesLocalDatabaseService() => _instance;
  MyStoriesLocalDatabaseService._internal();

  static MyStoriesLocalDatabaseService get instance => _instance;

  /// Get all cached stories for current user
  Future<List<StoryModel>> getMyStories({required String currentUserId}) async {
    try {
      final rows = await MyStoriesTable.getMyStories(
        currentUserId: currentUserId,
      );

      return rows.map((row) => _rowToStoryModel(row)).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [MyStoriesLocalDB] getMyStories error: $e');
      }
      return [];
    }
  }

  /// Cache a single story
  Future<void> cacheStory({
    required String currentUserId,
    required StoryModel story,
  }) async {
    try {
      await MyStoriesTable.upsertStory(
        currentUserId: currentUserId,
        storyId: story.id,
        mediaUrl: story.mediaUrl,
        mediaType: story.mediaType,
        caption: story.caption,
        duration: story.duration,
        viewsCount: story.viewsCount,
        expiresAt: story.expiresAt,
        backgroundColor: story.backgroundColor,
        createdAt: story.createdAt,
        updatedAt: story.updatedAt,
        isViewed: story.isViewed,
        thumbnailUrl: story.thumbnailUrl,
        videoDuration: story.videoDuration,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [MyStoriesLocalDB] cacheStory error: $e');
      }
    }
  }

  /// Cache all stories (replaces existing cache)
  Future<void> cacheAllStories({
    required String currentUserId,
    required List<StoryModel> stories,
  }) async {
    try {
      final storiesJson = stories.map((s) => s.toJson()).toList();
      await MyStoriesTable.replaceAllStories(
        currentUserId: currentUserId,
        stories: storiesJson,
      );

      if (kDebugMode) {
        debugPrint('✅ [MyStoriesLocalDB] Cached ${stories.length} stories');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [MyStoriesLocalDB] cacheAllStories error: $e');
      }
    }
  }

  /// Update views count for a story
  Future<void> updateViewsCount({
    required String currentUserId,
    required String storyId,
    required int viewsCount,
  }) async {
    try {
      await MyStoriesTable.updateViewsCount(
        currentUserId: currentUserId,
        storyId: storyId,
        viewsCount: viewsCount,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [MyStoriesLocalDB] updateViewsCount error: $e');
      }
    }
  }

  Future<int?> getViewsCount({
    required String currentUserId,
    required String storyId,
  }) async {
    try {
      final row = await MyStoriesTable.getStoryById(
        currentUserId: currentUserId,
        storyId: storyId,
      );
      if (row == null) return null;
      return row['views_count'] as int?;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [MyStoriesLocalDB] getViewsCount error: $e');
      }
      return null;
    }
  }

  /// Delete a story from cache
  Future<void> deleteStory({
    required String currentUserId,
    required String storyId,
  }) async {
    try {
      await MyStoriesTable.deleteStory(
        currentUserId: currentUserId,
        storyId: storyId,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [MyStoriesLocalDB] deleteStory error: $e');
      }
    }
  }

  /// Delete expired stories from cache
  Future<void> deleteExpiredStories({required String currentUserId}) async {
    try {
      await MyStoriesTable.deleteExpiredStories(currentUserId: currentUserId);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [MyStoriesLocalDB] deleteExpiredStories error: $e');
      }
    }
  }

  /// Clear all cached stories
  Future<void> clearCache({required String currentUserId}) async {
    try {
      await MyStoriesTable.clearAllStories(currentUserId: currentUserId);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [MyStoriesLocalDB] clearCache error: $e');
      }
    }
  }

  /// Convert database row to StoryModel
  StoryModel _rowToStoryModel(Map<String, dynamic> row) {
    return StoryModel(
      id: row['story_id'] as String? ?? '',
      userId: row['current_user_id'] as String? ?? '',
      mediaUrl: row['media_url'] as String? ?? '',
      mediaType: row['media_type'] as String? ?? 'image',
      caption: row['caption'] as String?,
      duration: row['duration'] as int? ?? 5,
      viewsCount: row['views_count'] as int? ?? 0,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(
        row['expires_at'] as int? ?? 0,
      ),
      backgroundColor: row['background_color'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        row['created_at'] as int? ?? 0,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        row['updated_at'] as int? ?? 0,
      ),
      isViewed: (row['is_viewed'] as int? ?? 0) == 1,
      thumbnailUrl: row['thumbnail_url'] as String?,
      videoDuration: (row['video_duration'] as num?)?.toDouble(),
    );
  }
}
