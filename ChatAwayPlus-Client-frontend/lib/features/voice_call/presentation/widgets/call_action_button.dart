import 'package:flutter/material.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';

/// Circular action button used in call screens (mute, speaker, end call, etc.)
class CallActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color backgroundColor;
  final Color iconColor;
  final VoidCallback onTap;
  final bool isActive;
  final double size;

  const CallActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.backgroundColor = const Color(0xFF2A2A3E),
    this.iconColor = Colors.white,
    this.isActive = false,
    this.size = 60,
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

        final buttonSize = responsive.size(size);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: buttonSize,
                height: buttonSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive
                      ? Colors.white.withValues(alpha: 0.25)
                      : backgroundColor,
                  border: isActive
                      ? Border.all(
                          color: Colors.white.withValues(alpha: 0.4),
                          width: 1.5,
                        )
                      : null,
                ),
                child: Icon(
                  icon,
                  color: isActive ? Colors.white : iconColor,
                  size: responsive.size(size * 0.43),
                ),
              ),
            ),
            SizedBox(height: responsive.spacing(8)),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: responsive.size(11),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Special end call button (red, larger)
class EndCallButton extends StatelessWidget {
  final VoidCallback onTap;
  final double size;

  const EndCallButton({
    super.key,
    required this.onTap,
    this.size = 70,
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

        final buttonSize = responsive.size(size);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: onTap,
              child: Container(
                width: buttonSize,
                height: buttonSize,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFEF4444),
                      Color(0xFFDC2626),
                    ],
                  ),
                ),
                child: Icon(
                  Icons.call_end_rounded,
                  color: Colors.white,
                  size: responsive.size(size * 0.43),
                ),
              ),
            ),
            SizedBox(height: responsive.spacing(8)),
            Text(
              'End',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: responsive.size(11),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Accept call button (green, with phone icon)
class AcceptCallButton extends StatelessWidget {
  final VoidCallback onTap;
  final double size;

  const AcceptCallButton({
    super.key,
    required this.onTap,
    this.size = 70,
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

        final buttonSize = responsive.size(size);

        return GestureDetector(
          onTap: onTap,
          child: Container(
            width: buttonSize,
            height: buttonSize,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF22C55E),
                  Color(0xFF16A34A),
                ],
              ),
            ),
            child: Icon(
              Icons.call_rounded,
              color: Colors.white,
              size: responsive.size(size * 0.43),
            ),
          ),
        );
      },
    );
  }
}

/// Reject call button (red, with end call icon)
class RejectCallButton extends StatelessWidget {
  final VoidCallback onTap;
  final double size;

  const RejectCallButton({
    super.key,
    required this.onTap,
    this.size = 70,
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

        final buttonSize = responsive.size(size);

        return GestureDetector(
          onTap: onTap,
          child: Container(
            width: buttonSize,
            height: buttonSize,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFEF4444),
                  Color(0xFFDC2626),
                ],
              ),
            ),
            child: Icon(
              Icons.call_end_rounded,
              color: Colors.white,
              size: responsive.size(size * 0.43),
            ),
          ),
        );
      },
    );
  }
}
