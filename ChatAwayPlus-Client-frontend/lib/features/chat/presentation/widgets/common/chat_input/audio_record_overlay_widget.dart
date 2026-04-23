import 'dart:async';
import 'package:flutter/material.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';

/// WhatsApp-style audio recording overlay
///
/// Shows when user long-presses the mic button:
/// - Red pulsing recording indicator + timer
/// - "Slide to cancel" hint with left arrow
/// - Replaces the input pill area during recording
class AudioRecordOverlayWidget extends StatefulWidget {
  const AudioRecordOverlayWidget({
    super.key,
    required this.responsive,
    required this.isDark,
    required this.onCancel,
    required this.onStopRecording,
    this.onMaxDurationReached,
    this.maxDurationSeconds = 60,
  });

  final ResponsiveSize responsive;
  final bool isDark;
  final VoidCallback onCancel;

  /// Called when recording stops (long-press released). Passes elapsed seconds.
  final ValueChanged<int> onStopRecording;

  /// Called when the max duration is reached (auto-stop).
  final VoidCallback? onMaxDurationReached;

  /// Maximum recording duration in seconds (default: 60).
  final int maxDurationSeconds;

  @override
  State<AudioRecordOverlayWidget> createState() =>
      AudioRecordOverlayWidgetState();
}

class AudioRecordOverlayWidgetState extends State<AudioRecordOverlayWidget>
    with SingleTickerProviderStateMixin {
  int _elapsedSeconds = 0;

  /// Public accessor for elapsed seconds (used by parent to get duration)
  int get elapsedSeconds => _elapsedSeconds;

  /// Called externally when user releases the mic long-press
  void stopRecording() {
    _timer?.cancel();
    widget.onStopRecording(_elapsedSeconds);
  }

  Timer? _timer;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _elapsedSeconds++);
        if (_elapsedSeconds >= widget.maxDurationSeconds) {
          _timer?.cancel();
          widget.onMaxDurationReached?.call();
          widget.onStopRecording(_elapsedSeconds);
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  String _formatDuration(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  double _dragOffset = 0;
  static const double _cancelThreshold = 80.0;

  @override
  Widget build(BuildContext context) {
    final responsive = widget.responsive;
    final isCancelling = _dragOffset < -_cancelThreshold;

    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        setState(() {
          _dragOffset += details.delta.dx;
          if (_dragOffset > 0) _dragOffset = 0;
        });
      },
      onHorizontalDragEnd: (details) {
        if (_dragOffset < -_cancelThreshold) {
          widget.onCancel();
        }
        setState(() => _dragOffset = 0);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        height: responsive.size(49),
        decoration: BoxDecoration(
          color: isCancelling
              ? (widget.isDark
                    ? Colors.red.shade900.withAlpha((0.3 * 255).round())
                    : Colors.red.shade50)
              : (widget.isDark
                    ? Theme.of(context).colorScheme.surface
                    : Colors.white),
          borderRadius: BorderRadius.circular(responsive.size(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(
                widget.isDark ? (0.25 * 255).round() : (0.08 * 255).round(),
              ),
              blurRadius: responsive.size(12),
              offset: Offset(0, responsive.spacing(2)),
            ),
          ],
        ),
        child: Row(
          children: [
            // Cancel button (trash icon)
            GestureDetector(
              onTap: widget.onCancel,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: responsive.spacing(10),
                  vertical: responsive.spacing(8),
                ),
                child: Icon(
                  Icons.delete_rounded,
                  color: isCancelling ? Colors.red.shade700 : Colors.red,
                  size: responsive.size(20),
                ),
              ),
            ),

            // Recording indicator (pulsing red dot) + timer
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Container(
                  width: responsive.size(8),
                  height: responsive.size(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red.withAlpha(
                      (((0.5 + _pulseController.value * 0.5)) * 255).round(),
                    ),
                  ),
                );
              },
            ),
            SizedBox(width: responsive.spacing(6)),
            Text(
              _formatDuration(_elapsedSeconds),
              style: TextStyle(
                color: widget.isDark ? Colors.white : Colors.black87,
                fontSize: responsive.size(13),
                fontWeight: FontWeight.w500,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),

            const Spacer(),

            // Slide to cancel hint (animated opacity based on drag)
            AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: isCancelling ? 0.0 : 1.0,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.chevron_left,
                    color: Colors.grey,
                    size: responsive.size(16),
                  ),
                  Text(
                    'Slide to cancel',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: responsive.size(11),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(width: responsive.spacing(10)),
          ],
        ),
      ),
    );
  }
}
