import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/core/themes/app_text_styles.dart';
import 'package:chataway_plus/core/connectivity/connectivity_service.dart';
import 'package:chataway_plus/core/snackbar/app_snackbar.dart';
import 'package:chataway_plus/core/storage/token_storage.dart';
import 'package:chataway_plus/core/routes/route_names.dart';
import 'package:chataway_plus/features/contacts/presentation/providers/contacts_management.dart';
import 'package:chataway_plus/features/contacts/data/models/contact_local.dart';
import 'package:chataway_plus/features/shared/widgets/avatars/cached_circle_avatar.dart';
import 'package:chataway_plus/features/voice_call/data/models/call_model.dart';
import 'package:chataway_plus/features/voice_call/presentation/providers/call_provider.dart';
import 'package:chataway_plus/features/voice_call/presentation/pages/outgoing_call_page.dart';
import 'package:chataway_plus/features/voice_call/presentation/pages/meeting_page.dart';

/// Calling Hub page — shows all existing app user contacts with call buttons
/// Accessed from the 3-dot menu in the Calls tab
class CallingHubPage extends ConsumerWidget {
  const CallingHubPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final contacts = ref.watch(appUserContactsProvider);

    return ResponsiveLayoutBuilder(
      builder: (context, constraints, breakpoint) {
        final responsive = ResponsiveSize(
          context: context,
          constraints: constraints,
          breakpoint: breakpoint,
        );

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
            elevation: 0,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_rounded,
                color: isDark ? Colors.white : AppColors.iconPrimary,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              'Calling Hub',
              style: AppTextSizes.heading(context).copyWith(
                color: isDark ? Colors.white : AppColors.iconPrimary,
                fontWeight: FontWeight.bold,
                fontSize: responsive.size(20),
              ),
            ),
          ),
          body: Column(
            children: [
              _buildMeetingButton(context, responsive, isDark),
              const Divider(height: 1),
              Expanded(
                child: contacts.isEmpty
                    ? _buildEmptyState(context, responsive, isDark)
                    : ListView.builder(
                        padding: EdgeInsets.only(top: responsive.spacing(8)),
                        itemCount: contacts.length,
                        itemBuilder: (context, index) {
                          return _buildContactTile(
                            context,
                            ref,
                            responsive,
                            isDark,
                            contacts[index],
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContactTile(
    BuildContext context,
    WidgetRef ref,
    ResponsiveSize responsive,
    bool isDark,
    ContactLocal contact,
  ) {
    final name = contact.preferredDisplayName;
    final profilePicUrl = contact.userDetails?.chatPictureUrl;

    return InkWell(
      onTap: () {
        if (contact.appUserId != null) {
          _initiateCall(
            context: context,
            ref: ref,
            contactId: contact.appUserId!,
            contactName: name,
            contactProfilePic: profilePicUrl,
          );
        }
      },
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: responsive.spacing(16),
          vertical: responsive.spacing(10),
        ),
        child: Row(
          children: [
            // Avatar
            CachedCircleAvatar(
              chatPictureUrl: profilePicUrl,
              radius: responsive.size(24),
              backgroundColor: isDark
                  ? Colors.grey.shade800
                  : Colors.grey.shade200,
              iconColor: isDark ? Colors.white54 : Colors.grey,
              contactName: name,
            ),
            SizedBox(width: responsive.spacing(14)),
            // Name + phone
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: responsive.size(16),
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : const Color(0xFF1F2937),
                    ),
                  ),
                  if (contact.mobileNo.isNotEmpty) ...[
                    SizedBox(height: responsive.spacing(2)),
                    Text(
                      contact.mobileNo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: responsive.size(13),
                        color: isDark
                            ? Colors.white38
                            : const Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Call buttons
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Video Call
                GestureDetector(
                  onTap: () {
                    if (contact.appUserId != null) {
                      _initiateCall(
                        context: context,
                        ref: ref,
                        contactId: contact.appUserId!,
                        contactName: name,
                        contactProfilePic: profilePicUrl,
                        callType: CallType.video,
                      );
                    }
                  },
                  child: Container(
                    padding: EdgeInsets.all(responsive.spacing(8)),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0EA5E9).withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.videocam_rounded,
                      color: Color(0xFF0EA5E9),
                      size: 22,
                    ),
                  ),
                ),
                SizedBox(width: responsive.spacing(8)),
                // Voice Call
                GestureDetector(
                  onTap: () {
                    if (contact.appUserId != null) {
                      _initiateCall(
                        context: context,
                        ref: ref,
                        contactId: contact.appUserId!,
                        contactName: name,
                        contactProfilePic: profilePicUrl,
                        callType: CallType.voice,
                      );
                    }
                  },
                  child: Container(
                    padding: EdgeInsets.all(responsive.spacing(8)),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.call_rounded,
                      color: AppColors.primary,
                      size: responsive.size(22),
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

  Future<void> _initiateCall({
    required BuildContext context,
    required WidgetRef ref,
    required String contactId,
    required String contactName,
    String? contactProfilePic,
    CallType callType = CallType.voice,
  }) async {
    if (!ConnectivityCache.instance.isOnline) {
      AppSnackbar.showOfflineWarning(
        context,
        "You're offline. Check your connection",
      );
      return;
    }

    final callId = 'call_${DateTime.now().millisecondsSinceEpoch}';
    final channelName = 'ch_${contactId}_$callId';

    ref
        .read(callProvider.notifier)
        .initiateCall(
          callId: callId,
          contactId: contactId,
          contactName: contactName,
          contactProfilePic: contactProfilePic,
          callType: callType,
        );

    final currentUserId = await TokenSecureStorage.instance.getCurrentUserIdUUID() ?? '';

    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            OutgoingCallPage(
              currentUserId: currentUserId,
              contactId: contactId,
              contactName: contactName,
              contactProfilePic: contactProfilePic,
              callType: callType,
              channelName: channelName,
              callId: callId,
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    ResponsiveSize responsive,
    bool isDark,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: responsive.size(100),
            height: responsive.size(100),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.1),
            ),
            child: Icon(
              Icons.people_outline_rounded,
              size: responsive.size(48),
              color: AppColors.primary.withValues(alpha: 0.5),
            ),
          ),
          SizedBox(height: responsive.spacing(20)),
          Text(
            'No contacts yet',
            style: TextStyle(
              fontSize: responsive.size(18),
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : const Color(0xFF374151),
            ),
          ),
          SizedBox(height: responsive.spacing(8)),
          Text(
            'Your contacts who use ChatAway+\nwill appear here',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: responsive.size(14),
              color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeetingButton(
    BuildContext context,
    ResponsiveSize responsive,
    bool isDark,
  ) {
    return InkWell(
      onTap: () => _showMeetingDialog(context),
      child: Padding(
        padding: EdgeInsets.all(responsive.spacing(16)),
        child: Row(
          children: [
            Container(
              width: responsive.size(48),
              height: responsive.size(48),
              decoration: BoxDecoration(
                color: const Color(0xFF0EA5E9).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.groups_rounded,
                color: Color(0xFF0EA5E9),
              ),
            ),
            SizedBox(width: responsive.spacing(14)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Start a Meeting',
                    style: TextStyle(
                      fontSize: responsive.size(16),
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1F2937),
                    ),
                  ),
                  Text(
                    'Join with an ID to talk with multiple people',
                    style: TextStyle(
                      fontSize: responsive.size(13),
                      color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? Colors.white24 : Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  void _showMeetingDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Join Meeting'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter Meeting ID (e.g. room123)',
            labelText: 'Meeting ID',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final id = controller.text.trim();
              if (id.isEmpty) return;
              Navigator.of(ctx).pop();
              
              final currentUserId = await TokenSecureStorage.instance.getCurrentUserIdUUID() ?? '';
              
              if (context.mounted) {
                Navigator.of(context).pushNamed(
                  RouteNames.meeting,
                  arguments: {
                    'meetingId': id,
                    'currentUserId': currentUserId,
                    'initialMeetingTitle': 'Meeting: $id',
                  },
                );
              }
            },
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }
}
