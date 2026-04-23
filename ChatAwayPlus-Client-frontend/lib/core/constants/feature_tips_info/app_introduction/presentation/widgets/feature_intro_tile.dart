import 'package:flutter/material.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/core/themes/app_text_styles.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:chataway_plus/core/constants/feature_tips_info/app_introduction/data/feature_intro_model.dart';
import 'package:chataway_plus/core/constants/feature_tips_info/app_introduction/presentation/widgets/verified_app_name.dart';

/// A single feature introduction list tile.
/// Styled like a contact list item with:
/// - Circle avatar (feature icon with colored background)
/// - App name with blue verification tick
/// - Feature name below
/// - Delete button on right side
class FeatureIntroTile extends StatelessWidget {
  const FeatureIntroTile({
    super.key,
    required this.feature,
    required this.responsive,
    required this.onTap,
    required this.onDelete,
  });

  final FeatureIntroModel feature;
  final ResponsiveSize responsive;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(responsive.size(12)),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: responsive.spacing(16),
          vertical: responsive.spacing(10),
        ),
        child: Row(
          children: [
            // Circle avatar with feature icon
            Container(
              width: responsive.size(52),
              height: responsive.size(52),
              decoration: BoxDecoration(
                color: feature.iconBackgroundColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                feature.icon,
                color: Colors.white,
                size: responsive.size(26),
              ),
            ),
            SizedBox(width: responsive.spacing(12)),

            // Name + feature name
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // App name with blue tick
                  VerifiedAppName(
                    responsive: responsive,
                    fontSize: responsive.size(15),
                    tickSize: responsive.size(16),
                  ),
                  SizedBox(height: responsive.spacing(2)),
                  // Feature name
                  Text(
                    feature.featureName,
                    style: AppTextSizes.small(context).copyWith(
                      color: isDark ? Colors.white60 : AppColors.colorGrey,
                      fontSize: responsive.size(13),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Delete button
            IconButton(
              onPressed: onDelete,
              icon: Icon(
                Icons.delete_outline_rounded,
                color: isDark ? Colors.white54 : AppColors.colorGrey,
                size: responsive.size(22),
              ),
              tooltip: 'Dismiss',
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(
                minWidth: responsive.size(36),
                minHeight: responsive.size(36),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
