import 'package:flutter/material.dart';
import 'package:chataway_plus/core/dialog_box/app_dialog_box_examples.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';

/// Demo page to test all AppDialogBox variations.
/// 
/// To use: Navigate to this page and tap each button to see the dialog box.
/// You can delete this file after testing or keep it for reference.
class AppDialogBoxDemoPage extends StatelessWidget {
  const AppDialogBoxDemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dialog Examples'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildButton(
            context,
            'Complete Profile Dialog',
            'Like the image you shared',
            () => AppDialogBoxExamples.showCompleteProfileDialog(context),
          ),
          _buildButton(
            context,
            'Success Dialog',
            'Single button',
            () => AppDialogBoxExamples.showSuccessDialog(context),
          ),
          _buildButton(
            context,
            'Delete Confirmation',
            'Two buttons side by side',
            () => AppDialogBoxExamples.showDeleteConfirmation(context),
          ),
          _buildButton(
            context,
            'Error Dialog',
            'With error icon',
            () => AppDialogBoxExamples.showErrorDialog(
              context,
              'Something went wrong. Please try again.',
            ),
          ),
          _buildButton(
            context,
            'Multiple Options',
            '3+ buttons stacked',
            () => AppDialogBoxExamples.showMultipleOptionsDialog(context),
          ),
          _buildButton(
            context,
            'Logout Dialog',
            'Confirmation with two buttons',
            () => AppDialogBoxExamples.showLogoutDialog(context),
          ),
          _buildButton(
            context,
            'Permission Dialog',
            'Request permissions',
            () => AppDialogBoxExamples.showPermissionDialog(context),
          ),
          _buildButton(
            context,
            'Custom Icon Widget',
            'With custom icon container',
            () => AppDialogBoxExamples.showCustomIconDialog(context),
          ),
          _buildButton(
            context,
            'Network Error',
            'No internet connection',
            () => AppDialogBoxExamples.showNetworkErrorDialog(context),
          ),
          _buildButton(
            context,
            'Update Available',
            'App update dialog',
            () => AppDialogBoxExamples.showUpdateDialog(context),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              'Custom Width & Height Examples',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          _buildButton(
            context,
            'Wide Dialog',
            'Custom width: 320px',
            () => AppDialogBoxExamples.showWideDialog(context),
          ),
          _buildButton(
            context,
            'Narrow Dialog',
            'Custom width: 250px',
            () => AppDialogBoxExamples.showNarrowDialog(context),
          ),
          _buildButton(
            context,
            'Fixed Height Dialog',
            'Custom width: 300px, height: 400px',
            () => AppDialogBoxExamples.showFixedHeightDialog(context),
          ),
          const SizedBox(height: 24),
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text(
              'Tap any button above to see the dialog.\n\n'
              'All dialogs use consistent styling from AppTextStyles and AppColors.\n\n'
              'You can customize width and height as needed.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButton(
    BuildContext context,
    String title,
    String description,
    VoidCallback onPressed,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(description),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onPressed,
      ),
    );
  }
}
