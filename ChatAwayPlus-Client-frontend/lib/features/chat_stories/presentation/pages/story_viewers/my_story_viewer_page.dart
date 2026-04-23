import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chataway_plus/core/themes/app_text_styles.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:chataway_plus/features/chat_stories/data/models/chat_story_models.dart';
import 'package:chataway_plus/features/chat_stories/data/socket/story_socket_models.dart';
import 'package:chataway_plus/features/chat_stories/presentation/providers/story_providers.dart';
import 'package:chataway_plus/features/chat_stories/presentation/widgets/story_navigation_gesture_layer.dart';
import 'package:chataway_plus/features/chat_stories/presentation/widgets/story_progress_bar.dart';
import 'package:chataway_plus/features/chat_stories/presentation/widgets/story_slide_renderer.dart';
import 'package:chataway_plus/core/constants/api_url/api_urls.dart';
import 'package:chataway_plus/features/shared/widgets/avatars/cached_circle_avatar.dart';
import 'package:chataway_plus/features/contacts/presentation/providers/contacts_management.dart';
import 'package:chataway_plus/features/contacts/utils/contact_display_name_helper.dart';
import 'package:chataway_plus/core/connectivity/connectivity_service.dart';
import 'package:chataway_plus/core/snackbar/app_snackbar.dart';

class MyStoryViewerPage extends ConsumerStatefulWidget {
  const MyStoryViewerPage({
    super.key,
    this.story,
    this.localImageFile,
    this.localImageFiles,
    this.socketStories,
  });

  final ChatStoryModel? story;
  final File? localImageFile;
  final List<File>? localImageFiles;
  final List<StoryModel>? socketStories;

  @override
  ConsumerState<MyStoryViewerPage> createState() => _MyStoryViewerPageState();
}

class _MyStoryViewerPageState extends ConsumerState<MyStoryViewerPage>
    with TickerProviderStateMixin {
  late final PageController _pageController;
  late final AnimationController _progressController;

  int _currentSlide = 0;
  bool _mediaReady = false;

  List<ChatStorySlide> get _slides => widget.story?.slides ?? const [];

  /// Get socket stories list
  List<StoryModel> get _socketStories => widget.socketStories ?? const [];

  /// Get local files list (prefer localImageFiles, fallback to single localImageFile)
  List<File> get _localFiles {
    if (widget.localImageFiles != null && widget.localImageFiles!.isNotEmpty) {
      return widget.localImageFiles!;
    }
    if (widget.localImageFile != null) {
      return [widget.localImageFile!];
    }
    return [];
  }

  bool get _hasLocalFiles => _localFiles.isNotEmpty;
  bool get _hasSocketStories => _socketStories.isNotEmpty;

  /// Get duration for a socket story at given index
  Duration _getSocketStoryDuration(int index) {
    if (index >= 0 && index < _socketStories.length) {
      final story = _socketStories[index];
      if (story.mediaType == 'video' &&
          story.videoDuration != null &&
          story.videoDuration! > 0) {
        return Duration(milliseconds: (story.videoDuration! * 1000).ceil());
      }
    }
    return const Duration(seconds: 5);
  }

  /// Get duration for a ChatStorySlide at given index
  Duration _getSlideDuration(int index) {
    if (index >= 0 && index < _slides.length) {
      final slide = _slides[index];
      if (slide.isVideo &&
          slide.videoDuration != null &&
          slide.videoDuration! > 0) {
        return Duration(milliseconds: (slide.videoDuration! * 1000).ceil());
      }
    }
    return const Duration(seconds: 5);
  }

  /// Get the initial duration for the first slide
  Duration _getInitialDuration() {
    if (_hasSocketStories) return _getSocketStoryDuration(0);
    if (_hasLocalFiles) return const Duration(seconds: 5);
    return _getSlideDuration(0);
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _progressController =
        AnimationController(vsync: this, duration: _getInitialDuration())
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              _goNext();
            }
          });

    if (_hasLocalFiles || _hasSocketStories || _slides.isNotEmpty) {
      _progressController.stop();
      _progressController.value = 0;
    }
  }

  void _handleMediaReady(int slideIndex) {
    if (!mounted) return;
    if (slideIndex != _currentSlide) return;
    if (_mediaReady) return;

    setState(() {
      _mediaReady = true;
    });

    if (_progressController.isAnimating) return;
    _progressController.forward(from: 0);
  }

  void _resumeProgressIfAllowed() {
    if (!_mediaReady) return;
    if (_progressController.isAnimating) return;
    _progressController.forward();
  }

  @override
  void dispose() {
    _progressController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  /// Get total slide count
  int get _totalSlides {
    if (_hasSocketStories) return _socketStories.length;
    if (_hasLocalFiles) return _localFiles.length;
    return _slides.length;
  }

  /// Resolve view count for the current slide from a list of live stories.
  /// [liveStories] should come from ref.watch (in build) or ref.read (in
  /// event handlers) so we don't call ref.watch outside the build cycle.
  int _resolveViewCount(List<StoryModel> liveStories) {
    if (_hasSocketStories && _currentSlide < _socketStories.length) {
      final storyId = _socketStories[_currentSlide].id;
      final liveStory = liveStories.where((s) => s.id == storyId).firstOrNull;
      if (liveStory != null) return liveStory.viewsCount;
      return _socketStories[_currentSlide].viewsCount;
    }
    return 0;
  }

  /// Get current story ID for deletion
  String? get _currentStoryId {
    // Try socket stories first
    if (_hasSocketStories && _currentSlide < _socketStories.length) {
      return _socketStories[_currentSlide].id;
    }
    // Try slides if available
    if (_currentSlide < _slides.length &&
        _slides[_currentSlide].storyId != null) {
      return _slides[_currentSlide].storyId;
    }
    return null;
  }

  void _goNext() {
    if (_totalSlides == 0) {
      Navigator.of(context).maybePop();
      return;
    }

    if (_currentSlide >= _totalSlides - 1) {
      Navigator.of(context).maybePop();
      return;
    }

    final next = _currentSlide + 1;
    _pageController.animateToPage(
      next,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _goPrev() {
    if (_currentSlide <= 0) {
      Navigator.of(context).maybePop();
      return;
    }

    final prev = _currentSlide - 1;
    _pageController.animateToPage(
      prev,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  /// Build network image URL
  String _buildNetworkUrl(String url) {
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

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayoutBuilder(
      builder: (context, constraints, breakpoint) {
        final responsive = ResponsiveSize(
          context: context,
          constraints: constraints,
          breakpoint: breakpoint,
        );

        // ignore: unused_local_variable
        final story = widget.story;

        return Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Stack(
              children: [
                Positioned.fill(
                  child: _hasSocketStories
                      // Show socket stories in PageView
                      ? PageView.builder(
                          controller: _pageController,
                          itemCount: _socketStories.length,
                          onPageChanged: (idx) {
                            setState(() => _currentSlide = idx);
                            _mediaReady = false;
                            _progressController.duration =
                                _getSocketStoryDuration(idx);
                            _progressController.stop();
                            _progressController.value = 0;
                          },
                          itemBuilder: (context, idx) {
                            final socketStory = _socketStories[idx];
                            return StorySlideRenderer(
                              responsive: responsive,
                              networkImageUrl: _buildNetworkUrl(
                                socketStory.mediaUrl,
                              ),
                              caption: socketStory.caption,
                              mediaType: socketStory.mediaType,
                              thumbnailUrl: socketStory.thumbnailUrl,
                              videoDuration: socketStory.videoDuration,
                              videoUrl: socketStory.mediaType == 'video'
                                  ? _buildNetworkUrl(socketStory.mediaUrl)
                                  : null,
                              onMediaReady: () => _handleMediaReady(idx),
                              onVideoInitialized: (duration) {
                                if (idx == _currentSlide && mounted) {
                                  _mediaReady = true;
                                  _progressController.duration = duration;
                                  _progressController.forward(from: 0);
                                }
                              },
                            );
                          },
                        )
                      : _hasLocalFiles
                      // Show local files in PageView
                      ? PageView.builder(
                          controller: _pageController,
                          itemCount: _localFiles.length,
                          onPageChanged: (idx) {
                            setState(() => _currentSlide = idx);
                            _mediaReady = false;
                            _progressController.stop();
                            _progressController.value = 0;
                          },
                          itemBuilder: (context, idx) {
                            return StorySlideRenderer(
                              responsive: responsive,
                              localFile: _localFiles[idx],
                              onMediaReady: () => _handleMediaReady(idx),
                            );
                          },
                        )
                      : _slides.isEmpty
                      ? Center(
                          child: Text(
                            'No story',
                            style: AppTextSizes.heading(context).copyWith(
                              color: Colors.white,
                              fontSize: responsive.size(18),
                            ),
                          ),
                        )
                      // Show network images/videos from slides
                      : PageView.builder(
                          controller: _pageController,
                          itemCount: _slides.length,
                          onPageChanged: (idx) {
                            setState(() => _currentSlide = idx);
                            _mediaReady = false;
                            _progressController.duration = _getSlideDuration(
                              idx,
                            );
                            _progressController.stop();
                            _progressController.value = 0;
                          },
                          itemBuilder: (context, idx) {
                            final slide = _slides[idx];
                            return StorySlideRenderer(
                              responsive: responsive,
                              networkImageUrl: slide.imageUrl,
                              caption: slide.caption,
                              mediaType: slide.mediaType,
                              thumbnailUrl: slide.thumbnailUrl,
                              videoDuration: slide.videoDuration,
                              videoUrl: slide.videoUrl,
                              onMediaReady: () => _handleMediaReady(idx),
                              onVideoInitialized: (duration) {
                                if (idx == _currentSlide && mounted) {
                                  _mediaReady = true;
                                  _progressController.duration = duration;
                                  _progressController.forward(from: 0);
                                }
                              },
                            );
                          },
                        ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: responsive.spacing(12),
                      right: responsive.spacing(10),
                      top: responsive.spacing(10),
                    ),
                    child: Column(
                      children: [
                        if (_totalSlides > 0)
                          StoryProgressBar(
                            totalSegments: _totalSlides,
                            currentIndex: _currentSlide,
                            progressController: _progressController,
                            responsive: responsive,
                          ),
                        SizedBox(height: responsive.spacing(10)),
                        // Simple header: "My Stories" on left, close icon on right
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'My Stories',
                              style: AppTextSizes.regular(context).copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: responsive.size(16),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(context).maybePop(),
                              icon: Icon(
                                Icons.close,
                                color: Colors.white,
                                size: responsive.size(22),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // Bottom RIGHT: Views count + Delete icon
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: responsive.spacing(14),
                      right: responsive.spacing(14),
                      bottom: responsive.spacing(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Views count
                        GestureDetector(
                          onTap: () => _showViewersList(context, responsive),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: responsive.spacing(12),
                              vertical: responsive.spacing(10),
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(
                                responsive.size(30),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.remove_red_eye_outlined,
                                  color: Colors.white,
                                  size: responsive.size(18),
                                ),
                                SizedBox(width: responsive.spacing(8)),
                                Text(
                                  '${_resolveViewCount(ref.watch(myStoriesProvider).stories)}',
                                  style: AppTextSizes.regular(context).copyWith(
                                    color: Colors.white,
                                    fontSize: responsive.size(14),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: responsive.spacing(12)),
                        // Delete button
                        GestureDetector(
                          onTap: () => _confirmDeleteStory(context, responsive),
                          child: Container(
                            padding: EdgeInsets.all(responsive.spacing(10)),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.35),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.delete,
                              color: Colors.white,
                              size: responsive.size(22),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Navigation gesture layer - positioned to exclude header (top 100px) and bottom controls
                Positioned(
                  left: 0,
                  right: 0,
                  top: 100, // Exclude header area where delete button is
                  bottom: 80, // Exclude bottom controls
                  child: StoryNavigationGestureLayer(
                    onPrev: _goPrev,
                    onNext: _goNext,
                    onPause: _progressController.stop,
                    onResume: _resumeProgressIfAllowed,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Confirm and delete story
  void _confirmDeleteStory(BuildContext context, ResponsiveSize responsive) {
    final storyId = _currentStoryId;
    if (storyId == null) return;

    // Check if offline before allowing delete
    if (!ConnectivityCache.instance.isOnline) {
      AppSnackbar.showOfflineWarning(
        context,
        "You're offline. Connect to internet",
      );
      return;
    }

    // Pause story progress while showing dialog
    _progressController.stop();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Story'),
        content: const Text('Are you sure you want to delete this story?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              if (mounted) _resumeProgressIfAllowed();
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              // Delete story
              final success = await ref
                  .read(myStoriesProvider.notifier)
                  .deleteStory(storyId);
              if (!mounted) return;
              if (success) {
                if (_totalSlides <= 1) {
                  Navigator.of(this.context).maybePop();
                } else {
                  _goNext();
                }
              } else {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(content: Text('Failed to delete story')),
                );
                _resumeProgressIfAllowed();
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  /// Show viewers list in a bottom sheet
  void _showViewersList(BuildContext context, ResponsiveSize responsive) {
    final storyId = _currentStoryId;
    if (storyId == null) return;

    // Keep behavior consistent with My Stories page: load cache first,
    // then fetch latest from server when online.
    ref.read(storyViewersProvider(storyId).notifier).refresh();

    // Pause story progress while showing viewers
    _progressController.stop();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _ViewersBottomSheet(
        storyId: storyId,
        responsive: responsive,
        fallbackTotalViews: _resolveViewCount(
          ref.read(myStoriesProvider).stories,
        ),
      ),
    ).then((_) {
      // Resume progress when bottom sheet closes
      if (mounted) {
        _resumeProgressIfAllowed();
      }
    });
  }
}

/// Bottom sheet for showing story viewers
class _ViewersBottomSheet extends ConsumerStatefulWidget {
  const _ViewersBottomSheet({
    required this.storyId,
    required this.responsive,
    required this.fallbackTotalViews,
  });

  final String storyId;
  final ResponsiveSize responsive;
  final int fallbackTotalViews;

  @override
  ConsumerState<_ViewersBottomSheet> createState() =>
      _ViewersBottomSheetState();
}

class _ViewersBottomSheetState extends ConsumerState<_ViewersBottomSheet> {
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToTop = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Show scroll-to-top button when scrolled past ~10 viewers (approx 600px)
    final shouldShow =
        _scrollController.hasClients && _scrollController.offset > 600;
    if (_showScrollToTop != shouldShow) {
      setState(() => _showScrollToTop = shouldShow);
    }
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewersState = ref.watch(storyViewersProvider(widget.storyId));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalViewsToShow = viewersState.totalViews > widget.fallbackTotalViews
        ? viewersState.totalViews
        : widget.fallbackTotalViews;

    return Container(
      height: MediaQuery.of(context).size.height * 0.5,
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: EdgeInsets.all(widget.responsive.spacing(16)),
            child: Row(
              children: [
                Icon(
                  Icons.remove_red_eye_outlined,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
                SizedBox(width: widget.responsive.spacing(8)),
                Text(
                  'Viewers ($totalViewsToShow)',
                  style: AppTextSizes.regular(context).copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.close,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Viewers list
          Expanded(
            child: viewersState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : viewersState.error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Failed to load viewers',
                          style: TextStyle(
                            color: isDark ? Colors.white54 : Colors.black54,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            ref
                                .read(
                                  storyViewersProvider(widget.storyId).notifier,
                                )
                                .refresh();
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : viewersState.viewers.isEmpty
                ? Center(
                    child: Text(
                      'No viewers yet',
                      style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                  )
                : Stack(
                    children: [
                      ListView.builder(
                        controller: _scrollController,
                        physics: const BouncingScrollPhysics(),
                        itemCount: viewersState.viewers.length,
                        itemBuilder: (context, index) {
                          final viewer = viewersState.viewers[index];
                          return _buildViewerTile(context, ref, viewer, isDark);
                        },
                      ),
                      // Scroll to top button - similar to chat list
                      if (_showScrollToTop)
                        Positioned(
                          bottom: widget.responsive.spacing(16),
                          right: widget.responsive.spacing(16),
                          child: AnimatedScale(
                            scale: _showScrollToTop ? 1.0 : 0.9,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                            child: AnimatedOpacity(
                              opacity: _showScrollToTop ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOut,
                              child: FloatingActionButton.small(
                                onPressed: _scrollToTop,
                                backgroundColor: isDark
                                    ? Colors.grey[800]
                                    : Colors.white,
                                foregroundColor: isDark
                                    ? Colors.white
                                    : Colors.black87,
                                elevation: 4,
                                child: const Icon(
                                  Icons.keyboard_arrow_up,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  /// Build viewer tile - chat list style with phone contact name resolution
  Widget _buildViewerTile(
    BuildContext context,
    WidgetRef ref,
    StoryViewerInfo viewer,
    bool isDark,
  ) {
    // Get contacts list for name resolution
    final contacts = ref.watch(contactsListProvider);

    // Resolve display name: prefer phone contact name, fallback to app name
    final displayName = ContactDisplayNameHelper.resolveDisplayName(
      contacts: contacts,
      userId: viewer.viewer.id,
      mobileNo: viewer.viewer.mobileNumber ?? '',
      backendDisplayName: viewer.viewer.fullName,
      fallbackLabel: 'ChatAway user',
    );

    final chatPictureUrl = viewer.viewer.chatPicture;

    return ListTile(
      contentPadding: EdgeInsets.symmetric(
        horizontal: widget.responsive.spacing(16),
        vertical: widget.responsive.spacing(4),
      ),
      leading: CachedCircleAvatar(
        key: ValueKey('viewer_avatar_${viewer.id}'),
        chatPictureUrl: chatPictureUrl,
        radius: widget.responsive.size(20),
        backgroundColor: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
        iconColor: isDark ? Colors.white54 : Colors.black54,
        contactName: displayName,
      ),
      title: Text(
        displayName,
        style: AppTextSizes.regular(context).copyWith(
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
      subtitle: Text(
        _formatViewedTime(viewer.viewedAt),
        style: AppTextSizes.small(
          context,
        ).copyWith(color: isDark ? Colors.white54 : Colors.black54),
      ),
    );
  }

  String _formatViewedTime(DateTime viewedAt) {
    final diff = DateTime.now().difference(viewedAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
