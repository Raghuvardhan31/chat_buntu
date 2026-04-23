import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/core/constants/api_url/api_urls.dart';
import 'package:chataway_plus/features/chat/models/chat_message_model.dart';
import 'package:chataway_plus/features/chat/data/media/media_cache_service.dart';
import 'package:chataway_plus/features/chat/presentation/widgets/chat_ui/message_delivery_status_icon.dart';
import 'package:chataway_plus/features/chat/utils/chat_helper.dart';

class AudioMessageBubble extends StatefulWidget {
  const AudioMessageBubble({
    super.key,
    required this.message,
    required this.isSender,
    this.uploadProgress,
    this.onRetry,
  });

  final ChatMessageModel message;
  final bool isSender;
  final double? uploadProgress;
  final VoidCallback? onRetry;

  @override
  State<AudioMessageBubble> createState() => _AudioMessageBubbleState();
}

class _AudioMessageBubbleState extends State<AudioMessageBubble> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  String? _resolvedAudioPath;
  bool _isDisposed = false;

  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<void>? _completeSub;

  @override
  void initState() {
    super.initState();
    _initDuration();
    _resolveAudioSource();

    _playerStateSub = _audioPlayer.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() {
        _isPlaying = state == PlayerState.playing;
      });
    });

    _durationSub = _audioPlayer.onDurationChanged.listen((d) {
      if (!mounted) return;
      setState(() => _duration = d);
    });

    _positionSub = _audioPlayer.onPositionChanged.listen((p) {
      if (!mounted) return;
      setState(() => _position = p);
    });

    _completeSub = _audioPlayer.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _isPlaying = false;
        _position = Duration.zero;
      });
    });
  }

  void _initDuration() {
    final dur = widget.message.audioDuration;
    if (dur != null && dur > 0) {
      _duration = Duration(milliseconds: (dur * 1000).round());
    }
  }

  Future<void> _resolveAudioSource() async {
    // Check local path first
    final localPath = widget.message.localImagePath;
    if (localPath != null && localPath.isNotEmpty) {
      final file = File(localPath);
      if (await file.exists()) {
        _resolvedAudioPath = localPath;
        return;
      }
    }

    // Check cache
    final cachedPath = await MediaCacheService.instance.getCachedFile(
      widget.message.id,
    );
    if (cachedPath != null) {
      _resolvedAudioPath = cachedPath;
    }
  }

  Future<void> _togglePlayPause() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_position > Duration.zero && _position < _duration) {
        await _audioPlayer.resume();
      } else {
        // Try local/cached path first
        if (_resolvedAudioPath != null) {
          await _audioPlayer.play(DeviceFileSource(_resolvedAudioPath!));
        } else {
          // Download and cache, then play
          final fileUrl = widget.message.imageUrl;
          if (fileUrl == null || fileUrl.isEmpty) {
            debugPrint('❌ No audio URL available');
            return;
          }

          final cachedPath = await MediaCacheService.instance
              .downloadAndCacheFile(
                messageId: widget.message.id,
                fileUrl: fileUrl,
                messageType: 'audio',
              );

          if (cachedPath != null) {
            _resolvedAudioPath = cachedPath;
            await _audioPlayer.play(DeviceFileSource(cachedPath));
          } else {
            // Fallback: stream from server
            final uri = fileUrl.startsWith('http')
                ? fileUrl
                : '${ApiUrls.apiBaseUrl}/chats/file/$fileUrl';
            await _audioPlayer.play(UrlSource(uri));
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Audio playback error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '${minutes.toString().padLeft(1, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _safeSeek(Duration position) {
    if (_isDisposed) return;
    if (_duration.inMilliseconds <= 0) return;

    final clamped = position < Duration.zero
        ? Duration.zero
        : (position > _duration ? _duration : position);

    try {
      _audioPlayer.seek(clamped).catchError((e, _) {
        debugPrint('❌ Audio seek error: $e');
      });
    } catch (e) {
      debugPrint('❌ Audio seek error: $e');
    }
  }

  @override
  void dispose() {
    _isDisposed = true;

    _playerStateSub?.cancel();
    _durationSub?.cancel();
    _positionSub?.cancel();
    _completeSub?.cancel();

    try {
      _audioPlayer.stop().catchError((_) {});
    } catch (_) {}

    _audioPlayer.dispose();
    super.dispose();
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

        final isSending = widget.message.messageStatus == 'sending';
        final isFailed = widget.message.messageStatus == 'failed';
        final showProgress = widget.uploadProgress != null && isSending;

        final isDark = Theme.of(context).brightness == Brightness.dark;

        final iconColor = widget.isSender
            ? (isDark ? Colors.white : AppColors.primary)
            : (isDark ? Colors.white : AppColors.iconPrimary);

        final textColor = widget.isSender
            ? (isDark ? Colors.white70 : Colors.grey[700]!)
            : (isDark ? Colors.white60 : Colors.grey[600]!);

        final sliderActiveColor = widget.isSender
            ? AppColors.primary
            : AppColors.primary;

        final sliderInactiveColor = widget.isSender
            ? (isDark ? Colors.white24 : Colors.grey[300]!)
            : (isDark ? Colors.white24 : Colors.grey[300]!);

        final displayDuration = _isPlaying || _position > Duration.zero
            ? _position
            : _duration;

        return Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.72,
            minWidth: responsive.size(200),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: responsive.spacing(10),
            vertical: responsive.spacing(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Play/Pause button
                  if (isFailed)
                    GestureDetector(
                      onTap: widget.onRetry,
                      child: Container(
                        width: responsive.size(40),
                        height: responsive.size(40),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.refresh,
                          color: Colors.red,
                          size: responsive.size(22),
                        ),
                      ),
                    )
                  else if (showProgress)
                    SizedBox(
                      width: responsive.size(40),
                      height: responsive.size(40),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: widget.uploadProgress,
                            strokeWidth: 2.5,
                            color: iconColor,
                            backgroundColor: sliderInactiveColor,
                          ),
                          Icon(
                            Icons.mic,
                            color: iconColor,
                            size: responsive.size(18),
                          ),
                        ],
                      ),
                    )
                  else
                    GestureDetector(
                      onTap: _isLoading ? null : _togglePlayPause,
                      child: Container(
                        width: responsive.size(40),
                        height: responsive.size(40),
                        decoration: BoxDecoration(
                          color: widget.isSender
                              ? (isDark
                                    ? Colors.white.withValues(alpha: 0.15)
                                    : AppColors.primary.withValues(alpha: 0.15))
                              : (isDark
                                    ? Colors.white.withValues(alpha: 0.1)
                                    : AppColors.primary.withValues(alpha: 0.1)),
                          shape: BoxShape.circle,
                        ),
                        child: _isLoading
                            ? Padding(
                                padding: EdgeInsets.all(responsive.size(10)),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: iconColor,
                                ),
                              )
                            : Icon(
                                _isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: iconColor,
                                size: responsive.size(24),
                              ),
                      ),
                    ),

                  SizedBox(width: responsive.spacing(8)),

                  // Seekbar + duration
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SliderTheme(
                          data: SliderThemeData(
                            trackHeight: responsive.size(3),
                            thumbShape: RoundSliderThumbShape(
                              enabledThumbRadius: responsive.size(5),
                            ),
                            overlayShape: RoundSliderOverlayShape(
                              overlayRadius: responsive.size(12),
                            ),
                            activeTrackColor: sliderActiveColor,
                            inactiveTrackColor: sliderInactiveColor,
                            thumbColor: sliderActiveColor,
                          ),
                          child: Slider(
                            value: _duration.inMilliseconds > 0
                                ? (_position.inMilliseconds /
                                          _duration.inMilliseconds)
                                      .clamp(0.0, 1.0)
                                : 0.0,
                            onChanged: (value) {
                              if (_duration.inMilliseconds > 0) {
                                final newPosition = Duration(
                                  milliseconds:
                                      (value * _duration.inMilliseconds)
                                          .round(),
                                );
                                _safeSeek(newPosition);
                              }
                            },
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: responsive.spacing(4),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatDuration(displayDuration),
                                style: TextStyle(
                                  fontSize: responsive.size(11),
                                  color: textColor,
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    ChatHelper.formatMessageTime(
                                      widget.message.createdAt,
                                    ),
                                    style: TextStyle(
                                      fontSize: responsive.size(10),
                                      color: textColor,
                                    ),
                                  ),
                                  if (widget.isSender) ...[
                                    SizedBox(width: responsive.spacing(3)),
                                    MessageDeliveryStatusIcon(
                                      status: widget.message.messageStatus,
                                      size: responsive.size(14),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
