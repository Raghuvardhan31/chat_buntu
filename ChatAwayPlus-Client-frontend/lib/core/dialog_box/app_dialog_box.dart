import 'package:flutter/material.dart';
import 'package:chataway_plus/core/themes/app_text_styles.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';

/// Global dialog utility for displaying consistent dialogs throughout the app.
///
/// Features:
/// - Optional icon with customizable color
/// - Title and message text with consistent styling
/// - Flexible buttons (1, 2, or more)
/// - Rounded corners and proper spacing
/// - Responsive sizing
///
/// Usage Examples:
/// ```dart
/// // Simple dialog with one button
/// AppDialogBox.show(
///   context,
///   title: 'Success',
///   message: 'Your profile has been updated',
///   buttons: [
///     DialogBoxButton(
///       text: 'OK',
///       onPressed: () => Navigator.pop(context),
///     ),
///   ],
/// );
///
/// // Dialog with icon and two buttons
/// AppDialogBox.show(
///   context,
///   icon: Icons.warning_amber_rounded,
///   iconColor: Colors.orange,
///   title: 'Delete Account',
///   message: 'Are you sure you want to delete your account? This action cannot be undone.',
///   buttons: [
///     DialogBoxButton(
///       text: 'Cancel',
///       onPressed: () => Navigator.pop(context),
///       isPrimary: false,
///     ),
///     DialogBoxButton(
///       text: 'Delete',
///       onPressed: () {
///         // Delete logic
///         Navigator.pop(context);
///       },
///       isPrimary: true,
///     ),
///   ],
/// );
///
/// // Dialog with custom icon widget
/// AppDialogBox.show(
///   context,
///   iconWidget: Icon(Icons.check_circle, color: Colors.green, size: 48),
///   title: 'Complete your profile',
///   message: 'To proceed, please add your Name and Share Your Voice.',
///   buttons: [
///     DialogBoxButton(
///       text: 'Complete Now',
///       onPressed: () => Navigator.pop(context),
///     ),
///   ],
/// );
/// ```
class AppDialogBox {
  /// Shows a dialog with the given parameters.
  ///
  /// Parameters:
  /// - [context]: BuildContext for dialog display
  /// - [title]: Dialog title (bold, large text)
  /// - [message]: Dialog message (regular text, can be multiline)
  /// - [buttons]: List of buttons to display (1 or more)
  /// - [icon]: Optional icon to display above title (IconData)
  /// - [iconColor]: Color for the icon (default: AppColors.primary)
  /// - [iconWidget]: Optional custom icon widget (overrides icon and iconColor)
  /// - [barrierDismissible]: Whether tapping outside dismisses dialog (default: true)
  /// - [dialogWidth]: Optional custom width (default: 295px for 375px screen)
  /// - [dialogHeight]: Optional custom height (default: auto based on content)
  /// - [titleColor]: Override the default title color
  /// - [titleAlignment]: Align title text (default center)
  /// - [messageAlignment]: Align message text (default center)
  /// - [customActions]: Optional widget rendered in place of the default buttons
  /// - [contentAlignment]: Optional cross-axis alignment for dialog content (defaults to center)
  /// - [customContent]: Optional widget rendered instead of the default message text
  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    required String message,
    required List<DialogBoxButton> buttons,
    IconData? icon,
    Color? iconColor,
    Widget? iconWidget,
    bool barrierDismissible = true,
    double? dialogWidth,
    double? dialogHeight,
    Color? titleColor,
    TextAlign titleAlignment = TextAlign.center,
    TextAlign messageAlignment = TextAlign.center,
    Widget? customActions,
    CrossAxisAlignment contentAlignment = CrossAxisAlignment.center,
    Widget? customContent,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => _AppDialogBoxContent(
        title: title,
        message: message,
        buttons: buttons,
        icon: icon,
        iconColor: iconColor,
        iconWidget: iconWidget,
        dialogWidth: dialogWidth,
        dialogHeight: dialogHeight,
        titleColor: titleColor,
        titleAlignment: titleAlignment,
        messageAlignment: messageAlignment,
        customActions: customActions,
        contentAlignment: contentAlignment,
        customContent: customContent,
      ),
    );
  }
}

/// Configuration for a dialog box button.
class DialogBoxButton {
  /// Button text
  final String text;

  /// Callback when button is pressed
  final VoidCallback onPressed;

  /// Whether this is a primary button (filled) or secondary (outlined)
  final bool isPrimary;

  /// Custom background color (overrides isPrimary)
  final Color? backgroundColor;

  /// Custom text color
  final Color? textColor;

  const DialogBoxButton({
    required this.text,
    required this.onPressed,
    this.isPrimary = true,
    this.backgroundColor,
    this.textColor,
  });
}

/// Internal widget for dialog box content.
class _AppDialogBoxContent extends StatelessWidget {
  final String title;
  final String message;
  final List<DialogBoxButton> buttons;
  final IconData? icon;
  final Color? iconColor;
  final Widget? iconWidget;
  final double? dialogWidth;
  final double? dialogHeight;
  final Color? titleColor;
  final TextAlign titleAlignment;
  final TextAlign messageAlignment;
  final Widget? customActions;
  final CrossAxisAlignment contentAlignment;
  final Widget? customContent;

  const _AppDialogBoxContent({
    required this.title,
    required this.message,
    required this.buttons,
    this.icon,
    this.iconColor,
    this.iconWidget,
    this.dialogWidth,
    this.dialogHeight,
    this.titleColor,
    this.titleAlignment = TextAlign.center,
    this.messageAlignment = TextAlign.center,
    this.customActions,
    this.contentAlignment = CrossAxisAlignment.center,
    this.customContent,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final responsive = ResponsiveSize(
      context: context,
      constraints: BoxConstraints(
        maxWidth: screenWidth,
        maxHeight: screenHeight,
      ),
      breakpoint: DeviceBreakpoint.fromWidth(screenWidth),
    );
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Calculate dialog dimensions
    final double defaultWidth = responsive.size(295);
    final double actualWidth = dialogWidth ?? defaultWidth;
    final double horizontalPadding = (screenWidth - actualWidth) / 2;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(responsive.size(16)),
      ),
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      insetPadding: EdgeInsets.symmetric(
        horizontal: horizontalPadding > 0
            ? horizontalPadding
            : responsive.spacing(40),
      ),
      child: SizedBox(
        width: actualWidth,
        height: dialogHeight, // null = auto height based on content
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: responsive.spacing(20),
            vertical: responsive.spacing(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: contentAlignment,
            children: [
              // Icon (if provided)
              if (iconWidget != null) ...[
                iconWidget!,
                SizedBox(height: responsive.spacing(16)),
              ] else if (icon != null) ...[
                Icon(
                  icon,
                  size: responsive.size(32),
                  color: iconColor ?? AppColors.primary,
                ),
                SizedBox(
                  height: responsive.spacing(12),
                ), // 12 px - tighter spacing
              ],

              // Title
              Text(
                title,
                textAlign: titleAlignment,
                style: AppTextSizes.large(context).copyWith(
                  fontWeight: FontWeight.bold,
                  color: titleColor ?? theme.colorScheme.onSurface,
                ),
              ),
              SizedBox(
                height: responsive.spacing(15),
              ), // 15 px - spacing after title
              // Message / custom content
              if (customContent != null)
                customContent!
              else
                Text(
                  message,
                  textAlign: messageAlignment,
                  style: AppTextSizes.regular(context).copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    height: 1.4,
                  ),
                ),
              SizedBox(
                height: responsive.spacing(16),
              ), // 16 px - tighter spacing before button
              // Buttons
              if (customActions != null)
                customActions!
              else if (buttons.length == 1)
                _buildSingleButton(context, buttons[0])
              else if (buttons.length == 2)
                _buildTwoButtons(context, buttons)
              else
                _buildMultipleButtons(context, buttons),
            ],
          ),
        ),
      ),
    );
  }

  /// Build a single full-width button
  Widget _buildSingleButton(BuildContext context, DialogBoxButton button) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final responsive = ResponsiveSize(
      context: context,
      constraints: BoxConstraints(
        maxWidth: screenWidth,
        maxHeight: screenHeight,
      ),
      breakpoint: DeviceBreakpoint.fromWidth(screenWidth),
    );

    return Center(
      child: SizedBox(
        width: responsive.size(180),
        child: ElevatedButton(
          onPressed: button.onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor:
                button.backgroundColor ??
                (button.isPrimary ? AppColors.primary : Colors.white),
            foregroundColor:
                button.textColor ??
                (button.isPrimary ? Colors.white : AppColors.primary),
            elevation: 1,
            padding: EdgeInsets.symmetric(vertical: responsive.spacing(12)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                responsive.size(25),
              ), // 25 px - more rounded
              side: button.isPrimary
                  ? BorderSide.none
                  : BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
          child: Text(
            button.text,
            style: AppTextSizes.regular(context).copyWith(
              fontWeight: FontWeight.w500,
              color:
                  button.textColor ??
                  (button.isPrimary ? Colors.white : AppColors.primary),
            ),
          ),
        ),
      ),
    );
  }

  /// Build two buttons side by side
  Widget _buildTwoButtons(BuildContext context, List<DialogBoxButton> buttons) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final responsive = ResponsiveSize(
      context: context,
      constraints: BoxConstraints(
        maxWidth: screenWidth,
        maxHeight: screenHeight,
      ),
      breakpoint: DeviceBreakpoint.fromWidth(screenWidth),
    );

    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: buttons[0].onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  buttons[0].backgroundColor ??
                  (buttons[0].isPrimary ? AppColors.primary : Colors.white),
              foregroundColor:
                  buttons[0].textColor ??
                  (buttons[0].isPrimary ? Colors.white : AppColors.primary),
              elevation: 0,
              padding: EdgeInsets.symmetric(vertical: responsive.spacing(14)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(responsive.size(8)), // 8 px
                side: buttons[0].isPrimary
                    ? BorderSide.none
                    : BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
            child: Text(
              buttons[0].text,
              style: AppTextSizes.regular(context).copyWith(
                fontWeight: FontWeight.w600,
                color:
                    buttons[0].textColor ??
                    (buttons[0].isPrimary ? Colors.white : AppColors.primary),
              ),
            ),
          ),
        ),
        SizedBox(width: responsive.spacing(12)), // 12 px
        Expanded(
          child: ElevatedButton(
            onPressed: buttons[1].onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  buttons[1].backgroundColor ??
                  (buttons[1].isPrimary ? AppColors.primary : Colors.white),
              foregroundColor:
                  buttons[1].textColor ??
                  (buttons[1].isPrimary ? Colors.white : AppColors.primary),
              elevation: 0,
              padding: EdgeInsets.symmetric(vertical: responsive.spacing(14)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(responsive.size(8)), // 8 px
                side: buttons[1].isPrimary
                    ? BorderSide.none
                    : BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
            child: Text(
              buttons[1].text,
              style: AppTextSizes.regular(context).copyWith(
                fontWeight: FontWeight.w600,
                color:
                    buttons[1].textColor ??
                    (buttons[1].isPrimary ? Colors.white : AppColors.primary),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Build multiple buttons stacked vertically
  Widget _buildMultipleButtons(
    BuildContext context,
    List<DialogBoxButton> buttons,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final responsive = ResponsiveSize(
      context: context,
      constraints: BoxConstraints(
        maxWidth: screenWidth,
        maxHeight: screenHeight,
      ),
      breakpoint: DeviceBreakpoint.fromWidth(screenWidth),
    );

    return Column(
      children: buttons.map((button) {
        final isLast = button == buttons.last;
        return Column(
          children: [
            ElevatedButton(
              onPressed: button.onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    button.backgroundColor ??
                    (button.isPrimary ? AppColors.primary : Colors.white),
                foregroundColor:
                    button.textColor ??
                    (button.isPrimary ? Colors.white : AppColors.primary),
                elevation: 0,
                padding: EdgeInsets.symmetric(vertical: responsive.spacing(14)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    responsive.size(8),
                  ), // 8 px
                  side: button.isPrimary
                      ? BorderSide.none
                      : BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
              child: Text(
                button.text,
                style: AppTextSizes.regular(context).copyWith(
                  fontWeight: FontWeight.w600,
                  color:
                      button.textColor ??
                      (button.isPrimary ? Colors.white : AppColors.primary),
                ),
              ),
            ),
            if (!isLast) SizedBox(height: responsive.spacing(12)), // 12 px
          ],
        );
      }).toList(),
    );
  }
}
