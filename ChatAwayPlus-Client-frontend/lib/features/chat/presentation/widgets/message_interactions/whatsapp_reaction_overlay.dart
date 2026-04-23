import 'package:flutter/material.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:chataway_plus/features/chat/models/chat_message_model.dart';
import 'package:chataway_plus/features/chat/presentation/widgets/message_interactions/message_reaction_bar.dart';
import 'dart:ui';

/// Types of actions that can be performed on a message from the reaction overlay
enum MessageActionType { edit, forward, delete, reply, copy, select }

/// A WhatsApp-style overlay that appears on message long-press.
/// It contains a reaction bar and common message actions (Edit, Forward, Delete).
class WhatsAppReactionOverlay extends StatelessWidget {
  const WhatsAppReactionOverlay({
    super.key,
    required this.message,
    required this.onReactionSelected,
    required this.onPlusTap,
    this.selectedEmoji,
    this.animation,
    required this.onActionSelected,
  });

  final ChatMessageModel message;
  final ValueChanged<String> onReactionSelected;
  final VoidCallback onPlusTap;
  final void Function(MessageActionType action) onActionSelected;
  final String? selectedEmoji;
  final Animation<double>? animation;

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

        Widget content = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 1. Reaction Bar (Pill shape)
            _buildReactionPill(isDark, responsive),
            SizedBox(height: responsive.spacing(12)),
            // 2. Action Bar (Secondary list of actions)
            _buildActionList(isDark, responsive),
          ],
        );

        if (animation != null) {
          return FadeTransition(
            opacity: animation!,
            child: ScaleTransition(
              scale: CurvedAnimation(
                parent: animation!,
                curve: Curves.easeOutBack,
              ),
              child: content,
            ),
          );
        }

        return content;
      },
    );
  }


  Widget _buildReactionPill(bool isDark, ResponsiveSize responsive) {
     final bgColor = isDark 
        ? const Color(0xFF2C2C2C).withValues(alpha: 0.95) 
        : Colors.white.withValues(alpha: 0.95);

    return IntrinsicWidth(
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: responsive.spacing(12),
          vertical: responsive.spacing(6),
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(responsive.size(30)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(responsive.size(30)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...MessageReactionBar.defaultReactions.map((emoji) {
                  final isSelected = selectedEmoji == emoji;
                  return _EmojiButton(
                    emoji: emoji,
                    isSelected: isSelected,
                    onTap: () => onReactionSelected(emoji),
                    responsive: responsive,
                  );
                }),
                _EmojiButton(
                  emoji: '+',
                  onTap: onPlusTap,
                  isPlus: true,
                  responsive: responsive,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionList(bool isDark, ResponsiveSize responsive) {
    final bgColor = isDark 
        ? const Color(0xFF2C2C2C).withValues(alpha: 0.95) 
        : Colors.white.withValues(alpha: 0.95);

    return IntrinsicWidth(
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: responsive.spacing(4),
          vertical: responsive.spacing(4),
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(responsive.size(12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ActionButton(
              icon: Icons.reply,
              label: 'Reply',
              onTap: () => onActionSelected(MessageActionType.reply),
              responsive: responsive,
            ),
            _ActionButton(
              icon: Icons.copy,
              label: 'Copy',
              onTap: () => onActionSelected(MessageActionType.copy),
              responsive: responsive,
            ),
            _ActionButton(
              icon: Icons.check_circle_outline,
              label: 'Select',
              onTap: () => onActionSelected(MessageActionType.select),
              responsive: responsive,
            ),
            _ActionButton(
              icon: Icons.forward,
              label: 'Forward',
              onTap: () => onActionSelected(MessageActionType.forward),
              responsive: responsive,
            ),
            _ActionButton(
              icon: Icons.delete_outline,
              label: 'Delete',
              onTap: () => onActionSelected(MessageActionType.delete),
              isDestructive: true,
              responsive: responsive,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
    required this.responsive,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;
  final ResponsiveSize responsive;

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? Colors.red : AppColors.primary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: responsive.spacing(12),
          vertical: responsive.spacing(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: responsive.size(22)),
            SizedBox(height: responsive.spacing(4)),
            Text(
              label,
              style: TextStyle(
                fontSize: responsive.size(10),
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmojiButton extends StatelessWidget {
  const _EmojiButton({
    required this.emoji,
    required this.onTap,
    this.isSelected = false,
    this.isPlus = false,
    required this.responsive,
  });

  final String emoji;
  final VoidCallback onTap;
  final bool isSelected;
  final bool isPlus;
  final ResponsiveSize responsive;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: responsive.spacing(isSelected ? 10 : 8),
          vertical: responsive.spacing(4),
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          emoji,
          style: TextStyle(
            fontSize: isPlus ? responsive.size(24) : responsive.size(26),
            color: isPlus ? AppColors.primary : null,
            fontWeight: isPlus ? FontWeight.bold : null,
          ),
        ),
      ),
    );
  }
}

