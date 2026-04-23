import 'package:flutter/material.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';

/// Emoji picker section widget for chat input
class EmojiPickerSection extends StatelessWidget {
  const EmojiPickerSection({
    super.key,
    required this.height,
    required this.responsive,
    required this.isDark,
    required this.onEmojiSelected,
  });

  final double height;
  final ResponsiveSize responsive;
  final bool isDark;
  final void Function(String emoji) onEmojiSelected;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SizedBox(
        height: height,
        child: EmojiPicker(
          onEmojiSelected: (category, emoji) {
            onEmojiSelected(emoji.emoji);
          },
          config: Config(
            height: height,
            checkPlatformCompatibility: true,
            emojiViewConfig: EmojiViewConfig(
              emojiSizeMax: responsive.size(28),
              backgroundColor: isDark
                  ? Theme.of(context).colorScheme.surface
                  : Colors.white,
            ),
            categoryViewConfig: CategoryViewConfig(
              backgroundColor: isDark
                  ? Theme.of(context).colorScheme.surface
                  : Colors.white,
              indicatorColor: AppColors.primary,
              iconColor: isDark ? Colors.white70 : Colors.grey.shade600,
              iconColorSelected: AppColors.primary,
            ),
            bottomActionBarConfig: BottomActionBarConfig(enabled: false),
            searchViewConfig: SearchViewConfig(
              backgroundColor: isDark
                  ? Theme.of(context).colorScheme.surface
                  : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
