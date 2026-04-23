// lib/features/chat/presentation/widgets/message_bubbles/follow_up_message_bubble.dart

import 'package:flutter/material.dart';
import 'package:chataway_plus/features/chat/models/chat_message_model.dart';
import 'package:chataway_plus/features/chat/presentation/widgets/message_bubbles/text_message_bubble.dart';

/// Widget for displaying follow-up message bubbles with special styling
///
/// Follow-up messages are visually distinguished from regular messages
/// with a continuation indicator and slightly different styling.
class FollowUpMessageBubble extends StatelessWidget {
  static const String _followUpPrefix = 'Follow up Text:';
  static const String _followUpLabel = 'Follow up-Text';

  const FollowUpMessageBubble({
    super.key,
    required this.message,
    required this.isSender,
    this.bubbleColor,
    this.onTap,
    this.onLongPress,
  });

  final ChatMessageModel message;
  final bool isSender;
  final Color? bubbleColor;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final cleanedText = _stripFollowUpPrefix(message.message);
    final displayText = '$_followUpLabel\n$cleanedText';

    return TextMessageBubble(
      message: message,
      isSender: isSender,
      bubbleColor: bubbleColor,
      displayText: displayText,
    );
  }

  String _stripFollowUpPrefix(String text) {
    final trimmed = text.trimLeft();
    if (!trimmed.toLowerCase().startsWith(_followUpPrefix.toLowerCase())) {
      return trimmed;
    }
    return trimmed.substring(_followUpPrefix.length).trimLeft();
  }
}
