import 'package:flutter/foundation.dart';
import 'package:chataway_plus/core/storage/token_storage.dart';
import 'package:chataway_plus/features/chat/data/services/chat_engine/index.dart';

/// Silent FCM Notification Handler for Profile Updates
///
/// Handles incoming FCM notifications when a contact updates their profile.
/// This is a SILENT handler - no user-facing notification is shown.
/// WhatsApp-style: Just update local DB and notify UI silently.
///
/// FCM Payload Structure:
/// {
///   type: 'profile_update',
///   userId: 'user_123',
///   updatedData: { ... },
///   updatedFields: ['firstName', 'chatPictureUrl', ...]
/// }
class ProfileUpdateSilentFcmHandler {
  const ProfileUpdateSilentFcmHandler._();

  static final TokenSecureStorage _tokenStorage = TokenSecureStorage();

  /// Handle incoming profile update FCM notification (SILENT)
  /// No notification shown - just updates local DB and notifies UI
  static Future<void> handle(Map<String, dynamic> data) async {
    try {
      if (kDebugMode) {
        debugPrint('👤 [ProfileUpdateSilentFcmHandler] Processing silently...');
        debugPrint('📦 Payload: $data');
      }

      // Skip processing if this profile update belongs to the current user
      // (self-updates should not create any local notification or DB changes)
      final userId = data['userId'] as String?;
      if (userId != null && userId.isNotEmpty) {
        final currentUserId = await _tokenStorage.getCurrentUserIdUUID();
        if (currentUserId != null &&
            currentUserId.isNotEmpty &&
            currentUserId == userId) {
          if (kDebugMode) {
            debugPrint(
              '👤 [ProfileUpdateSilentFcmHandler] Update is for current user – ignoring',
            );
          }
          return;
        }
      }

      // Delegate to ChatEngineService to update local DB and notify UI
      ChatEngineService.instance.handleFCMProfileUpdate(data);

      if (kDebugMode) {
        debugPrint(
          '✅ [ProfileUpdateSilentFcmHandler] Processed - NO notification shown',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [ProfileUpdateSilentFcmHandler] Error: $e');
      }
    }
  }

  /// Check if payload is a profile update notification
  static bool isProfileUpdateNotification(Map<String, dynamic> payload) {
    final type = payload['type']?.toString().toLowerCase();
    if (type == 'profile_update' || type == 'profile-updated') {
      return true;
    }

    // Also check by data fields pattern
    return (payload.containsKey('updatedData') ||
            payload.containsKey('updatedFields')) &&
        payload.containsKey('userId');
  }
}
