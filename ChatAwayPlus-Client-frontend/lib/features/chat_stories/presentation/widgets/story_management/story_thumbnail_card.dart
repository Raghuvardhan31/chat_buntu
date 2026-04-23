import 'dart:io';

import 'package:flutter/material.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:chataway_plus/core/themes/app_text_styles.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';

/// Story Thumbnail Card - Shows individual story preview with timestamp and delete option
/// Used in MyStoriesListPage to display user's stories in a grid format
class StoryThumbnailCard extends StatelessWidget {
  const StoryThumbnailCard({
    super.key,
    required this.storyImage,
    required this.createdTime,
    required this.storyIndex,
    required this.totalStories,
    required this.onTap,
    required this.onDelete,
  });

  final File storyImage;
  final DateTime createdTime;
  final int storyIndex;
  final int totalStories;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayoutBuilder(
      builder: (context, constraints, breakpoint) {
        final responsive = ResponsiveSize(
          context: context,
          constraints: constraints,
          breakpoint: breakpoint,
        );

        return GestureDetector(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(responsive.size(12)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: responsive.size(8),
                  offset: Offset(0, responsive.size(2)),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(responsive.size(12)),
              child: Stack(
                children: [
                  // Story Image Background
                  Positioned.fill(
                    child: Image.file(
                      storyImage,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: AppColors.greyLight,
                          child: Icon(
                            Icons.broken_image,
                            size: responsive.size(40),
                            color: AppColors.greyMedium,
                          ),
                        );
                      },
                    ),
                  ),

                  // Gradient Overlay for better text readability
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.6),
                          ],
                          stops: const [0.6, 1.0],
                        ),
                      ),
                    ),
                  ),

                  // Story Index Badge (Top Left)
                  Positioned(
                    top: responsive.spacing(8),
                    left: responsive.spacing(8),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: responsive.spacing(8),
                        vertical: responsive.spacing(4),
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(
                          responsive.size(12),
                        ),
                      ),
                      child: Text(
                        '$storyIndex of $totalStories',
                        style: AppTextSizes.small(context).copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  // Delete Button (Top Right)
                  Positioned(
                    top: responsive.spacing(8),
                    right: responsive.spacing(8),
                    child: GestureDetector(
                      onTap: onDelete,
                      child: Container(
                        padding: EdgeInsets.all(responsive.spacing(6)),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.8),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.delete_outline,
                          size: responsive.size(18),
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                  // Time Stamp (Bottom)
                  Positioned(
                    bottom: responsive.spacing(8),
                    left: responsive.spacing(8),
                    right: responsive.spacing(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTimeAgo(createdTime),
                          style: AppTextSizes.small(context).copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: responsive.spacing(2)),
                        Text(
                          _formatDateTime(createdTime),
                          style: AppTextSizes.small(context).copyWith(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: responsive.size(10),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Tap Indicator (Center)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(
                          responsive.size(12),
                        ),
                      ),
                      child: Center(
                        child: Container(
                          padding: EdgeInsets.all(responsive.spacing(8)),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.play_arrow,
                            size: responsive.size(24),
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatTimeAgo(DateTime createdTime) {
    final now = DateTime.now();
    final difference = now.difference(createdTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${(difference.inDays / 7).floor()}w ago';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final amPm = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);

    return '$displayHour:$minute $amPm';
  }
}
