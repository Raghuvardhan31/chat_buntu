import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:chataway_plus/core/constants/api_url/api_urls.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:chataway_plus/core/sync/authenticated_image_cache_manager.dart';
import 'package:chataway_plus/core/storage/token_storage.dart';

/// Video player widget for story video slides
/// Downloads and caches video files locally for instant playback.
/// Only shows loading indicator on first download or poor network.
class StoryVideoPlayer extends StatefulWidget {
  const StoryVideoPlayer({
    super.key,
    required this.videoUrl,
    required this.responsive,
    this.thumbnailUrl,
    this.onVideoInitialized,
    this.onVideoError,
  });

  final String videoUrl;
  final String? thumbnailUrl;
  final ResponsiveSize responsive;

  /// Called when video is initialized with its actual duration
  final ValueChanged<Duration>? onVideoInitialized;

  /// Called when video fails to load
  final VoidCallback? onVideoError;

  @override
  State<StoryVideoPlayer> createState() => _StoryVideoPlayerState();
}

class _StoryVideoPlayerState extends State<StoryVideoPlayer> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _isDownloading = false;
  bool _showVideo = false;
  int _retryCount = 0;
  bool _filePlaybackFailed = false;
  static const int _maxRetries = 3;
  static const int _minVideoFileSize = 1024;

  @override
  void initState() {
    super.initState();
    debugPrint('🎬 StoryVideoPlayer: thumbnailUrl=${widget.thumbnailUrl}');
    _initializeVideo();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _scheduleShowVideo(VideoPlayerController controller) async {
    await Future.delayed(const Duration(milliseconds: 220));
    if (!mounted) return;
    if (_controller != controller) return;
    setState(() => _showVideo = true);
  }

  Future<void> _initializeVideo() async {
    try {
      final fullUrl = _buildFullUrl(widget.videoUrl);
      debugPrint(
        '🎬 StoryVideoPlayer: Loading video (attempt ${_retryCount + 1}/$_maxRetries)',
      );
      debugPrint('   URL: $fullUrl');

      // If file-based playback already failed with a codec error,
      // skip file download and go straight to network streaming
      if (_filePlaybackFailed) {
        debugPrint(
          '   🌐 Using network streaming (file playback failed previously)',
        );
        await _initializeFromNetwork(fullUrl);
        return;
      }

      // 1. Try to get the video from local cache first (instant playback)
      File? localFile;
      try {
        final cachedFile = await AuthenticatedImageCacheManager.instance
            .getFileFromCache(fullUrl);
        if (cachedFile?.file != null) {
          final f = File(cachedFile!.file.path);
          final size = await f.length();
          if (size >= _minVideoFileSize) {
            localFile = f;
            debugPrint('   ✅ Cache hit: $size bytes');
          } else {
            debugPrint('   ⚠️ Cache has corrupt file (${size}B), removing');
            await AuthenticatedImageCacheManager.instance.removeFile(fullUrl);
          }
        }
      } catch (_) {}

      // 2. If not cached, download and cache the video
      if (localFile == null) {
        if (mounted) setState(() => _isDownloading = true);

        try {
          final fileInfo = await AuthenticatedImageCacheManager.instance
              .downloadFile(fullUrl);
          final f = File(fileInfo.file.path);
          final size = await f.length();
          if (size >= _minVideoFileSize) {
            localFile = f;
            debugPrint('   ✅ Downloaded: $size bytes');
          } else {
            debugPrint(
              '   ⚠️ Downloaded file too small (${size}B), discarding',
            );
            await AuthenticatedImageCacheManager.instance.removeFile(fullUrl);
            localFile = null;
          }
        } catch (e) {
          debugPrint('   ⚠️ Download failed: $e');
          try {
            await AuthenticatedImageCacheManager.instance.removeFile(fullUrl);
          } catch (_) {}
          localFile = null;
        }
      }

      if (!mounted) return;

      // 3. If we have no valid file, try network streaming directly
      if (localFile == null || !await localFile.exists()) {
        debugPrint('   🌐 No local file, trying network streaming');
        await _initializeFromNetwork(fullUrl);
        return;
      }

      // 4. Play from local file
      try {
        final controller = VideoPlayerController.file(localFile);
        _controller = controller;

        await controller.initialize();

        if (!mounted) return;

        controller.setLooping(false);
        controller.play();

        setState(() {
          _isInitialized = true;
          _isDownloading = false;
          _showVideo = false;
        });

        _scheduleShowVideo(controller);

        widget.onVideoInitialized?.call(controller.value.duration);
      } catch (e) {
        // File playback failed (likely MediaCodec error) — fallback to network
        debugPrint('   ⚠️ File playback failed: $e');
        debugPrint('   🌐 Falling back to network streaming');
        _controller?.dispose();
        _controller = null;
        _filePlaybackFailed = true;
        await _initializeFromNetwork(fullUrl);
      }
    } catch (e) {
      debugPrint('❌ StoryVideoPlayer: Error initializing video: $e');

      if (_retryCount < _maxRetries && mounted) {
        _retryCount++;
        _controller?.dispose();
        _controller = null;
        _showVideo = false;

        final delay = Duration(seconds: _retryCount + 1);
        debugPrint(
          '🔄 StoryVideoPlayer: Retry $_retryCount/$_maxRetries in ${delay.inSeconds}s',
        );
        await Future.delayed(delay);
        if (mounted) {
          _initializeVideo();
        }
        return;
      }

      if (mounted) {
        setState(() {
          _hasError = true;
          _isDownloading = false;
          _showVideo = false;
        });
        widget.onVideoError?.call();
      }
    }
  }

  /// Fallback: stream video directly from network with auth headers
  Future<void> _initializeFromNetwork(String fullUrl) async {
    try {
      final token = await _getAuthToken();
      final headers = <String, String>{
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final controller = VideoPlayerController.networkUrl(
        Uri.parse(fullUrl),
        httpHeaders: headers,
      );
      _controller = controller;

      if (mounted) setState(() => _isDownloading = true);

      await controller.initialize();

      if (!mounted) return;

      controller.setLooping(false);
      controller.play();

      setState(() {
        _isInitialized = true;
        _isDownloading = false;
        _showVideo = false;
      });

      _scheduleShowVideo(controller);

      debugPrint('   ✅ Network streaming initialized');
      widget.onVideoInitialized?.call(controller.value.duration);
    } catch (e) {
      debugPrint('   ❌ Network streaming failed: $e');
      // Re-throw to trigger retry logic in caller
      throw Exception('Network streaming failed: $e');
    }
  }

  Future<String?> _getAuthToken() async {
    try {
      return await TokenSecureStorage.instance.getToken();
    } catch (_) {
      return null;
    }
  }

  String _buildFullUrl(String url) {
    final raw = url.trim();
    if (raw.isEmpty) return raw;

    String normalize(String input) {
      const prefix = '/api/images/stream/';
      final hadLeadingSlash = input.startsWith('/');
      final withoutLeadingSlash = hadLeadingSlash ? input.substring(1) : input;

      // Plain key case: dev.chatawayplus/stories/... -> stories/...
      if (withoutLeadingSlash.startsWith('dev.chatawayplus/')) {
        final stripped = withoutLeadingSlash.substring(
          'dev.chatawayplus/'.length,
        );
        return hadLeadingSlash ? '/$stripped' : stripped;
      }
      if (withoutLeadingSlash.startsWith('chatawayplus/')) {
        final stripped = withoutLeadingSlash.substring('chatawayplus/'.length);
        return hadLeadingSlash ? '/$stripped' : stripped;
      }

      final firstSlash = withoutLeadingSlash.indexOf('/');
      if (firstSlash > 0) {
        final firstSeg = withoutLeadingSlash.substring(0, firstSlash);
        final rest = withoutLeadingSlash.substring(firstSlash + 1);
        if (firstSeg.contains('.') && rest.startsWith('stories/')) {
          return hadLeadingSlash ? '/$rest' : rest;
        }
      }

      if (!input.contains(prefix)) return input;

      final idx = input.indexOf(prefix);
      if (idx == -1) return input;
      final before = input.substring(0, idx + prefix.length);
      final after = input.substring(idx + prefix.length);

      if (after.startsWith('dev.chatawayplus/')) {
        return before + after.substring('dev.chatawayplus/'.length);
      }
      if (after.startsWith('chatawayplus/')) {
        return before + after.substring('chatawayplus/'.length);
      }
      return input;
    }

    final normalized = normalize(raw);
    if (normalized.startsWith('http://') || normalized.startsWith('https://')) {
      return normalized;
    }
    if (normalized.startsWith('/')) {
      if (normalized.startsWith('/api/') ||
          normalized.startsWith('/uploads/')) {
        return '${ApiUrls.mediaBaseUrl}$normalized';
      }
      return '${ApiUrls.mediaBaseUrl}/api/images/stream/${normalized.substring(1)}';
    }
    if (normalized.startsWith('api/') || normalized.startsWith('uploads/')) {
      return '${ApiUrls.mediaBaseUrl}/$normalized';
    }
    return '${ApiUrls.mediaBaseUrl}/api/images/stream/$normalized';
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return GestureDetector(
        onTap: () {
          // Manual retry
          setState(() {
            _hasError = false;
            _retryCount = 0;
          });
          _initializeVideo();
        },
        child: Container(
          color: Colors.black,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.videocam_off_outlined,
                  size: widget.responsive.size(48),
                  color: Colors.white70,
                ),
                SizedBox(height: widget.responsive.spacing(12)),
                Text(
                  'Unable to play video',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: widget.responsive.size(14),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: widget.responsive.spacing(4)),
                Text(
                  'Tap to retry',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: widget.responsive.size(12),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final thumbUrl = widget.thumbnailUrl;
    final hasThumb = thumbUrl != null && thumbUrl.isNotEmpty;
    final fullThumbUrl = hasThumb ? _buildFullUrl(thumbUrl) : null;

    if (!_isInitialized || _controller == null) {
      // Show thumbnail as preview while video loads (instead of black screen)
      return Stack(
        fit: StackFit.expand,
        children: [
          Container(color: Colors.black),
          if (fullThumbUrl != null)
            Center(
              child: CachedNetworkImage(
                imageUrl: fullThumbUrl,
                cacheManager: AuthenticatedImageCacheManager.instance,
                fit: BoxFit.contain,
                placeholder: (_, __) => const SizedBox.shrink(),
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          // Loading overlay
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  strokeWidth: widget.responsive.size(2),
                  color: Colors.white,
                ),
                if (_isDownloading) ...[
                  SizedBox(height: widget.responsive.spacing(12)),
                  Text(
                    'Loading video...',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: widget.responsive.size(14),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    }

    final controller = _controller!;

    final size = controller.value.size;
    final hasValidSize = size.width > 0 && size.height > 0;
    final videoChild = _showVideo && hasValidSize
        ? FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: VideoPlayer(controller),
            ),
          )
        : null;

    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: Colors.black),
        if (videoChild == null && fullThumbUrl != null)
          Center(
            child: CachedNetworkImage(
              imageUrl: fullThumbUrl,
              cacheManager: AuthenticatedImageCacheManager.instance,
              fit: BoxFit.contain,
              placeholder: (_, __) => const SizedBox.shrink(),
              errorWidget: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        if (videoChild != null) Center(child: videoChild),
      ],
    );
  }
}
