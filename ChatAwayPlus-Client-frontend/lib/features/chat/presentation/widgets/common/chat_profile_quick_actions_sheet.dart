import 'package:flutter/material.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/core/themes/app_text_styles.dart';
import 'package:chataway_plus/core/constants/assets/image_assets.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:chataway_plus/features/shared/widgets/avatars/cached_circle_avatar.dart';

/// A WhatsApp-style quick action sheet displayed when tapping a user's avatar.
///
/// Shows the enlarged profile picture along with quick actions like chat,
/// voice call, video call, love (react), and profile view. This widget is
/// intentionally decoupled from presentation logic so it can be plugged into
/// any `showModalBottomSheet` or overlay later.
class ChatProfileQuickActionsSheet extends StatelessWidget {
  const ChatProfileQuickActionsSheet({
    super.key,
    required this.displayName,
    this.avatarImageProvider,
    this.isLoved = false,
    this.syvtText,
    this.onPictureTap,
    this.onChat,
    this.onVoiceCall,
    this.onVideoCall,
    this.onLove,
    this.onProfile,
  });

  final String displayName;
  final ImageProvider<Object>? avatarImageProvider;
  final bool isLoved;
  final String? syvtText;
  final VoidCallback? onPictureTap;
  final VoidCallback? onChat;
  final VoidCallback? onVoiceCall;
  final VoidCallback? onVideoCall;
  final VoidCallback? onLove;
  final VoidCallback? onProfile;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ResponsiveLayoutBuilder(
        builder: (context, constraints, breakpoint) {
          final responsive = ResponsiveSize(
            context: context,
            constraints: constraints,
            breakpoint: breakpoint,
          );

          final basePadding = responsive.spacing(16);
          final sheetRadius = responsive.size(24);

          return Center(
            child: Padding(
              padding: EdgeInsets.all(basePadding),
              child: Container(
                width: constraints.maxWidth * 0.78,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(sheetRadius),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha((0.22 * 255).round()),
                      blurRadius: responsive.size(34),
                      offset: Offset(0, responsive.spacing(20)),
                    ),
                  ],
                ),
                child: _buildOverlayContent(
                  context,
                  padding: basePadding,
                  responsive: responsive,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOverlayContent(
    BuildContext context, {
    required double padding,
    required ResponsiveSize responsive,
  }) {
    final borderRadius = BorderRadius.circular(responsive.size(24));
    final placeholderIconSize = responsive.size(72);
    final titlePaddingVertical = responsive.spacing(11);
    final actionsPaddingHorizontal = responsive.spacing(10);
    final actionsPaddingVertical = responsive.spacing(8);
    final hasAvatar = avatarImageProvider != null;
    final effectiveOnPictureTap = onPictureTap;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.vertical(top: borderRadius.topLeft),
          child: AspectRatio(
            aspectRatio: 1,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: effectiveOnPictureTap,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (avatarImageProvider != null)
                    Image(image: avatarImageProvider!, fit: BoxFit.cover)
                  else
                    Container(
                      color: AppColors.greyLight,
                      child: Center(
                        child: Builder(
                          builder: (context) {
                            final initials = CachedCircleAvatar.getInitials(
                              displayName,
                            );
                            if (initials.isNotEmpty) {
                              final color = CachedCircleAvatar.getColorForName(
                                displayName,
                              );
                              return CircleAvatar(
                                radius: responsive.size(56),
                                backgroundColor: color,
                                child: Text(
                                  initials,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: responsive.size(42),
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              );
                            }
                            return Icon(
                              Icons.person,
                              size: placeholderIconSize,
                              color: AppColors.iconSecondary,
                            );
                          },
                        ),
                      ),
                    ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        vertical: titlePaddingVertical,
                        horizontal: padding,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withAlpha((0.75 * 255).round()),
                            Colors.black.withAlpha((0.35 * 255).round()),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          displayName,
                          textAlign: TextAlign.left,
                          style: AppTextSizes.large(
                            context,
                          ).copyWith(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              bottom: borderRadius.bottomLeft,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (syvtText != null && syvtText!.trim().isNotEmpty)
                _buildSyvtBanner(context, responsive),
              Divider(
                color: AppColors.greyLight,
                thickness: responsive.size(1),
                height: responsive.size(1),
              ),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: actionsPaddingHorizontal,
                  vertical: actionsPaddingVertical,
                ),
                child: _buildActionsRow(
                  context,
                  responsive,
                  canLove: hasAvatar,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSyvtBanner(BuildContext context, ResponsiveSize responsive) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: responsive.spacing(12),
        vertical: responsive.spacing(8),
      ),
      color: const Color(0xFFFFF3E0),
      child: Row(
        children: [
          Icon(
            Icons.mic_rounded,
            size: responsive.size(14),
            color: const Color(0xFFFF6D00),
          ),
          SizedBox(width: responsive.spacing(6)),
          Expanded(
            child: Text(
              'SYVT: ${syvtText!.trim()}',
              style: TextStyle(
                fontSize: responsive.size(11),
                fontWeight: FontWeight.w600,
                color: const Color(0xFFE65100),
                letterSpacing: 0.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsRow(
    BuildContext context,
    ResponsiveSize responsive, {
    required bool canLove,
  }) {
    final actions = [
      _ActionButtonData(
        icon: Icons.chat_bubble_rounded,
        label: 'Chat',
        onTap: onChat,
        assetPath: ImageAssets.alignLeft,
      ),
      // Call action hidden — calling service not yet available
      _ActionButtonData(
        icon: Icons.favorite_border_rounded,
        activeIcon: Icons.favorite_rounded,
        isActive: canLove ? isLoved : false,
        label: 'Love',
        onTap: onLove,
      ),
      _ActionButtonData(
        icon: Icons.person_outline_rounded,
        label: 'Profile',
        onTap: onProfile,
      ),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: actions
          .map(
            (action) => Expanded(
              child: Center(
                child: _ActionButton(data: action, responsive: responsive),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _ActionButtonData {
  const _ActionButtonData({
    required this.icon,
    required this.label,
    this.activeIcon,
    this.isActive = false,
    this.onTap,
    this.assetPath,
  });

  final IconData icon;
  final IconData? activeIcon;
  final bool isActive;
  final String label;
  final VoidCallback? onTap;
  final String? assetPath;
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.data, required this.responsive});

  final _ActionButtonData data;
  final ResponsiveSize responsive;

  @override
  Widget build(BuildContext context) {
    final buttonRadius = responsive.size(22);
    final buttonSize = responsive.size(38);
    final innerPadding = responsive.size(8);
    final iconSize = responsive.size(20);
    final verticalPadding = responsive.spacing(2);

    final showActiveIcon = data.isActive;
    final iconColor = showActiveIcon ? AppColors.error : AppColors.primary;

    return InkWell(
      borderRadius: BorderRadius.circular(buttonRadius),
      onTap: data.onTap == null ? null : () => data.onTap!.call(),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: verticalPadding),
        child: Container(
          width: buttonSize,
          height: buttonSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.greyLight.withAlpha((0.6 * 255).round()),
          ),
          child: data.assetPath != null
              ? Padding(
                  padding: EdgeInsets.all(innerPadding),
                  child: Image.asset(
                    data.assetPath!,
                    color: iconColor,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      showActiveIcon
                          ? (data.activeIcon ?? data.icon)
                          : data.icon,
                      color: iconColor,
                      size: iconSize,
                    ),
                  ),
                )
              : Icon(
                  showActiveIcon ? (data.activeIcon ?? data.icon) : data.icon,
                  color: iconColor,
                  size: iconSize,
                ),
        ),
      ),
    );
  }
}
