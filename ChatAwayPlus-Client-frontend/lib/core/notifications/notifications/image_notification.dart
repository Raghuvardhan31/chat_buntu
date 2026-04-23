class ImageNotificationHandler {
  static bool isTextMessageType(String? messageType) {
    final t = messageType?.toLowerCase().trim();
    return t == 'text';
  }

  static bool isImageMessageType(String? messageType) {
    if (messageType == null) return false;
    final t = messageType.toLowerCase();
    return t == 'image' || t == 'photo';
  }

  static String normalizeMessageText({
    required String messageText,
    required String? messageType,
    String? fileName,
    bool looksLikeJson = false,
    bool withEmoji = false,
  }) {
    final trimmed = messageText.trim();
    final t = messageType?.toLowerCase().trim() ?? '';
    if (t == 'location') {
      return withEmoji ? '📍 Location' : 'Location';
    }
    if ((trimmed.isEmpty || looksLikeJson) && !isTextMessageType(messageType)) {
      if (t == 'image' || t == 'photo') {
        return withEmoji ? '📷 Photo' : 'Photo';
      }
      if (t == 'video') {
        return withEmoji ? '🎥 Video' : 'Video';
      }
      if (t == 'document' || t == 'pdf') {
        if (withEmoji) return '📄 Document';
        final name = fileName?.trim();
        return name != null && name.isNotEmpty ? name : 'PDF';
      }
      if (t == 'contact') {
        return withEmoji ? '👤 Contact' : 'Contact';
      }
      if (t == 'audio' || t == 'voice') {
        return 'Voice message';
      }
      return 'New message';
    }

    return messageText;
  }
}
