import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:chataway_plus/core/themes/app_text_styles.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/core/constants/assets/image_assets.dart';
import 'package:chataway_plus/core/snackbar/app_snackbar.dart';
import 'package:chataway_plus/features/chat_stories/data/models/chat_story_models.dart';
import 'package:chataway_plus/features/chat_stories/presentation/widgets/story_navigation_gesture_layer.dart';
import 'package:chataway_plus/features/chat_stories/presentation/widgets/story_progress_bar.dart';
import 'package:chataway_plus/features/chat_stories/presentation/widgets/story_slide_renderer.dart';
import 'package:chataway_plus/features/chat_stories/presentation/widgets/story_viewer_header.dart';
import 'package:chataway_plus/core/storage/token_storage.dart';
import 'package:chataway_plus/features/chat/data/services/chat_engine/index.dart';

class ContactStoryViewerPage extends ConsumerStatefulWidget {
  const ContactStoryViewerPage({
    super.key,
    required this.story,
    this.initialSlide = 0,
    this.onSlideFullyWatched,
    this.onStoryFullyWatched,
  });

  final ChatStoryModel story;

  final int initialSlide;

  final ValueChanged<int>? onSlideFullyWatched;

  /// Callback when story is fully watched (all slides completed via progress ring)
  final VoidCallback? onStoryFullyWatched;

  @override
  ConsumerState<ContactStoryViewerPage> createState() =>
      _ContactStoryViewerPageState();
}

class _ContactStoryViewerPageState extends ConsumerState<ContactStoryViewerPage>
    with TickerProviderStateMixin {
  late final PageController _pageController;
  late final AnimationController _progressController;

  int _currentSlide = 0;
  bool _isReplying = false;
  bool _slideMarkedViewed = false;
  bool _mediaReady = false;
  final TextEditingController _replyController = TextEditingController();
  final FocusNode _replyFocusNode = FocusNode();

  List<ChatStorySlide> get _slides => widget.story.slides;

  /// Get duration for a specific slide index
  /// Video slides use their video duration, image slides default to 5 seconds
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

  @override
  void initState() {
    super.initState();

    final slides = _slides;
    final initial = slides.isEmpty
        ? 0
        : (widget.initialSlide >= 0 && widget.initialSlide < slides.length)
        ? widget.initialSlide
        : 0;
    _currentSlide = initial;
    _pageController = PageController(initialPage: initial);
    _progressController =
        AnimationController(vsync: this, duration: _getSlideDuration(initial))
          ..addListener(() {
            // Mark slide as viewed once progress reaches 40%
            if (!_slideMarkedViewed && _progressController.value >= 0.4) {
              _slideMarkedViewed = true;
              widget.onSlideFullyWatched?.call(_currentSlide);
            }
          })
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              if (_isReplying) {
                debugPrint(
                  '📩 [StoryReply] Progress completed while replying — ignoring auto-next',
                );
                return;
              }
              // Ring completed naturally
              _goNextNatural();
            }
          });

    if (_slides.isNotEmpty) {
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

    if (_isReplying) return;
    if (_progressController.isAnimating) return;

    _progressController.forward(from: 0);
  }

  void _resumeProgressIfAllowed() {
    if (_isReplying) return;
    if (!_mediaReady) return;
    if (_progressController.isAnimating) return;
    _progressController.forward();
  }

  @override
  void dispose() {
    _progressController.dispose();
    _pageController.dispose();
    _replyController.dispose();
    _replyFocusNode.dispose();
    super.dispose();
  }

  /// Called when progress ring completes naturally
  void _goNextNatural() {
    if (_slides.isEmpty) {
      Navigator.of(context).maybePop();
      return;
    }

    // Already marked at 40% via listener, but ensure it fires for edge cases
    if (!_slideMarkedViewed) {
      widget.onSlideFullyWatched?.call(_currentSlide);
    }
    _slideMarkedViewed = false;

    if (_currentSlide >= _slides.length - 1) {
      widget.onStoryFullyWatched?.call();
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

  /// Called when user taps to skip - mark as watched if progress >= 40% OR skipping forward
  void _goNextManual() {
    if (_slides.isEmpty) {
      Navigator.of(context).maybePop();
      return;
    }

    // Mark as watched if progress >= 40% OR user is skipping to next
    if (_mediaReady &&
        !_slideMarkedViewed &&
        (_progressController.value >= 0.4 ||
            _currentSlide < _slides.length - 1)) {
      widget.onSlideFullyWatched?.call(_currentSlide);
    }
    _slideMarkedViewed = false;

    if (_currentSlide >= _slides.length - 1) {
      widget.onStoryFullyWatched?.call();
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
    // Mark current slide as watched before going back (user has seen it)
    if (_mediaReady &&
        !_slideMarkedViewed &&
        _progressController.value >= 0.4) {
      widget.onSlideFullyWatched?.call(_currentSlide);
    }
    _slideMarkedViewed = false;

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

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayoutBuilder(
      builder: (context, constraints, breakpoint) {
        final responsive = ResponsiveSize(
          context: context,
          constraints: constraints,
          breakpoint: breakpoint,
        );

        final story = widget.story;

        return Scaffold(
          backgroundColor: Colors.black,
          resizeToAvoidBottomInset: false,
          body: SafeArea(
            child: Stack(
              children: [
                Positioned.fill(
                  child: _slides.isEmpty
                      ? Center(
                          child: Text(
                            'No story',
                            style: AppTextSizes.heading(context).copyWith(
                              color: Colors.white,
                              fontSize: responsive.size(18),
                            ),
                          ),
                        )
                      : PageView.builder(
                          controller: _pageController,
                          itemCount: _slides.length,
                          onPageChanged: (idx) {
                            _slideMarkedViewed = false;
                            _mediaReady = false;
                            setState(() => _currentSlide = idx);
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
                                  if (!_isReplying) {
                                    _progressController.forward(from: 0);
                                  }
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
                        if (_slides.isNotEmpty)
                          StoryProgressBar(
                            totalSegments: _slides.length,
                            currentIndex: _currentSlide,
                            progressController: _progressController,
                            responsive: responsive,
                          ),
                        SizedBox(height: responsive.spacing(10)),
                        StoryViewerHeader(
                          responsive: responsive,
                          avatarImageUrl: story.profileImage.trim().isEmpty
                              ? null
                              : story.profileImage,
                          title: story.name,
                          subtitle:
                              _slides.isNotEmpty &&
                                  _currentSlide < _slides.length
                              ? _slides[_currentSlide].timeAgo
                              : story.timeAgo,
                          onClose: () => Navigator.of(context).maybePop(),
                        ),
                      ],
                    ),
                  ),
                ),
                // Bottom: Reply input or reply button
                // Use viewInsets to lift above keyboard without resizing the story
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                  child: _isReplying
                      ? _buildReplyInputBar(responsive)
                      : _buildReplyButton(responsive),
                ),
                // Navigation gesture layer - positioned to exclude header (top 100px) and bottom action bar.
                // Hidden when replying so the reply input & send button can receive taps.
                if (!_isReplying)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 100, // Exclude header area
                    bottom: 80, // Exclude bottom action bar
                    child: StoryNavigationGestureLayer(
                      onPrev: _goPrev,
                      onNext: _goNextManual,
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

  /// Build reply button (bottom right)
  Widget _buildReplyButton(ResponsiveSize responsive) {
    return Padding(
      padding: EdgeInsets.only(
        left: responsive.spacing(14),
        right: responsive.spacing(14),
        bottom: responsive.spacing(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Padding(
            padding: EdgeInsets.only(right: responsive.spacing(4)),
            child: GestureDetector(
              onTap: () {
                debugPrint(
                  '📩 [StoryReply] Reply button tapped — opening input and pausing progress',
                );
                // Show reply input bar and pause story
                setState(() {
                  _isReplying = true;
                });
                _progressController.stop();
                // Focus the text field after a short delay
                Future.delayed(const Duration(milliseconds: 100), () {
                  _replyFocusNode.requestFocus();
                });
              },
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: responsive.spacing(14),
                  vertical: responsive.spacing(10),
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(responsive.size(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.arrow_outward_rounded,
                      color: Colors.white,
                      size: responsive.size(20),
                    ),
                    SizedBox(width: responsive.spacing(6)),
                    Text(
                      'Reply',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: responsive.size(14),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build reply input bar (shown when replying) - WhatsApp style
  Widget _buildReplyInputBar(ResponsiveSize responsive) {
    return Container(
      padding: EdgeInsets.only(
        left: responsive.spacing(14),
        right: responsive.spacing(14),
        bottom: responsive.spacing(16),
        top: responsive.spacing(10),
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Text input field with send button - WhatsApp style pill design
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(responsive.size(28)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Chat stories icon prefix
                Padding(
                  padding: EdgeInsets.only(left: responsive.spacing(16)),
                  child: Image.asset(
                    ImageAssets.chatStoriesIcon,
                    width: responsive.size(20),
                    height: responsive.size(20),
                    color: Colors.grey.shade600,
                  ),
                ),
                // "Stories comment:" text prefix
                Padding(
                  padding: EdgeInsets.only(left: responsive.spacing(8)),
                  child: Text(
                    'Stories comment:',
                    style: AppTextSizes.regular(context).copyWith(
                      color: Colors.grey.shade600,
                      fontSize: responsive.size(14),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                // Text field
                Expanded(
                  child: TextField(
                    controller: _replyController,
                    focusNode: _replyFocusNode,
                    cursorColor: Colors.black87,
                    selectionControls: MaterialTextSelectionControls(),
                    decoration:
                        const InputDecoration.collapsed(
                          hintText: 'Type here...',
                        ).copyWith(
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                          hintStyle: AppTextSizes.regular(context).copyWith(
                            color: Colors.grey.shade400,
                            fontSize: responsive.size(15),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: responsive.spacing(8),
                            vertical: responsive.spacing(14),
                          ),
                        ),
                    style: AppTextSizes.regular(context).copyWith(
                      color: Colors.black87,
                      fontSize: responsive.size(15),
                      height: 1.4,
                    ),
                    maxLines: 1,
                    minLines: 1,
                    textInputAction: TextInputAction.send,
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: (_) {
                      debugPrint('📩 [StoryReply] Keyboard send pressed');
                      _sendReply();
                    },
                  ),
                ),
                // Send button inside the pill
                GestureDetector(
                  onTap: () {
                    debugPrint('📩 [StoryReply] Send button tapped');
                    _sendReply();
                  },
                  child: Container(
                    margin: EdgeInsets.all(responsive.spacing(6)),
                    padding: EdgeInsets.all(responsive.spacing(10)),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary,
                          AppColors.primary.withValues(alpha: 0.85),
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: responsive.size(20),
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

  Future<void> _sendReply() async {
    final userText = _replyController.text.trim();
    debugPrint('📩 [StoryReply] _sendReply called, userText="$userText"');
    if (userText.isEmpty) {
      debugPrint('📩 [StoryReply] Empty text — aborting');
      return;
    }

    // Prepend "Stories comment : " prefix to the message
    final message = 'Stories comment : $userText';

    final receiverId = widget.story.userId ?? '';
    debugPrint(
      '📩 [StoryReply] receiverId="$receiverId", storyId="${widget.story.id}"',
    );
    if (receiverId.isEmpty) {
      debugPrint('📩 [StoryReply] receiverId is empty — aborting');
      if (mounted) {
        AppSnackbar.showError(context, 'Cannot send reply: unknown contact');
      }
      return;
    }

    // Capture ScaffoldMessenger BEFORE any async work / page pop so we can
    // still show a snackbar even after this page is disposed.
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // Close reply input and resume story FIRST — before any async work.
    // This prevents the progress controller from completing and popping
    // the page while we wait for the send to finish.
    setState(() {
      _isReplying = false;
      _replyController.clear();
    });
    _replyFocusNode.unfocus();
    _resumeProgressIfAllowed();
    debugPrint(
      '📩 [StoryReply] UI cleared, progress resumed. mounted=$mounted',
    );

    // Now send in background — even if the page is popped, the message
    // still gets saved to local DB and sent via socket.
    try {
      final chatEngine = ChatEngineService.instance;
      debugPrint(
        '📩 [StoryReply] ChatEngine.currentUserId=${chatEngine.currentUserId}, isOnline=${chatEngine.isOnline}',
      );

      // Ensure ChatEngine is initialized (use TokenSecureStorage directly
      // instead of ref, which may be disposed after the page pops).
      if (chatEngine.currentUserId == null) {
        debugPrint(
          '📩 [StoryReply] ChatEngine not initialized — fetching userId from storage',
        );
        final uid =
            await TokenSecureStorage.instance.getCurrentUserIdUUID() ?? '';
        debugPrint('📩 [StoryReply] Got uid="$uid"');
        if (uid.isNotEmpty) {
          await chatEngine.initialize(uid);
          debugPrint('📩 [StoryReply] ChatEngine initialized');
        } else {
          debugPrint(
            '📩 [StoryReply] uid is empty — cannot initialize ChatEngine',
          );
        }
      }

      debugPrint(
        '📩 [StoryReply] Calling sendMessage(receiverId=$receiverId, messageType=text, msgLength=${message.length})',
      );
      final sentMessage = await chatEngine.sendMessage(
        messageText: message,
        receiverId: receiverId,
        messageType: 'text',
      );

      debugPrint(
        '📩 [StoryReply] sendMessage returned: ${sentMessage != null ? "SUCCESS (id=${sentMessage.id})" : "NULL"}',
      );
      if (sentMessage != null) {
        _showSnackbarSafe(scaffoldMessenger, 'Reply sent');
      } else {
        _showSnackbarSafe(scaffoldMessenger, 'Failed to send reply');
      }
    } catch (e, stack) {
      debugPrint('❌ [StoryReply] Error: $e');
      debugPrint('❌ [StoryReply] Stack: $stack');
      _showSnackbarSafe(scaffoldMessenger, 'Failed to send reply');
    }
  }

  void _showSnackbarSafe(ScaffoldMessengerState messenger, String message) {
    try {
      messenger.showSnackBar(
        SnackBar(
          content: Text(message, textAlign: TextAlign.center),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (_) {
      // ScaffoldMessenger may have been disposed if the entire navigator
      // was replaced — silently ignore.
    }
  }
}
