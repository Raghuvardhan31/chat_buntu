import 'package:chataway_plus/features/chat/presentation/pages/chat_list/chat_list_page.dart';
import 'package:chataway_plus/features/chat/presentation/providers/chat_list_providers/chat_list_stream.dart';
import 'package:chataway_plus/features/chat/models/chat_message_model.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chataway_plus/features/chat_stories/presentation/pages/chat_stories_page.dart'
    show ChatStoriesPage, chatStoriesPageKey;
import 'package:chataway_plus/features/group_chat/presentation/pages/group_chat_page.dart';
import 'package:chataway_plus/features/voice_call/presentation/pages/call_history_page.dart';
import 'package:chataway_plus/features/navigation/presentation/widgets/custom_bottom_nav_bar.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/core/themes/app_text_styles.dart';
import 'package:chataway_plus/core/constants/assets/image_assets.dart';
import 'package:chataway_plus/core/routes/navigation_service.dart';
import 'package:chataway_plus/features/mood_emoji/presentation/providers/mood_emoji_provider.dart';
import 'package:chataway_plus/features/mood_emoji/presentation/widgets/mood_emoji_circle.dart';
import 'package:chataway_plus/features/chat/data/services/chat_engine/index.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:chataway_plus/features/chat_stories/presentation/providers/story_providers.dart';

/// Main navigation page with bottom navigation bar
/// Contains 4 tabs: Chat List (default), Chat Stories, Group Chat, and Calls
/// Supports swipe gestures between pages with dynamic AppBar
class MainNavigationPage extends ConsumerStatefulWidget {
  const MainNavigationPage({super.key});

  @override
  ConsumerState<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends ConsumerState<MainNavigationPage> {
  int _currentIndex = 0; // Default to Chat List (index 0)
  late PageController _pageController;
  StreamSubscription<Map<String, dynamic>>? _forceDisconnectSub;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);

    // REMOVED: Force disconnect banner
    // User requested to remove the "Disconnected! Connected from another device" banner
    // The app will handle reconnection automatically in the background
    _forceDisconnectSub = ChatEngineService.instance.forceDisconnectStream
        .listen((payload) {
          if (!mounted) return;
          // Just log for debugging - no UI notification
          final reason = payload['reason']?.toString().trim();
          debugPrint('🔌 [ForceDisconnect] Reason: $reason');
          // Auto-reconnect happens in ChatEngineService
        });
  }

  @override
  void dispose() {
    _forceDisconnectSub?.cancel();
    _pageController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  // List of pages for bottom navigation
  late final List<Widget> _pages = [
    ChatListPage(key: chatListPageKey), // Index 0 - with global key
    ChatStoriesPage(key: chatStoriesPageKey), // Index 1 - with global key
    const GroupChatPage(), // Index 2 - Group Chat (to be implemented by service team)
    CallHistoryPage(key: callHistoryPageKey), // Index 3 - Calls
  ];

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _onBottomNavTapped(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
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

        return PopScope(
          canPop: !(_currentIndex == 1 && _isSearching) && _currentIndex == 0,
          onPopInvokedWithResult: (bool didPop, dynamic result) {
            if (didPop) return;

            // Handle back button behavior
            if (_currentIndex == 1 && _isSearching) {
              // In chat stories search mode - exit search instead of app
              setState(() {
                _isSearching = false;
                _searchController.clear();
                chatStoriesPageKey.currentState?.clearSearch();
              });
            } else if (_currentIndex != 0) {
              // In chat stories or calls page - go to chat list instead of exiting app
              _pageController.animateToPage(
                0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }
          },
          child: Scaffold(
            appBar: _buildFixedAppBar(context, responsive),
            body: PageView(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              children: _pages,
            ),
            bottomNavigationBar: StreamBuilder<List<ChatContactModel>>(
              stream: ChatListStream.instance.stream,
              initialData: ChatListStream.instance.currentList,
              builder: (context, snapshot) {
                final contacts = snapshot.data ?? [];
                final totalUnread = contacts.fold<int>(
                  0,
                  (sum, c) => sum + c.unreadCount,
                );
                return Consumer(
                  builder: (context, ref, _) {
                    final hasNewStories = ref.watch(hasNewStoriesProvider);
                    return CustomBottomNavBar(
                      currentIndex: _currentIndex,
                      onTap: _onBottomNavTapped,
                      hasNewStories: hasNewStories,
                      unreadMessageCount: totalUnread,
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  /// Fixed AppBar that stays consistent across both tabs
  /// Chats tab: ChatAway+ title + MoodEmoji + Settings
  /// Chat Stories tab: Chat Stories title + Add + Menu
  PreferredSizeWidget _buildFixedAppBar(
    BuildContext context,
    ResponsiveSize responsive,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppBar(
      backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      elevation: 0,
      titleSpacing: responsive.spacing(16),
      centerTitle: false,
      automaticallyImplyLeading: false,
      leadingWidth: 0,
      title: _currentIndex == 1 && _isSearching
          ? TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              autofocus:
                  true, // Show cursor immediately when entering search mode
              cursorColor: isDark ? Colors.white : AppColors.colorBlack,
              style: AppTextSizes.regular(context).copyWith(
                color: isDark ? Colors.white : AppColors.iconPrimary,
                fontSize: responsive.size(16),
              ),
              decoration: InputDecoration(
                hintText: "Search contacts",
                hintStyle: AppTextSizes.regular(context).copyWith(
                  color: isDark ? Colors.white54 : AppColors.colorGrey,
                  fontSize: responsive.size(16),
                ),
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (value) {
                chatStoriesPageKey.currentState?.setSearch(value);
              },
            )
          : Text(
              _currentIndex == 0
                  ? 'ChatAway+'
                  : _currentIndex == 1
                  ? 'Chat Stories'
                  : _currentIndex == 2
                  ? 'Group Chat'
                  : 'Calls',
              style: AppTextSizes.heading(context).copyWith(
                color: _currentIndex == 0
                    ? AppColors.primary
                    : (isDark ? Colors.white : AppColors.iconPrimary),
                fontWeight: FontWeight.bold,
                fontSize: responsive.size(20),
              ),
            ),
      actions: _currentIndex == 0
          ? [
              // Chats tab: MoodEmoji + Settings
              Padding(
                padding: EdgeInsets.only(right: responsive.spacing(8)),
                child: Consumer(
                  builder: (context, ref, child) {
                    final moodProvider = ref.watch(moodEmojiProvider);
                    return MoodEmojiCircle(provider: moodProvider);
                  },
                ),
              ),
              Padding(
                padding: EdgeInsets.only(right: responsive.spacing(16)),
                child: IconButton(
                  icon: Icon(
                    Icons.settings_suggest_sharp,
                    size: responsive.size(24),
                    color: isDark ? Colors.white : AppColors.iconPrimary,
                  ),
                  onPressed: () => NavigationService.goToSettingsMain(),
                ),
              ),
            ]
          : _currentIndex == 1
          ? [
              // Chat Stories tab: Add Photo + Add Video + Search + Menu
              Padding(
                padding: EdgeInsets.only(right: responsive.spacing(16)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_isSearching)
                      IconButton(
                        icon: Icon(
                          Icons.add_photo_alternate,
                          size: responsive.size(23),
                          color: isDark ? Colors.white : AppColors.iconPrimary,
                        ),
                        tooltip: 'Add Photo Story',
                        onPressed: () {
                          chatStoriesPageKey.currentState?.handleAddStory();
                        },
                        padding: EdgeInsets.all(responsive.spacing(6)),
                        constraints: BoxConstraints(
                          minWidth: responsive.size(36),
                          minHeight: responsive.size(36),
                        ),
                      ),
                    if (!_isSearching)
                      IconButton(
                        icon: Image.asset(
                          ImageAssets.addVideoIcon,
                          width: responsive.size(25),
                          height: responsive.size(25),
                          color: isDark ? Colors.white : AppColors.iconPrimary,
                        ),
                        tooltip: 'Add Video Story',
                        onPressed: () {
                          chatStoriesPageKey.currentState
                              ?.handleAddVideoStory();
                        },
                        padding: EdgeInsets.all(responsive.spacing(6)),
                        constraints: BoxConstraints(
                          minWidth: responsive.size(36),
                          minHeight: responsive.size(36),
                        ),
                      ),
                    IconButton(
                      icon: Icon(
                        _isSearching ? Icons.close : Icons.search,
                        color: isDark ? Colors.white : AppColors.iconPrimary,
                      ),
                      onPressed: () {
                        setState(() {
                          if (_isSearching) {
                            if (_searchController.text.isNotEmpty) {
                              _searchController.clear();
                              chatStoriesPageKey.currentState?.clearSearch();
                            } else {
                              _isSearching = false;
                            }
                          } else {
                            _isSearching = true;
                          }
                        });
                      },
                      padding: EdgeInsets.all(responsive.spacing(8)),
                      constraints: BoxConstraints(
                        minWidth: responsive.size(40),
                        minHeight: responsive.size(40),
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert,
                        color: isDark ? Colors.white : AppColors.iconPrimary,
                      ),
                      padding: EdgeInsets.all(responsive.spacing(8)),
                      constraints: BoxConstraints(
                        minWidth: responsive.size(40),
                        minHeight: responsive.size(40),
                      ),
                      offset: Offset(0, responsive.spacing(80)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(responsive.size(8)),
                      ),
                      elevation: 8.0,
                      color: Theme.of(context).colorScheme.surface,
                      onSelected: (value) {
                        if (value == 'profile') {
                          NavigationService.goToCurrentUserProfile();
                        } else if (value == 'blocked') {
                          NavigationService.goToBlockContacts();
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem<String>(
                          value: 'profile',
                          height: responsive.size(48),
                          padding: EdgeInsets.symmetric(
                            horizontal: responsive.spacing(24),
                            vertical: responsive.spacing(12),
                          ),
                          child: Text(
                            'Profile',
                            style: AppTextSizes.natural(context).copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ),
                        PopupMenuItem<String>(
                          value: 'blocked',
                          height: responsive.size(48),
                          padding: EdgeInsets.symmetric(
                            horizontal: responsive.spacing(24),
                            vertical: responsive.spacing(12),
                          ),
                          child: Text(
                            'Blocked Contacts',
                            style: AppTextSizes.natural(context).copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ]
          : _currentIndex == 2
          ? [
              // Group Chat tab: Add Group button (to be implemented by service team)
              Padding(
                padding: EdgeInsets.only(right: responsive.spacing(16)),
                child: IconButton(
                  icon: Icon(
                    Icons.group_add_rounded,
                    size: responsive.size(24),
                    color: isDark ? Colors.white : AppColors.iconPrimary,
                  ),
                  onPressed: () {
                    // Create new group — to be implemented by service team
                  },
                ),
              ),
            ]
          : _currentIndex == 3
          ? [
              // Calls tab: Search (future) — keep clean for now
              Padding(
                padding: EdgeInsets.only(right: responsive.spacing(16)),
                child: IconButton(
                  icon: Icon(
                    Icons.search,
                    size: responsive.size(24),
                    color: isDark ? Colors.white : AppColors.iconPrimary,
                  ),
                  onPressed: () {
                    // Search calls — future enhancement
                  },
                ),
              ),
            ]
          : [],
    );
  }
}
