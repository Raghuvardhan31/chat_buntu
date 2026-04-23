// lib/features/profile/data/repositories/profile/helper_repos/update_name_repository.dart

import 'package:flutter/foundation.dart';
import '../../../datasources/profile_remote_datasource.dart';
import '../../../datasources/profile_local_datasource.dart';
import '../../../models/requests/profile_request_models.dart';
import '../../../models/responses/profile_response_models.dart';
import '../../../models/responses/profile_result.dart';

/// Repository for updating user name
class UpdateNameRepository {
  final ProfileRemoteDataSource remoteDataSource;
  final ProfileLocalDataSource localDataSource;

  UpdateNameRepository({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  void _log(String message) {
    if (kDebugMode) debugPrint(message);
  }

  Future<ProfileResult<UpdateProfileResponseModel>> updateName(
    String firstName,
    String? lastName,
  ) async {
    try {
      _log('[ProfileRepo:UpdateName] request -> remote firstName=$firstName');
      final request = UpdateNameRequestModel(
        firstName: firstName,
        lastName: lastName,
      );

      final response = await remoteDataSource.updateName(request);

      if (response.isSuccess && response.data != null) {
        _log(
          '[ProfileRepo:UpdateName] remote success -> save immediate snapshot',
        );
        await localDataSource.saveProfile(response.data!);
        _log('[ProfileRepo:UpdateName] post-write GET my-profile');
        final latest = await remoteDataSource.getCurrentUserProfile();
        if (latest.isSuccess && latest.data != null) {
          _log('[ProfileRepo:UpdateName] saving latest snapshot from GET');
          await localDataSource.saveProfile(latest.data!);
        } else {
          _log(
            '[ProfileRepo:UpdateName] GET failed -> kept immediate snapshot',
          );
        }
        return ProfileResult.success(response);
      } else {
        _log(
          '[ProfileRepo:UpdateName] remote failure -> message=${response.message}',
        );
        return ProfileResult.failure(
          message: response.message,
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      _log('[ProfileRepo:UpdateName] exception -> $e');
      return ProfileResult.failure(message: e.toString());
    }
  }
}
