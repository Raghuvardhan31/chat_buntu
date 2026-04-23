// lib/features/profile/data/models/responses/profile_response_models.dart

import '../current_user_profile_model.dart';

// =============================
// Get Profile Response
// =============================

class GetProfileResponseModel {
  final bool success;
  final String message;
  final CurrentUserProfileModel? data;
  final int? statusCode;

  GetProfileResponseModel({
    required this.success,
    required this.message,
    this.data,
    this.statusCode,
  });

  factory GetProfileResponseModel.fromJson(Map<String, dynamic> json) {
    return GetProfileResponseModel(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      data: json['data'] != null
          ? CurrentUserProfileModel.fromApi(json)
          : null,
      statusCode: json['statusCode'] as int?,
    );
  }

  factory GetProfileResponseModel.error({
    required String message,
    int? statusCode,
  }) {
    return GetProfileResponseModel(
      success: false,
      message: message,
      data: null,
      statusCode: statusCode,
    );
  }

  bool get isSuccess => success && data != null;
  bool get isError => !success || data == null;
}

// =============================
// Update Profile Response
// =============================

class UpdateProfileResponseModel {
  final bool success;
  final String message;
  final CurrentUserProfileModel? data;
  final int? statusCode;

  UpdateProfileResponseModel({
    required this.success,
    required this.message,
    this.data,
    this.statusCode,
  });

  factory UpdateProfileResponseModel.fromJson(Map<String, dynamic> json) {
    return UpdateProfileResponseModel(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      data: json['data'] != null
          ? CurrentUserProfileModel.fromApi(json)
          : null,
      statusCode: json['statusCode'] as int?,
    );
  }

  factory UpdateProfileResponseModel.error({
    required String message,
    int? statusCode,
  }) {
    return UpdateProfileResponseModel(
      success: false,
      message: message,
      data: null,
      statusCode: statusCode,
    );
  }

  bool get isSuccess => success && data != null;
  bool get isError => !success || data == null;
}

// =============================
// Delete Profile Picture Response
// =============================

class DeleteProfilePictureResponseModel {
  final bool success;
  final String message;
  final Map<String, dynamic>? data;
  final int? statusCode;

  DeleteProfilePictureResponseModel({
    required this.success,
    required this.message,
    this.data,
    this.statusCode,
  });

  factory DeleteProfilePictureResponseModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return DeleteProfilePictureResponseModel(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      data: json['data'] as Map<String, dynamic>?,
      statusCode: json['statusCode'] as int?,
    );
  }

  factory DeleteProfilePictureResponseModel.error({
    required String message,
    int? statusCode,
  }) {
    return DeleteProfilePictureResponseModel(
      success: false,
      message: message,
      data: null,
      statusCode: statusCode,
    );
  }

  bool get isSuccess => success;
  bool get isError => !success;
}
