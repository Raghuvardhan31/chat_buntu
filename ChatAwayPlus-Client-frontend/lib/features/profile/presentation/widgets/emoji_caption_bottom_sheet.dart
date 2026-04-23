import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/themes/colors/app_colors.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';

class EmojiCaptionBottomSheet extends StatefulWidget {
  final String initialCaption;
  final VoidCallback? onCancelled;
  final void Function(String caption)? onSave;
  final ResponsiveSize? responsive;

  const EmojiCaptionBottomSheet({
    super.key,
    this.initialCaption = '',
    this.onCancelled,
    this.onSave,
    this.responsive,
  });

  @override
  State<EmojiCaptionBottomSheet> createState() =>
      _EmojiCaptionBottomSheetState();
}

class _EmojiCaptionBottomSheetState extends State<EmojiCaptionBottomSheet> {
  late TextEditingController _captionController;
  static const int _maxCaptionLength = 100;

  @override
  void initState() {
    super.initState();
    _captionController = TextEditingController(text: widget.initialCaption);
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final responsive = widget.responsive;
    final captionLength = _captionController.text.characters.length;
    final isSaveEnabled = _captionController.text.trim().isNotEmpty;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // AnimatedPadding prevents keyboard "jump" when switching to emoji keyboard
    return AnimatedPadding(
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: responsive?.spacing(20) ?? 20.0,
          vertical: responsive?.spacing(16) ?? 16.0,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(responsive?.size(20) ?? 20.0),
            topRight: Radius.circular(responsive?.size(20) ?? 20.0),
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withValues(alpha: 0.08),
                  ),
                  child: Icon(
                    Icons.emoji_emotions_rounded,
                    size: responsive?.size(20) ?? 20.0,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(width: responsive?.spacing(12) ?? 12.0),
                Expanded(
                  child: TextField(
                    controller: _captionController,
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    maxLines: 1,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(_maxCaptionLength),
                    ],
                    cursorColor: theme.colorScheme.onSurface,
                    style: AppTextSizes.small(context).copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Add caption for your emojis',
                      hintStyle: AppTextSizes.natural(context).copyWith(
                        color: isDark ? Colors.white54 : AppColors.colorGrey,
                      ),
                      filled: false,
                      border: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            Divider(
              height: 1,
              thickness: 1,
              color: isDark ? Colors.white24 : Colors.grey.shade300,
            ),
            // Removed blue underline for cleaner dark mode look
            Padding(
              padding: EdgeInsets.only(top: responsive?.spacing(8) ?? 8.0),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '$captionLength/$_maxCaptionLength',
                  style: AppTextSizes.small(context).copyWith(
                    color: isDark ? Colors.white54 : AppColors.colorGrey,
                  ),
                ),
              ),
            ),
            SizedBox(height: responsive?.spacing(14) ?? 14.0),
            Text(
              "Craft a short caption for your updated emoji. It shows your"
              ' contacts inside Express Hub.',
              style: AppTextSizes.small(
                context,
              ).copyWith(color: isDark ? Colors.white54 : AppColors.colorGrey),
            ),
            SizedBox(height: responsive?.spacing(20) ?? 20.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    widget.onCancelled?.call();
                    Navigator.of(context).maybePop();
                  },
                  child: Text(
                    'Cancel',
                    style: AppTextSizes.regular(context).copyWith(
                      color: AppColors.colorGrey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                SizedBox(width: responsive?.spacing(40) ?? 40.0),
                TextButton(
                  onPressed: isSaveEnabled
                      ? () {
                          final caption = _captionController.text.trim();
                          widget.onSave?.call(caption);
                          Navigator.of(context).maybePop();
                        }
                      : null,
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: responsive?.spacing(10) ?? 10.0,
                    ),
                    child: Text(
                      'Save',
                      style: AppTextSizes.regular(context).copyWith(
                        color: isSaveEnabled
                            ? AppColors.primary
                            : AppColors.colorGrey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
