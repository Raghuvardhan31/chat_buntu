import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Clean swipe-to-reply bubble.
///
/// - Sender messages: swipe **left** (←) to reply
/// - Receiver messages: swipe **right** (→) to reply
///
/// No icons during swipe — clean drag only.
/// Triggers haptic feedback at the threshold. Snaps back with a spring
/// animation.
class SwipeReplyBubble extends StatefulWidget {
  const SwipeReplyBubble({
    super.key,
    required this.child,
    required this.isMe,
    required this.onSwipe,
    this.enabled = true,
    this.swipeThreshold = 64.0,
  });

  final Widget child;
  final bool isMe;
  final VoidCallback onSwipe;
  final bool enabled;
  final double swipeThreshold;

  @override
  State<SwipeReplyBubble> createState() => _SwipeReplyBubbleState();
}

class _SwipeReplyBubbleState extends State<SwipeReplyBubble>
    with SingleTickerProviderStateMixin {
  double _dragOffset = 0.0;
  bool _hasTriggered = false;
  late AnimationController _resetController;
  late Animation<double> _resetAnimation;

  @override
  void initState() {
    super.initState();
    _resetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _resetAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _resetController, curve: Curves.easeOutBack),
    );
    _resetController.addListener(() {
      setState(() => _dragOffset = _resetAnimation.value);
    });
  }

  @override
  void dispose() {
    _resetController.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (!widget.enabled) return;

    final delta = details.primaryDelta ?? 0;

    if (widget.isMe) {
      _dragOffset = (_dragOffset + delta).clamp(
        -widget.swipeThreshold * 1.3,
        0,
      );
    } else {
      _dragOffset = (_dragOffset + delta).clamp(0, widget.swipeThreshold * 1.3);
    }

    // Haptic feedback at threshold
    if (!_hasTriggered && _dragOffset.abs() >= widget.swipeThreshold) {
      _hasTriggered = true;
      HapticFeedback.mediumImpact();
    }

    setState(() {});
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (!widget.enabled) return;

    if (_dragOffset.abs() >= widget.swipeThreshold) {
      widget.onSwipe();
    }

    _resetAnimation = Tween<double>(begin: _dragOffset, end: 0).animate(
      CurvedAnimation(parent: _resetController, curve: Curves.easeOutBack),
    );
    _resetController.forward(from: 0);
    _hasTriggered = false;
  }

  void _onHorizontalDragCancel() {
    _resetAnimation = Tween<double>(begin: _dragOffset, end: 0).animate(
      CurvedAnimation(parent: _resetController, curve: Curves.easeOutBack),
    );
    _resetController.forward(from: 0);
    _hasTriggered = false;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      onHorizontalDragCancel: _onHorizontalDragCancel,
      child: Transform.translate(
        offset: Offset(_dragOffset, 0),
        child: widget.child,
      ),
    );
  }
}
