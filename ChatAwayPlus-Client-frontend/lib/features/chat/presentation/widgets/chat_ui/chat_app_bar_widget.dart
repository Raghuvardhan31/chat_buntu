import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/core/constants/api_url/api_urls.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:chataway_plus/core/routes/navigation_service.dart';
import 'package:chataway_plus/core/routes/route_names.dart';
import 'package:chataway_plus/features/shared/widgets/avatars/cached_circle_avatar.dart';
import 'package:chataway_plus/features/contacts/data/models/contact_local.dart';
import 'package:chataway_plus/features/chat/presentation/providers/chat_page_providers/user_status_provider.dart';
import 'package:chataway_plus/features/chat/presentation/providers/chat_list_providers/chat_list_provider.dart';
import 'package:chataway_plus/features/contacts/presentation/providers/contacts_management.dart';
import 'package:chataway_plus/features/chat/presentation/widgets/chat_ui/chat_date_utils.dart';
import 'package:chataway_plus/features/chat/models/chat_message_model.dart';

class ChatAppBarWidget extends ConsumerWidget implements PreferredSizeWidget {
  final String receiverId;
  final String contactName;
  final bool isEditing;
  final VoidCallback onBackPressed;
  final Future<void> Function() onLeaveChat;
  final Future<void> Function()? onNavigateBack;
  final void Function(dynamic)? onFollowUpSelected;
  final VoidCallback? onVoiceCall;
  final VoidCallback? onVideoCall;
  final int selectionCount;
  final VoidCallback? onClearSelection;
  final VoidCallback? onDeleteSelected;
  final VoidCallback? onForwardSelected;
  final VoidCallback? onEditSelected;

  const ChatAppBarWidget({
    super.key,
    required this.receiverId,
    required this.contactName,
    required this.isEditing,
    required this.onBackPressed,
    required this.onLeaveChat,
    this.onNavigateBack,
    this.onFollowUpSelected,
    this.onVoiceCall,
    this.onVideoCall,
    this.selectionCount = 0,
    this.onClearSelection,
    this.onDeleteSelected,
    this.onForwardSelected,
    this.onEditSelected,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userStatusAsync = ref.watch(specificUserStatusProvider(receiverId));
    final contacts = ref.watch(contactsListProvider);
    final chatListState = ref.watch(chatListNotifierProvider);

    final width = MediaQuery.of(context).size.width;
    final responsive = ResponsiveSize(
      context: context,
      constraints: BoxConstraints(maxWidth: width),
      breakpoint: DeviceBreakpoint.fromWidth(width),
    );

    final chatPictureUrl = _resolveChatPictureUrl(
      contacts,
      chatListState.contacts,
    );
    final String? resolvedChatPictureUrl;
    if (chatPictureUrl != null && chatPictureUrl.isNotEmpty) {
      resolvedChatPictureUrl = chatPictureUrl.startsWith('http')
          ? chatPictureUrl
          : '${ApiUrls.mediaBaseUrl}$chatPictureUrl';
    } else {
      resolvedChatPictureUrl = null;
    }

    String? chatPictureVersion;
    for (final contact in contacts) {
      final userId = contact.userDetails?.userId;
      if (userId == receiverId) {
        chatPictureVersion = contact.userDetails?.chatPictureVersion;
        break;
      }
    }

    final mobileNumber = _resolveMobileNumber(contacts, chatListState.contacts);
    final resolvedName = _resolveContactName(contacts, chatListState.contacts);

    void openConnectionInsightHub() {
      NavigationService.pushNamed(
        RouteNames.profile,
        arguments: {
          'contactName': resolvedName,
          'contactId': receiverId,
          'mobileNumber': mobileNumber,
          'chatPictureUrl': resolvedChatPictureUrl,
        },
      ).then((result) {
        onNavigateBack?.call();
        // Pass the follow-up entry result to parent if available
        if (result != null && onFollowUpSelected != null) {
          onFollowUpSelected!(result);
        }
      });
    }

    final isSelectionMode = selectionCount > 0;

    return AppBar(
      backgroundColor: isSelectionMode 
          ? (isDark ? const Color(0xFF1F2C34) : const Color(0xFF008069))
          : Theme.of(context).scaffoldBackgroundColor,
      surfaceTintColor: Colors.transparent,
      elevation: 1,
      iconTheme: IconThemeData(
        color: (isSelectionMode || isDark) ? Colors.white : Colors.black,
      ),
      titleSpacing: responsive.spacing(isSelectionMode ? 16 : 2),
      leading: isSelectionMode
          ? IconButton(
              icon: const Icon(Icons.close),
              onPressed: onClearSelection,
            )
          : IconButton(
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
      title: isSelectionMode
          ? Text(
              selectionCount.toString(),
              style: TextStyle(
                fontSize: responsive.size(20),
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: openConnectionInsightHub,
                  child: CachedCircleAvatar(
                    chatPictureUrl: chatPictureUrl,
                    chatPictureVersion: chatPictureVersion,
                    radius: responsive.size(18),
                    backgroundColor: AppColors.lighterGrey,
                    iconColor: AppColors.colorGrey,
                    contactName: resolvedName,
                  ),
                ),
                SizedBox(width: responsive.spacing(10)),
                Expanded(
                  child: GestureDetector(
                    onTap: openConnectionInsightHub,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          resolvedName,
                          style: TextStyle(
                            fontSize: responsive.size(18),
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: responsive.spacing(2)),
                        userStatusAsync.when(
                          data: (status) {
                            if (status == null) return const SizedBox.shrink();

                            if (status.isOnline) {
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: responsive.size(8),
                                    height: responsive.size(8),
                                    decoration: const BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  SizedBox(width: responsive.spacing(4)),
                                  Flexible(
                                    child: Text(
                                      'Online',
                                      style: TextStyle(
                                        fontSize: responsive.size(12),
                                        color: Colors.green,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              );
                            } else {
                              final lastSeen = ChatDateUtils.formatLastSeen(
                                status.lastSeen,
                              );
                              if (lastSeen.isEmpty) {
                                return const SizedBox.shrink();
                              }
                              return Text(
                                lastSeen,
                                style: TextStyle(
                                  fontSize: responsive.size(12),
                                  color: isDark ? Colors.white70 : Colors.grey[600],
                                  fontWeight: FontWeight.w400,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              );
                            }
                          },
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      actions: isSelectionMode
          ? [
              if (selectionCount == 1 && onEditSelected != null)
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.white),
                  onPressed: onEditSelected,
                ),
              if (onForwardSelected != null)
                IconButton(
                  icon: const Icon(Icons.forward, color: Colors.white),
                  onPressed: onForwardSelected,
                ),
              if (onDeleteSelected != null)
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.white),
                  onPressed: onDeleteSelected,
                ),
              SizedBox(width: responsive.spacing(4)),
            ]
          : (isEditing
              ? [
                  Padding(
                    padding: EdgeInsets.only(right: responsive.spacing(8)),
                    child: Icon(
                      Icons.edit,
                      color: AppColors.primary,
                      size: responsive.size(24),
                    ),
                  ),
                ]
              : [
                  if (onVideoCall != null)
                    IconButton(
                      icon: Icon(
                        Icons.videocam_rounded,
                        color: isDark ? Colors.white : Colors.black,
                        size: responsive.size(24),
                      ),
                      onPressed: onVideoCall,
                    ),
                  if (onVoiceCall != null)
                    IconButton(
                      icon: Icon(
                        Icons.call_rounded,
                        color: isDark ? Colors.white : Colors.black,
                        size: responsive.size(22),
                      ),
                      onPressed: onVoiceCall,
                    ),
                  SizedBox(width: responsive.spacing(4)),
                ]),
    );
  }

  String? _resolveChatPictureUrl(
    List<ContactLocal> contacts,
    List<ChatContactModel> chatContacts,
  ) {
    for (final contact in contacts) {
      final userId = contact.userDetails?.userId;
      if (userId == receiverId) {
        final url = contact.userDetails?.chatPictureUrl;
        if (url != null && url.isNotEmpty) return url;
        break;
      }
    }

    for (final chatContact in chatContacts) {
      if (chatContact.user.id == receiverId) {
        final url = chatContact.user.chatPictureUrl;
        if (url != null && url.isNotEmpty) return url;
        break;
      }
    }

    return null;
  }

  String _resolveMobileNumber(
    List<ContactLocal> contacts,
    List<ChatContactModel> chatContacts,
  ) {
    String normalizePhone(String input) {
      final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
      return digits.length > 10 ? digits.substring(digits.length - 10) : digits;
    }

    String mobileNumber = '';

    for (final contact in contacts) {
      final userId = contact.userDetails?.userId;
      if (userId == receiverId) {
        mobileNumber = contact.mobileNo;
        break;
      }
    }

    String chatListMobile = '';
    for (final chatContact in chatContacts) {
      if (chatContact.user.id == receiverId) {
        chatListMobile = chatContact.user.mobileNo;
        break;
      }
    }

    if (mobileNumber.isEmpty && chatListMobile.isNotEmpty) {
      final chatNorm = normalizePhone(chatListMobile);
      if (chatNorm.isNotEmpty) {
        for (final contact in contacts) {
          if (normalizePhone(contact.mobileNo) == chatNorm) {
            mobileNumber = contact.mobileNo;
            break;
          }
        }
      }
    }

    if (mobileNumber.isEmpty) {
      mobileNumber = chatListMobile;
    }

    return mobileNumber;
  }

  String _resolveContactName(
    List<ContactLocal> contacts,
    List<ChatContactModel> chatContacts,
  ) {
    for (final contact in contacts) {
      final userId = contact.userDetails?.userId;
      if (userId == receiverId) {
        final name = contact.preferredDisplayName.trim();
        if (name.isNotEmpty) return name;
        break;
      }
    }

    String normalizePhone(String input) {
      final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
      return digits.length > 10 ? digits.substring(digits.length - 10) : digits;
    }

    String chatListMobile = '';
    for (final chatContact in chatContacts) {
      if (chatContact.user.id == receiverId) {
        chatListMobile = chatContact.user.mobileNo;
        break;
      }
    }

    if (chatListMobile.trim().isNotEmpty) {
      final chatNorm = normalizePhone(chatListMobile);
      if (chatNorm.isNotEmpty) {
        for (final contact in contacts) {
          if (normalizePhone(contact.mobileNo) == chatNorm) {
            final name = contact.preferredDisplayName.trim();
            if (name.isNotEmpty) return name;
            break;
          }
        }
      }
    }

    for (final chatContact in chatContacts) {
      if (chatContact.user.id == receiverId) {
        final backendName =
            '${chatContact.user.firstName} ${chatContact.user.lastName}'.trim();
        if (backendName.isNotEmpty) return backendName;
        break;
      }
    }

    final fallback = contactName.trim();
    return fallback.isNotEmpty ? fallback : 'ChatAway user';
  }
}
