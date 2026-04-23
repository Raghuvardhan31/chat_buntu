// lib/features/profile/data/repositories/profile/helper_repos/update_profile_picture_repository.dart

import 'package:flutter/foundation.dart';
import '../../../datasources/profile_remote_datasource.dart';
import '../../../datasources/profile_local_datasource.dart';
import '../../../models/requests/profile_request_models.dart';
import '../../../models/responses/profile_response_models.dart';
import '../../../models/responses/profile_result.dart';

/// Repository for updating profile picture
class UpdateProfilePictureRepository {
  final ProfileRemoteDataSource remoteDataSource;
  final ProfileLocalDataSource localDataSource;

  UpdateProfilePictureRepository({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  void _log(String message) {
    if (kDebugMode) debugPrint(message);
  }

  Future<ProfileResult<UpdateProfileResponseModel>> updateProfilePicture(
    String imagePath,
  ) async {
    try {
      final request = UpdateProfilePictureRequestModel(imagePath: imagePath);

      _log(
        '[ProfileRepo:UpdatePic] request: chat picture update -> $imagePath',
      );

      final response = await remoteDataSource.updateProfilePicture(request);

      _log(
        '[ProfileRepo:UpdatePic] response: ${response.isSuccess ? 'SUCCESS' : 'FAIL'}',
      );

      if (response.isSuccess && response.data != null) {
        // Save immediate snapshot
        await localDataSource.saveProfile(response.data!);
        // Post-write GET to ensure we have the freshest server snapshot
        _log('[ProfileRepo:UpdatePic] post-write GET my-profile');
        final latest = await remoteDataSource.getCurrentUserProfile();
        if (latest.isSuccess && latest.data != null) {
          _log('[ProfileRepo:UpdatePic] saving latest snapshot from GET');
          await localDataSource.saveProfile(latest.data!);
        } else {
          _log('[ProfileRepo:UpdatePic] GET failed -> kept immediate snapshot');
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
