import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/core/themes/app_text_styles.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:chataway_plus/core/routes/navigation_service.dart';
import 'package:chataway_plus/core/routes/route_names.dart';
import 'package:chataway_plus/core/storage/token_storage.dart';
import 'package:chataway_plus/core/constants/assets/image_assets.dart';
import 'package:chataway_plus/features/chat/data/services/local/received_likes_local_db.dart';
import 'package:chataway_plus/features/contacts/data/datasources/contacts_database_service.dart';
import 'package:chataway_plus/features/contacts/data/models/contact_local.dart';
import 'package:chataway_plus/features/shared/widgets/avatars/cached_circle_avatar.dart';
import 'package:chataway_plus/features/chat/presentation/pages/media_viewer/app_user_chat_picture_view.dart';

/// Likes Hub Page — Single-page design
///
/// Shows all contacts who liked the user's Chat Picture or Shared Their Voice
/// in a single merged list (no tabs). Each entry is visually distinguished:
/// - Chat Picture likes: camera icon + "Chat Picture" text displayed right of the time
/// - Share Your Voice likes: "SYVT" label with mic icon displayed right of the time
class LikesHubPage extends StatefulWidget {
  const LikesHubPage({super.key});

  @override
  State<LikesHubPage> createState() => _LikesHubPageState();
}

class _LikesHubPageState extends State<LikesHubPage>
    with WidgetsBindingObserver {
  int? _selectedIndex;
  List<ReceivedLikeEntry> _allLikes = [];
  Map<String, ContactLocal> _contactsMap =
      {}; // userId -> contact for profile photos
  bool _isLoading = true;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadLikes();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Reload likes when app resumes — new likes may have arrived via FCM
    // while the app was backgrounded
    if (state == AppLifecycleState.resumed && mounted) {
      _loadLikes();
    }
  }

  Future<void> _loadLikes() async {
    try {
      final currentUserId = await TokenSecureStorage.instance
          .getCurrentUserIdUUID();
      if (currentUserId == null || currentUserId.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      _currentUserId = currentUserId;

      final likes = await ReceivedLikesLocalDatabaseService.instance
          .getAllLikes(currentUserId: currentUserId);

      // Deduplicate: keep only the newest entry per (fromUserId, likeType, statusId).
      // This handles any old duplicate rows already in the DB before the
      // insert-level dedup was added. Entries are already sorted newest-first.
      final seen = <String>{};
      final deduped = <ReceivedLikeEntry>[];
      for (final entry in likes) {
        final key =
            '${entry.fromUserId}_${entry.likeType}_${entry.statusId ?? ''}';
        if (seen.contains(key)) continue;
        seen.add(key);
        deduped.add(entry);
      }

      // Batch contact loading: load all unique contacts in one pass
      // Store full contact data for profile photos
      final uniqueUserIds = deduped.map((e) => e.fromUserId).toSet();
      final contactNameMap = <String, String>{};
      final contactsMap = <String, ContactLocal>{};
      for (final userId in uniqueUserIds) {
        try {
          final contact = await ContactsDatabaseService.instance
              .getContactByUserId(userId);
          if (contact != null) {
            final deviceName = contact.preferredDisplayName.trim();
            if (deviceName.isNotEmpty) {
              contactNameMap[userId] = deviceName;
            }
            contactsMap[userId] = contact;
          }
        } catch (_) {}
      }

      // Resolve display names using the pre-loaded map
      final resolved = deduped.map((entry) {
        final resolvedName =
            contactNameMap[entry.fromUserId] ?? entry.fromUserName;
        return ReceivedLikeEntry(
          id: entry.id,
          currentUserId: entry.currentUserId,
          fromUserId: entry.fromUserId,
          fromUserName: resolvedName,
          fromUserProfilePic: entry.fromUserProfilePic,
          likeType: entry.likeType,
          statusId: entry.statusId,
          likeId: entry.likeId,
          message: entry.message,
          createdAt: entry.createdAt,
        );
      }).toList();

      if (mounted) {
        setState(() {
          _allLikes = resolved;
          _contactsMap = contactsMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [LikesHub] Failed to load likes: $e');
      }
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openChat(ReceivedLikeEntry entry) {
    if (_currentUserId == null || _currentUserId!.isEmpty) return;
    setState(() => _selectedIndex = null);
    Navigator.pushNamed(
      context,
      RouteNames.oneToOneChat,
      arguments: {
        'contactName': entry.fromUserName,
        'receiverId': entry.fromUserId,
        'currentUserId': _currentUserId!,
      },
    );
  }

  Future<void> _deleteLike(int index) async {
    if (index < 0 || index >= _allLikes.length) return;
    final entry = _allLikes[index];
    await ReceivedLikesLocalDatabaseService.instance.deleteLike(entry.id);
    if (mounted) {
      setState(() {
        _allLikes.removeAt(index);
        _selectedIndex = null;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  static String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  ResponsiveSize _responsiveFor(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return ResponsiveSize(
      context: context,
      constraints: BoxConstraints(maxWidth: width),
      breakpoint: DeviceBreakpoint.fromWidth(width),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final responsive = _responsiveFor(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        NavigationService.goToChatList();
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: _buildAppBar(context, responsive, isDark),
        body: SafeArea(
          top: false,
          bottom: true,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _allLikes.isEmpty
              ? _buildEmptyState(context, responsive, isDark)
              : _buildLikesList(context, responsive, isDark),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // APP BAR
  // ══════════════════════════════════════════════════════════════════════════

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    ResponsiveSize responsive,
    bool isDark,
  ) {
    return AppBar(
      backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      elevation: 0,
      scrolledUnderElevation: 0.0,
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
        onPressed: () => NavigationService.goToChatList(),
      ),
      title: Row(
        children: [
          Icon(
            Icons.favorite_rounded,
            color: const Color(0xFFE91E63),
            size: responsive.size(22),
          ),
          SizedBox(width: responsive.spacing(8)),
          Text(
            'Likes Hub',
            style: AppTextSizes.large(context).copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.iconPrimary,
            ),
          ),
          SizedBox(width: responsive.spacing(10)),
          _buildCountBadge(
            _allLikes.length,
            const Color(0xFFE91E63),
            context,
            responsive,
          ),
        ],
      ),
    );
  }

  Widget _buildCountBadge(
    int count,
    Color color,
    BuildContext context,
    ResponsiveSize responsive,
  ) {
    if (count == 0) return const SizedBox.shrink();
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: responsive.spacing(7),
        vertical: responsive.spacing(2),
      ),
      decoration: BoxDecoration(
        color: color.withAlpha((0.15 * 255).round()),
        borderRadius: BorderRadius.circular(responsive.size(10)),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: AppTextSizes.getResponsiveSize(context, 11),
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // LIKES LIST — Single merged list
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildLikesList(
    BuildContext context,
    ResponsiveSize responsive,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header strip
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: responsive.spacing(20),
            vertical: responsive.spacing(12),
          ),
          color: isDark
              ? Colors.white.withAlpha((0.04 * 255).round())
              : Colors.grey.withAlpha((0.06 * 255).round()),
          child: Row(
            children: [
              Icon(
                Icons.access_time_rounded,
                size: responsive.size(14),
                color: isDark ? Colors.white38 : AppColors.colorGrey,
              ),
              SizedBox(width: responsive.spacing(6)),
              Text(
                'Disappears after 24 hours',
                style: AppTextSizes.small(context).copyWith(
                  color: isDark ? Colors.white38 : AppColors.colorGrey,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
        // List
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.only(
              top: responsive.spacing(4),
              bottom: responsive.spacing(100),
            ),
            itemCount: _allLikes.length,
            itemBuilder: (context, index) {
              return _buildLikeTile(
                context,
                _allLikes[index],
                index,
                responsive,
                isDark,
              );
            },
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // LIKE TILE — Dribbble-quality list item
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildLikeTile(
    BuildContext context,
    ReceivedLikeEntry entry,
    int index,
    ResponsiveSize responsive,
    bool isDark,
  ) {
    final isChatPicture = entry.isChatPicture;
    final isSelected = _selectedIndex == index;

    // Distinct color scheme per type
    final accentColor = isChatPicture
        ? const Color(0xFFE91E63) // Rose pink for Chat Picture
        : const Color(0xFFFF6D00); // Warm amber-orange for Voice
    final heartColor = accentColor; // Matches type: rose pink or amber-orange

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedIndex = isSelected ? null : index;
          });
        },
        splashColor: accentColor.withAlpha((0.08 * 255).round()),
        highlightColor: accentColor.withAlpha((0.04 * 255).round()),
        child: Container(
          color: isSelected
              ? accentColor.withAlpha((0.06 * 255).round())
              : Colors.transparent,
          padding: EdgeInsets.symmetric(
            horizontal: responsive.spacing(16),
            vertical: responsive.spacing(10),
          ),
          child: Row(
            children: [
              // ── Simple circle avatar (no ring) ──
              _buildSimpleAvatar(
                context,
                entry,
                accentColor,
                responsive,
                isDark,
              ),
              SizedBox(width: responsive.spacing(14)),

              // ── Name + time + type indicator ──
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name
                    Text(
                      entry.fromUserName,
                      style: AppTextSizes.regular(context).copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppColors.colorBlack,
                        letterSpacing: 0.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: responsive.spacing(4)),
                    // Time ago + type indicator (right of time)
                    Row(
                      children: [
                        Text(
                          _formatTimeAgo(entry.createdAt),
                          style: AppTextSizes.small(context).copyWith(
                            color: isDark
                                ? Colors.white54
                                : AppColors.colorGrey,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        SizedBox(width: responsive.spacing(8)),
                        _buildTypeIndicator(
                          context,
                          entry.isChatPicture
                              ? _LikeType.chatPicture
                              : _LikeType.voice,
                          responsive,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Selected: delete + chat icons ──
              if (isSelected) ...[
                GestureDetector(
                  onTap: () => _deleteLike(index),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: responsive.spacing(6),
                    ),
                    child: Icon(
                      Icons.delete_rounded,
                      size: responsive.size(22),
                      color: Colors.red.shade400,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => _openChat(entry),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: responsive.spacing(6),
                    ),
                    child: Image.asset(
                      ImageAssets.goingInsideChatIcon,
                      width: responsive.size(24),
                      height: responsive.size(24),
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
              ],

              // ── Heart icon (filled) — always visible ──
              Container(
                width: responsive.size(38),
                height: responsive.size(38),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: heartColor.withAlpha((0.10 * 255).round()),
                ),
                child: Center(
                  child: Icon(
                    Icons.favorite_rounded,
                    color: heartColor,
                    size: responsive.size(20),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Type indicator (right of time) ─────────────────────────────────────
  // Chat Picture: camera icon
  // Share Your Voice: "SYVT" text + mic icon

  Widget _buildTypeIndicator(
    BuildContext context,
    _LikeType type,
    ResponsiveSize responsive,
  ) {
    final isChatPicture = type == _LikeType.chatPicture;
    const greyColor = AppColors.colorGrey;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: responsive.spacing(7),
        vertical: responsive.spacing(3),
      ),
      decoration: BoxDecoration(
        color: greyColor.withAlpha((0.10 * 255).round()),
        borderRadius: BorderRadius.circular(responsive.size(8)),
      ),
      child: isChatPicture
          // Chat Picture: camera icon + "Chat Picture" text
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.camera_alt_rounded,
                  size: responsive.size(12),
                  color: greyColor,
                ),
                SizedBox(width: responsive.spacing(3)),
                Text(
                  'Chat Picture',
                  style: TextStyle(
                    fontSize: AppTextSizes.getResponsiveSize(context, 9),
                    fontWeight: FontWeight.w700,
                    color: greyColor,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            )
          // Share Your Voice: mic icon + "SYVT" text
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.mic_rounded,
                  size: responsive.size(12),
                  color: greyColor,
                ),
                SizedBox(width: responsive.spacing(3)),
                Text(
                  'SYVT',
                  style: TextStyle(
                    fontSize: AppTextSizes.getResponsiveSize(context, 9),
                    fontWeight: FontWeight.w700,
                    color: greyColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
    );
  }

  // ── Simple circle avatar (no ring) ─────────────────────────────────────

  Widget _buildSimpleAvatar(
    BuildContext context,
    ReceivedLikeEntry entry,
    Color accentColor,
    ResponsiveSize responsive,
    bool isDark,
  ) {
    final avatarSize = responsive.size(46);
    final contact = _contactsMap[entry.fromUserId];

    // Use CachedCircleAvatar like Express Hub if contact data is available
    if (contact != null) {
      return GestureDetector(
        onTap: () {
          Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute(
              builder: (_) => AppUserChatPictureView(
                displayName: entry.fromUserName,
                chatPictureUrl: contact.userDetails?.chatPictureUrl,
                chatPictureVersion: contact.userDetails?.chatPictureVersion,
                showLikeButton: false,
              ),
            ),
          );
        },
        child: CachedCircleAvatar(
          chatPictureUrl: contact.userDetails?.chatPictureUrl,
          chatPictureVersion: contact.userDetails?.chatPictureVersion,
          radius: avatarSize / 2,
          backgroundColor: AppColors.lighterGrey,
          iconColor: AppColors.iconPrimary,
          contactName: entry.fromUserName,
        ),
      );
    }

    // Fallback to initials if no contact data — still tappable for full view
    return GestureDetector(
      onTap: () {
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(
            builder: (_) => AppUserChatPictureView(
              displayName: entry.fromUserName,
              showLikeButton: false,
            ),
          ),
        );
      },
      child: Container(
        width: avatarSize,
        height: avatarSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: accentColor.withAlpha((0.12 * 255).round()),
        ),
        child: Center(
          child: Text(
            _getInitials(entry.fromUserName),
            style: TextStyle(
              fontSize: AppTextSizes.getResponsiveSize(context, 16),
              fontWeight: FontWeight.w700,
              color: accentColor,
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // EMPTY STATE
  // ══════════════════════════════════════════════════════════════════════════

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
            width: responsive.size(80),
            height: responsive.size(80),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFE91E63).withAlpha((0.10 * 255).round()),
            ),
            child: Center(
              child: Icon(
                Icons.favorite_outline_rounded,
                size: responsive.size(36),
                color: const Color(0xFFE91E63),
              ),
            ),
          ),
          SizedBox(height: responsive.spacing(20)),
          Text(
            'No likes yet',
            style: AppTextSizes.large(context).copyWith(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppColors.colorBlack,
            ),
          ),
          SizedBox(height: responsive.spacing(8)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: responsive.spacing(48)),
            child: Text(
              'Your admirers will show up here! When someone likes your chat picture or Share your voice text, you\'ll see it for 24 hours.',
              textAlign: TextAlign.center,
              style: AppTextSizes.regular(context).copyWith(
                color: isDark ? Colors.white54 : AppColors.colorGrey,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TYPE ENUM (used internally for UI styling)
// ══════════════════════════════════════════════════════════════════════════════

enum _LikeType { chatPicture, voice }
