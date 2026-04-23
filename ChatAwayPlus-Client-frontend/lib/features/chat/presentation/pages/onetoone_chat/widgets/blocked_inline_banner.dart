import 'package:flutter/material.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';

/// Inline banner shown at the top of messages when contact is blocked
class BlockedInlineBanner extends StatelessWidget {
  const BlockedInlineBanner({super.key, required this.responsive});

  final ResponsiveSize responsive;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(
        top: responsive.spacing(6),
        bottom: responsive.spacing(4),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: responsive.spacing(12),
              vertical: responsive.spacing(4),
            ),
            decoration: BoxDecoration(
              color: isDark ? Colors.white12 : Colors.grey[200],
              borderRadius: BorderRadius.circular(responsive.size(12)),
            ),
            child: Text(
              'You blocked this contact',
              style: TextStyle(
                fontSize: responsive.size(12),
                color: isDark ? Colors.white70 : Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
