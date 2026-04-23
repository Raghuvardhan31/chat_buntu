import 'package:flutter/material.dart';
import 'package:chataway_plus/core/themes/app_text_styles.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';

class MessageReactionBar extends StatelessWidget {
  const MessageReactionBar({
    super.key,
    required this.onReactionSelected,
    this.reactions,
    this.selectedEmoji,
    this.padding,
    this.backgroundColor,
    this.showContainer = true,
  });

  final ValueChanged<String> onReactionSelected;
  final List<String>? reactions;
  final String? selectedEmoji;
  final EdgeInsets? padding;
  final Color? backgroundColor;
  final bool showContainer;

  static const List<String> defaultReactions = <String>[
    '👍',
    '❤️',
    '😂',
    '😮',
    '😢',
    '🙏',
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ResponsiveLayoutBuilder(
      builder: (context, constraints, breakpoint) {
        final responsive = ResponsiveSize(
          context: context,
          constraints: constraints,
          breakpoint: breakpoint,
        );

        final effectivePadding =
            padding ?? EdgeInsets.symmetric(horizontal: responsive.spacing(10));

        final emojis = reactions ?? defaultReactions;

        final reactionButtons = emojis.map((emoji) {
          final isSelected = selectedEmoji == emoji;
          return _ReactionButton(
            emoji: emoji,
            isSelected: isSelected,
            onTap: () => onReactionSelected(emoji),
            responsive: responsive,
            isDark: isDark,
          );
        }).toList();

        // If the emoji buttons do not fit within available width, make the row
        // horizontally scrollable to avoid RenderFlex overflow on small screens.
        final buttonSize = responsive.size(42);
        final gap = responsive.spacing(8);
        final estimatedWidth =
            (reactionButtons.length * buttonSize) +
            ((reactionButtons.length - 1).clamp(0, 999) * gap);

        final content = estimatedWidth <= constraints.maxWidth
            ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: reactionButtons,
              )
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (int i = 0; i < reactionButtons.length; i++) ...[
                      if (i != 0) SizedBox(width: gap),
                      reactionButtons[i],
                    ],
                  ],
                ),
              );

        if (!showContainer) {
          return Padding(padding: effectivePadding, child: content);
        }

        return Padding(
          padding: effectivePadding,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: responsive.spacing(10),
                vertical: responsive.spacing(8),
              ),
              decoration: BoxDecoration(
                color:
                    backgroundColor ??
                    (isDark
                        ? Theme.of(context).colorScheme.surface
                        : Colors.white),
                borderRadius: BorderRadius.circular(responsive.size(14)),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                    blurRadius: responsive.size(10),
                    offset: Offset(0, responsive.spacing(4)),
                  ),
                ],
              ),
              child: content,
            ),
          ),
        );
      },
    );
  }
}

class _ReactionButton extends StatelessWidget {
  const _ReactionButton({
    required this.emoji,
    required this.isSelected,
    required this.onTap,
    required this.responsive,
    required this.isDark,
  });

  final String emoji;
  final bool isSelected;
  final VoidCallback onTap;
  final ResponsiveSize responsive;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final size = responsive.size(42);
    final emojiSize = responsive.size(28);

    return InkWell(
      borderRadius: BorderRadius.circular(size),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.12)
              : (isDark ? const Color(0xFF2C2C2C) : Colors.white),
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark ? Colors.white12 : AppColors.greyLight),
            width: responsive.size(1),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.only(bottom: responsive.spacing(1)),
          child: Text(
            emoji,
            style: AppTextSizes.custom(
              context,
              18,
              fontWeight: FontWeight.w400,
              height: 1.0,
              color: isDark ? Colors.white : AppColors.iconPrimary,
            ).copyWith(fontSize: emojiSize),
          ),
        ),
      ),
    );
  }
}
