import 'package:flutter/material.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/core/themes/app_text_styles.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:chataway_plus/core/routes/navigation_service.dart';

class SpeedDialFabWidget extends StatefulWidget {
  final ResponsiveSize responsive;
  final double bottomPadding;
  final bool isOpen;
  final VoidCallback onToggle;

  const SpeedDialFabWidget({
    super.key,
    required this.responsive,
    required this.bottomPadding,
    required this.isOpen,
    required this.onToggle,
  });

  @override
  State<SpeedDialFabWidget> createState() => _SpeedDialFabWidgetState();
}

class _SpeedDialFabWidgetState extends State<SpeedDialFabWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 0.4).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fabSize = widget.responsive.size(54);

    return Positioned(
      right: widget.responsive.spacing(16),
      bottom: widget.responsive.spacing(16) + widget.bottomPadding,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: widget.responsive.size(8),
                  offset: Offset(0, widget.responsive.spacing(4)),
                ),
              ],
            ),
            child: CircleAvatar(
              radius: fabSize / 2,
              backgroundColor: AppColors.primary,
              child: IconButton(
                onPressed: widget.onToggle,
                icon: Icon(
                  widget.isOpen ? Icons.close : Icons.add_circle_outline,
                  color: widget.isOpen
                      ? AppColors.iconPrimary
                      : AppColors.colorWhite,
                  size: widget.responsive.size(32),
                ),
              ),
            ),
          ),
          // Blinking hint dot — top-right corner (only when closed)
          if (!widget.isOpen)
            Positioned(
              top: widget.responsive.size(-6),
              right: widget.responsive.size(-4),
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Opacity(opacity: _pulseAnimation.value, child: child);
                },
                child: Container(
                  width: widget.responsive.size(12),
                  height: widget.responsive.size(12),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF6D00),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class SpeedDialButtonsOverlay extends StatelessWidget {
  final ResponsiveSize responsive;
  final double bottomPadding;
  final VoidCallback onClose;

  const SpeedDialButtonsOverlay({
    super.key,
    required this.responsive,
    required this.bottomPadding,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _buildSpeedDialButton(
          context: context,
          responsive: responsive,
          bottom:
              responsive.spacing(16) + bottomPadding + responsive.spacing(70),
          label: 'Contacts Hub',
          icon: Icons.shortcut_outlined,
          onPressed: () {
            onClose();
            NavigationService.goToContactsHub();
          },
        ),
        _buildSpeedDialButton(
          context: context,
          responsive: responsive,
          bottom:
              responsive.spacing(16) + bottomPadding + responsive.spacing(130),
          label: 'Express Hub',
          icon: Icons.mic,
          onPressed: () {
            onClose();
            NavigationService.goToVoiceHub();
          },
        ),
        _buildSpeedDialButton(
          context: context,
          responsive: responsive,
          bottom:
              responsive.spacing(16) + bottomPadding + responsive.spacing(190),
          label: 'Likes Hub',
          icon: Icons.favorite_rounded,
          onPressed: () {
            onClose();
            NavigationService.goToLikesHub();
          },
        ),
      ],
    );
  }

  Widget _buildSpeedDialButton({
    required BuildContext context,
    required ResponsiveSize responsive,
    required double bottom,
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    final fabSize = responsive.size(52);

    return Positioned(
      right: responsive.spacing(16),
      bottom: bottom,
      child: GestureDetector(
        onTap: onPressed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: responsive.size(120),
              padding: EdgeInsets.symmetric(
                horizontal: responsive.spacing(12),
                vertical: responsive.spacing(8),
              ),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha((0.8 * 255).round()),
                borderRadius: BorderRadius.circular(responsive.size(25)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: responsive.size(12),
                    offset: Offset(0, responsive.spacing(2)),
                  ),
                ],
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: AppTextSizes.small(context).copyWith(
                  color: AppColors.colorWhite,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            SizedBox(width: responsive.spacing(8)),
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: responsive.size(8),
                    offset: Offset(0, responsive.spacing(4)),
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: fabSize / 2,
                backgroundColor: AppColors.colorWhite,
                child: Icon(
                  icon,
                  color: AppColors.primary,
                  size: responsive.size(22),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
