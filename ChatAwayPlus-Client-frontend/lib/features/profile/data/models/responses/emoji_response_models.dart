// lib/features/profile/data/models/responses/emoji_response_models.dart

import '../emoji_model.dart';

// =============================
// Get All Emojis Response
// =============================

class GetAllEmojisResponseModel {
  final bool success;
  final String message;
  final List<EmojiModel>? data;
  final int? statusCode;

  GetAllEmojisResponseModel({
    required this.success,
    required this.message,
    this.data,
    this.statusCode,
  });

  factory GetAllEmojisResponseModel.fromJson(Map<String, dynamic> json) {
    final dataList = json['data'] as List?;
    List<EmojiModel>? emojiList;
    
    if (dataList != null) {
      emojiList = dataList
          .map((item) => EmojiModel.fromApi({'data': item}))
          .toList();
    }

    return GetAllEmojisResponseModel(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      data: emojiList,
      statusCode: json['statusCode'] as int?,
    );
  }

  factory GetAllEmojisResponseModel.error({
    required String message,
    int? statusCode,
  }) {
    return GetAllEmojisResponseModel(
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
// Get Emoji Response
// =============================

class GetEmojiResponseModel {
  final bool success;
  final String message;
  final EmojiModel? data;
  final int? statusCode;

  GetEmojiResponseModel({
    required this.success,
    required this.message,
    this.data,
    this.statusCode,
  });

  factory GetEmojiResponseModel.fromJson(Map<String, dynamic> json) {
    return GetEmojiResponseModel(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      data: json['data'] != null ? EmojiModel.fromApi(json) : null,
      statusCode: json['statusCode'] as int?,
    );
  }

  factory GetEmojiResponseModel.error({
    required String message,
    int? statusCode,
  }) {
    return GetEmojiResponseModel(
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
// Create/Update Emoji Response
// =============================

class EmojiUpdateResponseModel {
  final bool success;
  final String message;
  final EmojiModel? data;
  final int? statusCode;

  EmojiUpdateResponseModel({
    required this.success,
    required this.message,
    this.data,
    this.statusCode,
  });

  factory EmojiUpdateResponseModel.fromJson(Map<String, dynamic> json) {
    return EmojiUpdateResponseModel(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      data: json['data'] != null ? EmojiModel.fromApi(json) : null,
      statusCode: json['statusCode'] as int?,
    );
  }

  factory EmojiUpdateResponseModel.error({
    required String message,
    int? statusCode,
  }) {
    return EmojiUpdateResponseModel(
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
// Delete Emoji Response
// =============================

class DeleteEmojiResponseModel {
  final bool success;
  final String message;
  final int? statusCode;

  DeleteEmojiResponseModel({
    required this.success,
    required this.message,
    this.statusCode,
  });

  factory DeleteEmojiResponseModel.fromJson(Map<String, dynamic> json) {
    return DeleteEmojiResponseModel(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      statusCode: json['statusCode'] as int?,
    );
  }

  factory DeleteEmojiResponseModel.error({
    required String message,
    int? statusCode,
  }) {
    return DeleteEmojiResponseModel(
      success: false,
      message: message,
      statusCode: statusCode,
    );
  }

  bool get isSuccess => success;
  bool get isError => !success;
}
