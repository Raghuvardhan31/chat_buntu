// lib/features/chat/presentation/widgets/message_bubbles/text_message_bubble.dart

import 'package:flutter/material.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:chataway_plus/core/constants/assets/image_assets.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:chataway_plus/core/themes/app_text_styles.dart';
import 'package:chataway_plus/features/chat/models/chat_message_model.dart';
import 'package:chataway_plus/features/chat/presentation/widgets/chat_ui/message_delivery_status_icon.dart';
import 'package:chataway_plus/features/chat/presentation/widgets/message_bubbles/reply_preview_in_bubble.dart';

/// Text message bubble widget with emoji support, link detection, and inline timestamp
class TextMessageBubble extends StatelessWidget {
  const TextMessageBubble({
    super.key,
    required this.message,
    required this.isSender,
    this.bubbleColor,
    this.showTail = true,
    this.wrapWithBubbleDecoration = true,
    this.displayText,
    this.followUpReplyText,
    this.followUpReplyDateTime,
    this.isStoriesComment = false,
    this.expressHubReplyText,
    this.expressHubReplyType,
    this.currentUserId,
    this.contactName,
    this.onTapReplyMessage,
  });

  final ChatMessageModel message;
  final bool isSender;
  final Color? bubbleColor;
  final bool showTail;
  final bool wrapWithBubbleDecoration;
  final String? displayText;
  final String? followUpReplyText;
  final String? followUpReplyDateTime;
  final bool isStoriesComment;
  final String? expressHubReplyText;
  final String? expressHubReplyType;
  final String? currentUserId;
  final String? contactName;
  final void Function(String originalMessageId)? onTapReplyMessage;

  /// Whether this message is purely emoji (no text characters).
  /// Used by message_bubble_builder to skip bubble decoration.
  bool get isEmojiOnly {
    final text = (displayText ?? message.message).trim();
    return _isEmojiOnlyText(text);
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
        final isDark = Theme.of(context).brightness == Brightness.dark;

        final defaultBubbleColor = isSender
            ? (isDark ? const Color(0xFF1E3A5F) : AppColors.senderBubble)
            : (isDark ? const Color(0xFF2D2D2D) : AppColors.receiverBubble);

        final content = _buildContent(context, responsive, isDark);
        if (!wrapWithBubbleDecoration) return content;

        return Container(
          constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.75),
          decoration: BoxDecoration(
            color: bubbleColor ?? defaultBubbleColor,
            borderRadius: _getBubbleRadius(responsive),
          ),
          child: content,
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

  Widget _buildContent(
    BuildContext context,
    ResponsiveSize responsive,
    bool isDark,
  ) {
    final messageText = displayText ?? message.message;
    final hasFollowUpReply =
        followUpReplyText != null && followUpReplyDateTime != null;
    final hasExpressHubReply = expressHubReplyText != null;
    final hasSwipeReply =
        message.replyToMessage != null || message.replyToMessageId != null;
    return Padding(
      padding: EdgeInsets.only(
        left: responsive.spacing(10),
        right: responsive.spacing(10),
        top: responsive.spacing(6),
        bottom: responsive.spacing(6),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // WhatsApp-style text sizing
          final textToRender = (displayText ?? message.message).trim();
          final emojiOnly = _isEmojiOnlyText(textToRender);
          final emojiCount = _countEmojis(textToRender);

          // Emoji-only font size tiers (like WhatsApp)
          final double emojiOnlySize = emojiCount <= 1
              ? 48
              : (emojiCount <= 2 ? 40 : (emojiCount <= 3 ? 34 : 28));

          final baseStyle = AppTextSizes.regular(context).copyWith(
            fontSize: AppTextSizes.getResponsiveSize(context, 16),
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w400,
            height: 1.35,
          );

          // Emoji style for mixed text+emoji: noticeably larger than text
          final emojiStyle = AppTextSizes.regular(context).copyWith(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: AppTextSizes.getResponsiveSize(context, 22),
            fontWeight: FontWeight.w400,
            height: 1.15,
          );

          // Emoji-only style: large standalone emojis
          final emojiOnlyStyle = TextStyle(
            fontSize: AppTextSizes.getResponsiveSize(context, emojiOnlySize),
            height: 1.3,
          );

          final linkColor = isDark
              ? const Color(0xFF25D366)
              : const Color(0xFF128C7E);
          final linkStyle = baseStyle.copyWith(
            color: linkColor,
            decoration: TextDecoration.underline,
            fontWeight: FontWeight.w500,
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

          final direction = Directionality.of(context);
          final editedPainter = message.isEdited
              ? (TextPainter(
                  text: TextSpan(text: 'edited', style: timeStyle),
                  textDirection: direction,
                  maxLines: 1,
                )..layout())
              : null;
          final timePainter = TextPainter(
            text: TextSpan(text: timeText, style: timeStyle),
            textDirection: direction,
            maxLines: 1,
          )..layout();

          final statusApproxWidth = isSender
              ? (responsive.size(16) + responsive.spacing(3))
              : 0.0;
          final editedApproxWidth = message.isEdited
              ? (editedPainter!.width + responsive.spacing(4))
              : 0.0;
          final timestampWidth =
              timePainter.width +
              editedApproxWidth +
              statusApproxWidth +
              responsive.spacing(6);

          final hasEmoji = messageText.runes.any(_isEmojiCodePoint);
          final measureStyle = emojiOnly
              ? emojiOnlyStyle
              : (hasEmoji ? emojiStyle : baseStyle);
          final messagePainter = TextPainter(
            text: TextSpan(text: messageText, style: measureStyle),
            textDirection: direction,
          )..layout(maxWidth: constraints.maxWidth);

          final lines = messagePainter.computeLineMetrics();
          final isSingleLine = lines.length <= 1;
          final lastLineWidth = lines.isNotEmpty ? lines.last.width : 0.0;
          final canInline =
              isSingleLine &&
              (lastLineWidth + timestampWidth <= constraints.maxWidth);

          // Build message content with optional stories icon prefix
          Widget messageRichText;
          if (emojiOnly) {
            // Emoji-only: render large emojis, no RichText spans needed
            messageRichText = Text(messageText, style: emojiOnlyStyle);
          } else if (isStoriesComment) {
            // Stories comment: icon + "Stories comment" + user text inline
            final storiesIconColor = isDark ? Colors.white70 : Colors.black54;
            messageRichText = RichText(
              text: TextSpan(
                style: baseStyle,
                children: [
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Padding(
                      padding: EdgeInsets.only(right: responsive.spacing(4)),
                      child: Image.asset(
                        ImageAssets.chatStoriesIcon,
                        width: responsive.size(14),
                        height: responsive.size(14),
                        color: storiesIconColor,
                      ),
                    ),
                  ),
                  TextSpan(
                    text: 'Stories comment: ',
                    style: baseStyle.copyWith(
                      color: storiesIconColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  ..._buildEmojiAwareSpans(
                    messageText,
                    baseStyle,
                    emojiStyle,
                    linkStyle,
                  ),
                ],
              ),
            );
          } else {
            messageRichText = RichText(
              text: TextSpan(
                style: baseStyle,
                children: _buildEmojiAwareSpans(
                  messageText,
                  baseStyle,
                  emojiStyle,
                  linkStyle,
                ),
              ),
            );
          }

          // Swipe-to-reply preview (quoted message from backend replyToMessage)
          if (hasSwipeReply && message.replyToMessage != null) {
            final replyId =
                message.replyToMessageId ?? message.replyToMessage!.id;
            final steppedTimestampWidget = Transform.translate(
              offset: Offset(0, responsive.spacing(4)),
              child: timestampWidget,
            );

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ReplyPreviewInBubble(
                  replyToMessage: message.replyToMessage!,
                  isSender: isSender,
                  currentUserId: currentUserId ?? '',
                  contactName: contactName ?? '',
                  onTap: onTapReplyMessage != null
                      ? () => onTapReplyMessage!(replyId)
                      : null,
                ),
                messageRichText,
                SizedBox(height: responsive.spacing(2)),
                Align(
                  alignment: Alignment.bottomRight,
                  child: steppedTimestampWidget,
                ),
              ],
            );
          }

          // Express Hub reply quote box (SYVT / Emoji)
          if (hasExpressHubReply) {
            final ehReplyBg = isDark
                ? const Color(0xFF3E2723).withValues(alpha: 0.5)
                : const Color(0xFFFFF3E0);
            final ehReplyBorder = isDark
                ? const Color(0xFFFF6D00).withValues(alpha: 0.3)
                : const Color(0xFFFFCC80);
            final ehLabelColor = isDark
                ? const Color(0xFFFFAB40)
                : const Color(0xFFE65100);
            final ehTextColor = isDark
                ? const Color(0xFFFFCC80)
                : const Color(0xFFBF360C);

            final ehReplyBox = Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: responsive.spacing(10),
                vertical: responsive.spacing(8),
              ),
              decoration: BoxDecoration(
                color: ehReplyBg,
                borderRadius: BorderRadius.circular(responsive.size(10)),
                border: Border.all(color: ehReplyBorder, width: 1),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        ImageAssets.replyMessageIcon,
                        width: responsive.size(14),
                        height: responsive.size(14),
                        color: ehLabelColor,
                      ),
                      SizedBox(width: responsive.spacing(4)),
                      Text(
                        'Express Hub',
                        style: baseStyle.copyWith(
                          fontSize: AppTextSizes.getResponsiveSize(context, 11),
                          fontWeight: FontWeight.w700,
                          color: ehLabelColor,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: responsive.spacing(4)),
                  Text(
                    expressHubReplyText!,
                    style: baseStyle.copyWith(
                      fontSize: AppTextSizes.getResponsiveSize(context, 13),
                      fontWeight: FontWeight.w500,
                      color: ehTextColor,
                      height: 1.2,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );

            final steppedTimestampWidget = Transform.translate(
              offset: Offset(0, responsive.spacing(4)),
              child: timestampWidget,
            );

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ehReplyBox,
                SizedBox(height: responsive.spacing(6)),
                messageRichText,
                SizedBox(height: responsive.spacing(2)),
                Align(
                  alignment: Alignment.bottomRight,
                  child: steppedTimestampWidget,
                ),
              ],
            );
          }

          if (hasFollowUpReply) {
            final replyBg = isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06);
            final replyBorder = isDark
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.10);
            final replyTextStyle = baseStyle.copyWith(
              fontSize: AppTextSizes.getResponsiveSize(context, 13),
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : Colors.black87,
              height: 1.2,
            );
            final replyTimeStyle = timeStyle.copyWith(
              fontSize: AppTextSizes.getResponsiveSize(context, 11),
            );
            final replyBox = Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: responsive.spacing(10),
                vertical: responsive.spacing(8),
              ),
              decoration: BoxDecoration(
                color: replyBg,
                borderRadius: BorderRadius.circular(responsive.size(10)),
                border: Border.all(color: replyBorder, width: 1),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(followUpReplyText!, style: replyTextStyle),
                  SizedBox(height: responsive.spacing(4)),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(followUpReplyDateTime!, style: replyTimeStyle),
                  ),
                ],
              ),
            );

            final steppedTimestampWidget = Transform.translate(
              offset: Offset(0, responsive.spacing(4)),
              child: timestampWidget,
            );

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                replyBox,
                SizedBox(height: responsive.spacing(6)),
                messageRichText,
                SizedBox(height: responsive.spacing(2)),
                Align(
                  alignment: Alignment.bottomLeft,
                  child: steppedTimestampWidget,
                ),
              ],
            );
          }

          if (canInline) {
            final inlineTimestampWidget = Transform.translate(
              offset: Offset(0, responsive.spacing(5)),
              child: timestampWidget,
            );
            return Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(fit: FlexFit.loose, child: messageRichText),
                SizedBox(width: responsive.spacing(6)),
                inlineTimestampWidget,
              ],
            );
          }

          final steppedTimestampWidget = Transform.translate(
            offset: Offset(0, responsive.spacing(4)),
            child: timestampWidget,
          );

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              messageRichText,
              SizedBox(height: responsive.spacing(2)),
              Align(
                alignment: Alignment.bottomRight,
                child: steppedTimestampWidget,
              ),
            ],
          );
        },
      ),
    );
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

  /// Returns true if the message contains ONLY emoji characters
  /// (and optional whitespace / variation selectors / ZWJ).
  bool _isEmojiOnlyText(String text) {
    if (text.isEmpty) return false;
    for (final rune in text.runes) {
      if (_isEmojiCodePoint(rune)) continue;
      // Allow whitespace, variation selectors, ZWJ between emojis
      if (rune == 0x20 || rune == 0x0A || rune == 0xFE0F || rune == 0x200D) {
        continue;
      }
      return false;
    }
    return true;
  }

  /// Count the number of visible emoji glyphs in the text.
  int _countEmojis(String text) {
    int count = 0;
    bool prevWasEmoji = false;
    for (final rune in text.runes) {
      if (_isEmojiCodePoint(rune) && rune != 0xFE0F && rune != 0x200D) {
        // Don't double-count ZWJ sequences (e.g. 👨‍👩‍👧)
        if (!prevWasEmoji || rune >= 0x1F1E0) {
          count++;
        }
        prevWasEmoji = true;
      } else if (rune == 0x200D) {
        // ZWJ joins previous emoji with next — don't count
        prevWasEmoji = true;
      } else {
        prevWasEmoji = false;
      }
    }
    return count;
  }

  List<InlineSpan> _buildEmojiAwareSpans(
    String text,
    TextStyle baseStyle,
    TextStyle emojiStyle,
    TextStyle linkStyle,
  ) {
    final spans = <InlineSpan>[];
    final urlRegex = RegExp(
      r'(https?:\/\/[^\s]+)|(www\.[^\s]+)',
      caseSensitive: false,
    );

    final matches = urlRegex.allMatches(text).toList();
    int lastEnd = 0;

    for (final match in matches) {
      if (match.start > lastEnd) {
        spans.addAll(
          _buildEmojiSpans(
            text.substring(lastEnd, match.start),
            baseStyle,
            emojiStyle,
          ),
        );
      }
      final url = match.group(0)!;
      spans.add(
        WidgetSpan(
          child: GestureDetector(
            onTap: () => _launchUrl(url),
            child: Text(url, style: linkStyle),
          ),
        ),
      );
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.addAll(
        _buildEmojiSpans(text.substring(lastEnd), baseStyle, emojiStyle),
      );
    }

    return spans;
  }

  List<InlineSpan> _buildEmojiSpans(
    String text,
    TextStyle baseStyle,
    TextStyle emojiStyle,
  ) {
    final spans = <InlineSpan>[];
    final buffer = StringBuffer();
    bool isEmoji = false;

    for (final rune in text.runes) {
      final char = String.fromCharCode(rune);
      final charIsEmoji = _isEmojiCodePoint(rune);

      if (charIsEmoji != isEmoji && buffer.isNotEmpty) {
        spans.add(
          TextSpan(
            text: buffer.toString(),
            style: isEmoji ? emojiStyle : baseStyle,
          ),
        );
        buffer.clear();
      }

      buffer.write(char);
      isEmoji = charIsEmoji;
    }

    if (buffer.isNotEmpty) {
      spans.add(
        TextSpan(
          text: buffer.toString(),
          style: isEmoji ? emojiStyle : baseStyle,
        ),
      );
    }

    return spans;
  }

  Future<void> _launchUrl(String url) async {
    String finalUrl = url;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      finalUrl = 'https://$url';
    }
    final uri = Uri.parse(finalUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
