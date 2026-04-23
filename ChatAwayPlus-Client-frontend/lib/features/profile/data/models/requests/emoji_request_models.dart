// lib/features/profile/data/models/requests/emoji_request_models.dart

/// Base emoji request model with validation
abstract class BaseEmojiRequest {
  bool isValid();
  String? get validationError;
  Map<String, dynamic> toJson();
}

// =============================
// Create/Update Emoji Request
// =============================

class EmojiUpdateRequestModel implements BaseEmojiRequest {
  final String emoji;
  final String caption;

  EmojiUpdateRequestModel({required this.emoji, required this.caption});

  @override
  bool isValid() {
    final trimmedEmoji = emoji.trim();
    final trimmedCaption = caption.trim();

    // Allow either emoji-only or caption-only, but not both empty
    if (trimmedEmoji.isEmpty && trimmedCaption.isEmpty) return false;
    if (trimmedEmoji.length > 50) return false; // Max emoji limit
    if (trimmedCaption.length > 200) return false; // Max caption limit
    return true;
  }

  @override
  String? get validationError {
    final trimmedEmoji = emoji.trim();
    final trimmedCaption = caption.trim();

    if (trimmedEmoji.isEmpty && trimmedCaption.isEmpty) {
      return 'Emoji or caption is required';
    }
    if (trimmedEmoji.length > 50) {
      return 'Emoji must be 50 characters or less';
    }
    if (trimmedCaption.length > 200) {
      return 'Caption must be 200 characters or less';
    }
    return null;
  }

  @override
  Map<String, dynamic> toJson() {
    final e = emoji.trim();
    final c = caption.trim();
    return {'emoji': e, 'caption': c, 'emojis_update': e, 'emojis_caption': c};
  }
}

// =============================
// Delete Emoji Request
// =============================

class DeleteEmojiRequestModel implements BaseEmojiRequest {
  final String emoji;
  final String caption;

  DeleteEmojiRequestModel({required this.emoji, required this.caption});

  @override
  bool isValid() {
    // For delete, allow empty values (resource identified by ID),
    // but still enforce max lengths if provided.
    final trimmedEmoji = emoji.trim();
    final trimmedCaption = caption.trim();
    if (trimmedEmoji.length > 50) return false;
    if (trimmedCaption.length > 200) return false;
    return true;
  }

  @override
  String? get validationError {
    final trimmedEmoji = emoji.trim();
    final trimmedCaption = caption.trim();

    if (trimmedEmoji.length > 50) {
      return 'Emoji must be 50 characters or less';
    }
    if (trimmedCaption.length > 200) {
      return 'Caption must be 200 characters or less';
    }
    return null;
  }

  @override
  Map<String, dynamic> toJson() {
    final e = emoji.trim();
    final c = caption.trim();
    return {'emoji': e, 'caption': c, 'emojis_update': e, 'emojis_caption': c};
  }
}
