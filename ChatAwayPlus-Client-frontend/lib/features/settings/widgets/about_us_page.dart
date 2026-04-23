import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:chataway_plus/core/themes/app_text_styles.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:chataway_plus/core/constants/assets/image_assets.dart';

class AboutUsPage extends ConsumerStatefulWidget {
  const AboutUsPage({super.key});

  @override
  ConsumerState<AboutUsPage> createState() => _AboutUsPageState();
}

class _AboutUsPageState extends ConsumerState<AboutUsPage> {
  String _appVersion = '';
  String _buildNumber = '';

  @override
  void initState() {
    super.initState();
    _loadAppInfo();
  }

  Future<void> _loadAppInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = packageInfo.version;
      _buildNumber = packageInfo.buildNumber;
    });
  }

  @override
  Widget build(BuildContext context) {
    final responsive = _responsiveFor(context);
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
            size: responsive.size(24),
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'About Us',
          style: AppTextSizes.heading(context).copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(responsive.spacing(24)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: responsive.spacing(20)),

                // App Logo/Icon
                Container(
                  width: responsive.size(120),
                  height: responsive.size(120),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(responsive.size(24)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(responsive.size(24)),
                    child: Image.asset(
                      ImageAssets.appLogo,
                      width: responsive.size(120),
                      height: responsive.size(120),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: responsive.size(120),
                          height: responsive.size(120),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(
                              responsive.size(24),
                            ),
                          ),
                          child: Icon(
                            Icons.chat_bubble_outline,
                            size: responsive.size(60),
                            color: Colors.white,
                          ),
                        );
                      },
                    ),
                  ),
                ),

                SizedBox(height: responsive.spacing(24)),

                // App Name
                Text(
                  'ChatAway+',
                  style: AppTextSizes.heading(context).copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: AppTextSizes.getResponsiveSize(context, 28),
                  ),
                ),

                SizedBox(height: responsive.spacing(8)),

                // Version Info
                Text(
                  'Version $_appVersion${_buildNumber.isNotEmpty ? ' ($_buildNumber)' : ''}',
                  style: AppTextSizes.regular(context).copyWith(
                    color: isDark ? Colors.white70 : AppColors.colorGrey,
                  ),
                ),

                SizedBox(height: responsive.spacing(32)),

                // App Description
                _buildInfoSection(
                  title: 'About ChatAway+',
                  content:
                      'ChatAway+ enables secure personal messaging with text and media sharing.\n\nFeatures: Video Stories • Image Stories • Video Sending • Voice Messages • Location Sharing • PDF Sharing • Contact Sharing • Likes Hub • Chat Pictures • Voice Calls • Video Calls • Emoji Expressions • Story Reactions • Media Gallery • Offline Support',
                  responsive: responsive,
                  theme: theme,
                  isDark: isDark,
                ),

                SizedBox(height: responsive.spacing(24)),

                // Developer Info
                _buildInfoSection(
                  title: 'Developer',
                  content:
                      'Independently developed and maintained by a dedicated solo developer with passion for creating meaningful communication experiences.',
                  responsive: responsive,
                  theme: theme,
                  isDark: isDark,
                ),

                SizedBox(height: responsive.spacing(24)),

                // Future Development
                _buildInfoSection(
                  title: 'What\'s Next',
                  content:
                      'Additional features are in development to improve your messaging experience.',
                  responsive: responsive,
                  theme: theme,
                  isDark: isDark,
                ),

                SizedBox(height: responsive.spacing(24)),

                // Contact Info
                _buildInfoSection(
                  title: 'Contact Us',
                  content:
                      'For support, feedback, or inquiries:\nsupport@chatawayplus.com\ncontact@chatawayplus.com\nWebsite: www.chatawayplus.com',
                  responsive: responsive,
                  theme: theme,
                  isDark: isDark,
                ),

                SizedBox(height: responsive.spacing(32)),

                SizedBox(height: responsive.spacing(32)),

                // Copyright
                Text(
                  '© 2026 ChatAway+. All rights reserved.',
                  style: AppTextSizes.small(context).copyWith(
                    color: isDark ? Colors.white54 : AppColors.colorGrey,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  ResponsiveSize _responsiveFor(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return ResponsiveSize(
      context: context,
      constraints: BoxConstraints(maxWidth: width),
      breakpoint: DeviceBreakpoint.fromWidth(width),
    );
  }

  Widget _buildInfoSection({
    required String title,
    required String content,
    required ResponsiveSize responsive,
    required ThemeData theme,
    required bool isDark,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(responsive.spacing(20)),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.grey[100],
        borderRadius: BorderRadius.circular(responsive.size(12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextSizes.large(context).copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: responsive.spacing(8)),
          Text(
            content,
            style: AppTextSizes.regular(context).copyWith(
              color: isDark ? Colors.white70 : AppColors.colorGrey,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
