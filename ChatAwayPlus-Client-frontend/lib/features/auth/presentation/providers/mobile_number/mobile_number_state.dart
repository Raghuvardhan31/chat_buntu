// lib/features/auth/presentation/providers/auth_state.dart
class PhoneNumberEntryPageNotifierState {
  final bool loading; // sending OTP
  final bool otpSent; // true when OTP successfully sent
  final bool buttonDisabled; // prevents multiple requests
  final int secondsLeft; // countdown seconds for OTP validity / resend
  final String? phone;
  final String? error;

  const PhoneNumberEntryPageNotifierState({
    this.loading = false,
    this.otpSent = false,
    this.buttonDisabled = false,
    this.secondsLeft = 0,
    this.phone,
    this.error,
  });

  PhoneNumberEntryPageNotifierState copyWith({
    bool? loading,
    bool? otpSent,
    bool? buttonDisabled,
    int? secondsLeft,
    String? phone,
    String? error,
  }) {
    return PhoneNumberEntryPageNotifierState(
      loading: loading ?? this.loading,
      otpSent: otpSent ?? this.otpSent,
      buttonDisabled: buttonDisabled ?? this.buttonDisabled,
      secondsLeft: secondsLeft ?? this.secondsLeft,
      phone: phone ?? this.phone,
      error: error,
    );
  }

  @override
  String toString() {
    return 'AuthState(loading: $loading, otpSent: $otpSent, buttonDisabled: $buttonDisabled, secondsLeft: $secondsLeft, phone: $phone, error: $error)';
  }
}
