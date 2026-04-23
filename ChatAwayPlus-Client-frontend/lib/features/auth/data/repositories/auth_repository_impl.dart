import '../models/response/auth_response_model.dart';
import '../models/response/auth_result.dart';
import 'helper_repos/send_otp_repository.dart';
import 'helper_repos/verify_otp_repository.dart';
import 'helper_repos/resend_otp_repository.dart';
import 'auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final SendOtpRepository sendOtpRepo;
  final VerifyOtpRepository verifyOtpRepo;
  final ResendOtpRepository resendOtpRepo;

  AuthRepositoryImpl({
    required this.sendOtpRepo,
    required this.verifyOtpRepo,
    required this.resendOtpRepo,
  });

  @override
  Future<AuthResult<OtpRequestResponseModel>> sendOtp(
    String mobileNo, {
    String countryCode = '+91',
  }) => sendOtpRepo.sendOtp(mobileNo, countryCode: countryCode);

  @override
  Future<AuthResult<OtpVerificationResponseModel>> verifyOtp(
    String mobileNo,
    String otp, {
    String countryCode = '+91',
    String? deviceId,
    String? fcmToken,
  }) => verifyOtpRepo.verifyOtp(
    mobileNo,
    otp,
    countryCode: countryCode,
    deviceId: deviceId,
    fcmToken: fcmToken,
  );

  @override
  Future<AuthResult<OtpRequestResponseModel>> resendOtp(
    String mobileNo, {
    String countryCode = '+91',
    String reason = 'user_request',
    int attemptCount = 1,
  }) => resendOtpRepo.resendOtp(
    mobileNo,
    countryCode: countryCode,
    reason: reason,
    attemptCount: attemptCount,
  );

  // TODO: Implement remaining methods from AuthRepository
  @override
  Future<bool> isAuthenticated() async => false;
  @override
  Future<void> logout() async {}
  @override
  Future<AuthResult<AuthenticationData>> refreshToken() async =>
      AuthResult.failure(errorMessage: 'Not implemented');
  @override
  Future<AuthenticationData?> getAuthenticationData() async => null;
  @override
  Future<UserProfileData?> getUserProfile() async => null;
  @override
  Future<void> clearExpiredData() async {}
  @override
  Future<void> updateLastActivity() async {}
}
