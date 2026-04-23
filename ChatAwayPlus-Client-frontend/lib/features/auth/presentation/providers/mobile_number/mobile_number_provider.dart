// lib/features/auth/presentation/providers/auth_providers.dart

import 'package:chataway_plus/core/storage/token_storage.dart';
import 'package:chataway_plus/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:chataway_plus/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:chataway_plus/features/auth/data/repositories/helper_repos/send_otp_repository.dart';
import 'package:chataway_plus/features/auth/data/repositories/helper_repos/verify_otp_repository.dart';
import 'package:chataway_plus/features/auth/data/repositories/helper_repos/resend_otp_repository.dart';
import 'package:chataway_plus/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/repositories/auth_repository.dart';
import 'mobile_number_notifier.dart';
import 'mobile_number_state.dart';
import '../otp/otp_notifier.dart';
import '../otp/otp_state.dart';
import 'package:chataway_plus/core/services/permissions/index.dart';
import 'package:http/http.dart' as http;

// ===================================================================
// DATA LAYER PROVIDERS
// ===================================================================

/// HTTP Client provider
final httpClientProvider = Provider<http.Client>((ref) {
  return http.Client();
});

/// Remote datasource provider
final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  final httpClient = ref.watch(httpClientProvider);
  return AuthRemoteDataSourceImpl(httpClient: httpClient);
});

/// Local datasource provider
final authLocalDataSourceProvider = Provider<AuthLocalDataSource>((ref) {
  return AuthLocalDataSourceImpl();
});

/// Token storage provider (for sub-repos)
final tokenSecureStorageProvider = Provider<TokenSecureStorage>((ref) {
  return TokenSecureStorage.instance;
});

/// ===================================================================
/// AUTH REPOSITORY PROVIDER (split version)
// ===================================================================
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final remoteDataSource = ref.watch(authRemoteDataSourceProvider);
  final localDataSource = ref.watch(authLocalDataSourceProvider);
  final tokenStorage = ref.watch(tokenSecureStorageProvider);

  // Create the three sub-repositories
  final sendOtpRepo = SendOtpRepository(
    remoteDataSource: remoteDataSource,
    localDataSource: localDataSource,
  );

  final verifyOtpRepo = VerifyOtpRepository(
    remoteDataSource: remoteDataSource,
    localDataSource: localDataSource,
    tokenStorage: tokenStorage,
  );

  final resendOtpRepo = ResendOtpRepository(remoteDataSource: remoteDataSource);

  // ✅ AuthRepositoryImpl now only takes these three repos
  return AuthRepositoryImpl(
    sendOtpRepo: sendOtpRepo,
    verifyOtpRepo: verifyOtpRepo,
    resendOtpRepo: resendOtpRepo,
  );
});

// ===================================================================
// PRESENTATION LAYER PROVIDERS
// ===================================================================

/// Permission service provider
final contactPermissionServiceProvider = Provider<ContactPermissionsService>((
  ref,
) {
  return ContactPermissionsService();
});

/// Auth notifier provider
final authNotifierProvider =
    StateNotifierProvider<
      PhoneNumberEntryPageNotifier,
      PhoneNumberEntryPageNotifierState
    >((ref) {
      final authRepo = ref.read(authRepositoryProvider);
      // Permission check moved to UI layer (PhoneNumberEntryPage)
      return PhoneNumberEntryPageNotifier(authRepo);
    });

/// OTP verification notifier provider
final otpVerificationNotifierProvider =
    StateNotifierProvider<OtpVerificationNotifier, OtpVerificationState>((ref) {
      final authRepository = ref.read(authRepositoryProvider);
      return OtpVerificationNotifier(authRepository: authRepository, ref: ref);
    });
