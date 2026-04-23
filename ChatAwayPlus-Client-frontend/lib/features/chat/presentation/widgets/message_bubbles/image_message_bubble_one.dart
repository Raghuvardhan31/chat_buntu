import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:chataway_plus/core/constants/api_url/api_urls.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:chataway_plus/core/sync/authenticated_image_cache_manager.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/features/chat/models/chat_message_model.dart';
import 'package:chataway_plus/features/chat/presentation/widgets/chat_ui/message_delivery_status_icon.dart';
import 'package:chataway_plus/features/chat/utils/chat_helper.dart';
import 'package:flutter/material.dart';

/// ============================================================================
/// IMAGE MESSAGE BUBBLE - WhatsApp Style
/// ============================================================================
/// Displays image messages with:
/// - Optimistic UI (local image shown immediately while uploading)
/// - Smooth transition from local to server image (no white flicker)
/// - WhatsApp-style sizing and aspect ratio handling
/// - Timestamp and delivery status overlay
/// - Auto-resolve dimensions from network image if not provided by backend
/// ============================================================================
class ImageMessageBubbleOne extends StatelessWidget {
  final ChatMessageModel message;
  final bool isSender;
  final VoidCallback? onTap;
  final VoidCallback? onRetry;
  final double? uploadProgress; // 0.0 to 1.0

  const ImageMessageBubbleOne({
    super.key,
    required this.message,
    this.isSender = false,
    this.onTap,
    this.onRetry,
    this.uploadProgress,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayoutBuilder(
      builder: (context, constraints, breakpoint) {
        final responsive = ResponsiveSize(
          context: context,
          constraints: constraints,
          breakpoint: breakpoint,
        );

        // ====================================================================
        // SECTION 1: BUBBLE SIZING (WhatsApp-style)
        // ====================================================================
        final bubbleSize = _calculateBubbleSize(
          message: message,
          context: context,
          responsive: responsive,
          constraints: constraints,
        );

        // ====================================================================
        // SECTION 2: IMAGE PATHS (Local vs Remote)
        // ====================================================================
        final imagePaths = _resolveImagePaths(message);
        if (!imagePaths.hasAny) {
          return _buildErrorBubble(responsive, 'No image URL');
        }

        // ====================================================================
        // SECTION 3: BUILD BUBBLE UI
        // ====================================================================
        return _buildImageBubble(
          context: context,
          responsive: responsive,
          bubbleSize: bubbleSize,
          imagePaths: imagePaths,
        );
      },
    );
  }

  // ==========================================================================
  // SECTION 1: BUBBLE SIZE CALCULATION
  // ==========================================================================
  /// WhatsApp-style bubble sizing:
  /// - Size determined ONLY from message dimensions (no async resolution)
  /// - Container size is fixed once — never changes after first render
  /// - Max width ~68% of screen for consistent chat flow
  /// - Aspect ratio preserved (no stretching/cropping)
  /// - Default 4:3 placeholder when dimensions not known
  static _BubbleSize _calculateBubbleSize({
    required ChatMessageModel message,
    required BuildContext context,
    required ResponsiveSize responsive,
    required BoxConstraints constraints,
  }) {
    final mediaQuerySize = MediaQuery.of(context).size;
    final screenWidth = mediaQuerySize.width;
    final screenHeight = mediaQuerySize.height;

    // WhatsApp-style constraints — use screenWidth directly so both
    // sender and receiver get identical bubble sizes.
    const maxWidthFactor = 0.60; // ~60% of screen width
    const maxHeightFactor =
        0.50; // ~50% of screen height (prevents full-screen images)

    // Minimum bubble dimensions
    final minBubbleWidth = responsive.size(150);
    final minBubbleHeight = responsive.size(120);

    // Use ONLY message dimensions — no async resolution
    final effectiveWidth = message.imageWidth;
    final effectiveHeight = message.imageHeight;

    // Calculate max allowed dimensions from screen size (not constraints)
    final maxBubbleWidth = screenWidth * maxWidthFactor;
    final maxBubbleHeight = screenHeight * maxHeightFactor;

    // If dimensions not available, use fixed width with 4:3 aspect ratio
    // so UI stays stable across devices.
    if (effectiveWidth == null ||
        effectiveHeight == null ||
        effectiveWidth <= 0 ||
        effectiveHeight <= 0) {
      const defaultAspectRatio = 4.0 / 3.0; // moderate default placeholder
      final bubbleWidth = maxBubbleWidth;
      final bubbleHeight = (bubbleWidth / defaultAspectRatio)
          .clamp(minBubbleHeight, maxBubbleHeight)
          .toDouble();
      return _BubbleSize(width: bubbleWidth, height: bubbleHeight);
    }

    // Calculate aspect ratio from dimensions
    final double aspectRatio = effectiveWidth / effectiveHeight;

    // Deterministic sizing: keep width stable across devices, clamp height.
    // For very tall/wide media this may not preserve aspect ratio perfectly,
    // but we rely on BoxFit.cover cropping (WhatsApp-like) to avoid tiny bubbles.
    final bubbleWidth = maxBubbleWidth.clamp(minBubbleWidth, maxBubbleWidth);
    final rawHeight = bubbleWidth / aspectRatio;
    final bubbleHeight = rawHeight
        .clamp(minBubbleHeight, maxBubbleHeight)
        .toDouble();

    return _BubbleSize(width: bubbleWidth.toDouble(), height: bubbleHeight);
  }

  // ==========================================================================
  // SECTION 2: IMAGE PATH RESOLUTION
  // ==========================================================================
  /// Resolves local and remote image paths
  static _ImagePaths _resolveImagePaths(ChatMessageModel message) {
    // Local path (for optimistic UI during upload)
    final String? localPath =
        (message.localImagePath != null && message.localImagePath!.isNotEmpty)
        ? message.localImagePath
        : null;

    // Remote path (server URL after upload)
    final String? remotePath =
        (message.imageUrl != null && message.imageUrl!.isNotEmpty)
        ? message.imageUrl
        : null;

    // Build full remote URL if needed
    String? fullRemoteUrl;
    if (remotePath != null) {
      // Check if it's already a full URL
      if (remotePath.startsWith('http://') ||
          remotePath.startsWith('https://')) {
        fullRemoteUrl = remotePath;
      } else if (remotePath.startsWith('/api/')) {
        // API path - prepend base URL
        fullRemoteUrl = '${ApiUrls.mediaBaseUrl}$remotePath';
      } else {
        // S3 key or relative path - use the image stream endpoint
        fullRemoteUrl = '${ApiUrls.mediaBaseUrl}/api/images/stream/$remotePath';
      }
    }

    return _ImagePaths(localPath: localPath, fullRemoteUrl: fullRemoteUrl);
  }

  // ==========================================================================
  // SECTION 3: BUILD BUBBLE UI
  // ==========================================================================
  Widget _buildImageBubble({
    required BuildContext context,
    required ResponsiveSize responsive,
    required _BubbleSize bubbleSize,
    required _ImagePaths imagePaths,
  }) {
    final borderRadius = responsive.size(12);

    final effectiveUploadProgress = (uploadProgress ?? 0.01)
        .clamp(0.01, 1.0)
        .toDouble();
    final uploadPercent = (effectiveUploadProgress * 100).round().clamp(1, 100);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bubbleColor = isSender
        ? (isDark ? const Color(0xFF1E3A5F) : AppColors.senderBubble)
        : (isDark ? const Color(0xFF2D2D2D) : AppColors.receiverBubble);
    final bubblePadding = responsive.size(2);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(bubblePadding),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: SizedBox(
          width: bubbleSize.width,
          height: bubbleSize.height,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius - bubblePadding),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // ----- PLACEHOLDER BACKGROUND -----
                Container(color: Colors.grey.shade300),

                // ----- LOCAL IMAGE (Optimistic UI) -----
                if (imagePaths.hasLocal)
                  Image.file(
                    File(imagePaths.localPath!),
                    fit: BoxFit.cover,
                    width: bubbleSize.width,
                    height: bubbleSize.height,
                    errorBuilder: (_, __, ___) => _buildErrorBubble(
                      responsive,
                      'Failed to load',
                      width: bubbleSize.width,
                      height: bubbleSize.height,
                    ),
                  ),

                // ----- REMOTE IMAGE (Server) -----
                if (imagePaths.hasRemote)
                  CachedNetworkImage(
                    imageUrl: imagePaths.fullRemoteUrl!,
                    cacheManager: AuthenticatedImageCacheManager.instance,
                    fit: BoxFit.cover,
                    width: bubbleSize.width,
                    height: bubbleSize.height,
                    fadeInDuration: const Duration(milliseconds: 200),
                    fadeOutDuration: const Duration(milliseconds: 100),
                    imageBuilder: (context, imageProvider) {
                      return Image(
                        image: imageProvider,
                        fit: BoxFit.cover,
                        width: bubbleSize.width,
                        height: bubbleSize.height,
                      );
                    },
                    progressIndicatorBuilder: (_, __, downloadProgress) {
                      // If local image is visible underneath, don't cover it
                      // with an opaque background — just keep it transparent
                      if (imagePaths.hasLocal) {
                        return const SizedBox.shrink();
                      }
                      return _buildDownloadProgress(
                        responsive,
                        downloadProgress,
                      );
                    },
                    errorWidget: (_, url, error) {
                      if (imagePaths.hasLocal) return const SizedBox.shrink();
                      return _buildErrorBubble(
                        responsive,
                        'Failed to load',
                        width: bubbleSize.width,
                        height: bubbleSize.height,
                      );
                    },
                  ),

                // ----- UPLOAD PROGRESS OVERLAY -----
                if (imagePaths.hasLocal &&
                    !imagePaths.hasRemote &&
                    message.messageStatus == 'sending')
                  Container(
                    color: Colors.black.withValues(alpha: 0.3),
                    child: Center(
                      child: SizedBox(
                        width: responsive.size(60),
                        height: responsive.size(60),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: responsive.size(56),
                              height: responsive.size(56),
                              child: CircularProgressIndicator(
                                strokeWidth: responsive.size(3),
                                color: Colors.white,
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.25,
                                ),
                                value: effectiveUploadProgress,
                              ),
                            ),
                            Text(
                              '$uploadPercent%',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: responsive.size(12),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // ----- FAILED / RETRY OVERLAY -----
                if (message.messageStatus == 'failed')
                  GestureDetector(
                    onTap: onRetry,
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.5),
                      child: Center(
                        child: Container(
                          width: responsive.size(60),
                          height: responsive.size(60),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            shape: BoxShape.circle,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.refresh_rounded,
                                color: Colors.white,
                                size: responsive.size(28),
                              ),
                              SizedBox(height: responsive.spacing(2)),
                              Text(
                                'Retry',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: responsive.size(10),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                // ----- TIMESTAMP & STATUS OVERLAY -----
                _buildTimestampOverlay(responsive),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // DOWNLOAD PROGRESS (WhatsApp-style)
  // ==========================================================================
  Widget _buildDownloadProgress(
    ResponsiveSize responsive,
    DownloadProgress downloadProgress,
  ) {
    return Container(
      color: Colors.grey.shade200,
      child: Center(
        child: SizedBox(
          width: responsive.size(40),
          height: responsive.size(40),
          child: CircularProgressIndicator(
            strokeWidth: responsive.size(3),
            color: AppColors.primary,
            value: downloadProgress.progress,
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // SECTION 4: TIMESTAMP OVERLAY (WhatsApp Style)
  // ==========================================================================
  Widget _buildTimestampOverlay(ResponsiveSize responsive) {
    return Positioned(
      right: responsive.spacing(4),
      bottom: responsive.spacing(4),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: responsive.spacing(5),
          vertical: responsive.spacing(2),
        ),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.38),
          borderRadius: BorderRadius.circular(responsive.size(5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Time
            Text(
              ChatHelper.formatMessageTime(message.createdAt),
              style: TextStyle(
                color: Colors.white,
                fontSize: responsive.size(11),
                fontWeight: FontWeight.w400,
              ),
            ),
            // Delivery status (sender only)
            if (isSender) ...[
              SizedBox(width: responsive.spacing(3)),
              MessageDeliveryStatusIcon(
                status: message.messageStatus,
                color: message.messageStatus == 'read'
                    ? AppColors.primary
                    : Colors.white70,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // SECTION 5: ERROR STATE
  // ==========================================================================
  Widget _buildErrorBubble(
    ResponsiveSize responsive,
    String errorMessage, {
    double? width,
    double? height,
  }) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey.shade300,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.broken_image,
              size: responsive.size(48),
              color: Colors.grey,
            ),
            SizedBox(height: responsive.spacing(8)),
            Text(
              errorMessage,
              style: TextStyle(
                color: Colors.grey,
                fontSize: responsive.size(12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// HELPER CLASSES
// ============================================================================

/// Holds calculated bubble dimensions
class _BubbleSize {
  final double width;
  final double height;

  const _BubbleSize({required this.width, required this.height});
}

/// Holds resolved image paths
class _ImagePaths {
  final String? localPath;
  final String? fullRemoteUrl;

  const _ImagePaths({this.localPath, this.fullRemoteUrl});

  bool get hasLocal => localPath != null;
  bool get hasRemote => fullRemoteUrl != null;
  bool get hasAny => hasLocal || hasRemote;
}
