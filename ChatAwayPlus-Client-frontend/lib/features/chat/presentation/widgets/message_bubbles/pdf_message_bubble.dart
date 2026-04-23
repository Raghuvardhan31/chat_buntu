// lib/features/chat/presentation/widgets/message_bubbles/pdf_message_bubble.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/features/chat/models/chat_message_model.dart';
import 'package:chataway_plus/features/chat/data/media/media_cache_service.dart';
import 'package:chataway_plus/features/chat/presentation/widgets/chat_ui/message_delivery_status_icon.dart';
import 'package:chataway_plus/features/chat/utils/chat_helper.dart';

/// Widget to display PDF/document messages in chat
/// Supports downloading and opening with native PDF viewer
/// Uses WhatsApp-style bubble-color frame around content
class PdfMessageBubble extends StatefulWidget {
  const PdfMessageBubble({
    super.key,
    required this.message,
    required this.isSender,
    this.onTap,
    this.onRetry,
    this.uploadProgress,
  });

  final ChatMessageModel message;
  final bool isSender;
  final VoidCallback? onTap;
  final VoidCallback? onRetry;
  final double? uploadProgress; // 0.0 to 1.0

  @override
  State<PdfMessageBubble> createState() => _PdfMessageBubbleState();
}

class _PdfMessageBubbleState extends State<PdfMessageBubble> {
  bool _isDownloading = false;
  double _downloadProgress = 0;
  bool _isCached = false;
  String? _cachedPath;

  @override
  void initState() {
    super.initState();
    _checkCacheStatus();
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

  Future<void> _downloadAndOpenFile() async {
    // If already downloading, ignore tap
    if (_isDownloading) return;

    // If already cached, open directly
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

    // For sender messages, try to find the file in cache by message ID
    // This handles the case where temp ID was replaced with server ID
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

    // Start download (only for receiver or if sender's file not found locally)
    final fileUrl = widget.message.imageUrl ?? widget.message.localImagePath;
    if (fileUrl == null || fileUrl.isEmpty) {
      _showError('No file URL available');
      return;
    }

    // For sender, don't show download progress - just open directly after download
    if (widget.isSender) {
      try {
        final localPath = await MediaCacheService.instance.downloadAndCacheFile(
          messageId: widget.message.id,
          fileUrl: fileUrl,
          messageType: 'document',
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
          _showError('Failed to open file');
        }
      } catch (e) {
        debugPrint('❌ Open error: $e');
        _showError('Failed to open file');
      }
      return;
    }

    // For receiver, show download progress
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
    });

    try {
      final localPath = await MediaCacheService.instance.downloadAndCacheFile(
        messageId: widget.message.id,
        fileUrl: fileUrl,
        messageType: 'document',
        onProgress: (progress) {
          if (mounted) {
            setState(() => _downloadProgress = progress);
          }
        },
      );

      if (localPath != null) {
        setState(() {
          _isCached = true;
          _cachedPath = localPath;
          _isDownloading = false;
        });
        await _openFile(localPath);
      } else {
        setState(() => _isDownloading = false);
        _showError('Failed to download file');
      }
    } catch (e) {
      debugPrint('❌ Download error: $e');
      setState(() => _isDownloading = false);
      _showError('Download failed: $e');
    }
  }

  Future<void> _openFile(String filePath) async {
    try {
      debugPrint('📄 Opening file: $filePath');
      final result = await OpenFilex.open(filePath);
      debugPrint('📄 Open result: ${result.type} - ${result.message}');

      if (result.type != ResultType.done) {
        _showError(_formatOpenError(result));
      }
    } catch (e) {
      debugPrint('❌ Error opening file: $e');
      _showError('Failed to open file');
    }
  }

  String _formatOpenError(OpenResult result) {
    switch (result.type) {
      case ResultType.noAppToOpen:
        return 'No PDF viewer found. Please install a PDF reader to open this file.';
      case ResultType.permissionDenied:
        return 'Permission denied. Please allow file access to open this PDF.';
      default:
        if (result.message.trim().isNotEmpty) {
          return 'Unable to open file: ${result.message}';
        }
        return 'Unable to open file. Please try again.';
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    // Use global notification service instead of SnackBar
    debugPrint('❌ [PDF] $message');
    // TODO: Integrate with global notification service when available
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
        final isDark = Theme.of(context).brightness == Brightness.dark;

        final fileUrl =
            widget.message.imageUrl ?? widget.message.localImagePath;
        if (fileUrl == null || fileUrl.isEmpty) {
          return _buildErrorBubble('No document URL', responsive);
        }

        final fileName = widget.message.fileName ?? 'Document.pdf';
        final fileSize = widget.message.fileSize;
        final pageCount = widget.message.pageCount;
        final isSending = widget.message.messageStatus == 'sending';
        final isFailed = widget.message.messageStatus == 'failed';

        // Wider, cleaner document bubble
        final bubbleWidth =
            ((constraints.maxWidth * 0.88).clamp(
                      responsive.size(240),
                      responsive.size(380),
                    ) -
                    responsive.size(8))
                .toDouble();

        final bubbleColor = widget.isSender
            ? (isDark ? const Color(0xFF1E3A5F) : AppColors.senderBubble)
            : (isDark ? const Color(0xFF2D2D2D) : AppColors.receiverBubble);
        final cardColor = isDark
            ? Colors.white.withValues(alpha: widget.isSender ? 0.10 : 0.08)
            : (widget.isSender
                  ? Colors.white.withValues(alpha: 0.96)
                  : Colors.white);

        final VoidCallback? tapHandler =
            widget.onTap ??
            (isFailed
                ? widget.onRetry
                : (isSending ? null : _downloadAndOpenFile));

        return GestureDetector(
          onTap: tapHandler,
          child: Container(
            width: bubbleWidth,
            padding: EdgeInsets.all(responsive.spacing(2)),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.circular(responsive.size(12)),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : Colors.black.withValues(alpha: 0.05),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: responsive.size(6),
                  offset: Offset(0, responsive.spacing(1)),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: responsive.spacing(10),
                    vertical: responsive.spacing(8),
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(responsive.size(10)),
                    color: cardColor,
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.black.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Main content row
                      Row(
                        children: [
                          // PDF Icon with download/upload progress overlay
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: responsive.size(40),
                                height: responsive.size(40),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFEF4444),
                                      Color(0xFFDC2626),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    responsive.size(10),
                                  ),
                                ),
                                child: Icon(
                                  Icons.picture_as_pdf,
                                  color: Colors.white,
                                  size: responsive.size(22),
                                ),
                              ),
                              // Upload progress indicator (when sending)
                              if (isSending && widget.uploadProgress != null)
                                SizedBox(
                                  width: responsive.size(40),
                                  height: responsive.size(40),
                                  child: CircularProgressIndicator(
                                    value: widget.uploadProgress,
                                    strokeWidth: responsive.size(3),
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                    backgroundColor: Colors.white30,
                                  ),
                                ),
                              // Download progress indicator
                              if (_isDownloading)
                                SizedBox(
                                  width: responsive.size(40),
                                  height: responsive.size(40),
                                  child: CircularProgressIndicator(
                                    value: _downloadProgress > 0
                                        ? _downloadProgress / 100
                                        : null,
                                    strokeWidth: responsive.size(3),
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                    backgroundColor: Colors.white30,
                                  ),
                                ),
                              // Cached indicator (checkmark)
                              if (_isCached && !_isDownloading && !isSending)
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    width: responsive.size(16),
                                    height: responsive.size(16),
                                    decoration: const BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: responsive.size(10),
                                    ),
                                  ),
                                ),
                              // Failed indicator
                              if (isFailed)
                                Container(
                                  width: responsive.size(40),
                                  height: responsive.size(40),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.8),
                                    borderRadius: BorderRadius.circular(
                                      responsive.size(10),
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.refresh,
                                    color: Colors.white,
                                    size: responsive.size(20),
                                  ),
                                ),
                            ],
                          ),
                          SizedBox(width: responsive.spacing(8)),

                          // File info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  fileName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: responsive.size(13),
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: responsive.spacing(1)),
                                Row(
                                  children: [
                                    if (fileSize != null) ...[
                                      Text(
                                        _formatFileSize(fileSize),
                                        style: TextStyle(
                                          fontSize: responsive.size(11),
                                          color: isDark
                                              ? Colors.white70
                                              : AppColors.colorGrey,
                                        ),
                                      ),
                                    ],
                                    if (fileSize != null && pageCount != null)
                                      Text(
                                        ' • ',
                                        style: TextStyle(
                                          fontSize: responsive.size(11),
                                          color: isDark
                                              ? Colors.white70
                                              : AppColors.colorGrey,
                                        ),
                                      ),
                                    if (pageCount != null)
                                      Text(
                                        '$pageCount pages',
                                        style: TextStyle(
                                          fontSize: responsive.size(11),
                                          color: isDark
                                              ? Colors.white70
                                              : AppColors.colorGrey,
                                        ),
                                      ),
                                  ],
                                ),
                                // Status text
                                SizedBox(height: responsive.spacing(1)),
                                _buildStatusText(
                                  isSending,
                                  isFailed,
                                  responsive,
                                  widget.isSender,
                                ),
                              ],
                            ),
                          ),

                          // Action icon
                          _buildActionIcon(
                            isSending,
                            isFailed,
                            responsive,
                            widget.isSender,
                          ),
                        ],
                      ),
                      // Timestamp row
                      SizedBox(height: responsive.spacing(2)),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              ChatHelper.formatMessageTime(
                                widget.message.createdAt,
                              ),
                              style: TextStyle(
                                fontSize: responsive.size(11),
                                color: isDark
                                    ? Colors.white70
                                    : AppColors.colorGrey,
                              ),
                            ),
                            if (widget.isSender) ...[
                              SizedBox(width: responsive.spacing(4)),
                              _buildStatusIcon(
                                widget.message.messageStatus,
                                responsive,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Caption below document (WhatsApp-style)
                if (widget.message.message.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      responsive.spacing(10),
                      responsive.spacing(8),
                      responsive.spacing(10),
                      responsive.spacing(8),
                    ),
                    child: Text(
                      widget.message.message,
                      style: TextStyle(
                        color: widget.isSender ? Colors.white : Colors.black87,
                        fontSize: responsive.size(14),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusText(
    bool isSending,
    bool isFailed,
    ResponsiveSize responsive,
    bool isSender,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isFailed) {
      return Text(
        'Tap to retry',
        style: TextStyle(fontSize: responsive.size(11), color: Colors.red),
      );
    }

    if (isSending) {
      final progressText = widget.uploadProgress != null
          ? '${(widget.uploadProgress! * 100).toInt()}%'
          : '';
      return Row(
        children: [
          SizedBox(
            width: responsive.size(12),
            height: responsive.size(12),
            child: CircularProgressIndicator(
              strokeWidth: responsive.size(2),
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          SizedBox(width: responsive.spacing(6)),
          Text(
            'Uploading$progressText',
            style: TextStyle(
              fontSize: responsive.size(11),
              color: AppColors.primary,
            ),
          ),
        ],
      );
    }

    if (_isDownloading) {
      return Text(
        'Downloading ${_downloadProgress.toStringAsFixed(0)}%',
        style: TextStyle(
          fontSize: responsive.size(11),
          color: AppColors.primary,
        ),
      );
    }

    if (isSender) {
      return const SizedBox.shrink();
    }

    if (_isCached) {
      return Text(
        'Tap to open',
        style: TextStyle(
          fontSize: responsive.size(11),
          color: isDark ? Colors.green.shade300 : Colors.green.shade600,
        ),
      );
    }

    return Text(
      'Tap to download',
      style: TextStyle(
        fontSize: responsive.size(11),
        color: isDark ? Colors.white70 : AppColors.colorGrey,
      ),
    );
  }

  Widget _buildActionIcon(
    bool isSending,
    bool isFailed,
    ResponsiveSize responsive,
    bool isSender,
  ) {
    if (isFailed) {
      return Icon(Icons.refresh, color: Colors.red, size: responsive.size(20));
    }

    if (isSending) {
      return const SizedBox.shrink();
    }

    if (isSender && !_isCached && !_isDownloading) {
      return const SizedBox.shrink();
    }

    if (_isDownloading) {
      return SizedBox(
        width: responsive.size(20),
        height: responsive.size(20),
        child: CircularProgressIndicator(
          strokeWidth: responsive.size(2),
          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      );
    }

    if (_isCached) {
      return Icon(
        Icons.open_in_new,
        color: Colors.green,
        size: responsive.size(20),
      );
    }

    return Icon(
      Icons.download,
      color: AppColors.primary,
      size: responsive.size(20),
    );
  }

  Widget _buildErrorBubble(String errorMessage, ResponsiveSize responsive) {
    return Container(
      padding: EdgeInsets.all(responsive.spacing(12)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(responsive.size(12)),
        color: Colors.grey.shade300,
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.grey),
          SizedBox(width: responsive.spacing(8)),
          Text(
            errorMessage,
            style: TextStyle(color: Colors.grey, fontSize: responsive.size(12)),
          ),
        ],
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Widget _buildStatusIcon(String status, ResponsiveSize responsive) {
    final Color iconColor = status == 'read'
        ? AppColors.primary
        : (status == 'failed' ? Colors.red : Colors.grey.shade500);

    return MessageDeliveryStatusIcon(status: status, color: iconColor);
  }
}
