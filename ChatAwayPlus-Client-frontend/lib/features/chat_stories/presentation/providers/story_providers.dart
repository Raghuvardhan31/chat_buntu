import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chataway_plus/core/storage/token_storage.dart';
import 'package:chataway_plus/features/chat_stories/data/services/local/contacts_stories_local_db.dart';

import '../../data/repositories/story_repository.dart';
import '../../data/socket/story_socket_models.dart';
import 'story_state.dart';
import 'story_notifier.dart';

// ═══════════════════════════════════════════════════════════════════════════
// REPOSITORY PROVIDER
// ═══════════════════════════════════════════════════════════════════════════

/// Provider for the StoryRepository singleton
final storyRepositoryProvider = Provider<StoryRepository>((ref) {
  return StoryRepository.instance;
});

// ═══════════════════════════════════════════════════════════════════════════
// STREAM PROVIDERS
// ═══════════════════════════════════════════════════════════════════════════

/// Stream provider for new stories from contacts
final storyCreatedStreamProvider = StreamProvider<StoryCreatedEvent>((ref) {
  return StoryRepository.instance.storyCreatedStream;
});

/// Stream provider for story view events (when someone views my story)
final storyViewedStreamProvider = StreamProvider<StoryViewedEvent>((ref) {
  return StoryRepository.instance.storyViewedStream;
});

/// Stream provider for story deleted events
final storyDeletedStreamProvider = StreamProvider<StoryDeletedEvent>((ref) {
  return StoryRepository.instance.storyDeletedStream;
});

// ═══════════════════════════════════════════════════════════════════════════
// CONTACTS STORIES PROVIDER
// ═══════════════════════════════════════════════════════════════════════════

/// Provider for contacts stories with auto-fetch
final contactsStoriesProvider =
    StateNotifierProvider<ContactsStoriesNotifier, ContactsStoriesState>((ref) {
      final repository = ref.watch(storyRepositoryProvider);
      return ContactsStoriesNotifier(repository);
    });

// ═══════════════════════════════════════════════════════════════════════════
// NEW STORIES INDICATOR (for bottom nav bar dot)
// ═══════════════════════════════════════════════════════════════════════════

/// Provider that returns true when there are unviewed contact stories.
/// Used by the bottom navigation bar to show a notification dot on the
/// Stories tab icon (WhatsApp-style).
final hasNewStoriesProvider = Provider<bool>((ref) {
  final state = ref.watch(contactsStoriesProvider);
  return state.unviewedStories.isNotEmpty;
});

// ═══════════════════════════════════════════════════════════════════════════
// UNVIEWED STORIES USER IDS (for chat list avatar ring)
// ═══════════════════════════════════════════════════════════════════════════

/// Provider that returns a Set of user IDs who have unviewed stories.
/// Used by chat list tiles to show a stories ring gradient around avatars.
final unviewedStoriesUserIdsProvider = Provider<Set<String>>((ref) {
  final state = ref.watch(contactsStoriesProvider);
  return state.unviewedStories.map((g) => g.user.id).toSet();
});

// ═══════════════════════════════════════════════════════════════════════════
// MY STORIES PROVIDER
// ═══════════════════════════════════════════════════════════════════════════

/// Provider for my stories with auto-fetch
final myStoriesProvider =
    StateNotifierProvider<MyStoriesNotifier, MyStoriesState>((ref) {
      final repository = ref.watch(storyRepositoryProvider);
      return MyStoriesNotifier(repository);
    });

// ═══════════════════════════════════════════════════════════════════════════
// STORY VIEWERS PROVIDER
// ═══════════════════════════════════════════════════════════════════════════

/// Provider for fetching story viewers (family provider for storyId)
final storyViewersProvider =
    StateNotifierProvider.family<
      StoryViewersNotifier,
      StoryViewersState,
      String
    >((ref, storyId) {
      final repository = ref.watch(storyRepositoryProvider);
      return StoryViewersNotifier(repository, storyId);
    });

// ═══════════════════════════════════════════════════════════════════════════
// STORY VIEW ACTION PROVIDER
// ═══════════════════════════════════════════════════════════════════════════

/// Provider for marking a story as viewed
final markStoryViewedProvider =
    Provider.family<Future<bool> Function(), String>((ref, storyId) {
      final repository = ref.watch(storyRepositoryProvider);

      return () async {
        try {
          if (!repository.isConnected) {
            final currentUserId = await TokenSecureStorage.instance
                .getCurrentUserIdUUID();
            if (currentUserId != null && currentUserId.isNotEmpty) {
              await ContactsStoriesLocalDatabaseService.instance
                  .markAsViewedAndUpdateHasUnviewed(
                    currentUserId: currentUserId,
                    storyId: storyId,
                  );
              await repository.enqueuePendingViewedStoryId(storyId);
              await ref
                  .read(contactsStoriesProvider.notifier)
                  .reloadFromCache();
            }
            return true;
          }

          final response = await repository.markStoryViewed(storyId: storyId);
          final currentUserId = await TokenSecureStorage.instance
              .getCurrentUserIdUUID();
          if (currentUserId != null && currentUserId.isNotEmpty) {
            await ContactsStoriesLocalDatabaseService.instance
                .markAsViewedAndUpdateHasUnviewed(
                  currentUserId: currentUserId,
                  storyId: storyId,
                );
            if (!response.success) {
              await repository.enqueuePendingViewedStoryId(storyId);
            }
            await ref.read(contactsStoriesProvider.notifier).reloadFromCache();
          }
          return true;
        } catch (e) {
          if (kDebugMode) debugPrint('❌ markStoryViewed: Error - $e');
          try {
            final currentUserId = await TokenSecureStorage.instance
                .getCurrentUserIdUUID();
            if (currentUserId != null && currentUserId.isNotEmpty) {
              await ContactsStoriesLocalDatabaseService.instance
                  .markAsViewedAndUpdateHasUnviewed(
                    currentUserId: currentUserId,
                    storyId: storyId,
                  );
              await repository.enqueuePendingViewedStoryId(storyId);
              await ref
                  .read(contactsStoriesProvider.notifier)
                  .reloadFromCache();
              return true;
            }
          } catch (_) {}
          return false;
        }
      };
    });

// ═══════════════════════════════════════════════════════════════════════════
// COMBINED REFRESH PROVIDER
// ═══════════════════════════════════════════════════════════════════════════

/// Provider to refresh all story data
final refreshAllStoriesProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    await Future.wait([
      ref.read(contactsStoriesProvider.notifier).refresh(),
      ref.read(myStoriesProvider.notifier).refresh(),
    ]);
  };
});
