// lib/features/voice_hub/data/models/responses/emoji_updates_result.dart

/// Result wrapper for emoji updates operations
class EmojiUpdatesResult<T> {
  final T? data;
  final String? message;
  final int? statusCode;
  final bool isSuccess;

  const EmojiUpdatesResult._({
    this.data,
    this.message,
    this.statusCode,
    required this.isSuccess,
  });

  factory EmojiUpdatesResult.success(T data) {
    return EmojiUpdatesResult._(
      data: data,
      isSuccess: true,
    );
  }

  factory EmojiUpdatesResult.failure({
    String? message,
    int? statusCode,
  }) {
    return EmojiUpdatesResult._(
      message: message,
      statusCode: statusCode,
      isSuccess: false,
    );
  }

  bool get isFailure => !isSuccess;
}
