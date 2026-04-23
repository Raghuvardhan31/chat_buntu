import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chataway_plus/core/constants/api_url/api_urls.dart';
import 'package:chataway_plus/core/sync/authenticated_image_cache_manager.dart';

import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:chataway_plus/core/themes/app_text_styles.dart';
import 'package:chataway_plus/features/chat_stories/presentation/widgets/story_video_player.dart';

class StorySlideRenderer extends StatelessWidget {
  const StorySlideRenderer({
    super.key,
    required this.responsive,
    this.networkImageUrl,
    this.localFile,
    this.caption,
    this.mediaType = 'image',
    this.thumbnailUrl,
    this.videoDuration,
    this.videoUrl,
    this.onVideoInitialized,
    this.onMediaReady,
  });

  final ResponsiveSize responsive;
  final String? networkImageUrl;
  final File? localFile;
  final String? caption;
  final String mediaType; // 'image' or 'video'
  final String? thumbnailUrl;
  final double? videoDuration;
  final String? videoUrl;

  /// Called when a video story is initialized with its actual duration
  final ValueChanged<Duration>? onVideoInitialized;

  /// Called when an image/local story slide is actually ready to be shown.
  /// Used by story viewer to start the progress bar only after media is ready.
  final VoidCallback? onMediaReady;

  @override
  Widget build(BuildContext context) {
    final cap = (caption ?? '').trim();

    // Video story — use StoryVideoPlayer
    final effectiveVideoUrl = videoUrl ?? networkImageUrl;
    if (mediaType == 'video' &&
        effectiveVideoUrl != null &&
        effectiveVideoUrl.isNotEmpty) {
      return Stack(
        children: [
          Positioned.fill(
            child: StoryVideoPlayer(
              videoUrl: effectiveVideoUrl,
              thumbnailUrl: thumbnailUrl,
              responsive: responsive,
              onVideoInitialized: onVideoInitialized,
            ),
          ),
          if (cap.isNotEmpty)
            Positioned(
              left: responsive.spacing(14),
              right: responsive.spacing(14),
              bottom: responsive.spacing(74),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: responsive.spacing(12),
                  vertical: responsive.spacing(10),
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.38),
                  borderRadius: BorderRadius.circular(responsive.size(12)),
                ),
                child: Text(
                  cap,
                  style: AppTextSizes.regular(context).copyWith(
                    color: Colors.white,
                    fontSize: responsive.size(14),
                    height: 1.2,
                  ),
                ),
              ),
            ),
        ],
      );
    }

    Widget foreground;
    Widget background;

    if (localFile != null) {
      if (onMediaReady != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          onMediaReady?.call();
        });
      }
      final base = Image.file(
        localFile!,
        fit: BoxFit.cover,
        errorBuilder: (context, _, __) {
          return Container(
            color: Colors.black,
            child: Center(
              child: Icon(
                Icons.broken_image_outlined,
                size: responsive.size(42),
                color: Colors.white70,
              ),
            ),
          );
        },
      );

      background = ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: base,
      );

      foreground = Image.file(
        localFile!,
        fit: BoxFit.contain,
        errorBuilder: (context, _, __) {
          return Container(
            color: Colors.black,
            child: Center(
              child: Icon(
                Icons.broken_image_outlined,
                size: responsive.size(42),
                color: Colors.white70,
              ),
            ),
          );
        },
      );
    } else if (networkImageUrl != null && networkImageUrl!.isNotEmpty) {
      final raw = networkImageUrl!.trim();
      String fullUrl;
      if (raw.startsWith('http://') || raw.startsWith('https://')) {
        fullUrl = raw;
      } else if (raw.startsWith('/')) {
        if (raw.startsWith('/api/') || raw.startsWith('/uploads/')) {
          fullUrl = '${ApiUrls.mediaBaseUrl}$raw';
        } else {
          fullUrl =
              '${ApiUrls.mediaBaseUrl}/api/images/stream/${raw.substring(1)}';
        }
      } else {
        if (raw.startsWith('api/') || raw.startsWith('uploads/')) {
          fullUrl = '${ApiUrls.mediaBaseUrl}/$raw';
        } else {
          fullUrl = '${ApiUrls.mediaBaseUrl}/api/images/stream/$raw';
        }
      }

      final base = CachedNetworkImage(
        imageUrl: fullUrl,
        cacheManager: AuthenticatedImageCacheManager.instance,
        fit: BoxFit.cover,
        progressIndicatorBuilder: (_, __, downloadProgress) => Container(
          color: Colors.black,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  strokeWidth: responsive.size(2),
                  color: Colors.white,
                  value: downloadProgress.progress,
                ),
                SizedBox(height: responsive.spacing(12)),
                Text(
                  'Loading story...',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: responsive.size(14),
                  ),
                ),
              ],
            ),
          ),
        ),
        errorWidget: (_, __, ___) {
          return Container(
            color: Colors.black,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cloud_off_outlined,
                    size: responsive.size(48),
                    color: Colors.white70,
                  ),
                  SizedBox(height: responsive.spacing(12)),
                  Text(
                    'Unable to load story',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: responsive.size(14),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: responsive.spacing(4)),
                  Text(
                    'Check your connection',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: responsive.size(12),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );

      background = ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: base,
      );

      foreground = CachedNetworkImage(
        imageUrl: fullUrl,
        cacheManager: AuthenticatedImageCacheManager.instance,
        fit: BoxFit.contain,
        imageBuilder: (context, imageProvider) {
          if (onMediaReady != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              onMediaReady?.call();
            });
          }
          return Image(image: imageProvider, fit: BoxFit.contain);
        },
        progressIndicatorBuilder: (_, __, downloadProgress) => Container(
          color: Colors.black,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  strokeWidth: responsive.size(2),
                  color: Colors.white,
                  value: downloadProgress.progress,
                ),
                SizedBox(height: responsive.spacing(12)),
                Text(
                  'Loading story...',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: responsive.size(14),
                  ),
                ),
              ],
            ),
          ),
        ),
        errorWidget: (_, __, ___) {
          return Container(
            color: Colors.black,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cloud_off_outlined,
                    size: responsive.size(48),
                    color: Colors.white70,
                  ),
                  SizedBox(height: responsive.spacing(12)),
                  Text(
                    'Unable to load story',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: responsive.size(14),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: responsive.spacing(4)),
                  Text(
                    'Check your connection',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: responsive.size(12),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } else {
      final fallback = Container(
        color: Colors.black,
        child: Center(
          child: Icon(
            Icons.image_not_supported_outlined,
            size: responsive.size(42),
            color: Colors.white70,
          ),
        ),
      );

      background = fallback;
      foreground = fallback;
    }

    return Stack(
      children: [
        Positioned.fill(child: background),
        Positioned.fill(
          child: Container(color: Colors.black.withValues(alpha: 0.35)),
        ),
        Positioned.fill(child: foreground),
        if (cap.isNotEmpty)
          Positioned(
            left: responsive.spacing(14),
            right: responsive.spacing(14),
            bottom: responsive.spacing(74),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: responsive.spacing(12),
                vertical: responsive.spacing(10),
              ),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.38),
                borderRadius: BorderRadius.circular(responsive.size(12)),
              ),
              child: Text(
                cap,
                style: AppTextSizes.regular(context).copyWith(
                  color: Colors.white,
                  fontSize: responsive.size(14),
                  height: 1.2,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
