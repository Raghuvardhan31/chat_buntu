// lib/features/auth/presentation/widgets/otp_input_field.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/core/themes/app_text_styles.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';

class OtpInputField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final int index;
  final Function(int index, String value) onChanged;
  final VoidCallback? onTap;
  final double? width;
  final double? borderWidth;
  final ResponsiveSize? responsive;

  const OtpInputField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.index,
    required this.onChanged,
    this.onTap,
    this.width,
    this.borderWidth,
    this.responsive,
  });

  @override
  Widget build(BuildContext context) {
    const baseBorderWidth = 1.0; // 1 px base

    final effectiveBorderWidth =
        borderWidth ?? (responsive?.size(1) ?? baseBorderWidth);

    final horizontalMargin = responsive?.spacing(10) ?? 10.0; // 10 px
    final verticalMargin = responsive?.spacing(10) ?? 10.0; // 10 px

    final fieldWidth = width ?? (responsive?.size(30) ?? 30.0); // 30 px

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: horizontalMargin,
        vertical: verticalMargin,
      ),
      child: SizedBox(
        width: fieldWidth,
        child: TextFormField(
          controller: controller,
          focusNode: focusNode,
          onTap: onTap,
          cursorColor: Colors.black,
          showCursor: true,
          style: AppTextSizes.regular(
            context,
          ).copyWith(fontWeight: FontWeight.bold, color: AppColors.colorBlack),
          textAlign: TextAlign.center,
          maxLength: 1,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            border: UnderlineInputBorder(
              borderSide: BorderSide(
                color: AppColors.colorGrey,
                width: effectiveBorderWidth, // 1 px
              ),
            ),
            counterText: "",
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: AppColors.primary,
                width: effectiveBorderWidth * 2, // 2 px
              ),
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: AppColors.colorGrey,
                width: effectiveBorderWidth, // 1 px
              ),
            ),
            errorBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: AppColors.error,
                width: effectiveBorderWidth * 2, // 2 px
              ),
            ),
          ),
          onChanged: (value) => onChanged(index, value),
        ),
      ),
    );
  }
}
