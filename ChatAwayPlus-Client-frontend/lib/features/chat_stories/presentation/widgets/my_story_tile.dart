import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:chataway_plus/core/themes/app_text_styles.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/core/constants/api_url/api_urls.dart';
import 'package:chataway_plus/core/sync/authenticated_image_cache_manager.dart';
import 'package:chataway_plus/features/chat_stories/presentation/painters/story_ring_painter.dart';

class MyStoryTile extends StatelessWidget {
  const MyStoryTile({
    super.key,
    required this.responsive,
    required this.isDark,
    required this.hasStory,
    required this.storyImages,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.storyCount = 0,
    this.totalViews = 0,
    this.networkStoryUrls = const [],
  });

  final ResponsiveSize responsive;
  final bool isDark;
  final bool hasStory;
  final List<File> storyImages;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final int storyCount;
  final int totalViews;
  final List<String> networkStoryUrls;

  /// Get the full URL for the story image
  String? _getStoryImageUrl() {
    // Prefer network URLs from socket stories - use LAST (latest) story like WhatsApp
    if (networkStoryUrls.isNotEmpty) {
      final url = networkStoryUrls.last;

      // Return null for empty URLs (e.g., videos without thumbnails)
      if (url.trim().isEmpty) return null;

      final raw = url.trim();
      if (raw.startsWith('http://') || raw.startsWith('https://')) {
        return raw;
      }
      if (raw.startsWith('/')) {
        if (raw.startsWith('/api/') || raw.startsWith('/uploads/')) {
          return '${ApiUrls.mediaBaseUrl}$raw';
        }
        return '${ApiUrls.mediaBaseUrl}/api/images/stream/${raw.substring(1)}';
      }
      if (raw.startsWith('api/') || raw.startsWith('uploads/')) {
        return '${ApiUrls.mediaBaseUrl}/$raw';
      }
      return '${ApiUrls.mediaBaseUrl}/api/images/stream/$raw';
    }
    return null;
  }

  /// Build the avatar image widget
  Widget _buildAvatarImage() {
    final imageUrl = _getStoryImageUrl();

    if (imageUrl != null) {
      // Network image with authentication
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          cacheManager: AuthenticatedImageCacheManager.instance,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(
            color: AppColors.greyLight,
            child: const SizedBox.expand(),
          ),
          errorWidget: (_, url, error) {
            debugPrint('❌ Story tile image error: $error');
            return Container(
              color: AppColors.greyLight,
              child: Icon(
                Icons.image_not_supported_outlined,
                size: responsive.size(20),
                color: AppColors.greyMedium,
              ),
            );
          },
        ),
      );
    } else if (storyImages.isNotEmpty) {
      // Local file image - use LAST (latest) story like WhatsApp
      return ClipOval(
        child: Image.file(
          storyImages.last,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: AppColors.greyLight,
            child: Icon(
              Icons.broken_image_outlined,
              size: responsive.size(20),
              color: AppColors.greyMedium,
            ),
          ),
        ),
      );
    } else {
      // No image available
      return Container(color: AppColors.greyLight);
    }
  }

  @override
  Widget build(BuildContext context) {
    final actualStoryCount = networkStoryUrls.isNotEmpty
        ? networkStoryUrls.length
        : storyImages.length;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.only(bottom: responsive.spacing(8)),
        child: Row(
          children: [
            SizedBox(
              width: responsive.size(56),
              height: responsive.size(56),
              child: hasStory
                  ? CustomPaint(
                      painter: StoryRingPainter(
                        totalSegments: actualStoryCount > 0
                            ? actualStoryCount
                            : 1,
                        watchedSegments: <int>{},
                        unwatchedGradient: const LinearGradient(
                          colors: [
                            AppColors.inactiveStatus,
                            AppColors.inactiveStatus,
                          ],
                        ),
                        watchedColor: AppColors.inactiveStatus,
                        strokeWidth: responsive.size(2),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(3),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? Colors.black : Colors.white,
                              width: 2,
                            ),
                          ),
                          child: _buildAvatarImage(),
                        ),
                      ),
                    )
                  : Container(
                      width: responsive.size(56),
                      height: responsive.size(56),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.inactiveStatus,
                          width: 2,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: responsive.size(24),
                        backgroundColor: AppColors.greyLight,
                        child: Icon(
                          Icons.add_a_photo_outlined,
                          size: responsive.size(20),
                          color: AppColors.greyMedium,
                        ),
                      ),
                    ),
            ),
            SizedBox(width: responsive.spacing(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextSizes.regular(context).copyWith(
                      color: isDark ? Colors.white : Colors.black,
                      fontWeight: FontWeight.w600,
                      fontSize: responsive.size(16),
                    ),
                  ),
                  SizedBox(height: responsive.spacing(2)),
                  Text(
                    subtitle,
                    style: AppTextSizes.small(context).copyWith(
                      color: isDark ? Colors.white54 : Colors.black54,
                      fontSize: responsive.size(13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
