import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/core/themes/app_dimensions.dart';

/// Centralized theme configuration for ChatAway+ app
/// Provides light and dark theme with consistent styling across all widgets
class AppTheme {
  AppTheme._(); // Private constructor to prevent instantiation

  // ═══════════════════════════════════════════════════════════════════════════
  // LIGHT THEME
  // ═══════════════════════════════════════════════════════════════════════════

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,

      // ─────────────────────────────────────────────────────────────────────
      // COLOR SCHEME
      // ─────────────────────────────────────────────────────────────────────
      colorScheme: ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: AppColors.colorWhite,
        secondary: AppColors.primaryLight,
        onSecondary: AppColors.colorWhite,
        error: AppColors.error,
        onError: AppColors.colorWhite,
        surface: AppColors.colorWhite,
        onSurface: AppColors.colorBlack,
        surfaceContainerHighest: AppColors.greyLightest,
      ),

      // ─────────────────────────────────────────────────────────────────────
      // SCAFFOLD
      // ─────────────────────────────────────────────────────────────────────
      scaffoldBackgroundColor: AppColors.colorWhite,

      // ─────────────────────────────────────────────────────────────────────
      // APP BAR THEME
      // ─────────────────────────────────────────────────────────────────────
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor:
            AppColors.colorWhite, // Consistent block color for light theme
        foregroundColor: AppColors.colorBlack,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: Colors.white,
          systemNavigationBarDividerColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.dark,
          systemNavigationBarContrastEnforced: false,
        ),
        iconTheme: IconThemeData(
          color: AppColors.colorBlack,
          size: AppDimensions.iconSizeMedium,
        ),
        actionsIconTheme: IconThemeData(
          color: AppColors.colorBlack,
          size: AppDimensions.iconSizeMedium,
        ),
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.colorBlack,
        ),
      ),

      // ─────────────────────────────────────────────────────────────────────
      // ELEVATED BUTTON THEME
      // ─────────────────────────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.colorWhite,
          disabledBackgroundColor: AppColors.greyLight,
          disabledForegroundColor: AppColors.greyTextSecondary,
          elevation: AppDimensions.elevationMedium,
          shadowColor: AppColors.colorBlack.withValues(alpha: 0.1),
          padding: AppDimensions.buttonPadding,
          minimumSize: const Size(double.infinity, AppDimensions.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: AppDimensions.borderRadiusMedium,
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),

      // ─────────────────────────────────────────────────────────────────────
      // TEXT BUTTON THEME
      // ─────────────────────────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          disabledForegroundColor: AppColors.greyTextSecondary,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacingMedium,
            vertical: AppDimensions.spacingSmall,
          ),
        ),
      ),

      // ─────────────────────────────────────────────────────────────────────
      // OUTLINED BUTTON THEME
      // ─────────────────────────────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          disabledForegroundColor: AppColors.greyTextSecondary,
          side: const BorderSide(
            color: AppColors.primary,
            width: AppDimensions.borderWidth,
          ),
          padding: AppDimensions.buttonPadding,
          minimumSize: const Size(double.infinity, AppDimensions.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: AppDimensions.borderRadiusMedium,
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),

      // ─────────────────────────────────────────────────────────────────────
      // INPUT DECORATION THEME (TextFields)
      // ─────────────────────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.greyLightest,
        contentPadding: AppDimensions.inputPadding,

        // Border - Default state
        border: OutlineInputBorder(
          borderRadius: AppDimensions.borderRadiusMedium,
          borderSide: BorderSide.none,
        ),

        // Border - Enabled state
        enabledBorder: OutlineInputBorder(
          borderRadius: AppDimensions.borderRadiusMedium,
          borderSide: const BorderSide(
            color: AppColors.greyLight,
            width: AppDimensions.borderWidth,
          ),
        ),

        // Border - Focused state
        focusedBorder: OutlineInputBorder(
          borderRadius: AppDimensions.borderRadiusMedium,
          borderSide: const BorderSide(
            color: AppColors.primary,
            width: AppDimensions.borderWidthThick,
          ),
        ),

        // Border - Error state
        errorBorder: OutlineInputBorder(
          borderRadius: AppDimensions.borderRadiusMedium,
          borderSide: const BorderSide(
            color: AppColors.error,
            width: AppDimensions.borderWidth,
          ),
        ),

        // Border - Focused error state
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppDimensions.borderRadiusMedium,
          borderSide: const BorderSide(
            color: AppColors.error,
            width: AppDimensions.borderWidthThick,
          ),
        ),

        // Border - Disabled state
        disabledBorder: OutlineInputBorder(
          borderRadius: AppDimensions.borderRadiusMedium,
          borderSide: const BorderSide(
            color: AppColors.greyLight,
            width: AppDimensions.borderWidth,
          ),
        ),

        // Label style
        labelStyle: const TextStyle(
          fontSize: 16,
          color: AppColors.greyTextSecondary,
        ),

        // Hint style
        hintStyle: const TextStyle(
          fontSize: 16,
          color: AppColors.greyTextSecondary,
        ),

        // Error style
        errorStyle: const TextStyle(fontSize: 12, color: AppColors.error),

        // Helper style
        helperStyle: const TextStyle(
          fontSize: 12,
          color: AppColors.greyTextSecondary,
        ),

        // Prefix icon
        prefixIconColor: AppColors.iconSecondary,

        // Suffix icon
        suffixIconColor: AppColors.iconSecondary,
      ),

      // ─────────────────────────────────────────────────────────────────────
      // CARD THEME
      // ─────────────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        elevation: AppDimensions.elevationLow,
        color: AppColors.colorWhite,
        shadowColor: AppColors.colorBlack.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(
          borderRadius: AppDimensions.borderRadiusMedium,
        ),
        margin: const EdgeInsets.all(AppDimensions.spacingSmall),
      ),

      // ─────────────────────────────────────────────────────────────────────
      // DIVIDER THEME
      // ─────────────────────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: AppColors.greyLight,
        thickness: AppDimensions.dividerStandard,
        space: AppDimensions.spacingMedium,
      ),

      // ─────────────────────────────────────────────────────────────────────
      // BOTTOM NAVIGATION BAR THEME
      // ─────────────────────────────────────────────────────────────────────
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.colorWhite,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.iconSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: AppDimensions.elevationMedium,
        selectedIconTheme: IconThemeData(size: AppDimensions.iconSizeMedium),
        unselectedIconTheme: IconThemeData(size: AppDimensions.iconSizeMedium),
        selectedLabelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.normal,
        ),
      ),

      // ─────────────────────────────────────────────────────────────────────
      // DIALOG THEME
      // ─────────────────────────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.colorWhite,
        elevation: AppDimensions.elevationHigh,
        shape: RoundedRectangleBorder(
          borderRadius: AppDimensions.borderRadiusLarge,
        ),
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.colorBlack,
        ),
        contentTextStyle: const TextStyle(
          fontSize: 16,
          color: AppColors.greyTextPrimary,
        ),
      ),

      // ─────────────────────────────────────────────────────────────────────
      // SNACKBAR THEME
      // ─────────────────────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.iconPrimary,
        contentTextStyle: const TextStyle(
          fontSize: 14,
          color: AppColors.colorWhite,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: AppDimensions.borderRadiusSmall,
        ),
      ),

      // ─────────────────────────────────────────────────────────────────────
      // FLOATING ACTION BUTTON THEME
      // ─────────────────────────────────────────────────────────────────────
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.colorWhite,
        elevation: AppDimensions.elevationHigh,
        shape: CircleBorder(),
      ),

      // ─────────────────────────────────────────────────────────────────────
      // ICON THEME
      // ─────────────────────────────────────────────────────────────────────
      iconTheme: const IconThemeData(
        color: AppColors.iconPrimary,
        size: AppDimensions.iconSizeMedium,
      ),

      // ─────────────────────────────────────────────────────────────────────
      // CHIP THEME
      // ─────────────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.greyLightest,
        disabledColor: AppColors.greyLight,
        selectedColor: AppColors.primary.withValues(alpha: 0.1),
        secondarySelectedColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacingMedium,
          vertical: AppDimensions.spacingSmall,
        ),
        labelStyle: const TextStyle(
          fontSize: 14,
          color: AppColors.greyTextPrimary,
        ),
        secondaryLabelStyle: const TextStyle(
          fontSize: 14,
          color: AppColors.primary,
        ),
        brightness: Brightness.light,
        shape: RoundedRectangleBorder(
          borderRadius: AppDimensions.borderRadiusSmall,
        ),
      ),

      // ─────────────────────────────────────────────────────────────────────
      // SWITCH THEME
      // ─────────────────────────────────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.colorWhite;
          }
          return AppColors.greyLight;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary;
          }
          return AppColors.greyLight;
        }),
      ),

      // ─────────────────────────────────────────────────────────────────────
      // CHECKBOX THEME
      // ─────────────────────────────────────────────────────────────────────
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(AppColors.colorWhite),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusSmall / 2),
        ),
      ),

      // ─────────────────────────────────────────────────────────────────────
      // RADIO THEME
      // ─────────────────────────────────────────────────────────────────────
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary;
          }
          return AppColors.greyLight;
        }),
      ),

      // ─────────────────────────────────────────────────────────────────────
      // PROGRESS INDICATOR THEME
      // ─────────────────────────────────────────────────────────────────────
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.greyLight,
        circularTrackColor: AppColors.greyLight,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DARK THEME
  // ═══════════════════════════════════════════════════════════════════════════

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      // ─────────────────────────────────────────────────────────────────────
      // COLOR SCHEME
      // ─────────────────────────────────────────────────────────────────────
      colorScheme: ColorScheme.dark(
        primary: AppColors.primary,
        onPrimary: AppColors.colorWhite,
        secondary: AppColors.primaryLight,
        onSecondary: AppColors.colorWhite,
        error: AppColors.error,
        onError: AppColors.colorWhite,
        surface: const Color(0xFF1E1E1E), // Same as scaffold/AppBar
        onSurface: AppColors.colorWhite,
        surfaceContainerHighest: const Color(0xFF1E1E1E),
      ),

      // ─────────────────────────────────────────────────────────────────────
      // SCAFFOLD
      // ─────────────────────────────────────────────────────────────────────
      scaffoldBackgroundColor: const Color(
        0xFF1E1E1E,
      ), // Same as AppBar for consistent look
      // ─────────────────────────────────────────────────────────────────────
      // APP BAR THEME
      // ─────────────────────────────────────────────────────────────────────
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Color(
          0xFF1E1E1E,
        ), // Consistent block color throughout app
        foregroundColor: AppColors.colorWhite,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: Color(0xFF1E1E1E),
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        iconTheme: IconThemeData(
          color: AppColors.colorWhite,
          size: AppDimensions.iconSizeMedium,
        ),
        actionsIconTheme: IconThemeData(
          color: AppColors.colorWhite,
          size: AppDimensions.iconSizeMedium,
        ),
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.colorWhite,
        ),
      ),

      // ─────────────────────────────────────────────────────────────────────
      // ELEVATED BUTTON THEME
      // ─────────────────────────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.colorWhite,
          disabledBackgroundColor: const Color(0xFF2C2C2C),
          disabledForegroundColor: const Color(0xFF666666),
          elevation: AppDimensions.elevationMedium,
          shadowColor: Colors.black.withValues(alpha: 0.3),
          padding: AppDimensions.buttonPadding,
          minimumSize: const Size(double.infinity, AppDimensions.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: AppDimensions.borderRadiusMedium,
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),

      // ─────────────────────────────────────────────────────────────────────
      // TEXT BUTTON THEME
      // ─────────────────────────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          disabledForegroundColor: const Color(0xFF666666),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacingMedium,
            vertical: AppDimensions.spacingSmall,
          ),
        ),
      ),

      // ─────────────────────────────────────────────────────────────────────
      // OUTLINED BUTTON THEME
      // ─────────────────────────────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          disabledForegroundColor: const Color(0xFF666666),
          side: const BorderSide(
            color: AppColors.primary,
            width: AppDimensions.borderWidth,
          ),
          padding: AppDimensions.buttonPadding,
          minimumSize: const Size(double.infinity, AppDimensions.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: AppDimensions.borderRadiusMedium,
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),

      // ─────────────────────────────────────────────────────────────────────
      // INPUT DECORATION THEME (TextFields)
      // ─────────────────────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1E1E1E),
        contentPadding: AppDimensions.inputPadding,

        // Border - Default state
        border: OutlineInputBorder(
          borderRadius: AppDimensions.borderRadiusMedium,
          borderSide: BorderSide.none,
        ),

        // Border - Enabled state
        enabledBorder: OutlineInputBorder(
          borderRadius: AppDimensions.borderRadiusMedium,
          borderSide: const BorderSide(
            color: Color(0xFF2C2C2C),
            width: AppDimensions.borderWidth,
          ),
        ),

        // Border - Focused state
        focusedBorder: OutlineInputBorder(
          borderRadius: AppDimensions.borderRadiusMedium,
          borderSide: const BorderSide(
            color: AppColors.primary,
            width: AppDimensions.borderWidthThick,
          ),
        ),

        // Border - Error state
        errorBorder: OutlineInputBorder(
          borderRadius: AppDimensions.borderRadiusMedium,
          borderSide: const BorderSide(
            color: AppColors.error,
            width: AppDimensions.borderWidth,
          ),
        ),

        // Border - Focused error state
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppDimensions.borderRadiusMedium,
          borderSide: const BorderSide(
            color: AppColors.error,
            width: AppDimensions.borderWidthThick,
          ),
        ),

        // Border - Disabled state
        disabledBorder: OutlineInputBorder(
          borderRadius: AppDimensions.borderRadiusMedium,
          borderSide: const BorderSide(
            color: Color(0xFF2C2C2C),
            width: AppDimensions.borderWidth,
          ),
        ),

        // Label style
        labelStyle: const TextStyle(fontSize: 16, color: Color(0xFF9E9E9E)),

        // Hint style
        hintStyle: const TextStyle(fontSize: 16, color: Color(0xFF9E9E9E)),

        // Error style
        errorStyle: const TextStyle(fontSize: 12, color: AppColors.error),

        // Helper style
        helperStyle: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),

        // Prefix icon
        prefixIconColor: const Color(0xFF9E9E9E),

        // Suffix icon
        suffixIconColor: const Color(0xFF9E9E9E),
      ),

      // ─────────────────────────────────────────────────────────────────────
      // CARD THEME
      // ─────────────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        elevation: AppDimensions.elevationLow,
        color: const Color(0xFF1E1E1E),
        shadowColor: Colors.black.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: AppDimensions.borderRadiusMedium,
        ),
        margin: const EdgeInsets.all(AppDimensions.spacingSmall),
      ),

      // ─────────────────────────────────────────────────────────────────────
      // DIVIDER THEME
      // ─────────────────────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: Color(0xFF2C2C2C),
        thickness: AppDimensions.dividerStandard,
        space: AppDimensions.spacingMedium,
      ),

      // ─────────────────────────────────────────────────────────────────────
      // BOTTOM NAVIGATION BAR THEME
      // ─────────────────────────────────────────────────────────────────────
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF1E1E1E),
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Color(0xFF9E9E9E),
        type: BottomNavigationBarType.fixed,
        elevation: AppDimensions.elevationMedium,
        selectedIconTheme: IconThemeData(size: AppDimensions.iconSizeMedium),
        unselectedIconTheme: IconThemeData(size: AppDimensions.iconSizeMedium),
        selectedLabelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.normal,
        ),
      ),

      // ─────────────────────────────────────────────────────────────────────
      // DIALOG THEME
      // ─────────────────────────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: AppDimensions.elevationHigh,
        shape: RoundedRectangleBorder(
          borderRadius: AppDimensions.borderRadiusLarge,
        ),
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.colorWhite,
        ),
        contentTextStyle: const TextStyle(
          fontSize: 16,
          color: Color(0xFFE0E0E0),
        ),
      ),

      // ─────────────────────────────────────────────────────────────────────
      // SNACKBAR THEME
      // ─────────────────────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF2C2C2C),
        contentTextStyle: const TextStyle(
          fontSize: 14,
          color: AppColors.colorWhite,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: AppDimensions.borderRadiusSmall,
        ),
      ),

      // ─────────────────────────────────────────────────────────────────────
      // FLOATING ACTION BUTTON THEME
      // ─────────────────────────────────────────────────────────────────────
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.colorWhite,
        elevation: AppDimensions.elevationHigh,
        shape: CircleBorder(),
      ),

      // ─────────────────────────────────────────────────────────────────────
      // ICON THEME
      // ─────────────────────────────────────────────────────────────────────
      iconTheme: const IconThemeData(
        color: AppColors.colorWhite,
        size: AppDimensions.iconSizeMedium,
      ),

      // ─────────────────────────────────────────────────────────────────────
      // CHIP THEME
      // ─────────────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFF2C2C2C),
        disabledColor: const Color(0xFF1E1E1E),
        selectedColor: AppColors.primary.withValues(alpha: 0.2),
        secondarySelectedColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacingMedium,
          vertical: AppDimensions.spacingSmall,
        ),
        labelStyle: const TextStyle(fontSize: 14, color: Color(0xFFE0E0E0)),
        secondaryLabelStyle: const TextStyle(
          fontSize: 14,
          color: AppColors.primary,
        ),
        brightness: Brightness.dark,
        shape: RoundedRectangleBorder(
          borderRadius: AppDimensions.borderRadiusSmall,
        ),
      ),

      // ─────────────────────────────────────────────────────────────────────
      // SWITCH THEME
      // ─────────────────────────────────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.colorWhite;
          }
          return const Color(0xFF666666);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary;
          }
          return const Color(0xFF2C2C2C);
        }),
      ),

      // ─────────────────────────────────────────────────────────────────────
      // CHECKBOX THEME
      // ─────────────────────────────────────────────────────────────────────
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(AppColors.colorWhite),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusSmall / 2),
        ),
      ),

      // ─────────────────────────────────────────────────────────────────────
      // RADIO THEME
      // ─────────────────────────────────────────────────────────────────────
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary;
          }
          return const Color(0xFF666666);
        }),
      ),

      // ─────────────────────────────────────────────────────────────────────
      // PROGRESS INDICATOR THEME
      // ─────────────────────────────────────────────────────────────────────
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: Color(0xFF2C2C2C),
        circularTrackColor: Color(0xFF2C2C2C),
      ),
    );
  }
}
