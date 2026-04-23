import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:chataway_plus/core/storage/token_storage.dart';
import 'package:chataway_plus/features/chat_stories/data/services/business/stories_cache_service.dart';
import 'package:chataway_plus/features/chat_stories/data/services/local/contacts_stories_local_db.dart';
import 'package:chataway_plus/features/chat_stories/data/services/local/my_stories_local_db.dart';
import 'package:chataway_plus/features/chat_stories/data/socket/story_socket_models.dart';

class StoriesFcmSyncService {
  StoriesFcmSyncService._();

  static final StoriesFcmSyncService instance = StoriesFcmSyncService._();

  final StreamController<Map<String, dynamic>> _changesController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get changesStream => _changesController.stream;

  Future<void> handle(Map<String, dynamic> data) async {
    try {
      final type = (data['type']?.toString() ?? '').toLowerCase();

      await StoriesCacheService.instance.initialize();

      final currentUserId = await TokenSecureStorage.instance
          .getCurrentUserIdUUID();
      if (currentUserId == null || currentUserId.isEmpty) return;

      if (type == 'story_created' ||
          type == 'story-created' ||
          type == 'new_story' ||
          type == 'contact_story') {
        await _handleStoryCreated(currentUserId, data);
      } else if (type == 'story_viewed' ||
          type == 'story-viewed' ||
          type == 'story_view') {
        await _handleStoryViewed(currentUserId, data);
      } else if (type == 'story_deleted' ||
          type == 'story-deleted' ||
          type == 'delete_story') {
        await _handleStoryDeleted(currentUserId, data);
      } else if (type == 'story_expired' || type == 'story-expired') {
        await _handleStoryExpired(currentUserId, data);
      }

      await StoriesCacheService.instance.cleanupExpiredStories();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ StoriesFcmSyncService.handle error: $e');
      }
    }
  }

  Future<void> _handleStoryCreated(
    String currentUserId,
    Map<String, dynamic> data,
  ) async {
    final story = _parseStoryModelFromPayload(data);
    if (story == null) return;

    final ownerId = story.userId.isNotEmpty
        ? story.userId
        : (data['userId']?.toString() ?? data['user_id']?.toString() ?? '');

    if (ownerId.isEmpty) return;

    // If this is my own story created from another device, cache into my stories
    if (ownerId == currentUserId) {
      await MyStoriesLocalDatabaseService.instance.cacheStory(
        currentUserId: currentUserId,
        story: story.copyWith(userId: currentUserId),
      );
      _notifyChange({'scope': 'my', 'type': 'story_created'});
      return;
    }

    final owner = _parseOwnerInfo(data, ownerId);

    await ContactsStoriesLocalDatabaseService.instance.upsertStory(
      currentUserId: currentUserId,
      owner: owner,
      story: story.copyWith(userId: ownerId),
      hasUnviewed: true,
    );

    _notifyChange({'scope': 'contacts', 'type': 'story_created'});
  }

  Future<void> _handleStoryViewed(
    String currentUserId,
    Map<String, dynamic> data,
  ) async {
    final storyId =
        data['storyId']?.toString() ?? data['story_id']?.toString() ?? '';
    if (storyId.isEmpty) return;

    final viewsCountRaw =
        data['viewsCount'] ??
        data['views_count'] ??
        data['totalViews'] ??
        data['total_views'];

    int? viewsCount;
    if (viewsCountRaw is int) {
      viewsCount = viewsCountRaw;
    } else if (viewsCountRaw != null) {
      viewsCount = int.tryParse(viewsCountRaw.toString());
    }

    if (viewsCount == null) {
      final existing = await MyStoriesLocalDatabaseService.instance
          .getViewsCount(currentUserId: currentUserId, storyId: storyId);
      if (existing != null) {
        viewsCount = existing + 1;
      }
    }

    if (viewsCount != null) {
      await MyStoriesLocalDatabaseService.instance.updateViewsCount(
        currentUserId: currentUserId,
        storyId: storyId,
        viewsCount: viewsCount,
      );
      _notifyChange({'scope': 'my', 'type': 'story_viewed'});
    }
  }

  Future<void> _handleStoryDeleted(
    String currentUserId,
    Map<String, dynamic> data,
  ) async {
    final storyId =
        data['storyId']?.toString() ?? data['story_id']?.toString() ?? '';
    final ownerId =
        data['userId']?.toString() ?? data['user_id']?.toString() ?? '';

    if (storyId.isNotEmpty) {
      await Future.wait([
        ContactsStoriesLocalDatabaseService.instance.deleteStory(
          currentUserId: currentUserId,
          storyId: storyId,
        ),
        MyStoriesLocalDatabaseService.instance.deleteStory(
          currentUserId: currentUserId,
          storyId: storyId,
        ),
      ]);

      _notifyChange({'scope': 'all', 'type': 'story_deleted'});
      return;
    }

    if (ownerId.isNotEmpty) {
      await ContactsStoriesLocalDatabaseService.instance
          .deleteStoriesForContact(
            currentUserId: currentUserId,
            contactId: ownerId,
          );
      _notifyChange({'scope': 'contacts', 'type': 'story_deleted'});
    }
  }

  Future<void> _handleStoryExpired(
    String currentUserId,
    Map<String, dynamic> data,
  ) async {
    final storyId =
        data['storyId']?.toString() ?? data['story_id']?.toString() ?? '';
    if (storyId.isNotEmpty) {
      await Future.wait([
        ContactsStoriesLocalDatabaseService.instance.deleteStory(
          currentUserId: currentUserId,
          storyId: storyId,
        ),
        MyStoriesLocalDatabaseService.instance.deleteStory(
          currentUserId: currentUserId,
          storyId: storyId,
        ),
      ]);
      _notifyChange({'scope': 'all', 'type': 'story_expired'});
    }
  }

  void _notifyChange(Map<String, dynamic> payload) {
    try {
      _changesController.add(payload);
    } catch (_) {}
  }

  StoryModel? _parseStoryModelFromPayload(Map<String, dynamic> data) {
    final storyMap = data['story'];
    if (storyMap is Map) {
      try {
        return StoryModel.fromJson(Map<String, dynamic>.from(storyMap));
      } catch (_) {}
    }

    final id =
        data['storyId']?.toString() ?? data['story_id']?.toString() ?? '';
    final userId =
        data['userId']?.toString() ?? data['user_id']?.toString() ?? '';
    final mediaUrl =
        data['mediaUrl']?.toString() ?? data['media_url']?.toString() ?? '';
    final mediaType =
        data['mediaType']?.toString() ??
        data['media_type']?.toString() ??
        'image';

    if (id.isEmpty || mediaUrl.isEmpty) return null;

    final createdAt = _parseDateTime(
      data['createdAt'] ?? data['created_at'] ?? data['timestamp'],
    );
    final expiresAtValue = data['expiresAt'] ?? data['expires_at'];
    final expiresAt = expiresAtValue != null
        ? _parseDateTime(expiresAtValue)
        : createdAt.add(const Duration(hours: 24));

    final durationRaw = data['duration'];
    final duration = durationRaw is int
        ? durationRaw
        : int.tryParse('${durationRaw ?? ''}') ?? 5;

    final viewsRaw = data['viewsCount'] ?? data['views_count'];
    final viewsCount = viewsRaw is int
        ? viewsRaw
        : int.tryParse('${viewsRaw ?? ''}') ?? 0;

    final caption = data['caption']?.toString();
    final bg =
        data['backgroundColor']?.toString() ??
        data['background_color']?.toString();

    // FCM sends thumbnailUrl and videoDuration (as string) for video stories
    final thumbnailUrl =
        data['thumbnailUrl']?.toString() ?? data['thumbnail_url']?.toString();
    final videoDurationRaw = data['videoDuration'] ?? data['video_duration'];
    final double? videoDuration = videoDurationRaw is num
        ? videoDurationRaw.toDouble()
        : double.tryParse('${videoDurationRaw ?? ''}');

    return StoryModel(
      id: id,
      userId: userId,
      mediaUrl: mediaUrl,
      mediaType: mediaType,
      caption: caption,
      duration: duration,
      viewsCount: viewsCount,
      expiresAt: expiresAt,
      backgroundColor: bg,
      createdAt: createdAt,
      updatedAt: createdAt,
      isViewed: false,
      user: null,
      thumbnailUrl: thumbnailUrl,
      videoDuration: videoDuration,
    );
  }

  StoryUserInfo _parseOwnerInfo(Map<String, dynamic> data, String ownerId) {
    final userName =
        data['userName']?.toString() ?? data['user_name']?.toString() ?? '';
    String firstName = '';
    String lastName = '';
    final parts = userName.trim().split(RegExp(r'\s+'));
    if (parts.isNotEmpty) {
      firstName = parts.first;
      if (parts.length > 1) {
        lastName = parts.sublist(1).join(' ');
      }
    }

    final chatPicture =
        data['userProfilePic']?.toString() ??
        data['user_profile_pic']?.toString() ??
        data['chatPicture']?.toString() ??
        data['chat_picture']?.toString();

    final mobile =
        data['mobileNumber']?.toString() ?? data['mobile_number']?.toString();

    return StoryUserInfo(
      id: ownerId,
      firstName: firstName,
      lastName: lastName,
      chatPicture: chatPicture,
      mobileNumber: mobile,
    );
  }

  DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.fromMillisecondsSinceEpoch(0);
    if (value is DateTime) return value.toLocal();
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value).toLocal();
    }
    if (value is String) {
      try {
        return DateTime.parse(value).toLocal();
      } catch (_) {
        return DateTime.fromMillisecondsSinceEpoch(0);
      }
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}
