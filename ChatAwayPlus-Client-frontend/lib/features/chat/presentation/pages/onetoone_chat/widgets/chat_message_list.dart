import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:chataway_plus/features/chat/models/chat_message_model.dart';
import 'package:chataway_plus/features/chat/presentation/providers/chat_page_providers/chat_page_notifier.dart';
import 'package:chataway_plus/features/chat/presentation/widgets/chat_ui/chat_date_divider.dart';
import 'package:chataway_plus/features/chat/presentation/widgets/chat_ui/jump_to_latest_button.dart';
import 'package:chataway_plus/features/chat/presentation/pages/onetoone_chat/widgets/message_bubble_builder.dart';
import 'package:chataway_plus/features/chat/presentation/widgets/message_bubbles/swipe_reply_bubble.dart';
import 'package:chataway_plus/features/chat/presentation/pages/onetoone_chat/widgets/blocked_inline_banner.dart';
import 'package:chataway_plus/core/database/tables/chat/follow_ups_table.dart';

/// Widget that displays the scrollable list of chat messages
class ChatMessageList extends ConsumerWidget {
  const ChatMessageList({
    super.key,
    required this.messages,
    required this.responsive,
    required this.scrollController,
    required this.selectedMessageIds,
    required this.providerParams,
    required this.currentUserId,
    required this.contactName,
    required this.followUpEntries,
    required this.isLoadingFollowUps,
    required this.isBlocked,
    required this.showJumpToLatest,
    required this.messageLayerLinks,
    required this.messageBubbleKeys,
    required this.chatNotifier,
    required this.onJumpToLatest,
    required this.onMessageLongPress,
    required this.onRetryUpload,
    required this.onReactionTap,
    this.onSwipeToReply,
    this.onTapReplyMessage,
    this.highlightedMessageId,
  });

  final List<ChatMessageModel> messages;
  final ResponsiveSize responsive;
  final ScrollController scrollController;
  final Set<String> selectedMessageIds;
  final Map<String, String> providerParams;
  final String currentUserId;
  final String contactName;
  final List<FollowUpEntry> followUpEntries;
  final bool isLoadingFollowUps;
  final bool isBlocked;
  final bool showJumpToLatest;
  final Map<String, LayerLink> messageLayerLinks;
  final Map<String, GlobalKey> messageBubbleKeys;
  final ChatPageNotifier chatNotifier;
  final VoidCallback onJumpToLatest;
  final void Function(String messageId) onMessageLongPress;
  final void Function(ChatMessageModel message) onRetryUpload;
  final void Function(String messageId) onReactionTap;
  final void Function(ChatMessageModel message)? onSwipeToReply;
  final void Function(String originalMessageId)? onTapReplyMessage;
  final String? highlightedMessageId;

  bool _shouldShowDateDivider(
    ChatMessageModel currentMessage,
    ChatMessageModel? previousMessage,
  ) {
    if (previousMessage == null) return true;
    final currentLocal = currentMessage.createdAt.toLocal();
    final previousLocal = previousMessage.createdAt.toLocal();

    final currentDate = DateTime(
      currentLocal.year,
      currentLocal.month,
      currentLocal.day,
    );
    final previousDate = DateTime(
      previousLocal.year,
      previousLocal.month,
      previousLocal.day,
    );
    return currentDate != previousDate;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (messages.isEmpty) {
      return const SizedBox.shrink();
    }

    final hasSelection = selectedMessageIds.isNotEmpty;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final bottomPadding = keyboardHeight > 0 ? responsive.spacing(8) : 0.0;

    return Stack(
      children: [
        ListView.custom(
          reverse: true,
          controller: scrollController,
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.only(bottom: bottomPadding),
          cacheExtent: responsive.size(1624),
          childrenDelegate: SliverChildBuilderDelegate(
            (context, index) {
              final effectiveCount = messages.length;
              if (index >= effectiveCount) return null;

              final message = messages[messages.length - 1 - index];

              final hasFileUrl =
                  (message.imageUrl != null &&
                  message.imageUrl!.trim().isNotEmpty);
              final hasLocalPath =
                  (message.localImagePath != null &&
                  message.localImagePath!.trim().isNotEmpty);
              final hasMimeType =
                  (message.mimeType != null &&
                  message.mimeType!.trim().isNotEmpty);
              final hasFileName =
                  (message.fileName != null &&
                  message.fileName!.trim().isNotEmpty);
              final hasPageCount = message.pageCount != null;
              final hasFileSize = message.fileSize != null;
              final hasThumbnail =
                  (message.thumbnailUrl != null &&
                  message.thumbnailUrl!.trim().isNotEmpty);

              final isDeletedMessage =
                  message.messageType == MessageType.deleted;
              final shouldSkipBubble =
                  !isDeletedMessage &&
                  message.message.trim().isEmpty &&
                  !(hasFileUrl ||
                      hasLocalPath ||
                      hasThumbnail ||
                      hasMimeType ||
                      hasFileName ||
                      hasPageCount ||
                      hasFileSize);

              final isMe = message.senderId == currentUserId;
              final isSelected = selectedMessageIds.contains(message.id);

              final previousMessage = index < messages.length - 1
                  ? messages[messages.length - index - 2]
                  : null;
              final showDateDivider = _shouldShowDateDivider(
                message,
                previousMessage,
              );

              bool showTail = true;
              if (index < messages.length - 1) {
                final prevMessage = messages[messages.length - index - 2];
                if (prevMessage.senderId == message.senderId) {
                  showTail = false;
                }
              }

              if (shouldSkipBubble) {
                return const SizedBox.shrink();
              }

              final layerLink = messageLayerLinks.putIfAbsent(
                message.id,
                () => LayerLink(),
              );
              final bubbleKey = messageBubbleKeys.putIfAbsent(
                message.id,
                () => GlobalKey(),
              );

              return Column(
                key: ValueKey(message.id),
                children: [
                  if (isBlocked && index == 0)
                    BlockedInlineBanner(responsive: responsive),
                  if (showDateDivider) ChatDateDivider(date: message.createdAt),
                  SwipeReplyBubble(
                    isMe: isMe,
                    enabled:
                        !hasSelection &&
                        message.messageType != MessageType.deleted,
                    onSwipe: () => onSwipeToReply?.call(message),
                    child: MessageBubbleBuilder(
                      message: message,
                      isMe: isMe,
                      showTail: showTail,
                      isSelected: isSelected,
                      hasSelection: hasSelection,
                      responsive: responsive,
                      providerParams: providerParams,
                      currentUserId: currentUserId,
                      contactName: contactName,
                      followUpEntries: followUpEntries,
                      isLoadingFollowUps: isLoadingFollowUps,
                      layerLink: layerLink,
                      bubbleKey: bubbleKey,
                      onLongPress: () => onMessageLongPress(message.id),
                      onRetryUpload: message.messageStatus == 'failed'
                          ? () => onRetryUpload(message)
                          : null,
                      onReactionTap: () => onReactionTap(message.id),
                      onTap: () => chatNotifier.toggleMessageSelection(message.id),
                      onTapReplyMessage: onTapReplyMessage,
                      isHighlighted: highlightedMessageId == message.id,
                    ),
                  ),
                ],
              );
            },
            childCount: messages.length,
            addAutomaticKeepAlives: false,
            addRepaintBoundaries: true,
            addSemanticIndexes: false,
          ),
        ),

        if (showJumpToLatest)
          Positioned(
            bottom: responsive.spacing(16),
            right: responsive.spacing(16),
            child: AnimatedScale(
              scale: showJumpToLatest ? 1.0 : 0.9,
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeOut,
              child: AnimatedOpacity(
                opacity: showJumpToLatest ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeOut,
                child: JumpToLatestButton(onTap: onJumpToLatest),
              ),
            ),
          ),
      ],
    );
  }
}
