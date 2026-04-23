import 'package:chataway_plus/core/constants/api_url/api_urls.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:chataway_plus/core/themes/app_text_styles.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/features/chat/models/chat_message_model.dart';
import 'package:chataway_plus/features/chat/utils/chat_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';

class ChatPdfViewerPage extends StatefulWidget {
  const ChatPdfViewerPage({
    super.key,
    required this.message,
    required this.isMe,
    required this.otherUserName,
  });

  final ChatMessageModel message;
  final bool isMe;
  final String otherUserName;

  @override
  State<ChatPdfViewerPage> createState() => _ChatPdfViewerPageState();
}

class _ChatPdfViewerPageState extends State<ChatPdfViewerPage> {
  @override
  Widget build(BuildContext context) {
    return ResponsiveLayoutBuilder(
      builder: (context, constraints, breakpoint) {
        final responsive = ResponsiveSize(
          context: context,
          constraints: constraints,
          breakpoint: breakpoint,
        );

        final timeText = ChatHelper.formatMessageTime(widget.message.createdAt);
        final displayName = widget.isMe ? 'You' : widget.otherUserName;

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
              child: Stack(
                children: [
                  Positioned.fill(child: _buildPdfView(responsive)),

                  Positioned(
                    top: responsive.spacing(10),
                    left: responsive.spacing(14),
                    right: responsive.spacing(14),
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
                              style: AppTextSizes.small(
                                context,
                              ).copyWith(color: Colors.white70, height: 1.2),
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
                              style: AppTextSizes.small(
                                context,
                              ).copyWith(color: Colors.white70, height: 1.2),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

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
        );
      },
    );
  }

  Widget _buildPdfView(ResponsiveSize responsive) {
    final fileUrl = widget.message.localImagePath ?? widget.message.imageUrl;
    if (fileUrl == null || fileUrl.trim().isEmpty) {
      return _buildError(responsive, 'No PDF URL');
    }

    String resolvedPath = fileUrl;
    bool isLocalFile = false;

    if (fileUrl.startsWith('file://')) {
      try {
        resolvedPath = Uri.parse(fileUrl).toFilePath();
        isLocalFile = true;
      } catch (_) {
        return _buildError(responsive, 'Invalid local file path');
      }
    } else if (!fileUrl.startsWith('http') &&
        (fileUrl.startsWith('/') || fileUrl.contains('cache'))) {
      isLocalFile = true;
    } else {
      resolvedPath = fileUrl.startsWith('http')
          ? fileUrl
          : '${ApiUrls.mediaBaseUrl}/api/images/stream/$fileUrl';
    }

    final params = PdfViewerParams(backgroundColor: Colors.black);
    final pdfView = isLocalFile
        ? PdfViewer.file(resolvedPath, params: params)
        : PdfViewer.uri(Uri.parse(resolvedPath), params: params);

    return Container(color: Colors.black, child: pdfView);
  }

  Widget _buildError(ResponsiveSize responsive, String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.picture_as_pdf,
            size: responsive.size(56),
            color: Colors.white70,
          ),
          SizedBox(height: responsive.spacing(6)),
          Text(
            message,
            style: AppTextSizes.small(context).copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
