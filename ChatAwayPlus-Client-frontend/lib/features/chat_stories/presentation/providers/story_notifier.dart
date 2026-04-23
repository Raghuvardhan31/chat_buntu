import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chataway_plus/features/chat/data/services/chat_engine/index.dart';
import 'package:chataway_plus/core/constants/api_url/api_urls.dart';
import 'package:chataway_plus/core/storage/token_storage.dart';
import 'package:chataway_plus/core/sync/authenticated_image_cache_manager.dart';
import 'package:chataway_plus/features/chat_stories/data/services/business/stories_cache_service.dart';
import 'package:chataway_plus/features/chat_stories/data/services/local/contacts_stories_local_db.dart';
import 'package:chataway_plus/features/chat_stories/data/services/local/my_stories_local_db.dart';
import 'package:chataway_plus/features/chat_stories/data/services/local/story_viewers_local_db.dart';
import 'package:chataway_plus/features/chat_stories/data/services/sync/stories_fcm_sync_service.dart';

import '../../data/repositories/story_repository.dart';
import '../../data/socket/story_socket_models.dart';
import 'story_state.dart';

// ═══════════════════════════════════════════════════════════════════════════
// CONTACTS STORIES NOTIFIER
// ═══════════════════════════════════════════════════════════════════════════

/// Notifier for contacts stories
class ContactsStoriesNotifier extends StateNotifier<ContactsStoriesState> {
  void _safeSetState(ContactsStoriesState s) {
    if (mounted) state = s;
  }

  ContactsStoriesNotifier(this._repository)
    : super(const ContactsStoriesState()) {
    // Ensure repository is initialized
    _repository.initialize();
    _subscription = _repository.contactsStoriesStream.listen(_onStoriesUpdate);
    _setupConnectionListener();

    Future.microtask(_loadFromCache);
    _fcmSubscription = StoriesFcmSyncService.instance.changesStream.listen((
      event,
    ) {
      final scope = event['scope']?.toString();
      if (scope == 'contacts' || scope == 'all') {
        Future.microtask(_loadFromCache);
      }
    });
  }

  final StoryRepository _repository;
  StreamSubscription<List<UserStoriesGroup>>? _subscription;
  StreamSubscription<bool>? _connectionSubscription;
  StreamSubscription<Map<String, dynamic>>? _fcmSubscription;
  bool _hasFetched = false;

  final TokenSecureStorage _tokenStorage = TokenSecureStorage.instance;
  final ContactsStoriesLocalDatabaseService _localDb =
      ContactsStoriesLocalDatabaseService.instance;

  Future<List<UserStoriesGroup>> _filterOutCurrentUserStories(
    List<UserStoriesGroup> stories,
  ) async {
    final currentUserId = await _tokenStorage.getCurrentUserIdUUID();
    if (currentUserId == null || currentUserId.isEmpty) {
      return stories;
    }
    return stories.where((g) => g.user.id != currentUserId).toList();
  }

  void _setupConnectionListener() {
    // Check if already connected
    if (ChatEngineService.instance.isOnline) {
      state = state.copyWith(isLoading: true, error: null);
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) fetch();
      });
    }

    _connectionSubscription = ChatEngineService.instance.connectionStream
        .listen((isConnected) {
          if (isConnected && !_hasFetched) {
            // Set loading state while waiting for socket to be ready
            state = state.copyWith(isLoading: true, error: null);
            // Wait a bit for socket to be fully ready
            Future.delayed(const Duration(milliseconds: 800), () {
              if (mounted) fetch();
            });
          }
        });
  }

  void _onStoriesUpdate(List<UserStoriesGroup> stories) {
    Future.microtask(() async {
      final filteredStories = await _filterOutCurrentUserStories(stories);
      if (filteredStories.isEmpty) {
        // If we've already fetched from server once, an empty list means the
        // server genuinely has no stories — update state to empty instead of
        // falling back to stale cache data.
        if (_hasFetched) {
          _safeSetState(
            state.copyWith(
              stories: const [],
              isLoading: false,
              lastUpdated: DateTime.now(),
            ),
          );
          return;
        }
        // First load — cache fallback while waiting for server
        Future.microtask(_loadFromCache);
        return;
      }

      final normalized =
          filteredStories.map((g) {
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

      _safeSetState(
        state.copyWith(
          stories: normalized,
          isLoading: false,
          lastUpdated: DateTime.now(),
        ),
      );

      Future.microtask(() async {
        final currentUserId = await _tokenStorage.getCurrentUserIdUUID();
        if (currentUserId == null || currentUserId.isEmpty) return;
        await _localDb.cacheAllStories(
          currentUserId: currentUserId,
          storiesGroups: normalized,
        );

        // IMPORTANT: Apply locally-viewed state to UI after reconnect.
        // The DB merge logic preserves offline views even if the server hasn't
        // processed them yet. Reloading from cache prevents viewed stories from
        // reappearing in the "Latest Stories" section after coming back online.
        await _loadFromCache();

        await StoriesCacheService.instance.initialize();
        await StoriesCacheService.instance.cleanupExpiredStories();
        await _prefetchStoryMedia(normalized);
      });
    });
  }

  Future<void> _prefetchStoryMedia(List<UserStoriesGroup> stories) async {
    if (!ChatEngineService.instance.isOnline) return;

    // Collect all media URLs to prefetch (thumbnails, images, AND video files)
    final urlsToCache = <String>[];

    for (final group in stories) {
      if (group.stories.isEmpty) continue;

      for (final story in group.stories) {
        if (story.mediaType == 'video') {
          // Video story: cache both thumbnail and video file
          if (story.thumbnailUrl != null &&
              story.thumbnailUrl!.trim().isNotEmpty) {
            urlsToCache.add(_normalizeStoryMediaUrl(story.thumbnailUrl!));
          }
          if (story.mediaUrl.trim().isNotEmpty) {
            urlsToCache.add(_normalizeStoryMediaUrl(story.mediaUrl));
          }
        } else {
          // Image story: cache the image
          if (story.mediaUrl.trim().isNotEmpty) {
            urlsToCache.add(_normalizeStoryMediaUrl(story.mediaUrl));
          }
        }
      }
    }

    // Download all uncached files in background
    for (final fullUrl in urlsToCache) {
      try {
        final cached = await AuthenticatedImageCacheManager.instance
            .getFileFromCache(fullUrl);
        if (cached?.file == null) {
          final fileInfo = await AuthenticatedImageCacheManager.instance
              .downloadFile(fullUrl);
          // Validate downloaded file — remove if corrupt/empty (< 1KB for video)
          final fileSize = await File(fileInfo.file.path).length();
          if (fileSize < 1024 && fullUrl.contains('.mp4')) {
            await AuthenticatedImageCacheManager.instance.removeFile(fullUrl);
          }
        }
      } catch (_) {
        // Download failed — remove any partial cache entry
        try {
          await AuthenticatedImageCacheManager.instance.removeFile(fullUrl);
        } catch (_) {}
      }
    }
  }

  String _normalizeStoryMediaUrl(String imageUrl) {
    final raw = imageUrl.trim();
    if (raw.isEmpty) return raw;

    String stripBucket(String input) {
      final hadLeadingSlash = input.startsWith('/');
      final s = hadLeadingSlash ? input.substring(1) : input;
      if (s.startsWith('dev.chatawayplus/')) {
        final rest = s.substring('dev.chatawayplus/'.length);
        return hadLeadingSlash ? '/$rest' : rest;
      }
      if (s.startsWith('chatawayplus/')) {
        final rest = s.substring('chatawayplus/'.length);
        return hadLeadingSlash ? '/$rest' : rest;
      }
      final firstSlash = s.indexOf('/');
      if (firstSlash > 0) {
        final firstSeg = s.substring(0, firstSlash);
        final rest = s.substring(firstSlash + 1);
        if (firstSeg.contains('.') && rest.startsWith('stories/')) {
          return hadLeadingSlash ? '/$rest' : rest;
        }
      }
      const prefix = '/api/images/stream/';
      if (input.contains(prefix)) {
        final idx = input.indexOf(prefix);
        final before = input.substring(0, idx + prefix.length);
        final after = input.substring(idx + prefix.length);
        if (after.startsWith('dev.chatawayplus/')) {
          return before + after.substring('dev.chatawayplus/'.length);
        }
        if (after.startsWith('chatawayplus/')) {
          return before + after.substring('chatawayplus/'.length);
        }
      }
      return input;
    }

    final fixed = stripBucket(raw);
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return fixed;
    }
    if (fixed.startsWith('/')) {
      if (fixed.startsWith('/api/') || fixed.startsWith('/uploads/')) {
        return '${ApiUrls.mediaBaseUrl}$fixed';
      }
      return '${ApiUrls.mediaBaseUrl}/api/images/stream/${fixed.substring(1)}';
    }
    if (fixed.startsWith('api/') || fixed.startsWith('uploads/')) {
      return '${ApiUrls.mediaBaseUrl}/$fixed';
    }
    return '${ApiUrls.mediaBaseUrl}/api/images/stream/$fixed';
  }

  Future<void> _loadFromCache() async {
    final currentUserId = await _tokenStorage.getCurrentUserIdUUID();
    if (currentUserId == null || currentUserId.isEmpty) return;

    await StoriesCacheService.instance.initialize();
    await StoriesCacheService.instance.cleanupExpiredStories();
    final cached = await _localDb.getContactsStories(
      currentUserId: currentUserId,
    );

    final filteredCached = cached
        .where((g) => g.user.id != currentUserId)
        .toList();

    filteredCached.sort((a, b) {
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

    _safeSetState(
      state.copyWith(
        stories: filteredCached,
        isLoading: false,
        error: null,
        lastUpdated: DateTime.now(),
      ),
    );
  }

  int _fetchRetryCount = 0;
  static const int _maxFetchRetries = 3;

  /// Fetch contacts stories from server
  Future<void> fetch() async {
    // Check if connected first
    if (!_repository.isConnected) {
      await _loadFromCache();
      return;
    }

    _safeSetState(state.copyWith(isLoading: true, error: null));

    try {
      final response = await _repository.fetchContactsStories();
      _hasFetched = true;
      _fetchRetryCount = 0;
      if (!response.success) {
        // Server returned failure — fall back to cache
        await _loadFromCache();
        // Only show error if cache is also empty
        if (state.stories.isEmpty) {
          _safeSetState(
            state.copyWith(
              isLoading: false,
              error: response.error ?? 'Failed to fetch stories',
            ),
          );
        }
      }
      // Success is handled via stream
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ ContactsStoriesNotifier: Error fetching - $e');
      }
      // Fall back to cache so user sees cached stories instead of error
      await _loadFromCache();
      // Auto-retry with backoff if socket wasn't ready
      if (_fetchRetryCount < _maxFetchRetries && mounted) {
        _fetchRetryCount++;
        final delay = Duration(seconds: _fetchRetryCount * 2);
        if (kDebugMode) {
          debugPrint(
            '🔄 ContactsStoriesNotifier: Retry $_fetchRetryCount/$_maxFetchRetries in ${delay.inSeconds}s',
          );
        }
        Future.delayed(delay, () {
          if (mounted && !_hasFetched) fetch();
        });
      } else if (state.stories.isEmpty) {
        // Only show error if cache is also empty and retries exhausted
        _safeSetState(state.copyWith(isLoading: false, error: e.toString()));
      }
    }
  }

  /// Refresh stories
  Future<void> refresh() {
    _hasFetched = false;
    _fetchRetryCount = 0;
    return fetch();
  }

  Future<void> reloadFromCache() => _loadFromCache();

  @override
  void dispose() {
    _subscription?.cancel();
    _connectionSubscription?.cancel();
    _fcmSubscription?.cancel();
    super.dispose();
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// MY STORIES NOTIFIER
// ═══════════════════════════════════════════════════════════════════════════

/// Notifier for my stories
class MyStoriesNotifier extends StateNotifier<MyStoriesState> {
  void _safeSetState(MyStoriesState s) {
    if (mounted) state = s;
  }

  MyStoriesNotifier(this._repository) : super(const MyStoriesState()) {
    // Ensure repository is initialized
    _repository.initialize();
    _subscription = _repository.myStoriesStream.listen(_onStoriesUpdate);
    _setupConnectionListener();

    Future.microtask(_loadFromCache);
    _fcmSubscription = StoriesFcmSyncService.instance.changesStream.listen((
      event,
    ) {
      final scope = event['scope']?.toString();
      if (scope == 'my' || scope == 'all') {
        Future.microtask(_loadFromCache);
      }
    });
  }

  final StoryRepository _repository;
  StreamSubscription<List<StoryModel>>? _subscription;
  StreamSubscription<bool>? _connectionSubscription;
  StreamSubscription<Map<String, dynamic>>? _fcmSubscription;
  bool _hasFetched = false;

  final TokenSecureStorage _tokenStorage = TokenSecureStorage.instance;
  final MyStoriesLocalDatabaseService _localDb =
      MyStoriesLocalDatabaseService.instance;
  final StoryViewersLocalDatabaseService _viewersLocalDb =
      StoryViewersLocalDatabaseService.instance;
  final Map<String, int> _lastPrefetchedViewsCountByStoryId = {};

  void _setupConnectionListener() {
    // Check if already connected
    if (ChatEngineService.instance.isOnline) {
      _safeSetState(state.copyWith(isLoading: true, error: null));
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) fetch();
      });
    }

    _connectionSubscription = ChatEngineService.instance.connectionStream
        .listen((isConnected) {
          if (isConnected && !_hasFetched) {
            // Set loading state while waiting for socket to be ready
            _safeSetState(state.copyWith(isLoading: true, error: null));
            // Wait a bit for socket to be fully ready
            Future.delayed(const Duration(milliseconds: 800), () {
              if (mounted) fetch();
            });
          }
        });
  }

  void _onStoriesUpdate(List<StoryModel> stories) {
    _safeSetState(
      state.copyWith(
        stories: stories,
        isLoading: false,
        lastUpdated: DateTime.now(),
      ),
    );

    Future.microtask(() async {
      final currentUserId = await _tokenStorage.getCurrentUserIdUUID();
      if (currentUserId == null || currentUserId.isEmpty) return;
      await _localDb.cacheAllStories(
        currentUserId: currentUserId,
        stories: stories,
      );
      await StoriesCacheService.instance.initialize();
      await StoriesCacheService.instance.cleanupExpiredStories();
      await _prefetchViewersForStories(
        currentUserId: currentUserId,
        stories: stories,
      );
      await _prefetchMyStoryMedia(stories);
    });
  }

  Future<void> _prefetchMyStoryMedia(List<StoryModel> stories) async {
    if (!ChatEngineService.instance.isOnline) return;

    for (final story in stories) {
      if (story.mediaType == 'video') {
        // Cache both thumbnail and video file
        if (story.thumbnailUrl != null &&
            story.thumbnailUrl!.trim().isNotEmpty) {
          final thumbUrl = _normalizeMyStoryMediaUrl(story.thumbnailUrl!);
          try {
            final cached = await AuthenticatedImageCacheManager.instance
                .getFileFromCache(thumbUrl);
            if (cached?.file == null) {
              await AuthenticatedImageCacheManager.instance.downloadFile(
                thumbUrl,
              );
            }
          } catch (_) {}
        }
        if (story.mediaUrl.trim().isNotEmpty) {
          final videoUrl = _normalizeMyStoryMediaUrl(story.mediaUrl);
          try {
            final cached = await AuthenticatedImageCacheManager.instance
                .getFileFromCache(videoUrl);
            if (cached?.file == null) {
              await AuthenticatedImageCacheManager.instance.downloadFile(
                videoUrl,
              );
            }
          } catch (_) {}
        }
      } else {
        // Image story: cache the image
        if (story.mediaUrl.trim().isNotEmpty) {
          final imageUrl = _normalizeMyStoryMediaUrl(story.mediaUrl);
          try {
            final cached = await AuthenticatedImageCacheManager.instance
                .getFileFromCache(imageUrl);
            if (cached?.file == null) {
              await AuthenticatedImageCacheManager.instance.downloadFile(
                imageUrl,
              );
            }
          } catch (_) {}
        }
      }
    }
  }

  String _normalizeMyStoryMediaUrl(String url) {
    final raw = url.trim();
    if (raw.isEmpty) return raw;

    String stripBucket(String input) {
      final hadLeadingSlash = input.startsWith('/');
      final s = hadLeadingSlash ? input.substring(1) : input;
      if (s.startsWith('dev.chatawayplus/')) {
        final rest = s.substring('dev.chatawayplus/'.length);
        return hadLeadingSlash ? '/$rest' : rest;
      }
      if (s.startsWith('chatawayplus/')) {
        final rest = s.substring('chatawayplus/'.length);
        return hadLeadingSlash ? '/$rest' : rest;
      }
      final firstSlash = s.indexOf('/');
      if (firstSlash > 0) {
        final firstSeg = s.substring(0, firstSlash);
        final rest = s.substring(firstSlash + 1);
        if (firstSeg.contains('.') && rest.startsWith('stories/')) {
          return hadLeadingSlash ? '/$rest' : rest;
        }
      }
      const prefix = '/api/images/stream/';
      if (input.contains(prefix)) {
        final idx = input.indexOf(prefix);
        final before = input.substring(0, idx + prefix.length);
        final after = input.substring(idx + prefix.length);
        if (after.startsWith('dev.chatawayplus/')) {
          return before + after.substring('dev.chatawayplus/'.length);
        }
        if (after.startsWith('chatawayplus/')) {
          return before + after.substring('chatawayplus/'.length);
        }
      }
      return input;
    }

    final fixed = stripBucket(raw);

    if (fixed.startsWith('http://') || fixed.startsWith('https://')) {
      return fixed;
    }
    if (fixed.startsWith('/')) {
      if (fixed.startsWith('/api/') || fixed.startsWith('/uploads/')) {
        return '${ApiUrls.mediaBaseUrl}$fixed';
      }
      return '${ApiUrls.mediaBaseUrl}/api/images/stream/${fixed.substring(1)}';
    }
    if (fixed.startsWith('api/') || fixed.startsWith('uploads/')) {
      return '${ApiUrls.mediaBaseUrl}/$fixed';
    }
    return '${ApiUrls.mediaBaseUrl}/api/images/stream/$fixed';
  }

  Future<void> _prefetchViewersForStories({
    required String currentUserId,
    required List<StoryModel> stories,
  }) async {
    if (!_repository.isConnected) return;

    for (final story in stories) {
      final viewsCount = story.viewsCount;
      if (viewsCount <= 0) continue;

      final lastPrefetched = _lastPrefetchedViewsCountByStoryId[story.id];
      if (lastPrefetched != null && lastPrefetched == viewsCount) {
        continue;
      }

      try {
        final response = await _repository.getStoryViewers(storyId: story.id);
        if (!response.success) continue;

        final viewers = response.viewers ?? const <StoryViewerInfo>[];
        final serverTotalViews = response.totalViews ?? viewers.length;

        // Avoid wiping cached viewers if server says there are views
        // but doesn't provide any viewer rows.
        if (serverTotalViews > 0 && viewers.isEmpty) {
          continue;
        }

        await _viewersLocalDb.cacheViewers(
          currentUserId: currentUserId,
          storyId: story.id,
          viewers: viewers,
        );

        _lastPrefetchedViewsCountByStoryId[story.id] = viewsCount;
      } catch (_) {
        // ignore
      }
    }
  }

  Future<void> _loadFromCache() async {
    final currentUserId = await _tokenStorage.getCurrentUserIdUUID();
    if (currentUserId == null || currentUserId.isEmpty) return;

    await StoriesCacheService.instance.initialize();
    await StoriesCacheService.instance.cleanupExpiredStories();
    final cached = await _localDb.getMyStories(currentUserId: currentUserId);

    _safeSetState(
      state.copyWith(
        stories: cached,
        isLoading: false,
        error: null,
        lastUpdated: DateTime.now(),
      ),
    );
  }

  int _fetchRetryCount = 0;
  static const int _maxFetchRetries = 3;

  /// Fetch my stories from server
  Future<void> fetch() async {
    // Check if connected first
    if (!_repository.isConnected) {
      await _loadFromCache();
      return;
    }

    _safeSetState(state.copyWith(isLoading: true, error: null));

    try {
      final response = await _repository.fetchMyStories();
      _hasFetched = true;
      _fetchRetryCount = 0;
      if (!response.success) {
        // Server returned failure — fall back to cache
        await _loadFromCache();
        // Only show error if cache is also empty
        if (state.stories.isEmpty) {
          _safeSetState(
            state.copyWith(
              isLoading: false,
              error: response.error ?? 'Failed to fetch my stories',
            ),
          );
        }
      }
      // Success is handled via stream
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ MyStoriesNotifier: Error fetching - $e');
      }
      // Fall back to cache so user sees cached stories instead of error
      await _loadFromCache();
      // Auto-retry with backoff if socket wasn't ready
      if (_fetchRetryCount < _maxFetchRetries && mounted) {
        _fetchRetryCount++;
        final delay = Duration(seconds: _fetchRetryCount * 2);
        if (kDebugMode) {
          debugPrint(
            '🔄 MyStoriesNotifier: Retry $_fetchRetryCount/$_maxFetchRetries in ${delay.inSeconds}s',
          );
        }
        Future.delayed(delay, () {
          if (mounted && !_hasFetched) fetch();
        });
      } else if (state.stories.isEmpty) {
        // Only show error if cache is also empty and retries exhausted
        _safeSetState(state.copyWith(isLoading: false, error: e.toString()));
      }
    }
  }

  /// Create a new story
  Future<bool> createStory({
    required File mediaFile,
    File? thumbnailFile,
    String? caption,
    int? duration,
    String? backgroundColor,
  }) async {
    try {
      _safeSetState(state.copyWith(isLoading: true, error: null));

      final response = await _repository.createStory(
        mediaFile: mediaFile,
        thumbnailFile: thumbnailFile,
        caption: caption,
        duration: duration,
        backgroundColor: backgroundColor,
      );

      if (!response.success) {
        _safeSetState(
          state.copyWith(
            isLoading: false,
            error: response.error ?? 'Failed to create story',
          ),
        );
        return false;
      }

      // Pre-seed local cache so the user can view their own story instantly
      // without re-downloading from the server.
      _preSeedCacheFromLocalFile(response.story, mediaFile, thumbnailFile);

      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ MyStoriesNotifier: Error creating story - $e');
      }
      _safeSetState(state.copyWith(isLoading: false, error: e.toString()));
      return false;
    }
  }

  /// Pre-seed the authenticated cache with the local file under the server URL
  /// so StoryVideoPlayer / CachedNetworkImage gets an instant cache hit.
  void _preSeedCacheFromLocalFile(
    StoryModel? story,
    File mediaFile,
    File? thumbnailFile,
  ) {
    if (story == null) return;

    Future<void> seed() async {
      try {
        final cacheManager = AuthenticatedImageCacheManager.instance;

        // Cache the main media file (video or image)
        if (story.mediaUrl.trim().isNotEmpty) {
          final fullUrl = _normalizeMyStoryMediaUrl(story.mediaUrl);
          final bytes = await mediaFile.readAsBytes();
          final ext = mediaFile.path.split('.').last.toLowerCase();
          final fileExtension = ext.isNotEmpty ? '.$ext' : '.mp4';
          await cacheManager.putFile(
            fullUrl,
            bytes,
            fileExtension: fileExtension,
          );
          if (kDebugMode) {
            debugPrint('✅ Pre-seeded cache for story media: $fullUrl');
          }
        }

        // Cache the thumbnail if present
        if (thumbnailFile != null &&
            story.thumbnailUrl != null &&
            story.thumbnailUrl!.trim().isNotEmpty) {
          final thumbUrl = _normalizeMyStoryMediaUrl(story.thumbnailUrl!);
          final thumbBytes = await thumbnailFile.readAsBytes();
          await cacheManager.putFile(
            thumbUrl,
            thumbBytes,
            fileExtension: '.jpg',
          );
          if (kDebugMode) {
            debugPrint('✅ Pre-seeded cache for story thumbnail: $thumbUrl');
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️ Pre-seed cache failed (non-fatal): $e');
        }
      }
    }

    // Run async without blocking the return
    Future.microtask(seed);
  }

  /// Delete a story
  Future<bool> deleteStory(String storyId) async {
    try {
      final response = await _repository.deleteStory(storyId: storyId);
      if (response.success) {
        // Immediately remove from local DB so deleted story doesn't
        // reappear if the subsequent server refresh fails or is slow.
        final currentUserId = await _tokenStorage.getCurrentUserIdUUID();
        if (currentUserId != null && currentUserId.isNotEmpty) {
          await _localDb.deleteStory(
            currentUserId: currentUserId,
            storyId: storyId,
          );
        }
        // Optimistically remove from in-memory state
        final updated = state.stories.where((s) => s.id != storyId).toList();
        _safeSetState(state.copyWith(stories: updated));
      }
      return response.success;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ MyStoriesNotifier: Error deleting story - $e');
      }
      return false;
    }
  }

  /// Refresh stories
  Future<void> refresh() {
    _hasFetched = false;
    _fetchRetryCount = 0;
    return fetch();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _connectionSubscription?.cancel();
    _fcmSubscription?.cancel();
    super.dispose();
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// STORY VIEWERS NOTIFIER
// ═══════════════════════════════════════════════════════════════════════════

/// Notifier for story viewers with offline-first caching
class StoryViewersNotifier extends StateNotifier<StoryViewersState> {
  void _safeSetState(StoryViewersState s) {
    if (mounted) state = s;
  }

  StoryViewersNotifier(this._repository, this._storyId)
    : super(const StoryViewersState()) {
    // Load from cache first, then fetch from server
    _loadFromCacheThenFetch();
  }

  final StoryRepository _repository;
  final String _storyId;
  final _localDb = StoryViewersLocalDatabaseService.instance;

  /// Load from cache first, then fetch from server if online
  Future<void> _loadFromCacheThenFetch() async {
    _safeSetState(state.copyWith(isLoading: true, error: null));

    // Get current user ID
    final currentUserId = await TokenSecureStorage.instance
        .getCurrentUserIdUUID();
    if (currentUserId == null) {
      _safeSetState(
        state.copyWith(isLoading: false, error: 'User not logged in'),
      );
      return;
    }

    // Load from cache first
    final cachedViewers = await _localDb.getViewersForStory(
      currentUserId: currentUserId,
      storyId: _storyId,
    );

    if (cachedViewers.isNotEmpty) {
      _safeSetState(
        state.copyWith(
          viewers: cachedViewers,
          totalViews: cachedViewers.length,
          isLoading: false,
        ),
      );
    }

    // Try to fetch from server if connected
    if (_repository.isConnected) {
      await _fetchFromServer(currentUserId);
    } else if (cachedViewers.isEmpty) {
      _safeSetState(
        state.copyWith(isLoading: false, error: 'Offline - no cached data'),
      );
    }
  }

  /// Fetch viewers from server and cache them
  Future<void> _fetchFromServer(String currentUserId) async {
    try {
      final response = await _repository.getStoryViewers(storyId: _storyId);

      if (response.success) {
        final viewers = response.viewers ?? const <StoryViewerInfo>[];
        final serverTotalViews = response.totalViews ?? viewers.length;

        // If server says there are views but doesn't return viewer rows,
        // do NOT wipe cached data. Keep cached viewers if available.
        if (serverTotalViews > 0 && viewers.isEmpty) {
          if (state.viewers.isNotEmpty) {
            _safeSetState(
              state.copyWith(
                totalViews: serverTotalViews,
                isLoading: false,
                error: null,
              ),
            );
          } else {
            _safeSetState(
              state.copyWith(isLoading: false, error: 'Failed to load viewers'),
            );
          }
          return;
        }

        // Cache viewers locally
        await _localDb.cacheViewers(
          currentUserId: currentUserId,
          storyId: _storyId,
          viewers: viewers,
        );

        _safeSetState(
          state.copyWith(
            viewers: viewers,
            totalViews: serverTotalViews,
            isLoading: false,
            error: null,
          ),
        );
      } else {
        // Keep cached data if server fails
        if (state.viewers.isEmpty) {
          _safeSetState(
            state.copyWith(
              isLoading: false,
              error: response.error ?? 'Failed to fetch viewers',
            ),
          );
        } else {
          _safeSetState(state.copyWith(isLoading: false));
        }
      }
    } catch (e) {
      // Keep cached data on error
      if (state.viewers.isEmpty) {
        _safeSetState(state.copyWith(isLoading: false, error: e.toString()));
      } else {
        _safeSetState(state.copyWith(isLoading: false));
      }
    }
  }

  /// Fetch viewers for the story
  Future<void> fetch() async {
    if (state.isLoading) return;

    final currentUserId = await TokenSecureStorage.instance
        .getCurrentUserIdUUID();
    if (currentUserId == null) return;

    _safeSetState(state.copyWith(isLoading: true, error: null));

    if (_repository.isConnected) {
      await _fetchFromServer(currentUserId);
    } else {
      // Load from cache when offline
      final cachedViewers = await _localDb.getViewersForStory(
        currentUserId: currentUserId,
        storyId: _storyId,
      );

      _safeSetState(
        state.copyWith(
          viewers: cachedViewers,
          totalViews: cachedViewers.length,
          isLoading: false,
          error: cachedViewers.isEmpty ? 'Offline - no cached data' : null,
        ),
      );
    }
  }

  /// Refresh viewers
  Future<void> refresh() => fetch();
}
