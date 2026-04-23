// lib/features/profile/data/repositories/profile/profile_repository_impl.dart

import '../../models/current_user_profile_model.dart';
import '../../models/responses/profile_response_models.dart';
import '../../models/responses/profile_result.dart';
import '../../datasources/profile_local_datasource.dart';
import 'profile_repository.dart';
import 'helper_repos/get_profile_repository.dart';
import 'helper_repos/update_name_repository.dart';
import 'helper_repos/update_status_repository.dart';
import 'helper_repos/update_profile_picture_repository.dart';
import 'helper_repos/delete_profile_picture_repository.dart';

/// Implementation of [ProfileRepository]
/// Delegates to specific repository implementations
class ProfileRepositoryImpl implements ProfileRepository {
  final GetProfileRepository getProfileRepo;
  final UpdateNameRepository updateNameRepo;
  final UpdateStatusRepository updateStatusRepo;
  final UpdateProfilePictureRepository updateProfilePictureRepo;
  final DeleteProfilePictureRepository deleteProfilePictureRepo;
  final ProfileLocalDataSource localDataSource;

  ProfileRepositoryImpl({
    required this.getProfileRepo,
    required this.updateNameRepo,
    required this.updateStatusRepo,
    required this.updateProfilePictureRepo,
    required this.deleteProfilePictureRepo,
    required this.localDataSource,
  });

  @override
  Future<ProfileResult<GetProfileResponseModel>> getCurrentUserProfile() =>
      getProfileRepo.getCurrentUserProfile();

  @override
  Future<ProfileResult<UpdateProfileResponseModel>> updateName(
    String firstName,
    String? lastName,
  ) => updateNameRepo.updateName(firstName, lastName);

  @override
  Future<ProfileResult<UpdateProfileResponseModel>> updateStatus(
    String content,
  ) => updateStatusRepo.updateStatus(content);

  @override
  Future<ProfileResult<UpdateProfileResponseModel>> updateProfilePicture(
    String imagePath,
  ) => updateProfilePictureRepo.updateProfilePicture(imagePath);

  @override
  Future<ProfileResult<DeleteProfilePictureResponseModel>>
  deleteProfilePicture() => deleteProfilePictureRepo.deleteProfilePicture();

  @override
  Future<void> clearProfile() async {
    await localDataSource.clearProfile();
  }

  @override
  Future<CurrentUserProfileModel?> getLocalProfile() async {
    return await localDataSource.getProfile();
  }
}
