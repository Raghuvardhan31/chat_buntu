import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/themes/colors/app_colors.dart';
import 'package:chataway_plus/core/constants/api_url/api_urls.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:chataway_plus/core/sync/authenticated_image_cache_manager.dart';

/// Full-screen viewer for a chat/contact picture.
///
/// Designed for the scenario:
/// - User taps the photo in the app bar.
/// - Screen opens with top and bottom fully black.
/// - In the black app bar: back arrow and contact name.
/// - Between top and bottom, a white area showing the picture.
class ChatProfilePictureViewer extends StatelessWidget {
  const ChatProfilePictureViewer({
    super.key,
    required this.displayName,
    this.chatPictureUrl,
  });

  final String displayName;
  final String? chatPictureUrl;

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayoutBuilder(
      builder: (context, constraints, breakpoint) {
        final responsive = ResponsiveSize(
          context: context,
          constraints: constraints,
          breakpoint: breakpoint,
        );

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarColor: Colors.black,
            statusBarIconBrightness: Brightness.light,
            systemNavigationBarColor: Colors.black,
            systemNavigationBarIconBrightness: Brightness.light,
          ),
          child: Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.black,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                color: Colors.white,
                iconSize: responsive.size(24),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextSizes.large(
                      context,
                    ).copyWith(color: Colors.white),
                  ),
                  SizedBox(height: responsive.spacing(2)),
                  Text(
                    'ChatPicture',
                    style: AppTextSizes.small(
                      context,
                    ).copyWith(color: Colors.white70),
                  ),
                ],
              ),
              centerTitle: false,
            ),
            body: Container(
              color: Colors.black,
              alignment: Alignment.center,
              child: SizedBox(
                width: double.infinity,
                child: _buildImage(responsive),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildImage(ResponsiveSize responsive) {
    final url = chatPictureUrl;
    final hasUrl = url != null && url.isNotEmpty;

    final fallback = Container(
      color: Colors.black,
      alignment: Alignment.center,
      child: Icon(
        Icons.person,
        size: responsive.size(72),
        color: AppColors.iconSecondary,
      ),
    );

    if (!hasUrl) return fallback;

    // Handle local file URIs like file:///...
    if (url.startsWith('file://')) {
      try {
        final filePath = Uri.parse(url).toFilePath();
        return Image.file(
          File(filePath),
          fit: BoxFit.fitWidth,
          errorBuilder: (_, __, ___) => fallback,
        );
      } catch (_) {
        return fallback;
      }
    }

    // Handle server paths like /uploads/profile/...
    final fullUrl = url.startsWith('http')
        ? url
        : '${ApiUrls.mediaBaseUrl}$url';

    return CachedNetworkImage(
      imageUrl: fullUrl,
      cacheManager: AuthenticatedImageCacheManager.instance,
      fit: BoxFit.fitWidth,
      placeholder: (context, url) => Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: CircularProgressIndicator(
          color: AppColors.primary,
          strokeWidth: 2,
        ),
      ),
      errorWidget: (context, url, error) => fallback,
    );
  }
}
