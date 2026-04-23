// lib/features/auth/presentation/widgets/get_otp_button.dart
import 'package:flutter/material.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/core/themes/app_text_styles.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';

class GetOtpButton extends StatelessWidget {
  final bool isLoading;
  final bool disabled;
  final VoidCallback onPressed;
  final ResponsiveSize? responsive;

  const GetOtpButton({
    super.key,
    required this.isLoading,
    required this.disabled,
    required this.onPressed,
    this.responsive,
  });

  @override
  Widget build(BuildContext context) {
    final verticalPadding = responsive?.spacing(14) ?? 14.0;
    final loaderSize = responsive?.size(24) ?? 24.0;
    final loaderStrokeWidth = responsive?.size(2.5) ?? 2.5;

    return ElevatedButton(
      onPressed: disabled ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(vertical: verticalPadding),
      ),
      child: isLoading
          ? SizedBox(
              width: loaderSize,
              height: loaderSize,
              child: CircularProgressIndicator(
                strokeWidth: loaderStrokeWidth,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Text(
              'GET OTP',
              style: AppTextSizes.regular(
                context,
              ).copyWith(fontWeight: FontWeight.bold, color: Colors.white),
            ),
    );
  }
}
