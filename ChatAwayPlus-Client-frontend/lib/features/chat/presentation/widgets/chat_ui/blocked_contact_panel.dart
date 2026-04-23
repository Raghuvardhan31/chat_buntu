// lib/features/chat/presentation/pages/individual_chat/widgets/blocked_contact_panel.dart

import 'package:flutter/material.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';

/// Panel displayed when user has blocked the contact
/// Shows message and options to Exit or Unblock
class BlockedContactPanel extends StatelessWidget {
  const BlockedContactPanel({
    super.key,
    required this.onExit,
    required this.onUnblock,
    this.isUnblocking = false,
  });

  final VoidCallback onExit;
  final VoidCallback onUnblock;
  final bool isUnblocking;

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
        final viewInsets = MediaQuery.of(context).viewInsets.bottom;

        return AnimatedPadding(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(
            left: responsive.spacing(12),
            right: responsive.spacing(12),
            top: responsive.spacing(8),
            bottom: viewInsets > 0
                ? viewInsets + responsive.spacing(8)
                : responsive.spacing(12),
          ),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: responsive.spacing(16),
              vertical: responsive.spacing(12),
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(responsive.size(16)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: responsive.size(12),
                  offset: Offset(0, responsive.spacing(2)),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You blocked this contact',
                  style: TextStyle(
                    fontSize: responsive.size(15),
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppColors.colorBlack,
                  ),
                ),
                SizedBox(height: responsive.spacing(4)),
                Text(
                  'Please unblock this contact to have a chat.',
                  style: TextStyle(
                    fontSize: responsive.size(13),
                    color: isDark ? Colors.white70 : AppColors.colorGrey,
                  ),
                ),
                SizedBox(height: responsive.spacing(12)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: onExit,
                      child: Text(
                        'Exit',
                        style: TextStyle(
                          fontSize: responsive.size(13),
                          color: AppColors.colorGrey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    SizedBox(width: responsive.spacing(8)),
                    TextButton(
                      onPressed: isUnblocking ? null : onUnblock,
                      child: Text(
                        isUnblocking ? 'Unblocking...' : 'Unblock',
                        style: TextStyle(
                          fontSize: responsive.size(13),
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
