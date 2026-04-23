import 'dart:convert';

/// Profile update from contact (WhatsApp-style real-time updates)
class ProfileUpdate {
  final String userId;
  final String? name;
  final String? chatPictureUrl;
  final String? chatPictureVersion;
  final String? status; // "Share your voice" text
  final String? emoji;
  final String? emojiCaption;

  ProfileUpdate({
    required this.userId,
    this.name,
    this.chatPictureUrl,
    this.chatPictureVersion,
    this.status,
    this.emoji,
    this.emojiCaption,
  });

  factory ProfileUpdate.fromJson(Map<String, dynamic> json) {
    String? applyVersionToUrl(String? url, dynamic version) {
      if (url == null) return null;
      if (url.trim().isEmpty) return '';
      final v = version?.toString();
      if (v == null || v.isEmpty) return url;
      final hasV = RegExp(r'([?&])v=').hasMatch(url);
      if (hasV) return url;
      final sep = url.contains('?') ? '&' : '?';
      return '$url${sep}v=$v';
    }

    Map<String, dynamic>? castMap(dynamic value) {
      if (value == null) return null;
      if (value is Map<String, dynamic>) return value;
      if (value is Map) return Map<String, dynamic>.from(value);
      return null;
    }

    String? buildNameFromUserMap(Map<String, dynamic> userMap) {
      final first = (userMap['firstName'] ?? userMap['first_name'])
          ?.toString()
          .trim();
      final last = (userMap['lastName'] ?? userMap['last_name'])
          ?.toString()
          .trim();
      final fullName = '${first ?? ''} ${last ?? ''}'.trim();
      if (fullName.isNotEmpty) return fullName;
      return (userMap['name'] ?? userMap['fullName'] ?? userMap['displayName'])
          ?.toString();
    }

    String? extractStatus(dynamic raw) {
      if (raw == null) return null;
      final m = castMap(raw);
      if (m != null) {
        return (m['share_your_voice'] ??
                m['shareyourvoice'] ??
                m['status'] ??
                m['statusContent'] ??
                m['status_content'] ??
                m['content'] ??
                m['text'])
            ?.toString();
      }
      return raw.toString();
    }

    void extractEmojiFromMap(
      Map<String, dynamic> m, {
      required void Function(String?) setEmoji,
      required void Function(String?) setEmojiCaption,
    }) {
      setEmoji(
        (m['emojis_update'] ??
                m['emoji_updates'] ??
                m['emojis_updates'] ??
                m['emoji_update'] ??
                m['emoji'] ??
                m['emojisUpdate'])
            ?.toString(),
      );
      setEmojiCaption(
        (m['emojis_caption'] ??
                m['emoji_captions'] ??
                m['emojis_captions'] ??
                m['emoji_caption'] ??
                m['caption'] ??
                m['emojisCaption'])
            ?.toString(),
      );
    }

    final updatedFieldsRaw = json['updatedFields'];
    final updatedFields = updatedFieldsRaw is Map
        ? Map<String, dynamic>.from(updatedFieldsRaw)
        : <String, dynamic>{};

    String? name;
    String? rawChatPictureUrl;
    String? profilePicVersion;
    String? status;
    String? emoji;
    String? emojiCaption;

    void setEmojiIfEmpty(String? v) {
      if (emoji != null && emoji!.isNotEmpty) return;
      final s = v?.trim();
      if (s == null || s.isEmpty) return;
      emoji = s;
    }

    void setEmojiCaptionIfEmpty(String? v) {
      if (emojiCaption != null && emojiCaption!.isNotEmpty) return;
      final s = v?.trim();
      if (s == null || s.isEmpty) return;
      emojiCaption = s;
    }

    // Method 1: legacy payload format (updatedFields)
    name = updatedFields['name']?.toString();

    rawChatPictureUrl = updatedFields.containsKey('chat_picture')
        ? (updatedFields['chat_picture'] ?? '').toString()
        : (updatedFields['profile_pic'] ??
                  updatedFields['profile'
                      'PicUrl'] ??
                  updatedFields['profilePic'] ??
                  updatedFields['profile_pic_url'])
              ?.toString();

    profilePicVersion =
        (updatedFields['chat_picture_version'] ??
                updatedFields['profilePicVersion'] ??
                updatedFields['profile_pic_version'] ??
                updatedFields['profilePicVer'])
            ?.toString();

    status = extractStatus(
      updatedFields.containsKey('share_your_voice')
          ? updatedFields['share_your_voice']
          : (updatedFields.containsKey('shareyourvoice')
                ? updatedFields['shareyourvoice']
                : (updatedFields['statusUrl'] ??
                      updatedFields['status'] ??
                      updatedFields['statusContent'] ??
                      updatedFields['status_content'])),
    );

    String? readUpdatedField(List<String> keys) {
      for (final k in keys) {
        if (updatedFields.containsKey(k)) {
          return (updatedFields[k] ?? '').toString();
        }
      }
      return null;
    }

    emoji = readUpdatedField([
      'emojis_update',
      'emoji_updates',
      'emojis_updates',
      'emoji_update',
      'emoji',
      'emojisUpdate',
    ]);

    emojiCaption = readUpdatedField([
      'emojis_caption',
      'emoji_captions',
      'emojis_captions',
      'emoji_caption',
      'emojiCaption',
      'caption',
      'emojisCaption',
    ]);

    final rawEmojiUpdateFromUpdatedFields =
        updatedFields['emoji_update'] ??
        updatedFields['emojiUpdate'] ??
        updatedFields['recentEmojiUpdate'] ??
        updatedFields['recent_emoji_update'];
    try {
      if (rawEmojiUpdateFromUpdatedFields is String &&
          rawEmojiUpdateFromUpdatedFields.trim().isNotEmpty) {
        final decoded = jsonDecode(rawEmojiUpdateFromUpdatedFields);
        if (decoded is Map) {
          extractEmojiFromMap(
            Map<String, dynamic>.from(decoded),
            setEmoji: setEmojiIfEmpty,
            setEmojiCaption: setEmojiCaptionIfEmpty,
          );
        }
      } else {
        final emojiMap = castMap(rawEmojiUpdateFromUpdatedFields);
        if (emojiMap != null) {
          extractEmojiFromMap(
            emojiMap,
            setEmoji: setEmojiIfEmpty,
            setEmojiCaption: setEmojiCaptionIfEmpty,
          );
        }
      }
    } catch (_) {}

    // Method 2: new payload format (updatedData: { user, share_your_voice, emoji_update })
    final updatedDataRaw = json['updatedData'] ?? json['updated_data'];
    Map<String, dynamic>? parsedData;
    if (updatedDataRaw != null) {
      try {
        if (updatedDataRaw is String) {
          final decoded = jsonDecode(updatedDataRaw);
          if (decoded is Map) {
            parsedData = Map<String, dynamic>.from(decoded);
          }
        } else if (updatedDataRaw is Map) {
          parsedData = Map<String, dynamic>.from(updatedDataRaw);
        }
      } catch (_) {}
    }

    // Also allow websocket payloads that already send these objects directly.
    parsedData ??= <String, dynamic>{};
    if (json['user'] != null) parsedData['user'] ??= json['user'];
    if (json['share_your_voice'] != null) {
      parsedData['share_your_voice'] ??= json['share_your_voice'];
    }
    if (json['emoji_update'] != null) {
      parsedData['emoji_update'] ??= json['emoji_update'];
    }
    if (json['emojiUpdate'] != null) {
      parsedData['emoji_update'] ??= json['emojiUpdate'];
    }

    final userMap = castMap(parsedData['user']);
    if (userMap != null) {
      name ??= buildNameFromUserMap(userMap);
      rawChatPictureUrl ??= userMap.containsKey('chat_picture')
          ? (userMap['chat_picture'] ?? '').toString()
          : (userMap['profile_pic'] ??
                    userMap['profile'
                        'PicUrl'] ??
                    userMap['profilePic'] ??
                    userMap['profile_pic_url'])
                ?.toString();
      profilePicVersion ??=
          userMap['chat_picture_version']?.toString() ??
          userMap['chatPictureVersion']?.toString() ??
          userMap['profilePicVersion']?.toString() ??
          userMap['profile_pic_version']?.toString();
    }

    final voiceMap = castMap(parsedData['share_your_voice']);
    if (voiceMap != null) {
      status ??= extractStatus(voiceMap['share_your_voice'] ?? voiceMap);
    }

    final emojiMap =
        castMap(parsedData['emoji_update']) ??
        castMap(parsedData['emojiUpdate']);
    if (emojiMap != null) {
      extractEmojiFromMap(
        emojiMap,
        setEmoji: setEmojiIfEmpty,
        setEmojiCaption: setEmojiCaptionIfEmpty,
      );
    }

    // Method 3: direct fields on root
    name ??= json['name']?.toString();
    rawChatPictureUrl ??= json.containsKey('chat_picture')
        ? (json['chat_picture'] ?? '').toString()
        : (json['profile_pic'] ??
                  json['profilePicUrl'] ??
                  json['profile_pic_url'])
              ?.toString();
    profilePicVersion ??=
        json['chat_picture_version']?.toString() ??
        json['chatPictureVersion']?.toString() ??
        json['profilePicVersion']?.toString() ??
        json['profile_pic_version']?.toString();
    status ??= extractStatus(
      json.containsKey('share_your_voice')
          ? json['share_your_voice']
          : (json.containsKey('shareyourvoice')
                ? json['shareyourvoice']
                : (json['statusUrl'] ??
                      json['status'] ??
                      json['statusContent'])),
    );
    emoji ??=
        (json['emojis_update'] ??
                json['emoji_updates'] ??
                json['emojis_updates'] ??
                json['emoji_update'] ??
                json['emoji'] ??
                json['emojisUpdate'])
            ?.toString();
    emojiCaption ??=
        (json['emojis_caption'] ??
                json['emoji_captions'] ??
                json['emojis_captions'] ??
                json['emoji_caption'] ??
                json['caption'] ??
                json['emojisCaption'])
            ?.toString();

    final chatPictureUrl = applyVersionToUrl(
      rawChatPictureUrl,
      profilePicVersion,
    );

    return ProfileUpdate(
      userId:
          (json['userId'] ?? json['user_id'] ?? json['id'] ?? json['uid'])
              ?.toString() ??
          '',
      name: name,
      chatPictureUrl: chatPictureUrl,
      chatPictureVersion: profilePicVersion,
      status: status,
      emoji: emoji,
      emojiCaption: emojiCaption,
    );
  }

  /// Check if any field was updated
  /// Note: chatPictureUrl can be empty string '' to indicate deletion
  bool get hasUpdates =>
      name != null ||
      chatPictureUrl != null || // includes '' for deletion
      chatPictureVersion != null ||
      status != null ||
      emoji != null ||
      emojiCaption != null;

  /// Check if chat picture was explicitly deleted (empty string)
  bool get isChatPictureDeleted =>
      chatPictureUrl != null && chatPictureUrl!.isEmpty;

  @override
  String toString() =>
      'ProfileUpdate(userId: $userId, name: $name, chatPictureUrl: $chatPictureUrl, chatPictureVersion: $chatPictureVersion, status: $status, emoji: $emoji, emojiCaption: $emojiCaption)';
}
