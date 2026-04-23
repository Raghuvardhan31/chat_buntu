// lib/features/auth/data/repositories/functions/send_otp_repository.dart
import 'package:flutter/foundation.dart';
import 'package:chataway_plus/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:chataway_plus/features/auth/data/datasources/auth_local_datasource.dart';

import '../../models/requests/auth_request_models.dart';
import '../../models/response/auth_response_model.dart';
import '../../models/response/auth_result.dart';
// import 'package:chataway_plus/features/auth/data/models/auth_result.dart';
// import 'package:chataway_plus/features/auth/data/models/auth_request_models.dart';
// import 'package:chataway_plus/features/auth/data/models/auth_response_models.dart';

class SendOtpRepository {
  final AuthRemoteDataSource remoteDataSource;
  final AuthLocalDataSource localDataSource;

  SendOtpRepository({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  Future<AuthResult<OtpRequestResponseModel>> sendOtp(
    String mobileNo, {
    String countryCode = '+91',
  }) async {
    try {
      _log('SendOTP', 'Sending OTP to mobile number');

      final request = OtpRequestModel(
        mobileNo: mobileNo,
        countryCode: countryCode,
      );

      if (!request.isValid()) {
        _log('SendOTP', 'Invalid request: ${request.validationError}');
        return AuthResult.failure(
          errorMessage: request.validationError ?? 'Invalid mobile number',
          errorCode: 'VALIDATION_ERROR',
        );
      }

      final response = await remoteDataSource.sendOtp(request);

      if (response.isSuccess) {
        await localDataSource.saveMobileNumber(mobileNo);
        _log('SendOTP', 'OTP sent successfully');
        return AuthResult.success(response);
      } else {
        _log('SendOTP', 'Failed to send OTP: ${response.errorMessage}');
        return AuthResult.failure(
          errorMessage: response.errorMessage ?? 'Failed to send OTP',
          errorCode: 'SEND_OTP_FAILED',
          statusCode: response.statusCode,
        );
      }
    } catch (e, st) {
      _log('SendOTP', 'Exception occurred: $e\n$st');
      return AuthResult.failure(
        errorMessage: 'An unexpected error occurred while sending OTP',
        errorCode: 'SEND_OTP_EXCEPTION',
        exception: e is Exception ? e : Exception(e.toString()),
      );
    }
  }

  void _log(String op, String message) {
    if (kDebugMode) print('SendOtpRepository [$op]: $message');
  }
}
