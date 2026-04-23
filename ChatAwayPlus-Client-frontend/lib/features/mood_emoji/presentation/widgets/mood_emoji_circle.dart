import 'package:flutter/material.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:chataway_plus/features/mood_emoji/presentation/providers/mood_emoji_provider.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/core/themes/app_text_styles.dart';
import 'package:chataway_plus/core/snackbar/app_snackbar.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';

/// Personal mood emoji circle widget for ChatListPage AppBar
/// Shows colored emoji when active, grey emoji when expired/not set
class MoodEmojiCircle extends StatefulWidget {
  final MoodEmojiProvider provider;

  const MoodEmojiCircle({super.key, required this.provider});

  @override
  State<MoodEmojiCircle> createState() => _MoodEmojiCircleState();
}

class _MoodEmojiCircleState extends State<MoodEmojiCircle>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    widget.provider.addListener(_onProviderUpdate);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 0.4).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _syncPulse();
  }

  @override
  void dispose() {
    widget.provider.removeListener(_onProviderUpdate);
    _pulseController.dispose();
    super.dispose();
  }

  void _onProviderUpdate() {
    if (mounted) {
      _syncPulse();
      setState(() {});
    }
  }

  void _syncPulse() {
    if (widget.provider.isActive) {
      // Active emoji selected — stop blinking, show solid
      if (_pulseController.isAnimating) {
        _pulseController.stop();
        _pulseController.value = 0.0; // full opacity
      }
    } else {
      // Inactive: blink hint dot to prompt user
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isActive = widget.provider.isActive;
    final emoji = widget.provider.emojiDisplay;

    final screenWidth = MediaQuery.of(context).size.width;
    final responsive = ResponsiveSize(
      context: context,
      constraints: BoxConstraints(maxWidth: screenWidth),
      breakpoint: DeviceBreakpoint.fromWidth(screenWidth),
    );

    return GestureDetector(
      onTap: () => _showEmojiPicker(context),
      child: SizedBox(
        width: responsive.size(40),
        height: responsive.size(40),
        child: isActive
            // Active: show emoji solid (no blinking)
            ? Center(
                child: Text(
                  emoji,
                  style: TextStyle(fontSize: responsive.size(24)),
                ),
              )
            // Inactive: greyed emoji + blinking hint dot at top-right
            : Stack(
                clipBehavior: Clip.none,
                children: [
                  Center(
                    child: ColorFiltered(
                      colorFilter: const ColorFilter.matrix(<double>[
                        0.2126,
                        0.7152,
                        0.0722,
                        0,
                        0,
                        0.2126,
                        0.7152,
                        0.0722,
                        0,
                        0,
                        0.2126,
                        0.7152,
                        0.0722,
                        0,
                        0,
                        0,
                        0,
                        0,
                        1,
                        0,
                      ]),
                      child: Opacity(
                        opacity: 0.55,
                        child: Text(
                          emoji,
                          style: TextStyle(fontSize: responsive.size(24)),
                        ),
                      ),
                    ),
                  ),
                  // Blinking hint dot — top-right corner
                  Positioned(
                    top: responsive.size(2),
                    right: responsive.size(-2),
                    child: AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _pulseAnimation.value,
                          child: child,
                        );
                      },
                      child: Container(
                        width: responsive.size(10),
                        height: responsive.size(10),
                        decoration: const BoxDecoration(
                          color: Color(0xFF00E676),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  /// Show emoji picker with time duration selection
  void _showEmojiPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EmojiPickerSheet(provider: widget.provider),
    );
  }
}

/// Bottom sheet for emoji picker and time duration selection
class _EmojiPickerSheet extends StatefulWidget {
  final MoodEmojiProvider provider;

  const _EmojiPickerSheet({required this.provider});

  @override
  State<_EmojiPickerSheet> createState() => _EmojiPickerSheetState();
}

class _EmojiPickerSheetState extends State<_EmojiPickerSheet> {
  String? _selectedEmoji;
  Duration? _selectedDuration;
  bool _isOnDurationStep = false;
  String? _previousEmoji;

  // Available time durations (max 24 hours - no feeling continues more than 1 day)
  final List<Map<String, dynamic>> _durations = [
    {'label': '1m', 'duration': const Duration(minutes: 1)},
    {'label': '5m', 'duration': const Duration(minutes: 5)},
    {'label': '30m', 'duration': const Duration(minutes: 30)},
    {'label': '1h', 'duration': const Duration(hours: 1)},
    {'label': '2h', 'duration': const Duration(hours: 2)},
    {'label': '4h', 'duration': const Duration(hours: 4)},
    {'label': '6h', 'duration': const Duration(hours: 6)},
    {'label': '12h', 'duration': const Duration(hours: 12)},
    {'label': '24h', 'duration': const Duration(hours: 24)},
  ];

  @override
  void initState() {
    super.initState();
    // Prefill with current emoji if exists; go directly to duration step
    _previousEmoji = widget.provider.currentMoodEmoji?.emoji;
    _selectedEmoji = _previousEmoji;
    _selectedDuration = null;
    _isOnDurationStep = false; // always start on emoji screen
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final screenWidth = mediaQuery.size.width;

    final responsive = ResponsiveSize(
      context: context,
      constraints: BoxConstraints(maxWidth: screenWidth),
      breakpoint: DeviceBreakpoint.fromWidth(screenWidth),
    );

    final bool hasExisting = widget.provider.currentMoodEmoji?.emoji != null;
    final bool hasSelected = _selectedEmoji != null;
    final bool isInitial = !hasExisting && !hasSelected;

    Widget headerEmoji(String emoji, bool dimmed) {
      if (!dimmed) {
        return Text(emoji, style: TextStyle(fontSize: responsive.size(24)));
      }
      // Fully desaturate and fade for initial state
      return ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]),
        child: Opacity(
          opacity: 0.55,
          child: Text(emoji, style: TextStyle(fontSize: responsive.size(24))),
        ),
      );
    }

    return Container(
      height: screenHeight * 0.7,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(responsive.size(20)),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(responsive.spacing(16)),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: theme.dividerColor)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          'Your mood, your way!',
                          style: AppTextSizes.regular(
                            context,
                          ).copyWith(color: theme.colorScheme.onSurface),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: responsive.spacing(8)),
                      headerEmoji(
                        _selectedEmoji ?? widget.provider.emojiDisplay,
                        isInitial,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: theme.colorScheme.onSurface),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Content area
          Expanded(
            child: _isOnDurationStep
                ? _buildDurationSelector(responsive, theme)
                : _buildEmojiPicker(responsive, theme),
          ),
        ],
      ),
    );
  }

  Widget _buildEmojiPicker(ResponsiveSize responsive, ThemeData theme) {
    return Column(
      children: [
        Expanded(
          child: EmojiPicker(
            onEmojiSelected: (category, emoji) {
              setState(() {
                _selectedEmoji = emoji.emoji;
                _isOnDurationStep = true; // auto-advance to step 2
              });
            },
            config: Config(
              height: responsive.size(256),
              checkPlatformCompatibility: true,
              emojiViewConfig: EmojiViewConfig(
                emojiSizeMax: responsive.size(28),
                verticalSpacing: 0,
                horizontalSpacing: 0,
                gridPadding: EdgeInsets.zero,
                backgroundColor: theme.colorScheme.surface,
              ),
              skinToneConfig: SkinToneConfig(),
              categoryViewConfig: CategoryViewConfig(),
              bottomActionBarConfig: BottomActionBarConfig(),
              searchViewConfig: SearchViewConfig(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDurationSelector(ResponsiveSize responsive, ThemeData theme) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(responsive.spacing(16)),
      child: Column(
        children: [
          // Show selected emoji without border
          Center(
            child: Text(
              _selectedEmoji!,
              style: TextStyle(fontSize: responsive.size(64)),
            ),
          ),
          SizedBox(height: responsive.spacing(20)),

          // Duration options in horizontal grid (side by side)
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: responsive.size(320)),
              child: Wrap(
                spacing: responsive.spacing(10),
                runSpacing: responsive.spacing(10),
                alignment: WrapAlignment.center,
                children: _durations.map((duration) {
                  final isSelected = _selectedDuration == duration['duration'];
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedDuration = duration['duration'] as Duration;
                      });
                    },
                    child: SizedBox(
                      width: responsive.size(70),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: responsive.spacing(10),
                          vertical: responsive.spacing(8),
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withValues(alpha: 0.1)
                              : theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(
                            responsive.size(10),
                          ),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : theme.colorScheme.outlineVariant,
                            width: isSelected
                                ? responsive.size(1.5)
                                : responsive.size(1),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            duration['label'] as String,
                            style: AppTextSizes.small(context).copyWith(
                              fontSize: responsive.size(12),
                              color: isSelected
                                  ? AppColors.primary
                                  : theme.colorScheme.onSurface,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          SizedBox(height: responsive.spacing(18)),

          // Actions directly below timings
          Padding(
            padding: EdgeInsets.only(bottom: responsive.spacing(6)),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _isOnDurationStep = false;
                        _selectedDuration = null;
                        _selectedEmoji = _previousEmoji;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        vertical: responsive.spacing(8),
                      ),
                      side: BorderSide(
                        color: AppColors.primary,
                        width: responsive.size(1),
                      ),
                      minimumSize: Size(0, responsive.size(40)),
                    ),
                    child: Text(
                      'Back',
                      style: AppTextSizes.small(context).copyWith(
                        fontSize: responsive.size(12),
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: responsive.spacing(10)),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _selectedDuration == null
                        ? null
                        : _saveMoodEmoji,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      disabledBackgroundColor: AppColors.greyLight,
                      padding: EdgeInsets.symmetric(
                        vertical: responsive.spacing(8),
                      ),
                      minimumSize: Size(0, responsive.size(40)),
                    ),
                    child: Text(
                      'Save',
                      style: AppTextSizes.small(context).copyWith(
                        fontSize: responsive.size(12),
                        color: _selectedDuration == null
                            ? AppColors.greyMedium
                            : Colors.white,
                        fontWeight: FontWeight.w700,
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

  Future<void> _saveMoodEmoji() async {
    if (_selectedEmoji == null || _selectedDuration == null) return;

    final success = await widget.provider.updateMoodEmoji(
      emoji: _selectedEmoji!,
      duration: _selectedDuration!,
    );

    if (mounted) {
      Navigator.pop(context);
      if (success) {
        AppSnackbar.showSuccess(
          context,
          'Mood set to $_selectedEmoji',
          duration: const Duration(seconds: 2),
        );
      } else {
        AppSnackbar.showError(
          context,
          'Failed to set mood',
          duration: const Duration(seconds: 2),
        );
      }
    }
  }
}
