// lib/features/contacts/presentation/widgets/empty_error_loading.dart
import 'package:chataway_plus/core/themes/app_text_styles.dart';
import 'package:flutter/material.dart';

import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';

class EmptyStateWidget extends StatelessWidget {
  final bool isAppUser;
  final VoidCallback onRefresh;
  final ResponsiveSize? responsive;

  const EmptyStateWidget({
    super.key,
    required this.isAppUser,
    required this.onRefresh,
    this.responsive,
  });

  @override
  Widget build(BuildContext context) {
    final r = responsive;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isAppUser ? Icons.people_outline : Icons.person_add_alt_outlined,
            size: r?.size(64) ?? 64,
            color: AppColors.iconSecondary,
          ),
          SizedBox(height: r?.spacing(16) ?? 16),
          Text(
            isAppUser ? 'No app users found' : 'No contacts to invite',
            style: AppTextSizes.large(
              context,
            ).copyWith(color: AppColors.colorBlack),
          ),
          SizedBox(height: r?.spacing(8) ?? 8),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: r?.spacing(32) ?? 32),
            child: Text(
              isAppUser
                  ? 'Contacts using ChatAway+ will appear here'
                  : 'Invite your contacts to join ChatAway+',
              textAlign: TextAlign.center,
              style: AppTextSizes.regular(
                context,
              ).copyWith(color: AppColors.colorGrey),
            ),
          ),
          SizedBox(height: r?.spacing(20) ?? 20),
          ElevatedButton(
            onPressed: onRefresh,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: Text(
              'Refresh',
              style: AppTextSizes.regular(
                context,
              ).copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class ErrorStateWidget extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final ResponsiveSize? responsive;

  const ErrorStateWidget({
    super.key,
    required this.message,
    required this.onRetry,
    this.responsive,
  });

  @override
  Widget build(BuildContext context) {
    final r = responsive;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: r?.size(64) ?? 64,
            color: AppColors.error,
          ),
          SizedBox(height: r?.spacing(16) ?? 16),
          Text(
            'Error loading contacts',
            style: AppTextSizes.large(context).copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.iconPrimary,
            ),
          ),
          SizedBox(height: r?.spacing(8) ?? 8),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: r?.spacing(32) ?? 32),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextSizes.regular(
                context,
              ).copyWith(color: AppColors.colorGrey),
            ),
          ),
          SizedBox(height: r?.spacing(24) ?? 24),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: Text(
              'Retry',
              style: AppTextSizes.regular(
                context,
              ).copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class LoadingStateWidget extends StatelessWidget {
  final bool isManualRefresh;
  final ResponsiveSize? responsive;

  const LoadingStateWidget({
    super.key,
    this.isManualRefresh = false,
    this.responsive,
  });

  @override
  Widget build(BuildContext context) {
    final r = responsive;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.primary),
          SizedBox(height: r?.spacing(16) ?? 16),
          Text(
            'Loading contacts...',
            style: AppTextSizes.regular(
              context,
            ).copyWith(color: AppColors.colorBlack),
          ),
          if (isManualRefresh) ...[
            SizedBox(height: r?.spacing(12) ?? 12),
            Text(
              'Please don\'t press until it finishes (few seconds)',
              style: AppTextSizes.small(
                context,
              ).copyWith(color: AppColors.colorGrey),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
