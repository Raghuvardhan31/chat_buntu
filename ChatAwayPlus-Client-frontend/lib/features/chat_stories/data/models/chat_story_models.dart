import 'package:flutter/material.dart';

import '../socket/story_socket_models.dart';

@immutable
class ChatStorySlide {
  const ChatStorySlide({
    required this.imageUrl,
    this.caption,
    this.storyId,
    this.isViewed = false,
    this.timeAgo = '',
    this.mediaType = 'image',
    this.thumbnailUrl,
    this.videoDuration,
    this.videoUrl,
  });

  final String imageUrl;
  final String? caption;
  final String? storyId;
  final bool isViewed;
  final String timeAgo;
  final String mediaType; // 'image' or 'video'
  final String? thumbnailUrl;
  final double? videoDuration;
  final String? videoUrl;

  /// Whether this slide is a video
  bool get isVideo => mediaType == 'video';

  /// Create from socket StoryModel
  factory ChatStorySlide.fromStoryModel(StoryModel story) {
    return ChatStorySlide(
      // For video stories, use thumbnail URL if available
      // Don't fallback to video URL as it can't be loaded as an image
      imageUrl: story.mediaType == 'video'
          ? (story.thumbnailUrl ?? '') // Empty string if no thumbnail
          : story.mediaUrl,
      caption: story.caption,
      storyId: story.id,
      isViewed: story.isViewed,
      timeAgo: story.timeAgo,
      mediaType: story.mediaType,
      thumbnailUrl: story.thumbnailUrl,
      videoDuration: story.videoDuration,
      videoUrl: story.mediaType == 'video' ? story.mediaUrl : null,
    );
  }
}

@immutable
class ChatStoryModel {
  const ChatStoryModel({
    required this.id,
    required this.name,
    required this.timeAgo,
    required this.type,
    required this.hasStory,
    required this.profileImage,
    required this.slides,
    this.userId,
    this.hasUnviewed = false,
  });

  final String id;
  final String name;
  final String timeAgo;
  final String type;
  final bool hasStory;
  final String profileImage;
  final List<ChatStorySlide> slides;
  final String? userId;
  final bool hasUnviewed;

  /// Create from socket UserStoriesGroup
  factory ChatStoryModel.fromUserStoriesGroup(UserStoriesGroup group) {
    final user = group.user;
    final stories = group.stories;

    // Sort stories by createdAt ascending (oldest first) to maintain upload order
    // Story 1 stays as 1, Story 2 stays as 2, etc.
    final sortedStories = List<StoryModel>.from(stories)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    // Calculate time ago from newest story (most recent)
    String timeAgo = '';
    if (sortedStories.isNotEmpty) {
      timeAgo = sortedStories.last.timeAgo;
    }

    return ChatStoryModel(
      id: user.id,
      userId: user.id,
      name: user.fullName,
      timeAgo: timeAgo,
      type: sortedStories.isNotEmpty ? '${sortedStories.length}' : '',
      hasStory: sortedStories.isNotEmpty,
      profileImage: user.chatPicture ?? '',
      slides: sortedStories
          .map((s) => ChatStorySlide.fromStoryModel(s))
          .toList(),
      hasUnviewed: group.hasUnviewed,
    );
  }

  /// Create from list of socket StoryModel (for my stories)
  factory ChatStoryModel.fromMyStories({
    required String id,
    required String name,
    required String profileImage,
    required List<StoryModel> stories,
  }) {
    // Sort stories by createdAt ascending (oldest first) to maintain upload order
    // Story 1 stays as 1, Story 2 stays as 2, etc.
    final sortedStories = List<StoryModel>.from(stories)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    // Calculate time ago from newest story (most recent)
    String timeAgo = '';
    if (sortedStories.isNotEmpty) {
      timeAgo = sortedStories.last.timeAgo;
    }

    return ChatStoryModel(
      id: id,
      userId: id,
      name: name,
      timeAgo: timeAgo,
      type: sortedStories.isNotEmpty ? '${sortedStories.length}' : '',
      hasStory: sortedStories.isNotEmpty,
      profileImage: profileImage,
      slides: sortedStories
          .map((s) => ChatStorySlide.fromStoryModel(s))
          .toList(),
      hasUnviewed: false,
    );
  }

  /// Get list of story IDs
  List<String> get storyIds =>
      slides.where((s) => s.storyId != null).map((s) => s.storyId!).toList();

  /// Get indices of viewed slides
  Set<int> get viewedSlideIndices {
    final indices = <int>{};
    for (int i = 0; i < slides.length; i++) {
      if (slides[i].isViewed) {
        indices.add(i);
      }
    }
    return indices;
  }
}
