import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chataway_plus/core/themes/app_text_styles.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:chataway_plus/features/theme/data/models/app_theme_mode.dart';
import 'package:chataway_plus/features/theme/presentation/providers/theme_provider.dart';

/// Theme settings page for selecting app theme
class ThemeSettingsPage extends ConsumerWidget {
  const ThemeSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final responsive = _responsiveFor(context);
    final themeState = ref.watch(themeNotifierProvider);
    final currentMode = themeState.themeMode;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        scrolledUnderElevation: 0.0,
        toolbarHeight: responsive.size(68),
        centerTitle: false,
        titleSpacing: 0,
        leadingWidth: responsive.size(50),
        title: Text(
          'Theme',
          style: AppTextSizes.heading(context).copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: AppColors.primary,
            size: responsive.size(24),
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: responsive.spacing(16),
            vertical: responsive.spacing(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header description
              Padding(
                padding: EdgeInsets.only(
                  left: responsive.spacing(4),
                  bottom: responsive.spacing(20),
                ),
                child: Text(
                  'Choose your preferred theme',
                  style: AppTextSizes.regular(context).copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(
                      (0.6 * 255).round(),
                    ),
                  ),
                ),
              ),

              // Theme options
              ...AppThemeMode.values.map(
                (mode) => _buildThemeOption(
                  context: context,
                  ref: ref,
                  mode: mode,
                  isSelected: currentMode == mode,
                  responsive: responsive,
                  theme: theme,
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  ResponsiveSize _responsiveFor(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return ResponsiveSize(
      context: context,
      constraints: BoxConstraints(maxWidth: width),
      breakpoint: DeviceBreakpoint.fromWidth(width),
    );
  }

  Widget _buildThemeOption({
    required BuildContext context,
    required WidgetRef ref,
    required AppThemeMode mode,
    required bool isSelected,
    required ResponsiveSize responsive,
    required ThemeData theme,
    required bool isDark,
  }) {
    return InkWell(
      onTap: () {
        ref.read(themeNotifierProvider.notifier).setThemeMode(mode);
      },
      borderRadius: BorderRadius.circular(responsive.size(12)),
      child: Container(
        margin: EdgeInsets.only(bottom: responsive.spacing(12)),
        padding: EdgeInsets.symmetric(
          horizontal: responsive.spacing(16),
          vertical: responsive.spacing(16),
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withAlpha((0.08 * 255).round())
              : (isDark
                    ? Colors.white.withAlpha((0.05 * 255).round())
                    : Colors.transparent),
          borderRadius: BorderRadius.circular(responsive.size(12)),
        ),
        child: Row(
          children: [
            // Theme icon
            Container(
              width: responsive.size(44),
              height: responsive.size(44),
              decoration: BoxDecoration(
                color: _getIconBackgroundColor(mode),
                borderRadius: BorderRadius.circular(responsive.size(10)),
              ),
              child: Icon(
                _getThemeIcon(mode),
                color: _getIconColor(mode),
                size: responsive.size(24),
              ),
            ),
            SizedBox(width: responsive.spacing(16)),

            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mode.displayName,
                    style: AppTextSizes.regular(context).copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                  SizedBox(height: responsive.spacing(4)),
                  Text(
                    mode.description,
                    style: AppTextSizes.small(context).copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(
                        (0.6 * 255).round(),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Selection indicator
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: AppColors.primary,
                size: responsive.size(24),
              )
            else
              Icon(
                Icons.circle_outlined,
                color: isDark ? Colors.white38 : AppColors.greyLight,
                size: responsive.size(24),
              ),
          ],
        ),
      ),
    );
  }

  IconData _getThemeIcon(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return Icons.light_mode;
      case AppThemeMode.dark:
        return Icons.dark_mode;
      case AppThemeMode.system:
        return Icons.settings_brightness;
    }
  }

  Color _getIconBackgroundColor(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return const Color(0xFFFFF9E6); // Light yellow
      case AppThemeMode.dark:
        return const Color(0xFF2D2D2D); // Dark grey
      case AppThemeMode.system:
        return AppColors.greyLightest;
    }
  }

  Color _getIconColor(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return const Color(0xFFFFB300); // Amber
      case AppThemeMode.dark:
        return const Color(0xFF90CAF9); // Light blue
      case AppThemeMode.system:
        return AppColors.primary;
    }
  }
}
