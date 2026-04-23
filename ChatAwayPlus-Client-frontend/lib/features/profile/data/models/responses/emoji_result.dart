// lib/features/profile/data/models/responses/emoji_result.dart

/// Wrapper class for emoji operation results
/// Provides consistent error handling and success states
class EmojiResult<T> {
  final T? data;
  final String? errorMessage;
  final int? statusCode;
  final bool isSuccess;

  EmojiResult._({
    this.data,
    this.errorMessage,
    this.statusCode,
    required this.isSuccess,
  });

  /// Create a successful result
  factory EmojiResult.success(T data) {
    return EmojiResult._(
      data: data,
      isSuccess: true,
    );
  }

  /// Create a failed result
  factory EmojiResult.failure({
    required String message,
    int? statusCode,
  }) {
    return EmojiResult._(
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
