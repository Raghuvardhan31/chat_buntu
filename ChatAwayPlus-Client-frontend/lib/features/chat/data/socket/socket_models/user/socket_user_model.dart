/// Socket user model for WebSocket communication
class SocketUserModel {
  final String id;
  final String firstName;
  final String lastName;
  final String mobileNo;
  final String? chatPictureUrl;
  final String? chatPictureVersion;
  final String? status; // Share your voice status
  final String? emoji;
  final String? emojiCaption;
  final bool isOnline;
  final DateTime? lastSeen;

  SocketUserModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.mobileNo,
    this.chatPictureUrl,
    this.chatPictureVersion,
    this.status,
    this.emoji,
    this.emojiCaption,
    this.isOnline = false,
    this.lastSeen,
  });

  factory SocketUserModel.fromJson(Map<String, dynamic> json) {
    return SocketUserModel(
      id: (json['id'] ?? json['userId'] ?? json['user_id'])?.toString() ?? '',
      firstName: (json['firstName'] ?? json['first_name'])?.toString() ?? '',
      lastName: (json['lastName'] ?? json['last_name'])?.toString() ?? '',
      mobileNo:
          (json['mobileNo'] ?? json['mobile_no'] ?? json['phone'])
              ?.toString() ??
          '',
      chatPictureUrl:
          (json['chatPictureUrl'] ??
                  json['chat_picture_url'] ??
                  json['profile_pic_url'] ??
                  json['profilePicUrl'])
              ?.toString(),
      chatPictureVersion:
          (json['chatPictureVersion'] ??
                  json['chat_picture_version'] ??
                  json['profile_pic_version'])
              ?.toString(),
      status:
          (json['status'] ?? json['share_your_voice'] ?? json['statusContent'])
              ?.toString(),
      emoji: (json['emoji'] ?? json['emoji_update'] ?? json['emojisUpdate'])
          ?.toString(),
      emojiCaption:
          (json['emojiCaption'] ??
                  json['emoji_caption'] ??
                  json['emojisCaption'])
              ?.toString(),
      isOnline: _tryParseBool(json['isOnline'] ?? json['is_online']),
      lastSeen: _tryParseDateTime(json['lastSeen'] ?? json['last_seen']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'mobileNo': mobileNo,
      'chatPictureUrl': chatPictureUrl,
      'chatPictureVersion': chatPictureVersion,
      'status': status,
      'emoji': emoji,
      'emojiCaption': emojiCaption,
      'isOnline': isOnline,
      'lastSeen': lastSeen?.toIso8601String(),
    };
  }

  String get fullName => '$firstName $lastName'.trim();

  static bool _tryParseBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) return value == 1;
    final s = value.toString().toLowerCase();
    return s == 'true' || s == '1';
  }

  static DateTime? _tryParseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return DateTime.tryParse(value.toString());
  }
}
