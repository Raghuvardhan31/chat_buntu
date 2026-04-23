// lib/features/profile/data/models/responses/profile_result.dart

/// Wrapper class for profile operation results
/// Provides consistent error handling and success states
class ProfileResult<T> {
  final T? data;
  final String? errorMessage;
  final int? statusCode;
  final bool isSuccess;

  ProfileResult._({
    this.data,
    this.errorMessage,
    this.statusCode,
    required this.isSuccess,
  });

  /// Create a successful result
  factory ProfileResult.success(T data) {
    return ProfileResult._(
      data: data,
      isSuccess: true,
    );
  }

  /// Create a failed result
  factory ProfileResult.failure({
    required String message,
    int? statusCode,
  }) {
    return ProfileResult._(
      errorMessage: message,
      statusCode: statusCode,
      isSuccess: false,
    );
  }

  /// Check if result is a failure
  bool get isFailure => !isSuccess;

  /// Get data or throw if failed
  T get dataOrThrow {
    if (isSuccess && data != null) {
      return data!;
    }
    throw Exception(errorMessage ?? 'Operation failed');
  }
}
