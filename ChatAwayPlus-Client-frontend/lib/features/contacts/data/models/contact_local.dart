import 'dart:convert';

class ContactLocal {
  final String
  contactHash; // '${contact.appdisplayNameim()}_$phoneNumber'.hashCode.toString(),
  final String name;
  final String mobileNo;
  final bool isRegistered;
  final DateTime lastUpdated;
  final UserDetails? userDetails; // Added UserDetails

  // Getter for easy app user ID access
  String? get appUserId {
    final id = userDetails?.userId;
    return id;
  }

  // Helper method to create a copy with user details
  ContactLocal withUserDetails(UserDetails details) {
    return copyWith(userDetails: details);
  }

  // Helper to check if this contact is an app user
  bool get isAppUser => userDetails?.userId != null;

  String get preferredDisplayName {
    final deviceName = name.trim();
    if (deviceName.isNotEmpty) return deviceName;
    final appName = userDetails?.appdisplayName.trim() ?? '';
    if (appName.isNotEmpty) return appName;
    final phone = mobileNo.trim();
    if (phone.isNotEmpty) return phone;
    return 'ChatAway user';
  }

  // Constructor
  ContactLocal({
    required this.contactHash,
    required this.name,
    required this.mobileNo,
    required this.isRegistered,
    required this.lastUpdated,
    this.userDetails,
  });

  /// Create ContactLocal from database map
  factory ContactLocal.fromMap(Map<String, dynamic> map) {
    final rawLastUpdated = map['last_updated'];
    DateTime parsedLastUpdated;

    if (rawLastUpdated is int) {
      parsedLastUpdated = DateTime.fromMillisecondsSinceEpoch(rawLastUpdated);
    } else if (rawLastUpdated is String) {
      final numericValue = int.tryParse(rawLastUpdated);
      if (numericValue != null) {
        parsedLastUpdated = DateTime.fromMillisecondsSinceEpoch(numericValue);
      } else {
        parsedLastUpdated = DateTime.parse(rawLastUpdated);
      }
    } else {
      parsedLastUpdated = DateTime.now();
    }

    final userDetailsRaw = map['user_details'];
    Map<String, dynamic>? userDetailsMap;

    if (userDetailsRaw is String) {
      final trimmed = userDetailsRaw.trim();
      if (trimmed.isNotEmpty && trimmed != 'null') {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map<String, dynamic>) {
          userDetailsMap = decoded;
        }
      }
    } else if (userDetailsRaw is Map) {
      userDetailsMap = Map<String, dynamic>.from(userDetailsRaw);
    }

    return ContactLocal(
      contactHash: map['contact_hash'] as String,
      name: map['name'] as String,
      mobileNo: map['mobile_no'] as String,
      isRegistered: map['is_registered'] == 1,
      lastUpdated: parsedLastUpdated,
      userDetails: userDetailsMap != null
          ? UserDetails.fromMap(userDetailsMap)
          : null,
    );
  }

  /// Convert ContactLocal to a map for database storage
  Map<String, dynamic> toMap() {
    final map = {
      'contact_hash': contactHash,
      'name': name,
      'mobile_no': mobileNo,
      'is_registered': isRegistered ? 1 : 0,
      'last_updated': lastUpdated.millisecondsSinceEpoch,
      'user_details': null,
      'app_user_id': userDetails?.userId,
    };

    // Include userDetails as JSON string if available
    if (userDetails != null) {
      // Convert userDetails to JSON string
      final userDetailsMap = userDetails!.toMap();
      map['user_details'] = jsonEncode(userDetailsMap);
    }

    return map;
  }

  /// Create a new ContactLocal with some properties changed
  ContactLocal copyWith({
    String? contactHash,
    String? name,
    String? mobileNo,
    bool? isRegistered,
    DateTime? lastUpdated,
    UserDetails? userDetails,
    bool clearUserDetails = false,
  }) {
    return ContactLocal(
      contactHash: contactHash ?? this.contactHash,
      name: name ?? this.name,
      mobileNo: mobileNo ?? this.mobileNo,
      isRegistered: isRegistered ?? this.isRegistered,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      userDetails: clearUserDetails ? null : (userDetails ?? this.userDetails),
    );
  }

  @override
  String toString() {
    return 'ContactLocal(contactHash: $contactHash, name: $name, mobileNo: $mobileNo, isRegistered: $isRegistered, lastUpdated: $lastUpdated, userDetails: $userDetails)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContactLocal &&
          runtimeType == other.runtimeType &&
          contactHash == other.contactHash;

  @override
  int get hashCode => contactHash.hashCode;
}

class UserDetails {
  final String userId;
  final String? chatPictureUrl;
  final String? chatPictureVersion;
  final String appdisplayName;
  final UserStatus? recentStatus;
  final UserLocation? recentLocation;
  final Map<String, dynamic>? recentEmojiUpdate;

  UserDetails({
    required this.userId,
    this.chatPictureUrl,
    this.chatPictureVersion,
    required this.appdisplayName,
    this.recentStatus,
    this.recentLocation,
    this.recentEmojiUpdate,
  });

  // Factory constructor to create from JSON or Map
  factory UserDetails.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic>? castMap(dynamic value) {
      if (value == null) return null;
      if (value is Map<String, dynamic>) return value;
      if (value is Map) return Map<String, dynamic>.from(value);
      return null;
    }

    final recentStatusMap =
        castMap(map['recentStatus']) ?? castMap(map['recent_status']);
    final recentLocationMap =
        castMap(map['recentLocation']) ?? castMap(map['recent_location']);
    final recentEmojiUpdateMap =
        castMap(map['recentEmojiUpdate']) ??
        castMap(map['recent_emoji_update']);

    final userDetails = UserDetails(
      userId: (map['user_id'] ?? map['userId'] ?? map['id'] ?? '').toString(),
      chatPictureUrl:
          (map['chat_picture'] ??
                  map['profile_pic'] ??
                  map['profile'
                      'PicUrl'] ??
                  map['profile_pic_url'])
              ?.toString(),
      chatPictureVersion:
          (map['chat_picture_version'] ??
                  map['chatPictureVersion'] ??
                  map['profilePicVersion'] ??
                  map['profile_pic_version'])
              ?.toString(),
      appdisplayName:
          (map['contact_name'] ?? map['name'] ?? map['displayName'] ?? '')
              .toString(),
      recentStatus: recentStatusMap != null
          ? UserStatus.fromMap(recentStatusMap)
          : null,
      recentLocation: recentLocationMap != null
          ? UserLocation.fromMap(recentLocationMap)
          : null,
      recentEmojiUpdate: recentEmojiUpdateMap,
    );

    return userDetails;
  }

  // Convert to Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'contact_name': appdisplayName,
      'chat_picture': chatPictureUrl,
      'chat_picture_version': chatPictureVersion,
      'recentStatus': recentStatus?.toBackendMap(),
      'recentEmojiUpdate': recentEmojiUpdate,
    };
  }

  // CopyWith method for immutability
  UserDetails copyWith({
    String? userId,
    String? chatPictureUrl,
    String? chatPictureVersion,
    String? appdisplayName,
    UserStatus? recentStatus,
    UserLocation? recentLocation,
    Map<String, dynamic>? recentEmojiUpdate,
  }) {
    return UserDetails(
      userId: userId ?? this.userId,
      chatPictureUrl: chatPictureUrl ?? this.chatPictureUrl,
      chatPictureVersion: chatPictureVersion ?? this.chatPictureVersion,
      appdisplayName: appdisplayName ?? this.appdisplayName,
      recentStatus: recentStatus ?? this.recentStatus,
      recentLocation: recentLocation ?? this.recentLocation,
      recentEmojiUpdate: recentEmojiUpdate ?? this.recentEmojiUpdate,
    );
  }

  @override
  String toString() {
    return 'UserDetails{userId: $userId, chatPictureUrl: $chatPictureUrl, chatPictureVersion: $chatPictureVersion, appdisplayName: $appdisplayName, recentStatus: $recentStatus, recentLocation: $recentLocation, recentEmojiUpdate: $recentEmojiUpdate}';
  }
}

class UserStatus {
  final String? statusId;
  final String content;
  final DateTime createdAt;

  UserStatus({this.statusId, required this.content, required this.createdAt});

  factory UserStatus.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is DateTime) return value;
      if (value is int) {
        try {
          return DateTime.fromMillisecondsSinceEpoch(value);
        } catch (_) {
          return DateTime.now();
        }
      }
      final s = value.toString().trim();
      if (s.isEmpty) return DateTime.now();
      final numeric = int.tryParse(s);
      if (numeric != null) {
        try {
          return DateTime.fromMillisecondsSinceEpoch(numeric);
        } catch (_) {
          return DateTime.now();
        }
      }
      try {
        return DateTime.parse(s);
      } catch (_) {
        return DateTime.now();
      }
    }

    return UserStatus(
      statusId: (map['statusId'] ?? map['status_id'])?.toString(),
      content:
          (map['content'] ??
                  map['share_your_voice'] ??
                  map['shareyourvoice'] ??
                  map['statusContent'] ??
                  map['status'] ??
                  '')
              .toString(),
      createdAt: parseDate(
        map['created_at'] ?? map['createdAt'] ?? map['timestamp'],
      ),
    );
  }

  Map<String, dynamic> toBackendMap() {
    return {
      if (statusId != null) 'statusId': statusId,
      'share_your_voice': content,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  UserStatus copyWith({
    String? statusId,
    String? content,
    DateTime? createdAt,
  }) {
    return UserStatus(
      statusId: statusId ?? this.statusId,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'UserStatus{statusId: $statusId, content: $content, createdAt: $createdAt}';
  }
}

class UserLocation {
  final String locationName;
  final String description;
  final List<String> photoUrls;
  final DateTime createdAt;

  UserLocation({
    required this.locationName,
    required this.description,
    required this.photoUrls,
    required this.createdAt,
  });

  factory UserLocation.fromMap(Map<String, dynamic> map) {
    return UserLocation(
      locationName: map['name'] ?? '',
      description: map['description'] ?? '',
      photoUrls:
          (map['photos'] as List<dynamic>?)
              ?.map((photo) => photo.toString())
              .toList() ??
          [],
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': locationName,
      'description': description,
      'photos': photoUrls,
      'created_at': createdAt.toIso8601String(),
    };
  }

  UserLocation copyWith({
    String? locationName,
    String? description,
    List<String>? photoUrls,
    DateTime? createdAt,
  }) {
    return UserLocation(
      locationName: locationName ?? this.locationName,
      description: description ?? this.description,
      photoUrls: photoUrls ?? this.photoUrls,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'UserLocation{locationName: $locationName, description: $description}';
  }
}
