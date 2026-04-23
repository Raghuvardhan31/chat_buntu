// lib/features/profile/data/models/requests/profile_request_models.dart

/// Base request model with validation
abstract class BaseProfileRequest {
  bool isValid();
  String? get validationError;
  Map<String, dynamic> toJson();
}

// =============================
// Update Name Request
// =============================

class UpdateNameRequestModel implements BaseProfileRequest {
  final String firstName;
  final String? lastName;

  UpdateNameRequestModel({
    required this.firstName,
    this.lastName,
  });

  @override
  bool isValid() {
    if (firstName.trim().isEmpty) return false;
    if (firstName.trim().length > 50) return false;
    return true;
  }

  @override
  String? get validationError {
    if (firstName.trim().isEmpty) return 'First name is required';
    if (firstName.trim().length > 50) {
      return 'First name must be 50 characters or less';
    }
    return null;
  }

  @override
  Map<String, dynamic> toJson() {
    final fn = firstName.trim();
    final ln = lastName?.trim();
    return {
      // camelCase
      'firstName': fn,
      if (ln != null && ln.isNotEmpty) 'lastName': ln,
      // snake_case (backend compatibility)
      'first_name': fn,
      if (ln != null && ln.isNotEmpty) 'last_name': ln,
    };
  }
}

// =============================
// Update Status Request
// =============================

class UpdateStatusRequestModel implements BaseProfileRequest {
  final String content;

  UpdateStatusRequestModel({required this.content});

  @override
  bool isValid() {
    if (content.trim().isEmpty) return false;
    if (content.trim().length > 85) return false;
    return true;
  }

  @override
  String? get validationError {
    if (content.trim().isEmpty) return 'Status content is required';
    if (content.trim().length > 85) {
      return 'Status must be 85 characters or less';
    }
    return null;
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'content': content.trim(),
    };
  }
}

// =============================
// Update Profile Picture Request
// =============================

class UpdateProfilePictureRequestModel implements BaseProfileRequest {
  final String imagePath;

  UpdateProfilePictureRequestModel({required this.imagePath});

  @override
  bool isValid() {
    if (imagePath.trim().isEmpty) return false;
    return true;
  }

  @override
  String? get validationError {
    if (imagePath.trim().isEmpty) return 'Image path is required';
    return null;
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'imagePath': imagePath,
    };
  }
}
