import 'package:flutter/material.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/core/themes/app_text_styles.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';

/// Input pill widget containing text field with emoji and attachment icons
class InputPillWidget extends StatelessWidget {
  const InputPillWidget({
    super.key,
    required this.pillKey,
    required this.textController,
    required this.focusNode,
    required this.responsive,
    required this.isDark,
    required this.showEmojiPicker,
    required this.showAttachmentPanel,
    required this.showCamera,
    required this.onTextChanged,
    required this.onSubmitted,
    required this.onEmojiToggle,
    required this.onAttachmentToggle,
    required this.onCameraTap,
    this.replyName,
    this.replyText,
    this.replyIcon,
    this.replyAssetIcon,
    this.onCancelReply,
  });

  final GlobalKey pillKey;
  final TextEditingController textController;
  final FocusNode focusNode;
  final ResponsiveSize responsive;
  final bool isDark;
  final bool showEmojiPicker;
  final bool showAttachmentPanel;
  final bool showCamera;
  final ValueChanged<String> onTextChanged;
  final VoidCallback onSubmitted;
  final VoidCallback onEmojiToggle;
  final VoidCallback onAttachmentToggle;
  final VoidCallback onCameraTap;
  final String? replyName;
  final String? replyText;
  final IconData? replyIcon;
  final String? replyAssetIcon;
  final VoidCallback? onCancelReply;

  bool get _hasReply => replyName != null && replyText != null;

  bool _isEmojiCodePoint(int code) {
    return (code >= 0x1F300 && code <= 0x1F9FF) ||
        (code >= 0x2600 && code <= 0x26FF) ||
        (code >= 0x2700 && code <= 0x27BF) ||
        (code >= 0x1F600 && code <= 0x1F64F) ||
        (code >= 0x1F680 && code <= 0x1F6FF) ||
        (code >= 0x1FA00 && code <= 0x1FAFF) ||
        (code >= 0xFE00 && code <= 0xFE0F) ||
        (code >= 0x200D && code <= 0x200D) ||
        (code >= 0xE0020 && code <= 0xE007F) ||
        (code == 0xFE0F) ||
        (code >= 0x1F1E0 && code <= 0x1F1FF);
  }

  bool _isEmojiOnlyText(String text) {
    if (text.isEmpty) return false;
    for (final rune in text.runes) {
      if (_isEmojiCodePoint(rune)) continue;
      if (rune == 0x20 || rune == 0x0A || rune == 0xFE0F || rune == 0x200D) {
        continue;
      }
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final isEmojiReply =
        replyText != null && _isEmojiOnlyText(replyText!.trim());
    return Container(
      key: pillKey,
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(responsive.size(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.08 * 255).round()),
            blurRadius: responsive.size(12),
            offset: Offset(0, responsive.spacing(2)),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Reply preview inside the pill
          if (_hasReply)
            Container(
              margin: EdgeInsets.only(
                left: responsive.spacing(6),
                right: responsive.spacing(6),
                top: responsive.spacing(6),
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(responsive.size(10)),
              ),
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    // Primary accent bar
                    Container(
                      width: responsive.size(4),
                      margin: EdgeInsets.only(
                        left: responsive.spacing(4),
                        top: responsive.spacing(4),
                        bottom: responsive.spacing(4),
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(responsive.size(2)),
                      ),
                    ),
                    SizedBox(width: responsive.spacing(8)),
                    // Name + quoted text
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: responsive.spacing(6),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              replyName!,
                              style: TextStyle(
                                fontSize: responsive.size(12.5),
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                            SizedBox(height: responsive.spacing(1)),
                            Row(
                              children: [
                                if (replyAssetIcon != null) ...[
                                  Image.asset(
                                    replyAssetIcon!,
                                    width: responsive.size(14),
                                    height: responsive.size(14),
                                    color: isDark
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade600,
                                  ),
                                  SizedBox(width: responsive.spacing(3)),
                                ] else if (replyIcon != null) ...[
                                  Icon(
                                    replyIcon,
                                    size: responsive.size(13),
                                    color: isDark
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade600,
                                  ),
                                  SizedBox(width: responsive.spacing(3)),
                                ],
                                Expanded(
                                  child: Text(
                                    replyText!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: isEmojiReply
                                          ? responsive.size(16)
                                          : responsive.size(12.5),
                                      color: isDark
                                          ? Colors.grey.shade400
                                          : Colors.grey.shade600,
                                      height: isEmojiReply ? 1.1 : null,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Close button
                    GestureDetector(
                      onTap: onCancelReply,
                      child: Padding(
                        padding: EdgeInsets.all(responsive.spacing(8)),
                        child: Icon(
                          Icons.close,
                          size: responsive.size(16),
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Text field row
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Emoji toggle icon
              GestureDetector(
                onTap: onEmojiToggle,
                child: Padding(
                  padding: EdgeInsets.only(
                    left: responsive.spacing(12),
                    bottom: responsive.spacing(10),
                  ),
                  child: Icon(
                    showEmojiPicker
                        ? Icons.keyboard_alt_outlined
                        : Icons.emoji_emotions_outlined,
                    color: showEmojiPicker
                        ? AppColors.primary
                        : (isDark ? Colors.white70 : Colors.grey[600]),
                    size: responsive.size(24),
                  ),
                ),
              ),
              // Text field
              Expanded(
                child: TextField(
                  controller: textController,
                  focusNode: focusNode,
                  enabled: true,
                  cursorColor: isDark ? Colors.white : Colors.black,
                  style: AppTextSizes.natural(
                    context,
                  ).copyWith(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintMaxLines: 1,
                    hintStyle: AppTextSizes.natural(context).copyWith(
                      color: isDark ? Colors.white54 : AppColors.colorGrey,
                    ),
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: responsive.spacing(16),
                      vertical: responsive.spacing(12),
                    ),
                  ),
                  maxLines: 5,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: onTextChanged,
                  onSubmitted: (_) => onSubmitted(),
                ),
              ),
              // Attachment icon (+ or ×) - inside text field on right
              GestureDetector(
                onTap: onAttachmentToggle,
                child: Padding(
                  padding: EdgeInsets.only(
                    right: responsive.spacing(10),
                    bottom: responsive.spacing(10),
                  ),
                  child: Transform.translate(
                    offset: Offset(-responsive.spacing(2), 0),
                    child: AnimatedRotation(
                      turns: showAttachmentPanel ? 0.125 : 0, // 45 degrees
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.add,
                        color: showAttachmentPanel
                            ? AppColors.primary
                            : (isDark ? Colors.white70 : Colors.grey[600]),
                        size: responsive.size(26),
                      ),
                    ),
                  ),
                ),
              ),
              // Camera icon - quick access to take photo (animated)
              TweenAnimationBuilder<double>(
                tween: Tween<double>(end: showCamera ? 1.0 : 0.0),
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                builder: (context, value, child) {
                  return ClipRect(
                    child: Align(
                      alignment: Alignment.centerRight,
                      widthFactor: value,
                      child: Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(
                            responsive.spacing(10) * (1 - value),
                            0,
                          ),
                          child: child,
                        ),
                      ),
                    ),
                  );
                },
                child: GestureDetector(
                  onTap: onCameraTap,
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: responsive.spacing(6),
                      right: responsive.spacing(10),
                      bottom: responsive.spacing(10),
                    ),
                    child: Transform.translate(
                      offset: Offset(-responsive.spacing(2), 0),
                      child: Icon(
                        Icons.camera_alt_outlined,
                        color: isDark ? Colors.white70 : Colors.grey[600],
                        size: responsive.size(24),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
