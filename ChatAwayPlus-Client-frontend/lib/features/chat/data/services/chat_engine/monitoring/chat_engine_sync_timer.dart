part of '../chat_engine_service.dart';

mixin ChatEngineSyncTimerMixin {
  Timer? _syncTimer;
}

void _startPeriodicSyncImpl(ChatEngineService service) {
  service._syncTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
    if (AppStateService.instance.isAppInBackground) {
      return;
    }

    // If online but socket disconnected, attempt reconnection.
    // This self-heals after max reconnect attempts are exhausted during
    // a brief network blip while the app stays in the foreground.
    if (service._isOnline && !service._chatRepository.isConnected) {
      try {
        service._chatRepository.connectionManager.allowImmediateReconnect();
      } catch (_) {}
      unawaited(service._chatRepository.initializeSocket());
      return;
    }

    if (service._isOnline && service._chatRepository.isConnected) {
      service.syncPendingMessages();

      if (service._activeConversationUserId != null) {
        service.syncConversationWithServer(
          service._activeConversationUserId!,
          force: false,
        );
      }
    }
  });
}
