import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:chataway_plus/core/routes/route_names.dart';
import 'package:chataway_plus/core/notifications/local/notification_local_service.dart';
import 'package:chataway_plus/core/constants/assets/image_assets.dart';
import 'package:chataway_plus/features/shared/widgets/avatars/cached_circle_avatar.dart';
import 'package:chataway_plus/features/chat/models/chat_message_model.dart';
import 'package:chataway_plus/features/chat/presentation/providers/chat_page_providers/typing_indicator_provider.dart';
import 'package:chataway_plus/features/chat/presentation/providers/message_reactions/message_reaction_providers.dart';
import 'package:chataway_plus/features/chat/presentation/widgets/chat_ui/message_delivery_status_icon.dart';
import 'package:chataway_plus/features/contacts/presentation/providers/contacts_management.dart';
import 'package:chataway_plus/features/contacts/data/models/contact_local.dart';
import 'package:chataway_plus/features/contacts/utils/contact_display_name_helper.dart';
import 'package:chataway_plus/features/chat/data/socket/socket_models/index.dart';
import 'package:chataway_plus/features/chat/presentation/providers/chat_page_providers/notification_stream_provider.dart';
import 'package:chataway_plus/features/chat_stories/presentation/providers/story_providers.dart';

class ChatListTileWidget extends ConsumerWidget {
  final ChatContactModel contact;
  final String? currentUserId;
  final ResponsiveSize responsive;
  final Function(
    String name,
    String contactId,
    String mobileNumber,
    String? chatPictureUrl,
    String? chatPictureVersion,
  )
  onAvatarTap;
  final Future<void> Function() onNavigateBack;

  const ChatListTileWidget({
    super.key,
    required this.contact,
    required this.currentUserId,
    required this.responsive,
    required this.onAvatarTap,
    required this.onNavigateBack,
  });

  static const String _followUpPrefix = 'Follow up Text:';
  static const String _followUpReplyStart = '<<FU_REPLY>>';
  static const String _followUpReplyEnd = '<<FU_REPLY_END>>';
  static const String _expressHubReplyStart = '<<EH_REPLY>>';
  static const String _expressHubReplyEnd = '<<EH_REPLY_END>>';

  bool _looksLikeLatLngText(String raw) {
    final t = raw.trim();
    final m = RegExp(
      r'^-?\d{1,3}(?:\.\d+)?\s*,\s*-?\d{1,3}(?:\.\d+)?$',
    ).firstMatch(t);
    if (m == null) return false;
    final parts = t.split(',');
    if (parts.length < 2) return false;
    final lat = double.tryParse(parts[0].trim());
    final lng = double.tryParse(parts[1].trim());
    if (lat == null || lng == null) return false;
    if (lat < -90 || lat > 90) return false;
    if (lng < -180 || lng > 180) return false;
    return true;
  }

  String _sanitizePreviewText(String raw) {
    final cleanedRaw = _stripReplyWrappers(raw);
    final s = cleanedRaw.trim();
    if (s.isEmpty) return raw;

    if (_looksLikeLatLngText(s)) {
      return 'Location';
    }

    dynamic decoded;
    try {
      decoded = _tryDecodeJson(s);
    } catch (_) {
      decoded = null;
    }

    if (decoded is Map) {
      final map = Map<String, dynamic>.from(decoded);
      final candidates = <dynamic>[
        map['messageText'],
        map['message_text'],
        map['message'],
        map['text'],
        map['body'],
      ];
      for (final v in candidates) {
        if (v is String) {
          final t = _stripReplyWrappers(v).trim();
          if (t.isNotEmpty) return t;
        }
      }

      final msgType = (map['messageType'] ?? map['message_type'])
          ?.toString()
          .toLowerCase();
      if (msgType != null) {
        if (msgType == 'image' || msgType.startsWith('i')) {
          return 'Photo';
        } else if (msgType == 'document' || msgType == 'pdf') {
          final fileName = (map['fileName'] ?? map['file_name'])?.toString();
          return (fileName != null && fileName.trim().isNotEmpty)
              ? fileName
              : 'PDF';
        } else if (msgType == 'video') {
          return 'Video';
        } else if (msgType == 'location') {
          return 'Location';
        } else if (msgType == 'poll') {
          return 'Poll';
        }
      }

      final hasLat = map.containsKey('latitude') || map.containsKey('lat');
      final hasLng =
          map.containsKey('longitude') ||
          map.containsKey('lng') ||
          map.containsKey('lon');
      if (hasLat && hasLng) {
        return 'Location';
      }
    }

    return cleanedRaw;
  }

  dynamic _tryDecodeJson(String s) {
    dynamic decoded;
    try {
      decoded = jsonDecode(s);
    } catch (_) {
      decoded = null;
    }

    if (decoded == null) {
      try {
        final uriDecoded = Uri.decodeComponent(s);
        if (uriDecoded != s) {
          decoded = jsonDecode(uriDecoded);
        }
      } catch (_) {}
    }

    if (decoded == null && s.startsWith('{') && s.contains(r'\"')) {
      try {
        decoded = jsonDecode(s.replaceAll(r'\"', '"'));
      } catch (_) {
        decoded = null;
      }
    }

    return decoded;
  }

  String _stripReplyWrappers(String raw) {
    var result = raw;

    // Strip Express Hub reply wrapper
    final ehTrimmed = result.trimLeft();
    if (ehTrimmed.startsWith(_expressHubReplyStart)) {
      final ehEndIndex = ehTrimmed.indexOf(_expressHubReplyEnd);
      if (ehEndIndex != -1) {
        result = ehTrimmed
            .substring(ehEndIndex + _expressHubReplyEnd.length)
            .trimLeft();
      }
    }

    // Strip Follow-up reply wrapper
    final fuTrimmed = result.trimLeft();
    if (fuTrimmed.startsWith(_followUpReplyStart)) {
      final fuEndIndex = fuTrimmed.indexOf(_followUpReplyEnd);
      if (fuEndIndex != -1) {
        result = fuTrimmed
            .substring(fuEndIndex + _followUpReplyEnd.length)
            .trimLeft();
      }
    }

    return result;
  }

  String _formatTime(DateTime dt) {
    final istTime = dt.toUtc().add(const Duration(hours: 5, minutes: 30));
    final now = DateTime.now();
    final diff = now.difference(istTime);

    if (diff.inDays == 0) {
      final hour = istTime.hour % 12 == 0 ? 12 : istTime.hour % 12;
      final minute = istTime.minute.toString().padLeft(2, '0');
      final ampm = istTime.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $ampm';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[istTime.weekday - 1];
    } else {
      return '${istTime.day}/${istTime.month}/${istTime.year}';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = contact.user;
    final List<ContactLocal> allContacts = ref.watch(contactsListProvider);

    final ContactLocal? matchedContact =
        ContactDisplayNameHelper.findByUserIdOrPhone(
          contacts: allContacts,
          userId: user.id,
          mobileNo: user.mobileNo,
        );

    final mergedChatPictureUrl =
        matchedContact?.userDetails?.chatPictureUrl ?? user.chatPictureUrl;
    final chatPictureVersion = matchedContact?.userDetails?.chatPictureVersion;

    final String name = ContactDisplayNameHelper.resolveDisplayName(
      contacts: allContacts,
      userId: user.id,
      mobileNo: user.mobileNo,
      backendDisplayName: '${user.firstName} ${user.lastName}'.trim(),
      fallbackLabel: 'ChatAway user',
    );

    final notificationCounts = ref.watch(notificationCountsProvider);
    final userId = user.id;
    final notificationData = notificationCounts[userId];
    final dbUnreadCount = contact.unreadCount;
    final unreadCount = dbUnreadCount;
    final hasUnread = unreadCount > 0;
    final hasNotifications =
        hasUnread && notificationData != null && notificationData.count > 0;

    final isTyping = ref.watch(isUserTypingProvider(userId));

    final lastMessage = isTyping
        ? 'Typing...'
        : ((contact.lastMessage?.message ?? '').trim().isNotEmpty
              ? (contact.lastMessage?.message ?? '')
              : (hasNotifications ? notificationData.lastMessage : ''));

    String displayMessage = _sanitizePreviewText(lastMessage);

    if (!isTyping &&
        !hasNotifications &&
        contact.lastMessage != null &&
        contact.lastMessage!.messageType == MessageType.location) {
      displayMessage = 'Location';
    }

    // Check if this is a stories comment message (before removing prefix)
    final isStoriesComment =
        displayMessage.startsWith('Stories comment : ') ||
        (contact.lastMessage?.message.startsWith('Stories comment : ') ??
            false);

    // Remove "Stories comment : " prefix for display (icon will be shown separately)
    if (displayMessage.startsWith('Stories comment : ')) {
      displayMessage = displayMessage.substring('Stories comment : '.length);
    }

    final activity = contact.lastActivity;
    bool showActivityPreview = false;
    bool isDeletedPreview = false;

    if (!isTyping && !hasNotifications && activity != null) {
      final isByMe =
          currentUserId != null &&
          currentUserId!.isNotEmpty &&
          activity.actorId == currentUserId;

      final normalizedType = (activity.type ?? '')
          .toLowerCase()
          .trim()
          .replaceAll('-', '_');

      if (normalizedType == 'message_deleted') {
        final last = contact.lastMessage;
        final shouldShow =
            last == null || activity.timestamp.isAfter(last.createdAt);
        if (shouldShow) {
          displayMessage = isByMe
              ? 'You deleted this message'
              : 'This message was deleted';
          showActivityPreview = true;
          isDeletedPreview = true;
        }
      } else {
        final diff = DateTime.now().difference(activity.timestamp);
        if (diff <= const Duration(minutes: 5)) {
          final actorLabel = isByMe
              ? 'You'
              : (name.trim().isNotEmpty
                    ? name.trim().split(' ').first
                    : 'Someone');

          if (normalizedType == 'reaction') {
            final emoji = (activity.emoji ?? '').trim();
            if (emoji.isNotEmpty) {
              displayMessage = '$actorLabel reacted $emoji';
              showActivityPreview = true;
            }
          } else if (normalizedType == 'reaction_removed') {
            displayMessage = '$actorLabel removed reaction';
            showActivityPreview = true;
          }
        }
      }
    }

    if (!showActivityPreview &&
        !isTyping &&
        !hasNotifications &&
        contact.lastMessage != null) {
      final last = contact.lastMessage!;
      if (last.messageType == MessageType.deleted) {
        final isByMe =
            currentUserId != null &&
            currentUserId!.isNotEmpty &&
            last.senderId == currentUserId;
        displayMessage = isByMe
            ? 'You deleted this message'
            : 'This message was deleted';
        isDeletedPreview = true;
      }
    }

    if (!showActivityPreview &&
        !isTyping &&
        !hasNotifications &&
        contact.lastMessage != null) {
      final messageId = contact.lastMessage!.id;

      final reactionsState = ref.watch(messageReactionStateProvider);
      final liveReactions = reactionsState.getReactionsForMessage(messageId);
      final isLoaded = reactionsState.isLoaded(messageId);

      final fallbackReactions = contact.lastMessage!.reactions;
      final shouldUseFallback = !isLoaded && liveReactions.isEmpty;
      final reactions = shouldUseFallback ? fallbackReactions : liveReactions;

      if (reactions.isNotEmpty) {
        MessageReaction? currentUserReaction;
        if (currentUserId != null && currentUserId!.isNotEmpty) {
          for (final r in reactions) {
            if (r.userId == currentUserId) {
              currentUserReaction = r;
              break;
            }
          }
        }

        MessageReaction? latestReaction;
        for (final r in reactions) {
          if (latestReaction == null ||
              r.createdAt.isAfter(latestReaction.createdAt)) {
            latestReaction = r;
          }
        }

        final chosenReaction = currentUserReaction ?? latestReaction;
        if (chosenReaction != null) {
          final isByMe =
              currentUserId != null &&
              currentUserId!.isNotEmpty &&
              chosenReaction.userId == currentUserId;

          final rawText = (contact.lastMessage?.message ?? '').trim();
          final sanitizedRawText = _sanitizePreviewText(rawText).trim();
          String? quotedText;
          if (sanitizedRawText.isNotEmpty) {
            const maxLen = 30;
            quotedText = sanitizedRawText.length > maxLen
                ? '${sanitizedRawText.substring(0, maxLen)}...'
                : sanitizedRawText;
          }

          displayMessage = quotedText == null
              ? (isByMe
                    ? 'You hit ${chosenReaction.emoji}'
                    : 'Hit ${chosenReaction.emoji}')
              : (isByMe
                    ? 'You hit ${chosenReaction.emoji} to "$quotedText"'
                    : 'Hit ${chosenReaction.emoji} to "$quotedText"');
        }
      }
    }

    if (!isTyping && contact.lastMessage != null) {
      final last = contact.lastMessage!;
      final displayIsEmpty = displayMessage.trim().isEmpty;
      final looksLikeJson =
          displayMessage.trim().startsWith('{') ||
          displayMessage.trim().startsWith('[') ||
          displayMessage.contains('"messageType"') ||
          displayMessage.contains('"message":null');

      if (displayIsEmpty && last.messageType == MessageType.image) {
        displayMessage = 'Photo';
      } else if (displayIsEmpty && last.messageType == MessageType.document) {
        final fileName = (last.fileName ?? '').trim();
        displayMessage = fileName.isNotEmpty ? fileName : 'PDF';
      } else if (displayIsEmpty && last.messageType == MessageType.video) {
        displayMessage = 'Video';
      } else if (displayIsEmpty && last.messageType == MessageType.audio) {
        final dur = last.audioDuration;
        if (dur != null && dur > 0) {
          final mins = (dur ~/ 60).toString().padLeft(2, '0');
          final secs = (dur.toInt() % 60).toString().padLeft(2, '0');
          displayMessage = 'Voice message  $mins:$secs';
        } else {
          displayMessage = 'Voice message';
        }
      } else if (displayIsEmpty && last.messageType == MessageType.poll) {
        displayMessage = 'Poll';
      } else if (displayIsEmpty && last.messageType == MessageType.contact ||
          last.messageType == MessageType.contact) {
        displayMessage = _extractContactName(last.message);
      } else if (looksLikeJson) {
        final msgLower = displayMessage.toLowerCase();
        if (msgLower.contains('"messagetype":"image"') ||
            msgLower.contains('"message_type":"image"') ||
            msgLower.contains('messagetype":"i') ||
            last.messageType == MessageType.image) {
          displayMessage = 'Photo';
        } else if (msgLower.contains('"messagetype":"document"') ||
            msgLower.contains('"messagetype":"pdf"') ||
            msgLower.contains('"message_type":"document"') ||
            last.messageType == MessageType.document) {
          final fileName = (last.fileName ?? '').trim();
          displayMessage = fileName.isNotEmpty ? fileName : 'PDF';
        } else if (msgLower.contains('"messagetype":"video"') ||
            msgLower.contains('"message_type":"video"') ||
            last.messageType == MessageType.video) {
          displayMessage = 'Video';
        } else if (msgLower.contains('"messagetype":"audio"') ||
            msgLower.contains('"message_type":"audio"') ||
            last.messageType == MessageType.audio) {
          final dur = last.audioDuration;
          if (dur != null && dur > 0) {
            final mins = (dur ~/ 60).toString().padLeft(2, '0');
            final secs = (dur.toInt() % 60).toString().padLeft(2, '0');
            displayMessage = 'Voice message  $mins:$secs';
          } else {
            displayMessage = 'Voice message';
          }
        } else if (msgLower.contains('"messagetype":"poll"') ||
            msgLower.contains('"message_type":"poll"') ||
            last.messageType == MessageType.poll) {
          displayMessage = 'Poll';
        } else if (msgLower.contains('"messagetype":"contact"') ||
            msgLower.contains('"message_type":"contact"') ||
            msgLower.contains('"contactname"') ||
            msgLower.contains('"contact_name"') ||
            msgLower.contains('"contact_mobile_number"') ||
            last.messageType == MessageType.contact) {
          displayMessage = _extractContactName(last.message);
        } else {
          displayMessage = 'Media';
        }
      }

      final isOutgoing =
          currentUserId != null &&
          currentUserId!.isNotEmpty &&
          last.senderId == currentUserId;
      if (last.messageType == MessageType.text && last.isFollowUp) {
        final trimmed = displayMessage.trimLeft();
        if (isOutgoing) {
          if (!trimmed.startsWith(_followUpPrefix)) {
            displayMessage = '$_followUpPrefix $trimmed';
          }
        } else {
          if (trimmed.startsWith(_followUpPrefix)) {
            displayMessage = trimmed
                .substring(_followUpPrefix.length)
                .trimLeft();
          }
        }
      }
    }

    final time = showActivityPreview
        ? _formatTime(contact.lastActivity!.timestamp)
        : (contact.lastMessage != null
              ? _formatTime(
                  isDeletedPreview
                      ? contact.lastMessage!.updatedAt
                      : contact.lastMessage!.createdAt,
                )
              : '');

    final isRead = contact.lastMessage?.isRead ?? false;
    final isOutgoingMessage =
        currentUserId != null &&
        contact.lastMessage != null &&
        contact.lastMessage!.senderId == currentUserId;
    final messageStatus = contact.lastMessage?.messageStatus ?? 'sent';

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final avatarSize = responsive.size(48);
    final horizontalPadding = responsive.spacing(16);
    final verticalPadding = responsive.spacing(11);

    // Check if this contact has unviewed stories
    final unviewedUserIds = ref.watch(unviewedStoriesUserIdsProvider);
    final hasUnviewedStory = unviewedUserIds.contains(userId);

    return InkWell(
      onTap: () async {
        if (currentUserId == null) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('User not authenticated')),
            );
          }
          return;
        }

        try {
          await NotificationLocalService.clearChatNotifications(userId);
        } catch (_) {}

        ref.read(notificationCountsProvider.notifier).clearNotification(userId);

        if (context.mounted) {
          await Navigator.pushNamed(
            context,
            RouteNames.oneToOneChat,
            arguments: {
              'contactName': name,
              'receiverId': user.id,
              'currentUserId': currentUserId,
            },
          );

          await onNavigateBack();
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalPadding,
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => onAvatarTap(
                name,
                user.id,
                user.mobileNo,
                mergedChatPictureUrl,
                chatPictureVersion,
              ),
              child: hasUnviewedStory
                  ? _buildAvatarWithStoriesRing(
                      avatarSize: avatarSize,
                      ringWidth: responsive.size(2.5),
                      userId: user.id,
                      chatPictureUrl: mergedChatPictureUrl,
                      chatPictureVersion: chatPictureVersion,
                      isDark: isDark,
                      context: context,
                      contactName: name,
                    )
                  : CachedCircleAvatar(
                      key: ValueKey('chat_avatar_${user.id}'),
                      chatPictureUrl: mergedChatPictureUrl,
                      chatPictureVersion: chatPictureVersion,
                      radius: avatarSize / 2,
                      backgroundColor: AppColors.lighterGrey,
                      iconColor: AppColors.colorGrey,
                      contactName: name,
                    ),
            ),
            SizedBox(width: responsive.spacing(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: responsive.size(16),
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppColors.colorBlack,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: responsive.spacing(4)),
                  Row(
                    children: [
                      if (isOutgoingMessage && !isTyping && !isDeletedPreview)
                        ..._buildMessageStatusIcon(
                          responsive,
                          messageStatus,
                          isRead,
                        ),
                      if (isOutgoingMessage && !isTyping && !isDeletedPreview)
                        SizedBox(width: responsive.spacing(4)),
                      if (isDeletedPreview) ...[
                        Icon(
                          Icons.block,
                          size: responsive.size(16),
                          color: isDark ? Colors.white70 : AppColors.colorGrey,
                        ),
                        SizedBox(width: responsive.spacing(4)),
                      ],
                      if (!isTyping &&
                          !isDeletedPreview &&
                          contact.lastMessage != null &&
                          contact.lastMessage!.messageType ==
                              MessageType.image) ...[
                        Icon(
                          Icons.photo,
                          size: responsive.size(16),
                          color: isDark ? Colors.white70 : AppColors.colorGrey,
                        ),
                        SizedBox(width: responsive.spacing(4)),
                      ],
                      if (!isTyping &&
                          !isDeletedPreview &&
                          contact.lastMessage != null &&
                          contact.lastMessage!.messageType ==
                              MessageType.document) ...[
                        Icon(
                          Icons.picture_as_pdf,
                          size: responsive.size(16),
                          color: isDark ? Colors.white70 : AppColors.colorGrey,
                        ),
                        SizedBox(width: responsive.spacing(4)),
                      ],
                      // Stories comment icon
                      if (!isTyping &&
                          !isDeletedPreview &&
                          isStoriesComment) ...[
                        Image.asset(
                          ImageAssets.chatStoriesIcon,
                          width: responsive.size(16),
                          height: responsive.size(16),
                          color: isDark ? Colors.white70 : AppColors.colorGrey,
                        ),
                        SizedBox(width: responsive.spacing(4)),
                      ],
                      // Audio/voice note icon (waveform)
                      if (!isTyping &&
                          !isDeletedPreview &&
                          contact.lastMessage != null &&
                          contact.lastMessage!.messageType ==
                              MessageType.audio) ...[
                        Icon(
                          Icons.graphic_eq_rounded,
                          size: responsive.size(16),
                          color: isDark ? Colors.white70 : AppColors.colorGrey,
                        ),
                        SizedBox(width: responsive.spacing(4)),
                      ],
                      // Contact message icon
                      if (!isTyping &&
                          !isDeletedPreview &&
                          contact.lastMessage != null &&
                          contact.lastMessage!.messageType ==
                              MessageType.contact) ...[
                        Icon(
                          Icons.person,
                          size: responsive.size(16),
                          color: isDark ? Colors.white70 : AppColors.colorGrey,
                        ),
                        SizedBox(width: responsive.spacing(4)),
                      ],
                      Expanded(
                        child: Text(
                          displayMessage,
                          style: TextStyle(
                            fontSize: responsive.size(16),
                            color: isTyping
                                ? AppColors.primary
                                : (hasUnread
                                      ? (isDark
                                            ? Colors.white
                                            : AppColors.colorBlack)
                                      : (isDark
                                            ? Colors.white70
                                            : AppColors.colorGrey)),
                            fontWeight: hasUnread || isTyping
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  time,
                  style: TextStyle(
                    fontSize: responsive.size(12),
                    color: hasUnread
                        ? AppColors.primary
                        : (isDark ? Colors.white70 : AppColors.colorGrey),
                    fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                if (hasUnread)
                  Container(
                    margin: EdgeInsets.only(top: responsive.spacing(4)),
                    height: responsive.size(20),
                    constraints: BoxConstraints(minWidth: responsive.size(20)),
                    padding: EdgeInsets.symmetric(
                      horizontal: responsive.spacing(6),
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(responsive.size(20)),
                    ),
                    child: Center(
                      child: Text(
                        unreadCount > 99 ? '99+' : unreadCount.toString(),
                        style: TextStyle(
                          fontSize: responsive.size(11),
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildMessageStatusIcon(
    ResponsiveSize responsive,
    String messageStatus,
    bool isRead,
  ) {
    final status = ChatMessageModel.normalizeMessageStatus(
      messageStatus,
      isRead: isRead,
    );

    return [
      MessageDeliveryStatusIcon(
        status: status,
        size: responsive.size(16),
        useChatListStyle: true,
      ),
    ];
  }

  /// Extract contact name from contact message JSON payload
  String _extractContactName(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return 'Contact';

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map) {
        final data = Map<String, dynamic>.from(decoded);
        String? name = data['name']?.toString();
        name ??= data['contactName']?.toString();
        name ??= data['displayName']?.toString();
        name ??= data['fullName']?.toString();
        name ??= data['title']?.toString();
        name ??= data['contact_name']?.toString();
        if (name != null && name.trim().isNotEmpty) {
          return name.trim();
        }
      }
    } catch (_) {}

    // Fallback: try to parse as plain text lines
    final lines = trimmed
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (lines.isNotEmpty && !lines.first.startsWith('{')) {
      return lines.first;
    }

    return 'Contact';
  }

  /// Builds the avatar wrapped with a stories ring gradient
  /// when the contact has unviewed stories (Instagram/WhatsApp-style).
  Widget _buildAvatarWithStoriesRing({
    required double avatarSize,
    required double ringWidth,
    required String userId,
    required String? chatPictureUrl,
    required String? chatPictureVersion,
    required bool isDark,
    required BuildContext context,
    String? contactName,
  }) {
    final outerSize =
        avatarSize + ringWidth * 2 + 4; // 4 = gap between ring and avatar

    return Container(
      width: outerSize,
      height: outerSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.storiesCottonCandySky,
      ),
      child: Center(
        child: Container(
          width: outerSize - ringWidth * 2,
          height: outerSize - ringWidth * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark
                ? Theme.of(context).scaffoldBackgroundColor
                : Colors.white,
          ),
          child: Center(
            child: CachedCircleAvatar(
              key: ValueKey('chat_avatar_ring_$userId'),
              chatPictureUrl: chatPictureUrl,
              chatPictureVersion: chatPictureVersion,
              radius: (outerSize - ringWidth * 2 - 4) / 2,
              backgroundColor: AppColors.lighterGrey,
              iconColor: AppColors.colorGrey,
              contactName: contactName,
            ),
          ),
        ),
      ),
    );
  }
}
