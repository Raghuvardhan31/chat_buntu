part of 'package:chataway_plus/features/chat/data/services/chat_engine/chat_engine_service.dart';

/// UserProfileBroadcastMixin - Profile Update Handling
///
/// Handles broadcasted profile updates from other users:
/// - handleProfileUpdateInternal (from WebSocket)
/// - handleFCMProfileUpdate (from FCM)
/// - notifyContactJoined
mixin UserProfileBroadcastMixin on ChatEngineServiceBase {
  UserProfileBroadcastService? _profileBroadcastService;

  UserProfileBroadcastService get _broadcastService =>
      _profileBroadcastService ??= UserProfileBroadcastService(
        getCurrentUserId: () => _currentUserId,
        emitUpdate: (update) {
          final service = this as ChatEngineService;
          service._profileUpdateController.add(update);
        },
      );

  /// Handle profile update from WebSocket
  void handleProfileUpdateInternal(ProfileUpdate update) {
    _broadcastService.handleProfileUpdateInternal(update);
  }

  /// Handle FCM profile update (for offline contacts)
  void handleFCMProfileUpdate(Map<String, dynamic> data) {
    _broadcastService.handleFCMProfileUpdate(data);
  }

  /// Notify UI that a contact has joined the app
  void notifyContactJoined({
    required String userId,
    required String mobileNo,
    String? name,
    String? chatPictureUrl,
  }) {
    _broadcastService.notifyContactJoined(
      userId: userId,
      mobileNo: mobileNo,
      name: name,
      chatPictureUrl: chatPictureUrl,
    );
  }
}
