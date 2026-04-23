import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/core/sync/authenticated_image_cache_manager.dart';
import 'package:chataway_plus/core/constants/api_url/api_urls.dart';

/// Reusable avatar widget for call screens
/// Shows profile picture or initials with gradient background
class CallAvatar extends StatelessWidget {
  final String name;
  final String? profilePicUrl;
  final double size;
  final bool showRipple;

  const CallAvatar({
    super.key,
    required this.name,
    this.profilePicUrl,
    this.size = 100,
    this.showRipple = false,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayoutBuilder(
      builder: (context, constraints, breakpoint) {
        final responsive = ResponsiveSize(
          context: context,
          constraints: constraints,
          breakpoint: breakpoint,
        );

        final avatarSize = responsive.size(size);
        final initials = _getInitials(name);

        // Build full URL for profile picture
        String? fullProfilePicUrl;
        if (profilePicUrl != null && profilePicUrl!.isNotEmpty) {
          fullProfilePicUrl = profilePicUrl!.startsWith('http')
              ? profilePicUrl
              : '${ApiUrls.mediaBaseUrl}$profilePicUrl';
        }

        Widget avatar;

        // Use CachedNetworkImage with authentication for profile pictures
        if (fullProfilePicUrl != null) {
          avatar = Container(
            width: avatarSize,
            height: avatarSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: responsive.size(20),
                  spreadRadius: responsive.size(2),
                ),
              ],
            ),
            child: ClipOval(
              child: CachedNetworkImage(
                imageUrl: fullProfilePicUrl,
                cacheManager: AuthenticatedImageCacheManager.instance,
                width: avatarSize,
                height: avatarSize,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primaryLight,
                        AppColors.primary,
                        AppColors.primaryDark,
                      ],
                    ),
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: responsive.size(size * 0.35),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primaryLight,
                        AppColors.primary,
                        AppColors.primaryDark,
                      ],
                    ),
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: responsive.size(size * 0.35),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        } else {
          // No profile picture - show gradient with initials
          avatar = Container(
            width: avatarSize,
            height: avatarSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primaryLight,
                  AppColors.primary,
                  AppColors.primaryDark,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: responsive.size(20),
                  spreadRadius: responsive.size(2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                initials,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: responsive.size(size * 0.35),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          );
        }

        if (showRipple) {
          return _RippleEffect(size: avatarSize, child: avatar);
        }

        return avatar;
      },
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0].isNotEmpty ? parts[0][0].toUpperCase() : '?';
  }
}

/// Animated ripple effect around the avatar during ringing
class _RippleEffect extends StatefulWidget {
  final double size;
  final Widget child;

  const _RippleEffect({required this.size, required this.child});

  @override
  State<_RippleEffect> createState() => _RippleEffectState();
}

class _RippleEffectState extends State<_RippleEffect>
    with TickerProviderStateMixin {
  late final AnimationController _controller1;
  late final AnimationController _controller2;
  late final AnimationController _controller3;

  @override
  void initState() {
    super.initState();
    _controller1 = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _controller2 = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _controller3 = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // Stagger the ripples
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _controller2.repeat();
    });
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) _controller3.repeat();
    });
  }

  @override
  void dispose() {
    _controller1.dispose();
    _controller2.dispose();
    _controller3.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size * 1.8,
      height: widget.size * 1.8,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _buildRipple(_controller1),
          _buildRipple(_controller2),
          _buildRipple(_controller3),
          widget.child,
        ],
      ),
    );
  }

  Widget _buildRipple(AnimationController controller) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final scale = 1.0 + controller.value * 0.6;
        final opacity = (1.0 - controller.value) * 0.3;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primary.withValues(alpha: opacity),
                width: 2,
              ),
            ),
          ),
        );
      },
    );
  }
}
