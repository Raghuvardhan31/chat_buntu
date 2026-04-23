// lib/features/voice_hub/data/models/responses/emoji_updates_response.dart

import '../emoji_update_model.dart';

/// Response model for GET /api/emoji-updates/all
class GetAllEmojiUpdatesResponse {
  final bool success;
  final String message;
  final List<EmojiUpdateModel>? data;
  final int? statusCode;

  const GetAllEmojiUpdatesResponse({
    required this.success,
    required this.message,
    this.data,
    this.statusCode,
  });

  factory GetAllEmojiUpdatesResponse.fromJson(Map<String, dynamic> json) {
    final dataList = json['data'] as List?;
    List<EmojiUpdateModel>? emojiList;
    
    if (dataList != null) {
      emojiList = dataList
          .map((item) => EmojiUpdateModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    return GetAllEmojiUpdatesResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      data: emojiList,
      statusCode: json['statusCode'] as int?,
    );
  }

  factory GetAllEmojiUpdatesResponse.error({
    required String message,
    int? statusCode,
  }) {
    return GetAllEmojiUpdatesResponse(
      success: false,
      message: message,
      data: null,
      statusCode: statusCode,
    );
  }

  bool get isSuccess => success && data != null;
  bool get isError => !success || data == null;
}
