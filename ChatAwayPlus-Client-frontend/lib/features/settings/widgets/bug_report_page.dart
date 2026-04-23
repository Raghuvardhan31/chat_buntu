import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chataway_plus/core/themes/app_text_styles.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';

class BugReportPage extends ConsumerStatefulWidget {
  const BugReportPage({super.key});

  @override
  ConsumerState<BugReportPage> createState() => _BugReportPageState();
}

class _BugReportPageState extends ConsumerState<BugReportPage> {
  // Global responsive design variables - Base reference: 375x812 for proportional scaling
  late double screenWidth;
  late double screenHeight;
  late TextScaler textScaler;

  @override
  Widget build(BuildContext context) {
    // Initialize global responsive design variables to avoid repeated expensive calls
    final mediaQuery = MediaQuery.of(context);
    screenWidth = mediaQuery.size.width; // Base width: 375px
    screenHeight = mediaQuery.size.height; // Base height: 812px
    textScaler = MediaQuery.textScalerOf(context); // Accessibility text scaling

    final responsive = ResponsiveSize(
      context: context,
      constraints: BoxConstraints(
        maxWidth: screenWidth,
        maxHeight: screenHeight,
      ),
      breakpoint: DeviceBreakpoint.fromWidth(screenWidth),
    );

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0.0,
        toolbarHeight: responsive.size(68),
        centerTitle: false,
        titleSpacing: 0,
        leadingWidth: responsive.size(50),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: AppColors.primary,
            size: responsive.size(24), // 24px - Back icon size
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Support',
          style: AppTextSizes.heading(context).copyWith(
            color: theme.colorScheme.onSurface.withAlpha((0.7 * 255).round()),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(
            responsive.spacing(30),
          ), // 30px - Page padding
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App development icon
              Icon(
                Icons.build_rounded,
                size: responsive.size(80), // 80px - Icon size
                color: AppColors.primary,
              ),
              SizedBox(height: responsive.spacing(24)), // 24px - Spacing
              // Main message
              Text(
                'We are currently working to give you the best app experience.',
                style: AppTextSizes.large(context).copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: responsive.spacing(16)), // 16px - Spacing
              // Support message
              Text(
                'If you have any concerns or found bugs, please email us at our email id.',
                style: AppTextSizes.regular(context).copyWith(
                  color: isDark ? Colors.white54 : AppColors.colorGrey,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: responsive.spacing(20)), // 20px - Spacing
              // Email contact
              Text(
                'support@chatawayplus.com',
                style: AppTextSizes.large(context).copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
