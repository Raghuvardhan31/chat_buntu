import 'dart:io';

import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:chataway_plus/core/snackbar/app_snackbar.dart';
import 'package:chataway_plus/core/themes/app_text_styles.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:flutter_native_video_trimmer/flutter_native_video_trimmer.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';

/// Video story preview and trimmer page
/// Allows users to preview and trim videos to max 30 seconds for stories
class VideoStoryPreviewPage extends StatefulWidget {
  const VideoStoryPreviewPage({
    super.key,
    required this.videoFile,
    required this.onConfirm,
  });

  final File videoFile;
  final void Function(File videoFile, File? thumbnailFile) onConfirm;

  @override
  State<VideoStoryPreviewPage> createState() => VideoStoryPreviewPageState();
}

/// State class made public to allow external access to loading control methods
class VideoStoryPreviewPageState extends State<VideoStoryPreviewPage> {
  VideoPlayerController? _playerController;
  bool _isInitialized = false;
  bool _isUploading = false;
  bool _isTrimming = false;
  bool _isPlaying = false;
  Duration _videoDuration = Duration.zero;
  bool _exceedsLimit = false;
  bool _previewUnavailable = false;
  File? _fallbackThumbnail;

  // Trim range (in seconds)
  double _trimStart = 0;
  double _trimEnd = 30;

  // Trimmed file (null until user trims)
  File? _trimmedFile;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      _playerController = VideoPlayerController.file(widget.videoFile);
      await _playerController!.initialize();

      if (!mounted) return;

      _onPlayerReady();
    } catch (e) {
      debugPrint('⚠️ File playback failed: $e');
      debugPrint('🔄 Trying content URI fallback...');

      // Fallback: try content URI (works better on some Android devices)
      _playerController?.dispose();
      _playerController = null;

      try {
        final uri = Uri.file(widget.videoFile.path);
        _playerController = VideoPlayerController.contentUri(uri);
        await _playerController!.initialize();

        if (!mounted) return;

        _onPlayerReady();
      } catch (e2) {
        debugPrint('⚠️ Content URI also failed: $e2');
        _playerController?.dispose();
        _playerController = null;

        if (!mounted) return;

        // Both playback methods failed — show static thumbnail preview
        // so user can still upload the video
        await _setupFallbackPreview();
      }
    }
  }

  /// Called when the video player initializes successfully
  void _onPlayerReady() {
    final dur = _playerController!.value.duration;
    setState(() {
      _videoDuration = dur;
      _exceedsLimit = dur.inSeconds > 30;
      _isInitialized = true;
      _isPlaying = true;
      _trimStart = 0;
      _trimEnd = dur.inSeconds > 30 ? 30 : dur.inSeconds.toDouble();
    });

    // Auto-play the video
    _playerController!.play();
    _playerController!.setLooping(true);
  }

  void _togglePlayPause() {
    if (_playerController == null || !_playerController!.value.isInitialized) {
      return;
    }

    setState(() {
      if (_playerController!.value.isPlaying) {
        _playerController!.pause();
        _isPlaying = false;
      } else {
        _playerController!.play();
        _isPlaying = true;
      }
    });
  }

  /// When video player can't play the file on this device,
  /// extract a thumbnail and show a static preview so the user can still upload.
  Future<void> _setupFallbackPreview() async {
    debugPrint('🖼️ Setting up fallback thumbnail preview');
    final thumb = await _extractThumbnail(widget.videoFile);

    if (!mounted) return;

    setState(() {
      _previewUnavailable = true;
      _fallbackThumbnail = thumb;
      _isInitialized = true;
      // We can't determine exact duration without the player,
      // so allow upload without trim enforcement
      _exceedsLimit = false;
    });

    AppSnackbar.showSuccess(
      context,
      'Video preview unavailable on this device, but you can still upload.',
    );
  }

  @override
  void dispose() {
    _playerController?.dispose();
    super.dispose();
  }

  /// Start upload - show loading state
  void startUpload() {
    if (mounted) {
      setState(() => _isUploading = true);
    }
  }

  /// End upload - hide loading state
  void endUpload() {
    if (mounted) {
      setState(() => _isUploading = false);
    }
  }

  /// Trim the video using native platform trimmer
  Future<void> _trimVideo() async {
    if (_isTrimming) return;

    final trimDuration = _trimEnd - _trimStart;
    if (trimDuration <= 0 || trimDuration > 30) {
      if (mounted) {
        AppSnackbar.showError(context, 'Select up to 30 seconds');
      }
      return;
    }

    setState(() => _isTrimming = true);

    try {
      final videoTrimmer = VideoTrimmer();
      await videoTrimmer.loadVideo(widget.videoFile.path);

      final startMs = (_trimStart * 1000).toInt();
      final endMs = (_trimEnd * 1000).toInt();

      debugPrint('✂️ Trimming video: ${startMs}ms → ${endMs}ms');

      final trimmedPath = await videoTrimmer.trimVideo(
        startTimeMs: startMs,
        endTimeMs: endMs,
        includeAudio: true,
      );

      if (!mounted) return;

      if (trimmedPath != null) {
        final trimmedFile = File(trimmedPath);
        if (await trimmedFile.exists()) {
          // Re-initialize player with trimmed video
          _playerController?.dispose();
          _playerController = null;

          try {
            _playerController = VideoPlayerController.file(trimmedFile);
            await _playerController!.initialize();
          } catch (e) {
            debugPrint('⚠️ Trimmed file playback failed: $e');
            _playerController?.dispose();
            _playerController = null;

            try {
              final uri = Uri.file(trimmedFile.path);
              _playerController = VideoPlayerController.contentUri(uri);
              await _playerController!.initialize();
            } catch (e2) {
              debugPrint('⚠️ Trimmed content URI also failed: $e2');
              _playerController?.dispose();
              _playerController = null;
            }
          }

          if (!mounted) return;

          setState(() {
            _trimmedFile = trimmedFile;
            _previewUnavailable = _playerController == null;
            if (_playerController != null) {
              _videoDuration = _playerController!.value.duration;
            }
            _exceedsLimit = false;
            _isTrimming = false;
          });

          if (_playerController != null) {
            _playerController!.play();
            _playerController!.setLooping(true);
          }

          AppSnackbar.showSuccess(
            context,
            'Video trimmed to ${_videoDuration.inSeconds}s',
          );
          return;
        }
      }

      // Trim failed
      debugPrint('❌ Native trim returned null or file missing');
      setState(() => _isTrimming = false);
      if (mounted) {
        AppSnackbar.showError(context, 'Failed to trim video. Try again.');
      }
    } catch (e) {
      debugPrint('❌ Trim error: $e');
      if (mounted) {
        setState(() => _isTrimming = false);
        AppSnackbar.showError(context, 'Failed to trim video');
      }
    }
  }

  void _handleConfirm() async {
    if (_isUploading) return;

    // If still exceeds limit (not trimmed yet), prompt to trim
    if (_exceedsLimit) {
      AppSnackbar.showError(
        context,
        'Please trim the video to 30 seconds or less first.',
      );
      return;
    }

    // Extract thumbnail before upload
    setState(() => _isUploading = true);
    final videoToUpload = _trimmedFile ?? widget.videoFile;
    final thumbnailFile = await _extractThumbnail(videoToUpload);
    if (!mounted) return;

    // Keep loading state true - the callback will handle upload and navigation
    widget.onConfirm(videoToUpload, thumbnailFile);
  }

  /// Extract thumbnail from video at 0.5 seconds
  Future<File?> _extractThumbnail(File videoFile) async {
    try {
      debugPrint('🎬 Extracting thumbnail from video...');
      final tempDir = await getTemporaryDirectory();
      final fileName = 'thumb_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final thumbnailPath = await VideoThumbnail.thumbnailFile(
        video: videoFile.path,
        thumbnailPath: '${tempDir.path}/$fileName',
        imageFormat: ImageFormat.JPEG,
        maxWidth: 480,
        quality: 80,
        timeMs: 500, // 0.5 seconds into video
      );

      if (thumbnailPath != null) {
        debugPrint('✅ Thumbnail extracted: $thumbnailPath');
        return File(thumbnailPath);
      } else {
        debugPrint('⚠️ Thumbnail extraction returned null');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Thumbnail extraction error: $e');
      return null;
    }
  }

  String _formatSeconds(double seconds) {
    final mins = seconds.toInt() ~/ 60;
    final secs = seconds.toInt() % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
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

          if (!_isInitialized) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            );
          }

          return Stack(
            children: [
              SafeArea(
                child: Column(
                  children: [
                    _buildTopBar(responsive),
                    Expanded(child: _buildVideoPreview(responsive)),
                    _buildBottomBar(responsive),
                  ],
                ),
              ),
              // Upload loading overlay
              if (_isUploading)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.8),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.primary,
                            ),
                          ),
                          SizedBox(height: responsive.spacing(16)),
                          Text(
                            'Uploading story...',
                            style: AppTextSizes.regular(context).copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTopBar(ResponsiveSize responsive) {
    final statusText = _previewUnavailable
        ? 'Ready to upload'
        : _exceedsLimit
        ? '${_videoDuration.inSeconds}s - Trim to 30s or less'
        : '${_videoDuration.inSeconds}s - Ready to upload';

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: responsive.spacing(8),
        vertical: responsive.spacing(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Story Video',
                  style: AppTextSizes.regular(
                    context,
                  ).copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                ),
                Text(
                  statusText,
                  style: AppTextSizes.small(context).copyWith(
                    color: _previewUnavailable
                        ? Colors.green
                        : _exceedsLimit
                        ? Colors.orange
                        : Colors.green,
                    fontSize: responsive.size(12),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (!_previewUnavailable &&
              _playerController != null &&
              _playerController!.value.isInitialized)
            IconButton(
              onPressed: _togglePlayPause,
              icon: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
              ),
            ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPreview(ResponsiveSize responsive) {
    // Fallback: show static thumbnail when video player can't play on this device
    if (_previewUnavailable) {
      return Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_fallbackThumbnail != null)
              Image.file(
                _fallbackThumbnail!,
                fit: BoxFit.contain,
                width: double.infinity,
                height: double.infinity,
              )
            else
              Container(color: Colors.black),
            // Overlay indicating preview unavailable
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: responsive.spacing(16),
                vertical: responsive.spacing(8),
              ),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(responsive.size(8)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.videocam_outlined,
                    color: Colors.white70,
                    size: responsive.size(40),
                  ),
                  SizedBox(height: responsive.spacing(8)),
                  Text(
                    'Preview not available on this device',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: responsive.size(13),
                    ),
                  ),
                  SizedBox(height: responsive.spacing(4)),
                  Text(
                    'You can still upload this video',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: responsive.size(11),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (_playerController == null || !_playerController!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Center(
      child: AspectRatio(
        aspectRatio: _playerController!.value.aspectRatio,
        child: GestureDetector(
          onTap: _togglePlayPause,
          behavior: HitTestBehavior.opaque,
          child: VideoPlayer(_playerController!),
        ),
      ),
    );
  }

  Widget _buildTrimControls(ResponsiveSize responsive) {
    final totalSeconds = _videoDuration.inSeconds.toDouble();
    if (totalSeconds <= 0) return const SizedBox.shrink();

    final selectedDuration = (_trimEnd - _trimStart).toStringAsFixed(1);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: responsive.spacing(16),
        vertical: responsive.spacing(8),
      ),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((0.08 * 255).round()),
        borderRadius: BorderRadius.circular(responsive.size(12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Trim: ${_formatSeconds(_trimStart)} - ${_formatSeconds(_trimEnd)}',
                style: AppTextSizes.small(
                  context,
                ).copyWith(color: Colors.white, fontWeight: FontWeight.w500),
              ),
              Text(
                '${selectedDuration}s selected',
                style: AppTextSizes.small(context).copyWith(
                  color: (_trimEnd - _trimStart) <= 30
                      ? Colors.green
                      : Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: responsive.spacing(4)),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: Colors.white24,
              thumbColor: AppColors.primary,
              overlayColor: AppColors.primary.withAlpha((0.2 * 255).round()),
              rangeThumbShape: RoundRangeSliderThumbShape(
                enabledThumbRadius: responsive.size(8),
              ),
              trackHeight: responsive.size(4),
            ),
            child: RangeSlider(
              values: RangeValues(_trimStart, _trimEnd),
              min: 0,
              max: totalSeconds,
              divisions: totalSeconds.toInt().clamp(1, 1000),
              labels: RangeLabels(
                _formatSeconds(_trimStart),
                _formatSeconds(_trimEnd),
              ),
              onChanged: (values) {
                double start = values.start;
                double end = values.end;

                // Enforce max 30 second selection
                if (end - start > 30) {
                  // Determine which thumb moved
                  if ((start - _trimStart).abs() > (end - _trimEnd).abs()) {
                    // Start thumb moved — clamp end
                    end = start + 30;
                    if (end > totalSeconds) {
                      end = totalSeconds;
                      start = end - 30;
                    }
                  } else {
                    // End thumb moved — clamp start
                    start = end - 30;
                    if (start < 0) {
                      start = 0;
                      end = 30;
                    }
                  }
                }

                setState(() {
                  _trimStart = start;
                  _trimEnd = end;
                });

                // Seek to trim start for preview
                _playerController?.seekTo(
                  Duration(milliseconds: (start * 1000).toInt()),
                );
              },
            ),
          ),
          SizedBox(height: responsive.spacing(4)),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isTrimming ? null : _trimVideo,
              icon: _isTrimming
                  ? SizedBox(
                      width: responsive.size(16),
                      height: responsive.size(16),
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(Icons.content_cut_rounded, size: responsive.size(18)),
              label: Text(
                _isTrimming ? 'Trimming...' : 'Trim Video',
                style: AppTextSizes.regular(
                  context,
                ).copyWith(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: AppColors.primary.withAlpha(
                  (0.6 * 255).round(),
                ),
                padding: EdgeInsets.symmetric(vertical: responsive.spacing(12)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(responsive.size(10)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(ResponsiveSize responsive) {
    return Container(
      padding: EdgeInsets.all(responsive.spacing(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_exceedsLimit) ...[
            _buildTrimControls(responsive),
            SizedBox(height: responsive.spacing(12)),
          ],
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: !_exceedsLimit ? _handleConfirm : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: Colors.grey,
                    padding: EdgeInsets.symmetric(
                      vertical: responsive.spacing(16),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(responsive.size(12)),
                    ),
                  ),
                  child: Text(
                    _exceedsLimit ? 'Trim First' : 'Upload Story',
                    style: AppTextSizes.regular(context).copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
