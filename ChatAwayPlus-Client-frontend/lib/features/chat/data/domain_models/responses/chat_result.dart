// lib/features/chat/data/domain_models/responses/chat_result.dart

/// Generic result wrapper for chat operations
/// Similar to AuthResult, provides a consistent way to handle success/failure
class ChatResult<T> {
  final bool isSuccess;
  final T? data;
  final String? errorMessage;
  final String? errorCode;
  final int? statusCode;
  final Exception? exception;

  const ChatResult._({
    required this.isSuccess,
    this.data,
    this.errorMessage,
    this.errorCode,
    this.statusCode,
    this.exception,
  });

  /// Create a successful result with data
  factory ChatResult.success(T data) {
    return ChatResult._(isSuccess: true, data: data);
  }

  /// Create a failure result with error information
  factory ChatResult.failure({
    required String errorMessage,
    String? errorCode,
    int? statusCode,
    Exception? exception,
  }) {
    return ChatResult._(
      isSuccess: false,
      errorMessage: errorMessage,
      errorCode: errorCode,
      statusCode: statusCode,
      exception: exception,
    );
  }

  /// Check if the result represents a failure
  bool get isFailure => !isSuccess;

  @override
  String toString() {
    return isSuccess
        ? 'ChatResult.success(data: $data)'
        : 'ChatResult.failure(error: $errorMessage, code: $errorCode)';
  }
}
