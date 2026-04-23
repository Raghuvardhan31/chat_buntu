// lib/features/auth/presentation/widgets/phone_number_input.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/core/themes/app_text_styles.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';

class PhoneNumberInput extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final ResponsiveSize? responsive;

  const PhoneNumberInput({
    super.key,
    required this.controller,
    this.focusNode,
    this.responsive,
  });

  @override
  Widget build(BuildContext context) {
    final verticalPadding = responsive?.spacing(15) ?? 15.0; // 15 px
    final horizontalPadding = responsive?.spacing(26) ?? 26.0; // 26 px

    final borderWidth1 = responsive?.size(1) ?? 1.0; // 1 px
    final borderWidth2 = responsive?.size(2) ?? 2.0; // 2 px

    return TextField(
      cursorColor: AppColors.primary,
      controller: controller,
      focusNode: focusNode,
      keyboardType: TextInputType.phone,
      textAlign: TextAlign.left,
      maxLength: 10,
      style: AppTextSizes.regular(
        context,
      ).copyWith(fontWeight: FontWeight.w500, color: AppColors.colorBlack),
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        filled: false,
        contentPadding: EdgeInsets.symmetric(
          vertical: verticalPadding,
          horizontal: horizontalPadding,
        ),
        prefixText: "+91 ",
        prefixStyle: AppTextSizes.regular(
          context,
        ).copyWith(fontWeight: FontWeight.bold, color: AppColors.colorBlack),
        counterText: "",
        border: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.grey, width: borderWidth1),
        ),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.grey, width: borderWidth1),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.primary, width: borderWidth2),
        ),
        errorBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.red, width: borderWidth1),
        ),
        focusedErrorBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.red, width: borderWidth2),
        ),
      ),
    );
  }
}
