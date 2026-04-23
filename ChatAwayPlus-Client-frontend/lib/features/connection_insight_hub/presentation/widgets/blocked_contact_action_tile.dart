import 'dart:io';

import 'package:chataway_plus/core/dialog_box/app_dialog_box.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:chataway_plus/core/snackbar/app_snackbar.dart';
import 'package:chataway_plus/core/themes/app_text_styles.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/features/blocked_contacts/presentation/providers/blocked_contacts/blocked_contacts_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BlockedContactActionTile extends ConsumerWidget {
  const BlockedContactActionTile({
    super.key,
    required this.contactId,
    required this.contactName,
  });

  final String contactId;
  final String contactName;

  ResponsiveSize _responsiveFor(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return ResponsiveSize(
      context: context,
      constraints: BoxConstraints(maxWidth: width),
      breakpoint: DeviceBreakpoint.fromWidth(width),
    );
  }

  Future<bool?> _showConfirm({
    required BuildContext context,
    required String title,
    required String message,
    required String confirmText,
    required Color confirmColor,
  }) {
    final responsive = _responsiveFor(context);

    return AppDialogBox.show<bool>(
      context,
      title: title,
      message: message,
      buttons: const [],
      barrierDismissible: false,
      dialogWidth: responsive.size(295),
      titleColor: confirmColor,
      titleAlignment: TextAlign.left,
      messageAlignment: TextAlign.left,
      contentAlignment: CrossAxisAlignment.start,
      customActions: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.colorGrey,
              padding: EdgeInsets.symmetric(
                horizontal: responsive.spacing(16),
                vertical: responsive.spacing(10),
              ),
            ),
            child: Text(
              'Cancel',
              style: AppTextSizes.regular(context).copyWith(
                fontWeight: FontWeight.w500,
                color: AppColors.colorGrey,
              ),
            ),
          ),
          SizedBox(width: responsive.spacing(8)),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              foregroundColor: Colors.white,
              elevation: 1,
              padding: EdgeInsets.symmetric(
                horizontal: responsive.spacing(24),
                vertical: responsive.spacing(10),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(responsive.size(6)),
              ),
              minimumSize: Size(responsive.spacing(40), responsive.size(40)),
            ),
            child: Text(
              confirmText,
              style: AppTextSizes.regular(
                context,
              ).copyWith(fontWeight: FontWeight.w500, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final blockedAsync = ref.watch(isUserBlockedProvider(contactId));

    final isBlocked = blockedAsync.maybeWhen(
      data: (v) => v,
      orElse: () => false,
    );

    Future<void> handleTap() async {
      final name = contactName.trim().isNotEmpty
          ? contactName.trim()
          : 'this contact';

      if (isBlocked) {
        final confirmed = await _showConfirm(
          context: context,
          title: 'Unblock Contact',
          message: 'Do you want to unblock $name?',
          confirmText: 'Unblock',
          confirmColor: AppColors.primary,
        );
        if (confirmed != true) return;

        if (context.mounted) {
          AppSnackbar.showCustom(
            context,
            'Unblocking...',
            bottomPosition: 120,
            duration: const Duration(seconds: 1),
          );
        }

        try {
          final result = await ref
              .read(blockedContactsNotifierProvider.notifier)
              .unblockUser(contactId);
          if (context.mounted) {
            if (result.isSuccess) {
              ref.invalidate(blockedUserIdsLocalProvider);
              AppSnackbar.showSuccess(
                context,
                result.message.isNotEmpty ? result.message : 'Unblocked $name',
                bottomPosition: 120,
                duration: const Duration(seconds: 2),
              );
            } else {
              AppSnackbar.showError(
                context,
                result.message.isNotEmpty
                    ? result.message
                    : 'Failed to unblock user. Please try again.',
                bottomPosition: 120,
              );
            }
          }
        } on SocketException {
          if (context.mounted) {
            AppSnackbar.showOfflineWarning(
              context,
              "You're offline. Check your connection",
            );
          }
        } catch (_) {
          if (context.mounted) {
            AppSnackbar.showError(
              context,
              'Failed to unblock user. Please try again.',
              bottomPosition: 120,
            );
          }
        }

        return;
      }

      final confirmed = await _showConfirm(
        context: context,
        title: 'Block Contact',
        message:
            'Do you want to block $name? They will not be able to contact you.',
        confirmText: 'Block',
        confirmColor: AppColors.error,
      );
      if (confirmed != true) return;

      if (context.mounted) {
        AppSnackbar.showCustom(
          context,
          'Blocking...',
          bottomPosition: 120,
          duration: const Duration(seconds: 1),
        );
      }

      try {
        final result = await ref
            .read(blockedContactsNotifierProvider.notifier)
            .blockUser(contactId);
        if (context.mounted) {
          if (result.isSuccess) {
            ref.invalidate(blockedUserIdsLocalProvider);
            AppSnackbar.showSuccess(
              context,
              result.message.isNotEmpty ? result.message : 'Blocked $name',
              bottomPosition: 120,
              duration: const Duration(seconds: 2),
            );
          } else {
            AppSnackbar.showError(
              context,
              result.message.isNotEmpty
                  ? result.message
                  : 'Failed to block user. Please try again.',
              bottomPosition: 120,
            );
          }
        }
      } on SocketException {
        if (context.mounted) {
          AppSnackbar.showOfflineWarning(
            context,
            "You're offline. Check your connection",
          );
        }
      } catch (_) {
        if (context.mounted) {
          AppSnackbar.showError(
            context,
            'Failed to block user. Please try again.',
            bottomPosition: 120,
          );
        }
      }
    }

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        Icons.block,
        color: isDark ? Colors.white70 : AppColors.colorGrey,
      ),
      title: Text(
        'Blocked contact',
        style: AppTextSizes.regular(
          context,
        ).copyWith(color: isDark ? Colors.white : AppColors.colorBlack),
      ),
      subtitle: Text(
        blockedAsync.when(
          data: (blocked) => blocked ? 'Blocked' : 'Not blocked',
          loading: () => 'Checking...',
          error: (_, __) => 'Not blocked',
        ),
        style: AppTextSizes.small(
          context,
        ).copyWith(color: isDark ? Colors.white70 : AppColors.colorGrey),
      ),
      onTap: handleTap,
    );
  }
}
