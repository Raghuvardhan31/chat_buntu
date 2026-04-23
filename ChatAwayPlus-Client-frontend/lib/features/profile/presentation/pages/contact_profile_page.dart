import 'package:flutter/material.dart';

import '../../../../core/themes/colors/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';

/// Placeholder page shown when a user taps the profile icon in the
/// chat quick-action sheet. The design/content will be refined later.
class ContactProfilePage extends StatelessWidget {
  const ContactProfilePage({
    super.key,
    required this.contactName,
    required this.contactId,
    this.chatPictureUrl,
  });

  final String contactName;
  final String contactId;
  final String? chatPictureUrl;

  @override
  Widget build(BuildContext context) {
    final textTheme = AppTextSizes.large(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          contactName,
          style: AppTextSizes.regular(
            context,
          ).copyWith(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 48,
              backgroundColor: AppColors.greyLight,
              backgroundImage: chatPictureUrl != null
                  ? NetworkImage(chatPictureUrl!)
                  : null,
              child: chatPictureUrl == null
                  ? Icon(Icons.person, size: 48, color: AppColors.iconSecondary)
                  : null,
            ),
            const SizedBox(height: 16),
            Text(
              contactName,
              style: textTheme.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'User ID: $contactId',
              style: AppTextSizes.small(
                context,
              ).copyWith(color: AppColors.colorGrey),
            ),
            const SizedBox(height: 8),
            Text(
              'Contact profile details coming soon',
              style: AppTextSizes.small(
                context,
              ).copyWith(color: AppColors.colorGrey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
