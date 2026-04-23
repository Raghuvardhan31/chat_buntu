import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';

/// WhatsApp / Telegram-style audio confirmation card.
///
/// Shown after the user finishes recording. Displays:
/// - Play / pause toggle
/// - Animated waveform bars (simulated)
/// - Duration label
/// - Delete (cancel) and Send buttons
///
/// Positioned above the keyboard (when open) or above the input field.
class AudioConfirmationWidget extends StatefulWidget {
  const AudioConfirmationWidget({
    super.key,
    required this.responsive,
    required this.isDark,
    required this.recordedDurationSeconds,
    required this.onCancel,
    required this.onSend,
    this.audioFilePath,
  });

  final ResponsiveSize responsive;
  final bool isDark;
  final int recordedDurationSeconds;
  final VoidCallback onCancel;
  final VoidCallback onSend;
  final String? audioFilePath;

  @override
  State<AudioConfirmationWidget> createState() =>
      _AudioConfirmationWidgetState();
}

class _AudioConfirmationWidgetState extends State<AudioConfirmationWidget>
    with SingleTickerProviderStateMixin {
  bool _isPlaying = false;
  int _playbackSeconds = 0;
  Timer? _playbackTimer;
  late AnimationController _waveController;
  AudioPlayer? _audioPlayer;

  // Simulated waveform bar heights (0.0 – 1.0)
  late final List<double> _waveformBars;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    // Generate random waveform bars for visual representation
    final rng = math.Random(42);
    _waveformBars = List.generate(28, (_) => 0.15 + rng.nextDouble() * 0.85);

    // Set up real audio player if file path is available
    if (widget.audioFilePath != null && widget.audioFilePath!.isNotEmpty) {
      _audioPlayer = AudioPlayer();
      _audioPlayer!.onPlayerStateChanged.listen((state) {
        if (!mounted) return;
        setState(() => _isPlaying = state == PlayerState.playing);
      });
      _audioPlayer!.onPositionChanged.listen((pos) {
        if (!mounted) return;
        setState(() => _playbackSeconds = pos.inSeconds);
      });
      _audioPlayer!.onPlayerComplete.listen((_) {
        if (!mounted) return;
        setState(() {
          _isPlaying = false;
          _playbackSeconds = 0;
        });
      });
    }
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    _audioPlayer?.stop();
    _audioPlayer?.dispose();
    _waveController.dispose();
    super.dispose();
  }

  void _togglePlayback() {
    if (_audioPlayer != null) {
      _toggleRealPlayback();
    } else {
      _toggleSimulatedPlayback();
    }
  }

  Future<void> _toggleRealPlayback() async {
    if (_isPlaying) {
      await _audioPlayer!.pause();
    } else {
      try {
        await _audioPlayer!.play(DeviceFileSource(widget.audioFilePath!));
      } catch (e) {
        debugPrint('❌ Audio preview playback error: $e');
      }
    }
  }

  void _toggleSimulatedPlayback() {
    if (_isPlaying) {
      _playbackTimer?.cancel();
      setState(() => _isPlaying = false);
    } else {
      setState(() => _isPlaying = true);
      _playbackTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        if (_playbackSeconds >= widget.recordedDurationSeconds) {
          _playbackTimer?.cancel();
          setState(() {
            _isPlaying = false;
            _playbackSeconds = 0;
          });
        } else {
          setState(() => _playbackSeconds++);
        }
      });
    }
  }

  String _formatDuration(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  double get _progress {
    if (widget.recordedDurationSeconds <= 0) return 0;
    return _playbackSeconds / widget.recordedDurationSeconds;
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.responsive;
    final isDark = widget.isDark;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: r.spacing(6),
        vertical: r.spacing(10),
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2C34) : Colors.white,
        borderRadius: BorderRadius.circular(r.size(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(
              isDark ? (0.25 * 255).round() : (0.08 * 255).round(),
            ),
            blurRadius: r.size(10),
            offset: Offset(0, r.spacing(2)),
          ),
        ],
      ),
      child: Row(
        children: [
          // ── Delete / Cancel button ──
          _ActionCircle(
            onTap: widget.onCancel,
            size: r.size(42),
            backgroundColor: isDark
                ? Colors.red.shade900.withAlpha((0.3 * 255).round())
                : Colors.red.shade50,
            icon: Icons.delete_rounded,
            iconColor: isDark ? Colors.red.shade300 : Colors.red.shade400,
            iconSize: r.size(20),
          ),

          SizedBox(width: r.spacing(5)),

          // ── Play / Pause button ──
          GestureDetector(
            onTap: _togglePlayback,
            child: Container(
              width: r.size(34),
              height: r.size(34),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary,
              ),
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  transitionBuilder: (child, anim) =>
                      ScaleTransition(scale: anim, child: child),
                  child: Icon(
                    _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    key: ValueKey<bool>(_isPlaying),
                    color: Colors.white,
                    size: r.size(16),
                  ),
                ),
              ),
            ),
          ),

          SizedBox(width: r.spacing(5)),

          // ── Waveform + duration ──
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: r.size(18),
                  child: AnimatedBuilder(
                    animation: _waveController,
                    builder: (context, _) {
                      return CustomPaint(
                        size: Size(double.infinity, r.size(18)),
                        painter: _WaveformPainter(
                          bars: _waveformBars,
                          progress: _progress,
                          activeColor: AppColors.primary,
                          inactiveColor: isDark
                              ? Colors.white24
                              : Colors.grey.shade300,
                          animValue: _isPlaying ? _waveController.value : 0.0,
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(height: r.spacing(0)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(_playbackSeconds),
                      style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.grey.shade500,
                        fontSize: r.size(8.5),
                        fontWeight: FontWeight.w500,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      _formatDuration(widget.recordedDurationSeconds),
                      style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.grey.shade500,
                        fontSize: r.size(8.5),
                        fontWeight: FontWeight.w500,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          SizedBox(width: r.spacing(5)),

          // ── Send button ──
          _ActionCircle(
            onTap: widget.onSend,
            size: r.size(42),
            backgroundColor: AppColors.primary,
            icon: Icons.send_rounded,
            iconColor: Colors.white,
            iconSize: r.size(20),
            shadow: BoxShadow(
              color: AppColors.primary.withAlpha((0.3 * 255).round()),
              blurRadius: r.size(6),
              offset: Offset(0, r.spacing(2)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact circular action button used for cancel and send
class _ActionCircle extends StatelessWidget {
  const _ActionCircle({
    required this.onTap,
    required this.size,
    required this.backgroundColor,
    required this.icon,
    required this.iconColor,
    required this.iconSize,
    this.shadow,
  });

  final VoidCallback onTap;
  final double size;
  final Color backgroundColor;
  final IconData icon;
  final Color iconColor;
  final double iconSize;
  final BoxShadow? shadow;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: backgroundColor,
          boxShadow: shadow != null ? [shadow!] : null,
        ),
        child: Center(
          child: Icon(icon, color: iconColor, size: iconSize),
        ),
      ),
    );
  }
}

/// Custom painter for waveform bars with progress indicator
class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.bars,
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
    required this.animValue,
  });

  final List<double> bars;
  final double progress;
  final Color activeColor;
  final Color inactiveColor;
  final double animValue;

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty) return;

    final barCount = bars.length;
    final totalGap = barCount > 1 ? (barCount - 1) * 2.0 : 0.0;
    final barWidth = (size.width - totalGap) / barCount;
    final clampedBarWidth = barWidth.clamp(1.5, 4.0);
    final actualTotalWidth = clampedBarWidth * barCount + 2.0 * (barCount - 1);
    final startX = (size.width - actualTotalWidth) / 2;

    final activePaint = Paint()
      ..color = activeColor
      ..strokeCap = StrokeCap.round;
    final inactivePaint = Paint()
      ..color = inactiveColor
      ..strokeCap = StrokeCap.round;

    final progressIndex = (progress * barCount).floor();

    for (int i = 0; i < barCount; i++) {
      final x = startX + i * (clampedBarWidth + 2.0) + clampedBarWidth / 2;
      var heightFactor = bars[i];

      // Subtle bounce for playing bars near the playback head
      if (animValue > 0 && (i - progressIndex).abs() <= 2) {
        heightFactor = (heightFactor + animValue * 0.15).clamp(0.1, 1.0);
      }

      final barHeight = (size.height * 0.85 * heightFactor).clamp(
        3.0,
        size.height * 0.9,
      );
      final top = (size.height - barHeight) / 2;
      final bottom = top + barHeight;

      final paint = i <= progressIndex ? activePaint : inactivePaint;
      canvas.drawLine(
        Offset(x, top),
        Offset(x, bottom),
        paint..strokeWidth = clampedBarWidth,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.animValue != animValue;
  }
}
