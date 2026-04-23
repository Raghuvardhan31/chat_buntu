import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:chataway_plus/core/constants/api_url/api_urls.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:chataway_plus/core/sync/authenticated_image_cache_manager.dart';
import 'package:chataway_plus/core/themes/app_text_styles.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/features/chat/models/chat_message_model.dart';
import 'package:chataway_plus/features/chat/utils/chat_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class ChatImageViewerPage extends StatefulWidget {
  const ChatImageViewerPage({
    super.key,
    required this.message,
    required this.isMe,
    required this.otherUserName,
  });

  final ChatMessageModel message;
  final bool isMe;
  final String otherUserName;

  @override
  State<ChatImageViewerPage> createState() => _ChatImageViewerPageState();
}

class _ChatImageViewerPageState extends State<ChatImageViewerPage> {
  bool _showOverlays = true;
  bool _isSaving = false;

  Future<void> _saveToGallery() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      // Try local file first
      final localPath = widget.message.localImagePath;
      if (localPath != null && localPath.isNotEmpty) {
        final file = File(localPath);
        if (await file.exists()) {
          await Gal.putImage(localPath, album: 'ChatAway+ Photos');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Saved to gallery'),
                duration: Duration(seconds: 2),
              ),
            );
          }
          if (mounted) setState(() => _isSaving = false);
          return;
        }
      }

      // Try remote URL — download then save
      final imageUrl = widget.message.imageUrl;
      if (imageUrl != null && imageUrl.isNotEmpty) {
        final fullUrl = imageUrl.startsWith('http')
            ? imageUrl
            : '${ApiUrls.mediaBaseUrl}/api/images/stream/$imageUrl';

        final response = await http.get(Uri.parse(fullUrl));
        if (response.statusCode == 200) {
          final tempDir = await getTemporaryDirectory();
          final ext = imageUrl.contains('.png') ? 'png' : 'jpg';
          final tempFile = File(
            '${tempDir.path}/chataway_save_${DateTime.now().millisecondsSinceEpoch}.$ext',
          );
          await tempFile.writeAsBytes(response.bodyBytes);
          await Gal.putImage(tempFile.path, album: 'ChatAway+ Photos');
          await tempFile.delete();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Saved to gallery'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        } else {
          throw Exception('Failed to download image');
        }
      } else {
        throw Exception('No image available to save');
      }
    } catch (e) {
      debugPrint('❌ Failed to save image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save image'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }

    if (mounted) setState(() => _isSaving = false);
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

        final displayName = widget.isMe ? 'You' : widget.otherUserName;
        final timeText = ChatHelper.formatMessageTime(widget.message.createdAt);

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarColor: Colors.black,
            statusBarIconBrightness: Brightness.light,
            systemNavigationBarColor: Colors.black,
            systemNavigationBarIconBrightness: Brightness.light,
          ),
          child: Scaffold(
            backgroundColor: Colors.black,
            body: SafeArea(
              child: GestureDetector(
                onTap: () => setState(() => _showOverlays = !_showOverlays),
                onLongPress: () {
                  if (_showOverlays) {
                    setState(() => _showOverlays = false);
                  }
                },
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Center(
                        child: InteractiveViewer(
                          minScale: 1,
                          maxScale: 4,
                          child: _buildImage(responsive),
                        ),
                      ),
                    ),

                    // ----- TOP BAR (sender info + save button) -----
                    if (_showOverlays)
                      Positioned(
                        top: responsive.spacing(10),
                        left: responsive.spacing(14),
                        right: responsive.spacing(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Sender info
                            Expanded(
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: responsive.spacing(12),
                                  vertical: responsive.spacing(10),
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(
                                    responsive.size(14),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (widget.isMe) ...[
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
                                        widget.otherUserName.trim().isEmpty
                                            ? 'Sent $timeText'
                                            : 'Sent $timeText to ${widget.otherUserName}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTextSizes.small(context)
                                            .copyWith(
                                              color: Colors.white,
                                              height: 1.2,
                                            ),
                                      ),
                                    ] else ...[
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
                                        'Sent $timeText to you',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTextSizes.small(context)
                                            .copyWith(
                                              color: Colors.white,
                                              height: 1.2,
                                            ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(width: responsive.spacing(8)),
                            // Save button
                            GestureDetector(
                              onTap: _isSaving ? null : _saveToGallery,
                              child: Container(
                                width: responsive.size(44),
                                height: responsive.size(44),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.35),
                                  shape: BoxShape.circle,
                                ),
                                child: _isSaving
                                    ? Padding(
                                        padding: EdgeInsets.all(
                                          responsive.size(12),
                                        ),
                                        child: const CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Icon(
                                        Icons.download_rounded,
                                        color: Colors.white,
                                        size: responsive.size(22),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // ----- BACK BUTTON -----
                    if (_showOverlays)
                      Positioned(
                        right: responsive.spacing(16),
                        bottom: responsive.spacing(16),
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).maybePop(),
                          child: Container(
                            width: responsive.size(52),
                            height: responsive.size(52),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.85),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.35),
                                  blurRadius: responsive.size(10),
                                  offset: Offset(0, responsive.size(4)),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                              size: responsive.size(24),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildImage(ResponsiveSize responsive) {
    final fileUrl = widget.message.localImagePath ?? widget.message.imageUrl;

    final fallback = Icon(
      Icons.broken_image,
      size: responsive.size(72),
      color: AppColors.iconSecondary,
    );

    if (fileUrl == null || fileUrl.trim().isEmpty) return fallback;

    if (fileUrl.startsWith('file://')) {
      try {
        final filePath = Uri.parse(fileUrl).toFilePath();
        return Image.file(File(filePath), fit: BoxFit.contain);
      } catch (_) {
        return fallback;
      }
    }

    final isLocalFile =
        !fileUrl.startsWith('http') &&
        (fileUrl.startsWith('/') || fileUrl.contains('cache'));

    final fullImageUrl = isLocalFile
        ? fileUrl
        : (fileUrl.startsWith('http')
              ? fileUrl
              : '${ApiUrls.mediaBaseUrl}/api/images/stream/$fileUrl');

    if (isLocalFile) {
      return Image.file(
        File(fullImageUrl),
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => fallback,
      );
    }

    return CachedNetworkImage(
      imageUrl: fullImageUrl,
      cacheManager: AuthenticatedImageCacheManager.instance,
      fit: BoxFit.contain,
      placeholder: (context, url) => CircularProgressIndicator(
        color: AppColors.primary,
        strokeWidth: responsive.size(2),
      ),
      errorWidget: (context, url, error) => fallback,
    );
  }
}
