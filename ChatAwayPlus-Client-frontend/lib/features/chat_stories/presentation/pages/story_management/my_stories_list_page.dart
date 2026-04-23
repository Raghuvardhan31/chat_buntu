import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chataway_plus/core/constants/api_url/api_urls.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:chataway_plus/core/snackbar/app_snackbar.dart';
import 'package:chataway_plus/core/sync/authenticated_image_cache_manager.dart';
import 'package:chataway_plus/core/themes/app_text_styles.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/features/chat_stories/data/models/chat_story_models.dart';
import 'package:chataway_plus/features/chat_stories/data/socket/story_socket_models.dart';
import 'package:chataway_plus/features/chat_stories/presentation/pages/story_viewers/my_story_viewer_page.dart';
import 'package:chataway_plus/features/chat_stories/presentation/providers/story_providers.dart';
import 'package:chataway_plus/features/chat_stories/presentation/providers/story_state.dart';
import 'package:chataway_plus/features/contacts/presentation/providers/contacts_management.dart';
import 'package:chataway_plus/features/contacts/utils/contact_display_name_helper.dart';
import 'package:chataway_plus/features/shared/widgets/avatars/cached_circle_avatar.dart';
import 'package:chataway_plus/core/connectivity/connectivity_service.dart';

/// My Stories List Page - WhatsApp-style Latest Updates UI
/// Shows user's stories in horizontal scrollable circular format
class MyStoriesListPage extends ConsumerStatefulWidget {
  const MyStoriesListPage({super.key});

  @override
  ConsumerState<MyStoriesListPage> createState() => _MyStoriesListPageState();
}

class _MyStoriesListPageState extends ConsumerState<MyStoriesListPage> {
  @override
  Widget build(BuildContext context) {
    return ResponsiveLayoutBuilder(
      builder: (context, constraints, breakpoint) {
        final responsive = ResponsiveSize(
          context: context,
          constraints: constraints,
          breakpoint: breakpoint,
        );

        final myStoriesState = ref.watch(myStoriesProvider);
        final stories = myStoriesState.stories;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: _buildAppBar(context, responsive, stories),
          body: _buildWhatsAppStyleBody(context, responsive, myStoriesState),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    ResponsiveSize responsive,
    List<StoryModel> stories,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Colors.white : AppColors.iconPrimary;
    final textColor = isDark ? Colors.white : AppColors.iconPrimary;

    return AppBar(
      backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      elevation: 0,
      centerTitle: false,
      title: Text(
        'My Stories',
        style: AppTextSizes.heading(
          context,
        ).copyWith(color: textColor, fontWeight: FontWeight.bold),
      ),
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back,
          color: iconColor,
          size: responsive.size(24),
        ),
        onPressed: () => Navigator.of(context).pop(),
      ),
      actions: [
        // Only show delete all icon when there are multiple stories
        if (stories.length > 1)
          IconButton(
            icon: Icon(
              Icons.delete,
              color: iconColor,
              size: responsive.size(24),
            ),
            onPressed: () => _showDeleteAllDialog(stories),
            tooltip: 'Delete All Stories',
          ),
      ],
    );
  }

  Widget _buildWhatsAppStyleBody(
    BuildContext context,
    ResponsiveSize responsive,
    MyStoriesState myStoriesState,
  ) {
    if (myStoriesState.isLoading && myStoriesState.stories.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (myStoriesState.stories.isEmpty) {
      return _buildEmptyState(context, responsive);
    }

    // Simple vertical list only - no duplicate headers or horizontal scrolling
    return _buildStoryDetailsList(context, responsive, myStoriesState.stories);
  }

  Widget _buildStoryDetailsList(
    BuildContext context,
    ResponsiveSize responsive,
    List<StoryModel> stories,
  ) {
    // Sort stories by creation time (oldest first) to maintain consistent positions
    final sortedStories = List<StoryModel>.from(stories)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: responsive.spacing(16)),
      itemCount: sortedStories.length,
      itemBuilder: (context, index) {
        return _buildStoryListItem(context, responsive, sortedStories, index);
      },
    );
  }

  Widget _buildStoryListItem(
    BuildContext context,
    ResponsiveSize responsive,
    List<StoryModel> stories,
    int index,
  ) {
    final story = stories[index];

    return InkWell(
      onTap: () => _openStoryViewer(stories, index),
      borderRadius: BorderRadius.circular(responsive.size(8)),
      child: Container(
        margin: EdgeInsets.only(bottom: responsive.spacing(20)),
        child: Row(
          children: [
            // Photo and Story text (entire row is tappable)
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: responsive.size(48),
                    height: responsive.size(48),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(responsive.size(8)),
                      border: Border.all(color: AppColors.greyLight, width: 1),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(responsive.size(7)),
                      child:
                          story.mediaType == 'video' &&
                              story.thumbnailUrl == null
                          ? Container(
                              color: AppColors.greyLight,
                              child: Center(
                                child: Icon(
                                  Icons.videocam_rounded,
                                  size: responsive.size(20),
                                  color: AppColors.greyMedium,
                                ),
                              ),
                            )
                          : CachedNetworkImage(
                              imageUrl: _getStoryImageUrl(
                                // For video stories, use thumbnail URL only if available
                                // Don't fallback to video URL as it can't be loaded as an image
                                story.mediaType == 'video'
                                    ? (story.thumbnailUrl ?? '')
                                    : story.mediaUrl,
                              ),
                              fit: BoxFit.cover,
                              cacheManager:
                                  AuthenticatedImageCacheManager.instance,
                              placeholder: (_, __) => Container(
                                color: AppColors.greyLight,
                                child: Center(
                                  child: SizedBox(
                                    width: responsive.size(18),
                                    height: responsive.size(18),
                                    child: const CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              ),
                              errorWidget: (_, __, ___) => Container(
                                color: AppColors.greyLight,
                                child: Icon(
                                  Icons.broken_image,
                                  size: responsive.size(20),
                                  color: AppColors.greyMedium,
                                ),
                              ),
                            ),
                    ),
                  ),
                  SizedBox(width: responsive.spacing(12)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Story ${index + 1}',
                          style: AppTextSizes.regular(context).copyWith(
                            color: AppColors.greyDark,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: responsive.spacing(4)),
                        Text(
                          '${_formatTimeAgo(story.createdAt)} • ${_formatDateTime(story.createdAt)}',
                          style: AppTextSizes.small(
                            context,
                          ).copyWith(color: AppColors.greyMedium),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Tappable views count - shows viewers list
            GestureDetector(
              onTap: () => _showViewersList(context, story, responsive),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: responsive.spacing(10),
                  vertical: responsive.spacing(6),
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(responsive.size(16)),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.visibility,
                      color: AppColors.primary,
                      size: responsive.size(14),
                    ),
                    SizedBox(width: responsive.spacing(4)),
                    Text(
                      '${_getStoryViewCount(story)}',
                      style: AppTextSizes.small(context).copyWith(
                        color: AppColors.primary,
                        fontSize: responsive.size(12),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: responsive.spacing(12)),
            // Delete button - matches AppBar delete icon style
            GestureDetector(
              onTap: () => _deleteStory(story),
              child: Container(
                padding: EdgeInsets.all(responsive.spacing(6)),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withValues(alpha: 0.1)
                      : AppColors.iconPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(responsive.size(8)),
                ),
                child: Icon(
                  Icons.delete,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : AppColors.iconPrimary,
                  size: responsive.size(20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ResponsiveSize responsive) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.photo_library_outlined,
            size: responsive.size(80),
            color: AppColors.greyMedium,
          ),
          SizedBox(height: responsive.spacing(16)),
          Text(
            'No Stories Yet',
            style: AppTextSizes.large(
              context,
            ).copyWith(color: AppColors.greyDark, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: responsive.spacing(8)),
          Text(
            'Add your first story to get started',
            style: AppTextSizes.regular(
              context,
            ).copyWith(color: AppColors.greyMedium),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _openStoryViewer(List<StoryModel> stories, int index) {
    // Only show the selected story, not all stories
    final selectedStory = stories[index];
    final singleStoryList = [selectedStory];

    final chatStoryModel = ChatStoryModel.fromMyStories(
      id: 'my_story',
      name: 'My Story',
      profileImage: selectedStory.mediaUrl,
      stories: singleStoryList,
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MyStoryViewerPage(
          story: chatStoryModel,
          socketStories: singleStoryList,
        ),
      ),
    );
  }

  void _deleteStory(StoryModel story) {
    // Check if offline before allowing delete
    if (!ConnectivityCache.instance.isOnline) {
      AppSnackbar.showOfflineWarning(
        context,
        "You're offline. Connect to internet",
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Story',
          style: AppTextSizes.large(
            context,
          ).copyWith(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to delete this story? This action cannot be undone.',
          style: AppTextSizes.regular(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: AppTextSizes.regular(
                context,
              ).copyWith(color: AppColors.greyMedium),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _performDeleteStory(story.id);
            },
            child: Text(
              'Delete',
              style: AppTextSizes.regular(
                context,
              ).copyWith(color: Colors.red, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _performDeleteStory(String storyId) async {
    final success = await ref
        .read(myStoriesProvider.notifier)
        .deleteStory(storyId);
    if (!mounted) return;
    if (success) {
      AppSnackbar.showSuccess(context, 'Story deleted successfully');
    } else {
      AppSnackbar.showError(context, 'Failed to delete story');
    }
  }

  int _getStoryViewCount(StoryModel story) {
    // For now, return a mock view count based on story age
    // In a real app, this would come from your backend/database
    return story.viewsCount;
  }

  void _showViewersList(
    BuildContext context,
    StoryModel story,
    ResponsiveSize responsive,
  ) {
    // Trigger a refresh to fetch latest viewers
    ref.read(storyViewersProvider(story.id).notifier).refresh();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _ViewersBottomSheetWidget(
        storyId: story.id,
        responsive: responsive,
        initialTotalViews: story.viewsCount,
      ),
    );
  }

  void _showDeleteAllDialog(List<StoryModel> stories) {
    // Check if offline before allowing delete
    if (!ConnectivityCache.instance.isOnline) {
      AppSnackbar.showOfflineWarning(
        context,
        "You're offline. Connect to internet",
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete All Stories',
          style: AppTextSizes.large(
            context,
          ).copyWith(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to delete all ${stories.length} stories? This action cannot be undone.',
          style: AppTextSizes.regular(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: AppTextSizes.regular(
                context,
              ).copyWith(color: AppColors.greyMedium),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _performDeleteAllStories(stories);
            },
            child: Text(
              'Delete All',
              style: AppTextSizes.regular(
                context,
              ).copyWith(color: Colors.red, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _performDeleteAllStories(List<StoryModel> stories) async {
    for (final s in stories) {
      await ref.read(myStoriesProvider.notifier).deleteStory(s.id);
    }
    if (!mounted) return;
    AppSnackbar.showSuccess(context, 'All stories deleted successfully');
    Navigator.of(context).pop();
  }

  String _getStoryImageUrl(String imageUrl) {
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

  String _formatDateTime(DateTime dateTime) {
    // Convert to local time if needed
    final localTime = dateTime.toLocal();
    final hour = localTime.hour;
    final minute = localTime.minute.toString().padLeft(2, '0');
    final amPm = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);

    return '$displayHour:$minute $amPm';
  }

  String _formatTimeAgo(DateTime createdTime) {
    final now = DateTime.now();
    final diff = now.difference(createdTime);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }
}

/// Separate widget for viewers bottom sheet with scroll controller
class _ViewersBottomSheetWidget extends ConsumerStatefulWidget {
  const _ViewersBottomSheetWidget({
    required this.storyId,
    required this.responsive,
    required this.initialTotalViews,
  });

  final String storyId;
  final ResponsiveSize responsive;
  final int initialTotalViews;

  @override
  ConsumerState<_ViewersBottomSheetWidget> createState() =>
      _ViewersBottomSheetWidgetState();
}

class _ViewersBottomSheetWidgetState
    extends ConsumerState<_ViewersBottomSheetWidget> {
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
    return Consumer(
      builder: (consumerContext, consumerRef, _) {
        final viewersState = consumerRef.watch(
          storyViewersProvider(widget.storyId),
        );
        final viewers = viewersState.viewers;
        final isLoading = viewersState.isLoading;
        final totalViews = viewersState.totalViews > widget.initialTotalViews
            ? viewersState.totalViews
            : widget.initialTotalViews;

        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey.shade900
                : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(widget.responsive.size(20)),
              topRight: Radius.circular(widget.responsive.size(20)),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: EdgeInsets.only(top: widget.responsive.spacing(12)),
                width: widget.responsive.size(40),
                height: widget.responsive.size(4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(
                    widget.responsive.size(2),
                  ),
                ),
              ),
              // Header
              Padding(
                padding: EdgeInsets.all(widget.responsive.spacing(16)),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(widget.responsive.spacing(10)),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.visibility,
                        color: AppColors.primary,
                        size: widget.responsive.size(22),
                      ),
                    ),
                    SizedBox(width: widget.responsive.spacing(12)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Story Views',
                            style: AppTextSizes.large(
                              context,
                            ).copyWith(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            isLoading
                                ? 'Loading viewers...'
                                : '$totalViews ${totalViews == 1 ? 'person' : 'people'} viewed',
                            style: AppTextSizes.small(
                              context,
                            ).copyWith(color: AppColors.greyMedium),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close,
                        color: AppColors.greyMedium,
                        size: widget.responsive.size(24),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: Colors.grey.shade200),
              // Viewers list
              Flexible(
                child: isLoading
                    ? Center(
                        child: Padding(
                          padding: EdgeInsets.all(
                            widget.responsive.spacing(32),
                          ),
                          child: const CircularProgressIndicator(),
                        ),
                      )
                    : viewers.isEmpty
                    ? _buildEmptyViewersState(context, widget.responsive)
                    : Stack(
                        children: [
                          ListView.builder(
                            controller: _scrollController,
                            physics: const BouncingScrollPhysics(),
                            shrinkWrap: true,
                            padding: EdgeInsets.only(
                              top: widget.responsive.spacing(8),
                              bottom: widget.responsive.spacing(100),
                            ),
                            itemCount: viewers.length,
                            itemBuilder: (listContext, index) {
                              final viewer = viewers[index];
                              return _buildViewerTile(
                                listContext,
                                viewer,
                                widget.responsive,
                              );
                            },
                          ),
                          // Scroll to top button
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
                                    backgroundColor:
                                        Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.grey[800]
                                        : Colors.white,
                                    foregroundColor:
                                        Theme.of(context).brightness ==
                                            Brightness.dark
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
      },
    );
  }

  Widget _buildEmptyViewersState(
    BuildContext context,
    ResponsiveSize responsive,
  ) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(responsive.spacing(32)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.visibility_off_outlined,
              size: responsive.size(48),
              color: AppColors.greyMedium,
            ),
            SizedBox(height: responsive.spacing(12)),
            Text(
              'No views yet',
              style: AppTextSizes.regular(context).copyWith(
                color: AppColors.greyMedium,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: responsive.spacing(4)),
            Text(
              'Share your story to get views',
              style: AppTextSizes.small(
                context,
              ).copyWith(color: AppColors.greyLight),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewerTile(
    BuildContext context,
    StoryViewerInfo viewer,
    ResponsiveSize responsive,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allContacts = ref.watch(contactsListProvider);

    // Get device contact name using ContactDisplayNameHelper
    final viewerName = ContactDisplayNameHelper.resolveDisplayName(
      contacts: allContacts,
      userId: viewer.viewer.id,
      mobileNo: viewer.viewer.mobileNumber ?? '',
      backendDisplayName: viewer.viewer.fullName,
      fallbackLabel: 'ChatAway user',
    );

    final chatPictureUrl = viewer.viewer.chatPicture;

    // Chat list style tile - simple and clean
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: responsive.spacing(16),
        vertical: responsive.spacing(11),
      ),
      child: Row(
        children: [
          // Avatar - same as chat list
          CachedCircleAvatar(
            key: ValueKey('viewer_avatar_${viewer.id}'),
            chatPictureUrl: chatPictureUrl,
            radius: responsive.size(24),
            backgroundColor: AppColors.lighterGrey,
            iconColor: AppColors.colorGrey,
            contactName: viewerName,
          ),
          SizedBox(width: responsive.spacing(12)),
          // Name and time - same as chat list
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  viewerName,
                  style: TextStyle(
                    fontSize: responsive.size(16),
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppColors.colorBlack,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: responsive.spacing(4)),
                Text(
                  _formatViewTime(viewer.viewedAt),
                  style: TextStyle(
                    fontSize: responsive.size(14),
                    color: isDark ? Colors.white70 : AppColors.colorGrey,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatViewTime(DateTime viewedAt) {
    final now = DateTime.now();
    final diff = now.difference(viewedAt);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }
}
