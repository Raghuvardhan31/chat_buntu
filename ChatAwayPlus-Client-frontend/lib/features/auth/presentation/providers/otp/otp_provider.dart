// lib/features/auth/presentation/providers/otp_verify_providers/otp_verification_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chataway_plus/features/auth/presentation/providers/mobile_number/mobile_number_provider.dart';
import 'package:chataway_plus/features/auth/presentation/providers/otp/otp_state.dart';
import 'package:chataway_plus/features/auth/presentation/providers/otp/otp_notifier.dart';

/// Extension methods for WidgetRef to provide easier access to OTP verification functionality
extension OtpVerificationProvider on WidgetRef {
  /// Get the current OTP verification state
  OtpVerificationState get otpState => watch(otpVerificationNotifierProvider);

  /// Get the OTP verification notifier for actions
  OtpVerificationNotifier get otpNotifier =>
      read(otpVerificationNotifierProvider.notifier);

  /// Check if OTP verification is currently in progress
  bool get isVerifyingOtp => otpState.isVerifying;

  /// Check if OTP resend is currently in progress
  bool get isResendingOtp => otpState.isResending;

  /// Check if any OTP operation is loading
  bool get isOtpLoading => otpState.isLoading;

  /// Check if resend OTP is available
  bool get canResendOtp => otpState.canResend;

  /// Get formatted time remaining for resend
  String get resendTimeFormatted =>
      otpNotifier.formatTime(otpState.secondsLeft);

  /// Get current error message, if any
  String? get otpError => otpState.error;

  /// Check if there's an active error
  bool get hasOtpError => otpState.hasError;
}

/// Extension methods for OtpVerificationState to provide convenient getters
extension OtpVerificationStateExtensions on OtpVerificationState {
  /// Check if the verification process is complete and successful
  bool get isVerificationComplete => status == OtpVerificationStatus.verified;

  /// Check if the verification failed
  bool get isVerificationFailed => status == OtpVerificationStatus.failed;

  /// Check if resend was successful
  bool get isResendSuccessful => status == OtpVerificationStatus.resent;

  /// Check if resend failed
  bool get isResendFailed => status == OtpVerificationStatus.resendFailed;

  /// Get a user-friendly status message
  String get statusMessage {
    switch (status) {
      case OtpVerificationStatus.initial:
        return 'Ready to verify';
      case OtpVerificationStatus.verifying:
        return 'Verifying OTP...';
      case OtpVerificationStatus.verified:
        return 'OTP verified successfully';
      case OtpVerificationStatus.failed:
        return 'OTP verification failed';
      case OtpVerificationStatus.resending:
        return 'Sending OTP...';
      case OtpVerificationStatus.resent:
        return 'OTP sent successfully';
      case OtpVerificationStatus.resendFailed:
        return 'Failed to send OTP';
    }
  }

  /// Get appropriate color for the current status
  String get statusColorHex {
    switch (status) {
      case OtpVerificationStatus.initial:
        return '#666666'; // Grey
      case OtpVerificationStatus.verifying:
      case OtpVerificationStatus.resending:
        return '#2196F3'; // Blue
      case OtpVerificationStatus.verified:
      case OtpVerificationStatus.resent:
        return '#4CAF50'; // Green
      case OtpVerificationStatus.failed:
      case OtpVerificationStatus.resendFailed:
        return '#F44336'; // Red
    }
  }
}

/// Extension methods for OtpVerificationNotifier to provide utility functions
extension OtpVerificationNotifierExtensions on OtpVerificationNotifier {
  /// Initialize with phone number and start the process
  void initializeAndStart(String phoneNumber) {
    initialize(phoneNumber);
  }

  /// Verify OTP with additional validation
  Future<bool> verifyOtpWithValidation(String otp) async {
    // Additional client-side validation
    if (otp.isEmpty) {
      return false;
    }

    if (otp.length != 6) {
      return false;
    }

    if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
      return false;
    }

    return await verifyOtp(otp);
  }

  /// Reset and clear all data
  void resetAndClear() {
    reset();
    clearError();
  }
}

/// Utility class for OTP-related constants and helpers
class OtpVerificationConstants {
  static const int otpLength = 6;
  static const int initialTimerSeconds = 90;
  static const Duration snackBarDuration = Duration(seconds: 3);
  static const Duration successMessageDuration = Duration(seconds: 2);

  /// Validate OTP format
  static bool isValidOtpFormat(String otp) {
    return otp.length == otpLength && RegExp(r'^\d{6}$').hasMatch(otp);
  }

  /// Generate test OTP (for development/testing)
  static String generateTestOtp() {
    return '123456'; // Should only be used in development
  }

  /// Format phone number for display
  static String formatPhoneForDisplay(String phone) {
    if (phone.startsWith('+91')) {
      return phone;
    }
    return '+91-$phone';
  }
}

/// Helper class for OTP verification analytics and logging
class OtpVerificationAnalytics {
  static void logVerificationAttempt(String phoneNumber) {
    // Log verification attempt
    print('OTP Verification attempted for: ${_maskPhoneNumber(phoneNumber)}');
  }

  static void logVerificationSuccess(String phoneNumber) {
    // Log successful verification
    print('OTP Verification successful for: ${_maskPhoneNumber(phoneNumber)}');
  }

  static void logVerificationFailure(String phoneNumber, String error) {
    // Log verification failure
    print(
      'OTP Verification failed for: ${_maskPhoneNumber(phoneNumber)}, Error: $error',
    );
  }

  static void logResendAttempt(String phoneNumber) {
    // Log resend attempt
    print('OTP Resend attempted for: ${_maskPhoneNumber(phoneNumber)}');
  }

  static String _maskPhoneNumber(String phone) {
    if (phone.length <= 4) return phone;
    final masked = phone
        .substring(0, phone.length - 4)
        .replaceAll(RegExp(r'\d'), '*');
    return masked + phone.substring(phone.length - 4);
  }
}
