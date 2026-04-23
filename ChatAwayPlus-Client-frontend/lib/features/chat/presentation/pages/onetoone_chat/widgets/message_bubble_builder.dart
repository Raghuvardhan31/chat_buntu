import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:chataway_plus/core/snackbar/app_snackbar.dart';
import 'package:chataway_plus/features/chat/models/chat_message_model.dart';
import 'package:chataway_plus/features/chat/presentation/providers/chat_page_providers/chat_page_provider.dart';
import 'package:chataway_plus/features/chat/presentation/providers/chat_page_providers/chat_page_notifier.dart';
import 'package:chataway_plus/features/chat/presentation/providers/message_reactions/message_reaction_providers.dart';
import 'package:chataway_plus/features/chat/presentation/widgets/message_bubbles/image_message_bubble_one.dart';
import 'package:chataway_plus/features/chat/presentation/widgets/message_bubbles/video_message_bubble.dart';
import 'package:chataway_plus/features/chat/presentation/widgets/message_bubbles/pdf_message_bubble.dart';
import 'package:chataway_plus/features/chat/presentation/widgets/message_bubbles/text_message_bubble.dart';
import 'package:chataway_plus/features/chat/presentation/widgets/message_bubbles/emoji_message_bubble.dart';
import 'package:chataway_plus/features/chat/presentation/widgets/message_bubbles/poll_message_bubble.dart';
import 'package:chataway_plus/features/chat/presentation/widgets/message_bubbles/contact_message_bubble.dart';
import 'package:chataway_plus/features/chat/presentation/widgets/message_bubbles/audio_message_bubble.dart';
import 'package:chataway_plus/features/chat/presentation/widgets/message_bubbles/location_message_bubble.dart';
import 'package:chataway_plus/features/chat/presentation/widgets/message_bubbles/reply_preview_in_bubble.dart';
import 'package:chataway_plus/features/chat/presentation/widgets/message_interactions/message_reaction_display.dart';
import 'package:chataway_plus/features/chat/presentation/pages/media_viewer/chat_image_viewer_page.dart';
import 'package:chataway_plus/core/database/tables/chat/follow_ups_table.dart';

/// Builds individual message bubbles with proper styling and interactions
class MessageBubbleBuilder extends ConsumerWidget {
  const MessageBubbleBuilder({
    super.key,
    required this.message,
    required this.isMe,
    required this.showTail,
    required this.isSelected,
    required this.hasSelection,
    required this.responsive,
    required this.providerParams,
    required this.currentUserId,
    required this.contactName,
    required this.followUpEntries,
    required this.isLoadingFollowUps,
    required this.layerLink,
    required this.bubbleKey,
    required this.onLongPress,
    required this.onRetryUpload,
    required this.onReactionTap,
    this.onTapReplyMessage,
    this.onTap,
    this.isHighlighted = false,
  });

  final ChatMessageModel message;
  final bool isMe;
  final bool showTail;
  final bool isSelected;
  final bool hasSelection;
  final ResponsiveSize responsive;
  final Map<String, String> providerParams;
  final String currentUserId;
  final String contactName;
  final List<FollowUpEntry> followUpEntries;
  final bool isLoadingFollowUps;
  final LayerLink layerLink;
  final GlobalKey bubbleKey;
  final VoidCallback onLongPress;
  final VoidCallback? onRetryUpload;
  final VoidCallback onReactionTap;
  final VoidCallback? onTap;
  final void Function(String originalMessageId)? onTapReplyMessage;
  final bool isHighlighted;

  static const String _followUpPrefix = 'Follow up Text:';
  static const String _followUpReplyStart = '<<FU_REPLY>>';
  static const String _followUpReplyEnd = '<<FU_REPLY_END>>';
  static const String _expressHubReplyStart = '<<EH_REPLY>>';
  static const String _expressHubReplyEnd = '<<EH_REPLY_END>>';

  _ParsedExpressHubReply _parseExpressHubReply(String rawText) {
    final raw = rawText.trim();
    if (raw.isEmpty) return const _ParsedExpressHubReply(body: '');

    final startIdx = raw.indexOf(_expressHubReplyStart);
    final endIdx = raw.indexOf(_expressHubReplyEnd);
    if (startIdx != -1 && endIdx != -1 && endIdx > startIdx) {
      final block = raw
          .substring(startIdx + _expressHubReplyStart.length, endIdx)
          .trim();
      final after = raw
          .substring(endIdx + _expressHubReplyEnd.length)
          .trimLeft();
      final lines = block
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (lines.length >= 2) {
        final replyType = lines.first; // 'voice' or 'emoji'
        final replyText = lines.sublist(1).join('\n').trim();
        return _ParsedExpressHubReply(
          body: after.trimLeft(),
          replyText: replyText.isEmpty ? null : replyText,
          replyType: replyType,
        );
      } else if (lines.length == 1) {
        return _ParsedExpressHubReply(
          body: after.trimLeft(),
          replyText: lines.first,
          replyType: 'voice',
        );
      }
    }

    return _ParsedExpressHubReply(body: raw);
  }

  _ParsedFollowUpReply _parseFollowUpReply(String rawText) {
    final raw = rawText.trim();
    if (raw.isEmpty) return const _ParsedFollowUpReply(body: '');

    final startIdx = raw.indexOf(_followUpReplyStart);
    final endIdx = raw.indexOf(_followUpReplyEnd);
    if (startIdx != -1 && endIdx != -1 && endIdx > startIdx) {
      final block = raw
          .substring(startIdx + _followUpReplyStart.length, endIdx)
          .trim();
      final after = raw.substring(endIdx + _followUpReplyEnd.length).trimLeft();
      final lines = block
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (lines.length >= 2) {
        final replyDateTime = lines.last;
        final replyText = lines.sublist(0, lines.length - 1).join('\n').trim();
        return _ParsedFollowUpReply(
          body: after.trimLeft(),
          replyText: replyText.isEmpty ? null : replyText,
          replyDateTime: replyDateTime.isEmpty ? null : replyDateTime,
        );
      }
    }

    final lines = raw.split('\n');
    if (lines.length >= 2) {
      final first = lines[0].trim();
      final second = lines[1].trim();
      final hasPrefix = first.toLowerCase().startsWith(
        _followUpPrefix.toLowerCase(),
      );
      final looksLikeDateTime =
          second.startsWith('Today') ||
          second.startsWith('Yesterday') ||
          RegExp(r'^(Mon|Tue|Wed|Thu|Fri|Sat|Sun)\\b').hasMatch(second) ||
          RegExp(r'^\\d{1,2}/\\d{1,2}/\\d{2,4}\\b').hasMatch(second);

      if (hasPrefix && looksLikeDateTime) {
        final replyText = first.substring(_followUpPrefix.length).trim();
        final remaining = lines.sublist(2);
        while (remaining.isNotEmpty && remaining.first.trim().isEmpty) {
          remaining.removeAt(0);
        }
        final body = remaining.join('\n').trimLeft();
        return _ParsedFollowUpReply(
          body: body,
          replyText: replyText.isEmpty ? null : replyText,
          replyDateTime: second.isEmpty ? null : second,
        );
      }
    }

    return _ParsedFollowUpReply(body: raw);
  }

  String _formatTime(DateTime dt) {
    final localTime = dt.toLocal();
    final hour = localTime.hour % 12 == 0 ? 12 : localTime.hour % 12;
    final minute = localTime.minute.toString().padLeft(2, '0');
    final ampm = localTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $ampm';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final selectionColor = isHighlighted
        ? AppColors.primary.withValues(alpha: 0.25)
        : (isSelected
              ? AppColors.primary.withValues(alpha: 0.18)
              : Colors.transparent);

    final senderBubbleColor = isDark
        ? const Color(0xFF1E3A5F)
        : AppColors.senderBubble;
    final receiverBubbleColor = isDark
        ? const Color(0xFF2D2D2D)
        : AppColors.receiverBubble;

    final chatNotifier = ref.read(
      chatPageNotifierProvider(providerParams).notifier,
    );

    // Get upload progress for this message (if uploading)
    final chatState = ref.watch(chatPageNotifierProvider(providerParams));
    final uploadProgress = chatState.getUploadProgress(message.id);

    Widget content = _buildMessageContent(
      context,
      ref,
      isDark,
      uploadProgress,
      chatNotifier,
    );

    // Detect emoji-only text messages — they use their own EmojiMessageBubble
    final isEmojiOnlyMessage = _isEmojiOnlyMessage();

    final actualReactions = ref.watch(
      messageReactionsForMessageProvider(message.id),
    );
    final hasReactions =
        actualReactions.isNotEmpty &&
        message.messageType != MessageType.deleted;

    return Padding(
      padding: EdgeInsets.only(
        top: responsive.spacing(1),
        bottom: responsive.spacing(1),
        left: responsive.spacing(4),
        right: responsive.spacing(4),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: selectionColor,
          borderRadius: BorderRadius.circular(responsive.size(16)),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: responsive.spacing(4),
          vertical: responsive.size(1),
        ),
        child: Row(
          mainAxisAlignment: isMe
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: 0,
                maxWidth:
                    (message.isImageMessage ||
                        message.messageType == MessageType.video)
                    ? MediaQuery.of(context).size.width * 0.85
                    : (message.messageType == MessageType.location
                          ? MediaQuery.of(context).size.width * 0.75
                          : (message.messageType == MessageType.document
                                ? responsive.size(380)
                                : MediaQuery.of(context).size.width * 0.75)),
              ),
              child: CompositedTransformTarget(
                link: layerLink,
                key: bubbleKey,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onLongPress: () {
                    if (message.messageType == MessageType.deleted) {
                      AppSnackbar.show(context, 'Message already deleted');
                      return;
                    }
                    onLongPress();
                  },
                  onTap: () {
                    if (hasSelection) {
                      onTap?.call();
                    }
                  },
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // For image/video/emoji-only: no outer bubble decoration
                      // For other types: standard bubble with color, radius, shadow
                      if (message.isImageMessage ||
                          message.messageType == MessageType.video)
                        content
                      else if (isEmojiOnlyMessage)
                        content
                      else
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          decoration: BoxDecoration(
                            color: isMe
                                ? senderBubbleColor
                                : receiverBubbleColor,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(responsive.size(12)),
                              topRight: Radius.circular(responsive.size(12)),
                              bottomLeft: Radius.circular(
                                isMe
                                    ? responsive.size(12)
                                    : (showTail ? 0 : responsive.size(12)),
                              ),
                              bottomRight: Radius.circular(
                                isMe
                                    ? (showTail ? 0 : responsive.size(12))
                                    : responsive.size(12),
                              ),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: isMe ? 0.06 : 0.10,
                                ),
                                blurRadius: responsive.size(isMe ? 2 : 3),
                                offset: Offset(0, responsive.spacing(1)),
                              ),
                            ],
                          ),
                          child: content,
                        ),
                      if (hasReactions)
                        Positioned(
                          bottom: -responsive.spacing(24),
                          left: isMe
                              ? null
                              : (showTail ? responsive.spacing(4) : 0),
                          right: isMe
                              ? (showTail
                                    ? responsive.spacing(8)
                                    : responsive.spacing(2))
                              : null,
                          child: MessageReactionDisplay(
                            messageId: message.id,
                            currentUserId: currentUserId,
                            onReactionTap: onReactionTap,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Check if this is a text message containing only emojis.
  bool _isEmojiOnlyMessage() {
    if (message.messageType != MessageType.text) return false;
    final text = message.message.trim();
    if (text.isEmpty) return false;
    for (final rune in text.runes) {
      if (_isEmojiCodePoint(rune)) continue;
      if (rune == 0x20 || rune == 0x0A || rune == 0xFE0F || rune == 0x200D) {
        continue;
      }
      return false;
    }
    return true;
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

  /// Wrap media content with reply preview if this message has a reply
  Widget _wrapWithReplyPreview(Widget mediaContent) {
    // Only show reply preview for media messages that have replyToMessage
    if (message.replyToMessage == null) {
      return mediaContent;
    }

    final replyId = message.replyToMessageId ?? message.replyToMessage!.id;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(
            left: responsive.spacing(6),
            right: responsive.spacing(6),
            top: responsive.spacing(4),
          ),
          child: ReplyPreviewInBubble(
            replyToMessage: message.replyToMessage!,
            isSender: isMe,
            currentUserId: currentUserId,
            contactName: contactName,
            onTap: onTapReplyMessage != null
                ? () => onTapReplyMessage!(replyId)
                : null,
          ),
        ),
        mediaContent,
      ],
    );
  }

  Widget _buildMessageContent(
    BuildContext context,
    WidgetRef ref,
    bool isDark,
    double? uploadProgress,
    ChatPageNotifier chatNotifier,
  ) {
    if (message.messageType == MessageType.deleted) {
      return _buildDeletedMessageContent(isDark);
    } else if (message.isImageMessage) {
      return _wrapWithReplyPreview(
        _buildImageContent(context, chatNotifier, uploadProgress),
      );
    } else if (message.messageType == MessageType.video) {
      return _wrapWithReplyPreview(
        _buildVideoContent(chatNotifier, uploadProgress),
      );
    } else if (message.messageType == MessageType.document) {
      return _wrapWithReplyPreview(
        _buildDocumentContent(context, chatNotifier, uploadProgress),
      );
    } else if (message.messageType == MessageType.audio) {
      return _wrapWithReplyPreview(
        _buildAudioContent(chatNotifier, uploadProgress),
      );
    } else if (message.messageType == MessageType.contact) {
      return _wrapWithReplyPreview(
        ContactMessageBubble(message: message, isSender: isMe),
      );
    } else if (message.messageType == MessageType.location) {
      return _wrapWithReplyPreview(
        LocationMessageBubble(message: message, isSender: isMe),
      );
    } else if (message.messageType == MessageType.poll) {
      return _wrapWithReplyPreview(
        PollMessageBubble(
          message: message,
          isSender: isMe,
          currentUserId: currentUserId,
        ),
      );
    } else if (_isEmojiOnlyMessage()) {
      // Pure emoji message — use dedicated EmojiMessageBubble
      final emojiContent = EmojiMessageBubble(
        message: message,
        isSender: isMe,
        showTail: showTail,
      );

      // If has reply, wrap with background container like media messages
      if (message.replyToMessage != null) {
        final senderBg = isDark
            ? const Color(0xFF1E3A5F)
            : AppColors.senderBubble;
        final receiverBg = isDark
            ? const Color(0xFF2D2D2D)
            : AppColors.receiverBubble;

        return Container(
          decoration: BoxDecoration(
            color: isMe ? senderBg : receiverBg,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(responsive.size(12)),
              topRight: Radius.circular(responsive.size(12)),
              bottomLeft: Radius.circular(
                isMe
                    ? responsive.size(12)
                    : (showTail ? 0 : responsive.size(12)),
              ),
              bottomRight: Radius.circular(
                isMe
                    ? (showTail ? 0 : responsive.size(12))
                    : responsive.size(12),
              ),
            ),
          ),
          child: _wrapWithReplyPreview(emojiContent),
        );
      }

      return emojiContent;
    } else {
      // First check for Express Hub reply tags
      final ehParsed = _parseExpressHubReply(message.message);
      final hasExpressHubReply = ehParsed.replyText != null;

      // Then check for follow-up reply tags on the remaining body
      final parsed = _parseFollowUpReply(
        hasExpressHubReply ? ehParsed.body : message.message,
      );
      final trimmedText = parsed.body.trim();

      // Check if this is a stories comment message
      final isStoriesComment = trimmedText.startsWith('Stories comment : ');
      final actualText = isStoriesComment
          ? trimmedText.substring('Stories comment : '.length)
          : trimmedText;

      // Use server-side isFollowUp flag from model
      // Server sends clean text to receiver, sender keeps prefix locally
      final isFollowUpMessage = message.isFollowUp;

      String displayText;
      if (isFollowUpMessage && isMe) {
        // Sender: show with prefix for follow-up styling
        final hasPrefix = actualText.toLowerCase().startsWith(
          _followUpPrefix.toLowerCase(),
        );
        displayText = hasPrefix ? actualText : '$_followUpPrefix $actualText';
      } else {
        // Receiver or non-follow-up: show clean text (server sends without prefix)
        displayText = actualText;
      }

      return TextMessageBubble(
        message: message,
        isSender: isMe,
        wrapWithBubbleDecoration: false,
        displayText: displayText,
        followUpReplyText: parsed.replyText,
        followUpReplyDateTime: parsed.replyDateTime,
        isStoriesComment: isStoriesComment,
        expressHubReplyText: ehParsed.replyText,
        expressHubReplyType: ehParsed.replyType,
        currentUserId: currentUserId,
        contactName: contactName,
        onTapReplyMessage: onTapReplyMessage,
      );
    }
  }

  Widget _buildDeletedMessageContent(bool isDark) {
    final deletedText = isMe
        ? 'You deleted this message'
        : 'This message was deleted';
    final deletedTime = message.updatedAt;
    final timeText = _formatTime(deletedTime);

    final iconColor = isDark ? Colors.white54 : Colors.black45;
    final textStyle = TextStyle(
      fontSize: responsive.size(14),
      color: isDark ? Colors.white70 : Colors.black54,
      fontStyle: FontStyle.italic,
    );
    final timeStyle = TextStyle(
      fontSize: responsive.size(11),
      color: isDark ? Colors.white54 : AppColors.colorGrey,
    );

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: responsive.spacing(12),
        vertical: responsive.spacing(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.block, size: responsive.size(18), color: iconColor),
          SizedBox(width: responsive.spacing(8)),
          Flexible(
            child: Text(
              deletedText,
              style: textStyle,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: responsive.spacing(12)),
          Text(timeText, style: timeStyle),
        ],
      ),
    );
  }

  Widget _buildImageContent(
    BuildContext context,
    ChatPageNotifier chatNotifier,
    double? uploadProgress,
  ) {
    return ImageMessageBubbleOne(
      message: message,
      isSender: isMe,
      uploadProgress: uploadProgress,
      onRetry: message.messageStatus == 'failed' ? onRetryUpload : null,
      onTap: () {
        if (hasSelection) {
          chatNotifier.toggleMessageSelection(message.id);
          return;
        }
        if (message.messageStatus == 'sending' ||
            message.messageStatus == 'failed') {
          return;
        }
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ChatImageViewerPage(
              message: message,
              isMe: isMe,
              otherUserName: contactName,
            ),
          ),
        );
      },
    );
  }

  Widget _buildVideoContent(
    ChatPageNotifier chatNotifier,
    double? uploadProgress,
  ) {
    return VideoMessageBubble(
      message: message,
      isSender: isMe,
      uploadProgress: uploadProgress,
      otherUserName: contactName,
      onTap: hasSelection
          ? () => chatNotifier.toggleMessageSelection(message.id)
          : null,
      onRetry: message.messageStatus == 'failed' ? onRetryUpload : null,
    );
  }

  Widget _buildDocumentContent(
    BuildContext context,
    ChatPageNotifier chatNotifier,
    double? uploadProgress,
  ) {
    return PdfMessageBubble(
      message: message,
      isSender: isMe,
      uploadProgress: uploadProgress,
      onTap: hasSelection
          ? () => chatNotifier.toggleMessageSelection(message.id)
          : null,
      onRetry: message.messageStatus == 'failed' ? onRetryUpload : null,
    );
  }

  Widget _buildAudioContent(
    ChatPageNotifier chatNotifier,
    double? uploadProgress,
  ) {
    return AudioMessageBubble(
      message: message,
      isSender: isMe,
      uploadProgress: uploadProgress,
      onRetry: message.messageStatus == 'failed' ? onRetryUpload : null,
    );
  }
}

class _ParsedFollowUpReply {
  const _ParsedFollowUpReply({
    required this.body,
    this.replyText,
    this.replyDateTime,
  });

  final String body;
  final String? replyText;
  final String? replyDateTime;
}

class _ParsedExpressHubReply {
  const _ParsedExpressHubReply({
    required this.body,
    this.replyText,
    this.replyType,
  });

  final String body;
  final String? replyText;
  final String? replyType;
}
