import 'package:flutter/material.dart';
import 'package:chataway_plus/core/themes/app_text_styles.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';

/// Centralized feature tips for onboarding/intro cards.
/// Keep content short (2 lines) for responsive layouts.
class FeatureTips {
  const FeatureTips._();

  static const String tipKeyDraggableEmoji = 'draggable_emoji';
  static const String tipKeyPersonalThoughts = 'personal_thoughts';
  static const String tipKeyEmojiCaptions = 'emoji_captions';
  static const String tipKeyMoodEmoji = 'mood_emoji';

  /// Draggable Emoji: fun + greeting on app open.
  static const String draggableEmoji =
      'Choose your favorite emoji and drag it for fun,\n'
      'and let it greet you every time you open ChatAway+.';

  /// Personal Thoughts: Write private thoughts and feelings.
  static const String personalThoughts =
      'Write your personal thoughts and feelings here.';

  /// Emoji Captions: Express with emojis and captions.
  static const String emojiCaptions =
      'Express yourself better with emojis and captions!';

  /// Mood Emoji: current feeling with time-bound display.
  static const String moodEmoji =
      'Set your current mood for yourself with a timer!\n'
      'Only you can see it - appears in your top bar for the time you choose.';

  /// Card presets for reuse in UI
  static const FeatureTipCardData draggableEmojiCard = FeatureTipCardData(
    text: draggableEmoji,
    backgroundColor: Color.fromRGBO(
      255,
      87,
      34,
      0.85,
    ), // vibrant orange with transparency
    icon: Icons.emoji_emotions, // emoji icon for better understanding
  );

  static const FeatureTipCardData personalThoughtsCard = FeatureTipCardData(
    text: personalThoughts,
    backgroundColor: Color.fromRGBO(
      156,
      39,
      176,
      0.85,
    ), // purple with transparency
    icon: Icons.mic, // mic icon for personal thoughts
  );

  static const FeatureTipCardData emojiCaptionsCard = FeatureTipCardData(
    text: emojiCaptions,
    backgroundColor: Color.fromRGBO(
      0,
      150,
      136,
      0.85,
    ), // teal with transparency
    icon: Icons.add_reaction_rounded, // emoji icon for captions
  );

  static const FeatureTipCardData moodEmojiCard = FeatureTipCardData(
    text: moodEmoji,
    backgroundColor: Color.fromRGBO(33, 150, 243, 0.85),
    icon: Icons.mood,
  );

  /// Card style presets (use with ResponsiveSize for scaling)
  static const FeatureTipCardStyle tipCardStyle = FeatureTipCardStyle(
    maxWidthFactor: 0.9, // wider to keep text on two lines comfortably
    minWidthFactor: 0.6,
    horizontalPadding: 12,
    verticalPadding: 10,
    borderRadius: 12,
    iconSize: 18,
    textLineHeight: 1.35,
    shadowOpacity: 0.12,
    shadowBlurRadius: 12,
    shadowYOffsetScale: 4, // use responsive.spacing(shadowYOffsetScale)
  );
}

class FeatureTipCardData {
  final String text;
  final Color backgroundColor;
  final IconData icon;
  final IconData? secondIcon; // Optional second icon for combined features

  const FeatureTipCardData({
    required this.text,
    required this.backgroundColor,
    required this.icon,
    this.secondIcon,
  });
}

class FeatureTipCardStyle {
  final double maxWidthFactor;
  final double minWidthFactor;
  final double horizontalPadding;
  final double verticalPadding;
  final double borderRadius;
  final double iconSize;
  final double textLineHeight;
  final double shadowOpacity;
  final double shadowBlurRadius;

  /// multiplier passed into responsive.spacing() for vertical shadow offset
  final double shadowYOffsetScale;

  const FeatureTipCardStyle({
    required this.maxWidthFactor,
    required this.minWidthFactor,
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.borderRadius,
    required this.iconSize,
    required this.textLineHeight,
    required this.shadowOpacity,
    required this.shadowBlurRadius,
    required this.shadowYOffsetScale,
  });
}

/// Reusable tip card widget - use this instead of creating custom cards
class TipCard extends StatelessWidget {
  final FeatureTipCardData data;
  final FeatureTipCardStyle style;
  final ResponsiveSize responsive;
  final Widget? leading;
  final VoidCallback? onClose;

  const TipCard({
    super.key,
    required this.data,
    required this.style,
    required this.responsive,
    this.leading,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: responsive.spacing(style.horizontalPadding),
        vertical: responsive.spacing(style.verticalPadding),
      ),
      decoration: BoxDecoration(
        color: data.backgroundColor,
        borderRadius: BorderRadius.circular(
          responsive.size(style.borderRadius),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: style.shadowOpacity),
            blurRadius: responsive.size(style.shadowBlurRadius),
            offset: Offset(0, responsive.spacing(style.shadowYOffsetScale)),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (leading != null)
            leading!
          else if (data.secondIcon != null) ...[
            Icon(
              data.icon,
              size: responsive.size(style.iconSize),
              color: Colors.white,
            ),
            SizedBox(width: responsive.spacing(4)),
            Icon(
              data.secondIcon!,
              size: responsive.size(style.iconSize),
              color: Colors.white,
            ),
          ] else
            Icon(
              data.icon,
              size: responsive.size(style.iconSize),
              color: Colors.white,
            ),
          SizedBox(width: responsive.spacing(8)),
          Expanded(
            child: Text(
              data.text,
              style: AppTextSizes.small(context).copyWith(
                color: Colors.white,
                height: style.textLineHeight,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (onClose != null) ...[
            SizedBox(width: responsive.spacing(8)),
            GestureDetector(
              onTap: onClose,
              child: Icon(
                Icons.close,
                size: responsive.size(style.iconSize),
                color: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
