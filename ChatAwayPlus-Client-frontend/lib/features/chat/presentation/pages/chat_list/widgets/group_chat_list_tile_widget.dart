import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:chataway_plus/core/routes/route_names.dart';
import 'package:chataway_plus/features/shared/widgets/avatars/cached_circle_avatar.dart';
import 'package:chataway_plus/features/group_chat/models/group_models.dart';
import 'package:chataway_plus/features/chat/presentation/widgets/chat_ui/message_delivery_status_icon.dart';
import 'package:intl/intl.dart';

class GroupChatListTileWidget extends ConsumerWidget {
  final GroupModel group;
  final String? currentUserId;
  final ResponsiveSize responsive;
  final Future<void> Function() onNavigateBack;

  const GroupChatListTileWidget({
    super.key,
    required this.group,
    required this.currentUserId,
    required this.responsive,
    required this.onNavigateBack,
  });

  String _formatTime(DateTime dt) {
    final istTime = dt.toUtc().add(const Duration(hours: 5, minutes: 30));
    final now = DateTime.now();
    final diff = now.difference(istTime);

    if (diff.inDays == 0) {
      return DateFormat('h:mm a').format(istTime);
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return DateFormat('EEE').format(istTime);
    } else {
      return DateFormat('d/M/y').format(istTime);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final avatarSize = responsive.size(48);
    final horizontalPadding = responsive.spacing(16);
    final verticalPadding = responsive.spacing(11);

    final lastMsg = group.lastMessage;
    final String previewText = lastMsg != null 
      ? '${lastMsg.senderName}: ${lastMsg.previewText}'
      : group.description ?? 'No messages yet';

    final time = _formatTime(lastMsg?.createdAt ?? group.createdAt);

    return InkWell(
      onTap: () async {
        await Navigator.pushNamed(
          context,
          RouteNames.groupChat,
          arguments: {
            'groupId': group.id,
            'groupName': group.name,
            'groupIcon': group.icon,
          },
        );
        await onNavigateBack();
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalPadding,
        ),
        child: Row(
          children: [
            CachedCircleAvatar(
              key: ValueKey('group_avatar_${group.id}'),
              chatPictureUrl: group.icon,
              radius: avatarSize / 2,
              backgroundColor: AppColors.lighterGrey,
              iconColor: AppColors.colorGrey,
              contactName: group.name,
              isGroup: true,
            ),
            SizedBox(width: responsive.spacing(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.name,
                    style: TextStyle(
                      fontSize: responsive.size(16),
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppColors.colorBlack,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: responsive.spacing(4)),
                  Text(
                    previewText,
                    style: TextStyle(
                      fontSize: responsive.size(14),
                      color: isDark ? Colors.white70 : AppColors.colorGrey,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Text(
              time,
              style: TextStyle(
                fontSize: responsive.size(12),
                color: isDark ? Colors.white70 : AppColors.colorGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
