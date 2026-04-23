import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Global responsive layout builder for ChatAway+
/// Provides consistent breakpoints and responsive sizing across the app
///
/// Usage:
/// ```dart
/// ResponsiveLayoutBuilder(
///   builder: (context, constraints, breakpoint) {
///     return YourWidget();
///   },
/// )
/// ```
/*ResponsiveLayoutBuilder(
  builder: (context, constraints, breakpoint) {
    final responsive = ResponsiveSize(
      context: context,
      constraints: constraints,
      breakpoint: breakpoint,
    );

    return Container(
      width: responsive.size(40),              // Width
      height: responsive.size(70),             // Height
      padding: EdgeInsets.all(
        responsive.spacing(12),                // Padding
      ),
      decoration: BoxDecoration(
        color: Colors.blue, 
        borderRadius: BorderRadius.circular( 
          responsive.size(8),                  // Border radius
        ),
      ),
      child: Text('Hello'),
    );

   very Importnat one
responsive.size()
 → Use for: width, height, border radius, icon sizes
responsive.spacing()
 → Use for: padding, margin, gaps between widgets



  } */
///

class ResponsiveLayoutBuilder extends StatelessWidget {
  final Widget Function(
    BuildContext context,
    BoxConstraints constraints,
    DeviceBreakpoint breakpoint,
  )
  builder;

  const ResponsiveLayoutBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = MediaQuery.of(context).size.width;
        final breakpoint = DeviceBreakpoint.fromWidth(width);
        return builder(context, constraints, breakpoint);
      },
    );
  }
}

/// Device breakpoint categories based on screen width
/// Follows industry-standard breakpoints (Material Design, Bootstrap)
enum DeviceBreakpoint {
  /// Small phones: < 360px
  extraSmall,

  /// Regular phones: 360px - 599px
  small,

  /// Large phones / Small tablets: 600px - 839px
  medium,

  /// Tablets: 840px - 1199px
  large,

  /// Desktop / Large tablets: >= 1200px
  extraLarge;

  /// Determine breakpoint from screen width
  static DeviceBreakpoint fromWidth(double width) {
    if (width < 360) return DeviceBreakpoint.extraSmall;
    if (width < 600) return DeviceBreakpoint.small;
    if (width < 840) return DeviceBreakpoint.medium;
    if (width < 1200) return DeviceBreakpoint.large;
    return DeviceBreakpoint.extraLarge;
  }

  /// Check if current breakpoint is mobile (small or extra small)
  bool get isMobile => this == small || this == extraSmall;

  /// Check if current breakpoint is tablet
  bool get isTablet => this == medium || this == large;

  /// Check if current breakpoint is desktop
  bool get isDesktop => this == extraLarge;

  /// Get responsive multiplier for sizing
  double get sizeMultiplier {
    switch (this) {
      case DeviceBreakpoint.extraSmall:
        return 0.9; // Slightly smaller for tiny screens
      case DeviceBreakpoint.small:
        return 1.0; // Base size (375px reference)
      case DeviceBreakpoint.medium:
        return 1.2; // Larger for tablets
      case DeviceBreakpoint.large:
        return 1.4; // Even larger for big tablets
      case DeviceBreakpoint.extraLarge:
        return 1.6; // Largest for desktop
    }
  }

  double fluidSizeScale(double width) {
    const baseWidth = 375.0;
    final ratio = (width / baseWidth).clamp(0.75, 3.0);
    final scaled = math.pow(ratio, 0.5).toDouble();
    switch (this) {
      case DeviceBreakpoint.extraSmall:
        return scaled.clamp(0.90, 0.98).toDouble();
      case DeviceBreakpoint.small:
        return scaled.clamp(0.95, 1.08).toDouble();
      case DeviceBreakpoint.medium:
        return scaled.clamp(1.05, 1.18).toDouble();
      case DeviceBreakpoint.large:
        return scaled.clamp(1.12, 1.28).toDouble();
      case DeviceBreakpoint.extraLarge:
        return scaled.clamp(1.20, 1.40).toDouble();
    }
  }

  /// Get responsive spacing multiplier
  double get spacingMultiplier {
    switch (this) {
      case DeviceBreakpoint.extraSmall:
        return 0.85;
      case DeviceBreakpoint.small:
        return 1.0;
      case DeviceBreakpoint.medium:
        return 1.3;
      case DeviceBreakpoint.large:
        return 1.5;
      case DeviceBreakpoint.extraLarge:
        return 1.8;
    }
  }

  double fluidSpacingScale(double width) {
    const baseWidth = 375.0;
    final ratio = (width / baseWidth).clamp(0.75, 3.0);
    final scaled = math.pow(ratio, 0.55).toDouble();
    switch (this) {
      case DeviceBreakpoint.extraSmall:
        return scaled.clamp(0.90, 1.00).toDouble();
      case DeviceBreakpoint.small:
        return scaled.clamp(0.95, 1.10).toDouble();
      case DeviceBreakpoint.medium:
        return scaled.clamp(1.06, 1.25).toDouble();
      case DeviceBreakpoint.large:
        return scaled.clamp(1.14, 1.35).toDouble();
      case DeviceBreakpoint.extraLarge:
        return scaled.clamp(1.22, 1.45).toDouble();
    }
  }
}

/// Responsive sizing helper - use this for consistent sizing across app
class ResponsiveSize {
  final BuildContext context;
  final BoxConstraints constraints;
  final DeviceBreakpoint breakpoint;

  ResponsiveSize({
    required this.context,
    required this.constraints,
    required this.breakpoint,
  });

  /// Get responsive size based on base mobile size
  /// [mobileSize] - Size for 375px width screen (base)
  double size(double mobileSize) {
    final width = MediaQuery.of(context).size.width;
    return mobileSize * breakpoint.fluidSizeScale(width);
  }

  /// Get responsive spacing based on base mobile spacing
  /// [mobileSpacing] - Spacing for 375px width screen (base)
  double spacing(double mobileSpacing) {
    final width = MediaQuery.of(context).size.width;
    return mobileSpacing * breakpoint.fluidSpacingScale(width);
  }

  /// Get horizontal padding based on breakpoint
  double get horizontalPadding {
    switch (breakpoint) {
      case DeviceBreakpoint.extraSmall:
        return 12.0;
      case DeviceBreakpoint.small:
        return 16.0;
      case DeviceBreakpoint.medium:
        return 24.0;
      case DeviceBreakpoint.large:
        return 32.0;
      case DeviceBreakpoint.extraLarge:
        return 48.0;
    }
  }

  /// Get content max width to prevent oversized layouts
  double get contentMaxWidth {
    switch (breakpoint) {
      case DeviceBreakpoint.extraSmall:
      case DeviceBreakpoint.small:
        return constraints.maxWidth; // Full width on mobile
      case DeviceBreakpoint.medium:
        return 600.0; // Constrain on tablets
      case DeviceBreakpoint.large:
        return 800.0; // Constrain on large tablets
      case DeviceBreakpoint.extraLarge:
        return 1000.0; // Constrain on desktop
    }
  }

  /// Get number of columns for grid layouts
  int get gridColumns {
    switch (breakpoint) {
      case DeviceBreakpoint.extraSmall:
      case DeviceBreakpoint.small:
        return 1; // Single column on mobile
      case DeviceBreakpoint.medium:
        return 2; // Two columns on small tablets
      case DeviceBreakpoint.large:
        return 3; // Three columns on tablets
      case DeviceBreakpoint.extraLarge:
        return 4; // Four columns on desktop
    }
  }
}

/// Extension on BuildContext for easy access to screen size
extension ResponsiveContext on BuildContext {
  /// Get screen width
  double get screenWidth => MediaQuery.of(this).size.width;

  /// Get screen height
  double get screenHeight => MediaQuery.of(this).size.height;

  /// Get current device breakpoint
  DeviceBreakpoint get breakpoint => DeviceBreakpoint.fromWidth(screenWidth);

  /// Check if device is mobile
  bool get isMobile => breakpoint.isMobile;

  /// Check if device is tablet
  bool get isTablet => breakpoint.isTablet;

  /// Check if device is desktop
  bool get isDesktop => breakpoint.isDesktop;
}
