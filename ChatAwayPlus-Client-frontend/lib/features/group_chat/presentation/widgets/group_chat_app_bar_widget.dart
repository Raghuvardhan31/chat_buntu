import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:chataway_plus/core/routes/navigation_service.dart';
import 'package:chataway_plus/core/routes/route_names.dart';
import 'package:chataway_plus/features/shared/widgets/avatars/cached_circle_avatar.dart';
import 'package:chataway_plus/features/group_chat/models/group_models.dart';
import 'package:chataway_plus/features/group_chat/presentation/providers/group_providers.dart';

class GroupChatAppBarWidget extends ConsumerWidget implements PreferredSizeWidget {
  final GroupModel? group;
  final String groupId;
  final String groupName;
  final String? groupIcon;
  final VoidCallback onBackPressed;
  final Future<void> Function() onLeaveChat;

  const GroupChatAppBarWidget({
    super.key,
    this.group,
    required this.groupId,
    required this.groupName,
    this.groupIcon,
    required this.onBackPressed,
    required this.onLeaveChat,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final width = MediaQuery.of(context).size.width;
    final responsive = ResponsiveSize(
      context: context,
      constraints: BoxConstraints(maxWidth: width),
      breakpoint: DeviceBreakpoint.fromWidth(width),
    );

    void openGroupInfo() {
      if (group != null) {
        NavigationService.pushNamed(
          RouteNames.groupInfo,
          arguments: {'group': group},
        );
      }
    }

    final memberCount = group?.members.length ?? 0;
    final typingUsers = ref.watch(groupTypingProvider(groupId));
    final isSomeoneTyping = typingUsers.isNotEmpty;

    return AppBar(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      surfaceTintColor: Colors.transparent,
      elevation: 1,
      iconTheme: IconThemeData(
        color: isDark ? Colors.white : Colors.black,
      ),
      titleSpacing: responsive.spacing(2),
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back,
          color: isDark ? Colors.white : Colors.black,
          size: responsive.size(24),
        ),
        onPressed: () async {
          await onLeaveChat();
          onBackPressed();
        },
      ),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: openGroupInfo,
            child: CachedCircleAvatar(
              chatPictureUrl: group?.icon ?? groupIcon,
              radius: responsive.size(18),
              backgroundColor: AppColors.lighterGrey,
              iconColor: AppColors.colorGrey,
              contactName: groupName,
            ),
          ),
          SizedBox(width: responsive.spacing(10)),
          Expanded(
            child: GestureDetector(
              onTap: openGroupInfo,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    groupName,
                    style: TextStyle(
                      fontSize: responsive.size(18),
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (isSomeoneTyping)
                    Text(
                      typingUsers.length == 1 ? 'Someone is typing...' : '${typingUsers.length} people typing...',
                      style: TextStyle(
                        fontSize: responsive.size(12),
                        color: Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  else if (memberCount > 0)
                    Text(
                      '$memberCount members',
                      style: TextStyle(
                        fontSize: responsive.size(12),
                        color: isDark ? Colors.white70 : Colors.grey[600],
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(
            Icons.videocam_rounded,
            color: isDark ? Colors.white : Colors.black,
            size: responsive.size(24),
          ),
          onPressed: () {
            // Group video call placeholder
          },
          tooltip: 'Group Video Call',
        ),
        IconButton(
          icon: Icon(
            Icons.call_rounded,
            color: isDark ? Colors.white : Colors.black,
            size: responsive.size(24),
          ),
          onPressed: () {
            // Group voice call placeholder
          },
          tooltip: 'Group Voice Call',
        ),
        SizedBox(width: responsive.spacing(4)),
      ],
    );
  }
}
