import 'dart:math' as math;

import 'package:flutter/material.dart';

class StoryRingPainter extends CustomPainter {
  StoryRingPainter({
    required this.totalSegments,
    required this.watchedSegments,
    required this.unwatchedGradient,
    required this.watchedColor,
    required this.strokeWidth,
  });

  final int totalSegments;
  final Set<int> watchedSegments;
  final Gradient unwatchedGradient;
  final Color watchedColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = (math.min(size.width, size.height) / 2) - (strokeWidth / 2);
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);

    final segments = math.max(1, totalSegments);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final startBase = math.pi / 2;
    final segmentAngle = (2 * math.pi) / segments;
    final gapAngle = segments == 1 ? 0.0 : (segmentAngle * 0.12);
    final sweep = math.max(0.0, segmentAngle - gapAngle);

    for (var i = 0; i < segments; i++) {
      if (watchedSegments.contains(i)) {
        paint.shader = null;
        paint.color = watchedColor;
      } else {
        paint.shader = unwatchedGradient.createShader(rect);
      }
      final start = startBase + (i * segmentAngle) + (gapAngle / 2);
      canvas.drawArc(rect, start, sweep, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant StoryRingPainter oldDelegate) {
    return oldDelegate.totalSegments != totalSegments ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.unwatchedGradient != unwatchedGradient ||
        oldDelegate.watchedColor != watchedColor ||
        !_setEquals(oldDelegate.watchedSegments, watchedSegments);
  }

  bool _setEquals(Set<int> a, Set<int> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (final v in a) {
      if (!b.contains(v)) return false;
    }
    return true;
  }
}
