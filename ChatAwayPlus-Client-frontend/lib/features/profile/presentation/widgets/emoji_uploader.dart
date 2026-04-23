import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/core/themes/app_text_styles.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/connectivity/connectivity_service.dart';
import 'package:chataway_plus/core/snackbar/app_snackbar.dart';

class EmojiUploader extends ConsumerStatefulWidget {
  final List<String> initialEmojis;
  final ValueChanged<List<String>>? onChanged;
  final ResponsiveSize? responsive;
  final VoidCallback? onCaptionTap;
  const EmojiUploader({
    super.key,
    this.initialEmojis = const [],
    this.onChanged,
    this.responsive,
    this.onCaptionTap,
  });

  @override
  ConsumerState<EmojiUploader> createState() => _EmojiUploaderState();
}

class _EmojiUploaderState extends ConsumerState<EmojiUploader> {
  static const int maxEmojis = 7;
  late List<String> _emojis;
  bool _localEditPending = false;

  @override
  void initState() {
    super.initState();
    _emojis = List<String>.from(widget.initialEmojis.take(maxEmojis));
  }

  @override
  void didUpdateWidget(covariant EmojiUploader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_localEditPending) {
      _localEditPending = false;
      return;
    }
    final oldEmojis = oldWidget.initialEmojis.join();
    final newEmojis = widget.initialEmojis.join();
    if (oldEmojis != newEmojis) {
      if (kDebugMode) {
        debugPrint(
          '[EmojiUploader] didUpdateWidget: emojis changed from "$oldEmojis" to "$newEmojis"',
        );
      }
      setState(() {
        _emojis = List<String>.from(widget.initialEmojis.take(maxEmojis));
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final responsive = widget.responsive;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(
            left: responsive != null ? responsive.spacing(33) : 33,
          ),
          child: Text(
            "Emoji's",
            style: AppTextSizes.regular(
              context,
            ).copyWith(color: Theme.of(context).colorScheme.onSurface),
          ),
        ),
        SizedBox(height: responsive != null ? responsive.spacing(1) : 1),
        GestureDetector(
          onTap: () => _openEmojiOptionsSheet(context),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.add_reaction,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : AppColors.iconPrimary,
                size: responsive != null ? responsive.size(24) : 24,
                semanticLabel: 'Emoji',
              ),
              SizedBox(width: responsive != null ? responsive.spacing(12) : 12),
              Expanded(
                child: Text(
                  _emojis.isEmpty ? 'Select emojis' : _emojis.join(' '),
                  style: AppTextSizes.natural(context).copyWith(
                    color: _emojis.isEmpty
                        ? (Theme.of(context).brightness == Brightness.dark
                              ? Colors.white54
                              : Colors.grey.shade600)
                        : Theme.of(context).colorScheme.onSurface,
                    fontSize: _emojis.isEmpty ? null : 20,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _openEmojiOptionsSheet(context),
                icon: Icon(
                  Icons.keyboard_arrow_down,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                tooltip: 'Select emojis',
              ),
              if (widget.onCaptionTap != null)
                IconButton(
                  onPressed: widget.onCaptionTap,
                  icon: Icon(
                    Icons.edit_note_rounded,
                    color: AppColors.primary,
                    size: responsive != null ? responsive.size(22) : 22,
                  ),
                  tooltip: "Emoji's caption",
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.only(
            left: responsive != null ? responsive.spacing(36) : 36,
          ),
          child: Divider(
            height: 0,
            thickness: 1,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white24
                : Colors.grey.shade400,
          ),
        ),
        SizedBox(height: responsive != null ? responsive.spacing(8) : 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              '${_emojis.length}/$maxEmojis',
              style: AppTextSizes.small(
                context,
              ).copyWith(color: AppColors.colorGrey),
            ),
          ],
        ),
      ],
    );
  }

  void _openEmojiOptionsSheet(BuildContext context) {
    final hasEmojis = _emojis.isNotEmpty;
    final sheetTheme = Theme.of(context);
    final sheetIsDark = sheetTheme.brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: sheetTheme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final responsive = widget.responsive;

        final sheetVerticalPadding = responsive?.spacing(30) ?? 30.0;
        final sheetHorizontalPadding = responsive?.spacing(20) ?? 20.0;
        final actionCircleSize = responsive?.size(60) ?? 60.0;
        final actionBorderWidth = responsive?.size(2) ?? 2.0;
        final actionIconSize = responsive?.size(28) ?? 28.0;
        final actionLabelSpacing = responsive?.spacing(12) ?? 12.0;
        final bottomSpacing = responsive?.spacing(30) ?? 30.0;

        return Container(
          color: sheetTheme.colorScheme.surface,
          padding: EdgeInsets.symmetric(
            vertical: sheetVerticalPadding,
            horizontal: sheetHorizontalPadding,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Add/Edit
                  Column(
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.of(ctx).pop();
                          _openEmojiEditorSheet(context);
                        },
                        child: Container(
                          width: actionCircleSize,
                          height: actionCircleSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primaryDark,
                              width: actionBorderWidth,
                            ),
                          ),
                          child: Icon(
                            hasEmojis
                                ? Icons.emoji_emotions_sharp
                                : Icons.add_reaction,
                            color: sheetIsDark
                                ? Colors.white
                                : AppColors.iconPrimary,
                            size: actionIconSize,
                          ),
                        ),
                      ),
                      SizedBox(height: actionLabelSpacing),
                      Text(
                        hasEmojis ? 'Edit' : 'Add',
                        style: AppTextSizes.regular(context).copyWith(
                          fontWeight: FontWeight.w500,
                          color: sheetTheme.colorScheme.onSurface,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                  // Delete
                  Column(
                    children: [
                      GestureDetector(
                        onTap: hasEmojis
                            ? () async {
                                final online = ref
                                    .read(internetStatusStreamProvider)
                                    .maybeWhen(
                                      data: (v) => v,
                                      orElse: () => false,
                                    );
                                if (!online) {
                                  AppSnackbar.showOfflineWarning(
                                    context,
                                    "You're offline. Please connect to the internet",
                                  );
                                  return;
                                }
                                if (!mounted) return;
                                Navigator.of(ctx).pop();
                                _localEditPending = true;
                                setState(() => _emojis = []);
                                try {
                                  widget.onChanged?.call(_emojis);
                                  for (int i = 0; i < 12; i++) {
                                    if (!mounted) return;
                                    if (MediaQuery.of(
                                          context,
                                        ).viewInsets.bottom ==
                                        0) {
                                      break;
                                    }
                                    await Future.delayed(
                                      const Duration(milliseconds: 50),
                                    );
                                  }
                                  if (!mounted) return;
                                  AppSnackbar.showSuccess(
                                    context,
                                    "Emoji's deleted",
                                    bottomPosition: 300,
                                    duration: const Duration(seconds: 1),
                                  );
                                } catch (e) {
                                  for (int i = 0; i < 12; i++) {
                                    if (!mounted) return;
                                    if (MediaQuery.of(
                                          context,
                                        ).viewInsets.bottom ==
                                        0) {
                                      break;
                                    }
                                    await Future.delayed(
                                      const Duration(milliseconds: 50),
                                    );
                                  }
                                  if (!mounted) return;
                                  AppSnackbar.showError(
                                    context,
                                    'Error updating emojis. Please try again',
                                    bottomPosition: 300,
                                    duration: const Duration(seconds: 2),
                                  );
                                }
                              }
                            : null,
                        child: Container(
                          width: actionCircleSize,
                          height: actionCircleSize,
                          decoration: BoxDecoration(
                            color: sheetTheme.colorScheme.surface,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: hasEmojis
                                  ? AppColors.primaryDark
                                  : (sheetIsDark
                                        ? Colors.white24
                                        : Colors.grey[300]!),
                              width: actionBorderWidth,
                            ),
                          ),
                          child: Icon(
                            Icons.delete,
                            color: hasEmojis
                                ? (sheetIsDark
                                      ? Colors.white
                                      : AppColors.iconPrimary)
                                : (sheetIsDark
                                      ? Colors.white38
                                      : Colors.grey[300]!),
                            size: actionIconSize,
                          ),
                        ),
                      ),
                      SizedBox(height: actionLabelSpacing),
                      Text(
                        'Delete',
                        style: AppTextSizes.regular(context).copyWith(
                          fontWeight: FontWeight.w500,
                          color: hasEmojis
                              ? sheetTheme.colorScheme.onSurface
                              : (sheetIsDark
                                    ? Colors.white24
                                    : Colors.grey[400]!),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: bottomSpacing),
            ],
          ),
        );
      },
    );
  }

  void _openEmojiEditorSheet(BuildContext context) {
    final editorTheme = Theme.of(context);
    final editorIsDark = editorTheme.brightness == Brightness.dark;
    final responsive = widget.responsive;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _EmojiPickerEditorSheet(
          initialEmojis: List<String>.from(_emojis),
          maxEmojis: maxEmojis,
          editorTheme: editorTheme,
          editorIsDark: editorIsDark,
          responsive: responsive,
          onSave: (list) async {
            final online = ref
                .read(internetStatusStreamProvider)
                .maybeWhen(data: (v) => v, orElse: () => false);
            if (!online) {
              AppSnackbar.showOfflineWarning(
                context,
                "You're offline. Please connect to the internet",
              );
              return;
            }
            _localEditPending = true;
            setState(() => _emojis = list.take(maxEmojis).toList());
            if (!mounted) return;
            try {
              widget.onChanged?.call(_emojis);
              if (!mounted) return;
              Navigator.of(context).pop();
              await Future.delayed(const Duration(milliseconds: 100));
              if (!mounted) return;
              AppSnackbar.showSuccess(
                context,
                "Emoji's updated",
                bottomPosition: 300,
                duration: const Duration(seconds: 1),
              );
            } catch (e) {
              if (!mounted) return;
              Navigator.of(context).pop();
              await Future.delayed(const Duration(milliseconds: 100));
              if (!mounted) return;
              AppSnackbar.showError(
                context,
                'Error updating emojis. Please try again',
                bottomPosition: 300,
                duration: const Duration(seconds: 2),
              );
            }
          },
        );
      },
    );
  }
}

/// Stateful bottom sheet that shows an emoji picker grid directly
/// (like "Your mood, your way" in MoodEmojiCircle) instead of a TextField.
class _EmojiPickerEditorSheet extends StatefulWidget {
  final List<String> initialEmojis;
  final int maxEmojis;
  final ThemeData editorTheme;
  final bool editorIsDark;
  final ResponsiveSize? responsive;
  final Future<void> Function(List<String>) onSave;

  const _EmojiPickerEditorSheet({
    required this.initialEmojis,
    required this.maxEmojis,
    required this.editorTheme,
    required this.editorIsDark,
    required this.responsive,
    required this.onSave,
  });

  @override
  State<_EmojiPickerEditorSheet> createState() =>
      _EmojiPickerEditorSheetState();
}

class _EmojiPickerEditorSheetState extends State<_EmojiPickerEditorSheet> {
  late List<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = List<String>.from(widget.initialEmojis);
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.editorTheme;
    final isDark = widget.editorIsDark;
    final responsive = widget.responsive;
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    final rs =
        responsive ??
        ResponsiveSize(
          context: context,
          constraints: BoxConstraints(maxWidth: screenWidth),
          breakpoint: DeviceBreakpoint.fromWidth(screenWidth),
        );

    return Container(
      height: screenHeight * 0.7,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(rs.size(20))),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(rs.spacing(16)),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: theme.dividerColor)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Select Emojis',
                    style: AppTextSizes.regular(
                      context,
                    ).copyWith(color: theme.colorScheme.onSurface),
                  ),
                ),
                Text(
                  '${_selected.length}/${widget.maxEmojis}',
                  style: AppTextSizes.natural(
                    context,
                  ).copyWith(color: AppColors.iconPrimary),
                ),
                SizedBox(width: rs.spacing(8)),
                IconButton(
                  icon: Icon(Icons.close, color: theme.colorScheme.onSurface),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Selected emojis row — tap to remove
          if (_selected.isNotEmpty)
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: rs.spacing(16),
                vertical: rs.spacing(8),
              ),
              child: Row(
                children: [
                  ..._selected.map((emoji) {
                    return GestureDetector(
                      onTap: () {
                        setState(() => _selected.remove(emoji));
                      },
                      child: Padding(
                        padding: EdgeInsets.only(right: rs.spacing(6)),
                        child: Chip(
                          label: Text(
                            emoji,
                            style: TextStyle(fontSize: rs.size(20)),
                          ),
                          deleteIcon: Icon(
                            Icons.close,
                            size: rs.size(16),
                            color: isDark
                                ? Colors.white54
                                : AppColors.colorGrey,
                          ),
                          onDeleted: () {
                            setState(() => _selected.remove(emoji));
                          },
                          backgroundColor: isDark
                              ? Colors.white12
                              : Colors.grey.shade100,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(rs.size(20)),
                          ),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          padding: EdgeInsets.symmetric(
                            horizontal: rs.spacing(4),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),

          // Emoji picker grid — directly visible
          Expanded(
            child: EmojiPicker(
              onEmojiSelected: (category, emoji) {
                if (_selected.length >= widget.maxEmojis) {
                  return; // max reached
                }
                setState(() {
                  _selected.add(emoji.emoji);
                });
              },
              config: Config(
                height: rs.size(256),
                checkPlatformCompatibility: true,
                emojiViewConfig: EmojiViewConfig(
                  emojiSizeMax: rs.size(28),
                  verticalSpacing: 0,
                  horizontalSpacing: 0,
                  gridPadding: EdgeInsets.zero,
                  backgroundColor: theme.colorScheme.surface,
                ),
                skinToneConfig: SkinToneConfig(),
                categoryViewConfig: CategoryViewConfig(),
                bottomActionBarConfig: BottomActionBarConfig(),
                searchViewConfig: SearchViewConfig(),
              ),
            ),
          ),

          // Save / Cancel buttons
          Padding(
            padding: EdgeInsets.all(rs.spacing(12)),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: rs.spacing(8)),
                      side: BorderSide(
                        color: AppColors.primary,
                        width: rs.size(1),
                      ),
                      minimumSize: Size(0, rs.size(40)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: AppTextSizes.small(context).copyWith(
                        fontSize: rs.size(12),
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: rs.spacing(10)),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _selected.isEmpty
                        ? null
                        : () => widget.onSave(_selected),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      disabledBackgroundColor: isDark
                          ? Colors.white12
                          : Colors.grey.shade300,
                      padding: EdgeInsets.symmetric(vertical: rs.spacing(8)),
                      minimumSize: Size(0, rs.size(40)),
                    ),
                    child: Text(
                      'Save',
                      style: AppTextSizes.small(context).copyWith(
                        fontSize: rs.size(12),
                        color: _selected.isEmpty
                            ? (isDark ? Colors.white38 : AppColors.colorGrey)
                            : Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
