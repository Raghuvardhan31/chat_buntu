import 'package:flutter/foundation.dart';

String _normalizeStreamUrl(String url) {
  final raw = url.trim();
  if (raw.isEmpty) return raw;

  const streamPrefix = '/api/images/stream/';

  String stripBucket(String remainder) {
    if (remainder.startsWith('dev.chatawayplus/')) {
      return remainder.substring('dev.chatawayplus/'.length);
    }
    if (remainder.startsWith('chatawayplus/')) {
      return remainder.substring('chatawayplus/'.length);
    }

    final firstSlash = remainder.indexOf('/');
    if (firstSlash > 0) {
      final firstSeg = remainder.substring(0, firstSlash);
      final rest = remainder.substring(firstSlash + 1);
      if (firstSeg.contains('.') && rest.startsWith('stories/')) {
        return rest;
      }
    }

    return remainder;
  }

  String stripStandaloneBucket(String input) {
    final hadLeadingSlash = input.startsWith('/');
    final candidate = hadLeadingSlash ? input.substring(1) : input;
    final stripped = stripBucket(candidate);
    if (stripped == candidate) return input;
    return hadLeadingSlash ? '/$stripped' : stripped;
  }

  // If the backend returns a plain key, some clients accidentally prepend the bucket.
  // Example: dev.chatawayplus/stories/... -> stories/...
  // Example: /dev.chatawayplus/stories/... -> /stories/...
  final standalone = stripStandaloneBucket(raw);
  if (standalone != raw &&
      !standalone.startsWith('http://') &&
      !standalone.startsWith('https://')) {
    return standalone;
  }

  if (raw.startsWith('http://') || raw.startsWith('https://')) {
    final idx = raw.indexOf(streamPrefix);
    if (idx == -1) return raw;
    final before = raw.substring(0, idx + streamPrefix.length);
    final after = raw.substring(idx + streamPrefix.length);
    return before + stripBucket(after);
  }

  if (raw.startsWith(streamPrefix)) {
    return streamPrefix + stripBucket(raw.substring(streamPrefix.length));
  }

  if (raw.startsWith('api/images/stream/')) {
    const p = 'api/images/stream/';
    return p + stripBucket(raw.substring(p.length));
  }

  return raw;
}

/// Story model for socket responses - represents a single story
@immutable
class StoryModel {
  const StoryModel({
    required this.id,
    required this.userId,
    required this.mediaUrl,
    required this.mediaType,
    this.caption,
    required this.duration,
    required this.viewsCount,
    required this.expiresAt,
    this.backgroundColor,
    required this.createdAt,
    required this.updatedAt,
    this.isViewed = false,
    this.user,
    this.thumbnailUrl,
    this.videoDuration,
  });

  final String id;
  final String userId;
  final String mediaUrl;
  final String mediaType; // 'image' or 'video'
  final String? caption;
  final int duration;
  final int viewsCount;
  final DateTime expiresAt;
  final String? backgroundColor;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isViewed;
  final StoryUserInfo? user;
  final String? thumbnailUrl;
  final double? videoDuration;

  factory StoryModel.fromJson(Map<String, dynamic> json) {
    final mediaType = json['mediaType'] as String? ?? 'image';
    final thumbnailUrlRaw = json['thumbnailUrl'] as String?;
    final mediaUrlRaw = json['mediaUrl'] as String? ?? '';
    final thumbnailUrl = thumbnailUrlRaw == null
        ? null
        : _normalizeStreamUrl(thumbnailUrlRaw);
    final mediaUrl = _normalizeStreamUrl(mediaUrlRaw);

    // Debug: trace thumbnailUrl for video stories
    if (mediaType == 'video') {
      debugPrint(
        '📹 StoryModel.fromJson: video story id=${json['id']}, '
        'thumbnailUrl=$thumbnailUrl, '
        'mediaUrl=${json['mediaUrl']}',
      );
    }

    return StoryModel(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      mediaUrl: mediaUrl,
      mediaType: mediaType,
      caption: json['caption'] as String?,
      duration: json['duration'] as int? ?? 5,
      viewsCount: json['viewsCount'] as int? ?? 0,
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String)
          : DateTime.now().add(const Duration(hours: 24)),
      backgroundColor: json['backgroundColor'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String).toLocal()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
      isViewed: json['isViewed'] as bool? ?? false,
      user: json['user'] != null
          ? StoryUserInfo.fromJson(json['user'] as Map<String, dynamic>)
          : null,
      thumbnailUrl: thumbnailUrl,
      videoDuration: (json['videoDuration'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'mediaUrl': mediaUrl,
      'mediaType': mediaType,
      'caption': caption,
      'duration': duration,
      'viewsCount': viewsCount,
      'expiresAt': expiresAt.toIso8601String(),
      'backgroundColor': backgroundColor,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isViewed': isViewed,
      if (user != null) 'user': user!.toJson(),
      if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
      if (videoDuration != null) 'videoDuration': videoDuration,
    };
  }

  StoryModel copyWith({
    String? id,
    String? userId,
    String? mediaUrl,
    String? mediaType,
    String? caption,
    int? duration,
    int? viewsCount,
    DateTime? expiresAt,
    String? backgroundColor,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isViewed,
    StoryUserInfo? user,
    String? thumbnailUrl,
    double? videoDuration,
  }) {
    return StoryModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaType: mediaType ?? this.mediaType,
      caption: caption ?? this.caption,
      duration: duration ?? this.duration,
      viewsCount: viewsCount ?? this.viewsCount,
      expiresAt: expiresAt ?? this.expiresAt,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isViewed: isViewed ?? this.isViewed,
      user: user ?? this.user,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      videoDuration: videoDuration ?? this.videoDuration,
    );
  }

  /// Check if story is expired
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Get time ago string for display
  String get timeAgo {
    final now = DateTime.now();
    final diff = now.difference(createdAt);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

/// User info associated with a story
@immutable
class StoryUserInfo {
  const StoryUserInfo({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.chatPicture,
    this.mobileNumber,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String? chatPicture;
  final String? mobileNumber;

  factory StoryUserInfo.fromJson(Map<String, dynamic> json) {
    return StoryUserInfo(
      id: json['id'] as String? ?? '',
      firstName:
          json['firstName'] as String? ?? json['first_name'] as String? ?? '',
      lastName:
          json['lastName'] as String? ?? json['last_name'] as String? ?? '',
      chatPicture:
          json['chatPicture'] as String? ?? json['chat_picture'] as String?,
      mobileNumber:
          json['mobileNumber'] as String? ?? json['mobile_number'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      if (chatPicture != null) 'chatPicture': chatPicture,
      if (mobileNumber != null) 'mobileNumber': mobileNumber,
    };
  }

  String get fullName => '$firstName $lastName'.trim();
}

/// Grouped stories by user - for contacts stories response
@immutable
class UserStoriesGroup {
  const UserStoriesGroup({
    required this.user,
    required this.stories,
    required this.hasUnviewed,
  });

  final StoryUserInfo user;
  final List<StoryModel> stories;
  final bool hasUnviewed;

  factory UserStoriesGroup.fromJson(Map<String, dynamic> json) {
    return UserStoriesGroup(
      user: StoryUserInfo.fromJson(json['user'] as Map<String, dynamic>),
      stories:
          (json['stories'] as List<dynamic>?)
              ?.map((s) => StoryModel.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      hasUnviewed: json['hasUnviewed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user': user.toJson(),
      'stories': stories.map((s) => s.toJson()).toList(),
      'hasUnviewed': hasUnviewed,
    };
  }
}

/// Story viewer info
@immutable
class StoryViewerInfo {
  const StoryViewerInfo({
    required this.id,
    required this.viewedAt,
    required this.viewer,
  });

  final String id;
  final DateTime viewedAt;
  final StoryUserInfo viewer;

  factory StoryViewerInfo.fromJson(Map<String, dynamic> json) {
    return StoryViewerInfo(
      id: json['id'] as String? ?? '',
      viewedAt: json['viewedAt'] != null
          ? DateTime.parse(json['viewedAt'] as String)
          : DateTime.now(),
      viewer: StoryUserInfo.fromJson(json['viewer'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'viewedAt': viewedAt.toIso8601String(),
      'viewer': viewer.toJson(),
    };
  }
}

/// Story created event payload
@immutable
class StoryCreatedEvent {
  const StoryCreatedEvent({
    required this.storyId,
    required this.userId,
    required this.userName,
    this.userProfilePic,
    required this.mediaUrl,
    required this.mediaType,
    required this.createdAt,
    required this.timestamp,
    this.thumbnailUrl,
    this.videoDuration,
  });

  final String storyId;
  final String userId;
  final String userName;
  final String? userProfilePic;
  final String mediaUrl;
  final String mediaType;
  final DateTime createdAt;
  final DateTime timestamp;
  final String? thumbnailUrl;
  final double? videoDuration;

  factory StoryCreatedEvent.fromJson(Map<String, dynamic> json) {
    final mediaUrlRaw = json['mediaUrl'] as String? ?? '';
    final thumbnailUrlRaw = json['thumbnailUrl'] as String?;
    return StoryCreatedEvent(
      storyId: json['storyId'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      userName: json['userName'] as String? ?? '',
      userProfilePic: json['userProfilePic'] as String?,
      mediaUrl: _normalizeStreamUrl(mediaUrlRaw),
      mediaType: json['mediaType'] as String? ?? 'image',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String).toLocal()
          : DateTime.now(),
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String).toLocal()
          : DateTime.now(),
      thumbnailUrl: thumbnailUrlRaw == null
          ? null
          : _normalizeStreamUrl(thumbnailUrlRaw),
      videoDuration: (json['videoDuration'] as num?)?.toDouble(),
    );
  }
}

/// Story viewed event payload
@immutable
class StoryViewedEvent {
  const StoryViewedEvent({
    required this.storyId,
    required this.viewerId,
    required this.viewerName,
    this.viewerProfilePic,
    required this.timestamp,
  });

  final String storyId;
  final String viewerId;
  final String viewerName;
  final String? viewerProfilePic;
  final DateTime timestamp;

  factory StoryViewedEvent.fromJson(Map<String, dynamic> json) {
    return StoryViewedEvent(
      storyId: json['storyId'] as String? ?? '',
      viewerId: json['viewerId'] as String? ?? '',
      viewerName: json['viewerName'] as String? ?? '',
      viewerProfilePic: json['viewerProfilePic'] as String?,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
    );
  }
}

/// Story deleted event payload
@immutable
class StoryDeletedEvent {
  const StoryDeletedEvent({
    required this.storyId,
    required this.userId,
    required this.timestamp,
  });

  final String storyId;
  final String userId;
  final DateTime timestamp;

  factory StoryDeletedEvent.fromJson(Map<String, dynamic> json) {
    return StoryDeletedEvent(
      storyId: json['storyId'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
    );
  }
}

/// Story acknowledgment response from server
@immutable
class StoryAckResponse {
  const StoryAckResponse({
    required this.action,
    required this.requestId,
    required this.success,
    this.message,
    this.story,
    this.stories,
    this.viewers,
    this.totalViews,
    this.isNewView,
    this.error,
  });

  final String action;
  final String requestId;
  final bool success;
  final String? message;
  final StoryModel? story;
  final List<dynamic>?
  stories; // Can be List<StoryModel> or List<UserStoriesGroup>
  final List<StoryViewerInfo>? viewers;
  final int? totalViews;
  final bool? isNewView;
  final String? error;

  factory StoryAckResponse.fromJson(Map<String, dynamic> json) {
    return StoryAckResponse(
      action: json['action'] as String? ?? '',
      requestId: json['requestId'] as String? ?? '',
      success: json['success'] as bool? ?? false,
      message: json['message'] as String?,
      story: json['story'] != null
          ? StoryModel.fromJson(json['story'] as Map<String, dynamic>)
          : null,
      stories: json['stories'] as List<dynamic>?,
      viewers: (json['viewers'] as List<dynamic>?)
          ?.map((v) => StoryViewerInfo.fromJson(v as Map<String, dynamic>))
          .toList(),
      totalViews: json['totalViews'] as int?,
      isNewView: json['isNewView'] as bool?,
      error: json['error'] as String?,
    );
  }

  /// Parse stories for 'get-contacts' action (grouped by user)
  List<UserStoriesGroup> get contactsStories {
    if (stories == null) return [];
    return stories!
        .map((s) => UserStoriesGroup.fromJson(s as Map<String, dynamic>))
        .toList();
  }

  /// Parse stories for 'get-my' or 'get-user' action (flat list)
  List<StoryModel> get storyList {
    if (stories == null) return [];
    return stories!
        .map((s) => StoryModel.fromJson(s as Map<String, dynamic>))
        .toList();
  }
}
