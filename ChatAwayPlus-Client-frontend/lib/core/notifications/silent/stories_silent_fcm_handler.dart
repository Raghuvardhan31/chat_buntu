import 'package:flutter/foundation.dart';
import 'package:chataway_plus/features/chat_stories/data/services/sync/stories_fcm_sync_service.dart';

/// Silent FCM Notification Handler for Story Updates
///
/// Handles incoming FCM notifications for story-related events.
/// This is a SILENT handler - no user-facing notification is shown.
/// WhatsApp-style: Just update local DB and notify UI silently.
///
/// Supported Story FCM Types:
/// - story_created: When a contact posts a new story
/// - story_viewed: When someone views your story
/// - story_deleted: When a contact deletes their story
/// - story_expired: When a story expires (24h)
///
/// FCM Payload Structure:
/// {
///   type: 'story_created' | 'story_viewed' | 'story_deleted' | 'story_expired',
///   userId: 'user_123',
///   storyId: 'story_456',
///   ... (additional fields based on type)
/// }
class StoriesSilentFcmHandler {
  const StoriesSilentFcmHandler._();

  static Map<String, dynamic> _normalizePayload(Map<String, dynamic> data) {
    final normalized = Map<String, dynamic>.from(data);

    final messageType =
        (normalized['messageType'] ?? normalized['message_type'] ?? '')
            .toString()
            .toLowerCase();
    final type = (normalized['type'] ?? normalized['notificationType'] ?? '')
        .toString()
        .toLowerCase();

    // If this is already a concrete story event, keep it.
    // Note: backend uses `type: stories_changed` which must be normalized.
    if (type.isNotEmpty && type != 'stories_changed') return normalized;

    if (type == 'stories_changed' || messageType == 'stories_changed') {
      final action = (normalized['action'] ?? '').toString().toLowerCase();
      final mappedType = switch (action) {
        'created' => 'story_created',
        'deleted' => 'story_deleted',
        'viewed' => 'story_viewed',
        'expired' => 'story_expired',
        _ => '',
      };

      if (mappedType.isNotEmpty) {
        normalized['type'] = mappedType;
        normalized['userId'] ??=
            normalized['actorUserId'] ?? normalized['actor_user_id'];
      }
    }

    return normalized;
  }

  /// Handle incoming story FCM notification (SILENT)
  /// No notification shown - just updates local state and notifies UI
  static Future<void> handle(Map<String, dynamic> data) async {
    try {
      final payload = _normalizePayload(data);

      if (kDebugMode) {
        debugPrint('📖 [StoriesSilentFcmHandler] Processing silently...');
        debugPrint('📦 Payload: $payload');
      }

      final type = payload['type']?.toString().toLowerCase() ?? '';

      // Handle based on story event type
      switch (type) {
        case 'story_created':
        case 'story-created':
        case 'new_story':
        case 'contact_story':
          await _handleStoryCreated(payload);
          break;

        case 'story_viewed':
        case 'story-viewed':
        case 'story_view':
          await _handleStoryViewed(payload);
          break;

        case 'story_deleted':
        case 'story-deleted':
        case 'delete_story':
          await _handleStoryDeleted(payload);
          break;

        case 'story_expired':
        case 'story-expired':
          await _handleStoryExpired(payload);
          break;

        default:
          if (kDebugMode) {
            debugPrint(
              '📖 [StoriesSilentFcmHandler] Unknown story type: $type',
            );
          }
      }

      if (kDebugMode) {
        debugPrint(
          '✅ [StoriesSilentFcmHandler] Processed - NO notification shown',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [StoriesSilentFcmHandler] Error: $e');
      }
    }
  }

  /// Handle story created event
  /// Notify UI to refresh contacts stories list
  static Future<void> _handleStoryCreated(Map<String, dynamic> data) async {
    if (kDebugMode) {
      debugPrint('📖 [StoriesSilentFcmHandler] Story created by contact');
    }

    await StoriesFcmSyncService.instance.handle(data);
  }

  /// Handle story viewed event
  /// Update view count for current user's story
  static Future<void> _handleStoryViewed(Map<String, dynamic> data) async {
    if (kDebugMode) {
      debugPrint('📖 [StoriesSilentFcmHandler] Story viewed');
    }

    await StoriesFcmSyncService.instance.handle(data);
  }

  /// Handle story deleted event
  /// Remove story from local cache
  static Future<void> _handleStoryDeleted(Map<String, dynamic> data) async {
    if (kDebugMode) {
      debugPrint('📖 [StoriesSilentFcmHandler] Story deleted');
    }

    await StoriesFcmSyncService.instance.handle(data);
  }

  /// Handle story expired event
  /// Remove expired story from local cache
  static Future<void> _handleStoryExpired(Map<String, dynamic> data) async {
    if (kDebugMode) {
      debugPrint('📖 [StoriesSilentFcmHandler] Story expired');
    }

    await StoriesFcmSyncService.instance.handle(data);
  }

  /// Check if payload is a story notification
  static bool isStoryNotification(Map<String, dynamic> payload) {
    final type = payload['type']?.toString().toLowerCase() ?? '';

    // Check explicit story types
    if (type.contains('story')) {
      return true;
    }

    // Check by data fields pattern
    if (payload.containsKey('storyId') || payload.containsKey('story_id')) {
      return true;
    }

    return false;
  }

  /// List of all story notification types
  static const List<String> storyNotificationTypes = [
    'story_created',
    'story-created',
    'new_story',
    'contact_story',
    'story_viewed',
    'story-viewed',
    'story_view',
    'story_deleted',
    'story-deleted',
    'delete_story',
    'story_expired',
    'story-expired',
  ];
}
