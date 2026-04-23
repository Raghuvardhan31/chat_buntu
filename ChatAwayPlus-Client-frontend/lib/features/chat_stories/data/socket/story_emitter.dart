import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:uuid/uuid.dart';

import 'story_socket_constants.dart';

/// Emitter for sending story-related events to the server
///
/// All methods return a requestId that can be used to match the response
class StoryEmitter {
  const StoryEmitter();

  static const bool _verboseLogs = false;
  static const Uuid _uuid = Uuid();

  /// Generate a unique request ID for matching responses
  String _generateRequestId() => _uuid.v4();

  /// Create a new story
  ///
  /// Before calling this, upload the media to S3 using the upload endpoint.
  /// Returns requestId for matching the acknowledgment response.
  String createStory({
    required io.Socket socket,
    required String mediaUrl,
    required String mediaType,
    String? caption,
    int? duration,
    String? backgroundColor,
    String? thumbnailUrl,
    double? videoDuration,
  }) {
    final requestId = _generateRequestId();
    try {
      final payload = <String, dynamic>{
        'requestId': requestId,
        'mediaUrl': mediaUrl,
        'mediaType': mediaType,
        if (caption != null && caption.isNotEmpty) 'caption': caption,
        if (duration != null) 'duration': duration,
        if (backgroundColor != null) 'backgroundColor': backgroundColor,
        if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
        if (videoDuration != null) 'videoDuration': videoDuration,
      };

      if (_verboseLogs) {
        debugPrint('📤 StoryEmitter.createStory: $payload');
      }

      socket.emit(StorySocketEventNames.storiesCreate, payload);
      return requestId;
    } catch (e) {
      debugPrint('❌ StoryEmitter.createStory failed: $e');
      return requestId;
    }
  }

  /// Get stories from all contacts
  ///
  /// Returns requestId for matching the acknowledgment response.
  String getContactsStories({required io.Socket socket}) {
    final requestId = _generateRequestId();
    try {
      final payload = <String, dynamic>{'requestId': requestId};

      if (_verboseLogs) {
        debugPrint('📤 StoryEmitter.getContactsStories: $payload');
      }

      socket.emit(StorySocketEventNames.storiesGetContacts, payload);
      return requestId;
    } catch (e) {
      debugPrint('❌ StoryEmitter.getContactsStories failed: $e');
      return requestId;
    }
  }

  /// Get my own stories
  ///
  /// Returns requestId for matching the acknowledgment response.
  String getMyStories({required io.Socket socket}) {
    final requestId = _generateRequestId();
    try {
      final payload = <String, dynamic>{'requestId': requestId};

      if (_verboseLogs) {
        debugPrint('📤 StoryEmitter.getMyStories: $payload');
      }

      socket.emit(StorySocketEventNames.storiesGetMy, payload);
      return requestId;
    } catch (e) {
      debugPrint('❌ StoryEmitter.getMyStories failed: $e');
      return requestId;
    }
  }

  /// Get a specific user's stories
  ///
  /// Returns requestId for matching the acknowledgment response.
  String getUserStories({required io.Socket socket, required String userId}) {
    final requestId = _generateRequestId();
    try {
      final payload = <String, dynamic>{
        'requestId': requestId,
        'userId': userId,
      };

      if (_verboseLogs) {
        debugPrint('📤 StoryEmitter.getUserStories: $payload');
      }

      socket.emit(StorySocketEventNames.storiesGetUser, payload);
      return requestId;
    } catch (e) {
      debugPrint('❌ StoryEmitter.getUserStories failed: $e');
      return requestId;
    }
  }

  /// Mark a story as viewed
  ///
  /// Returns requestId for matching the acknowledgment response.
  String markStoryViewed({required io.Socket socket, required String storyId}) {
    final requestId = _generateRequestId();
    try {
      final payload = <String, dynamic>{
        'requestId': requestId,
        'storyId': storyId,
      };

      if (_verboseLogs) {
        debugPrint('📤 StoryEmitter.markStoryViewed: $payload');
      }

      socket.emit(StorySocketEventNames.storiesMarkViewed, payload);
      return requestId;
    } catch (e) {
      debugPrint('❌ StoryEmitter.markStoryViewed failed: $e');
      return requestId;
    }
  }

  /// Get viewers for a story (owner only)
  ///
  /// Returns requestId for matching the acknowledgment response.
  String getStoryViewers({required io.Socket socket, required String storyId}) {
    final requestId = _generateRequestId();
    try {
      final payload = <String, dynamic>{
        'requestId': requestId,
        'storyId': storyId,
      };

      if (_verboseLogs) {
        debugPrint('📤 StoryEmitter.getStoryViewers: $payload');
      }

      socket.emit(StorySocketEventNames.storiesGetViewers, payload);
      return requestId;
    } catch (e) {
      debugPrint('❌ StoryEmitter.getStoryViewers failed: $e');
      return requestId;
    }
  }

  /// Delete a story (owner only)
  ///
  /// Returns requestId for matching the acknowledgment response.
  String deleteStory({required io.Socket socket, required String storyId}) {
    final requestId = _generateRequestId();
    try {
      final payload = <String, dynamic>{
        'requestId': requestId,
        'storyId': storyId,
      };

      if (_verboseLogs) {
        debugPrint('📤 StoryEmitter.deleteStory: $payload');
      }

      socket.emit(StorySocketEventNames.storiesDelete, payload);
      return requestId;
    } catch (e) {
      debugPrint('❌ StoryEmitter.deleteStory failed: $e');
      return requestId;
    }
  }
}
