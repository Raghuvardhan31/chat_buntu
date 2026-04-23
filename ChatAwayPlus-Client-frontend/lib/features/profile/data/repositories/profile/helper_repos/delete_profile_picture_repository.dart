// lib/features/profile/data/repositories/profile/helper_repos/delete_profile_picture_repository.dart

import 'package:flutter/foundation.dart';
import '../../../datasources/profile_remote_datasource.dart';
import '../../../datasources/profile_local_datasource.dart';
import '../../../models/responses/profile_response_models.dart';
import '../../../models/responses/profile_result.dart';

/// Repository for deleting profile picture
class DeleteProfilePictureRepository {
  final ProfileRemoteDataSource remoteDataSource;
  final ProfileLocalDataSource localDataSource;

  DeleteProfilePictureRepository({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  void _log(String message) {
    if (kDebugMode) debugPrint(message);
  }

  Future<ProfileResult<DeleteProfilePictureResponseModel>>
  deleteProfilePicture() async {
    try {
      final response = await remoteDataSource.deleteProfilePicture();

      if (response.isSuccess) {
        await localDataSource.deleteProfilePicture();
        // Post-write GET to make sure local snapshot has the freshest name/status
        _log('[ProfileRepo:DeletePic] post-write GET my-profile');
        final latest = await remoteDataSource.getCurrentUserProfile();
        if (latest.isSuccess && latest.data != null) {
          _log('[ProfileRepo:DeletePic] saving latest snapshot from GET');
          await localDataSource.saveProfile(latest.data!);
        } else {
          _log(
            '[ProfileRepo:DeletePic] GET failed -> kept local null pic only',
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
