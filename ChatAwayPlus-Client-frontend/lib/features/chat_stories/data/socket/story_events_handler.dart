import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import 'story_socket_constants.dart';
import 'story_socket_models.dart';

/// Handler for story-related events from the server
///
/// Registers listeners for:
/// - stories:ack - Acknowledgment responses for all story actions
/// - story-created - New story from a contact
/// - story-viewed - Someone viewed my story
/// - story-deleted - A story was deleted
class StoryEventsHandler {
  const StoryEventsHandler();

  static const bool _verboseLogs = false;

  /// Register all story event listeners
  void register({
    required io.Socket socket,
    required void Function(StoryAckResponse ack) onStoryAck,
    required void Function(StoryCreatedEvent event) onStoryCreated,
    required void Function(StoryViewedEvent event) onStoryViewed,
    required void Function(StoryDeletedEvent event) onStoryDeleted,
  }) {
    // ═══════════════════════════════════════════════════════════════════════
    // stories:ack - Acknowledgment for all story operations
    // ═══════════════════════════════════════════════════════════════════════
    socket.on(StorySocketEventNames.storiesAck, (data) {
      if (_verboseLogs) {
        debugPrint('🎯 STORIES:ACK EVENT FIRED!');
        debugPrint('📨 Data: $data');
      }

      try {
        final map = data is Map
            ? Map<String, dynamic>.from(data)
            : <String, dynamic>{};
        final ack = StoryAckResponse.fromJson(map);

        if (_verboseLogs) {
          debugPrint(
            '✅ StoryAck parsed: action=${ack.action}, success=${ack.success}',
          );
        }

        onStoryAck(ack);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('❌ Error parsing stories:ack: $e');
        }
      }
    });

    // ═══════════════════════════════════════════════════════════════════════
    // story-created - New story from a contact
    // ═══════════════════════════════════════════════════════════════════════
    socket.on(StorySocketEventNames.storyCreated, (data) {
      if (_verboseLogs) {
        debugPrint('🎯 STORY-CREATED EVENT FIRED!');
        debugPrint('📨 Data: $data');
      }

      try {
        final map = data is Map
            ? Map<String, dynamic>.from(data)
            : <String, dynamic>{};
        final event = StoryCreatedEvent.fromJson(map);

        if (_verboseLogs) {
          debugPrint(
            '✅ StoryCreated parsed: userId=${event.userId}, userName=${event.userName}',
          );
        }

        onStoryCreated(event);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('❌ Error parsing story-created: $e');
        }
      }
    });

    // ═══════════════════════════════════════════════════════════════════════
    // story-viewed - Someone viewed my story
    // ═══════════════════════════════════════════════════════════════════════
    socket.on(StorySocketEventNames.storyViewed, (data) {
      if (_verboseLogs) {
        debugPrint('🎯 STORY-VIEWED EVENT FIRED!');
        debugPrint('📨 Data: $data');
      }

      try {
        final map = data is Map
            ? Map<String, dynamic>.from(data)
            : <String, dynamic>{};
        final event = StoryViewedEvent.fromJson(map);

        if (_verboseLogs) {
          debugPrint(
            '✅ StoryViewed parsed: storyId=${event.storyId}, viewerName=${event.viewerName}',
          );
        }

        onStoryViewed(event);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('❌ Error parsing story-viewed: $e');
        }
      }
    });

    // ═══════════════════════════════════════════════════════════════════════
    // story-deleted - A story was deleted
    // ═══════════════════════════════════════════════════════════════════════
    socket.on(StorySocketEventNames.storyDeleted, (data) {
      if (_verboseLogs) {
        debugPrint('🎯 STORY-DELETED EVENT FIRED!');
        debugPrint('📨 Data: $data');
      }

      try {
        final map = data is Map
            ? Map<String, dynamic>.from(data)
            : <String, dynamic>{};
        final event = StoryDeletedEvent.fromJson(map);

        if (_verboseLogs) {
          debugPrint(
            '✅ StoryDeleted parsed: storyId=${event.storyId}, userId=${event.userId}',
          );
        }

        onStoryDeleted(event);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('❌ Error parsing story-deleted: $e');
        }
      }
    });
  }

  /// Unregister all story event listeners
  void unregister(io.Socket socket) {
    socket.off(StorySocketEventNames.storiesAck);
    socket.off(StorySocketEventNames.storyCreated);
    socket.off(StorySocketEventNames.storyViewed);
    socket.off(StorySocketEventNames.storyDeleted);
  }
}
