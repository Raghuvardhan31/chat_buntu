import 'package:flutter/material.dart';
import 'package:chataway_plus/core/dialog_box/app_dialog_box.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';

/// Examples of how to use AppDialogBox throughout the app.
///
/// Copy these examples wherever you need to show a dialog box.

class AppDialogBoxExamples {
  /// Example 1: Simple success dialog with one button
  static void showSuccessDialog(BuildContext context) {
    AppDialogBox.show(
      context,
      icon: Icons.check_circle_rounded,
      iconColor: Colors.green,
      title: 'Success',
      message: 'Your profile has been updated successfully.',
      buttons: [
        DialogBoxButton(text: 'OK', onPressed: () => Navigator.pop(context)),
      ],
    );
  }

  /// Example 2: Complete profile dialog (like in the image)
  static void showCompleteProfileDialog(BuildContext context) {
    AppDialogBox.show(
      context,
      icon: Icons.warning_amber_rounded,
      iconColor: AppColors.warning,
      title: '"Complete your ChatAway+ profile"',
      message:
          'To proceed on ChatAway+, please add your Name and Share Your Voice.',
      barrierDismissible: false,
      buttons: [
        DialogBoxButton(
          text: 'Complete Now',
          onPressed: () {
            Navigator.pop(context);
            // Navigate to profile completion page
          },
        ),
      ],
    );
  }

  /// Example 3: Confirmation dialog with two buttons (Cancel + Confirm)
  static void showDeleteConfirmation(BuildContext context) {
    AppDialogBox.show(
      context,
      icon: Icons.delete_outline_rounded,
      iconColor: Colors.red,
      title: 'Delete Account',
      message:
          'Are you sure you want to delete your account? This action cannot be undone.',
      barrierDismissible: false,
      buttons: [
        DialogBoxButton(
          text: 'Cancel',
          onPressed: () => Navigator.pop(context),
          isPrimary: false,
        ),
        DialogBoxButton(
          text: 'Delete',
          onPressed: () {
            // Perform delete action
            Navigator.pop(context);
          },
          isPrimary: true,
        ),
      ],
    );
  }

  /// Example 4: Error dialog
  static void showErrorDialog(BuildContext context, String errorMessage) {
    AppDialogBox.show(
      context,
      icon: Icons.error_outline_rounded,
      iconColor: Colors.red,
      title: 'Error',
      message: errorMessage,
      buttons: [
        DialogBoxButton(text: 'OK', onPressed: () => Navigator.pop(context)),
      ],
    );
  }

  /// Example 5: Multiple options dialog (3+ buttons)
  static void showMultipleOptionsDialog(BuildContext context) {
    AppDialogBox.show(
      context,
      icon: Icons.info_outline_rounded,
      iconColor: Colors.blue,
      title: 'Choose an option',
      message: 'How would you like to proceed?',
      buttons: [
        DialogBoxButton(
          text: 'Option 1',
          onPressed: () {
            Navigator.pop(context);
            // Handle option 1
          },
        ),
        DialogBoxButton(
          text: 'Option 2',
          onPressed: () {
            Navigator.pop(context);
            // Handle option 2
          },
        ),
        DialogBoxButton(
          text: 'Cancel',
          onPressed: () => Navigator.pop(context),
          isPrimary: false,
        ),
      ],
    );
  }

  /// Example 6: Logout confirmation
  static void showLogoutDialog(BuildContext context) {
    AppDialogBox.show(
      context,
      icon: Icons.logout_rounded,
      iconColor: Colors.orange,
      title: 'Logout',
      message: 'Are you sure you want to logout from ChatAway+?',
      buttons: [
        DialogBoxButton(
          text: 'Cancel',
          onPressed: () => Navigator.pop(context),
          isPrimary: false,
        ),
        DialogBoxButton(
          text: 'Logout',
          onPressed: () {
            // Perform logout
            Navigator.pop(context);
          },
          isPrimary: true,
        ),
      ],
    );
  }

  /// Example 7: Permission required dialog
  static void showPermissionDialog(BuildContext context) {
    AppDialogBox.show(
      context,
      icon: Icons.security_rounded,
      iconColor: Colors.blue,
      title: 'Permission Required',
      message:
          'This feature requires camera permission to continue. Please grant access in settings.',
      barrierDismissible: false,
      buttons: [
        DialogBoxButton(
          text: 'Not Now',
          onPressed: () => Navigator.pop(context),
          isPrimary: false,
        ),
        DialogBoxButton(
          text: 'Open Settings',
          onPressed: () {
            Navigator.pop(context);
            // Open app settings
          },
          isPrimary: true,
        ),
      ],
    );
  }

  /// Example 8: Custom icon widget
  static void showCustomIconDialog(BuildContext context) {
    AppDialogBox.show(
      context,
      iconWidget: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.notifications_active_rounded,
          color: Colors.blue,
          size: 36,
        ),
      ),
      title: 'Enable Notifications',
      message: 'Get notified when you receive new messages and updates.',
      buttons: [
        DialogBoxButton(
          text: 'Maybe Later',
          onPressed: () => Navigator.pop(context),
          isPrimary: false,
        ),
        DialogBoxButton(
          text: 'Enable',
          onPressed: () {
            Navigator.pop(context);
            // Enable notifications
          },
          isPrimary: true,
        ),
      ],
    );
  }

  /// Example 9: Network error dialog
  static void showNetworkErrorDialog(BuildContext context) {
    AppDialogBox.show(
      context,
      icon: Icons.wifi_off_rounded,
      iconColor: Colors.grey,
      title: 'No Internet Connection',
      message: 'Please check your internet connection and try again.',
      buttons: [
        DialogBoxButton(
          text: 'Retry',
          onPressed: () {
            Navigator.pop(context);
            // Retry action
          },
        ),
      ],
    );
  }

  /// Example 10: Update available dialog
  static void showUpdateDialog(BuildContext context) {
    AppDialogBox.show(
      context,
      icon: Icons.system_update_rounded,
      iconColor: Colors.green,
      title: 'Update Available',
      message:
          'A new version of ChatAway+ is available. Update now to get the latest features and improvements.',
      barrierDismissible: false,
      buttons: [
        DialogBoxButton(
          text: 'Later',
          onPressed: () => Navigator.pop(context),
          isPrimary: false,
        ),
        DialogBoxButton(
          text: 'Update Now',
          onPressed: () {
            Navigator.pop(context);
            // Open store for update
          },
          isPrimary: true,
        ),
      ],
    );
  }

  /// Example 11: Custom width dialog (wider)
  static void showWideDialog(BuildContext context) {
    AppDialogBox.show(
      context,
      icon: Icons.info_outline_rounded,
      iconColor: Colors.blue,
      title: 'Wide Dialog Example',
      message:
          'This dialog has a custom width of 320px, making it wider than the default.',
      dialogWidth: 320, // Custom width
      buttons: [
        DialogBoxButton(
          text: 'Got it',
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  /// Example 12: Custom width dialog (narrower)
  static void showNarrowDialog(BuildContext context) {
    AppDialogBox.show(
      context,
      icon: Icons.check_circle_rounded,
      iconColor: Colors.green,
      title: 'Narrow Dialog',
      message: 'This is a more compact dialog with 250px width.',
      dialogWidth: 250, // Custom narrower width
      buttons: [
        DialogBoxButton(text: 'OK', onPressed: () => Navigator.pop(context)),
      ],
    );
  }

  /// Example 13: Custom height dialog with scrollable content
  static void showFixedHeightDialog(BuildContext context) {
    AppDialogBox.show(
      context,
      icon: Icons.article_rounded,
      iconColor: Colors.orange,
      title: 'Terms and Conditions',
      message:
          'By using this app, you agree to our terms. This dialog has a fixed height of 400px.',
      dialogWidth: 300,
      dialogHeight: 400, // Fixed height - content will scroll if needed
      buttons: [
        DialogBoxButton(
          text: 'Decline',
          onPressed: () => Navigator.pop(context),
          isPrimary: false,
        ),
        DialogBoxButton(
          text: 'Accept',
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }
}
