/// Generic result wrapper for authentication operations
class AuthResult<T> {
  final bool isSuccess;
  final T? data;
  final String? errorMessage;
  final String? errorCode;
  final int? statusCode;
  final Exception? exception;

  const AuthResult._({
    required this.isSuccess,
    this.data,
    this.errorMessage,
    this.errorCode,
    this.statusCode,
    this.exception,
  });

  factory AuthResult.success(T data) {
    return AuthResult._(isSuccess: true, data: data);
  }

  factory AuthResult.failure({
    required String errorMessage,
    String? errorCode,
    int? statusCode,
    Exception? exception,
  }) {
    return AuthResult._(
      isSuccess: false,
      errorMessage: errorMessage,
      errorCode: errorCode,
      statusCode: statusCode,
      exception: exception,
    );
  }

  @override
  String toString() {
    return isSuccess
        ? 'AuthResult.success(data: $data)'
        : 'AuthResult.failure(error: $errorMessage, code: $errorCode)';
  }
}
