import 'package:flutter/material.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:chataway_plus/core/constants/feature_tips_info/app_introduction/data/feature_intro_model.dart';

/// Reusable widget: "ChatAway+" text with a blue verification tick
/// (like Instagram / Twitter verified badge).
/// Used in both the feature intro list and the feature detail page.
class VerifiedAppName extends StatelessWidget {
  const VerifiedAppName({
    super.key,
    required this.responsive,
    this.fontSize,
    this.tickSize,
    this.textColor,
    this.fontWeight,
  });

  final ResponsiveSize responsive;
  final double? fontSize;
  final double? tickSize;
  final Color? textColor;
  final FontWeight? fontWeight;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final resolvedFontSize = fontSize ?? responsive.size(15);
    final resolvedTickSize = tickSize ?? responsive.size(16);
    final resolvedTextColor =
        textColor ?? (isDark ? Colors.white : AppColors.colorBlack);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          FeatureIntroData.appName,
          style: TextStyle(
            color: resolvedTextColor,
            fontSize: resolvedFontSize,
            fontWeight: fontWeight ?? FontWeight.w600,
          ),
        ),
        SizedBox(width: responsive.spacing(4)),
        // Blue verification tick — stacked icons for Instagram/Twitter style
        Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.circle,
              color: Colors.white,
              size: resolvedTickSize * 0.65,
            ),
            Icon(
              Icons.verified,
              color: const Color(0xFF1DA1F2), // Twitter blue
              size: resolvedTickSize,
            ),
          ],
        ),
      ],
    );
  }
}
