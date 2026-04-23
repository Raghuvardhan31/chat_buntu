import 'dart:io';

import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

class PdfPreviewPage extends StatefulWidget {
  const PdfPreviewPage({
    super.key,
    required this.pdfFile,
    required this.receiverName,
    required this.onSend,
  });

  final File pdfFile;
  final String receiverName;
  final void Function(File pdfFile, String caption) onSend;

  @override
  State<PdfPreviewPage> createState() => _PdfPreviewPageState();
}

class _PdfPreviewPageState extends State<PdfPreviewPage> {
  final TextEditingController _captionController = TextEditingController();
  final FocusNode _captionFocusNode = FocusNode();
  bool _isSending = false;

  @override
  void dispose() {
    _captionController.dispose();
    _captionFocusNode.dispose();
    super.dispose();
  }

  void _handleSend() {
    if (_isSending) return;

    setState(() => _isSending = true);

    final caption = _captionController.text.trim();
    widget.onSend(widget.pdfFile, caption);

    Navigator.of(context).pop();
  }

  String _formatBytes(int bytes) {
    const kb = 1024;
    const mb = 1024 * 1024;
    if (bytes >= mb) return '${(bytes / mb).toStringAsFixed(1)} MB';
    if (bytes >= kb) return '${(bytes / kb).toStringAsFixed(1)} KB';
    return '$bytes B';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: ResponsiveLayoutBuilder(
        builder: (context, constraints, breakpoint) {
          final responsive = ResponsiveSize(
            context: context,
            constraints: constraints,
            breakpoint: breakpoint,
          );
          final viewInsets = MediaQuery.of(context).viewInsets.bottom;

          return SafeArea(
            child: Column(
              children: [
                _buildTopBar(responsive),
                Expanded(child: _buildPdfCard(responsive)),
                _buildBottomBar(responsive, viewInsets: viewInsets),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopBar(ResponsiveSize responsive) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: responsive.spacing(8),
        vertical: responsive.spacing(12),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(
              Icons.close,
              color: Colors.white,
              size: responsive.size(28),
            ),
          ),
          SizedBox(width: responsive.spacing(8)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.receiverName,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: responsive.size(18),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Document',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: responsive.size(14),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPdfCard(ResponsiveSize responsive) {
    final fileName = widget.pdfFile.path.split(Platform.pathSeparator).last;

    return FutureBuilder<int>(
      future: widget.pdfFile.length(),
      builder: (context, snapshot) {
        final sizeBytes = snapshot.data;
        return LayoutBuilder(
          builder: (context, constraints) {
            final previewWidth = (constraints.maxWidth * 0.82)
                .clamp(responsive.size(240), responsive.size(340))
                .toDouble();
            final previewHeight = (previewWidth * 1.35)
                .clamp(responsive.size(260), responsive.size(460))
                .toDouble();

            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(vertical: responsive.spacing(8)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildPdfPreview(responsive, previewWidth, previewHeight),
                    SizedBox(height: responsive.spacing(16)),
                    _buildPdfInfoCard(responsive, fileName, sizeBytes),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPdfPreview(
    ResponsiveSize responsive,
    double width,
    double height,
  ) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(responsive.size(14)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: responsive.size(12),
            offset: Offset(0, responsive.spacing(6)),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(responsive.size(14)),
        child: PdfDocumentViewBuilder.file(
          widget.pdfFile.path,
          loadingBuilder: (context) => _buildPdfPreviewLoading(responsive),
          errorBuilder: (context, error, stackTrace) =>
              _buildPdfPreviewError(responsive),
          builder: (context, document) {
            if (document == null) {
              return _buildPdfPreviewLoading(responsive);
            }
            return PdfPageView(
              document: document,
              pageNumber: 1,
              alignment: Alignment.center,
            );
          },
        ),
      ),
    );
  }

  Widget _buildPdfPreviewLoading(ResponsiveSize responsive) {
    return Center(
      child: SizedBox(
        width: responsive.size(28),
        height: responsive.size(28),
        child: CircularProgressIndicator(
          strokeWidth: responsive.size(2.5),
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildPdfPreviewError(ResponsiveSize responsive) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.picture_as_pdf,
            size: responsive.size(48),
            color: Colors.black38,
          ),
          SizedBox(height: responsive.spacing(8)),
          Text(
            'Preview unavailable',
            style: TextStyle(
              color: Colors.black54,
              fontSize: responsive.size(14),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPdfInfoCard(
    ResponsiveSize responsive,
    String fileName,
    int? sizeBytes,
  ) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: responsive.spacing(16)),
      padding: EdgeInsets.all(responsive.spacing(16)),
      constraints: BoxConstraints(maxWidth: responsive.size(360)),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(responsive.size(14)),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: responsive.size(1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: responsive.size(52),
            height: responsive.size(52),
            decoration: BoxDecoration(
              color: const Color(0xFFE53935),
              borderRadius: BorderRadius.circular(responsive.size(12)),
            ),
            child: Center(
              child: Icon(
                Icons.picture_as_pdf,
                color: Colors.white,
                size: responsive.size(28),
              ),
            ),
          ),
          SizedBox(width: responsive.spacing(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  fileName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: responsive.size(15),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: responsive.spacing(4)),
                Text(
                  sizeBytes != null ? _formatBytes(sizeBytes) : ' ',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: responsive.size(13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(
    ResponsiveSize responsive, {
    required double viewInsets,
  }) {
    return Container(
      padding: EdgeInsets.only(
        left: responsive.spacing(12),
        right: responsive.spacing(12),
        top: responsive.spacing(12),
        bottom: responsive.spacing(16),
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
        ),
      ),
      child: Center(
        child: GestureDetector(
          onTap: _isSending ? null : _handleSend,
          child: Container(
            width: responsive.size(56),
            height: responsive.size(56),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isSending
                  ? AppColors.primary.withValues(alpha: 0.5)
                  : AppColors.primary,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: responsive.size(8),
                  offset: Offset(0, responsive.spacing(4)),
                ),
              ],
            ),
            child: Center(
              child: _isSending
                  ? SizedBox(
                      width: responsive.size(24),
                      height: responsive.size(24),
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: responsive.size(2),
                      ),
                    )
                  : Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: responsive.size(26),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
