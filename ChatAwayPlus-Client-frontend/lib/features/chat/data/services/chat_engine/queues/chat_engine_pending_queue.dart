part of '../chat_engine_service.dart';

mixin ChatEnginePendingQueueMixin on ChatEngineServiceBase {
  bool _pendingReadFlushInProgress = false;
  bool _pendingDeliveredFlushInProgress = false;

  @override
  Future<bool> _markMessagesDeliveredViaRest({
    required List<String> messageIds,
    String receiverDeliveryChannel = 'fcm',
  }) async {
    if (messageIds.isEmpty) return true;
    try {
      final token = await TokenSecureStorage.instance.getToken();
      if (token == null || token.isEmpty) return false;

      final uri = Uri.parse(ApiUrls.markMessagesAsDelivered);
      final client = http.Client();
      try {
        final response = await client
            .put(
              uri,
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
              body: jsonEncode({
                'messageIds': messageIds,
                'receiverDeliveryChannel': receiverDeliveryChannel,
              }),
            )
            .timeout(const Duration(seconds: 10));
        return response.statusCode >= 200 && response.statusCode < 300;
      } finally {
        client.close();
      }
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> _enqueuePendingReadIds(List<String> messageIds) async {
    if (messageIds.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing =
          prefs.getStringList(ChatEngineService._pendingReadIdsPrefsKey) ??
          <String>[];
      final merged = <String>{...existing, ...messageIds}.toList();
      await prefs.setStringList(
        ChatEngineService._pendingReadIdsPrefsKey,
        merged,
      );
    } catch (_) {
      // ignore
    }
  }

  @override
  Future<void> _enqueuePendingDeliveredIds(List<String> messageIds) async {
    if (messageIds.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing =
          prefs.getStringList(ChatEngineService._pendingDeliveredIdsPrefsKey) ??
          <String>[];
      final merged = <String>{...existing, ...messageIds}.toList();
      await prefs.setStringList(
        ChatEngineService._pendingDeliveredIdsPrefsKey,
        merged,
      );
    } catch (_) {
      // ignore
    }
  }

  Future<List<String>> _getPendingReadIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(ChatEngineService._pendingReadIdsPrefsKey) ??
          <String>[];
    } catch (_) {
      return <String>[];
    }
  }

  Future<List<String>> _getPendingDeliveredIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(
            ChatEngineService._pendingDeliveredIdsPrefsKey,
          ) ??
          <String>[];
    } catch (_) {
      return <String>[];
    }
  }

  Future<void> _removePendingReadIds(Set<String> idsToRemove) async {
    if (idsToRemove.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing =
          prefs.getStringList(ChatEngineService._pendingReadIdsPrefsKey) ??
          <String>[];
      if (existing.isEmpty) return;
      final updated = existing
          .where((id) => !idsToRemove.contains(id))
          .toList();
      await prefs.setStringList(
        ChatEngineService._pendingReadIdsPrefsKey,
        updated,
      );
    } catch (_) {}
  }

  Future<void> _removePendingDeliveredIds(Set<String> idsToRemove) async {
    if (idsToRemove.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing =
          prefs.getStringList(ChatEngineService._pendingDeliveredIdsPrefsKey) ??
          <String>[];
      if (existing.isEmpty) return;
      final updated = existing
          .where((id) => !idsToRemove.contains(id))
          .toList();
      await prefs.setStringList(
        ChatEngineService._pendingDeliveredIdsPrefsKey,
        updated,
      );
    } catch (_) {}
  }

  Future<void> _flushPendingReadIds() async {
    if (_pendingReadFlushInProgress) return;
    _pendingReadFlushInProgress = true;
    try {
      const maxBatch = 200;
      const maxLoops = 5;
      for (var i = 0; i < maxLoops; i++) {
        final pending = await _getPendingReadIds();
        if (pending.isEmpty) return;

        final batch = pending.length > maxBatch
            ? pending.sublist(0, maxBatch)
            : pending;
        final ready = await _chatRepository.ensureSocketReady();
        if (!ready) return;
        final ok = await _chatRepository.updateMessageStatusBatch(
          messageIds: batch,
          status: 'read',
        );
        if (!ok) return;
        await _removePendingReadIds(batch.toSet());
      }
    } catch (_) {
    } finally {
      _pendingReadFlushInProgress = false;
    }
  }

  Future<void> _flushPendingDeliveredIds() async {
    if (_pendingDeliveredFlushInProgress) return;
    _pendingDeliveredFlushInProgress = true;
    try {
      const maxBatch = 200;
      const maxLoops = 5;
      for (var i = 0; i < maxLoops; i++) {
        final pending = await _getPendingDeliveredIds();
        if (pending.isEmpty) return;

        final batch = pending.length > maxBatch
            ? pending.sublist(0, maxBatch)
            : pending;

        final ok = await _markMessagesDeliveredViaRest(
          messageIds: batch,
          receiverDeliveryChannel: 'fcm',
        );
        if (!ok) return;
        await _removePendingDeliveredIds(batch.toSet());
      }
    } catch (_) {
    } finally {
      _pendingDeliveredFlushInProgress = false;
    }
  }
}
