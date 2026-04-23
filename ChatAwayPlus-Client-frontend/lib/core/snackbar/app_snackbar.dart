import 'dart:async';
import 'package:flutter/material.dart';
import 'package:chataway_plus/core/themes/app_text_styles.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';

/// Global SnackBar utility for displaying consistent notifications throughout the app.
///
/// All snackbars use unified styling with AppColors.iconPrimary background and white text.
/// Features: solid background, sharp shadow, responsive sizing, and keyboard-aware positioning.
///
/// Usage Examples:
/// ```dart
/// // Standard snackbar
/// AppSnackbar.show(context, 'Profile updated successfully');
///
/// // Success snackbar (same styling, different semantic meaning)
/// AppSnackbar.showSuccess(context, 'Changes saved!');
///
/// // Error snackbar (same styling, longer duration)
/// AppSnackbar.showError(context, 'Failed to update profile');
///
/// // Custom color snackbar (if you need different colors)
/// AppSnackbar.showCustom(
///   context,
///   'Custom message',
///   backgroundColor: Colors.purple,
///   duration: Duration(seconds: 3),
/// );
/// ```
/// // Bottom snackbars:
/// AppSnackbar.show(context, 'Message');                              // 1 second
/// AppSnackbar.showSuccess(context, 'Saved!');                        // 1 second
/// AppSnackbar.showError(context, 'Failed');                          // 2 seconds
/// AppSnackbar.showWarning(context, 'Warning');                       // 1.5 seconds
/// AppSnackbar.showInfo(context, 'Info');                             // 1 second
///
/// // Top warning for offline scenarios:
/// AppSnackbar.showOfflineWarning(context, 'You\'re offline');        // 2 seconds, top position with WiFi icon
///
class AppSnackbar {
  // Static fields for top warning overlay
  static OverlayEntry? _topWarningEntry;
  static Timer? _topWarningTimer;

  /// Shows a standard snackbar at the bottom of the screen.
  ///
  /// This is the default snackbar style used throughout the app.
  /// - Background: AppColors.iconPrimary with shadow
  /// - Text: White, centered, large with font weight
  /// - Position: 80px from bottom (or above keyboard)
  /// - Duration: 1 second (default)
  ///
  /// Parameters:
  /// - [context]: BuildContext for overlay access
  /// - [message]: Text to display in the snackbar
  /// - [duration]: How long to show the snackbar (default: 1 second)
  static Future<void> show(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 1),
  }) {
    return _showSnackbarCustom(
      context,
      message,
      backgroundColor: AppColors.iconPrimary,
      textColor: Colors.white,
      bottomPosition: 80,
      duration: duration,
    );
  }

  /// Shows a success snackbar.
  ///
  /// Use this for positive feedback like successful saves, updates, etc.
  /// - Background: AppColors.iconPrimary with shadow
  /// - Text: White, large with font weight
  /// - Position: 80px from bottom (default, adjustable)
  /// - Duration: 1 second (default, adjustable)
  ///
  /// Parameters:
  /// - [context]: BuildContext for overlay access
  /// - [message]: Success message to display
  /// - [bottomPosition]: Distance from bottom (default: 80)
  /// - [duration]: How long to show the snackbar (default: 1 second)
  static Future<void> showSuccess(
    BuildContext context,
    String message, {
    double bottomPosition = 80,
    Duration duration = const Duration(seconds: 1),
  }) {
    return _showSnackbarCustom(
      context,
      message,
      backgroundColor: AppColors.iconPrimary,
      textColor: Colors.white,
      bottomPosition: bottomPosition,
      duration: duration,
    );
  }

  /// Shows an error snackbar.
  ///
  /// Use this for error messages, failed operations, validation errors, etc.
  /// - Background: AppColors.iconPrimary with shadow
  /// - Text: White, large with font weight
  /// - Position: 80px from bottom (default, adjustable)
  /// - Duration: 2 seconds (default - longer for errors, adjustable)
  ///
  /// Parameters:
  /// - [context]: BuildContext for overlay access
  /// - [message]: Error message to display
  /// - [bottomPosition]: Distance from bottom (default: 80)
  /// - [duration]: How long to show the snackbar (default: 2 seconds)
  static Future<void> showError(
    BuildContext context,
    String message, {
    double bottomPosition = 80,
    Duration duration = const Duration(seconds: 2),
  }) {
    return _showSnackbarCustom(
      context,
      message,
      backgroundColor: AppColors.iconPrimary,
      textColor: Colors.white,
      bottomPosition: bottomPosition,
      duration: duration,
    );
  }

  /// Shows a warning snackbar at bottom.
  ///
  /// Use this for warnings, cautions, or important notices.
  /// - Background: AppColors.iconPrimary with shadow
  /// - Text: White, large with font weight
  /// - Position: 80px from bottom (or above keyboard)
  /// - Duration: 1.5 seconds (default)
  ///
  /// Parameters:
  /// - [context]: BuildContext for overlay access
  /// - [message]: Warning message to display
  /// - [duration]: How long to show the snackbar (default: 1.5 seconds)
  static Future<void> showWarning(
    BuildContext context,
    String message, {
    double bottomPosition = 80,
    Duration duration = const Duration(milliseconds: 1500),
  }) {
    return _showSnackbarCustom(
      context,
      message,
      backgroundColor: AppColors.iconPrimary,
      textColor: Colors.white,
      bottomPosition: bottomPosition,
      duration: duration,
    );
  }

  /// Shows an offline warning at the TOP of the screen with WiFi off icon.
  ///
  /// Use this specifically when user tries to perform actions while offline.
  /// - Background: AppColors.iconPrimary with shadow
  /// - Icon: WiFi off icon on the left
  /// - Text: White, regular size
  /// - Position: Top of screen (below safe area + 40px)
  /// - Duration: 2 seconds (default)
  ///
  /// Parameters:
  /// - [context]: BuildContext for overlay access
  /// - [message]: Offline warning message (e.g., "You're offline. Check your connection")
  /// - [duration]: How long to show the warning (default: 2 seconds)
  static void showOfflineWarning(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    _showTopWarning(context, message, duration: duration);
  }

  static void showTopInfo(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    _showTopWarning(
      context,
      message,
      duration: duration,
      icon: Icons.info_outline,
    );
  }

  /// Shows an info snackbar.
  ///
  /// Use this for informational messages, tips, or neutral notifications.
  /// - Background: AppColors.iconPrimary with shadow
  /// - Text: White, large with font weight
  /// - Position: 80px from bottom (or above keyboard)
  /// - Duration: 1 second (default)
  ///
  /// Parameters:
  /// - [context]: BuildContext for overlay access
  /// - [message]: Info message to display
  /// - [bottomPosition]: Distance from bottom (default: 80)
  /// - [duration]: How long to show the snackbar (default: 1 second)
  static Future<void> showInfo(
    BuildContext context,
    String message, {
    double bottomPosition = 80,
    Duration duration = const Duration(seconds: 1),
  }) {
    return _showSnackbarCustom(
      context,
      message,
      backgroundColor: AppColors.iconPrimary,
      textColor: Colors.white,
      bottomPosition: bottomPosition,
      duration: duration,
    );
  }

  /// Shows a custom snackbar with gallery widget styling.
  ///
  /// Uses the same styling as the gallery widget delete snackbar:
  /// - Background: AppColors.iconPrimary (default) or custom color
  /// - Text: White color with regular size
  /// - Shadow: Subtle black shadow for depth
  /// - Position: 80px from bottom (or above keyboard)
  ///
  /// Parameters:
  /// - [context]: BuildContext for overlay access
  /// - [message]: Message to display
  /// - [backgroundColor]: Background color (default: AppColors.iconPrimary)
  /// - [textColor]: Text color (default: Colors.white)
  /// - [bottomPosition]: Distance from bottom (default: 80)
  /// - [duration]: How long to show the snackbar (default: 1 second)
  static Future<void> showCustom(
    BuildContext context,
    String message, {
    Color? backgroundColor,
    Color textColor = Colors.white,
    double bottomPosition = 80,
    Duration duration = const Duration(seconds: 1),
  }) {
    return _showSnackbarCustom(
      context,
      message,
      backgroundColor: backgroundColor ?? AppColors.iconPrimary,
      textColor: textColor,
      bottomPosition: bottomPosition,
      duration: duration,
    );
  }

  /// Internal method for snackbar display with modern styling.
  ///
  /// This method creates a snackbar matching the gallery widget delete snackbar:
  /// - Solid background color (no transparency)
  /// - Box shadow for depth
  /// - No border
  /// - Positioned at specified distance from bottom
  static Future<void> _showSnackbarCustom(
    BuildContext context,
    String message, {
    required Color backgroundColor,
    required Color textColor,
    required double bottomPosition,
    required Duration duration,
  }) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final viewInsets = mediaQuery.viewInsets.bottom;
    final bottomSafe = mediaQuery.padding.bottom;

    final responsive = ResponsiveSize(
      context: context,
      constraints: BoxConstraints(maxWidth: screenWidth),
      breakpoint: DeviceBreakpoint.fromWidth(screenWidth),
    );

    // Calculate bottom margin
    final bottomMargin =
        (viewInsets > 0 ? viewInsets : bottomPosition) + bottomSafe;

    // Custom widget with modern styling
    final customWidget = Container(
      padding: EdgeInsets.symmetric(
        // Slightly reduced horizontal padding for a more compact look
        horizontal: responsive.spacing(8),
        vertical: responsive.spacing(8),
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(responsive.size(8)),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 0, offset: Offset(0, 2)),
        ],
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: AppTextSizes.regular(
          context,
        ).copyWith(color: textColor, height: 1.1),
      ),
    );

    final snackBar = SnackBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      content: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.max,
        children: [Flexible(child: customWidget)],
      ),
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.only(
        bottom: bottomMargin,
        left: responsive.spacing(20),
        right: responsive.spacing(20),
      ),
      padding: EdgeInsets.zero,
      duration: duration,
    );

    final controller = ScaffoldMessenger.of(context).showSnackBar(snackBar);
    return controller.closed.then((_) => null);
  }

  /// Internal method for showing offline warning at top of screen.
  ///
  /// This method uses Overlay to display a warning at the top of the screen
  /// with a WiFi off icon, specifically for offline scenarios.
  static void _showTopWarning(
    BuildContext context,
    String message, {
    required Duration duration,
    IconData icon = Icons.wifi_off,
  }) {
    // Try to grab any available overlay; if none, fall back to bottom snackbar
    final overlay =
        Overlay.maybeOf(context, rootOverlay: true) ?? Overlay.maybeOf(context);
    if (overlay == null) {
      // Fallback: show a bottom warning snackbar to ensure the user sees something
      AppSnackbar.showWarning(context, message, duration: duration);
      return;
    }

    // Remove any existing top warning to avoid stacking
    _topWarningTimer?.cancel();
    _topWarningEntry?.remove();
    _topWarningEntry = null;

    _topWarningEntry = OverlayEntry(
      builder: (ctx) {
        final paddingTop = MediaQuery.of(ctx).padding.top + 40;
        final width = MediaQuery.of(ctx).size.width;

        final responsive = ResponsiveSize(
          context: ctx,
          constraints: BoxConstraints(maxWidth: width),
          breakpoint: DeviceBreakpoint.fromWidth(width),
        );
        return Positioned(
          top: paddingTop,
          left: 12,
          right: 12,
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: BoxConstraints(maxWidth: responsive.contentMaxWidth),
              padding: EdgeInsets.symmetric(
                horizontal: responsive.spacing(14),
                vertical: responsive.spacing(8),
              ),
              decoration: BoxDecoration(
                color: AppColors.iconPrimary,
                borderRadius: BorderRadius.circular(responsive.size(10)),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 0,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: Colors.white, size: responsive.size(24)),
                  SizedBox(width: responsive.spacing(8)),
                  Expanded(
                    child: Text(
                      message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextSizes.regular(
                        ctx,
                      ).copyWith(color: Colors.white, height: 1.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(_topWarningEntry!);
    _topWarningTimer = Timer(duration, () {
      _topWarningEntry?.remove();
      _topWarningEntry = null;
      _topWarningTimer = null;
    });
  }
}
