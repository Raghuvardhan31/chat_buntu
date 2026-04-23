// lib/features/auth/data/repositories/functions/verify_otp_repository.dart
import 'package:flutter/foundation.dart';
import 'package:chataway_plus/core/notifications/firebase/fcm_token_service.dart';
import 'package:chataway_plus/core/notifications/firebase/fcm_token_sending.dart';
import 'package:chataway_plus/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:chataway_plus/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:chataway_plus/core/storage/token_storage.dart';
import 'package:chataway_plus/core/storage/fcm_token_storage.dart';

import '../../models/requests/auth_request_models.dart';
import '../../models/response/auth_response_model.dart';
import '../../models/response/auth_result.dart';

// import 'package:chataway_plus/features/auth/data/models/auth_result.dart';
// import 'package:chataway_plus/features/auth/data/models/auth_request_models.dart';
// import 'package:chataway_plus/features/auth/data/models/auth_response_models.dart';

class VerifyOtpRepository {
  final AuthRemoteDataSource remoteDataSource;
  final AuthLocalDataSource localDataSource;
  final TokenSecureStorage tokenStorage;
  final FCMTokenStorage fcmTokenStorage;

  VerifyOtpRepository({
    required this.remoteDataSource,
    required this.localDataSource,
    TokenSecureStorage? tokenStorage,
    FCMTokenStorage? fcmTokenStorage,
  }) : tokenStorage = tokenStorage ?? TokenSecureStorage.instance,
       fcmTokenStorage = fcmTokenStorage ?? FCMTokenStorage.instance;

  Future<AuthResult<OtpVerificationResponseModel>> verifyOtp(
    String mobileNo,
    String otp, {
    String countryCode = '+91',
    String? deviceId,
    String? fcmToken,
  }) async {
    try {
      _log('VerifyOTP', 'Verifying OTP for mobile number');

      // Get FCM token if not provided
      fcmToken ??= await FCMTokenService.instance.getToken();

      final request = OtpVerificationRequestModel(
        mobileNo: mobileNo,
        otp: otp,
        countryCode: countryCode,
        deviceId: deviceId,
        fcmToken: fcmToken,
      );

      if (!request.isValid()) {
        _log('VerifyOTP', 'Invalid request: ${request.validationError}');
        return AuthResult.failure(
          errorMessage:
              request.validationError ?? 'Invalid OTP or mobile number',
          errorCode: 'VALIDATION_ERROR',
        );
      }

      final response = await remoteDataSource.verifyOtp(request);

      if (response.isSuccess && response.authData != null) {
        await _handleSuccessfulAuthentication(response, mobileNo, fcmToken);
        _log('VerifyOTP', 'OTP verified successfully');
        return AuthResult.success(response);
      } else {
        _log('VerifyOTP', 'OTP verification failed: ${response.errorMessage}');
        return AuthResult.failure(
          errorMessage: response.errorMessage ?? 'Invalid OTP',
          errorCode: 'VERIFY_OTP_FAILED',
          statusCode: response.statusCode,
        );
      }
    } catch (e, st) {
      _log('VerifyOTP', 'Exception occurred: $e\n$st');
      return AuthResult.failure(
        errorMessage: 'An unexpected error occurred during OTP verification',
        errorCode: 'VERIFY_OTP_EXCEPTION',
        exception: e is Exception ? e : Exception(e.toString()),
      );
    }
  }

  Future<void> _handleSuccessfulAuthentication(
    OtpVerificationResponseModel response,
    String mobileNo,
    String? fcmToken,
  ) async {
    try {
      _log('HandleAuth', 'Processing successful authentication');

      final authData = response.authData!;

      // Save mobile number to local datasource
      await localDataSource.saveMobileNumber(mobileNo);

      // Save tokens to secure storage
      try {
        await tokenStorage.saveToken(authData.token, mobileNo);
        await tokenStorage.saveCurrentUserIdUUID(authData.userId);
      } catch (e) {
        _log('HandleAuth', 'Failed to save to token storage: $e');
        // don't rethrow
      }

      // Handle FCM token (save locally and send to backend)
      await _handleFCMToken(fcmToken, mobileNo);

      _log('HandleAuth', 'Authentication data saved successfully');
    } catch (e, st) {
      _log('HandleAuth', 'Exception handling successful auth: $e\n$st');
    }
  }

  Future<void> _handleFCMToken(String? fcmToken, String mobileNo) async {
    try {
      if (fcmToken != null && fcmToken.isNotEmpty) {
        try {
          await fcmTokenStorage.saveFCMToken(fcmToken, mobileNo);
        } catch (e) {
          _log('HandleFCM', 'Failed to save FCM token: $e');
        }

        // send to backend (non-blocking)
        _sendFCMTokenToBackend();
      }
    } catch (e) {
      _log('HandleFCM', 'Exception handling FCM token: $e');
    }
  }

  void _sendFCMTokenToBackend() {
    // run in background without awaiting, same pattern as original
    () async {
      try {
        await FCMTokenApiService.instance.ensureFCMTokenSentToBackend();
        _log('SendFCM', 'FCM token sent to backend successfully');
      } catch (e) {
        _log('SendFCM', 'Failed to send FCM token to backend: $e');
      }
    }();
  }

  void _log(String op, String message) {
    if (kDebugMode) print('VerifyOtpRepository [$op]: $message');
  }
}
