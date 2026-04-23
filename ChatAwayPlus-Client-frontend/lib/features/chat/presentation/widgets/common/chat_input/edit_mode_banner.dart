import 'package:flutter/material.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/core/themes/app_text_styles.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';

/// Edit mode banner widget showing "Edit message" indicator
class EditModeBanner extends StatelessWidget {
  const EditModeBanner({
    super.key,
    required this.editingLabel,
    required this.responsive,
    required this.isDark,
    required this.isSavingEdit,
    required this.onCancel,
  });

  final String? editingLabel;
  final ResponsiveSize responsive;
  final bool isDark;
  final bool isSavingEdit;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        responsive.spacing(12),
        responsive.spacing(6),
        responsive.spacing(12),
        0,
      ),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: responsive.spacing(12),
          vertical: responsive.spacing(10),
        ),
        decoration: BoxDecoration(
          color: isDark
              ? Theme.of(context).colorScheme.surfaceContainerHighest
              : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(responsive.size(12)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.edit,
              size: responsive.size(18),
              color: AppColors.primary,
            ),
            SizedBox(width: responsive.spacing(8)),
            Expanded(
              child: Text(
                editingLabel ?? 'Edit message',
                style: AppTextSizes.natural(
                  context,
                ).copyWith(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              onPressed: isSavingEdit ? null : onCancel,
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
