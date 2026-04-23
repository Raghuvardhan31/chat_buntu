import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chataway_plus/features/voice_call/data/models/call_model.dart';
import 'package:chataway_plus/features/voice_call/data/services/call_signaling_service.dart';
import 'package:chataway_plus/features/voice_call/data/datasources/call_history_local_datasource.dart';

/// State for the call history and active call management
@immutable
class CallState {
  final List<CallModel> callHistory;
  final ActiveCallState? activeCall;
  final bool isLoading;

  const CallState({
    this.callHistory = const [],
    this.activeCall,
    this.isLoading = false,
  });

  CallState copyWith({
    List<CallModel>? callHistory,
    ActiveCallState? activeCall,
    bool clearActiveCall = false,
    bool? isLoading,
  }) {
    return CallState(
      callHistory: callHistory ?? this.callHistory,
      activeCall: clearActiveCall ? null : (activeCall ?? this.activeCall),
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// Notifier for managing call state
/// Offline-first: saves all call records to local SQLite DB
class CallNotifier extends ChangeNotifier {
  CallState _state = const CallState();
  CallState get state => _state;

  final _localDb = CallHistoryLocalDatasource.instance;
  final List<StreamSubscription> _subscriptions = [];

  CallNotifier() {
    _initSignalingListeners();
  }

  void _initSignalingListeners() {
    // Listen for call accepted
    _subscriptions.add(
      CallSignalingService.instance.callAcceptedStream.listen((data) {
        if (_state.activeCall != null && _state.activeCall!.callId == data['callId']) {
          acceptCall();
        }
      })
    );

    // Listen for call rejected
    _subscriptions.add(
      CallSignalingService.instance.callRejectedStream.listen((callId) {
        if (_state.activeCall != null && _state.activeCall!.callId == callId) {
          endCallWithStatus(CallStatus.rejected);
        }
      })
    );

    // Listen for call ended
    _subscriptions.add(
      CallSignalingService.instance.callEndedStream.listen((callId) {
        if (_state.activeCall != null && _state.activeCall!.callId == callId) {
          endCallWithStatus(CallStatus.ended);
        }
      })
    );

    // Listen for unavailable
    _subscriptions.add(
      CallSignalingService.instance.callUnavailableStream.listen((callId) {
        if (_state.activeCall != null && _state.activeCall!.callId == callId) {
          endCallWithStatus(CallStatus.failed);
        }
      })
    );
  }

  @override
  void dispose() {
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    super.dispose();
  }

  /// Initiate an outgoing call
  Future<void> initiateCall({
    String? callId,
    required String contactId,
    required String contactName,
    String? contactProfilePic,
    CallType callType = CallType.voice,
  }) async {
    final effectiveCallId = (callId != null && callId.isNotEmpty)
        ? callId
        : 'call_${DateTime.now().millisecondsSinceEpoch}';
    
    final channelName = 'chan_${effectiveCallId}';

    _state = _state.copyWith(
      activeCall: ActiveCallState(
        callId: effectiveCallId,
        contactId: contactId,
        contactName: contactName,
        contactProfilePic: contactProfilePic,
        callType: callType,
        direction: CallDirection.outgoing,
        status: CallStatus.ringing,
        startTime: DateTime.now(),
      ),
    );
    notifyListeners();

    // 🚀 NEW: Actually tell the server to start the call!
    try {
      await CallSignalingService.instance.initiateCall(
        callId: effectiveCallId,
        calleeId: contactId,
        callType: callType,
        channelName: channelName,
      );
    } catch (e) {
      debugPrint('❌ CallNotifier: Failed to initiate call signal: $e');
      _state = _state.copyWith(clearActiveCall: true);
      notifyListeners();
    }
  }

  /// Register an incoming call (so it gets recorded to history)
  void registerIncomingCall({
    required String callId,
    required String contactId,
    required String contactName,
    String? contactProfilePic,
    CallType callType = CallType.voice,
  }) {
    _state = _state.copyWith(
      activeCall: ActiveCallState(
        callId: callId,
        contactId: contactId,
        contactName: contactName,
        contactProfilePic: contactProfilePic,
        callType: callType,
        direction: CallDirection.incoming,
        status: CallStatus.ringing,
        startTime: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  /// Accept an incoming call
  void acceptCall() {
    if (_state.activeCall == null) return;
    _state = _state.copyWith(
      activeCall: _state.activeCall!.copyWith(
        status: CallStatus.active,
        startTime: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  /// Reject an incoming call — records as rejected in history
  void rejectCall() {
    if (_state.activeCall == null) return;
    _addToHistory(_state.activeCall!, CallStatus.rejected);
    _state = _state.copyWith(clearActiveCall: true);
    notifyListeners();
  }

  /// End an active call and record it to history
  void endCall() {
    if (_state.activeCall == null) return;
    _addToHistory(_state.activeCall!, CallStatus.ended);
    _state = _state.copyWith(clearActiveCall: true);
    notifyListeners();
  }

  /// End call with a specific status (picked, missed, rejected, etc.)
  void endCallWithStatus(CallStatus status) {
    if (_state.activeCall == null) return;
    _addToHistory(_state.activeCall!, status);
    _state = _state.copyWith(clearActiveCall: true);
    notifyListeners();
  }

  /// Record a call to history (even without active call state)
  void recordCall(CallModel call) {
    final updated = [call, ..._state.callHistory];
    _state = _state.copyWith(callHistory: updated);
    notifyListeners();
    // Persist to local DB
    _localDb.saveCall(call);
  }

  /// Internal: add active call to history and persist to local DB
  void _addToHistory(ActiveCallState activeCall, CallStatus status) {
    final duration = status == CallStatus.ended || status == CallStatus.active
        ? DateTime.now().difference(activeCall.startTime).inSeconds
        : null;
    final call = CallModel(
      id: activeCall.callId,
      contactId: activeCall.contactId,
      contactName: activeCall.contactName,
      contactProfilePic: activeCall.contactProfilePic,
      callType: activeCall.callType,
      direction: activeCall.direction,
      status: status,
      timestamp: activeCall.startTime,
      durationSeconds: duration,
    );
    final updated = [call, ..._state.callHistory];
    _state = _state.copyWith(callHistory: updated);
    // Persist to local SQLite DB
    _localDb.saveCall(call);
  }

  /// Toggle mute
  void toggleMute() {
    if (_state.activeCall == null) return;
    _state = _state.copyWith(
      activeCall: _state.activeCall!.copyWith(
        isMuted: !_state.activeCall!.isMuted,
      ),
    );
    notifyListeners();
  }

  /// Toggle speaker
  void toggleSpeaker() {
    if (_state.activeCall == null) return;
    _state = _state.copyWith(
      activeCall: _state.activeCall!.copyWith(
        isSpeakerOn: !_state.activeCall!.isSpeakerOn,
      ),
    );
    notifyListeners();
  }

  /// Delete a call from history (memory + local DB)
  void deleteCall(String callId) {
    final updated = _state.callHistory.where((c) => c.id != callId).toList();
    _state = _state.copyWith(callHistory: updated);
    notifyListeners();
    _localDb.deleteCall(callId);
  }

  /// Clear all call history (memory + local DB)
  void clearCallHistory() {
    _state = _state.copyWith(callHistory: []);
    notifyListeners();
    _localDb.clearAll();
  }

  // ═══════════════════════════════════════════════════════════════════
  // OFFLINE-FIRST: Load from local DB, then optionally sync from server
  // ═══════════════════════════════════════════════════════════════════

  /// Load call history from local SQLite DB (offline-first, instant)
  Future<void> loadCallHistory() async {
    if (_state.isLoading) return;
    _state = _state.copyWith(isLoading: true);
    notifyListeners();

    try {
      final calls = await _localDb.getAllCalls(limit: 100);
      _state = _state.copyWith(callHistory: calls, isLoading: false);
      notifyListeners();
    } catch (e) {
      debugPrint('❌ CallNotifier: Failed to load local call history: $e');
      _state = _state.copyWith(isLoading: false);
      notifyListeners();
    }
  }

  /// Fetch call history from server and merge into local DB
  /// Called after loadCallHistory() for background sync
  Future<void> syncCallHistoryFromServer() async {
    StreamSubscription<List<CallHistoryEntry>>? sub;
    try {
      final completer = Completer<List<CallHistoryEntry>>();

      sub = CallSignalingService.instance.callHistoryStream.listen((entries) {
        if (!completer.isCompleted) completer.complete(entries);
      });

      await CallSignalingService.instance.fetchCallHistory(limit: 50);

      final entries = await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => <CallHistoryEntry>[],
      );

      if (entries.isEmpty) return;

      // Convert server entries to CallModel
      final serverCalls = entries.map((e) => _entryToCallModel(e)).toList();

      // Save to local DB (IGNORE duplicates — local is source of truth)
      await _localDb.saveCallsBatch(serverCalls);

      // Reload from local DB to get merged result
      final allCalls = await _localDb.getAllCalls(limit: 100);
      _state = _state.copyWith(callHistory: allCalls);
      notifyListeners();
    } catch (e) {
      debugPrint('❌ CallNotifier: Failed to sync server call history: $e');
    } finally {
      await sub?.cancel();
    }
  }

  /// Load from local DB first, then sync from server in background
  Future<void> loadCallHistoryFromServer() async {
    // Step 1: Load from local DB instantly (offline-first)
    await loadCallHistory();

    // Step 2: Background sync from server (non-blocking)
    syncCallHistoryFromServer();
  }

  /// Convert server CallHistoryEntry to local CallModel
  CallModel _entryToCallModel(CallHistoryEntry entry) {
    CallStatus status;
    switch (entry.status.toLowerCase()) {
      case 'missed':
        status = CallStatus.missed;
        break;
      case 'rejected':
        status = CallStatus.rejected;
        break;
      case 'failed':
      case 'unavailable':
        status = CallStatus.failed;
        break;
      case 'completed':
      case 'ended':
        status = CallStatus.ended;
        break;
      default:
        status = CallStatus.ended;
    }

    final direction = entry.direction.toLowerCase() == 'outgoing'
        ? CallDirection.outgoing
        : CallDirection.incoming;

    final callType = entry.callType.toLowerCase() == 'video'
        ? CallType.video
        : CallType.voice;

    return CallModel(
      id: entry.callId,
      contactId: entry.otherUser?.id ?? '',
      contactName: entry.otherUser?.fullName ?? 'Unknown',
      contactProfilePic: entry.otherUser?.chatPicture,
      callType: callType,
      direction: direction,
      status: status,
      timestamp: entry.startedAt ?? entry.createdAt,
      durationSeconds: entry.duration,
    );
  }
}

/// Global provider for call state
final callProvider = ChangeNotifierProvider<CallNotifier>((ref) {
  return CallNotifier();
});

/// Provider for call history list
final callHistoryProvider = Provider<List<CallModel>>((ref) {
  return ref.watch(callProvider).state.callHistory;
});

/// Provider for active call state
final activeCallProvider = Provider<ActiveCallState?>((ref) {
  return ref.watch(callProvider).state.activeCall;
});

/// Provider for call loading state
final callLoadingProvider = Provider<bool>((ref) {
  return ref.watch(callProvider).state.isLoading;
});
