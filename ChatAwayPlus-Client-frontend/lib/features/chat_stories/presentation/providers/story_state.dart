import 'package:flutter/foundation.dart';
import '../../data/socket/story_socket_models.dart';

// ═══════════════════════════════════════════════════════════════════════════
// CONTACTS STORIES STATE
// ═══════════════════════════════════════════════════════════════════════════

/// State for contacts stories
@immutable
class ContactsStoriesState {
  const ContactsStoriesState({
    this.stories = const [],
    this.isLoading = true, // Start with loading true
    this.error,
    this.lastUpdated,
  });

  final List<UserStoriesGroup> stories;
  final bool isLoading;
  final String? error;
  final DateTime? lastUpdated;

  ContactsStoriesState copyWith({
    List<UserStoriesGroup>? stories,
    bool? isLoading,
    String? error,
    DateTime? lastUpdated,
  }) {
    return ContactsStoriesState(
      stories: stories ?? this.stories,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  /// Get stories that have unviewed content (should appear first)
  List<UserStoriesGroup> get unviewedStories =>
      stories.where((g) => g.hasUnviewed).toList();

  /// Get stories that have been fully viewed
  List<UserStoriesGroup> get viewedStories =>
      stories.where((g) => !g.hasUnviewed).toList();
}

// ═══════════════════════════════════════════════════════════════════════════
// MY STORIES STATE
// ═══════════════════════════════════════════════════════════════════════════

/// State for my stories
@immutable
class MyStoriesState {
  const MyStoriesState({
    this.stories = const [],
    this.isLoading = true, // Start with loading true
    this.error,
    this.lastUpdated,
  });

  final List<StoryModel> stories;
  final bool isLoading;
  final String? error;
  final DateTime? lastUpdated;

  MyStoriesState copyWith({
    List<StoryModel>? stories,
    bool? isLoading,
    String? error,
    DateTime? lastUpdated,
  }) {
    return MyStoriesState(
      stories: stories ?? this.stories,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  /// Check if user has any active stories
  bool get hasStories => stories.isNotEmpty;

  /// Total views across all my stories
  int get totalViews => stories.fold(0, (sum, s) => sum + s.viewsCount);
}

// ═══════════════════════════════════════════════════════════════════════════
// STORY VIEWERS STATE
// ═══════════════════════════════════════════════════════════════════════════

/// State for story viewers
@immutable
class StoryViewersState {
  const StoryViewersState({
    this.viewers = const [],
    this.totalViews = 0,
    this.isLoading = false,
    this.error,
  });

  final List<StoryViewerInfo> viewers;
  final int totalViews;
  final bool isLoading;
  final String? error;

  StoryViewersState copyWith({
    List<StoryViewerInfo>? viewers,
    int? totalViews,
    bool? isLoading,
    String? error,
  }) {
    return StoryViewersState(
      viewers: viewers ?? this.viewers,
      totalViews: totalViews ?? this.totalViews,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}
