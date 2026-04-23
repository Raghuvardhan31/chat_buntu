import 'package:flutter/material.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';

/// Centralized text size constants for ChatAway+ app
/// Inspired by WhatsApp and Instagram typography patterns
///
/// Base design resolution: 375x812 (iPhone 11 Pro)
/// All sizes are responsive and support accessibility text scaling
class AppTextSizes {
  AppTextSizes._(); // Private constructor to prevent instantiation

  static double _responsiveFontSize(BuildContext context, double baseFontSize) {
    final textScaler = MediaQuery.textScalerOf(context);
    final breakpoint = DeviceBreakpoint.fromWidth(
      MediaQuery.of(context).size.width,
    );

    return textScaler.scale(baseFontSize * breakpoint.sizeMultiplier);
  }

  /// Heading text - 20px
  /// Usage: Titles, headers, app bar titles
  /// Examples: "Edit Profile", "Settings", "ChatAway+"
  static TextStyle heading(BuildContext context) {
    return TextStyle(
      fontSize: _responsiveFontSize(context, 22),
      fontWeight: FontWeight.w600,
      height: 1.2,
    );
  }

  /// Large text - 18px
  /// Usage: Important content, main messages, prominent labels
  /// Examples: "Enter your name", "Phone number", main content
  static TextStyle large(BuildContext context) {
    return TextStyle(
      fontSize: _responsiveFontSize(context, 18),
      fontWeight: FontWeight.w600, // Normal weight for readability
      height: 1.0, // Increased height for better spacing
    );
  }

  /// Regular text - 16px (Default body text)
  /// Usage: Body content, descriptions, button text
  /// Examples: Descriptions, paragraph text, button labels
  static TextStyle regular(BuildContext context) {
    return TextStyle(
      fontSize: _responsiveFontSize(context, 16),
      fontWeight: FontWeight.w500, // Normal weight for readability
      height: 1.4,
    );
  }

  /// Small text - 14px
  /// Usage: Captions, timestamps, helper text, secondary info
  /// Examples: "Last updated", error messages, hints
  static TextStyle small(BuildContext context) {
    return TextStyle(
      fontSize: _responsiveFontSize(context, 14),
      fontWeight: FontWeight.w400,
      height: 1.5,
    );
  }

  /// Natural Text - 16px No Weight
  /// Usage: Status messages, natural Flutter appearance
  /// Examples: Available status options, message text with no forced weight
  static TextStyle natural(BuildContext context) {
    return TextStyle(
      fontSize: _responsiveFontSize(context, 16),
      // No fontWeight - let Flutter use natural system default
      height: 1.4,
    );
  }

  // Utility method for custom responsive text sizing
  /// Create custom text size with responsive scaling
  /// [baseFontSize] - Font size based on 375px width screen
  static TextStyle custom(
    BuildContext context,
    double baseFontSize, {
    FontWeight? fontWeight,
    double? height,
    Color? color,
  }) {
    return TextStyle(
      fontSize: _responsiveFontSize(context, baseFontSize),
      fontWeight: fontWeight ?? FontWeight.w400,
      height: height ?? 1.4,
      color: color,
    );
  }

  // Text size values for non-widget contexts (like calculations)
  /// Get responsive font size value without TextStyle
  /// [baseFontSize] - Font size based on 375px width screen
  static double getResponsiveSize(BuildContext context, double baseFontSize) {
    return _responsiveFontSize(context, baseFontSize);
  }

  // Predefined size constants
  static const double headingSize = 20.0; // 20px - Heading text
  static const double largeSize = 18.0; // 18px - Large text
  static const double regularSize = 16.0; // 16px - Regular text
  static const double smallSize = 14.0; // 14px - Small text
}
