import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/themes/colors/app_colors.dart';
import '../../../../core/sync/authenticated_image_cache_manager.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';

class CurrentUserChatPictureViewer extends StatelessWidget {
  const CurrentUserChatPictureViewer({
    super.key,
    this.localImagePath,
    this.chatPictureUrl,
    required this.onEdit,
  });

  final String? localImagePath;
  final String? chatPictureUrl;
  final VoidCallback onEdit;

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
              title: Text(
                'Yours ChatPicture',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextSizes.regular(
                  context,
                ).copyWith(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              centerTitle: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  color: Colors.white,
                  iconSize: responsive.size(22),
                  onPressed: onEdit,
                ),
              ],
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
    final hasLocal = localImagePath != null && localImagePath!.isNotEmpty;
    final hasNetwork =
        !hasLocal && chatPictureUrl != null && chatPictureUrl!.isNotEmpty;

    final fallback = Container(
      color: Colors.black,
      alignment: Alignment.center,
      child: Icon(
        Icons.person,
        size: responsive.size(72),
        color: AppColors.iconSecondary,
      ),
    );

    if (hasLocal) {
      return Image.file(
        File(localImagePath!),
        fit: BoxFit.fitWidth,
        errorBuilder: (_, __, ___) => fallback,
      );
    }

    if (hasNetwork) {
      return CachedNetworkImage(
        imageUrl: chatPictureUrl!,
        cacheManager: AuthenticatedImageCacheManager.instance,
        fit: BoxFit.fitWidth,
        placeholder: (context, url) => Container(
          color: Colors.black,
          alignment: Alignment.center,
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        errorWidget: (context, url, error) => fallback,
      );
    }

    return fallback;
  }
}
