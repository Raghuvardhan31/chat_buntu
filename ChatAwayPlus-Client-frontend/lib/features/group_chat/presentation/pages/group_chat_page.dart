import 'package:flutter/material.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/core/themes/app_text_styles.dart';

/// Placeholder page for Group Chat feature
/// This will be implemented by the service team
class GroupChatPage extends StatelessWidget {
  const GroupChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.groups_rounded,
                size: 80,
                color: AppColors.primary.withOpacity(0.5),
              ),
              const SizedBox(height: 24),
              Text(
                'Group Chat',
                style: AppTextSizes.heading(context).copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.iconPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Group chat feature will be implemented here',
                textAlign: TextAlign.center,
                style: AppTextSizes.natural(context).copyWith(
                  fontSize: 16,
                  color: isDark ? Colors.white70 : AppColors.colorGrey,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Service team will build:\n• Create groups\n• Group messaging\n• Group media sharing\n• Group admin controls',
                textAlign: TextAlign.center,
                style: AppTextSizes.small(context).copyWith(
                  fontSize: 14,
                  color: isDark ? Colors.white60 : AppColors.colorGrey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
