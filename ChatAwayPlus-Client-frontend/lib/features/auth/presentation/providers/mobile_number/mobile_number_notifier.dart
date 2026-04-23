// lib/features/auth/presentation/providers/auth_notifier.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/repositories/auth_repository.dart';
import 'mobile_number_state.dart';

class PhoneNumberEntryPageNotifier
    extends StateNotifier<PhoneNumberEntryPageNotifierState> {
  final AuthRepository _authRepository;

  Timer? _otpTimer;
  static const int otpDurationSec = 120; // 2 minutes
  static const Duration minOtpRequestInterval = Duration(seconds: 30);
  DateTime? _lastOtpRequestTime;

  PhoneNumberEntryPageNotifier(this._authRepository)
    : super(const PhoneNumberEntryPageNotifierState());

  Future<void> sendOtp(String phone) async {
    debugPrint('SENDOTP: Starting for $phone');
    final now = DateTime.now();
    if (_lastOtpRequestTime != null &&
        now.difference(_lastOtpRequestTime!) < minOtpRequestInterval) {
      state = state.copyWith(
        error: 'Please wait before requesting another OTP',
      );
      debugPrint('SENDOTP: Request throttled');
      return;
    }

    // NOTE: Permission check removed - already validated in UI layer
    // Permissions are checked in PhoneNumberEntryPage before calling sendOtp

    // set phone early so listeners can read it
    state = state.copyWith(loading: true, error: null, phone: phone);
    _lastOtpRequestTime = DateTime.now();
    debugPrint('SENDOTP: calling repo.sendOtp for $phone');

    try {
      final result = await _authRepository.sendOtp(phone);
      debugPrint(
        'SENDOTP: authRepository.sendOtp returned: ${result.isSuccess}',
      );

      if (result.isSuccess) {
        // keep phone in state (already set above), set otpSent
        state = state.copyWith(
          loading: false,
          otpSent: true,
          buttonDisabled: true,
          secondsLeft: otpDurationSec,
        );
        debugPrint(
          'SENDOTP: state updated -> otpSent=true, phone=${state.phone}',
        );
        _startTimer();
      } else {
        state = state.copyWith(
          loading: false,
          error: result.errorMessage ?? 'Failed to send OTP. Please try again.',
          buttonDisabled: false,
        );
        debugPrint('SENDOTP: failed -> ${state.error}');
      }
    } catch (e, st) {
      debugPrint('SENDOTP: exception -> $e\n$st');
      state = state.copyWith(
        loading: false,
        error: e.toString(),
        buttonDisabled: false,
      );
    }
  }

  Future<void> resendOtp() async {
    // Resend uses same flow, but respect min interval
    if (state.phone == null || state.phone!.isEmpty) {
      state = state.copyWith(error: 'Phone not available to resend OTP');
      return;
    }
    await sendOtp(state.phone!);
  }

  void _startTimer() {
    _otpTimer?.cancel();
    _otpTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      final left = state.secondsLeft - 1;
      if (left <= 0) {
        t.cancel();
        state = state.copyWith(
          secondsLeft: 0,
          buttonDisabled: false,
          otpSent: false,
        );
      } else {
        state = state.copyWith(secondsLeft: left);
      }
    });
  }

  void cancelTimer() {
    _otpTimer?.cancel();
    _otpTimer = null;
  }

  void reset() {
    cancelTimer();
    _lastOtpRequestTime = null;
    state = const PhoneNumberEntryPageNotifierState();
  }

  @override
  void dispose() {
    cancelTimer();
    super.dispose();
  }
}
