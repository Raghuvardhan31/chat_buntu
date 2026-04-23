// lib/features/chat/presentation/pages/individual_chat/widgets/jump_to_latest_button.dart

import 'package:flutter/material.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';

/// Floating button to jump to latest messages in chat
class JumpToLatestButton extends StatelessWidget {
  const JumpToLatestButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ResponsiveLayoutBuilder(
      builder: (context, constraints, breakpoint) {
        final responsive = ResponsiveSize(
          context: context,
          constraints: constraints,
          breakpoint: breakpoint,
        );

        return Material(
          elevation: responsive.size(6),
          borderRadius: BorderRadius.circular(responsive.size(24)),
          color: isDark ? AppColors.iconPrimary : Colors.white,
          child: InkWell(
            borderRadius: BorderRadius.circular(responsive.size(24)),
            onTap: onTap,
            child: Container(
              width: responsive.size(42),
              height: responsive.size(42),
              decoration: BoxDecoration(shape: BoxShape.circle),
              child: Icon(
                Icons.keyboard_double_arrow_down_rounded,
                color: isDark ? Colors.white : AppColors.iconPrimary,
                size: responsive.size(22),
              ),
            ),
          ),
        );
      },
    );
  }
}
