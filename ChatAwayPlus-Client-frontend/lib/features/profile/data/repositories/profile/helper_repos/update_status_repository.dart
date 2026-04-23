// lib/features/profile/data/repositories/profile/helper_repos/update_status_repository.dart

import 'package:flutter/foundation.dart';
import '../../../datasources/profile_remote_datasource.dart';
import '../../../datasources/profile_local_datasource.dart';
import '../../../models/requests/profile_request_models.dart';
import '../../../models/responses/profile_response_models.dart';
import '../../../models/responses/profile_result.dart';

/// Repository for updating user status
class UpdateStatusRepository {
  final ProfileRemoteDataSource remoteDataSource;
  final ProfileLocalDataSource localDataSource;

  UpdateStatusRepository({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  void _log(String message) {
    if (kDebugMode) debugPrint(message);
  }

  Future<ProfileResult<UpdateProfileResponseModel>> updateStatus(
    String content,
  ) async {
    try {
      final request = UpdateStatusRequestModel(content: content);

      final response = await remoteDataSource.updateStatus(request);

      if (response.isSuccess && response.data != null) {
        // Save immediate snapshot to local
        await localDataSource.saveProfile(response.data!);
        // Post-write GET to ensure freshest state
        _log('[ProfileRepo:UpdateStatus] post-write GET my-profile');
        final latest = await remoteDataSource.getCurrentUserProfile();
        if (latest.isSuccess && latest.data != null) {
          _log('[ProfileRepo:UpdateStatus] saving latest snapshot from GET');
          await localDataSource.saveProfile(latest.data!);
        } else {
          _log(
            '[ProfileRepo:UpdateStatus] GET failed -> kept immediate snapshot',
          );
        }
        return ProfileResult.success(response);
      } else {
        return ProfileResult.failure(
          message: response.message,
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ProfileResult.failure(message: e.toString());
    }
  }
}
