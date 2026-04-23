import 'package:flutter/material.dart';

import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';

class StoryProgressBar extends StatelessWidget {
  const StoryProgressBar({
    super.key,
    required this.totalSegments,
    required this.currentIndex,
    required this.progressController,
    required this.responsive,
  });

  final int totalSegments;
  final int currentIndex;
  final AnimationController progressController;
  final ResponsiveSize responsive;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(totalSegments, (idx) {
        final isCompleted = idx < currentIndex;
        final isActive = idx == currentIndex;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: responsive.spacing(2)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(responsive.size(99)),
              child: Container(
                height: responsive.size(3),
                color: Colors.white.withValues(alpha: 0.28),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: AnimatedBuilder(
                    animation: progressController,
                    builder: (context, _) {
                      final v = isCompleted
                          ? 1.0
                          : (isActive ? progressController.value : 0.0);
                      return FractionallySizedBox(
                        widthFactor: v,
                        child: Container(color: Colors.white),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
