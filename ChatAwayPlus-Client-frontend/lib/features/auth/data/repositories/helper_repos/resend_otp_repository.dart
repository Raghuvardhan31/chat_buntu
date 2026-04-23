// lib/features/auth/data/repositories/functions/resend_otp_repository.dart

import '../../datasources/auth_remote_datasource.dart';
import '../../models/requests/auth_request_models.dart';
import '../../models/response/auth_response_model.dart';
import '../../models/response/auth_result.dart';

class ResendOtpRepository {
  final AuthRemoteDataSource remoteDataSource;

  ResendOtpRepository({required this.remoteDataSource});

  Future<AuthResult<OtpRequestResponseModel>> resendOtp(
    String mobileNo, {
    String countryCode = '+91',
    String reason = 'user_request',
    int attemptCount = 1,
  }) async {
    try {
      final request = ResendOtpRequestModel(
        mobileNo: mobileNo,
        countryCode: countryCode,
        reason: reason,
        attemptCount: attemptCount,
      );

      if (!request.isValid()) {
        return AuthResult.failure(
          errorMessage: request.validationError ?? 'Invalid mobile number',
          errorCode: 'VALIDATION_ERROR',
        );
      }

      final response = await remoteDataSource.resendOtp(request);

      if (response.isSuccess) {
        return AuthResult.success(response);
      } else {
        return AuthResult.failure(
          errorMessage: response.errorMessage ?? 'Failed to resend OTP',
          errorCode: 'RESEND_OTP_FAILED',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return AuthResult.failure(
        errorMessage: 'Unexpected error while resending OTP',
        errorCode: 'RESEND_OTP_EXCEPTION',
        exception: e is Exception ? e : Exception(e.toString()),
      );
    }
  }
}
