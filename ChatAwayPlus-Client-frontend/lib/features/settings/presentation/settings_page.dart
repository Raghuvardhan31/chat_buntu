import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chataway_plus/core/themes/app_text_styles.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/core/routes/navigation_service.dart';
import 'package:chataway_plus/core/database/app_database.dart';
import 'package:chataway_plus/core/storage/token_storage.dart';
import 'package:chataway_plus/core/storage/fcm_token_storage.dart';
import 'package:chataway_plus/core/delete_account/user_account_api_service.dart';
import 'package:chataway_plus/features/chat/data/cache/index.dart';
import 'package:chataway_plus/features/chat/data/services/chat_engine/chat_engine_service.dart';
import 'package:chataway_plus/core/app_lifecycle/app_state_service.dart';
import 'package:chataway_plus/core/connectivity/connectivity_service.dart';
import 'package:chataway_plus/core/dialog_box/app_dialog_box.dart';
import 'package:chataway_plus/core/snackbar/app_snackbar.dart';
import 'package:chataway_plus/features/shared/widgets/avatars/cached_circle_avatar.dart';
import 'package:chataway_plus/features/settings/providers/settings_user_providers.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});
  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(settingsUserNotifierProvider.notifier).loadCurrentUser();
    });
  }

  @override
  Widget build(BuildContext context) {
    final responsive = _responsiveFor(context);
    final avatarUrl = ref.watch(settingsUserAvatarUrlProvider);
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        NavigationService.goToChatList();
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
          scrolledUnderElevation: 0.0,
          toolbarHeight: responsive.size(68),
          centerTitle: false,
          titleSpacing: 0,
          leadingWidth: responsive.size(50),
          title: Text(
            'Settings',
            style: AppTextSizes.heading(context).copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: AppColors.primary,
              size: responsive.size(24),
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => NavigationService.goToChatList(),
          ),
          actions: [
            Padding(
              padding: EdgeInsets.only(
                right: responsive.spacing(16),
                top: responsive.spacing(15),
              ),
              child: _buildCurrentUserAvatar(avatarUrl),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.only(
                left: responsive.spacing(16),
                right: responsive.spacing(16),
                top: responsive.spacing(80),
                bottom: responsive.spacing(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSettingOption(
                    icon: Icons.edit,
                    title: 'Edit Profile',
                    subtitle: 'Update your profile information',
                    onTap: () => NavigationService.goToCurrentUserProfile(),
                    showDivider: true,
                  ),
                  _buildSettingOption(
                    icon: Icons.palette_outlined,
                    title: 'Theme',
                    subtitle: 'Light, Dark, or System default',
                    onTap: () => NavigationService.goToThemeSettings(),
                    showDivider: true,
                  ),
                  _buildSettingOption(
                    icon: Icons.block,
                    title: 'Block Contacts',
                    subtitle: 'Manage blocked contacts',
                    onTap: () => NavigationService.goToBlockContacts(),
                    showDivider: true,
                  ),
                  _buildSettingOption(
                    icon: Icons.bug_report,
                    title: 'Bug Report',
                    subtitle: 'Report issues or bugs',
                    onTap: () => NavigationService.goToBugReport(),
                    showDivider: true,
                  ),
                  _buildSettingOption(
                    icon: Icons.info_outline,
                    title: 'About Us',
                    subtitle: 'App info, version, and contact details',
                    onTap: () => NavigationService.goToAboutUs(),
                    showDivider: true,
                  ),
                  _buildSettingOption(
                    icon: Icons.logout,
                    title: 'Logout',
                    subtitle: 'Sign out of your account',
                    onTap: () => _showLogoutDialog(),
                    showDivider: true,
                    isDestructive: true,
                  ),
                  _buildSettingOption(
                    icon: Icons.delete_forever,
                    title: 'Delete Account',
                    subtitle: 'Permanently delete your account',
                    onTap: () => _showDeleteAccountDialog(),
                    showDivider: true,
                    isDestructive: true,
                  ),
                ],
              ),
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

  Widget _buildCurrentUserAvatar(String? avatarUrl) {
    final responsive = _responsiveFor(context);
    final avatarDiameter = responsive.size(48);
    return SizedBox(
      width: avatarDiameter,
      height: avatarDiameter,
      child: InkWell(
        onTap: () => NavigationService.goToCurrentUserProfile(),
        customBorder: const CircleBorder(),
        child: CachedCircleAvatar(
          chatPictureUrl: avatarUrl,
          radius: avatarDiameter / 2,
          backgroundColor: AppColors.lighterGrey,
          iconColor: AppColors.colorGrey,
        ),
      ),
    );
  }

  Widget _buildSettingOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool showDivider = true,
    bool isDestructive = false,
  }) {
    final responsive = _responsiveFor(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.symmetric(
            horizontal: responsive.spacing(20),
            vertical: responsive.spacing(8),
          ),
          leading: Icon(
            icon,
            color: isDestructive
                ? AppColors.error
                : (isDark ? Colors.white70 : AppColors.colorGrey),
            size: responsive.size(24),
          ),
          title: Text(
            title,
            style: AppTextSizes.regular(context).copyWith(
              color: isDestructive
                  ? AppColors.error
                  : theme.colorScheme.onSurface,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: AppTextSizes.small(context).copyWith(
              color: theme.colorScheme.onSurface.withAlpha((0.6 * 255).round()),
            ),
          ),
          trailing: Icon(
            Icons.arrow_forward_ios,
            color: isDark ? Colors.white54 : AppColors.colorGrey,
            size: responsive.size(16),
          ),
          onTap: onTap,
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            color: isDark ? Colors.white24 : Colors.grey.shade300,
            indent: responsive.spacing(20),
            endIndent: responsive.spacing(20),
          ),
      ],
    );
  }

  /// Shows delete account confirmation dialog
  void _showDeleteAccountDialog() {
    final responsive = _responsiveFor(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    AppDialogBox.show<void>(
      context,
      title: 'Delete Account',
      message:
          'Are you sure you want to delete your account? This action cannot be undone and all your data will be permanently deleted.',
      buttons: const [],
      barrierDismissible: false,
      titleColor: AppColors.error,
      titleAlignment: TextAlign.left,
      messageAlignment: TextAlign.left,
      contentAlignment: CrossAxisAlignment.start,
      customActions: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: AppTextSizes.regular(
                context,
              ).copyWith(color: isDark ? Colors.white54 : AppColors.colorGrey),
            ),
          ),
          SizedBox(width: responsive.spacing(8)),
          TextButton(
            onPressed: () async {
              await _handleDeleteConfirm();
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: EdgeInsets.symmetric(
                horizontal: responsive.spacing(16),
                vertical: responsive.spacing(8),
              ),
            ),
            child: Text(
              'Delete',
              style: AppTextSizes.regular(
                context,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  /// Shows logout confirmation dialog
  void _showLogoutDialog() {
    final responsive = _responsiveFor(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white70 : AppColors.colorGrey;

    AppDialogBox.show<void>(
      context,
      title: 'Logout',
      message: '',
      buttons: const [],
      barrierDismissible: false,
      titleColor: AppColors.error,
      titleAlignment: TextAlign.left,
      messageAlignment: TextAlign.left,
      contentAlignment: CrossAxisAlignment.start,
      customContent: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Are you sure you want to logout?',
            style: AppTextSizes.regular(context).copyWith(color: textColor),
          ),
          SizedBox(height: responsive.spacing(12)),
          Text(
            'This will delete all stored data:',
            style: AppTextSizes.small(context).copyWith(color: textColor),
          ),
          SizedBox(height: responsive.spacing(8)),
          ...[
            'Chat messages and conversations',
            'Saved contacts',
            'Personal emoji updates',
            'User preferences',
          ].map(
            (item) => Padding(
              padding: EdgeInsets.only(left: responsive.spacing(8)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '\u2022 ',
                    style: AppTextSizes.small(
                      context,
                    ).copyWith(color: textColor),
                  ),
                  Expanded(
                    child: Text(
                      item,
                      style: AppTextSizes.small(
                        context,
                      ).copyWith(color: textColor),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: responsive.spacing(12)),
        ],
      ),
      customActions: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: AppTextSizes.regular(
                context,
              ).copyWith(color: isDark ? Colors.white54 : AppColors.colorGrey),
            ),
          ),
          SizedBox(width: responsive.spacing(8)),
          TextButton(
            onPressed: () async {
              await _handleLogoutConfirm();
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: EdgeInsets.symmetric(
                horizontal: responsive.spacing(16),
                vertical: responsive.spacing(8),
              ),
            ),
            child: Text(
              'Logout',
              style: AppTextSizes.regular(
                context,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final responsive = _responsiveFor(context);
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(responsive.size(12)), // 12 px
          ),
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: responsive.size(22), // 22 px
                height: responsive.size(22), // 22 px
                child: CircularProgressIndicator(
                  strokeWidth: responsive.size(2.5), // 2.5 px
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.primary,
                  ),
                ),
              ),
              SizedBox(width: responsive.spacing(16)), // 16 px
              Text(
                message,
                style: AppTextSizes.regular(
                  context,
                ).copyWith(color: Theme.of(context).colorScheme.onSurface),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Performs complete logout with data cleanup
  Future<void> _performLogout() async {
    try {
      // Show loading dialog
      _showLoadingDialog('Logging out...');

      debugPrint('🚪 [Logout] Starting logout process...');

      // Step 1: Disconnect WebSocket and dispose ChatEngineService
      debugPrint('🔌 [Logout] Disconnecting WebSocket...');
      try {
        ChatEngineService.instance.dispose();
      } catch (_) {}
      debugPrint('✅ [Logout] WebSocket disconnected');

      // Step 2: Clear lifecycle callbacks to prevent stale reconnect attempts
      try {
        AppStateService.instance.clearCallbacks();
      } catch (_) {}

      ChatCacheManager.instance.clearAll();

      // Step 3: Clear secure storage (auth tokens, credentials)
      debugPrint('🔑 [Logout] Clearing auth tokens...');
      await TokenSecureStorage.instance.clearUserData();
      debugPrint('✅ [Logout] Auth tokens cleared');

      // Step 4: Delete FCM tokens
      debugPrint('📱 [Logout] Deleting FCM tokens...');
      await FCMTokenStorage.instance.deleteFCMToken();
      debugPrint('✅ [Logout] FCM tokens deleted');

      // Step 5: Delete entire database
      debugPrint('🗄️ [Logout] Deleting database...');
      await AppDatabaseManager.instance.deleteDatabaseFile();
      debugPrint('✅ [Logout] Database deleted');

      // Step 6: Clear SharedPreferences (theme, tips, etc.)
      debugPrint('🧹 [Logout] Clearing SharedPreferences...');
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
      } catch (_) {}
      debugPrint('✅ [Logout] SharedPreferences cleared');

      // Step 7: Reset connectivity cache
      try {
        ConnectivityCache.instance.dispose();
      } catch (_) {}

      debugPrint('✅ [Logout] Logout process completed successfully');

      // Close loading dialog
      if (!mounted) return;
      Navigator.of(context).pop();

      // Success snackbar then navigate
      await AppSnackbar.showSuccess(context, 'Logged out successfully');
      if (!mounted) return;
      debugPrint('🧭 [Logout] Navigating to login page...');
      await NavigationService.goToPhoneNumberEntry();
    } catch (e) {
      debugPrint('❌ [Logout] Error during logout: $e');

      // Close loading dialog if still open
      if (!mounted) return;
      Navigator.of(context).pop();

      // Error snackbar
      await AppSnackbar.showError(context, 'Logout failed. Please try again.');
    }
  }

  Future<void> _handleLogoutConfirm() async {
    try {
      final online = await InternetConnectionChecker().hasConnection;
      if (!mounted) return;
      if (!online) {
        AppSnackbar.showOfflineWarning(
          context,
          "You're offline. Check your connection",
        );
        return;
      }
      Navigator.of(context).pop();
      await _performLogout();
    } catch (e) {
      if (mounted) {
        await AppSnackbar.showError(
          context,
          'Something went wrong. Please try again.',
        );
      }
    }
  }

  Future<void> _handleDeleteConfirm() async {
    try {
      final online = await InternetConnectionChecker().hasConnection;
      if (!mounted) return;
      if (!online) {
        AppSnackbar.showOfflineWarning(
          context,
          "You're offline. Check your connection",
        );
        return;
      }
      Navigator.of(context).pop();
      if (!mounted) return;

      _showLoadingDialog('Deleting account...');

      final deleteResp = await UserAccountApiService.instance
          .requestDeleteAccount(deleteAccount: true);
      if (!deleteResp.success) {
        if (!mounted) return;
        Navigator.of(context).pop();
        await AppSnackbar.showError(
          context,
          deleteResp.message.isNotEmpty
              ? deleteResp.message
              : 'Delete failed. Please try again.',
        );
        return;
      }

      debugPrint('🗑️ [Delete Account] Clearing all user data...');

      // Disconnect WebSocket and dispose ChatEngineService
      try {
        ChatEngineService.instance.dispose();
      } catch (_) {}

      // Clear lifecycle callbacks to prevent stale reconnect attempts
      try {
        AppStateService.instance.clearCallbacks();
      } catch (_) {}

      ChatCacheManager.instance.clearAll();

      // Clear auth tokens
      await TokenSecureStorage.instance.clearUserData();
      debugPrint('✅ [Delete Account] Auth tokens cleared');

      // Delete FCM tokens
      await FCMTokenStorage.instance.deleteFCMToken();
      debugPrint('✅ [Delete Account] FCM tokens deleted');

      // Delete entire local database
      await AppDatabaseManager.instance.deleteDatabaseFile();
      debugPrint('✅ [Delete Account] Local database deleted');

      // Clear SharedPreferences (theme, tips, etc.)
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
      } catch (_) {}
      debugPrint('✅ [Delete Account] SharedPreferences cleared');

      // Reset connectivity cache
      try {
        ConnectivityCache.instance.dispose();
      } catch (_) {}

      if (!mounted) return;
      Navigator.of(context).pop();

      await AppSnackbar.showSuccess(
        context,
        deleteResp.message.isNotEmpty
            ? deleteResp.message
            : 'Deletion requested. Your account will be deleted from server within 30 days.',
        duration: const Duration(seconds: 2),
      );
      if (!mounted) return;
      await NavigationService.goToPhoneNumberEntry();
    } catch (e) {
      debugPrint('❌ [Delete Account] Error: $e');

      // Close loading dialog if still open
      if (!mounted) return;
      Navigator.of(context).pop();

      await AppSnackbar.showError(context, 'Delete failed. Please try again.');
    }
  }
}
