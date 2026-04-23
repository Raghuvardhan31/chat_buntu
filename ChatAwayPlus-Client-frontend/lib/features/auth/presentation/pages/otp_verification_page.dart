// lib/features/auth/presentation/pages/otp_verification_page.dart
import 'dart:async';

import 'package:chataway_plus/features/auth/presentation/providers/mobile_number/mobile_number_provider.dart';
import 'package:chataway_plus/features/contacts/presentation/providers/contacts_management.dart';
import 'package:chataway_plus/core/constants/assets/index.dart';
import 'package:chataway_plus/core/routes/navigation_service.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/core/themes/app_text_styles.dart';
import 'package:chataway_plus/core/isolates/contact_sync_isolate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chataway_plus/core/connectivity/connectivity_service.dart';
import 'package:chataway_plus/core/snackbar/app_snackbar.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';

import 'package:chataway_plus/core/database/tables/user/mobile_number_table.dart';
import '../../../../core/notifications/firebase/fcm_token_service.dart';
import '../../../../core/storage/fcm_token_storage.dart';

class OtpverificationPage extends ConsumerStatefulWidget {
  final String mobileNo;

  const OtpverificationPage({super.key, required this.mobileNo});

  @override
  ConsumerState<OtpverificationPage> createState() =>
      _OtpverificationScreenState();
}

class _OtpverificationScreenState extends ConsumerState<OtpverificationPage>
    with WidgetsBindingObserver {
  // --------------------------------
  // State
  // --------------------------------
  int _seconds = 90;
  Timer? _timer;
  bool _isVerifyingOtp = false;
  bool _isProcessingSuccess = false;

  final FocusNode _textFieldFocusNode = FocusNode();
  final List<String> _previousValues = List.filled(6, "");

  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );

  // Progress dialog tracking
  bool _isProgressDialogVisible = false;

  // --------------------------------
  // Lifecycle
  // --------------------------------
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _textFieldFocusNode.dispose();
    for (final n in _focusNodes) {
      n.dispose();
    }
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  // --------------------------------
  // Build
  // --------------------------------
  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    final keyboardInset = mediaQuery.viewInsets.bottom;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          // Ensure phone entry page starts fresh (button enabled)
          ref.read(authNotifierProvider.notifier).reset();
          NavigationService.goToPhoneNumberEntry();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.colorWhite,
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: AppColors.colorWhite,
          scrolledUnderElevation: 0.0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: AppColors.colorGrey,
              size: 24, // 24 px
            ),
            onPressed: () {
              // Ensure phone entry page starts fresh (button enabled)
              ref.read(authNotifierProvider.notifier).reset();
              NavigationService.goToPhoneNumberEntry();
            },
          ),
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

                final otpImageHeight = responsive.size(100).clamp(90.0, 140.0);
                final verticalSpacingXXL = responsive.spacing(60);
                final verticalSpacingXL = responsive.spacing(40);
                final verticalSpacingL = responsive.spacing(24);

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
                                      ImageAssets.otpImage,
                                      color: AppColors.primary,
                                      fit: BoxFit.contain,
                                      height: otpImageHeight,
                                    ),
                                    SizedBox(height: verticalSpacingL),
                                    Text(
                                      'OTP Verification',
                                      style: AppTextSizes.heading(context)
                                          .copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.colorBlack,
                                            height: 1.2,
                                          ),
                                    ),
                                    SizedBox(height: verticalSpacingL),
                                    Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: responsive.spacing(16),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'Enter the OTP to ',
                                            style: AppTextSizes.regular(context)
                                                .copyWith(
                                                  color: AppColors.colorGrey,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                          Text(
                                            '+91-${widget.mobileNo}',
                                            style: AppTextSizes.regular(context)
                                                .copyWith(
                                                  color: AppColors.colorBlack,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(height: verticalSpacingXL),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: List.generate(
                                        6,
                                        (index) => Expanded(
                                          child: Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: responsive.spacing(4),
                                            ),
                                            child: TextFormField(
                                              controller: _controllers[index],
                                              focusNode: _focusNodes[index],
                                              cursorColor: Colors.black,
                                              showCursor: true,
                                              style:
                                                  AppTextSizes.regular(
                                                    context,
                                                  ).copyWith(
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.colorBlack,
                                                  ),
                                              textAlign: TextAlign.center,
                                              maxLength: 1,
                                              keyboardType:
                                                  TextInputType.number,
                                              decoration: InputDecoration(
                                                filled: false,
                                                border: UnderlineInputBorder(
                                                  borderSide: BorderSide(
                                                    color: AppColors.colorGrey,
                                                    width: responsive.size(1),
                                                  ),
                                                ),
                                                counterText: '',
                                                focusedBorder:
                                                    UnderlineInputBorder(
                                                      borderSide: BorderSide(
                                                        color:
                                                            AppColors.primary,
                                                        width: responsive.size(
                                                          2,
                                                        ),
                                                      ),
                                                    ),
                                                enabledBorder:
                                                    UnderlineInputBorder(
                                                      borderSide: BorderSide(
                                                        color:
                                                            AppColors.colorGrey,
                                                        width: responsive.size(
                                                          1,
                                                        ),
                                                      ),
                                                    ),
                                              ),
                                              onChanged: (value) {
                                                _handleOtpFieldChanged(
                                                  context,
                                                  index,
                                                  value,
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: verticalSpacingXL),
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        left: 12,
                                        right: 8,
                                      ),
                                      child: Row(
                                        children: [
                                          Text(
                                            'Didn\'t receive the OTP?',
                                            style: AppTextSizes.regular(context)
                                                .copyWith(
                                                  color: AppColors.colorGrey,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                          SizedBox(
                                            width: responsive.spacing(8),
                                          ),
                                          _buildResendText(context),
                                        ],
                                      ),
                                    ),
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
                                      child: ElevatedButton(
                                        onPressed:
                                            (_isVerifyingOtp ||
                                                _isProcessingSuccess)
                                            ? null
                                            : () {
                                                if (!_previousValues.any(
                                                  (element) => element.isEmpty,
                                                )) {
                                                  _verifyOtp();
                                                } else {
                                                  AppSnackbar.showWarning(
                                                    context,
                                                    'Please enter the complete OTP',
                                                    bottomPosition: 150,
                                                  );
                                                }
                                              },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          foregroundColor: Colors.white,
                                          padding: EdgeInsets.symmetric(
                                            vertical: responsive.spacing(16),
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              responsive.size(5),
                                            ),
                                          ),
                                          elevation: 0,
                                        ),
                                        child: _isVerifyingOtp
                                            ? SizedBox(
                                                width: responsive.size(24),
                                                height: responsive.size(24),
                                                child: CircularProgressIndicator(
                                                  strokeWidth: responsive.size(
                                                    2.5,
                                                  ),
                                                  valueColor:
                                                      const AlwaysStoppedAnimation<
                                                        Color
                                                      >(Colors.white),
                                                ),
                                              )
                                            : Text(
                                                'VERIFY & PROCEED',
                                                style:
                                                    AppTextSizes.regular(
                                                      context,
                                                    ).copyWith(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      letterSpacing: responsive
                                                          .size(0.5),
                                                    ),
                                              ),
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

  void _handleOtpFieldChanged(BuildContext context, int index, String value) {
    if (value.length > 1) {
      final chars = value.split('');
      _controllers[index].text = chars[0];
      _previousValues[index] = chars[0];
      for (int i = 1; i < chars.length && index + i < 6; i++) {
        _controllers[index + i].text = chars[i];
        _previousValues[index + i] = chars[i];
      }
      if (index + chars.length < 6) {
        _focusNodes[index + chars.length].requestFocus();
      } else {
        FocusScope.of(context).unfocus();
      }
      return;
    }

    _previousValues[index] = value;

    if (value.length == 1) {
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        FocusScope.of(context).unfocus();
      }
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  Widget _buildResendText(BuildContext context) {
    if (_seconds > 0) {
      return Text(
        'Resend in ${_formatTime(_seconds)}',
        style: AppTextSizes.regular(
          context,
        ).copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
      );
    }

    if (_isProcessingSuccess) {
      return Text(
        'Resend OTP',
        style: AppTextSizes.regular(
          context,
        ).copyWith(color: AppColors.colorGrey, fontWeight: FontWeight.bold),
      );
    }

    return GestureDetector(
      onTap: _resendOtp,
      child: Text(
        'Resend OTP',
        style: AppTextSizes.regular(
          context,
        ).copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
      ),
    );
  }

  // --------------------------------
  // Timer helpers
  // --------------------------------
  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_seconds > 0) {
        setState(() => _seconds--);
      } else {
        _timer?.cancel();
      }
    });
  }

  String _formatTime(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final remainingSeconds = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remainingSeconds';
  }

  // --------------------------------
  // OTP flow
  // --------------------------------
  Future<void> _verifyOtp() async {
    if (_isVerifyingOtp) return;
    _timer?.cancel();
    _timer = null;
    final online = ref
        .read(internetStatusStreamProvider)
        .maybeWhen(data: (v) => v, orElse: () => false);
    if (!online) {
      AppSnackbar.showOfflineWarning(
        context,
        "You're offline. Please connect to the internet",
      );
      return;
    }

    setState(() {
      _isVerifyingOtp = true;
      _seconds = 0; // Stop timer display immediately
    });
    debugPrint('🔐 OTP: _verifyOtp() started');

    try {
      final otp = _previousValues.join();
      if (otp.length < 6) {
        AppSnackbar.showError(
          context,
          'Please enter a valid OTP',
          bottomPosition: 150,
        );
        return;
      }

      final authRepo = ref.read(authRepositoryProvider);
      final result = await authRepo.verifyOtp(widget.mobileNo, otp);

      if (!result.isSuccess) {
        if (!mounted) return;
        AppSnackbar.showError(
          context,
          result.errorMessage ?? 'Invalid OTP. Please try again.',
          bottomPosition: 150,
        );
        return;
      }

      debugPrint('✅ OTP: verification succeeded');

      // Show success snack
      if (!mounted) return;
      AppSnackbar.showSuccess(
        context,
        'OTP verified successfully! Redirecting...',
        duration: const Duration(seconds: 2),
        bottomPosition: 150,
      );

      // mark processing success so UI (resend/verify) is disabled while we persist and navigate
      if (mounted) setState(() => _isProcessingSuccess = true);

      // STOP timer immediately — avoids extra work on UI thread
      _timer?.cancel();
      _timer = null;

      // -------------------------
      // Persist mobile number into MobileNumberTable (single-row table)
      // -------------------------
      try {
        await MobileNumberTable.instance.saveMobileNumber(
          mobileNo: widget.mobileNo,
          countryCode: '+91',
        );
        debugPrint('💾 Saved mobile to MobileNumberTable: ${widget.mobileNo}');
      } catch (e) {
        debugPrint('❌ Failed to save mobile number: $e');
      }

      // ====================================================================
      // STEP: FCM TOKEN GENERATION (existing logic)
      // ====================================================================
      try {
        final fcmService = FCMTokenService.instance;
        final granted =
            await fcmService.isPermissionGranted() ||
            await fcmService.requestPermission();

        if (granted) {
          final token = await fcmService.getToken();
          if (token != null) {
            await FCMTokenStorage.instance.saveFCMToken(token, widget.mobileNo);
            debugPrint('💾 OTP Flow: FCM Token saved to secure storage');

            // Register refresh listener once (idempotent)
            fcmService.registerOnTokenRefreshOnce((newToken) async {
              await FCMTokenStorage.instance.updateFCMToken(newToken);
              debugPrint('🔄 OTP Flow: Refreshed FCM Token handled');
            });
          } else {
            debugPrint('⚠️ OTP Flow: FCM Token was null');
          }
        } else {
          debugPrint('⚠️ OTP Flow: Notification permission denied');
        }
      } catch (e) {
        debugPrint('❌ OTP Flow: Error handling FCM token - $e');
      }

      // ====================================================================
      // Continue with existing contacts sync & navigation
      // ====================================================================
      bool ok = false;
      try {
        debugPrint('🚦 OTP: starting contacts sync now');
        // show modal progress dialog while syncing
        // OPTIMIZED: Updated message for large contact lists
        if (mounted) {
          _showProgressDialog(
            'Syncing your contacts...\nThis may take a few minutes for large contact lists.\nPlease wait...',
          );
        }
        ok = await _syncContacts();
        debugPrint('✅ OTP: contacts sync attempt finished');
      } catch (e) {
        debugPrint('❌ OTP: contacts sync error - $e');
      } finally {
        // ensure dialog is hidden
        if (mounted) _hideProgressDialog();
      }

      // Navigate (after everything important is awaited)
      if (ok) {
        debugPrint('🧭 OTP: contacts sync succeeded');
        if (mounted) {
          await AppSnackbar.showSuccess(
            context,
            'Contacts synced successfully',
            bottomPosition: 150,
            duration: const Duration(seconds: 1),
          );
        }
        NavigationService.goToCurrentUserProfile(fromOtp: true);
      } else {
        if (mounted) {
          AppSnackbar.showWarning(
            context,
            'Contact sync failed.',
            duration: const Duration(seconds: 2),
            bottomPosition: 150,
          );
          final retry = await _confirmContinueAfterSyncFailure();
          if (retry == true) {
            if (mounted) {
              AppSnackbar.showInfo(
                context,
                'Retrying sync...',
                duration: const Duration(seconds: 1),
                bottomPosition: 150,
              );
            }
            bool okRetry = false;
            try {
              // show dialog while retrying
              if (mounted) _showProgressDialog('Retrying contact sync...');
              okRetry = await _syncContacts();
            } catch (_) {
            } finally {
              if (mounted) _hideProgressDialog();
            }
            if (okRetry) {
              debugPrint(
                '🧭 OTP: navigating to CurrentUserProfile after retry',
              );
              if (mounted) {
                await AppSnackbar.showSuccess(
                  context,
                  'Contacts synced successfully',
                  bottomPosition: 150,
                  duration: const Duration(seconds: 1),
                );
              }
              NavigationService.goToCurrentUserProfile(fromOtp: true);
            } else {
              if (mounted) {
                AppSnackbar.showError(
                  context,
                  'Sync failed again. You can retry later from settings.',
                  duration: const Duration(seconds: 3),
                  bottomPosition: 150,
                );
              }
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(
          context,
          'An error occurred during verification. Please try again.',
          bottomPosition: 150,
        );
      }
      debugPrint('❌ OTP: Verification error - $e');
    } finally {
      // Make sure to clear verifying flag; keep isProcessingSuccess true for navigation flow until
      // the page is dismissed or navigation occurs.
      if (mounted) setState(() => _isVerifyingOtp = false);
    }
  }

  // --------------------------------
  // Resend OTP
  // --------------------------------
  Future<void> _resendOtp() async {
    try {
      final online = ref
          .read(internetStatusStreamProvider)
          .maybeWhen(data: (v) => v, orElse: () => false);
      if (!online) {
        AppSnackbar.showOfflineWarning(
          context,
          "You're offline. Please connect to the internet",
        );
        return;
      }

      AppSnackbar.showInfo(
        context,
        'Sending OTP...',
        duration: const Duration(seconds: 2),
      );

      final authRepo = ref.read(authRepositoryProvider);
      final result = await authRepo.resendOtp(widget.mobileNo);

      if (result.isSuccess) {
        setState(() {
          _seconds = 90;
          _startTimer();
        });
        if (!mounted) return;
        AppSnackbar.showSuccess(
          context,
          'OTP sent successfully',
          duration: const Duration(seconds: 2),
          bottomPosition: 150,
        );
      } else {
        if (!mounted) return;
        AppSnackbar.showError(
          context,
          'Failed to send OTP. Please try again.',
          duration: const Duration(seconds: 2),
          bottomPosition: 150,
        );
      }
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.showError(
        context,
        'Error sending OTP. Please check your connection and try again.',
        duration: const Duration(seconds: 3),
        bottomPosition: 150,
      );
    }
  }

  // ====================================================================
  // CONTACTS SYNC METHOD
  // ====================================================================

  // --------------------------------
  // Contacts sync (post-OTP)
  // --------------------------------
  Future<bool> _syncContacts() async {
    try {
      print('🔵 Contacts Sync: Started');

      final isolateHandler = ContactSyncIsolateHandler();
      final syncResponse = await isolateHandler.syncContacts();

      if (syncResponse.success) {
        final total = syncResponse.totalContacts ?? syncResponse.contactCount;
        final registered = syncResponse.appUsers ?? 0;
        final nonRegistered = syncResponse.regularContacts ?? 0;
        print('📦 Contacts Sync: Total=$total');
        print('🟩 Registered App Users=$registered');
        print('🟥 Non-App Users=$nonRegistered');

        final contactsNotifier = ref.read(
          contactsManagementNotifierProvider.notifier,
        );
        await contactsNotifier.refreshContacts();

        print('💾 Contacts Sync: Saved to database and providers refreshed');

        return true;
      } else {
        print(
          '❌ Contacts Sync: Failed - ${syncResponse.error ?? 'Unknown error'}',
        );
        return false;
      }
    } catch (e) {
      print('❌ Contacts Sync: Exception - $e');
      return false;
    }
  }

  // --------------------------------
  // Progress dialog helpers (modal, centered)
  // --------------------------------
  void _showProgressDialog(String message) {
    if (!_isProgressDialogVisible && mounted) {
      _isProgressDialogVisible = true;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (context) {
          return ResponsiveLayoutBuilder(
            builder: (context, constraints, breakpoint) {
              final responsive = ResponsiveSize(
                context: context,
                constraints: constraints,
                breakpoint: breakpoint,
              );

              return PopScope(
                canPop: false,
                child: Dialog(
                  insetPadding: EdgeInsets.symmetric(
                    horizontal: responsive.spacing(24),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(responsive.size(12)),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: responsive.spacing(20),
                      horizontal: responsive.spacing(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: responsive.size(28),
                          height: responsive.size(28),
                          child: CircularProgressIndicator(
                            strokeWidth: responsive.size(3),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.primary,
                            ),
                          ),
                        ),
                        SizedBox(width: responsive.spacing(16)),
                        Expanded(
                          child: Text(
                            message,
                            style: AppTextSizes.regular(context).copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.colorBlack,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    }
  }

  void _hideProgressDialog() {
    if (_isProgressDialogVisible && mounted) {
      _isProgressDialogVisible = false;
      // Use try/catch in case dialog was already popped
      try {
        Navigator.of(context, rootNavigator: true).pop();
      } catch (_) {}
    }
  }

  // --------------------------------
  // Dialog helpers - Sync failure with retry option (contacts hub style)
  // --------------------------------
  Future<bool?> _confirmContinueAfterSyncFailure() async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return ResponsiveLayoutBuilder(
          builder: (context, constraints, breakpoint) {
            final responsive = ResponsiveSize(
              context: context,
              constraints: constraints,
              breakpoint: breakpoint,
            );

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(responsive.size(8)),
              ),
              elevation: 8.0,
              backgroundColor: Theme.of(context).colorScheme.surface,
              insetPadding: EdgeInsets.symmetric(
                horizontal: responsive.spacing(24),
                vertical: responsive.spacing(24),
              ),
              child: Container(
                constraints: BoxConstraints(maxWidth: responsive.size(320)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Padding(
                      padding: EdgeInsets.all(responsive.spacing(20)),
                      child: Column(
                        children: [
                          Text(
                            'Sync Failed',
                            style: AppTextSizes.heading(context).copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                              fontSize: responsive.size(18),
                            ),
                          ),
                          SizedBox(height: responsive.spacing(12)),
                          Text(
                            'Contacts sync failed. Would you like to retry now?',
                            style: AppTextSizes.regular(context).copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.7),
                              fontSize: responsive.size(14),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    // Actions (contacts hub style)
                    Container(
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.1),
                            width: 1,
                          ),
                        ),
                      ),
                      child: IntrinsicHeight(
                        child: Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => Navigator.of(context).pop(false),
                                borderRadius: BorderRadius.only(
                                  bottomLeft: Radius.circular(
                                    responsive.size(8),
                                  ),
                                ),
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    vertical: responsive.spacing(16),
                                  ),
                                  child: Text(
                                    'Skip',
                                    style: AppTextSizes.regular(context)
                                        .copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.6),
                                          fontWeight: FontWeight.w500,
                                          fontSize: responsive.size(14),
                                        ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              width: 1,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.1),
                            ),
                            Expanded(
                              child: InkWell(
                                onTap: () => Navigator.of(context).pop(true),
                                borderRadius: BorderRadius.only(
                                  bottomRight: Radius.circular(
                                    responsive.size(8),
                                  ),
                                ),
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    vertical: responsive.spacing(16),
                                  ),
                                  child: Text(
                                    'Retry',
                                    style: AppTextSizes.regular(context)
                                        .copyWith(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: responsive.size(14),
                                        ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
