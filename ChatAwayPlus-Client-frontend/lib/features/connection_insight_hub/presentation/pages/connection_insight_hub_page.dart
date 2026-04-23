import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/themes/colors/app_colors.dart';
import 'package:chataway_plus/features/chat/data/services/chat_engine/index.dart';
import 'package:chataway_plus/features/contacts/data/models/contact_local.dart';
import 'package:chataway_plus/features/contacts/presentation/providers/contacts_management.dart';
import 'package:chataway_plus/core/database/tables/chat/follow_ups_table.dart';
import 'package:chataway_plus/core/storage/token_storage.dart';
import 'package:chataway_plus/features/chat/data/services/local/follow_ups_local_db_service.dart';
import '../widgets/chat_profile_picture_viewer.dart';
import '../widgets/blocked_contact_action_tile.dart';
import '../widgets/share_your_voice_tile.dart';
import '../widgets/follow_ups_section.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:chataway_plus/features/shared/widgets/avatars/cached_circle_avatar.dart';
import 'package:chataway_plus/core/dialog_box/app_dialog_box.dart';

final bool _showSharedContent = false;
final bool _showStarredMessages = false;
final bool _showLinks = false;
final bool _showMuteNotifications = true;

class ConnectionInsightHubPage extends ConsumerStatefulWidget {
  const ConnectionInsightHubPage({
    super.key,
    required this.contactName,
    required this.contactId,
    required this.mobileNumber,
    this.chatPictureUrl,
  });

  final String contactName;
  final String contactId;
  final String mobileNumber;
  final String? chatPictureUrl;

  @override
  ConsumerState<ConnectionInsightHubPage> createState() =>
      _ConnectionInsightHubPageState();
}

class _ConnectionInsightHubPageState
    extends ConsumerState<ConnectionInsightHubPage> {
  StreamSubscription? _profileUpdateSub;
  bool _isLoadingFollowUps = false;
  bool _showAllFollowUps = false;
  List<FollowUpEntry> _followUpEntries = [];

  String _normalizePhone(String input) {
    final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length > 10 ? digits.substring(digits.length - 10) : digits;
  }

  ContactLocal? _findContact(List<ContactLocal> contacts) {
    if (widget.contactId.trim().isNotEmpty) {
      for (final c in contacts) {
        if ((c.userDetails?.userId ?? '').trim() == widget.contactId.trim()) {
          return c;
        }
      }
    }

    final normalized = _normalizePhone(widget.mobileNumber);
    if (normalized.isNotEmpty) {
      for (final c in contacts) {
        if (_normalizePhone(c.mobileNo) == normalized) {
          return c;
        }
      }
    }

    return null;
  }

  Future<void> _loadFollowUps() async {
    final currentUserId =
        (await TokenSecureStorage.instance.getCurrentUserIdUUID())?.trim() ??
        '';
    final contactId = widget.contactId.trim();
    if (currentUserId.isEmpty || contactId.isEmpty) {
      if (mounted) {
        setState(() {
          _followUpEntries = [];
          _showAllFollowUps = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() => _isLoadingFollowUps = true);
    }

    try {
      final entries = await FollowUpsTable.instance.getFollowUpEntries(
        currentUserId: currentUserId,
        contactId: contactId,
        limit: 50,
      );
      if (!mounted) return;
      setState(() {
        _followUpEntries = entries;
        _isLoadingFollowUps = false;
        if (_followUpEntries.length <= 1) {
          _showAllFollowUps = false;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingFollowUps = false);
    }
  }

  Future<void> _deleteFollowUp(FollowUpEntry entry) async {
    final currentUserId =
        (await TokenSecureStorage.instance.getCurrentUserIdUUID())?.trim() ??
        '';
    final contactId = widget.contactId.trim();

    if (currentUserId.isEmpty || contactId.isEmpty) return;

    try {
      // Use FollowUpsLocalDatabaseService to delete follow-up AND reset message flag
      final success = await FollowUpsLocalDatabaseService.instance
          .deleteFollowUpEntry(
            currentUserId: currentUserId,
            contactId: contactId,
            followUpText: entry.text,
            createdAt: entry.createdAt,
          );

      if (success && mounted) {
        setState(() {
          _followUpEntries.removeWhere(
            (e) => e.text == entry.text && e.createdAt == entry.createdAt,
          );
          if (_followUpEntries.length <= 1) {
            _showAllFollowUps = false;
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Follow-up deleted successfully'),
            duration: Duration(seconds: 2),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete follow-up'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error deleting follow-up'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    unawaited(
      ref.read(contactsManagementNotifierProvider.notifier).loadFromCache(),
    );
    _profileUpdateSub = ChatEngineService.instance.profileUpdateStream.listen((
      update,
    ) async {
      if (!mounted) return;

      if (widget.contactId.trim().isNotEmpty &&
          update.userId.trim() != widget.contactId.trim()) {
        return;
      }

      await ref
          .read(contactsManagementNotifierProvider.notifier)
          .loadFromCache();
    });

    unawaited(_loadFollowUps());
  }

  @override
  void didUpdateWidget(covariant ConnectionInsightHubPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.contactId.trim() != widget.contactId.trim()) {
      unawaited(_loadFollowUps());
    }
  }

  @override
  void dispose() {
    _profileUpdateSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appUsers = ref.watch(appUserContactsProvider);
    final nonAppUsers = ref.watch(nonAppUserContactsProvider);
    final contact = _findContact([...appUsers, ...nonAppUsers]);
    final voiceText = (contact?.userDetails?.recentStatus?.content ?? '')
        .trim();
    final resolvedName = (contact?.preferredDisplayName ?? widget.contactName)
        .trim();
    final resolvedChatPictureUrl =
        contact?.userDetails?.chatPictureUrl ?? widget.chatPictureUrl;

    return ResponsiveLayoutBuilder(
      builder: (context, constraints, breakpoint) {
        final responsive = ResponsiveSize(
          context: context,
          constraints: constraints,
          breakpoint: breakpoint,
        );

        // DISABLED: Media and Documents data (can be uncommented when features are re-enabled)
        // final sharedMedia = List.generate(
        //   8,
        //   (index) => 'https://picsum.photos/seed/media_$index/400/400',
        // );
        final sharedLinks = [
          'https://example.com/news/launch',
          'https://blog.chataway.plus/product-update',
          'https://youtu.be/launch-demo',
        ];
        // final sharedDocs = [
        //   'Trip_itinerary.pdf',
        //   'Budget.xlsx',
        //   'Guest_list.docx',
        // ];

        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            title: Text(
              'Connection Insight Hub',
              style: AppTextSizes.large(context).copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.iconPrimary,
              ),
            ),
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            elevation: 0,
            scrolledUnderElevation: 0,
            toolbarHeight: responsive.size(68),
            centerTitle: false,
            titleSpacing: 0,
            leadingWidth: responsive.size(50),
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back,
                color: AppColors.primary,
                size: responsive.size(24),
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => Navigator.of(context).pop(),
            ),
            iconTheme: IconThemeData(
              color: isDark ? Colors.white : Colors.black,
            ),
            actions: [
              Padding(
                padding: EdgeInsets.only(right: responsive.spacing(12)),
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => ChatProfilePictureViewer(
                          displayName: resolvedName,
                          chatPictureUrl: resolvedChatPictureUrl,
                        ),
                      ),
                    );
                  },
                  child: CachedCircleAvatar(
                    chatPictureUrl: resolvedChatPictureUrl,
                    radius: responsive.size(24),
                    backgroundColor: AppColors.greyLight,
                    iconColor: AppColors.iconSecondary,
                    contactName: resolvedName,
                  ),
                ),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: EdgeInsets.all(responsive.spacing(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionInfoTile(
                  icon: Icons.person_outline,
                  title: 'Contact name',
                  subtitle: resolvedName.trim().isNotEmpty
                      ? resolvedName
                      : 'Unknown',
                ),

                SizedBox(height: responsive.spacing(12)),

                // 1. Mobile number option styled like settings
                _SectionInfoTile(
                  icon: Icons.phone_android_rounded,
                  title: 'Mobile number',
                  subtitle: widget.mobileNumber.isNotEmpty
                      ? widget.mobileNumber
                      : 'Number unavailable',
                ),

                SizedBox(height: responsive.spacing(12)),

                ShareYourVoiceTile(
                  voiceText: voiceText,
                  responsive: responsive,
                  isDark: isDark,
                  statusOwnerId: widget.contactId,
                  // ⚠️ CRITICAL: statusId MUST be provided by backend when status exists
                  statusId: contact?.userDetails?.recentStatus?.statusId,
                  statusCreatedAt:
                      contact?.userDetails?.recentStatus?.createdAt,
                ),

                SizedBox(height: responsive.spacing(12)),

                // 2. Follow-up section
                FollowUpsSection(
                  followUpEntries: _followUpEntries,
                  isLoading: _isLoadingFollowUps,
                  isExpanded: _showAllFollowUps,
                  onToggleExpanded: _followUpEntries.length > 1
                      ? () => setState(() {
                          _showAllFollowUps = !_showAllFollowUps;
                        })
                      : null,
                  responsive: responsive,
                  isDark: isDark,
                  onFollowUpTap: (entry) {
                    // Navigate back to chat with follow-up entry for reply
                    Navigator.of(context).pop(entry);
                  },
                  onFollowUpDelete: _deleteFollowUp,
                ),

                SizedBox(height: responsive.spacing(12)),

                // 3. Starred messages option styled like settings
                if (_showStarredMessages) ...[
                  const _SectionInfoTile(
                    icon: Icons.star_border_rounded,
                    title: 'Starred messages',
                    subtitle: 'No messages starred yet',
                  ),
                  SizedBox(height: responsive.spacing(12)),
                ],

                // 3. Links section styled like settings
                if (_showLinks) ...[
                  const _SectionInfoTile(
                    icon: Icons.link_rounded,
                    title: 'Links',
                    subtitle: 'Shared links from this chat will appear here',
                  ),
                  if (_showSharedContent) ...[
                    SizedBox(height: responsive.spacing(12)),
                    _LinksList(sharedLinks),
                  ],
                  SizedBox(height: responsive.spacing(12)),
                ],

                // 4. Documents section - DISABLED FOR NOW (can be re-enabled in future)
                // const _SectionInfoTile(
                //   icon: Icons.description_outlined,
                //   title: 'Documents',
                //   subtitle: 'All documents exchanged in this chat live here',
                // ),
                // if (_showSharedContent) ...[
                //   SizedBox(height: responsive.spacing(12)),
                //   _DocumentsList(sharedDocs),
                // ],
                // SizedBox(height: responsive.spacing(12)),

                // 5. Media section - DISABLED FOR NOW (can be re-enabled in future)
                // const _SectionInfoTile(
                //   icon: Icons.photo_library_rounded,
                //   title: 'Media',
                //   subtitle: 'Photos and videos shared recently',
                // ),
                // if (_showSharedContent) ...[
                //   SizedBox(height: responsive.spacing(12)),
                //   _HorizontalMediaStrip(imageUrls: sharedMedia),
                // ],
                // SizedBox(height: responsive.spacing(12)),

                // 6. Blocked contact section
                BlockedContactActionTile(
                  contactId: widget.contactId,
                  contactName: resolvedName,
                ),

                SizedBox(height: responsive.spacing(12)),

                // 7. Clean chat option
                _CleanChatTile(
                  contactName: resolvedName,
                  responsive: responsive,
                ),

                SizedBox(height: responsive.spacing(12)),

                // 8. Notifications / Mute section
                if (_showMuteNotifications) ...[
                  _NotificationTile(responsive: responsive),
                  SizedBox(height: responsive.spacing(12)),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

// DISABLED: Media strip widget (can be uncommented when Media section is re-enabled)
// class _HorizontalMediaStrip extends StatelessWidget {
//   const _HorizontalMediaStrip({required this.imageUrls});
//
//   final List<String> imageUrls;
//
//   @override
//   Widget build(BuildContext context) {
//     final width = MediaQuery.of(context).size.width;
//     final responsive = ResponsiveSize(
//       context: context,
//       constraints: BoxConstraints(maxWidth: width),
//       breakpoint: DeviceBreakpoint.fromWidth(width),
//     );
//
//     return SizedBox(
//       height: responsive.size(110),
//       child: ListView.separated(
//         scrollDirection: Axis.horizontal,
//         itemCount: imageUrls.length,
//         separatorBuilder: (_, __) => SizedBox(width: responsive.spacing(12)),
//         itemBuilder: (context, index) => ClipRRect(
//           borderRadius: BorderRadius.circular(responsive.size(16)),
//           child: Image.network(
//             imageUrls[index],
//             width: responsive.size(110),
//             height: responsive.size(110),
//             fit: BoxFit.cover,
//             errorBuilder: (_, __, ___) => Container(
//               width: responsive.size(110),
//               height: responsive.size(110),
//               color: AppColors.greyLight,
//               child: const Icon(Icons.image_not_supported_rounded),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }

class _LinksList extends StatelessWidget {
  const _LinksList(this.links);

  final List<String> links;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final responsive = ResponsiveSize(
      context: context,
      constraints: BoxConstraints(maxWidth: screenWidth),
      breakpoint: DeviceBreakpoint.fromWidth(screenWidth),
    );

    final cardWidth = screenWidth * 0.5;

    return SizedBox(
      height: responsive.size(52),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: links.length,
        separatorBuilder: (_, __) => SizedBox(width: responsive.spacing(12)),
        itemBuilder: (context, index) {
          final link = links[index];
          return Container(
            width: cardWidth,
            padding: EdgeInsets.symmetric(
              horizontal: responsive.spacing(10),
              vertical: responsive.spacing(8),
            ),
            decoration: BoxDecoration(
              color: isDark
                  ? Theme.of(context).colorScheme.surface
                  : Colors.white,
              borderRadius: BorderRadius.circular(responsive.size(14)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.link_rounded,
                  color: isDark ? Colors.white70 : AppColors.iconPrimary,
                ),
                SizedBox(width: responsive.spacing(12)),
                Expanded(
                  child: Text(
                    link,
                    style: AppTextSizes.regular(context).copyWith(
                      color: isDark ? Colors.white : AppColors.colorBlack,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.open_in_new_rounded,
                    color: AppColors.primary,
                  ),
                  onPressed: () {},
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// DISABLED: Documents list widget (can be uncommented when Documents section is re-enabled)
// class _DocumentsList extends StatelessWidget {
//   const _DocumentsList(this.documents);
//
//   final List<String> documents;
//
//   @override
//   Widget build(BuildContext context) {
//     final isDark = Theme.of(context).brightness == Brightness.dark;
//     final screenWidth = MediaQuery.of(context).size.width;
//     final responsive = ResponsiveSize(
//       context: context,
//       constraints: BoxConstraints(maxWidth: screenWidth),
//       breakpoint: DeviceBreakpoint.fromWidth(screenWidth),
//     );
//
//     final cardWidth = screenWidth * 0.5;
//
//     return SizedBox(
//       height: responsive.size(52),
//       child: ListView.separated(
//         scrollDirection: Axis.horizontal,
//         itemCount: documents.length,
//         separatorBuilder: (_, __) => SizedBox(width: responsive.spacing(12)),
//         itemBuilder: (context, index) {
//           final doc = documents[index];
//           return Container(
//             width: cardWidth,
//             padding: EdgeInsets.symmetric(
//               horizontal: responsive.spacing(10),
//               vertical: responsive.spacing(8),
//             ),
//             decoration: BoxDecoration(
//               color: isDark
//                   ? Theme.of(context).colorScheme.surface
//                   : Colors.white,
//               borderRadius: BorderRadius.circular(responsive.size(12)),
//             ),
//             child: Row(
//               children: [
//                 Icon(
//                   Icons.description_outlined,
//                   color: isDark ? Colors.white70 : AppColors.iconPrimary,
//                 ),
//                 SizedBox(width: responsive.spacing(12)),
//                 Expanded(
//                   child: Text(
//                     doc,
//                     style: AppTextSizes.regular(context).copyWith(
//                       color: isDark ? Colors.white : AppColors.colorBlack,
//                     ),
//                     maxLines: 1,
//                     overflow: TextOverflow.ellipsis,
//                   ),
//                 ),
//                 IconButton(
//                   icon: const Icon(
//                     Icons.download_rounded,
//                     color: AppColors.primary,
//                   ),
//                   onPressed: () {},
//                 ),
//               ],
//             ),
//           );
//         },
//       ),
//     );
//   }
// }

class _NotificationTile extends StatefulWidget {
  const _NotificationTile({required this.responsive});

  final ResponsiveSize responsive;

  @override
  State<_NotificationTile> createState() => _NotificationTileState();
}

class _NotificationTileState extends State<_NotificationTile> {
  bool _isMuted = true;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final responsive = widget.responsive;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        _isMuted
            ? Icons.notifications_off_outlined
            : Icons.notifications_active_outlined,
        color: isDark ? Colors.white70 : AppColors.colorGrey,
        size: responsive.size(24),
      ),
      title: Text(
        'Mute notifications',
        style: AppTextSizes.regular(
          context,
        ).copyWith(color: isDark ? Colors.white : AppColors.colorBlack),
      ),
      subtitle: Text(
        _isMuted ? 'Notifications muted' : 'Notifications enabled',
        style: AppTextSizes.small(
          context,
        ).copyWith(color: isDark ? Colors.white70 : AppColors.colorGrey),
      ),
      trailing: Transform.scale(
        scale: 0.85,
        child: Switch(
          value: _isMuted,
          onChanged: (value) {
            setState(() {
              _isMuted = value;
            });
          },
          activeThumbColor: AppColors.primary,
          activeTrackColor: AppColors.primary.withAlpha((0.5 * 255).round()),
          inactiveThumbColor: isDark ? Colors.white70 : Colors.grey.shade600,
          inactiveTrackColor: isDark ? Colors.white24 : Colors.grey.shade300,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}

class _CleanChatTile extends StatelessWidget {
  const _CleanChatTile({required this.contactName, required this.responsive});

  final String contactName;
  final ResponsiveSize responsive;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        Icons.cleaning_services_outlined,
        color: AppColors.error,
        size: responsive.size(24),
      ),
      title: Text(
        'Clean chat',
        style: AppTextSizes.regular(context).copyWith(color: AppColors.error),
      ),
      subtitle: Text(
        'Delete all messages in this chat',
        style: AppTextSizes.small(
          context,
        ).copyWith(color: isDark ? Colors.white70 : AppColors.colorGrey),
      ),
      onTap: () => _showCleanChatDialog(context),
    );
  }

  void _showCleanChatDialog(BuildContext context) {
    final name = contactName.trim().isNotEmpty
        ? contactName.trim()
        : 'this contact';

    AppDialogBox.show(
      context,
      icon: Icons.cleaning_services_rounded,
      iconColor: AppColors.error,
      title: 'Clean Chat',
      message:
          'Are you sure you want to delete all messages with $name?\n\n'
          'This action will permanently remove all chat history '
          'with this contact from your device. This cannot be undone.',
      dialogWidth: responsive.size(310),
      titleColor: AppColors.error,
      barrierDismissible: true,
      titleAlignment: TextAlign.left,
      messageAlignment: TextAlign.left,
      contentAlignment: CrossAxisAlignment.start,
      buttons: [
        DialogBoxButton(
          text: 'Cancel',
          onPressed: () => Navigator.pop(context),
          isPrimary: false,
        ),
        DialogBoxButton(
          text: 'Clean Chat',
          onPressed: () {
            Navigator.pop(context);
            // TODO: Backend integration pending — will be implemented
            // after discussion with backend developer.
          },
          isPrimary: true,
        ),
      ],
    );
  }
}

class _SectionInfoTile extends StatelessWidget {
  const _SectionInfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: isDark ? Colors.white70 : AppColors.colorGrey),
      title: Text(
        title,
        style: AppTextSizes.regular(
          context,
        ).copyWith(color: isDark ? Colors.white : AppColors.colorBlack),
      ),
      subtitle: Text(
        subtitle,
        style: AppTextSizes.small(
          context,
        ).copyWith(color: isDark ? Colors.white70 : AppColors.colorGrey),
      ),
    );
  }
}
