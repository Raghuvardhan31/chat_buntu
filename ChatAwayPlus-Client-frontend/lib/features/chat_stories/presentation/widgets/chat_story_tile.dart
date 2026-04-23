import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:chataway_plus/core/constants/api_url/api_urls.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:chataway_plus/core/sync/authenticated_image_cache_manager.dart';
import 'package:chataway_plus/core/themes/app_text_styles.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/features/chat_stories/data/models/chat_story_models.dart';
import 'package:chataway_plus/features/chat_stories/presentation/painters/story_ring_painter.dart';

class ChatStoryTile extends StatelessWidget {
  const ChatStoryTile({
    super.key,
    required this.story,
    required this.watchedSegments,
    required this.responsive,
    required this.isDark,
    required this.onTap,
  });

  final ChatStoryModel story;
  final Set<int> watchedSegments;
  final ResponsiveSize responsive;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.only(bottom: responsive.spacing(16)),
        child: Row(
          children: [
            SizedBox(
              width: responsive.size(56),
              height: responsive.size(56),
              child: CustomPaint(
                painter: StoryRingPainter(
                  totalSegments: story.slides.isEmpty ? 1 : story.slides.length,
                  watchedSegments: watchedSegments,
                  unwatchedGradient: AppColors.storiesCottonCandySky,
                  watchedColor: AppColors.inactiveStatus,
                  strokeWidth: responsive.size(2),
                ),
                child: Padding(
                  padding: EdgeInsets.all(story.hasStory ? 3 : 0),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: story.hasStory
                          ? Border.all(
                              color: isDark ? Colors.black : Colors.white,
                              width: 2,
                            )
                          : null,
                    ),
                    child: ClipOval(
                      // Use LAST (latest) story like WhatsApp
                      child: story.slides.isNotEmpty
                          ? _buildStoryImage(
                              story.slides.last.imageUrl,
                              responsive.size(48),
                            )
                          : Container(
                              width: responsive.size(48),
                              height: responsive.size(48),
                              color: AppColors.greyLight,
                              child: Icon(
                                Icons.person,
                                size: responsive.size(24),
                                color: AppColors.greyMedium,
                              ),
                            ),
                    ),
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
                    story.name,
                    style: AppTextSizes.regular(context).copyWith(
                      color: isDark ? Colors.white : Colors.black,
                      fontWeight: FontWeight.w600,
                      fontSize: responsive.size(16),
                    ),
                  ),
                  if (story.timeAgo.isNotEmpty)
                    SizedBox(height: responsive.spacing(2)),
                  if (story.timeAgo.isNotEmpty)
                    Text(
                      story.timeAgo,
                      style: AppTextSizes.small(context).copyWith(
                        color: isDark ? Colors.white54 : Colors.black54,
                        fontSize: responsive.size(14),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build story image with authentication
  Widget _buildStoryImage(String imageUrl, double size) {
    // Check if imageUrl is empty (e.g., video without thumbnail)
    if (imageUrl.trim().isEmpty) {
      return Container(
        width: size,
        height: size,
        color: AppColors.greyLight,
        child: Icon(
          Icons.videocam_rounded,
          size: size * 0.5,
          color: AppColors.greyMedium,
        ),
      );
    }

    final fullUrl = _getStoryImageUrl(imageUrl);

    return CachedNetworkImage(
      imageUrl: fullUrl,
      width: size,
      height: size,
      fit: BoxFit.cover,
      cacheManager: AuthenticatedImageCacheManager.instance,
      placeholder: (context, url) => Container(
        width: size,
        height: size,
        color: AppColors.greyLight,
        child: Center(
          child: SizedBox(
            width: size * 0.4,
            height: size * 0.4,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.greyMedium),
            ),
          ),
        ),
      ),
      errorWidget: (context, url, error) {
        debugPrint('❌ ChatStoryTile image error: $error for URL: $url');
        return Container(
          width: size,
          height: size,
          color: AppColors.greyLight,
          child: Icon(
            Icons.person,
            size: size * 0.5,
            color: AppColors.greyMedium,
          ),
        );
      },
    );
  }

  /// Get full story image URL
  String _getStoryImageUrl(String imageUrl) {
    final raw = imageUrl.trim();
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
}
