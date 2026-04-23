// lib/features/chat/presentation/widgets/message_bubbles/video_message_bubble.dart

import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:chataway_plus/core/constants/api_url/api_urls.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:chataway_plus/core/sync/authenticated_image_cache_manager.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/features/chat/data/media/media_cache_service.dart';
import 'package:chataway_plus/features/chat/models/chat_message_model.dart';
import 'package:chataway_plus/features/chat/presentation/widgets/chat_ui/message_delivery_status_icon.dart';
import 'package:chataway_plus/features/chat/utils/chat_helper.dart';
import 'package:flutter/material.dart';
import 'package:chataway_plus/features/chat/presentation/pages/media_viewer/chat_video_viewer_page.dart';

/// Widget to display video messages in chat
/// Supports WhatsApp-style upload progress with percentage and retry on failure
class VideoMessageBubble extends StatefulWidget {
  const VideoMessageBubble({
    super.key,
    required this.message,
    required this.isSender,
    this.onTap,
    this.onRetry,
    this.uploadProgress,
    this.otherUserName = '',
  });

  final ChatMessageModel message;
  final bool isSender;
  final VoidCallback? onTap;
  final VoidCallback? onRetry;
  final double? uploadProgress; // 0.0 to 1.0
  final String otherUserName;

  @override
  State<VideoMessageBubble> createState() => _VideoMessageBubbleState();
}

class _VideoMessageBubbleState extends State<VideoMessageBubble> {
  bool _isDownloading = false;
  double _downloadProgress = 0;
  bool _isCached = false;
  String? _cachedPath;

  @override
  void initState() {
    super.initState();
    _checkCacheStatus();
  }

  @override
  void didUpdateWidget(VideoMessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message.id != widget.message.id ||
        oldWidget.message.thumbnailUrl != widget.message.thumbnailUrl) {
      _checkCacheStatus();
    }
  }

  Future<void> _checkCacheStatus() async {
    final cachedPath = await MediaCacheService.instance.getCachedFile(
      widget.message.id,
    );
    final localPath = _resolveLocalPath(widget.message.localImagePath);
    final hasLocalPath = localPath != null && await File(localPath).exists();
    final resolvedPath = hasLocalPath ? localPath : cachedPath;
    if (mounted) {
      setState(() {
        _isCached = resolvedPath != null;
        _cachedPath = resolvedPath;
      });
    }
  }

  String? _resolveLocalPath(String? rawPath) {
    if (rawPath == null || rawPath.trim().isEmpty) return null;
    final trimmed = rawPath.trim();
    if (trimmed.startsWith('http')) return null;
    if (trimmed.startsWith('file://')) {
      try {
        return Uri.parse(trimmed).toFilePath();
      } catch (_) {
        return null;
      }
    }
    return trimmed;
  }

  Future<String?> _findExistingLocalFile() async {
    final candidates = <String?>[_cachedPath, widget.message.localImagePath];
    for (final candidate in candidates) {
      final resolved = _resolveLocalPath(candidate);
      if (resolved == null) continue;
      final file = File(resolved);
      if (await file.exists()) return resolved;
    }
    return null;
  }

  Future<void> _downloadAndOpenVideo() async {
    if (_isDownloading) return;

    // 1) Check existing local file (cached path or localImagePath)
    final existingPath = await _findExistingLocalFile();
    if (existingPath != null) {
      if (mounted) {
        setState(() {
          _isCached = true;
          _cachedPath = existingPath;
        });
      }
      await _openFile(existingPath);
      return;
    }

    // 2) For sender: re-check cache by message ID
    //    (handles temp ID → server ID change)
    if (widget.isSender) {
      final cachedPath = await MediaCacheService.instance.getCachedFile(
        widget.message.id,
      );
      if (cachedPath != null && await File(cachedPath).exists()) {
        if (mounted) {
          setState(() {
            _isCached = true;
            _cachedPath = cachedPath;
          });
        }
        await _openFile(cachedPath);
        return;
      }
    }

    final fileUrl = widget.message.imageUrl ?? widget.message.localImagePath;
    if (fileUrl == null || fileUrl.isEmpty) {
      _showError('No video file available');
      return;
    }

    // 3) For sender: silently download and cache (no progress UI)
    //    Same pattern as PDF bubble — sender should never see download progress
    if (widget.isSender) {
      try {
        final localPath = await MediaCacheService.instance.downloadAndCacheFile(
          messageId: widget.message.id,
          fileUrl: fileUrl,
          messageType: 'video',
        );
        if (localPath != null) {
          if (mounted) {
            setState(() {
              _isCached = true;
              _cachedPath = localPath;
            });
          }
          await _openFile(localPath);
        } else {
          _showError('Failed to open video');
        }
      } catch (e) {
        debugPrint('❌ Open error: $e');
        _showError('Failed to open video');
      }
      return;
    }

    // 4) For receiver: show download progress
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
    });

    try {
      final localPath = await MediaCacheService.instance.downloadAndCacheFile(
        messageId: widget.message.id,
        fileUrl: fileUrl,
        messageType: 'video',
        onProgress: (progress) {
          if (mounted) {
            setState(() => _downloadProgress = progress);
          }
        },
      );

      if (localPath != null) {
        if (mounted) {
          setState(() {
            _isCached = true;
            _cachedPath = localPath;
            _isDownloading = false;
          });
        }
        await _openFile(localPath);
      } else {
        if (mounted) {
          setState(() => _isDownloading = false);
        }
        _showError('Failed to download video');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
      _showError('Download failed: $e');
    }
  }

  Future<void> _openFile(String filePath) async {
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChatVideoViewerPage(
          message: widget.message,
          isMe: widget.isSender,
          otherUserName: widget.otherUserName,
          videoPath: filePath,
        ),
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  _BubbleSize _calculateBubbleSize({
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
        0.50; // ~50% of screen height (prevents full-screen videos)
    const defaultAspectRatio = 3 / 4; // taller default placeholder

    final minBubbleWidth = responsive.size(150);
    final minBubbleHeight = responsive.size(120);

    // Use ONLY message dimensions — no async resolution
    final effectiveWidth = widget.message.imageWidth;
    final effectiveHeight = widget.message.imageHeight;

    // Calculate max allowed dimensions from screen size (not constraints)
    final maxBubbleWidth = screenWidth * maxWidthFactor;
    final maxBubbleHeight = screenHeight * maxHeightFactor;

    if (effectiveWidth == null ||
        effectiveHeight == null ||
        effectiveWidth <= 0 ||
        effectiveHeight <= 0) {
      final bubbleWidth = maxBubbleWidth;
      final bubbleHeight = (bubbleWidth / defaultAspectRatio)
          .clamp(minBubbleHeight, maxBubbleHeight)
          .toDouble();
      return _BubbleSize(width: bubbleWidth, height: bubbleHeight);
    }

    final aspectRatio = effectiveWidth / effectiveHeight;

    // Deterministic sizing: keep width stable across devices, clamp height.
    // For very tall/wide videos we rely on BoxFit.cover cropping to avoid
    // very small bubbles.
    final bubbleWidth = maxBubbleWidth.clamp(minBubbleWidth, maxBubbleWidth);
    final rawHeight = bubbleWidth / aspectRatio;
    final bubbleHeight = rawHeight
        .clamp(minBubbleHeight, maxBubbleHeight)
        .toDouble();

    return _BubbleSize(width: bubbleWidth.toDouble(), height: bubbleHeight);
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayoutBuilder(
      builder: (context, constraints, breakpoint) {
        final responsive = ResponsiveSize(
          context: context,
          constraints: constraints,
          breakpoint: breakpoint,
        );

        final bubbleSize = _calculateBubbleSize(
          context: context,
          responsive: responsive,
          constraints: constraints,
        );

        final bubbleWidth = bubbleSize.width;
        final bubbleHeight = bubbleSize.height;

        final fileUrl =
            widget.message.imageUrl ?? widget.message.localImagePath;
        if (fileUrl == null || fileUrl.isEmpty) {
          return _buildErrorBubble(
            'No video URL',
            responsive: responsive,
            width: bubbleWidth,
            height: bubbleHeight,
          );
        }

        final thumbUrl = widget.message.thumbnailUrl;
        final hasThumb = thumbUrl != null && thumbUrl.isNotEmpty;

        final trimmedThumbUrl = thumbUrl?.trim() ?? '';
        final isApiThumb = hasThumb && trimmedThumbUrl.startsWith('/api/');
        final isUploadsThumb =
            hasThumb && trimmedThumbUrl.startsWith('/uploads/');
        final isRemoteRelativeThumb = isApiThumb || isUploadsThumb;

        final isLikelyLocalThumb =
            hasThumb &&
            !trimmedThumbUrl.startsWith('http') &&
            !isRemoteRelativeThumb &&
            (trimmedThumbUrl.startsWith('file://') ||
                trimmedThumbUrl.contains('cache') ||
                trimmedThumbUrl.startsWith('/data/') ||
                trimmedThumbUrl.startsWith('/storage/'));

        final fullThumbUrl = !hasThumb
            ? null
            : (isLikelyLocalThumb
                  ? _resolveLocalPath(trimmedThumbUrl) ?? trimmedThumbUrl
                  : (trimmedThumbUrl.startsWith('http')
                        ? trimmedThumbUrl
                        : (trimmedThumbUrl.startsWith('/api/') ||
                              trimmedThumbUrl.startsWith('/uploads/'))
                        ? '${ApiUrls.mediaBaseUrl}$trimmedThumbUrl'
                        : (trimmedThumbUrl.startsWith('api/') ||
                              trimmedThumbUrl.startsWith('uploads/'))
                        ? '${ApiUrls.mediaBaseUrl}/$trimmedThumbUrl'
                        : '${ApiUrls.mediaBaseUrl}/api/images/stream/${trimmedThumbUrl.startsWith('/') ? trimmedThumbUrl.substring(1) : trimmedThumbUrl}'));

        final isSending = widget.message.messageStatus == 'sending';
        final isFailed = widget.message.messageStatus == 'failed';
        final showDownload =
            !widget.isSender && !_isCached && !_isDownloading && !isSending;
        final showPlay = !showDownload && !_isDownloading && !isSending;

        final effectiveUploadProgress = (widget.uploadProgress ?? 0.01)
            .clamp(0.01, 1.0)
            .toDouble();
        final uploadPercent = (effectiveUploadProgress * 100).round().clamp(
          1,
          100,
        );

        final borderRadius = responsive.size(12);
        final effectiveCaptionText = widget.message.message.trim();
        final isDefaultVideoLabel =
            effectiveCaptionText.toLowerCase() == 'video';
        final hasCaption =
            effectiveCaptionText.isNotEmpty && !isDefaultVideoLabel;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final bubbleColor = widget.isSender
            ? (isDark ? const Color(0xFF1E3A5F) : AppColors.senderBubble)
            : (isDark ? const Color(0xFF2D2D2D) : AppColors.receiverBubble);
        final bubblePadding = widget.isSender
            ? responsive.size(2).clamp(1.0, 3.0).toDouble()
            : 0.0;
        final effectiveRadius = (borderRadius - bubblePadding)
            .clamp(0.0, borderRadius)
            .toDouble();

        return GestureDetector(
          onTap: () {
            if (widget.onTap != null) {
              widget.onTap?.call();
              return;
            }
            if (isSending || isFailed || _isDownloading) return;
            _downloadAndOpenVideo();
          },
          child: Container(
            padding: EdgeInsets.all(bubblePadding),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: bubbleWidth,
                  height: bubbleHeight,
                  child: ClipRRect(
                    borderRadius: hasCaption
                        ? BorderRadius.only(
                            topLeft: Radius.circular(effectiveRadius),
                            topRight: Radius.circular(effectiveRadius),
                          )
                        : BorderRadius.circular(effectiveRadius),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // ----- PLACEHOLDER BACKGROUND -----
                        Container(color: Colors.black),

                        // ----- THUMBNAIL -----
                        if (hasThumb)
                          isLikelyLocalThumb
                              ? Image.file(
                                  File(fullThumbUrl!),
                                  fit: BoxFit.cover,
                                  width: bubbleWidth,
                                  height: bubbleHeight,
                                  errorBuilder: (_, __, ___) =>
                                      Container(color: Colors.black),
                                )
                              : CachedNetworkImage(
                                  imageUrl: fullThumbUrl!,
                                  cacheManager:
                                      AuthenticatedImageCacheManager.instance,
                                  fit: BoxFit.cover,
                                  width: bubbleWidth,
                                  height: bubbleHeight,
                                  placeholder: (_, __) =>
                                      Container(color: Colors.black),
                                  imageBuilder: (context, imageProvider) {
                                    return Image(
                                      image: imageProvider,
                                      fit: BoxFit.cover,
                                      width: bubbleWidth,
                                      height: bubbleHeight,
                                    );
                                  },
                                  errorWidget: (_, __, ___) =>
                                      Container(color: Colors.black),
                                )
                        else
                          // No thumbnail — show video icon + file size
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.videocam,
                                  size: responsive.size(48),
                                  color: Colors.white70,
                                ),
                                SizedBox(height: responsive.spacing(8)),
                                if (widget.message.fileSize != null)
                                  Text(
                                    _formatFileSize(widget.message.fileSize!),
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: responsive.size(12),
                                    ),
                                  ),
                              ],
                            ),
                          ),

                        // ----- PLAY BUTTON (WhatsApp style) -----
                        if (showPlay)
                          Center(
                            child: Container(
                              width: responsive.size(52),
                              height: responsive.size(52),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black.withValues(alpha: 0.45),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                Icons.play_arrow_rounded,
                                size: responsive.size(34),
                                color: Colors.white,
                              ),
                            ),
                          ),

                        // ----- DOWNLOAD BUTTON (receiver, not cached) -----
                        if (showDownload)
                          Center(
                            child: Container(
                              width: responsive.size(52),
                              height: responsive.size(52),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black.withValues(alpha: 0.45),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                Icons.download_rounded,
                                size: responsive.size(28),
                                color: Colors.white,
                              ),
                            ),
                          ),

                        // ----- UPLOAD PROGRESS OVERLAY -----
                        if (isSending)
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
                                        backgroundColor: Colors.white
                                            .withValues(alpha: 0.25),
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
                        if (isFailed)
                          GestureDetector(
                            onTap: widget.onRetry,
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

                        // ----- DOWNLOAD PROGRESS OVERLAY -----
                        if (_isDownloading)
                          Container(
                            color: Colors.black.withValues(alpha: 0.4),
                            child: Center(
                              child: Container(
                                width: responsive.size(60),
                                height: responsive.size(60),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  shape: BoxShape.circle,
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    SizedBox(
                                      width: responsive.size(48),
                                      height: responsive.size(48),
                                      child: CircularProgressIndicator(
                                        value: _downloadProgress > 0
                                            ? _downloadProgress / 100
                                            : null,
                                        strokeWidth: responsive.size(3),
                                        backgroundColor: Colors.white24,
                                        valueColor:
                                            const AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    ),
                                    Text(
                                      '${_downloadProgress.toInt()}%',
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

                        // ----- TIMESTAMP & STATUS OVERLAY -----
                        if (!hasCaption)
                          Positioned(
                            right: responsive.spacing(4),
                            bottom: responsive.spacing(4),
                            child: _buildTimestampChip(responsive),
                          ),
                      ],
                    ),
                  ),
                ),

                // ----- CAPTION (WhatsApp-style below thumbnail) -----
                if (hasCaption)
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      responsive.spacing(10),
                      responsive.spacing(6),
                      responsive.spacing(10),
                      responsive.spacing(4),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          effectiveCaptionText,
                          style: TextStyle(
                            color: widget.isSender
                                ? Colors.white
                                : (isDark ? Colors.white : Colors.black87),
                            fontSize: responsive.size(14),
                          ),
                        ),
                        SizedBox(height: responsive.spacing(2)),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: _buildTimestampRow(responsive),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Timestamp chip overlay on video (no caption case) — WhatsApp style
  Widget _buildTimestampChip(ResponsiveSize responsive) {
    return Container(
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
          Text(
            ChatHelper.formatMessageTime(widget.message.createdAt),
            style: TextStyle(
              color: Colors.white,
              fontSize: responsive.size(11),
              fontWeight: FontWeight.w400,
            ),
          ),
          if (widget.isSender) ...[
            SizedBox(width: responsive.spacing(3)),
            MessageDeliveryStatusIcon(
              status: widget.message.messageStatus,
              color: widget.message.messageStatus == 'read'
                  ? AppColors.primary
                  : Colors.white70,
            ),
          ],
        ],
      ),
    );
  }

  /// Timestamp row for caption area — text-colored
  Widget _buildTimestampRow(ResponsiveSize responsive) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          ChatHelper.formatMessageTime(widget.message.createdAt),
          style: TextStyle(
            color: widget.isSender ? Colors.white60 : Colors.grey,
            fontSize: responsive.size(11),
            fontWeight: FontWeight.w400,
          ),
        ),
        if (widget.isSender) ...[
          SizedBox(width: responsive.spacing(3)),
          MessageDeliveryStatusIcon(
            status: widget.message.messageStatus,
            color: widget.message.messageStatus == 'read'
                ? AppColors.primary
                : (widget.isSender ? Colors.white60 : Colors.grey),
          ),
        ],
      ],
    );
  }

  Widget _buildErrorBubble(
    String errorMessage, {
    required ResponsiveSize responsive,
    double? width,
    double? height,
  }) {
    return Container(
      width: width ?? responsive.size(280),
      height: height ?? responsive.size(150),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(responsive.size(12)),
        color: Colors.grey.shade300,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
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

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _BubbleSize {
  const _BubbleSize({required this.width, required this.height});

  final double width;
  final double height;
}
