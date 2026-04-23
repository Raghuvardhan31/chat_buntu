import 'package:flutter/material.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';

/// Centralized dimension constants for ChatAway+ app
/// Provides consistent spacing, padding, sizing, and border radius values
/// Following Material Design spacing guidelines
class AppDimensions {
  AppDimensions._(); // Private constructor to prevent instantiation

  // ═══════════════════════════════════════════════════════════════════════════
  // SPACING & PADDING - Material Design 8dp grid system
  // ═══════════════════════════════════════════════════════════════════════════

  /// Extra small spacing - 4dp
  /// Usage: Tight spacing between related elements
  static const double spacingXs = 4.0;

  /// Small spacing - 8dp
  /// Usage: Small gaps, compact layouts
  static const double spacingSmall = 8.0;

  /// Medium spacing - 16dp
  /// Usage: Standard spacing between elements (most common)
  static const double spacingMedium = 16.0;

  /// Large spacing - 24dp
  /// Usage: Spacing between sections
  static const double spacingLarge = 24.0;

  /// Extra large spacing - 32dp
  /// Usage: Major section spacing
  static const double spacingXl = 32.0;

  /// XXL spacing - 48dp
  /// Usage: Top/bottom screen padding
  static const double spacingXxl = 48.0;

  // ═══════════════════════════════════════════════════════════════════════════
  // PADDING - Common padding values
  // ═══════════════════════════════════════════════════════════════════════════

  /// Page horizontal padding - 16dp
  /// Usage: Standard left/right padding for screens
  static const double pageHorizontalPadding = 16.0;

  /// Page vertical padding - 20dp
  /// Usage: Standard top/bottom padding for screens
  static const double pageVerticalPadding = 20.0;

  /// Card padding - 16dp
  /// Usage: Padding inside cards
  static const double cardPadding = 16.0;

  /// Button padding - 16dp vertical, 24dp horizontal
  /// Usage: Standard button padding
  static const EdgeInsets buttonPadding = EdgeInsets.symmetric(
    horizontal: 24.0,
    vertical: 16.0,
  );

  /// Input field padding - 16dp
  /// Usage: Padding inside text fields
  static const EdgeInsets inputPadding = EdgeInsets.all(16.0);

  /// List tile padding - 16dp horizontal, 12dp vertical
  /// Usage: Chat list items, contact list items
  static const EdgeInsets listTilePadding = EdgeInsets.symmetric(
    horizontal: 16.0,
    vertical: 12.0,
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // BORDER RADIUS - Corner rounding
  // ═══════════════════════════════════════════════════════════════════════════

  /// Small radius - 8dp
  /// Usage: Small cards, chips, tags
  static const double radiusSmall = 8.0;

  /// Medium radius - 12dp
  /// Usage: Buttons, text fields, cards (most common)
  static const double radiusMedium = 12.0;

  /// Large radius - 16dp
  /// Usage: Larger cards, bottom sheets
  static const double radiusLarge = 16.0;

  /// Extra large radius - 24dp
  /// Usage: Profile pictures, special elements
  static const double radiusXl = 24.0;

  /// Circular radius - 999dp
  /// Usage: Fully rounded elements (circles)
  static const double radiusCircular = 999.0;

  /// Border radius objects (commonly used)
  static final BorderRadius borderRadiusSmall = BorderRadius.circular(
    radiusSmall,
  );
  static final BorderRadius borderRadiusMedium = BorderRadius.circular(
    radiusMedium,
  );
  static final BorderRadius borderRadiusLarge = BorderRadius.circular(
    radiusLarge,
  );
  static final BorderRadius borderRadiusXl = BorderRadius.circular(radiusXl);
  static final BorderRadius borderRadiusCircular = BorderRadius.circular(
    radiusCircular,
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // SIZES - Common component sizes
  // ═══════════════════════════════════════════════════════════════════════════

  /// Button height - 50dp
  /// Usage: Standard button height
  static const double buttonHeight = 50.0;

  /// Button height small - 40dp
  /// Usage: Compact buttons
  static const double buttonHeightSmall = 40.0;

  /// Input field height - 56dp
  /// Usage: Standard text field height
  static const double inputHeight = 56.0;

  /// App bar height - 56dp
  /// Usage: Top app bar (default Flutter AppBar height)
  static const double appBarHeight = 56.0;

  /// Bottom navigation bar height - 60dp
  /// Usage: Bottom tab bar
  static const double bottomNavBarHeight = 60.0;

  /// Icon size small - 20dp
  /// Usage: Small icons in text, badges
  static const double iconSizeSmall = 20.0;

  /// Icon size medium - 24dp
  /// Usage: Standard icons (most common)
  static const double iconSizeMedium = 24.0;

  /// Icon size large - 32dp
  /// Usage: Larger action icons
  static const double iconSizeLarge = 32.0;

  /// Icon size XL - 48dp
  /// Usage: Feature icons, illustrations
  static const double iconSizeXl = 48.0;

  /// Profile picture size small - 40dp
  /// Usage: Small avatars in lists
  static const double profilePicSmall = 40.0;

  /// Profile picture size medium - 60dp
  /// Usage: Standard avatars
  static const double profilePicMedium = 60.0;

  /// Profile picture size large - 100dp
  /// Usage: Profile page avatar
  static const double profilePicLarge = 100.0;

  /// Profile picture size XL - 120dp
  /// Usage: Full screen profile picture
  static const double profilePicXl = 120.0;

  // ═══════════════════════════════════════════════════════════════════════════
  // ELEVATION - Material shadow depth
  // ═══════════════════════════════════════════════════════════════════════════

  /// No elevation
  static const double elevationNone = 0.0;

  /// Low elevation - 2dp
  /// Usage: Cards, raised elements
  static const double elevationLow = 2.0;

  /// Medium elevation - 4dp
  /// Usage: Buttons, important cards
  static const double elevationMedium = 4.0;

  /// High elevation - 8dp
  /// Usage: Floating action buttons, dialogs
  static const double elevationHigh = 8.0;

  // ═══════════════════════════════════════════════════════════════════════════
  // DIVIDER & BORDER - Line thickness
  // ═══════════════════════════════════════════════════════════════════════════

  /// Thin divider - 1dp
  /// Usage: Subtle separators
  static const double dividerThin = 1.0;

  /// Standard divider - 1dp
  /// Usage: List dividers, section separators
  static const double dividerStandard = 1.0;

  /// Thick divider - 2dp
  /// Usage: Emphasized separators
  static const double dividerThick = 2.0;

  /// Border width - 1dp
  /// Usage: Input borders, card borders
  static const double borderWidth = 1.0;

  /// Border width thick - 2dp
  /// Usage: Focused borders, active states
  static const double borderWidthThick = 2.0;

  // ═══════════════════════════════════════════════════════════════════════════
  // RESPONSIVE BREAKPOINTS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Mobile breakpoint - 600dp
  /// Usage: Small phones, portrait mode
  static const double breakpointMobile = 600.0;

  /// Tablet breakpoint - 900dp
  /// Usage: Tablets, landscape mode
  static const double breakpointTablet = 900.0;

  /// Desktop breakpoint - 1200dp
  /// Usage: Desktop, large screens
  static const double breakpointDesktop = 1200.0;

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPER METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get responsive padding based on screen width
  static EdgeInsets responsivePagePadding(BuildContext context) {
    final breakpoint = context.breakpoint;

    switch (breakpoint) {
      case DeviceBreakpoint.extraSmall:
      case DeviceBreakpoint.small:
        // Mobile: default page paddings
        return const EdgeInsets.symmetric(
          horizontal: pageHorizontalPadding,
          vertical: pageVerticalPadding,
        );
      case DeviceBreakpoint.medium:
        // Small tablets
        return const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0);
      case DeviceBreakpoint.large:
      case DeviceBreakpoint.extraLarge:
        // Large tablets / desktop
        return const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0);
    }
  }

  /// Get responsive horizontal spacing
  static double responsiveSpacing(BuildContext context) {
    final breakpoint = context.breakpoint;

    switch (breakpoint) {
      case DeviceBreakpoint.extraSmall:
      case DeviceBreakpoint.small:
        // Phones
        return spacingMedium;
      case DeviceBreakpoint.medium:
      case DeviceBreakpoint.large:
        // Tablets
        return spacingLarge;
      case DeviceBreakpoint.extraLarge:
        // Desktop / very large
        return spacingXl;
    }
  }

  /// Check if device is mobile
  static bool isMobile(BuildContext context) {
    return context.breakpoint.isMobile;
  }

  /// Check if device is tablet
  static bool isTablet(BuildContext context) {
    return context.breakpoint.isTablet;
  }

  /// Check if device is desktop
  static bool isDesktop(BuildContext context) {
    return context.breakpoint.isDesktop;
  }
}
