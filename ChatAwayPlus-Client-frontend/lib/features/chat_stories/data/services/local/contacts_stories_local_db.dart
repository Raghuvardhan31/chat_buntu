import 'package:flutter/foundation.dart';
import 'package:chataway_plus/core/database/tables/chat/contacts_stories_table.dart';
import 'package:chataway_plus/features/chat_stories/data/socket/story_socket_models.dart';

/// Local database service for contacts' stories
/// Provides offline-first caching for contacts stories
class ContactsStoriesLocalDatabaseService {
  static final ContactsStoriesLocalDatabaseService _instance =
      ContactsStoriesLocalDatabaseService._internal();
  factory ContactsStoriesLocalDatabaseService() => _instance;
  ContactsStoriesLocalDatabaseService._internal();

  static ContactsStoriesLocalDatabaseService get instance => _instance;

  /// Get all cached contacts stories grouped by user
  Future<List<UserStoriesGroup>> getContactsStories({
    required String currentUserId,
  }) async {
    try {
      final rows = await ContactsStoriesTable.getContactsStories(
        currentUserId: currentUserId,
      );

      // Group stories by owner
      final Map<String, List<Map<String, dynamic>>> grouped = {};
      final Map<String, Map<String, dynamic>> ownerInfo = {};

      for (final row in rows) {
        final ownerId = row['story_owner_id'] as String? ?? '';
        if (ownerId.isEmpty) continue;

        grouped.putIfAbsent(ownerId, () => []);
        grouped[ownerId]!.add(row);

        // Store owner info from first row
        if (!ownerInfo.containsKey(ownerId)) {
          ownerInfo[ownerId] = {
            'id': ownerId,
            'firstName': row['owner_first_name'],
            'lastName': row['owner_last_name'],
            'chatPicture': row['owner_chat_picture'],
            'mobileNumber': row['owner_mobile_number'],
          };
        }
      }

      // Convert to UserStoriesGroup list
      final groupsList = grouped.entries.map((entry) {
        final ownerId = entry.key;
        final storyRows = entry.value;
        final owner = ownerInfo[ownerId]!;

        final hasUnviewed = storyRows.any(
          (r) => (r['has_unviewed'] as int? ?? 0) == 1,
        );

        final stories = storyRows.map((r) => _rowToStoryModel(r)).toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

        return UserStoriesGroup(
          user: StoryUserInfo(
            id: owner['id'] as String? ?? '',
            firstName: owner['firstName'] as String? ?? '',
            lastName: owner['lastName'] as String? ?? '',
            chatPicture: owner['chatPicture'] as String?,
            mobileNumber: owner['mobileNumber'] as String?,
          ),
          stories: stories,
          hasUnviewed: hasUnviewed,
        );
      }).toList();

      groupsList.sort((a, b) {
        if (a.hasUnviewed != b.hasUnviewed) {
          return a.hasUnviewed ? -1 : 1;
        }
        final aTime = a.stories.isNotEmpty
            ? a.stories.last.createdAt
            : DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.stories.isNotEmpty
            ? b.stories.last.createdAt
            : DateTime.fromMillisecondsSinceEpoch(0);
        final cmp = bTime.compareTo(aTime);
        if (cmp != 0) return cmp;
        return a.user.id.compareTo(b.user.id);
      });

      return groupsList;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [ContactsStoriesLocalDB] getContactsStories error: $e');
      }
      return [];
    }
  }

  /// Get stories for a specific contact
  Future<List<StoryModel>> getStoriesForContact({
    required String currentUserId,
    required String contactId,
  }) async {
    try {
      final rows = await ContactsStoriesTable.getStoriesForContact(
        currentUserId: currentUserId,
        contactId: contactId,
      );

      return rows.map((r) => _rowToStoryModel(r)).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [ContactsStoriesLocalDB] getStoriesForContact error: $e');
      }
      return [];
    }
  }

  /// Cache all contacts stories (replaces existing cache)
  Future<void> cacheAllStories({
    required String currentUserId,
    required List<UserStoriesGroup> storiesGroups,
  }) async {
    try {
      final storiesWithOwner = storiesGroups.map((group) {
        return {
          'user': group.user.toJson(),
          'stories': group.stories.map((s) => s.toJson()).toList(),
          'hasUnviewed': group.hasUnviewed,
        };
      }).toList();

      await ContactsStoriesTable.replaceAllStories(
        currentUserId: currentUserId,
        storiesWithOwner: storiesWithOwner,
      );

      if (kDebugMode) {
        debugPrint(
          '✅ [ContactsStoriesLocalDB] Cached ${storiesGroups.length} contacts stories',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [ContactsStoriesLocalDB] cacheAllStories error: $e');
      }
    }
  }

  Future<void> upsertStory({
    required String currentUserId,
    required StoryUserInfo owner,
    required StoryModel story,
    required bool hasUnviewed,
  }) async {
    try {
      await ContactsStoriesTable.upsertStory(
        currentUserId: currentUserId,
        storyId: story.id,
        storyOwnerId: owner.id,
        ownerFirstName: owner.firstName,
        ownerLastName: owner.lastName,
        ownerChatPicture: owner.chatPicture,
        ownerMobileNumber: owner.mobileNumber,
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
        hasUnviewed: hasUnviewed,
        thumbnailUrl: story.thumbnailUrl,
        videoDuration: story.videoDuration,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [ContactsStoriesLocalDB] upsertStory error: $e');
      }
    }
  }

  /// Mark a story as viewed
  Future<void> markAsViewed({
    required String currentUserId,
    required String storyId,
  }) async {
    try {
      await ContactsStoriesTable.markAsViewed(
        currentUserId: currentUserId,
        storyId: storyId,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [ContactsStoriesLocalDB] markAsViewed error: $e');
      }
    }
  }

  Future<void> markAsViewedAndUpdateHasUnviewed({
    required String currentUserId,
    required String storyId,
  }) async {
    try {
      await ContactsStoriesTable.markAsViewedAndUpdateHasUnviewed(
        currentUserId: currentUserId,
        storyId: storyId,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '❌ [ContactsStoriesLocalDB] markAsViewedAndUpdateHasUnviewed error: $e',
        );
      }
    }
  }

  /// Delete a story from cache
  Future<void> deleteStory({
    required String currentUserId,
    required String storyId,
  }) async {
    try {
      await ContactsStoriesTable.deleteStory(
        currentUserId: currentUserId,
        storyId: storyId,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [ContactsStoriesLocalDB] deleteStory error: $e');
      }
    }
  }

  /// Delete all stories for a contact
  Future<void> deleteStoriesForContact({
    required String currentUserId,
    required String contactId,
  }) async {
    try {
      await ContactsStoriesTable.deleteStoriesForContact(
        currentUserId: currentUserId,
        contactId: contactId,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '❌ [ContactsStoriesLocalDB] deleteStoriesForContact error: $e',
        );
      }
    }
  }

  /// Delete expired stories from cache
  Future<void> deleteExpiredStories({required String currentUserId}) async {
    try {
      await ContactsStoriesTable.deleteExpiredStories(
        currentUserId: currentUserId,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [ContactsStoriesLocalDB] deleteExpiredStories error: $e');
      }
    }
  }

  /// Clear all cached stories
  Future<void> clearCache({required String currentUserId}) async {
    try {
      await ContactsStoriesTable.clearAllStories(currentUserId: currentUserId);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [ContactsStoriesLocalDB] clearCache error: $e');
      }
    }
  }

  /// Convert database row to StoryModel
  StoryModel _rowToStoryModel(Map<String, dynamic> row) {
    final createdAtMs = row['created_at'] as int? ?? 0;
    final updatedAtMs = row['updated_at'] as int? ?? 0;

    if (kDebugMode) {
      debugPrint(
        '📖 [ContactsStoriesLocalDB] Loading story: created_at=$createdAtMs, updated_at=$updatedAtMs',
      );
    }

    return StoryModel(
      id: row['story_id'] as String? ?? '',
      userId: row['story_owner_id'] as String? ?? '',
      mediaUrl: row['media_url'] as String? ?? '',
      mediaType: row['media_type'] as String? ?? 'image',
      caption: row['caption'] as String?,
      duration: row['duration'] as int? ?? 5,
      viewsCount: row['views_count'] as int? ?? 0,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(
        row['expires_at'] as int? ?? 0,
      ),
      backgroundColor: row['background_color'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtMs),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAtMs),
      isViewed: (row['is_viewed'] as int? ?? 0) == 1,
      thumbnailUrl: row['thumbnail_url'] as String?,
      videoDuration: (row['video_duration'] as num?)?.toDouble(),
      user: StoryUserInfo(
        id: row['story_owner_id'] as String? ?? '',
        firstName: row['owner_first_name'] as String? ?? '',
        lastName: row['owner_last_name'] as String? ?? '',
        chatPicture: row['owner_chat_picture'] as String?,
        mobileNumber: row['owner_mobile_number'] as String?,
      ),
    );
  }
}
