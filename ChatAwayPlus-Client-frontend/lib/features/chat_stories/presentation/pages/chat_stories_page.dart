import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:image_picker/image_picker.dart';

import 'package:image_cropper/image_cropper.dart';

import 'package:permission_handler/permission_handler.dart';

import 'package:chataway_plus/core/themes/app_text_styles.dart';

import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';

import 'package:chataway_plus/core/snackbar/app_snackbar.dart';

import 'package:chataway_plus/core/storage/token_storage.dart';

import 'package:chataway_plus/features/chat_stories/data/models/chat_story_models.dart';

import 'package:chataway_plus/features/chat_stories/data/socket/story_socket_models.dart';

import 'package:chataway_plus/features/contacts/data/datasources/contacts_database_service.dart';

import 'package:chataway_plus/features/chat_stories/presentation/pages/story_management/my_stories_list_page.dart';

import 'package:chataway_plus/features/chat_stories/presentation/pages/story_viewers/contact_story_viewer_page.dart';

import 'package:chataway_plus/features/chat_stories/presentation/providers/story_providers.dart';

import 'package:chataway_plus/features/chat_stories/presentation/providers/story_state.dart';

import 'package:chataway_plus/features/chat_stories/presentation/widgets/chat_story_tile.dart';

import 'package:chataway_plus/features/chat_stories/presentation/widgets/my_story_tile.dart';

import 'package:chataway_plus/features/chat_stories/presentation/widgets/video_story_preview_page.dart';

import 'package:internet_connection_checker/internet_connection_checker.dart';

import 'package:chataway_plus/core/connectivity/connectivity_service.dart';

/// Chat Stories page - WhatsApp-like status/stories feature

/// Shows user chat stories in circular format with gradient rings

/// Now integrated with socket-based real-time updates.

class ChatStoriesPage extends ConsumerStatefulWidget {
  const ChatStoriesPage({super.key});

  @override
  ConsumerState<ChatStoriesPage> createState() => ChatStoriesPageState();
}

/// Global key to access ChatStoriesPage state from MainNavigationPage

final GlobalKey<ChatStoriesPageState> chatStoriesPageKey =
    GlobalKey<ChatStoriesPageState>();

class ChatStoriesPageState extends ConsumerState<ChatStoriesPage> {
  final ImagePicker _imagePicker = ImagePicker();

  String? _currentUserId;

  Map<String, String> _deviceNameByUserId = <String, String>{};

  // Search functionality

  String _searchQuery = '';

  // Track watched story slides locally (for animation/UI purposes)

  final Map<String, Set<int>> _watchedStorySlides = {};

  Set<int> _watchedSlidesFor(String storyId) =>
      _watchedStorySlides[storyId] ?? <int>{};

  bool _isStoryFullyWatched(ChatStoryModel story) {
    if (story.slides.isEmpty) return false;

    // Calculate fully-watched status based on actual slide data

    // Combine local tracking (for instant UI feedback) with server-side isViewed flags

    final localWatched = _watchedSlidesFor(story.id);

    final serverViewed = story.viewedSlideIndices;

    final allWatched = {...localWatched, ...serverViewed};

    // Story is fully watched if all slides are marked as watched

    final isFullyWatched = allWatched.length >= story.slides.length;

    // Double-check with hasUnviewed flag - if server says there are unviewed stories,

    // but our calculation says fully watched, trust the slide data (more granular)

    // This prevents the flash where stories briefly appear in wrong section

    return isFullyWatched;
  }

  int _firstUnwatchedSlideIndex(ChatStoryModel story) {
    if (story.slides.isEmpty) return 0;

    final localWatched = _watchedSlidesFor(story.id);

    final serverViewed = story.viewedSlideIndices;

    final allWatched = {...localWatched, ...serverViewed};

    for (var i = 0; i < story.slides.length; i++) {
      if (!allWatched.contains(i)) return i;
    }

    return 0;
  }

  void _markStorySlideAsWatched(
    String storyId,

    int slideIndex,

    String? slideStoryId,
  ) {
    if (!mounted) return;

    setState(() {
      final set = _watchedStorySlides.putIfAbsent(storyId, () => <int>{});

      set.add(slideIndex);
    });

    // Mark as viewed on server

    if (slideStoryId != null) {
      ref.read(markStoryViewedProvider(slideStoryId))();
    }
  }

  /// Clear search query - called from MainNavigationPage

  void clearSearch() {
    if (!mounted) return;

    setState(() {
      _searchQuery = '';
    });
  }

  /// Set search query - called from MainNavigationPage

  void setSearch(String query) {
    if (!mounted) return;

    setState(() {
      _searchQuery = query.toLowerCase().trim();
    });
  }

  @override
  void initState() {
    super.initState();

    _loadCurrentUserAndDeviceNames();

    // Ensure story repository is initialized and fetch latest stories

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final repository = ref.read(storyRepositoryProvider);

      repository.initialize();

      // Wait for socket to be ready, then fetch latest stories

      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted && repository.isConnected) {
          if (kDebugMode) {
            debugPrint('📥 Fetching latest stories on page load');
          }

          ref.read(contactsStoriesProvider.notifier).fetch();

          ref.read(myStoriesProvider.notifier).fetch();
        }
      });
    });
  }

  /// Public method to add story - can be called from MainNavigationPage

  Future<void> handleAddStory() async {
    if (kDebugMode) {
      debugPrint('➕ Add story tapped');
    }

    if (!ConnectivityCache.instance.isOnline) {
      if (!mounted) return;

      AppSnackbar.showOfflineWarning(context, "You're offline");

      return;
    }

    // Check story limit first (5 stories maximum)

    final myStoriesState = ref.read(myStoriesProvider);

    final currentStoryCount = myStoriesState.stories.length;

    if (currentStoryCount >= 5) {
      if (!mounted) return;

      AppSnackbar.showError(
        context,

        'Story limit reached! You can only have 5 stories due to beta version limitations for best user experience.',
      );

      return;
    }

    try {
      var permission = await Permission.photos.isGranted
          ? Permission.photos
          : Permission.storage;

      var status = await permission.status;

      if (status.isDenied) {
        status = await permission.request();

        if (status.isDenied && permission == Permission.photos) {
          permission = Permission.storage;

          status = await permission.request();
        }

        if (status.isDenied) {
          if (!mounted) return;

          AppSnackbar.showError(
            context,

            'Permission to access photos is required',
          );

          return;
        }
      }

      if (status.isPermanentlyDenied) {
        if (!mounted) return;

        AppSnackbar.showError(
          context,

          'Please enable photo permission in settings',
        );

        await openAppSettings();

        return;
      }

      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,

        maxWidth: 1920,

        maxHeight: 1920,

        imageQuality: 85,
      );

      if (image != null) {
        final File imageFile = File(image.path);

        if (kDebugMode) {
          debugPrint('📸 Selected story image: ${imageFile.path}');
        }

        // Crop image before uploading

        final croppedFile = await _cropStoryImage(imageFile);

        if (croppedFile == null) {
          if (kDebugMode) {
            debugPrint('❌ Image cropping cancelled');
          }

          return;
        }

        // Show loading indicator

        if (!mounted) return;

        AppSnackbar.showInfo(context, 'Uploading story...');

        // Upload story via socket

        final success = await ref
            .read(myStoriesProvider.notifier)
            .createStory(mediaFile: File(croppedFile.path));

        if (!mounted) return;

        if (!success) {
          final error = ref.read(myStoriesProvider).error;

          // Check if this is an offline/network error

          final errorStr = (error ?? '').toLowerCase();

          final isTimeoutError =
              errorStr.contains('timeoutexception') ||
              errorStr.contains('timed out') ||
              errorStr.contains('timeout');

          if (isTimeoutError) {
            AppSnackbar.showError(context, 'Upload failed. Try again');

            return;
          }

          // Handle file too large error (413)

          if (errorStr.contains('413') ||
              errorStr.contains('request entity too large') ||
              errorStr.contains('too large')) {
            AppSnackbar.showError(
              context,

              'Image too large. Please try a different photo',
            );

            return;
          }

          final isSocketNotReady =
              errorStr.contains('socket not connected') ||
              errorStr.contains('socket not ready');

          if (isSocketNotReady) {
            AppSnackbar.showError(context, 'Connecting... Please try again');
          } else {
            final hasInternet = await InternetConnectionChecker().hasConnection;

            if (!mounted) return;

            final isOfflineError =
                errorStr.contains('socketexception') ||
                errorStr.contains('clientexception') ||
                errorStr.contains('host lookup') ||
                errorStr.contains('network is unreachable') ||
                errorStr.contains('no address associated') ||
                !hasInternet;

            if (isOfflineError) {
              AppSnackbar.showOfflineWarning(
                context,

                "You're offline. Connect to internet",
              );

              return;
            }

            AppSnackbar.showError(context, error ?? 'Failed to post story');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Gallery error: $e');
      }

      if (!mounted) return;

      // Check if this is an offline/network error

      final errorStr = e.toString().toLowerCase();

      if (errorStr.contains('socket not connected') ||
          errorStr.contains('socket not ready')) {
        AppSnackbar.showError(context, 'Connecting... Please try again');
      } else {
        final hasInternet = await InternetConnectionChecker().hasConnection;

        if (!mounted) return;

        final isOfflineError =
            errorStr.contains('socketexception') ||
            errorStr.contains('clientexception') ||
            errorStr.contains('host lookup') ||
            errorStr.contains('network is unreachable') ||
            errorStr.contains('no address associated') ||
            !hasInternet;

        if (isOfflineError) {
          AppSnackbar.showOfflineWarning(
            context,

            "You're offline. Connect to internet",
          );

          return;
        }

        AppSnackbar.showError(context, 'Failed to pick image');
      }
    }
  }

  /// Public method to add VIDEO story - opens video-only picker from gallery

  Future<void> handleAddVideoStory() async {
    if (kDebugMode) {
      debugPrint('🎬 Add video story tapped');
    }

    if (!ConnectivityCache.instance.isOnline) {
      if (!mounted) return;

      AppSnackbar.showOfflineWarning(context, "You're offline");

      return;
    }

    // Check story limit first (5 stories maximum)

    final myStoriesState = ref.read(myStoriesProvider);

    final currentStoryCount = myStoriesState.stories.length;

    if (currentStoryCount >= 5) {
      if (!mounted) return;

      AppSnackbar.showError(
        context,

        'Story limit reached! You can only have 5 stories due to beta version limitations for best user experience.',
      );

      return;
    }

    // Check video story limit (max 3 video stories)

    final videoStoryCount = myStoriesState.stories
        .where((s) => s.mediaType == 'video')
        .length;

    if (videoStoryCount >= 3) {
      if (!mounted) return;

      AppSnackbar.showError(
        context,

        'Video story limit reached! You can add up to 3 video stories.',
      );

      return;
    }

    try {
      var permission = await Permission.photos.isGranted
          ? Permission.photos
          : Permission.storage;

      var status = await permission.status;

      if (status.isDenied) {
        status = await permission.request();

        if (status.isDenied && permission == Permission.photos) {
          permission = Permission.storage;

          status = await permission.request();
        }

        if (status.isDenied) {
          if (!mounted) return;

          AppSnackbar.showError(
            context,

            'Permission to access videos is required',
          );

          return;
        }
      }

      if (status.isPermanentlyDenied) {
        if (!mounted) return;

        AppSnackbar.showError(
          context,

          'Please enable storage permission in settings',
        );

        await openAppSettings();

        return;
      }

      final XFile? video = await _imagePicker.pickVideo(
        source: ImageSource.gallery,
      );

      if (video != null) {
        final File videoFile = File(video.path);

        if (kDebugMode) {
          debugPrint('🎬 Selected story video: ${videoFile.path}');
        }

        // Check file size (max 100MB for video stories)

        final fileSizeInBytes = await videoFile.length();

        final fileSizeInMB = fileSizeInBytes / (1024 * 1024);

        if (kDebugMode) {
          debugPrint('📦 Video size: ${fileSizeInMB.toStringAsFixed(2)} MB');
        }

        if (fileSizeInMB > 100) {
          if (!mounted) return;

          AppSnackbar.showError(
            context,

            'Video too large (${fileSizeInMB.toStringAsFixed(1)}MB). Max: 100MB',
          );

          return;
        }

        // Navigate to trimmer/preview page - it handles duration check and trimming

        if (!mounted) return;

        final previewPageKey = GlobalKey<VideoStoryPreviewPageState>();

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => VideoStoryPreviewPage(
              key: previewPageKey,

              videoFile: videoFile,

              onConfirm: (File processedVideo, File? thumbnailFile) async {
                // Show loading indicator on the preview page

                previewPageKey.currentState?.startUpload();

                // Upload story via socket (same API, different media type)

                final success = await ref
                    .read(myStoriesProvider.notifier)
                    .createStory(
                      mediaFile: processedVideo,

                      thumbnailFile: thumbnailFile,
                    );

                // Hide loading indicator

                previewPageKey.currentState?.endUpload();

                if (!mounted) return;

                if (success) {
                  // Close preview page on success

                  Navigator.of(context).pop();

                  return;
                }

                // Handle errors

                final error = ref.read(myStoriesProvider).error;

                final errorStr = (error ?? '').toLowerCase();

                final isTimeoutError =
                    errorStr.contains('timeoutexception') ||
                    errorStr.contains('timed out') ||
                    errorStr.contains('timeout');

                if (isTimeoutError) {
                  AppSnackbar.showError(context, 'Upload failed. Try again');

                  return;
                }

                // Handle file too large error (413)

                if (errorStr.contains('413') ||
                    errorStr.contains('request entity too large') ||
                    errorStr.contains('too large')) {
                  AppSnackbar.showError(
                    context,

                    'Video too large. Try a shorter video',
                  );

                  return;
                }

                final isSocketNotReady =
                    errorStr.contains('socket not connected') ||
                    errorStr.contains('socket not ready');

                if (isSocketNotReady) {
                  AppSnackbar.showError(
                    context,

                    'Connecting... Please try again',
                  );
                } else {
                  final hasInternet =
                      await InternetConnectionChecker().hasConnection;

                  if (!mounted) return;

                  final isOfflineError =
                      errorStr.contains('socketexception') ||
                      errorStr.contains('clientexception') ||
                      errorStr.contains('host lookup') ||
                      errorStr.contains('network is unreachable') ||
                      errorStr.contains('no address associated') ||
                      !hasInternet;

                  if (isOfflineError) {
                    AppSnackbar.showOfflineWarning(
                      context,

                      "You're offline. Connect to internet",
                    );

                    return;
                  }

                  AppSnackbar.showError(
                    context,

                    error ?? 'Failed to post video story',
                  );
                }
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Video gallery error: $e');
      }

      if (!mounted) return;

      final errorStr = e.toString().toLowerCase();

      if (errorStr.contains('socket not connected') ||
          errorStr.contains('socket not ready')) {
        AppSnackbar.showError(context, 'Connecting... Please try again');
      } else {
        final hasInternet = await InternetConnectionChecker().hasConnection;

        if (!mounted) return;

        final isOfflineError =
            errorStr.contains('socketexception') ||
            errorStr.contains('clientexception') ||
            errorStr.contains('host lookup') ||
            errorStr.contains('network is unreachable') ||
            errorStr.contains('no address associated') ||
            !hasInternet;

        if (isOfflineError) {
          AppSnackbar.showOfflineWarning(
            context,

            "You're offline. Connect to internet",
          );

          return;
        }

        AppSnackbar.showError(context, 'Failed to pick video');
      }
    }
  }

  /// Crop story image before uploading

  /// Shows original photo size - no forced aspect ratio or upscaling

  Future<CroppedFile?> _cropStoryImage(File imageFile) async {
    try {
      return await ImageCropper().cropImage(
        sourcePath: imageFile.path,

        // No forced aspectRatio - let user see original photo as-is
        compressFormat: ImageCompressFormat.jpg,

        compressQuality: 85,

        // No maxWidth/maxHeight to avoid upscaling small images
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Edit Story',

            toolbarColor: Colors.black,

            toolbarWidgetColor: Colors.white,

            backgroundColor: Colors.black,

            initAspectRatio: CropAspectRatioPreset.original,

            lockAspectRatio: false,

            hideBottomControls: false,

            showCropGrid: true,

            cropGridColor: Colors.white54,

            cropFrameColor: Colors.white,

            activeControlsWidgetColor: Colors.white,

            dimmedLayerColor: Colors.black.withAlpha((0.7 * 255).round()),

            cropStyle: CropStyle.rectangle,

            aspectRatioPresets: [
              CropAspectRatioPreset.original,

              CropAspectRatioPreset.square,

              CropAspectRatioPreset.ratio3x2,

              CropAspectRatioPreset.ratio4x3,

              CropAspectRatioPreset.ratio16x9,
            ],
          ),

          IOSUiSettings(
            title: 'Edit Story',

            cancelButtonTitle: 'Cancel',

            doneButtonTitle: 'Done',

            aspectRatioLockEnabled: false,

            resetAspectRatioEnabled: true,

            cropStyle: CropStyle.rectangle,

            aspectRatioPickerButtonHidden: false,
          ),
        ],
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Image cropping error: $e');
      }

      return null;
    }
  }

  /// Convert socket stories to UI models

  List<ChatStoryModel> _convertContactsStories(
    List<UserStoriesGroup> groups, {

    required String? effectiveCurrentUserId,
  }) {
    return groups
        .where(
          (g) =>
              effectiveCurrentUserId == null ||
              g.user.id != effectiveCurrentUserId,
        )
        .map((g) {
          final model = ChatStoryModel.fromUserStoriesGroup(g);

          final userId = model.userId ?? model.id;

          final overrideName = _deviceNameByUserId[userId];

          if (overrideName != null && overrideName.trim().isNotEmpty) {
            return ChatStoryModel(
              id: model.id,

              name: overrideName,

              timeAgo: model.timeAgo,

              type: model.type,

              hasStory: model.hasStory,

              profileImage: model.profileImage,

              slides: model.slides,

              userId: model.userId,

              hasUnviewed: model.hasUnviewed,
            );
          }

          return model;
        })
        .toList();
  }

  /// Get latest updates (unviewed stories)

  List<ChatStoryModel> _getLatestUpdates(List<ChatStoryModel> stories) {
    return stories
        .where((s) => s.hasStory && !_isStoryFullyWatched(s))
        .toList();
  }

  /// Get seen history (fully viewed stories)

  List<ChatStoryModel> _getSeenHistory(List<ChatStoryModel> stories) {
    return stories.where((s) => s.hasStory && _isStoryFullyWatched(s)).toList();
  }

  @override
  Widget build(BuildContext context) {
    // Watch providers

    final contactsStoriesState = ref.watch(contactsStoriesProvider);

    final myStoriesState = ref.watch(myStoriesProvider);

    // Listen for real-time story events

    ref.listen(storyCreatedStreamProvider, (_, asyncValue) {
      asyncValue.whenData((event) {
        // Story created event received - UI will auto-refresh via provider

        if (kDebugMode) {
          debugPrint('📥 ${event.userName} posted a new story');
        }
      });
    });

    ref.listen(storyViewedStreamProvider, (_, asyncValue) {
      asyncValue.whenData((event) {
        // Optional: Show notification when someone views my story

        if (kDebugMode) {
          debugPrint('📥 ${event.viewerName} viewed your story');
        }
      });
    });

    ref.listen(storyDeletedStreamProvider, (_, asyncValue) {
      asyncValue.whenData((event) {
        // Clean up local watched slides tracking for the deleted story

        if (mounted) {
          setState(() {
            _watchedStorySlides.remove(event.storyId);
          });
        }

        if (kDebugMode) {
          debugPrint(
            '🗑️ Story ${event.storyId} deleted — cleaned up local state',
          );
        }
      });
    });

    final effectiveCurrentUserId =
        _currentUserId ??
        (myStoriesState.stories.isNotEmpty
            ? myStoriesState.stories.first.userId
            : null);

    // Convert to UI models

    final allStories = _convertContactsStories(
      contactsStoriesState.stories,

      effectiveCurrentUserId: effectiveCurrentUserId,
    );

    final latestUpdates = _getLatestUpdates(allStories);

    final seenHistory = _getSeenHistory(allStories);

    // Apply search filter if search query is not empty

    final filteredLatestUpdates = _searchQuery.isEmpty
        ? latestUpdates
        : latestUpdates
              .where((story) => story.name.toLowerCase().contains(_searchQuery))
              .toList();

    final filteredSeenHistory = _searchQuery.isEmpty
        ? seenHistory
        : seenHistory
              .where((story) => story.name.toLowerCase().contains(_searchQuery))
              .toList();

    final isSearchActive = _searchQuery.isNotEmpty;

    final hasSearchResults =
        filteredLatestUpdates.isNotEmpty || filteredSeenHistory.isNotEmpty;

    return ResponsiveLayoutBuilder(
      builder: (context, constraints, breakpoint) {
        final responsive = ResponsiveSize(
          context: context,

          constraints: constraints,

          breakpoint: breakpoint,
        );

        final isDark = Theme.of(context).brightness == Brightness.dark;

        final hasFilteredLatestUpdates = filteredLatestUpdates.isNotEmpty;

        final hasFilteredSeenHistory = filteredSeenHistory.isNotEmpty;

        final isLoading =
            contactsStoriesState.isLoading || myStoriesState.isLoading;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,

          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {
                await ref.read(refreshAllStoriesProvider)();
              },

              child: ListView(
                padding: EdgeInsets.only(
                  left: responsive.spacing(16),

                  right: responsive.spacing(16),

                  top: 0,
                ),

                children: [
                  // ============================================================

                  // SECTION 1: Current User Story (hide when searching)

                  // ============================================================
                  if (!isSearchActive)
                    _buildMyStoryTile(
                      responsive: responsive,

                      isDark: isDark,

                      myStoriesState: myStoriesState,
                    ),

                  // ============================================================

                  // SECTION 2: Loading indicator

                  // ============================================================
                  if (isLoading && allStories.isEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: responsive.spacing(32)),

                      child: const Center(child: CircularProgressIndicator()),
                    ),

                  // ============================================================

                  // SECTION 3: Search - No results found

                  // ============================================================
                  if (isSearchActive && !hasSearchResults)
                    Padding(
                      padding: EdgeInsets.only(top: responsive.spacing(32)),

                      child: Center(
                        child: Text(
                          'No story found with this contact',

                          style: AppTextSizes.regular(context).copyWith(
                            color: isDark ? Colors.white38 : Colors.black38,

                            fontSize: responsive.size(14),
                          ),
                        ),
                      ),
                    ),

                  // ============================================================

                  // SECTION 4: Latest Updates (if any)

                  // ============================================================
                  if (hasFilteredLatestUpdates) ...[
                    SizedBox(height: responsive.spacing(16)),

                    Text(
                      'Latest Stories',

                      style: AppTextSizes.regular(context).copyWith(
                        color: isDark ? Colors.white54 : Colors.black54,

                        fontWeight: FontWeight.w500,

                        fontSize: responsive.size(14),
                      ),
                    ),

                    SizedBox(height: responsive.spacing(8)),

                    ...filteredLatestUpdates.map(
                      (story) => ChatStoryTile(
                        story: story,

                        watchedSegments: {
                          ..._watchedSlidesFor(story.id),

                          ...story.viewedSlideIndices,
                        },

                        responsive: responsive,

                        isDark: isDark,

                        onTap: () => _openContactStoryViewer(story),
                      ),
                    ),
                  ],

                  // ============================================================

                  // SECTION 5: Seen History (if any)

                  // ============================================================
                  if (hasFilteredSeenHistory) ...[
                    SizedBox(height: responsive.spacing(16)),

                    Text(
                      'Seen Stories',

                      style: AppTextSizes.regular(context).copyWith(
                        color: isDark ? Colors.white54 : Colors.black54,

                        fontWeight: FontWeight.w500,

                        fontSize: responsive.size(14),
                      ),
                    ),

                    SizedBox(height: responsive.spacing(8)),

                    ...filteredSeenHistory.map(
                      (story) => ChatStoryTile(
                        story: story,

                        watchedSegments: {
                          ..._watchedSlidesFor(story.id),

                          ...story.viewedSlideIndices,
                        },

                        responsive: responsive,

                        isDark: isDark,

                        onTap: () => _openContactStoryViewer(story),
                      ),
                    ),
                  ],

                  // ============================================================

                  // SECTION 6: Empty state fallback (only when not searching)

                  // ============================================================
                  if (!isLoading &&
                      !isSearchActive &&
                      !hasFilteredLatestUpdates &&
                      !hasFilteredSeenHistory)
                    Padding(
                      padding: EdgeInsets.only(top: responsive.spacing(32)),

                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,

                          children: [
                            Text(
                              'No Stories Added Yet From Your Contacts',

                              style: AppTextSizes.regular(context).copyWith(
                                color: isDark ? Colors.white54 : Colors.black54,

                                fontSize: responsive.size(14),

                                fontWeight: FontWeight.w500,
                              ),

                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),

                  // ============================================================

                  // SECTION 6: Error state

                  // ============================================================
                  if (contactsStoriesState.error != null)
                    Padding(
                      padding: EdgeInsets.only(top: responsive.spacing(16)),

                      child: Center(
                        child: Column(
                          children: [
                            Text(
                              'Failed to load stories',

                              style: AppTextSizes.regular(context).copyWith(
                                color: Colors.red,

                                fontSize: responsive.size(14),
                              ),
                            ),

                            SizedBox(height: responsive.spacing(8)),

                            TextButton(
                              onPressed: () {
                                ref
                                    .read(contactsStoriesProvider.notifier)
                                    .refresh();
                              },

                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMyStoryTile({
    required ResponsiveSize responsive,

    required bool isDark,

    required MyStoriesState myStoriesState,
  }) {
    final hasStory = myStoriesState.hasStories;

    final stories = myStoriesState.stories;

    // Format time ago from most recent story

    String formatStoryTime() {
      if (stories.isEmpty) return 'Add Story';

      final sortedStories = List<StoryModel>.from(stories)
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

      return sortedStories.last.timeAgo;
    }

    return MyStoryTile(
      responsive: responsive,

      isDark: isDark,

      hasStory: hasStory,

      storyImages: const [], // We don't use local files anymore

      storyCount: stories.length,

      totalViews: myStoriesState.totalViews,

      networkStoryUrls: stories.map((s) {
        // For video stories, use thumbnail URL only if available

        // Don't fallback to video URL as it can't be loaded as an image

        if (s.mediaType == 'video') {
          return s.thumbnailUrl ?? ''; // Return empty if no thumbnail
        }

        return s.mediaUrl;
      }).toList(),

      title: hasStory ? 'My Stories' : 'Tap here to add stories',

      subtitle: hasStory ? formatStoryTime() : 'Add Story',

      onTap: hasStory
          ? () => _openMyStoriesManagement()
          : () => handleAddStory(),
    );
  }

  void _openContactStoryViewer(ChatStoryModel story) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => ContactStoryViewerPage(
              story: story,

              initialSlide: _firstUnwatchedSlideIndex(story),

              onSlideFullyWatched: (idx) {
                final slideStoryId = idx < story.slides.length
                    ? story.slides[idx].storyId
                    : null;

                _markStorySlideAsWatched(story.id, idx, slideStoryId);
              },

              onStoryFullyWatched: () {
                // Story fully watched - state updates via socket

                if (kDebugMode) {
                  debugPrint('📖 Story ${story.id} fully watched');
                }
              },
            ),
          ),
        )
        .then((_) {
          if (!mounted) return;

          setState(() {});
        });
  }

  Future<void> _loadCurrentUserAndDeviceNames() async {
    try {
      final currentUserId = await TokenSecureStorage.instance
          .getCurrentUserIdUUID();

      final contacts = await ContactsDatabaseService.instance
          .loadRegisteredFromCache();

      final map = <String, String>{};

      for (final c in contacts) {
        final id = c.appUserId;

        if (id == null || id.trim().isEmpty) continue;

        final name = c.preferredDisplayName.trim();

        if (name.isEmpty) continue;

        map[id] = name;
      }

      if (!mounted) return;

      setState(() {
        _currentUserId = currentUserId;

        _deviceNameByUserId = map;
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ ChatStoriesPage: Failed to load device names: $e');
      }
    }
  }

  void _openMyStoriesManagement() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const MyStoriesListPage()));
  }
}
