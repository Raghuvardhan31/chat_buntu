// lib/features/profile/data/repositories/profile/profile_repository.dart

import '../../models/current_user_profile_model.dart';
import '../../models/responses/profile_response_models.dart';
import '../../models/responses/profile_result.dart';

/// Main profile repository interface
/// Defines all profile-related operations
abstract class ProfileRepository {
  /// Get current user profile
  Future<ProfileResult<GetProfileResponseModel>> getCurrentUserProfile();

  /// Update profile name
  Future<ProfileResult<UpdateProfileResponseModel>> updateName(
    String firstName,
    String? lastName,
  );

  /// Update profile status
  Future<ProfileResult<UpdateProfileResponseModel>> updateStatus(
    String content,
  );

  /// Update profile picture
  Future<ProfileResult<UpdateProfileResponseModel>> updateProfilePicture(
    String imagePath,
  );

  /// Delete profile picture
  Future<ProfileResult<DeleteProfilePictureResponseModel>> deleteProfilePicture();

  /// Clear all profile data (for logout)
  Future<void> clearProfile();

  /// Get profile from local database (for offline access)
  Future<CurrentUserProfileModel?> getLocalProfile();
}
