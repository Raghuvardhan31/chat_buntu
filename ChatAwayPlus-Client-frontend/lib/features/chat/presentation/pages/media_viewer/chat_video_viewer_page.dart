import 'dart:io';

import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:chataway_plus/core/themes/app_text_styles.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/features/chat/models/chat_message_model.dart';
import 'package:chataway_plus/features/chat/utils/chat_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:video_player/video_player.dart';

class ChatVideoViewerPage extends StatefulWidget {
  const ChatVideoViewerPage({
    super.key,
    required this.message,
    required this.isMe,
    required this.otherUserName,
    required this.videoPath,
  });

  final ChatMessageModel message;
  final bool isMe;
  final String otherUserName;
  final String videoPath;

  @override
  State<ChatVideoViewerPage> createState() => _ChatVideoViewerPageState();
}

class _ChatVideoViewerPageState extends State<ChatVideoViewerPage> {
  late VideoPlayerController _controller;
  bool _showOverlays = true;
  bool _isSaving = false;
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    _controller = VideoPlayerController.file(File(widget.videoPath));
    try {
      await _controller.initialize();
      _controller.addListener(_onPlayerUpdate);
      if (mounted) {
        setState(() => _isInitialized = true);
        _controller.play();
      }
    } catch (e) {
      debugPrint('❌ Video player init error: $e');
      if (mounted) setState(() => _hasError = true);
    }
  }

  void _onPlayerUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onPlayerUpdate);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveToGallery() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final file = File(widget.videoPath);
      if (await file.exists()) {
        await Gal.putVideo(widget.videoPath, album: 'ChatAway+ Videos');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Saved to gallery'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        throw Exception('Video file not found');
      }
    } catch (e) {
      debugPrint('❌ Failed to save video: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save video'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }

    if (mounted) setState(() => _isSaving = false);
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
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
                onTap: () {
                  if (_showOverlays) {
                    setState(() => _showOverlays = false);
                  } else {
                    setState(() => _showOverlays = true);
                  }
                },
                onLongPress: () {
                  if (_showOverlays) {
                    setState(() => _showOverlays = false);
                  }
                },
                child: Stack(
                  children: [
                    // ----- VIDEO PLAYER -----
                    Positioned.fill(
                      child: Center(
                        child: _hasError
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    color: Colors.white54,
                                    size: responsive.size(64),
                                  ),
                                  SizedBox(height: responsive.spacing(12)),
                                  Text(
                                    'Failed to play video',
                                    style: AppTextSizes.regular(
                                      context,
                                    ).copyWith(color: Colors.white54),
                                  ),
                                ],
                              )
                            : _isInitialized
                            ? AspectRatio(
                                aspectRatio: _controller.value.aspectRatio,
                                child: VideoPlayer(_controller),
                              )
                            : CircularProgressIndicator(
                                color: AppColors.primary,
                                strokeWidth: responsive.size(3),
                              ),
                      ),
                    ),

                    // ----- PLAY/PAUSE CENTER BUTTON -----
                    if (_isInitialized && _showOverlays)
                      Positioned.fill(
                        child: Center(
                          child: GestureDetector(
                            onTap: () {
                              if (_controller.value.isPlaying) {
                                _controller.pause();
                              } else {
                                _controller.play();
                              }
                            },
                            child: Container(
                              width: responsive.size(64),
                              height: responsive.size(64),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black.withValues(alpha: 0.5),
                              ),
                              child: Icon(
                                _controller.value.isPlaying
                                    ? Icons.pause
                                    : Icons.play_arrow,
                                color: Colors.white,
                                size: responsive.size(36),
                              ),
                            ),
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

                    // ----- BOTTOM CONTROLS (progress bar + back button) -----
                    if (_showOverlays && _isInitialized)
                      Positioned(
                        left: responsive.spacing(14),
                        right: responsive.spacing(14),
                        bottom: responsive.spacing(16),
                        child: Row(
                          children: [
                            // Current time
                            Text(
                              _formatDuration(_controller.value.position),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: responsive.size(12),
                              ),
                            ),
                            SizedBox(width: responsive.spacing(8)),
                            // Progress bar
                            Expanded(
                              child: VideoProgressIndicator(
                                _controller,
                                allowScrubbing: true,
                                colors: VideoProgressColors(
                                  playedColor: AppColors.primary,
                                  bufferedColor: Colors.white24,
                                  backgroundColor: Colors.white12,
                                ),
                              ),
                            ),
                            SizedBox(width: responsive.spacing(8)),
                            // Total time
                            Text(
                              _formatDuration(_controller.value.duration),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: responsive.size(12),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // ----- BACK BUTTON -----
                    if (_showOverlays)
                      Positioned(
                        right: responsive.spacing(16),
                        bottom: _isInitialized
                            ? responsive.spacing(56)
                            : responsive.spacing(16),
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
}
