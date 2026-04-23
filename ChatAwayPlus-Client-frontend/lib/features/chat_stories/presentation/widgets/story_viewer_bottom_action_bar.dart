import 'package:flutter/material.dart';

import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:chataway_plus/core/themes/app_text_styles.dart';

class StoryViewerBottomActionBar extends StatelessWidget {
  const StoryViewerBottomActionBar({
    super.key,
    required this.responsive,
    this.onReply,
    this.onLike,
    this.onSend,
  });

  final ResponsiveSize responsive;
  final VoidCallback? onReply;
  final VoidCallback? onLike;
  final VoidCallback? onSend;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: responsive.spacing(12),
        right: responsive.spacing(12),
        bottom: responsive.spacing(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: responsive.spacing(12),
                vertical: responsive.spacing(10),
              ),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(responsive.size(30)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.reply,
                    color: Colors.white,
                    size: responsive.size(18),
                  ),
                  SizedBox(width: responsive.spacing(10)),
                  Text(
                    'Reply...',
                    style: AppTextSizes.regular(context).copyWith(
                      color: Colors.white70,
                      fontSize: responsive.size(14),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: responsive.spacing(10)),
          Container(
            width: responsive.size(44),
            height: responsive.size(44),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: onLike,
              icon: Icon(
                Icons.favorite_border,
                color: Colors.white,
                size: responsive.size(20),
              ),
            ),
          ),
          SizedBox(width: responsive.spacing(10)),
          Container(
            width: responsive.size(44),
            height: responsive.size(44),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: onSend,
              icon: Icon(
                Icons.send,
                color: Colors.white,
                size: responsive.size(20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
