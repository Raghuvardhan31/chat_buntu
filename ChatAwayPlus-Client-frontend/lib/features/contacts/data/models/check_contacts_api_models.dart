class CheckContactsResponse {
  final bool success;
  final List<CheckContactItem> data;

  const CheckContactsResponse({required this.success, required this.data});

  factory CheckContactsResponse.fromJson(Map<String, dynamic> json) {
    final success = json['success'] == true;
    final rawData = json['data'];
    final List<CheckContactItem> parsed;
    if (rawData is List) {
      parsed = rawData
          .whereType<Map>()
          .map((e) => CheckContactItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } else {
      parsed = const [];
    }

    // Debug logging
    final registeredCount = parsed.where((c) => c.isRegistered).length;
    final withUserDetails = parsed.where((c) => c.userDetails != null).length;
    print('✅ Parsed ${parsed.length} contacts from checkContacts API');
    print(
      '📊 Registered: $registeredCount | With user_details: $withUserDetails',
    );

    // Log first few registered users for verification
    final registered = parsed.where((c) => c.isRegistered).take(3).toList();
    for (final c in registered) {
      print(
        '   ✓ ${c.contactName} (${c.contactMobileNumber}) - userId: ${c.userDetails?.userId}',
      );
    }

    return CheckContactsResponse(success: success, data: parsed);
  }
}

bool _isTruthy(dynamic value) {
  if (value == null) return false;
  if (value is bool) return value;
  if (value is num) return value != 0;
  final s = value.toString().trim().toLowerCase();
  return s == 'true' || s == '1' || s == 'yes' || s == 'y';
}

class CheckContactItem {
  final String contactName;
  final String contactMobileNumber;
  final bool isRegistered;
  final CheckContactUserDetails? userDetails;

  const CheckContactItem({
    required this.contactName,
    required this.contactMobileNumber,
    required this.isRegistered,
    this.userDetails,
  });

  factory CheckContactItem.fromJson(Map<String, dynamic> json) {
    final rawUserDetails = json['user_details'];

    // Parse user details first
    final userDetails = rawUserDetails is Map
        ? CheckContactUserDetails.fromJson(
            Map<String, dynamic>.from(rawUserDetails),
          )
        : null;

    // User is registered if:
    // 1. is_registered flag is true OR
    // 2. user_details exists with a valid userId
    final hasUserDetails =
        userDetails != null && userDetails.userId.trim().isNotEmpty;
    final isRegistered = _isTruthy(json['is_registered']) || hasUserDetails;

    return CheckContactItem(
      contactName: (json['contact_name'] ?? '').toString(),
      contactMobileNumber: (json['contact_mobile_number'] ?? '').toString(),
      isRegistered: isRegistered,
      userDetails: userDetails,
    );
  }
}

class CheckContactUserDetails {
  final String userId;
  final String contactName;
  final String? chatPicture;
  final String? chatPictureVersion;
  final CheckContactRecentStatus? recentStatus;
  final CheckContactRecentEmojiUpdate? recentEmojiUpdate;

  const CheckContactUserDetails({
    required this.userId,
    required this.contactName,
    this.chatPicture,
    this.chatPictureVersion,
    this.recentStatus,
    this.recentEmojiUpdate,
  });

  factory CheckContactUserDetails.fromJson(Map<String, dynamic> json) {
    final rawRecentStatus = json['recentStatus'];
    final rawRecentEmojiUpdate =
        json['recentEmojiUpdate'] ?? json['recent_emoji_update'];

    return CheckContactUserDetails(
      userId: (json['user_id'] ?? '').toString(),
      contactName: (json['contact_name'] ?? '').toString(),
      chatPicture: json['chat_picture']?.toString(),
      chatPictureVersion: json['chat_picture_version']?.toString(),
      recentStatus: rawRecentStatus is Map
          ? CheckContactRecentStatus.fromJson(
              Map<String, dynamic>.from(rawRecentStatus),
            )
          : null,
      recentEmojiUpdate: rawRecentEmojiUpdate is Map
          ? CheckContactRecentEmojiUpdate.fromJson(
              Map<String, dynamic>.from(rawRecentEmojiUpdate),
            )
          : null,
    );
  }
}

class CheckContactRecentStatus {
  final String? statusId;
  final String shareYourVoice;
  final DateTime? createdAt;

  const CheckContactRecentStatus({
    this.statusId,
    required this.shareYourVoice,
    this.createdAt,
  });

  factory CheckContactRecentStatus.fromJson(Map<String, dynamic> json) {
    final rawDate = json['createdAt'];
    DateTime? parsed;
    if (rawDate is String && rawDate.trim().isNotEmpty) {
      try {
        parsed = DateTime.parse(rawDate);
      } catch (_) {}
    }

    return CheckContactRecentStatus(
      statusId: (json['statusId'] ?? json['status_id'])?.toString(),
      shareYourVoice: (json['share_your_voice'] ?? '').toString(),
      createdAt: parsed,
    );
  }
}

class CheckContactRecentEmojiUpdate {
  final String emojisUpdate;
  final String? emojisCaption;
  final DateTime? createdAt;

  const CheckContactRecentEmojiUpdate({
    required this.emojisUpdate,
    this.emojisCaption,
    this.createdAt,
  });

  factory CheckContactRecentEmojiUpdate.fromJson(Map<String, dynamic> json) {
    final rawDate = json['createdAt'];
    DateTime? parsed;
    if (rawDate is String && rawDate.trim().isNotEmpty) {
      try {
        parsed = DateTime.parse(rawDate);
      } catch (_) {}
    }

    String readField(List<String> keys) {
      for (final k in keys) {
        final v = json[k];
        if (v != null) return v.toString();
      }
      return '';
    }

    String? readNullableField(List<String> keys) {
      for (final k in keys) {
        final v = json[k];
        if (v != null) return v.toString();
      }
      return null;
    }

    return CheckContactRecentEmojiUpdate(
      emojisUpdate: readField([
        'emojis_update',
        'emoji_updates',
        'emojis_updates',
        'emoji_update',
        'emoji',
        'emojisUpdate',
      ]),
      emojisCaption: readNullableField([
        'emojis_caption',
        'emoji_captions',
        'emojis_captions',
        'emoji_caption',
        'caption',
        'emojisCaption',
      ]),
      createdAt: parsed,
    );
  }
}
