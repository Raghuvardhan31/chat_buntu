import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:chataway_plus/core/snackbar/app_snackbar.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/features/chat/models/chat_message_model.dart';
import 'package:chataway_plus/features/chat/presentation/providers/chat_page_providers/chat_page_notifier.dart';
import 'package:flutter/material.dart';

Future<void> showDeleteSelectionDialog({
  required BuildContext context,
  required ResponsiveSize responsive,
  required ChatPageNotifier chatNotifier,
  required int selectionCount,
  required Set<String> selectedMessageIds,
  required List<ChatMessageModel> selectedMessages,
}) async {
  const title = 'Delete messages?';
  final subtitle = selectionCount > 1
      ? 'Do you want to delete $selectionCount messages?'
      : 'Do you want to delete this message?';

  Future<void> handleDeleteFromBothPhones() async {
    final ids = selectedMessageIds.toList();
    final now = DateTime.now();
    const window = Duration(hours: 1);

    final hasExpired = selectedMessages.any(
      (m) => now.difference(m.createdAt) > window,
    );

    if (hasExpired) {
      Navigator.of(context).pop();
      await AppSnackbar.showWarning(
        context,
        'You can delete a message from both phones only within 1 hour.',
      );
      return;
    }

    debugPrint(
      '🗑️ [ChatUI] Delete-from-both confirmed for '
      '${ids.length} message(s): $ids',
    );

    Navigator.of(context).pop();

    await chatNotifier.deleteSelectedMessages(forEveryone: true);

    debugPrint(
      '🗑️ [ChatUI] deleteSelectedMessages(forEveryone: true) completed',
    );
  }

  Widget buildAction({
    required String label,
    required VoidCallback onTap,
    FontWeight fontWeight = FontWeight.w500,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: responsive.spacing(20),
          vertical: responsive.spacing(14),
        ),
        child: Align(
          alignment: Alignment.centerRight,
          child: Text(
            label,
            style: TextStyle(
              fontSize: responsive.size(16),
              color: AppColors.primary,
              fontWeight: fontWeight,
              textBaseline: TextBaseline.alphabetic,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ),
    );
  }

  await showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(responsive.size(18)),
        ),
        titlePadding: EdgeInsets.fromLTRB(
          responsive.spacing(20),
          responsive.spacing(20),
          responsive.spacing(20),
          0,
        ),
        contentPadding: EdgeInsets.zero,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: responsive.size(18),
                fontWeight: FontWeight.w700,
                color: Colors.red,
              ),
            ),
            SizedBox(height: responsive.spacing(6)),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: responsive.size(14),
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: responsive.spacing(4)),
            buildAction(
              label: 'Delete from both phones',
              fontWeight: FontWeight.w600,
              onTap: handleDeleteFromBothPhones,
            ),

            buildAction(
              label: 'Cancel',
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
    },
  );
}
