// lib/features/auth/presentation/providers/otp_verification_state.dart

enum OtpVerificationStatus {
  initial,
  verifying,
  verified,
  failed,
  resending,
  resent,
  resendFailed,
}

class OtpVerificationState {
  final OtpVerificationStatus status;
  final String? error;
  final bool isProcessingSuccess;
  final int secondsLeft;
  final bool canResend;
  final String? phoneNumber;

  const OtpVerificationState({
    this.status = OtpVerificationStatus.initial,
    this.error,
    this.isProcessingSuccess = false,
    this.secondsLeft = 90,
    this.canResend = false,
    this.phoneNumber,
  });

  OtpVerificationState copyWith({
    OtpVerificationStatus? status,
    String? error,
    bool? isProcessingSuccess,
    int? secondsLeft,
    bool? canResend,
    String? phoneNumber,
  }) {
    return OtpVerificationState(
      status: status ?? this.status,
      error: error,
      isProcessingSuccess: isProcessingSuccess ?? this.isProcessingSuccess,
      secondsLeft: secondsLeft ?? this.secondsLeft,
      canResend: canResend ?? this.canResend,
      phoneNumber: phoneNumber ?? this.phoneNumber,
    );
  }

  bool get isLoading => status == OtpVerificationStatus.verifying || status == OtpVerificationStatus.resending;
  bool get isVerifying => status == OtpVerificationStatus.verifying;
  bool get isResending => status == OtpVerificationStatus.resending;
  bool get hasError => error != null && error!.isNotEmpty;

  @override
  String toString() {
    return 'OtpVerificationState(status: $status, error: $error, isProcessingSuccess: $isProcessingSuccess, secondsLeft: $secondsLeft, canResend: $canResend, phoneNumber: $phoneNumber)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OtpVerificationState &&
        other.status == status &&
        other.error == error &&
        other.isProcessingSuccess == isProcessingSuccess &&
        other.secondsLeft == secondsLeft &&
        other.canResend == canResend &&
        other.phoneNumber == phoneNumber;
  }

  @override
  int get hashCode {
    return status.hashCode ^
        error.hashCode ^
        isProcessingSuccess.hashCode ^
        secondsLeft.hashCode ^
        canResend.hashCode ^
        phoneNumber.hashCode;
  }
}
