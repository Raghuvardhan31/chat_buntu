// lib/features/profile/data/repositories/profile/helper_repos/get_profile_repository.dart

import 'package:flutter/foundation.dart';
import '../../../datasources/profile_remote_datasource.dart';
import '../../../datasources/profile_local_datasource.dart';
import '../../../models/responses/profile_response_models.dart';
import '../../../models/responses/profile_result.dart';

/// Repository for getting user profile
class GetProfileRepository {
  final ProfileRemoteDataSource remoteDataSource;
  final ProfileLocalDataSource localDataSource;

  GetProfileRepository({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  void _log(String message) {
    if (kDebugMode) debugPrint(message);
  }

  Future<ProfileResult<GetProfileResponseModel>> getCurrentUserProfile() async {
    try {
      _log('[ProfileRepo:Get] request -> remote');
      final response = await remoteDataSource.getCurrentUserProfile();

      if (response.isSuccess && response.data != null) {
        _log('[ProfileRepo:Get] success -> saving to local');
        await localDataSource.saveProfile(response.data!);
        _log('[ProfileRepo:Get] local save complete');
        return ProfileResult.success(response);
      } else {
        _log('[ProfileRepo:Get] failure -> message=${response.message}');
        return ProfileResult.failure(
          message: response.message,
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      _log('[ProfileRepo:Get] exception -> $e');
      return ProfileResult.failure(message: e.toString());
    }
  }
}
