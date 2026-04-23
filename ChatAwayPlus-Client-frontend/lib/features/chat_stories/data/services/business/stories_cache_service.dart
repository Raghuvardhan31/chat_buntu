import 'package:flutter/foundation.dart';
import 'package:chataway_plus/core/storage/token_storage.dart';
import 'package:chataway_plus/features/chat_stories/data/repositories/story_repository.dart';
import 'package:chataway_plus/features/chat_stories/data/services/local/my_stories_local_db.dart';
import 'package:chataway_plus/features/chat_stories/data/services/local/contacts_stories_local_db.dart';
import 'package:chataway_plus/features/chat_stories/data/socket/story_socket_models.dart';

/// Service for managing stories with offline-first caching
/// Handles synchronization between local cache and server
class StoriesCacheService {
  static final StoriesCacheService _instance = StoriesCacheService._internal();
  factory StoriesCacheService() => _instance;
  StoriesCacheService._internal();

  static StoriesCacheService get instance => _instance;

  final StoryRepository _repository = StoryRepository.instance;
  final MyStoriesLocalDatabaseService _myStoriesLocalDb =
      MyStoriesLocalDatabaseService.instance;
  final ContactsStoriesLocalDatabaseService _contactsStoriesLocalDb =
      ContactsStoriesLocalDatabaseService.instance;

  String? _currentUserId;

  /// Initialize with current user ID
  Future<void> initialize() async {
    _currentUserId = await TokenSecureStorage.instance.getCurrentUserIdUUID();
    if (kDebugMode) {
      debugPrint('✅ StoriesCacheService: Initialized for user $_currentUserId');
    }
  }

  /// Get current user ID
  String? get currentUserId => _currentUserId;

  // ═══════════════════════════════════════════════════════════════════════════
  // MY STORIES (Current User)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get my stories - offline-first approach
  /// Returns cached data immediately, then fetches from server
  Future<List<StoryModel>> getMyStories({bool forceRefresh = false}) async {
    if (_currentUserId == null) await initialize();
    if (_currentUserId == null) return [];

    // 1. Return cached data first (instant UI)
    if (!forceRefresh) {
      final cached = await _myStoriesLocalDb.getMyStories(
        currentUserId: _currentUserId!,
      );
      if (cached.isNotEmpty) {
        if (kDebugMode) {
          debugPrint(
            '💾 [StoriesCacheService] Returning ${cached.length} cached my stories',
          );
        }
        // Fetch fresh data in background
        _refreshMyStoriesInBackground();
        return cached;
      }
    }

    // 2. Fetch from server
    return await _fetchAndCacheMyStories();
  }

  /// Fetch my stories from server and cache
  Future<List<StoryModel>> _fetchAndCacheMyStories() async {
    try {
      final response = await _repository.fetchMyStories();
      if (response.success) {
        final stories = response.storyList;

        // Cache the stories
        await _myStoriesLocalDb.cacheAllStories(
          currentUserId: _currentUserId!,
          stories: stories,
        );

        if (kDebugMode) {
          debugPrint(
            '🌐 [StoriesCacheService] Fetched and cached ${stories.length} my stories',
          );
        }
        return stories;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [StoriesCacheService] Error fetching my stories: $e');
      }
    }
    return [];
  }

  /// Refresh my stories in background (non-blocking)
  void _refreshMyStoriesInBackground() {
    _fetchAndCacheMyStories().catchError((e) {
      if (kDebugMode) {
        debugPrint('⚠️ [StoriesCacheService] Background refresh failed: $e');
      }
      return <StoryModel>[];
    });
  }

  /// Cache a newly created story
  Future<void> cacheNewStory(StoryModel story) async {
    if (_currentUserId == null) return;

    await _myStoriesLocalDb.cacheStory(
      currentUserId: _currentUserId!,
      story: story,
    );
  }

  /// Update views count for a story
  Future<void> updateStoryViewsCount({
    required String storyId,
    required int viewsCount,
  }) async {
    if (_currentUserId == null) return;

    await _myStoriesLocalDb.updateViewsCount(
      currentUserId: _currentUserId!,
      storyId: storyId,
      viewsCount: viewsCount,
    );
  }

  /// Delete a story from cache
  Future<void> deleteMyStory(String storyId) async {
    if (_currentUserId == null) return;

    await _myStoriesLocalDb.deleteStory(
      currentUserId: _currentUserId!,
      storyId: storyId,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CONTACTS STORIES
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get contacts stories - offline-first approach
  /// Returns cached data immediately, then fetches from server
  Future<List<UserStoriesGroup>> getContactsStories({
    bool forceRefresh = false,
  }) async {
    if (_currentUserId == null) await initialize();
    if (_currentUserId == null) return [];

    // 1. Return cached data first (instant UI)
    if (!forceRefresh) {
      final cached = await _contactsStoriesLocalDb.getContactsStories(
        currentUserId: _currentUserId!,
      );
      if (cached.isNotEmpty) {
        if (kDebugMode) {
          debugPrint(
            '💾 [StoriesCacheService] Returning ${cached.length} cached contacts stories',
          );
        }
        // Fetch fresh data in background
        _refreshContactsStoriesInBackground();
        return cached;
      }
    }

    // 2. Fetch from server
    return await _fetchAndCacheContactsStories();
  }

  /// Fetch contacts stories from server and cache
  Future<List<UserStoriesGroup>> _fetchAndCacheContactsStories() async {
    try {
      final response = await _repository.fetchContactsStories();
      if (response.success) {
        final storiesGroups =
            response.contactsStories.map((g) {
              final sortedStories = List<StoryModel>.from(g.stories)
                ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
              return UserStoriesGroup(
                user: g.user,
                stories: sortedStories,
                hasUnviewed: g.hasUnviewed,
              );
            }).toList()..sort((a, b) {
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

        // Cache the stories
        await _contactsStoriesLocalDb.cacheAllStories(
          currentUserId: _currentUserId!,
          storiesGroups: storiesGroups,
        );

        if (kDebugMode) {
          debugPrint(
            '🌐 [StoriesCacheService] Fetched and cached ${storiesGroups.length} contacts stories',
          );
        }
        return storiesGroups;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '❌ [StoriesCacheService] Error fetching contacts stories: $e',
        );
      }
    }
    return [];
  }

  /// Refresh contacts stories in background (non-blocking)
  void _refreshContactsStoriesInBackground() {
    _fetchAndCacheContactsStories().catchError((e) {
      if (kDebugMode) {
        debugPrint(
          '⚠️ [StoriesCacheService] Background contacts refresh failed: $e',
        );
      }
      return <UserStoriesGroup>[];
    });
  }

  /// Mark a story as viewed in local cache
  Future<void> markStoryAsViewed(String storyId) async {
    if (_currentUserId == null) return;

    await _contactsStoriesLocalDb.markAsViewed(
      currentUserId: _currentUserId!,
      storyId: storyId,
    );
  }

  /// Delete a contact's story from cache (when story expires or is deleted)
  Future<void> deleteContactStory(String storyId) async {
    if (_currentUserId == null) return;

    await _contactsStoriesLocalDb.deleteStory(
      currentUserId: _currentUserId!,
      storyId: storyId,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CLEANUP
  // ═══════════════════════════════════════════════════════════════════════════

  /// Delete expired stories from cache
  Future<void> cleanupExpiredStories() async {
    if (_currentUserId == null) return;

    await Future.wait([
      _myStoriesLocalDb.deleteExpiredStories(currentUserId: _currentUserId!),
      _contactsStoriesLocalDb.deleteExpiredStories(
        currentUserId: _currentUserId!,
      ),
    ]);

    if (kDebugMode) {
      debugPrint('🗑️ [StoriesCacheService] Cleaned up expired stories');
    }
  }

  /// Clear all cached stories (on logout)
  Future<void> clearAllCache() async {
    if (_currentUserId == null) return;

    await Future.wait([
      _myStoriesLocalDb.clearCache(currentUserId: _currentUserId!),
      _contactsStoriesLocalDb.clearCache(currentUserId: _currentUserId!),
    ]);

    if (kDebugMode) {
      debugPrint('🗑️ [StoriesCacheService] Cleared all stories cache');
    }
  }
}
