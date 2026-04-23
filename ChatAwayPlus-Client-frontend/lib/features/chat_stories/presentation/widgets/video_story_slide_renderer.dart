import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chataway_plus/core/constants/api_url/api_urls.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:chataway_plus/core/themes/app_text_styles.dart';

/// Renders a video story slide with play/pause controls.
///
/// Supports both local files and network URLs.
/// Designed for fullscreen story viewing with:
/// - Auto-play on load
/// - Tap to pause/resume
/// - Loading indicator while buffering
/// - Error state with retry
/// - Caption overlay at bottom
class VideoStorySlideRenderer extends StatefulWidget {
  const VideoStorySlideRenderer({
    super.key,
    required this.responsive,
    this.networkVideoUrl,
    this.localFile,
    this.caption,
    this.onVideoInitialized,
    this.onVideoCompleted,
  });

  final ResponsiveSize responsive;
  final String? networkVideoUrl;
  final File? localFile;
  final String? caption;

  /// Called when video is initialized — passes duration in seconds
  final ValueChanged<int>? onVideoInitialized;

  /// Called when video playback completes
  final VoidCallback? onVideoCompleted;

  @override
  State<VideoStorySlideRenderer> createState() =>
      _VideoStorySlideRendererState();
}

class _VideoStorySlideRendererState extends State<VideoStorySlideRenderer> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initializeVideo() async {
    try {
      if (widget.localFile != null) {
        try {
          _controller = VideoPlayerController.file(widget.localFile!);
          await _controller!.initialize();
        } catch (e) {
          debugPrint('⚠️ VideoSlideRenderer: File playback failed: $e');
          debugPrint('🔄 Trying content URI fallback...');
          _controller?.dispose();
          _controller = null;

          final uri = Uri.file(widget.localFile!.path);
          _controller = VideoPlayerController.contentUri(uri);
          await _controller!.initialize();
        }
      } else if (widget.networkVideoUrl != null &&
          widget.networkVideoUrl!.isNotEmpty) {
        final fullUrl = _buildFullUrl(widget.networkVideoUrl!);
        _controller = VideoPlayerController.networkUrl(Uri.parse(fullUrl));
        await _controller!.initialize();
      } else {
        setState(() => _hasError = true);
        return;
      }

      if (!mounted) return;

      _controller!.addListener(_onVideoUpdate);
      _controller!.setLooping(false);
      _controller!.play();

      setState(() => _isInitialized = true);

      final durationSeconds = _controller!.value.duration.inSeconds;
      widget.onVideoInitialized?.call(durationSeconds);
    } catch (e) {
      debugPrint('❌ Video init error: $e');
      if (mounted) setState(() => _hasError = true);
    }
  }

  void _onVideoUpdate() {
    if (!mounted || _controller == null) return;

    final value = _controller!.value;
    if (value.position >= value.duration && value.duration.inMilliseconds > 0) {
      widget.onVideoCompleted?.call();
    }
  }

  void _togglePlayPause() {
    if (_controller == null || !_isInitialized) return;

    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
        _isPaused = true;
      } else {
        _controller!.play();
        _isPaused = false;
      }
    });
  }

  /// Pause video externally (e.g., when story progress pauses)
  void pause() {
    if (_controller != null && _isInitialized && _controller!.value.isPlaying) {
      _controller!.pause();
      if (mounted) setState(() => _isPaused = true);
    }
  }

  /// Resume video externally
  void resume() {
    if (_controller != null &&
        _isInitialized &&
        !_controller!.value.isPlaying) {
      _controller!.play();
      if (mounted) setState(() => _isPaused = false);
    }
  }

  String _buildFullUrl(String url) {
    final raw = url.trim();
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    if (raw.startsWith('/')) {
      if (raw.startsWith('/api/') || raw.startsWith('/uploads/')) {
        return '${ApiUrls.mediaBaseUrl}$raw';
      }
      return '${ApiUrls.mediaBaseUrl}/api/images/stream/${raw.substring(1)}';
    }
    if (raw.startsWith('api/') || raw.startsWith('uploads/')) {
      return '${ApiUrls.mediaBaseUrl}/$raw';
    }
    return '${ApiUrls.mediaBaseUrl}/api/images/stream/$raw';
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final responsive = widget.responsive;
    final cap = (widget.caption ?? '').trim();

    // Error state
    if (_hasError) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.videocam_off_rounded,
                size: responsive.size(48),
                color: Colors.white70,
              ),
              SizedBox(height: responsive.spacing(12)),
              Text(
                'Unable to load video',
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
              SizedBox(height: responsive.spacing(16)),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _hasError = false;
                    _isInitialized = false;
                  });
                  _initializeVideo();
                },
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: responsive.spacing(20),
                    vertical: responsive.spacing(10),
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha((0.15 * 255).round()),
                    borderRadius: BorderRadius.circular(responsive.size(20)),
                  ),
                  child: Text(
                    'Retry',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: responsive.size(14),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Loading state
    if (!_isInitialized) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                strokeWidth: responsive.size(2),
                color: Colors.white,
              ),
              SizedBox(height: responsive.spacing(12)),
              Text(
                'Loading video...',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: responsive.size(14),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Video player
    final controller = _controller!;
    final aspectRatio = controller.value.aspectRatio;

    return GestureDetector(
      onTap: _togglePlayPause,
      child: Stack(
        children: [
          // Black background
          Positioned.fill(child: Container(color: Colors.black)),

          // Video centered with correct aspect ratio
          Positioned.fill(
            child: Center(
              child: AspectRatio(
                aspectRatio: aspectRatio > 0 ? aspectRatio : 9 / 16,
                child: VideoPlayer(controller),
              ),
            ),
          ),

          // Pause icon overlay
          if (_isPaused)
            Positioned.fill(
              child: Container(
                color: Colors.black.withAlpha((0.3 * 255).round()),
                child: Center(
                  child: Container(
                    width: responsive.size(64),
                    height: responsive.size(64),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withAlpha((0.5 * 255).round()),
                    ),
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: responsive.size(40),
                    ),
                  ),
                ),
              ),
            ),

          // Video progress bar at bottom
          Positioned(
            left: responsive.spacing(14),
            right: responsive.spacing(14),
            bottom: cap.isNotEmpty
                ? responsive.spacing(120)
                : responsive.spacing(74),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Duration text
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ValueListenableBuilder(
                      valueListenable: controller,
                      builder: (_, value, __) {
                        return Text(
                          _formatDuration(value.position),
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: responsive.size(11),
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      },
                    ),
                    Text(
                      _formatDuration(controller.value.duration),
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: responsive.size(11),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: responsive.spacing(4)),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(responsive.size(2)),
                  child: ValueListenableBuilder(
                    valueListenable: controller,
                    builder: (_, value, __) {
                      final progress = value.duration.inMilliseconds > 0
                          ? value.position.inMilliseconds /
                                value.duration.inMilliseconds
                          : 0.0;
                      return LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.white.withAlpha(
                          (0.2 * 255).round(),
                        ),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                        minHeight: responsive.size(2.5),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Video badge (top left)
          Positioned(
            left: responsive.spacing(14),
            bottom: responsive.spacing(74),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: responsive.spacing(8),
                vertical: responsive.spacing(4),
              ),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha((0.5 * 255).round()),
                borderRadius: BorderRadius.circular(responsive.size(6)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.videocam_rounded,
                    color: Colors.white70,
                    size: responsive.size(12),
                  ),
                  SizedBox(width: responsive.spacing(4)),
                  Text(
                    'Video',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: responsive.size(10),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Caption overlay
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
                  color: Colors.black.withAlpha((0.38 * 255).round()),
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
      ),
    );
  }
}
