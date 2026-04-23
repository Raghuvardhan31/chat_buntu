import 'package:flutter/material.dart';

class StoryNavigationGestureLayer extends StatelessWidget {
  const StoryNavigationGestureLayer({
    super.key,
    required this.onPrev,
    required this.onNext,
    required this.onPause,
    required this.onResume,
  });

  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onPause;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onPrev,
            onLongPressStart: (_) => onPause(),
            onLongPressEnd: (_) => onResume(),
          ),
        ),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onNext,
            onLongPressStart: (_) => onPause(),
            onLongPressEnd: (_) => onResume(),
          ),
        ),
      ],
    );
  }
}
