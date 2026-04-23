// lib/features/auth/presentation/providers/otp_verification_notifier.dart

import 'dart:async';
// TODO: CONTACTS - ON HOLD
// import 'package:chataway_plus/core/isolates/contact_sync_isolate.dart';
// import 'package:chataway_plus/features/contacts/presentation/providers/contacts_management.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/repositories/auth_repository.dart';
import 'otp_state.dart';

class OtpVerificationNotifier extends StateNotifier<OtpVerificationState> {
  final AuthRepository _authRepository;
  // TODO: CONTACTS - ON HOLD (used by _syncContactsInBackground)
  // ignore: unused_field
  final Ref _ref;

  Timer? _timer;
  static const int _initialSeconds = 90;

  OtpVerificationNotifier({
    required AuthRepository authRepository,
    required Ref ref,
  }) : _authRepository = authRepository,
       _ref = ref,
       super(const OtpVerificationState());

  /// Initialize the OTP verification process with phone number
  void initialize(String phoneNumber) {
    if (state.phoneNumber != phoneNumber) {
      state = state.copyWith(
        phoneNumber: phoneNumber,
        secondsLeft: _initialSeconds,
        canResend: false,
        error: null,
      );
      _startTimer();
    }
  }

  /// Verify the entered OTP
  Future<bool> verifyOtp(String otp) async {
    if (state.isVerifying || state.phoneNumber == null) return false;

    // Validate OTP format
    if (otp.length != 6 || !RegExp(r'^\d{6}$').hasMatch(otp)) {
      state = state.copyWith(
        status: OtpVerificationStatus.failed,
        error: 'Please enter a valid 6-digit OTP',
      );
      return false;
    }

    state = state.copyWith(
      status: OtpVerificationStatus.verifying,
      error: null,
    );

    try {
      final result = await _authRepository.verifyOtp(state.phoneNumber!, otp);

      if (result.isSuccess && result.data != null) {
        state = state.copyWith(
          status: OtpVerificationStatus.verified,
          isProcessingSuccess: true,
          error: null,
        );

        // Handle post-verification flow
        await _handlePostVerification();
        return true;
      } else {
        state = state.copyWith(
          status: OtpVerificationStatus.failed,
          error: result.errorMessage ?? 'Invalid OTP. Please try again.',
        );
        return false;
      }
    } catch (e) {
      debugPrint('OTP Verification Error: $e');
      state = state.copyWith(
        status: OtpVerificationStatus.failed,
        error: 'An error occurred during verification. Please try again.',
      );
      return false;
    }
  }

  /// Resend OTP
  Future<bool> resendOtp() async {
    if (state.isResending || state.phoneNumber == null || !state.canResend) {
      return false;
    }

    state = state.copyWith(
      status: OtpVerificationStatus.resending,
      error: null,
    );

    try {
      final result = await _authRepository.resendOtp(
        state.phoneNumber!,
        attemptCount: 2, // Increment attempt count for resend
      );

      if (result.isSuccess && result.data != null) {
        state = state.copyWith(
          status: OtpVerificationStatus.resent,
          secondsLeft: _initialSeconds,
          canResend: false,
          error: null,
        );
        _startTimer();
        return true;
      } else {
        state = state.copyWith(
          status: OtpVerificationStatus.resendFailed,
          error: result.errorMessage ?? 'Failed to send OTP. Please try again.',
        );
        return false;
      }
    } catch (e) {
      debugPrint('Resend OTP Error: $e');
      state = state.copyWith(
        status: OtpVerificationStatus.resendFailed,
        error: 'Error sending OTP. Please check your connection and try again.',
      );
      return false;
    }
  }

  /// Handle post-verification flow
  Future<void> _handlePostVerification() async {
    try {
      // ====================================================================
      // TODO: CONTACTS SYNC - ON HOLD
      // ====================================================================
      /* 
      // Optional contacts sync (non-blocking for navigation decision)
      _syncContactsInBackground();
      */
    } catch (e) {
      debugPrint('Post-verification error: $e');
    } finally {
      if (mounted) {
        state = state.copyWith(isProcessingSuccess: false);
      }
    }
  }

  // ====================================================================
  // TODO: CONTACTS SYNC METHOD - ON HOLD
  // ====================================================================
  /* 
  /// Background contacts sync
  void _syncContactsInBackground() {
    // Run contacts sync in background without blocking navigation
    () async {
      try {
        final isolateHandler = ContactSyncIsolateHandler();
        final syncResponse = await isolateHandler.syncContacts();

        if (syncResponse.success) {
          final contactsNotifier = _ref.read(
            contactsManagementNotifierProvider.notifier,
          );
          await contactsNotifier.refreshContacts();
        }
      } catch (e) {
        debugPrint('Background contacts sync error: $e');
        // Silently fail - contacts sync is not critical for auth flow
      }
    }();
  }
  */

  /// Start the countdown timer
  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final newSeconds = state.secondsLeft - 1;
      if (newSeconds <= 0) {
        timer.cancel();
        state = state.copyWith(secondsLeft: 0, canResend: true);
      } else {
        state = state.copyWith(secondsLeft: newSeconds);
      }
    });
  }

  /// Clear any error messages
  void clearError() {
    if (state.hasError) {
      state = state.copyWith(error: null);
    }
  }

  /// Reset the state (useful for testing or re-initialization)
  void reset() {
    _timer?.cancel();
    state = const OtpVerificationState();
  }

  /// Format seconds to MM:SS format
  String formatTime(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final remainingSeconds = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remainingSeconds';
  }

  /// Get minutes and seconds separately
  Map<String, int> get timeComponents {
    final seconds = mounted ? state.secondsLeft : 0;
    return {'minutes': seconds ~/ 60, 'seconds': seconds % 60};
  }

  /// Check if timer is active
  bool get isTimerActive => mounted && state.secondsLeft > 0;

  /// Get progress percentage for timer (0.0 to 1.0)
  double get timerProgress {
    if (!mounted || state.secondsLeft <= 0) return 0.0;
    return (90 - state.secondsLeft) / 90.0;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
