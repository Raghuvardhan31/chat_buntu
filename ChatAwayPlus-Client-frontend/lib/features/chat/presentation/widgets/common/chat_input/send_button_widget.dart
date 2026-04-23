import 'package:flutter/material.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';

/// Circular send/mic button widget for chat input (WhatsApp-style)
///
/// - No text + not editing → mic icon (hold to record)
/// - Has text or editing → send/check icon
class SendButtonWidget extends StatelessWidget {
  const SendButtonWidget({
    super.key,
    required this.buttonKey,
    required this.responsive,
    required this.canSend,
    required this.isEditing,
    required this.isSending,
    required this.isSavingEdit,
    required this.onSend,
    required this.onEditSave,
    this.isRecording = false,
    this.onMicLongPressStart,
    this.onMicLongPressEnd,
    this.onMicTap,
    this.onSlideToCancel,
  });

  final GlobalKey buttonKey;
  final ResponsiveSize responsive;
  final bool canSend;
  final bool isEditing;
  final bool isSending;
  final bool isSavingEdit;
  final VoidCallback onSend;
  final VoidCallback onEditSave;
  final bool isRecording;
  final VoidCallback? onMicLongPressStart;
  final VoidCallback? onMicLongPressEnd;
  final VoidCallback? onMicTap;
  final VoidCallback? onSlideToCancel;

  static const double _slideCancelThreshold = 100.0;

  bool get _showMic => !canSend && !isEditing && !isSending;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _showMic
          ? onMicTap
          : (canSend ? (isEditing ? onEditSave : onSend) : null),
      onLongPressStart: _showMic ? (_) => onMicLongPressStart?.call() : null,
      onLongPressMoveUpdate: _showMic
          ? (details) {
              if (details.offsetFromOrigin.dx < -_slideCancelThreshold) {
                onSlideToCancel?.call();
              }
            }
          : null,
      onLongPressEnd: _showMic ? (_) => onMicLongPressEnd?.call() : null,
      child: Container(
        key: buttonKey,
        width: responsive.size(48),
        height: responsive.size(48),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isRecording ? Colors.red : AppColors.primaryDark,
          boxShadow: [
            BoxShadow(
              color: (isRecording ? Colors.red : AppColors.primary).withAlpha(
                (0.3 * 255).round(),
              ),
              blurRadius: responsive.size(6),
              offset: Offset(0, responsive.spacing(2)),
            ),
          ],
        ),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            switchInCurve: Curves.easeInOut,
            switchOutCurve: Curves.easeInOut,
            transitionBuilder: (child, animation) {
              return ScaleTransition(scale: animation, child: child);
            },
            child: Icon(
              _showMic
                  ? Icons.mic
                  : (isEditing ? Icons.check : Icons.send_rounded),
              key: ValueKey<bool>(_showMic),
              color: (isSending || isSavingEdit)
                  ? Colors.white70
                  : Colors.white,
              size: responsive.size(24),
            ),
          ),
        ),
      ),
    );
  }
}
