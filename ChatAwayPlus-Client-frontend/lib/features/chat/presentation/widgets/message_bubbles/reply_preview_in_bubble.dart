import 'package:flutter/material.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:chataway_plus/features/chat/models/chat_message_model.dart';

/// Reply preview displayed inside a message bubble for swipe-to-reply feature.
///
/// Shows the quoted message with sender name and message preview.
/// Supports text, image, video, audio, document, contact, location message types.
class ReplyPreviewInBubble extends StatelessWidget {
  const ReplyPreviewInBubble({
    super.key,
    required this.replyToMessage,
    required this.isSender,
    required this.currentUserId,
    required this.contactName,
    this.onTap,
  });

  final ChatMessageModel replyToMessage;
  final bool isSender;
  final String currentUserId;
  final String contactName;
  final VoidCallback? onTap;

  String get _replyToSenderName {
    if (replyToMessage.senderId == currentUserId) {
      return 'You';
    }
    // Use sender name from replyToMessage if available, otherwise contactName
    if (replyToMessage.sender != null) {
      return replyToMessage.sender!.fullName;
    }
    return contactName;
  }

  IconData? get _mediaIcon {
    switch (replyToMessage.messageType) {
      case MessageType.image:
        return Icons.image;
      case MessageType.video:
        return Icons.videocam;
      case MessageType.audio:
        return Icons.mic;
      case MessageType.document:
        return Icons.description;
      case MessageType.contact:
        return Icons.person;
      case MessageType.location:
        return Icons.location_on;
      case MessageType.poll:
        return Icons.poll;
      default:
        return null;
    }
  }

  String get _previewText {
    switch (replyToMessage.messageType) {
      case MessageType.image:
        return 'Photo';
      case MessageType.video:
        return 'Video';
      case MessageType.audio:
        return 'Voice message';
      case MessageType.document:
        return replyToMessage.fileName ?? 'Document';
      case MessageType.contact:
        return 'Contact';
      case MessageType.location:
        return 'Location';
      case MessageType.poll:
        return 'Poll';
      case MessageType.deleted:
        return 'This message was deleted';
      default:
        // For text messages, show the actual text (strip reply tags)
        final text = _stripReplyTags(replyToMessage.message).trim();
        return text.isEmpty ? 'Message' : text;
    }
  }

  /// Strip Express Hub and Follow-Up reply tags from raw message text
  String _stripReplyTags(String raw) {
    var text = raw;
    final ehStart = text.indexOf('<<EH_REPLY>>');
    final ehEnd = text.indexOf('<<EH_REPLY_END>>');
    if (ehStart != -1 && ehEnd != -1 && ehEnd > ehStart) {
      text =
          text.substring(0, ehStart) +
          text.substring(ehEnd + '<<EH_REPLY_END>>'.length);
    }
    final fuStart = text.indexOf('<<FU_REPLY>>');
    final fuEnd = text.indexOf('<<FU_REPLY_END>>');
    if (fuStart != -1 && fuEnd != -1 && fuEnd > fuStart) {
      text =
          text.substring(0, fuStart) +
          text.substring(fuEnd + '<<FU_REPLY_END>>'.length);
    }
    return text.trim();
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

        // Color for the reply sender name - use accent color based on who sent
        final nameColor = AppColors.primary;

        // Background color for the reply box
        final replyBgColor = isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.05);

        return GestureDetector(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            margin: EdgeInsets.only(bottom: responsive.spacing(4)),
            padding: EdgeInsets.symmetric(
              horizontal: responsive.spacing(8),
              vertical: responsive.spacing(6),
            ),
            decoration: BoxDecoration(
              color: replyBgColor,
              borderRadius: BorderRadius.circular(responsive.size(8)),
              border: Border(
                left: BorderSide(color: nameColor, width: responsive.size(3)),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sender name
                Text(
                  _replyToSenderName,
                  style: TextStyle(
                    fontSize: responsive.size(12),
                    fontWeight: FontWeight.w600,
                    color: nameColor,
                  ),
                ),
                SizedBox(height: responsive.spacing(2)),
                // Message preview with optional icon
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_mediaIcon != null) ...[
                      Icon(
                        _mediaIcon,
                        size: responsive.size(14),
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.6)
                            : Colors.black.withValues(alpha: 0.5),
                      ),
                      SizedBox(width: responsive.spacing(4)),
                    ],
                    Flexible(
                      child: Text(
                        _previewText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: responsive.size(12),
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.6)
                              : Colors.black.withValues(alpha: 0.5),
                          fontStyle:
                              replyToMessage.messageType == MessageType.deleted
                              ? FontStyle.italic
                              : FontStyle.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
