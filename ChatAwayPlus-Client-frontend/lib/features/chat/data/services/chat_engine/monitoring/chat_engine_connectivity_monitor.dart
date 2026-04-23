part of '../chat_engine_service.dart';

mixin ChatEngineConnectivityMonitorMixin {
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
}

void _setupConnectivityMonitoringImpl(ChatEngineService service) {
  service._connectivitySubscription = Connectivity().onConnectivityChanged
      .listen(service._onConnectivityChanged);
}

void _onConnectivityChangedImpl(
  ChatEngineService service,
  List<ConnectivityResult> results,
) {
  final wasOnline = service._isOnline;
  service._isOnline = results.any(
    (result) => result != ConnectivityResult.none,
  );

  debugPrint(
    ' ChatEngineService: Connectivity changed: $results (Online: ${service._isOnline})',
  );

  if (!wasOnline && service._isOnline) {
    debugPrint(
      ' ChatEngineService: Connection restored, syncing pending messages...',
    );
    service.syncPendingMessages();

    final allowIncomingSync =
        !AppStateService.instance.isAppInBackground ||
        (service._activeConversationUserId != null &&
            service._activeConversationUserId!.isNotEmpty);
    if (allowIncomingSync) {
      service.syncAllPendingIncomingMessages();
    }

    if (!service._chatRepository.isConnected) {
      debugPrint(
        ' ChatEngineService: WebSocket disconnected after connectivity restore - attempting reconnection...',
      );
      // DNS may not be ready immediately after WiFi reconnect - retry with backoff
      unawaited(_attemptReconnectWithRetry(service));
    }
  }

  service._onConnectionChanged?.call(service._isOnline);
}

/// Attempt socket reconnection with retry logic for DNS not ready scenarios
/// WiFi reconnect often triggers "online" before DNS is actually working
Future<void> _attemptReconnectWithRetry(
  ChatEngineService service, {
  int attempt = 1,
  int maxAttempts = 4,
}) async {
  if (attempt > maxAttempts) {
    debugPrint(
      '⚠️ ChatEngineService: Max reconnect retries ($maxAttempts) reached after connectivity restore',
    );
    return;
  }

  // Skip if already connected or app went offline again
  if (service._chatRepository.isConnected || !service._isOnline) {
    return;
  }

  // Skip if app is in background (will reconnect on resume)
  if (AppStateService.instance.isAppInBackground) {
    debugPrint(
      '💤 ChatEngineService: App in background - skipping reconnect retry',
    );
    return;
  }

  debugPrint(
    '🔄 ChatEngineService: Reconnect attempt $attempt/$maxAttempts...',
  );

  // Allow immediate reconnect (bypass throttle)
  try {
    service._chatRepository.connectionManager.allowImmediateReconnect();
  } catch (_) {}

  final success = await service._chatRepository.initializeSocket();

  if (success) {
    debugPrint('✅ ChatEngineService: Reconnected on attempt $attempt');
    return;
  }

  // Exponential backoff: 0s (first retry), 1s, 2s, 4s
  // First retry is immediate, subsequent retries have increasing delays
  final delaySeconds = attempt == 1 ? 0 : (1 << (attempt - 2)); // 0, 1, 2, 4
  if (delaySeconds > 0) {
    debugPrint(
      '⏳ ChatEngineService: Reconnect failed, retrying in ${delaySeconds}s...',
    );
    await Future<void>.delayed(Duration(seconds: delaySeconds));
  } else {
    debugPrint(
      '⏳ ChatEngineService: Reconnect failed, retrying immediately...',
    );
  }

  // Recurse with next attempt
  await _attemptReconnectWithRetry(
    service,
    attempt: attempt + 1,
    maxAttempts: maxAttempts,
  );
}
