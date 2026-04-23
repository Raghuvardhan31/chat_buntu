import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:chataway_plus/core/themes/app_text_styles.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';

/// Data class for attachment option configuration
class AttachmentOptionData {
  const AttachmentOptionData({
    this.icon,
    this.assetPath,
    this.iconSize,
    required this.label,
    required this.color,
    required this.onTap,
  }) : assert(
         icon != null || assetPath != null,
         'Provide either icon or assetPath.',
       );

  final IconData? icon;
  final String? assetPath;
  final double? iconSize;
  final String label;
  final Color color;
  final VoidCallback onTap;
}

/// WhatsApp-style attachment panel with grid layout
/// Easy to add more options - just add to the attachmentOptions list
class AttachmentPanelWidget extends StatelessWidget {
  const AttachmentPanelWidget({
    super.key,
    required this.attachmentOptions,
    required this.responsive,
    required this.isDark,
    this.verboseLogs = false,
  });

  final List<AttachmentOptionData> attachmentOptions;
  final ResponsiveSize responsive;
  final bool isDark;
  final bool verboseLogs;

  @override
  Widget build(BuildContext context) {
    if (verboseLogs && kDebugMode) {
      debugPrint('📦 Building attachment panel');
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: responsive.spacing(16),
        vertical: responsive.spacing(20),
      ),
      margin: EdgeInsets.symmetric(horizontal: responsive.spacing(12)),
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(responsive.size(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.08 * 255).round()),
            blurRadius: responsive.size(12),
            offset: Offset(0, responsive.spacing(4)),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int start = 0; start < attachmentOptions.length; start += 3) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: attachmentOptions
                  .sublist(
                    start,
                    (start + 3 > attachmentOptions.length)
                        ? attachmentOptions.length
                        : start + 3,
                  )
                  .map(
                    (option) => _AttachmentOption(
                      icon: option.icon,
                      assetPath: option.assetPath,
                      iconSize: option.iconSize,
                      label: option.label,
                      color: option.color,
                      onTap: option.onTap,
                      responsive: responsive,
                      isDark: isDark,
                      verboseLogs: verboseLogs,
                    ),
                  )
                  .toList(),
            ),
            if (start + 3 < attachmentOptions.length)
              SizedBox(height: responsive.spacing(20)),
          ],
        ],
      ),
    );
  }
}

class _AttachmentOption extends StatelessWidget {
  const _AttachmentOption({
    required this.icon,
    required this.assetPath,
    required this.iconSize,
    required this.label,
    required this.color,
    required this.onTap,
    required this.responsive,
    required this.isDark,
    this.verboseLogs = false,
  });

  final IconData? icon;
  final String? assetPath;
  final double? iconSize;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final ResponsiveSize responsive;
  final bool isDark;
  final bool verboseLogs;

  @override
  Widget build(BuildContext context) {
    final size = responsive.size(iconSize ?? 24);
    final Widget iconWidget = (assetPath != null)
        ? Image.asset(
            assetPath!,
            width: size,
            height: size,
            fit: BoxFit.contain,
            color: color,
          )
        : Icon(icon, color: color, size: size);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (verboseLogs && kDebugMode) {
          debugPrint('🎯 Attachment option tapped: $label');
        }
        onTap();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: responsive.size(52),
            height: responsive.size(52),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha((0.1 * 255).round()),
                  blurRadius: responsive.size(8),
                  offset: Offset(0, responsive.spacing(3)),
                ),
              ],
            ),
            child: iconWidget,
          ),
          SizedBox(height: responsive.spacing(6)),
          Text(
            label,
            style: AppTextSizes.small(
              context,
            ).copyWith(color: isDark ? Colors.white : Colors.black87),
          ),
        ],
      ),
    );
  }
}
