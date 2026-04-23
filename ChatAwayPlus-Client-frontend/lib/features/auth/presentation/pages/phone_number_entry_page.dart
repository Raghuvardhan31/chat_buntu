// lib/features/auth/presentation/pages/phone_number_entry_page.dart
import 'package:chataway_plus/core/snackbar/app_snackbar.dart';
import 'package:chataway_plus/features/auth/presentation/widgets/get_otp_button.dart';
import 'package:chataway_plus/features/auth/presentation/widgets/phone_number_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

import '../providers/mobile_number/mobile_number_provider.dart';

import 'package:chataway_plus/core/constants/assets/index.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/core/themes/app_text_styles.dart';
import 'package:chataway_plus/core/routes/navigation_service.dart';
import 'package:chataway_plus/core/services/permissions/permission_manager.dart';
import 'package:chataway_plus/core/connectivity/connectivity_service.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';

class PhoneNumberEntryPage extends ConsumerStatefulWidget {
  const PhoneNumberEntryPage({super.key});

  @override
  ConsumerState<PhoneNumberEntryPage> createState() =>
      _PhoneNumberEntryPageState();
}

class _PhoneNumberEntryPageState extends ConsumerState<PhoneNumberEntryPage>
    with WidgetsBindingObserver {
  final TextEditingController _userMobileNumberController =
      TextEditingController();
  final FocusNode _textFieldFocusNode = FocusNode();

  // Flag to prevent listener from running after navigation
  bool _isNavigating = false;
  bool _isRequestingPermissions = false;
  bool online = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    online = ref
        .read(internetStatusStreamProvider)
        .maybeWhen(data: (v) => v, orElse: () => false);

    // Defer side-effects to after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
    });
  }

  @override
  void dispose() {
    _userMobileNumberController.dispose();
    _textFieldFocusNode.dispose();
    WidgetsBinding.instance.removeObserver(this);

    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }

  bool isValidIndianMobile(String phone) =>
      RegExp(r'^[6-9]\d{9}$').hasMatch(phone);

  /// Request essential permissions (Contacts + Photos/Gallery)
  Future<void> _requestEssentialPermissions() async {
    if (_isRequestingPermissions) {
      debugPrint(
        '📛 Permission request already in progress, skipping duplicate',
      );
      return;
    }
    _isRequestingPermissions = true;
    try {
      final permissionManager = PermissionManager.instance;

      debugPrint('🔐 ========================================');
      debugPrint('🔐 PERMISSION CHECK STARTED');
      debugPrint('🔐 ========================================');

      // Check current status BEFORE requesting
      debugPrint('📋 Checking current permission status...');
      for (final type in permissionManager.getEssentialPermissions()) {
        final status = await permissionManager.getPermissionStatus(type);
        final name = permissionManager.getPermissionName(type);
        debugPrint('   • $name: $status');
      }

      debugPrint('');
      debugPrint('🔔 Requesting permissions (popups should appear now)...');

      // Request all essential permissions
      final results = await permissionManager.requestEssentialPermissions();

      debugPrint('');
      debugPrint('📊 Permission Request Results:');

      // Log detailed results
      results.forEach((type, result) {
        final name = permissionManager.getPermissionName(type);
        final icon = result.isGranted ? '✅' : '❌';
        debugPrint('   $icon $name: ${result.status}');

        if (!result.isGranted) {
          debugPrint('      ⚠️ Reason: ${result.message}');
        }
      });

      // Final summary
      final allGranted = results.values.every((r) => r.isGranted);

      debugPrint('');
      if (allGranted) {
        debugPrint('✅ SUCCESS: All essential permissions granted!');
      } else {
        final deniedCount = results.values.where((r) => !r.isGranted).length;
        debugPrint('⚠️ WARNING: $deniedCount permission(s) not granted');

        final deniedList = results.entries
            .where((e) => !e.value.isGranted)
            .map((e) => permissionManager.getPermissionName(e.key))
            .join(', ');
        debugPrint('   Denied: $deniedList');
      }

      debugPrint('🔐 ========================================');
      debugPrint('🔐 PERMISSION CHECK COMPLETED');
      debugPrint('🔐 ========================================');
    } catch (e, stackTrace) {
      debugPrint('❌ ERROR requesting permissions: $e');
      debugPrint('Stack trace: $stackTrace');
    } finally {
      _isRequestingPermissions = false;
    }
  }

  Future<void> _onGetOtpPressed() async {
    FocusScope.of(context).unfocus();
    final phoneNumber = _userMobileNumberController.text.trim();

    if (!isValidIndianMobile(phoneNumber)) {
      AppSnackbar.showError(
        context,
        "Please enter a valid 10-digit mobile number",
        bottomPosition: 150,
      );
      return;
    }
    // Block when offline (fresh check each tap to avoid stale value)
    final onlineNow = await InternetConnectionChecker().hasConnection;
    if (!onlineNow) {
      if (!mounted) return;
      AppSnackbar.showOfflineWarning(
        context,
        "You're offline. Please connect to the internet",
      );
      return;
    }

    // Check if essential permissions are granted before sending OTP
    final hasPermissions = await _checkEssentialPermissions();
    if (!hasPermissions) {
      _showPermissionsRequiredDialog();
      return;
    }

    // call notifier to send OTP
    await ref.read(authNotifierProvider.notifier).sendOtp(phoneNumber);

    if (!mounted) return;

    // Read current state once and navigate inline if OTP sent
    final current = ref.read(authNotifierProvider);
    if (current.otpSent && !_isNavigating) {
      _isNavigating = true;
      await AppSnackbar.showSuccess(
        context,
        'OTP sent successfully',
        bottomPosition: 150,
      );
      // Cancel any timers/tasks associated with this page before navigating
      ref.read(authNotifierProvider.notifier).cancelTimer();
      await NavigationService.goToOtpVerification(phoneNumber);
      return;
    }

    // If failed, surface error (if any)
    if (current.error != null && current.error!.isNotEmpty) {
      AppSnackbar.showError(
        context,
        'Error sending OTP. Please try again.',
        bottomPosition: 150,
      );
    }
  }

  /// Check if minimum required permissions are granted
  /// Required: Contacts + Photos Read (Photos Write is optional)
  Future<bool> _checkEssentialPermissions() async {
    try {
      final permissionManager = PermissionManager.instance;

      // Check only critical permissions: Contacts and Photos Read
      final contactsGranted = await permissionManager.isPermissionGranted(
        AppPermissionType.contacts,
      );
      final photosReadGranted = await permissionManager.isPermissionGranted(
        AppPermissionType.photosRead,
      );

      debugPrint('📋 Required Permission Check:');
      debugPrint('   • Contacts: ${contactsGranted ? "✅" : "❌"}');
      debugPrint('   • Photos Read: ${photosReadGranted ? "✅" : "❌"}');

      // Photos Write is optional - can be requested later when saving images
      return contactsGranted && photosReadGranted;
    } catch (e) {
      debugPrint('❌ Error checking permissions: $e');
      return false;
    }
  }

  /// Show dialog when permissions are required to proceed
  void _showPermissionsRequiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => ResponsiveLayoutBuilder(
        builder: (context, constraints, breakpoint) {
          final responsive = ResponsiveSize(
            context: context,
            constraints: constraints,
            breakpoint: breakpoint,
          );

          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(responsive.size(12)),
            ),
            title: Text(
              'Permissions Required',
              style: AppTextSizes.large(context).copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.colorBlack,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'To proceed, we need access to:',
                  style: AppTextSizes.regular(
                    context,
                  ).copyWith(color: AppColors.colorGrey),
                ),
                SizedBox(height: responsive.spacing(16)),
                _buildPermissionItem(
                  responsive,
                  '📞',
                  'Contacts (Required)',
                  'To sync and connect with your friends',
                ),
                SizedBox(height: responsive.spacing(12)),
                _buildPermissionItem(
                  responsive,
                  '📸',
                  'Photos (Required)',
                  'To select and share images',
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(
                  'Cancel',
                  style: AppTextSizes.regular(
                    context,
                  ).copyWith(color: AppColors.colorGrey),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  await _requestEssentialPermissions();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: responsive.spacing(20),
                    vertical: responsive.spacing(12),
                  ),
                ),
                child: Text(
                  'Grant Permissions',
                  style: AppTextSizes.regular(
                    context,
                  ).copyWith(fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Build permission item widget for dialog
  Widget _buildPermissionItem(
    ResponsiveSize responsive,
    String emoji,
    String title,
    String description,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: TextStyle(fontSize: responsive.size(24))),
        SizedBox(width: responsive.spacing(12)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextSizes.regular(context).copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.colorBlack,
                ),
              ),
              SizedBox(height: responsive.spacing(2)),
              Text(
                description,
                style: AppTextSizes.small(
                  context,
                ).copyWith(color: AppColors.colorGrey),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final keyboardInset = mediaQuery.viewInsets.bottom;
    final state = ref.watch(authNotifierProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          scrolledUnderElevation: 0.0,
          automaticallyImplyLeading: false,
          title: const SizedBox.shrink(),
          actions: [],
        ),
        body: SafeArea(
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            behavior: HitTestBehavior.opaque,
            child: ResponsiveLayoutBuilder(
              builder: (context, constraints, breakpoint) {
                final responsive = ResponsiveSize(
                  context: context,
                  constraints: constraints,
                  breakpoint: breakpoint,
                );

                final imageHeight = responsive.size(100).clamp(90.0, 140.0);
                final verticalSpacingXXL = responsive.spacing(40);
                final verticalSpacingXL = responsive.spacing(32);
                final verticalSpacingL = responsive.spacing(24);
                final verticalSpacingM = responsive.spacing(16);
                final verticalSpacingS = responsive.spacing(8);

                return SingleChildScrollView(
                  padding: EdgeInsets.only(bottom: keyboardInset),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: responsive.horizontalPadding,
                        ),
                        child: Column(
                          children: [
                            Center(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: responsive.contentMaxWidth,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    SizedBox(height: verticalSpacingXXL),
                                    Image.asset(
                                      ImageAssets.mobileBankingImage,
                                      color: AppColors.primary,
                                      fit: BoxFit.contain,
                                      height: imageHeight,
                                    ),
                                    SizedBox(height: verticalSpacingL),
                                    Text(
                                      'OTP Verification',
                                      style: AppTextSizes.custom(
                                        context,
                                        24,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.colorBlack,
                                        height: 1.2,
                                      ),
                                    ),
                                    SizedBox(height: verticalSpacingS),
                                    Text(
                                      "We'll send you One Time Password",
                                      textAlign: TextAlign.center,
                                      style: AppTextSizes.regular(
                                        context,
                                      ).copyWith(color: AppColors.colorGrey),
                                    ),
                                    SizedBox(height: verticalSpacingS / 2),
                                    Text(
                                      'on this mobile number',
                                      textAlign: TextAlign.center,
                                      style: AppTextSizes.regular(
                                        context,
                                      ).copyWith(color: AppColors.colorGrey),
                                    ),
                                    SizedBox(height: verticalSpacingXL),
                                    Text(
                                      'Enter your mobile number',
                                      textAlign: TextAlign.center,
                                      style: AppTextSizes.large(
                                        context,
                                      ).copyWith(color: Colors.black),
                                    ),
                                    SizedBox(height: verticalSpacingM),
                                    Center(
                                      child: ConstrainedBox(
                                        constraints: BoxConstraints(
                                          maxWidth: responsive.size(320),
                                        ),
                                        child: SizedBox(
                                          height: responsive.size(55),
                                          child: PhoneNumberInput(
                                            controller:
                                                _userMobileNumberController,
                                            focusNode: _textFieldFocusNode,
                                            responsive: responsive,
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: verticalSpacingL),
                                  ],
                                ),
                              ),
                            ),
                            const Spacer(),
                            Center(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: responsive.contentMaxWidth,
                                ),
                                child: SafeArea(
                                  top: false,
                                  child: Padding(
                                    padding: EdgeInsets.only(
                                      bottom: responsive.spacing(16),
                                    ),
                                    child: SizedBox(
                                      width: double.infinity,
                                      child: GetOtpButton(
                                        isLoading: state.loading,
                                        disabled: state.buttonDisabled,
                                        onPressed: _onGetOtpPressed,
                                        responsive: responsive,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
