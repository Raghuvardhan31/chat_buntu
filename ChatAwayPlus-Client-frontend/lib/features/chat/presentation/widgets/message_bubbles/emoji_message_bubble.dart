// lib/features/chat/presentation/widgets/message_bubbles/emoji_message_bubble.dart

import 'package:flutter/material.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/core/themes/app_text_styles.dart';
import 'package:chataway_plus/features/chat/models/chat_message_model.dart';
import 'package:chataway_plus/features/chat/presentation/widgets/chat_ui/message_delivery_status_icon.dart';

/// Emoji-only message bubble — renders pure emoji messages inside a styled bubble
/// with proper background, border radius, and inline timestamp for both sender/receiver.
class EmojiMessageBubble extends StatelessWidget {
  const EmojiMessageBubble({
    super.key,
    required this.message,
    required this.isSender,
    this.showTail = true,
  });

  final ChatMessageModel message;
  final bool isSender;
  final bool showTail;

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayoutBuilder(
      builder: (context, constraints, breakpoint) {
        final responsive = ResponsiveSize(
          context: context,
          constraints: constraints,
          breakpoint: breakpoint,
        );
        final isDark = Theme.of(context).brightness == Brightness.dark;

        final senderBubbleColor = isDark
            ? const Color(0xFF1E3A5F)
            : AppColors.senderBubble;
        final receiverBubbleColor = isDark
            ? const Color(0xFF2D2D2D)
            : AppColors.receiverBubble;

        final bubbleColor = isSender ? senderBubbleColor : receiverBubbleColor;

        final emojiText = message.message.trim();
        final emojiCount = _countEmojis(emojiText);

        // Tiered emoji sizes
        final double emojiSize = emojiCount <= 1
            ? 28
            : (emojiCount <= 2 ? 24 : (emojiCount <= 3 ? 22 : 18));

        final emojiStyle = TextStyle(
          fontSize: AppTextSizes.getResponsiveSize(context, emojiSize),
          height: 1.3,
        );

        final timeText = _formatTime(message.createdAt);
        final timeStyle = AppTextSizes.small(context).copyWith(
          fontSize: AppTextSizes.getResponsiveSize(context, 12),
          color: isDark ? Colors.white70 : AppColors.colorGrey,
          fontWeight: FontWeight.w400,
        );

        final timestampWidget = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(timeText, style: timeStyle),
            if (message.isEdited) ...[
              SizedBox(width: responsive.spacing(4)),
              Text('edited', style: timeStyle),
            ],
            if (isSender) ...[
              SizedBox(width: responsive.spacing(3)),
              MessageDeliveryStatusIcon(status: message.messageStatus),
            ],
          ],
        );

        // Measure emoji width to size bubble to content
        final direction = Directionality.of(context);
        final emojiPainter = TextPainter(
          text: TextSpan(text: emojiText, style: emojiStyle),
          textDirection: direction,
        )..layout();
        final timePainter = TextPainter(
          text: TextSpan(text: timeText, style: timeStyle),
          textDirection: direction,
          maxLines: 1,
        )..layout();

        final statusWidth = isSender
            ? (responsive.size(16) + responsive.spacing(3))
            : 0.0;
        final editedWidth = message.isEdited
            ? (responsive.spacing(4) + timePainter.width)
            : 0.0;
        final timestampWidth = timePainter.width + editedWidth + statusWidth;

        // Bubble width = max of emoji row and timestamp row + padding
        final horizontalPad = responsive.spacing(12) + responsive.spacing(10);
        final contentWidth = [
          emojiPainter.width,
          timestampWidth,
        ].reduce((a, b) => a > b ? a : b);

        final bubbleWidth = (contentWidth + horizontalPad).clamp(
          0.0,
          constraints.maxWidth * 0.75,
        );

        // Check if timestamp fits inline next to emoji
        final canInline =
            emojiPainter.width +
                responsive.spacing(8) +
                timestampWidth +
                horizontalPad <=
            constraints.maxWidth * 0.75;

        return Container(
          constraints: BoxConstraints(
            minWidth: bubbleWidth,
            maxWidth: constraints.maxWidth * 0.75,
          ),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: _getBubbleRadius(responsive),
          ),
          padding: EdgeInsets.only(
            left: responsive.spacing(12),
            right: responsive.spacing(10),
            top: responsive.spacing(8),
            bottom: responsive.spacing(6),
          ),
          child: canInline
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Flexible(child: Text(emojiText, style: emojiStyle)),
                    SizedBox(width: responsive.spacing(8)),
                    Transform.translate(
                      offset: Offset(0, responsive.spacing(4)),
                      child: timestampWidget,
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(emojiText, style: emojiStyle),
                    SizedBox(height: responsive.spacing(2)),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: timestampWidget,
                    ),
                  ],
                ),
        );
      },
    );
  }

  BorderRadius _getBubbleRadius(ResponsiveSize responsive) {
    final radius = responsive.size(16);
    final smallRadius = responsive.size(4);

    if (isSender) {
      return BorderRadius.only(
        topLeft: Radius.circular(radius),
        topRight: Radius.circular(radius),
        bottomLeft: Radius.circular(radius),
        bottomRight: Radius.circular(showTail ? smallRadius : radius),
      );
    } else {
      return BorderRadius.only(
        topLeft: Radius.circular(radius),
        topRight: Radius.circular(radius),
        bottomLeft: Radius.circular(showTail ? smallRadius : radius),
        bottomRight: Radius.circular(radius),
      );
    }
  }

  String _formatTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final suffix = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }

  bool _isEmojiCodePoint(int code) {
    return (code >= 0x1F300 && code <= 0x1F9FF) ||
        (code >= 0x2600 && code <= 0x26FF) ||
        (code >= 0x2700 && code <= 0x27BF) ||
        (code >= 0x1F600 && code <= 0x1F64F) ||
        (code >= 0x1F680 && code <= 0x1F6FF) ||
        (code >= 0x1FA00 && code <= 0x1FAFF) ||
        (code >= 0xFE00 && code <= 0xFE0F) ||
        (code >= 0x200D && code <= 0x200D) ||
        (code >= 0xE0020 && code <= 0xE007F) ||
        (code == 0xFE0F) ||
        (code >= 0x1F1E0 && code <= 0x1F1FF);
  }

  int _countEmojis(String text) {
    int count = 0;
    bool prevWasEmoji = false;
    for (final rune in text.runes) {
      if (_isEmojiCodePoint(rune) && rune != 0xFE0F && rune != 0x200D) {
        if (!prevWasEmoji || rune >= 0x1F1E0) {
          count++;
        }
        prevWasEmoji = true;
      } else if (rune == 0x200D) {
        prevWasEmoji = true;
      } else {
        prevWasEmoji = false;
      }
    }
    return count;
  }
}
