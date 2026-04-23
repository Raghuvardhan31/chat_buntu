
import '../models/response/auth_result.dart';
import '../models/response/auth_response_model.dart';

abstract class AuthRepository {
  Future<AuthResult<OtpRequestResponseModel>> sendOtp(
      String mobileNo, {
        String countryCode = '+91',
      });

  Future<AuthResult<OtpVerificationResponseModel>> verifyOtp(
      String mobileNo,
      String otp, {
        String countryCode = '+91',
        String? deviceId,
        String? fcmToken,
      });

  Future<AuthResult<OtpRequestResponseModel>> resendOtp(
      String mobileNo, {
        String countryCode = '+91',
        String reason = 'user_request',
        int attemptCount = 1,
      });

  Future<bool> isAuthenticated();
  Future<AuthenticationData?> getAuthenticationData();
  Future<UserProfileData?> getUserProfile();
  Future<void> logout();
  Future<AuthResult<AuthenticationData>> refreshToken();
  Future<void> clearExpiredData();
  Future<void> updateLastActivity();
}
