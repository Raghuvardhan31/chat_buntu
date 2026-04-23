import 'dart:io';

import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class VideoPreviewPage extends StatefulWidget {
  const VideoPreviewPage({
    super.key,
    required this.videoFile,
    required this.receiverName,
    required this.onSend,
  });

  final File videoFile;
  final String receiverName;
  final void Function(File videoFile, String caption, File? thumbnailFile)
  onSend;

  @override
  State<VideoPreviewPage> createState() => _VideoPreviewPageState();
}

class _VideoPreviewPageState extends State<VideoPreviewPage> {
  bool _isSending = false;
  bool _isPreparingThumbnail = true;
  late File _currentVideoFile;
  File? _thumbnailFile;

  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _currentVideoFile = widget.videoFile;
    _generateThumbnail();
    _initVideoPlayer();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _initVideoPlayer() async {
    try {
      _videoController = VideoPlayerController.file(_currentVideoFile);
      await _videoController!.initialize();
      await _videoController!.setVolume(1.0);
      _videoController!.setLooping(true);
      if (!mounted) return;
      setState(() => _isVideoInitialized = true);
    } catch (e) {
      debugPrint('\u26a0\ufe0f [VideoPreview] Failed to init video player: $e');
    }
  }

  void _togglePlayPause() {
    if (_videoController == null || !_isVideoInitialized) return;
    setState(() {
      if (_videoController!.value.isPlaying) {
        _videoController!.pause();
        _isPlaying = false;
      } else {
        _videoController!.play();
        _isPlaying = true;
      }
    });
  }

  void _handleSend() {
    if (_isSending) return;

    setState(() => _isSending = true);

    widget.onSend(_currentVideoFile, '', _thumbnailFile);

    Navigator.of(context).pop();
  }

  Future<void> _generateThumbnail() async {
    try {
      final dir = await getTemporaryDirectory();
      final thumbPath = await VideoThumbnail.thumbnailFile(
        video: _currentVideoFile.path,
        thumbnailPath: dir.path,
        imageFormat: ImageFormat.PNG,
        quality: 90,
      );
      if (!mounted) return;
      setState(() {
        _thumbnailFile = (thumbPath != null) ? File(thumbPath) : null;
        _isPreparingThumbnail = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _thumbnailFile = null;
        _isPreparingThumbnail = false;
      });
    }
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
                Expanded(child: _buildVideoPreview(responsive)),
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
                  'Video',
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

  Widget _buildVideoPreview(ResponsiveSize responsive) {
    final fileName = widget.videoFile.path.split(Platform.pathSeparator).last;

    return Center(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: responsive.spacing(12)),
        constraints: BoxConstraints(
          maxWidth: responsive.size(340),
          maxHeight: responsive.size(520),
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF121212),
          borderRadius: BorderRadius.circular(responsive.size(14)),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: _isVideoInitialized && _videoController != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(responsive.size(14)),
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: _videoController!.value.size.width,
                          height: _videoController!.value.size.height,
                          child: VideoPlayer(_videoController!),
                        ),
                      ),
                    )
                  : _isPreparingThumbnail
                  ? Container(color: const Color(0xFF121212))
                  : (_thumbnailFile != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(
                              responsive.size(14),
                            ),
                            child: Image.file(
                              _thumbnailFile!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  Container(color: const Color(0xFF121212)),
                            ),
                          )
                        : Container(color: const Color(0xFF121212))),
            ),
            GestureDetector(
              onTap: _togglePlayPause,
              behavior: HitTestBehavior.opaque,
              child: Center(
                child: AnimatedOpacity(
                  opacity: _isPlaying ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha((0.5 * 255).round()),
                      shape: BoxShape.circle,
                    ),
                    padding: EdgeInsets.all(responsive.spacing(12)),
                    child: Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: responsive.size(56),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: responsive.spacing(12),
              right: responsive.spacing(12),
              bottom: responsive.spacing(12),
              child: Text(
                fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: responsive.size(13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(
    ResponsiveSize responsive, {
    required double viewInsets,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(
        left: responsive.spacing(12),
        right: responsive.spacing(12),
        top: responsive.spacing(12),
        bottom: viewInsets > 0
            ? viewInsets + responsive.spacing(8)
            : responsive.spacing(16),
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          GestureDetector(
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
        ],
      ),
    );
  }
}
