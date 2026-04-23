import 'package:flutter/material.dart';
import 'package:chataway_plus/core/themes/app_text_styles.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/core/constants/assets/image_assets.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';

/// Custom bottom navigation bar for ChatAway+
/// WhatsApp-style with 4 tabs: Chats, Stories, Groups, and Calls
/// Features: pill/capsule highlight on selected tab, unread badge on Chats
class CustomBottomNavBar extends StatefulWidget {
  final int currentIndex;
  final Function(int) onTap;
  final bool hasNewStories;
  final int missedCallCount;
  final int unreadMessageCount;

  const CustomBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.hasNewStories = false,
    this.missedCallCount = 0,
    this.unreadMessageCount = 0,
  });

  @override
  State<CustomBottomNavBar> createState() => _CustomBottomNavBarState();
}

class _CustomBottomNavBarState extends State<CustomBottomNavBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 0.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _syncPulse();
  }

  @override
  void didUpdateWidget(covariant CustomBottomNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hasNewStories != widget.hasNewStories) {
      _syncPulse();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _syncPulse() {
    if (widget.hasNewStories) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedColor =
        Theme.of(context).bottomNavigationBarTheme.selectedItemColor ??
        AppColors.primary;
    final unselectedColor =
        Theme.of(context).bottomNavigationBarTheme.unselectedItemColor ??
        AppColors.iconSecondary;
    // WhatsApp-style: light tint of primary for the pill background
    final pillColor = isDark
        ? selectedColor.withValues(alpha: 0.15)
        : selectedColor.withValues(alpha: 0.12);

    return ResponsiveLayoutBuilder(
      builder: (context, constraints, breakpoint) {
        final responsive = ResponsiveSize(
          context: context,
          constraints: constraints,
          breakpoint: breakpoint,
        );

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).bottomNavigationBarTheme.backgroundColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: responsive.size(8),
                offset: Offset(0, -responsive.size(2)),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: responsive.spacing(6)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // Tab 0: Chats
                  _buildNavItem(
                    index: 0,
                    responsive: responsive,
                    selectedColor: selectedColor,
                    unselectedColor: unselectedColor,
                    pillColor: pillColor,
                    label: 'Chats',
                    child: _buildChatsIcon(
                      responsive: responsive,
                      color: widget.currentIndex == 0
                          ? selectedColor
                          : unselectedColor,
                    ),
                  ),
                  // Tab 1: Stories
                  _buildNavItem(
                    index: 1,
                    responsive: responsive,
                    selectedColor: selectedColor,
                    unselectedColor: unselectedColor,
                    pillColor: pillColor,
                    label: 'Stories',
                    child: _buildStoriesIcon(
                      responsive: responsive,
                      color: widget.currentIndex == 1
                          ? selectedColor
                          : unselectedColor,
                    ),
                  ),
                  // Tab 2: Groups
                  _buildNavItem(
                    index: 2,
                    responsive: responsive,
                    selectedColor: selectedColor,
                    unselectedColor: unselectedColor,
                    pillColor: pillColor,
                    label: 'Groups',
                    child: _buildGroupsIcon(
                      responsive: responsive,
                      color: widget.currentIndex == 2
                          ? selectedColor
                          : unselectedColor,
                    ),
                  ),
                  // Tab 3: Calls
                  _buildNavItem(
                    index: 3,
                    responsive: responsive,
                    selectedColor: selectedColor,
                    unselectedColor: unselectedColor,
                    pillColor: pillColor,
                    label: 'Calls',
                    child: _buildCallsIcon(
                      responsive: responsive,
                      color: widget.currentIndex == 3
                          ? selectedColor
                          : unselectedColor,
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

  /// Builds a single nav item with WhatsApp-style pill background when selected
  Widget _buildNavItem({
    required int index,
    required ResponsiveSize responsive,
    required Color selectedColor,
    required Color unselectedColor,
    required Color pillColor,
    required String label,
    required Widget child,
  }) {
    final isSelected = widget.currentIndex == index;

    return GestureDetector(
      onTap: () => widget.onTap(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: responsive.size(80),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon with pill background
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              padding: EdgeInsets.symmetric(
                horizontal: responsive.spacing(isSelected ? 16 : 12),
                vertical: responsive.spacing(4),
              ),
              decoration: BoxDecoration(
                color: isSelected ? pillColor : Colors.transparent,
                borderRadius: BorderRadius.circular(responsive.size(16)),
              ),
              child: child,
            ),
            SizedBox(height: responsive.spacing(2)),
            // Label
            Text(
              label,
              style: AppTextSizes.small(context).copyWith(
                fontSize: responsive.size(11),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? selectedColor : unselectedColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the Chats tab icon with optional unread badge
  Widget _buildChatsIcon({
    required ResponsiveSize responsive,
    required Color color,
  }) {
    final icon = Image.asset(
      ImageAssets.alignLeft,
      width: responsive.size(24),
      height: responsive.size(24),
      color: color,
    );

    if (widget.unreadMessageCount <= 0) return icon;

    return SizedBox(
      width: responsive.size(34),
      height: responsive.size(26),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(left: 0, bottom: 0, child: icon),
          // Unread count badge — top-right
          Positioned(
            top: -responsive.size(4),
            right: -responsive.size(8),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: responsive.spacing(5),
                vertical: responsive.spacing(1),
              ),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(responsive.size(10)),
              ),
              child: Text(
                widget.unreadMessageCount > 99
                    ? '99+'
                    : '${widget.unreadMessageCount}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: responsive.size(9),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the Calls tab icon with an optional missed call badge
  Widget _buildCallsIcon({
    required ResponsiveSize responsive,
    required Color color,
  }) {
    final icon = Icon(
      Icons.call_rounded,
      size: responsive.size(24),
      color: color,
    );

    if (widget.missedCallCount <= 0) return icon;

    return SizedBox(
      width: responsive.size(34),
      height: responsive.size(30),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(left: 0, bottom: 0, child: icon),
          // Missed call count badge — top-right
          Positioned(
            top: -responsive.size(2),
            right: -responsive.size(8),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: responsive.spacing(5),
                vertical: responsive.spacing(1),
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                borderRadius: BorderRadius.circular(responsive.size(10)),
              ),
              child: Text(
                '${widget.missedCallCount}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: responsive.size(9),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the Stories tab icon with an optional blinking notification dot
  /// positioned above and to the right of the icon.
  /// Dot uses the predefined AppColors.storiesCottonCandySky gradient
  /// and blinks when new stories exist.
  Widget _buildStoriesIcon({
    required ResponsiveSize responsive,
    required Color color,
  }) {
    final icon = Image.asset(
      ImageAssets.chatStoriesIcon,
      width: responsive.size(24),
      height: responsive.size(24),
      color: color,
    );

    if (!widget.hasNewStories) return icon;

    return SizedBox(
      width: responsive.size(34),
      height: responsive.size(30),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(left: 0, bottom: 0, child: icon),
          // Blinking stories ring color dot — top-right
          Positioned(
            top: -responsive.size(1),
            right: -responsive.size(10),
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Opacity(opacity: _pulseAnimation.value, child: child);
              },
              child: Container(
                width: responsive.size(12),
                height: responsive.size(12),
                decoration: BoxDecoration(
                  gradient: AppColors.storiesCottonCandySky,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the Groups tab icon
  Widget _buildGroupsIcon({
    required ResponsiveSize responsive,
    required Color color,
  }) {
    return Icon(Icons.groups_rounded, size: responsive.size(24), color: color);
  }
}
