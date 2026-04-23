import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:chataway_plus/core/constants/api_url/api_urls.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:chataway_plus/core/sync/authenticated_image_cache_manager.dart';
import 'package:chataway_plus/core/themes/app_text_styles.dart';

class StoryViewerHeader extends StatelessWidget {
  const StoryViewerHeader({
    super.key,
    required this.responsive,
    this.avatarImageUrl,
    required this.title,
    required this.subtitle,
    required this.onClose,
    this.trailingActions = const <Widget>[],
  });

  final ResponsiveSize responsive;
  final String? avatarImageUrl;
  final String title;
  final String subtitle;
  final VoidCallback onClose;
  final List<Widget> trailingActions;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipOval(
          child: avatarImageUrl != null && avatarImageUrl!.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: _getImageUrl(avatarImageUrl!),
                  width: responsive.size(36),
                  height: responsive.size(36),
                  fit: BoxFit.cover,
                  cacheManager: AuthenticatedImageCacheManager.instance,
                  placeholder: (_, __) => Container(
                    width: responsive.size(36),
                    height: responsive.size(36),
                    color: Colors.white24,
                    child: Icon(
                      Icons.person,
                      color: Colors.white70,
                      size: responsive.size(18),
                    ),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    width: responsive.size(36),
                    height: responsive.size(36),
                    color: Colors.white24,
                    child: Icon(
                      Icons.person,
                      color: Colors.white70,
                      size: responsive.size(18),
                    ),
                  ),
                )
              : Container(
                  width: responsive.size(36),
                  height: responsive.size(36),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white24,
                  ),
                  child: Icon(
                    Icons.person,
                    color: Colors.white70,
                    size: responsive.size(18),
                  ),
                ),
        ),
        SizedBox(width: responsive.spacing(10)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextSizes.regular(context).copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: responsive.size(15),
                ),
              ),
              if (subtitle.trim().isNotEmpty)
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextSizes.small(context).copyWith(
                    color: Colors.white70,
                    fontSize: responsive.size(12),
                  ),
                ),
            ],
          ),
        ),
        ...trailingActions,
        IconButton(
          onPressed: onClose,
          icon: Icon(
            Icons.close,
            color: Colors.white,
            size: responsive.size(22),
          ),
        ),
      ],
    );
  }

  /// Get full image URL
  String _getImageUrl(String url) {
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
}
