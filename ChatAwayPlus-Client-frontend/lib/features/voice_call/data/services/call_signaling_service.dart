import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:chataway_plus/features/chat/data/socket/websocket_repository/websocket_chat_repository.dart';
import 'package:chataway_plus/features/voice_call/data/models/call_model.dart';

/// Socket event names for call signaling
class CallSocketEvents {
  CallSocketEvents._();

  // Client → Server (emit)
  static const String initiateCall = 'call:initiate';
  static const String acceptCall = 'call:accept';
  static const String rejectCall = 'call:reject';
  static const String endCall = 'call:end';
  static const String callBusy = 'call:busy';
  static const String incomingAck = 'call:incoming_ack';
  static const String callState = 'call:state';

  // Server → Client (listen)
  static const String incomingCall = 'call:incoming';
  static const String callAccepted = 'call:accepted';
  static const String callRejected = 'call:rejected';
  static const String callEnded = 'call:ended';
  static const String callUnavailable = 'call:unavailable';
  static const String callRinging = 'call:ringing';
  static const String callError = 'call:error';
  static const String callMissed = 'call:missed';
  static const String callStateResponse = 'call:state_response';

  // Call history & statistics (emit → listen)
  static const String getCallHistory = 'get-call-history';
  static const String callHistoryResponse = 'call-history-response';
  static const String callHistoryError = 'call-history-error';
  static const String getMissedCallsCount = 'get-missed-calls-count';
  static const String missedCallsCountResponse = 'missed-calls-count-response';
  static const String missedCallsCountError = 'missed-calls-count-error';
  static const String getCallStatistics = 'get-call-statistics';
  static const String callStatisticsResponse = 'call-statistics-response';
  static const String callStatisticsError = 'call-statistics-error';
}

/// Call history entry from server
@immutable
class CallHistoryEntry {
  final String id;
  final String callId;
  final String callType;
  final String status;
  final String direction;
  final CallHistoryUser? otherUser;
  final DateTime? startedAt;
  final DateTime? answeredAt;
  final DateTime? endedAt;
  final int? duration;
  final DateTime createdAt;

  const CallHistoryEntry({
    required this.id,
    required this.callId,
    required this.callType,
    required this.status,
    required this.direction,
    this.otherUser,
    this.startedAt,
    this.answeredAt,
    this.endedAt,
    this.duration,
    required this.createdAt,
  });

  factory CallHistoryEntry.fromJson(Map<String, dynamic> json) {
    return CallHistoryEntry(
      id: (json['id'] ?? '').toString(),
      callId: (json['callId'] ?? '').toString(),
      callType: (json['callType'] ?? 'voice').toString(),
      status: (json['status'] ?? '').toString(),
      direction: (json['direction'] ?? '').toString(),
      otherUser: json['otherUser'] is Map
          ? CallHistoryUser.fromJson(
              Map<String, dynamic>.from(json['otherUser']),
            )
          : null,
      startedAt: json['startedAt'] != null
          ? DateTime.tryParse(json['startedAt'].toString())
          : null,
      answeredAt: json['answeredAt'] != null
          ? DateTime.tryParse(json['answeredAt'].toString())
          : null,
      endedAt: json['endedAt'] != null
          ? DateTime.tryParse(json['endedAt'].toString())
          : null,
      duration: json['duration'] as int?,
      createdAt:
          DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}

/// User info in call history
@immutable
class CallHistoryUser {
  final String id;
  final String firstName;
  final String lastName;
  final String? chatPicture;
  final String? mobileNo;

  const CallHistoryUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.chatPicture,
    this.mobileNo,
  });

  factory CallHistoryUser.fromJson(Map<String, dynamic> json) {
    return CallHistoryUser(
      id: (json['id'] ?? '').toString(),
      firstName: (json['firstName'] ?? '').toString(),
      lastName: (json['lastName'] ?? '').toString(),
      chatPicture: json['chat_picture'] as String?,
      mobileNo: json['mobileNo'] as String?,
    );
  }

  String get fullName => '$firstName $lastName'.trim();
}

/// Call statistics from server
@immutable
class CallStatistics {
  final int totalCalls;
  final int voiceCalls;
  final int videoCalls;
  final int incomingCalls;
  final int outgoingCalls;
  final int missedCalls;
  final int answeredCalls;
  final int rejectedCalls;
  final int totalDuration;
  final int averageDuration;

  const CallStatistics({
    this.totalCalls = 0,
    this.voiceCalls = 0,
    this.videoCalls = 0,
    this.incomingCalls = 0,
    this.outgoingCalls = 0,
    this.missedCalls = 0,
    this.answeredCalls = 0,
    this.rejectedCalls = 0,
    this.totalDuration = 0,
    this.averageDuration = 0,
  });

  factory CallStatistics.fromJson(Map<String, dynamic> json) {
    return CallStatistics(
      totalCalls: json['totalCalls'] as int? ?? 0,
      voiceCalls: json['voiceCalls'] as int? ?? 0,
      videoCalls: json['videoCalls'] as int? ?? 0,
      incomingCalls: json['incomingCalls'] as int? ?? 0,
      outgoingCalls: json['outgoingCalls'] as int? ?? 0,
      missedCalls: json['missedCalls'] as int? ?? 0,
      answeredCalls: json['answeredCalls'] as int? ?? 0,
      rejectedCalls: json['rejectedCalls'] as int? ?? 0,
      totalDuration: json['totalDuration'] as int? ?? 0,
      averageDuration: json['averageDuration'] as int? ?? 0,
    );
  }
}

/// Represents an incoming call signal from the server
/// Now includes createdAt/expiresAt for expiry checking
@immutable
class IncomingCallSignal {
  final String callId;
  final String callerId;
  final String callerName;
  final String? callerProfilePic;
  final CallType callType;
  final String channelName;
  final int? createdAt;   // Unix timestamp ms from server
  final int? expiresAt;   // Unix timestamp ms from server

  const IncomingCallSignal({
    required this.callId,
    required this.callerId,
    required this.callerName,
    this.callerProfilePic,
    required this.callType,
    required this.channelName,
    this.createdAt,
    this.expiresAt,
  });

  factory IncomingCallSignal.fromJson(Map<String, dynamic> json) {
    return IncomingCallSignal(
      callId: (json['callId'] ?? '').toString(),
      callerId: (json['callerId'] ?? '').toString(),
      callerName: (json['callerName'] ?? 'Unknown').toString(),
      callerProfilePic: json['callerProfilePic'] as String?,
      callType: (json['callType'] ?? '') == 'video'
          ? CallType.video
          : CallType.voice,
      channelName: (json['channelName'] ?? '').toString(),
      createdAt: json['createdAt'] as int?,
      expiresAt: json['expiresAt'] as int?,
    );
  }

  /// Check if this call invite has expired
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().millisecondsSinceEpoch > expiresAt!;
  }
}

/// Call signaling service — handles WebSocket call events
/// WhatsApp-style: Signal first, then join Agora channel only after accept
class CallSignalingService {
  CallSignalingService._();
  static final CallSignalingService instance = CallSignalingService._();

  final WebSocketChatRepository _socketRepo = WebSocketChatRepository.instance;

  bool _isListening = false;

  /// Track which socket instance we registered listeners on
  /// so we can detect reconnection and re-register
  Object? _registeredSocket;

  // Stream controllers for call events
  final _incomingCallController =
      StreamController<IncomingCallSignal>.broadcast();
  final _callAcceptedController =
      StreamController<Map<String, String?>>.broadcast();
  final _callRejectedController = StreamController<String>.broadcast();
  final _callEndedController = StreamController<String>.broadcast();
  final _callUnavailableController = StreamController<String>.broadcast();
  final _callRingingController =
      StreamController<Map<String, String?>>.broadcast();
  final _callErrorController = StreamController<String>.broadcast();
  final _callMissedController = StreamController<String>.broadcast();

  // Call history & statistics stream controllers
  final _callHistoryController =
      StreamController<List<CallHistoryEntry>>.broadcast();
  final _missedCallsCountController = StreamController<int>.broadcast();
  final _callStatisticsController =
      StreamController<CallStatistics>.broadcast();

  // Public streams
  Stream<IncomingCallSignal> get incomingCallStream =>
      _incomingCallController.stream;
  Stream<Map<String, String?>> get callAcceptedStream =>
      _callAcceptedController.stream;
  Stream<String> get callRejectedStream => _callRejectedController.stream;
  Stream<String> get callEndedStream => _callEndedController.stream;
  Stream<String> get callUnavailableStream => _callUnavailableController.stream;
  Stream<Map<String, String?>> get callRingingStream =>
      _callRingingController.stream;
  Stream<String> get callErrorStream => _callErrorController.stream;
  Stream<String> get callMissedStream => _callMissedController.stream;
  Stream<List<CallHistoryEntry>> get callHistoryStream =>
      _callHistoryController.stream;
  Stream<int> get missedCallsCountStream => _missedCallsCountController.stream;
  Stream<CallStatistics> get callStatisticsStream =>
      _callStatisticsController.stream;

  /// Set of callIds we've already processed — prevents duplicate handling
  /// of the same incoming call (e.g. from server retries)
  final Set<String> _processedIncomingCallIds = {};

  /// Re-register listeners (e.g. after socket reconnection)
  void restartListening() {
    stopListening();
    startListening();
  }

  /// Initialize call signaling listeners on the existing WebSocket
  void startListening() {
    final socket = _socketRepo.connectionManager.socket;
    if (socket == null) {
      debugPrint('[CALL] signaling: Socket is null, cannot start listening');
      _isListening = false;
      _registeredSocket = null;
      return;
    }

    // If already listening on the SAME socket instance, skip
    if (_isListening && identical(socket, _registeredSocket)) {
      return;
    }

    // If listening on a DIFFERENT (old/dead) socket, clean up first
    if (_isListening && _registeredSocket != null) {
      debugPrint('[CALL] signaling: Socket changed, re-registering listeners');
      _removeListenersFromSocket();
    }

    _isListening = true;
    _registeredSocket = socket;

    debugPrint('[CALL] signaling: Registering listeners on socket ${socket.hashCode}');

    // ── Incoming call from another user ──
    socket.on(CallSocketEvents.incomingCall, (data) {
      debugPrint('[CALL] incoming received: $data');
      try {
        final signal = IncomingCallSignal.fromJson(
          data is Map ? Map<String, dynamic>.from(data) : {},
        );

        // ── Dedup guard: ignore if already processed ──
        if (_processedIncomingCallIds.contains(signal.callId)) {
          debugPrint('[CALL] incoming IGNORED — already processed callId=${signal.callId}');
          _sendIncomingAck(signal.callId);
          return;
        }

        // ── Expiry guard: reject expired invites ──
        if (signal.isExpired) {
          debugPrint('[CALL] incoming IGNORED — expired callId=${signal.callId}');
          _sendIncomingAck(signal.callId);
          return;
        }

        // Mark as processed immediately
        _processedIncomingCallIds.add(signal.callId);

        // Send ack to server immediately to stop retries
        _sendIncomingAck(signal.callId);

        // Forward to listeners
        _incomingCallController.add(signal);
      } catch (e) {
        debugPrint('[CALL] incoming parse error: $e');
      }
    });

    // ── Call accepted (by us or peer) ──
    socket.on(CallSocketEvents.callAccepted, (data) {
      debugPrint('[CALL] accepted received: $data');
      final callId = _extractCallId(data);
      if (callId.isNotEmpty) {
        _processedIncomingCallIds.add(callId);
        _callAcceptedController.add({
          'callId': callId,
          'channelName': (data is Map ? data['channelName'] : null)?.toString(),
        });
      }
    });

    // ── Call rejected (by us or peer) ──
    socket.on(CallSocketEvents.callRejected, (data) {
      debugPrint('[CALL] rejected received: $data');
      final callId = _extractCallId(data);
      if (callId.isNotEmpty) {
        _processedIncomingCallIds.add(callId);
        _callRejectedController.add(callId);
      }
    });

    // ── Call ended (by us or peer) ──
    socket.on(CallSocketEvents.callEnded, (data) {
      debugPrint('[CALL] ended received: $data');
      final callId = _extractCallId(data);
      if (callId.isNotEmpty) {
        _processedIncomingCallIds.add(callId);
        _callEndedController.add(callId);
      }
    });

    // ── Callee is unavailable (offline) ──
    socket.on(CallSocketEvents.callUnavailable, (data) {
      debugPrint('[CALL] unavailable received: $data');
      final callId = _extractCallId(data);
      _callUnavailableController.add(callId);
    });

    // ── Server confirms callee's phone is ringing ──
    socket.on(CallSocketEvents.callRinging, (data) {
      debugPrint('[CALL] ringing received: $data');
      final callId = _extractCallId(data);
      _callRingingController.add({'callId': callId});
    });

    // ── Call error from server ──
    socket.on(CallSocketEvents.callError, (data) {
      debugPrint('[CALL] error received: $data');
      final message = _extractMessage(data);
      _callErrorController.add(message);
    });

    // ── Call was missed (timeout on server side) ──
    socket.on(CallSocketEvents.callMissed, (data) {
      debugPrint('[CALL] missed received: $data');
      final callId = _extractCallId(data);
      if (callId.isNotEmpty) {
        _processedIncomingCallIds.add(callId);
        _callMissedController.add(callId);
      }
    });

    // ── Call history response ──
    socket.on(CallSocketEvents.callHistoryResponse, (data) {
      debugPrint('[CALL] history received');
      try {
        final map = data is Map
            ? Map<String, dynamic>.from(data)
            : <String, dynamic>{};
        if (map['success'] == true && map['data'] is List) {
          final entries = (map['data'] as List)
              .map(
                (e) => CallHistoryEntry.fromJson(
                  e is Map ? Map<String, dynamic>.from(e) : {},
                ),
              )
              .toList();
          _callHistoryController.add(entries);
        }
      } catch (e) {
        debugPrint('[CALL] history parse error: $e');
      }
    });

    // ── Missed calls count response ──
    socket.on(CallSocketEvents.missedCallsCountResponse, (data) {
      try {
        final map = data is Map
            ? Map<String, dynamic>.from(data)
            : <String, dynamic>{};
        if (map['success'] == true) {
          _missedCallsCountController.add(map['count'] as int? ?? 0);
        }
      } catch (e) {
        debugPrint('[CALL] missed count parse error: $e');
      }
    });

    // ── Call statistics response ──
    socket.on(CallSocketEvents.callStatisticsResponse, (data) {
      try {
        final map = data is Map
            ? Map<String, dynamic>.from(data)
            : <String, dynamic>{};
        if (map['success'] == true && map['data'] is Map) {
          final stats = CallStatistics.fromJson(
            Map<String, dynamic>.from(map['data']),
          );
          _callStatisticsController.add(stats);
        }
      } catch (e) {
        debugPrint('[CALL] statistics parse error: $e');
      }
    });

    debugPrint('[CALL] signaling: All listeners registered');
  }

  /// Send incoming_ack to server so it stops retrying
  void _sendIncomingAck(String callId) {
    final socket = _socketRepo.connectionManager.socket;
    if (socket == null) return;
    socket.emit(CallSocketEvents.incomingAck, {'callId': callId});
    debugPrint('[CALL] incoming ack sent for callId=$callId');
  }

  /// Remove listeners from the current/registered socket without resetting state
  void _removeListenersFromSocket() {
    final socket = _socketRepo.connectionManager.socket;
    if (socket == null) return;

    try {
      socket.off(CallSocketEvents.incomingCall);
      socket.off(CallSocketEvents.callAccepted);
      socket.off(CallSocketEvents.callRejected);
      socket.off(CallSocketEvents.callEnded);
      socket.off(CallSocketEvents.callUnavailable);
      socket.off(CallSocketEvents.callRinging);
      socket.off(CallSocketEvents.callError);
      socket.off(CallSocketEvents.callMissed);
      socket.off(CallSocketEvents.callHistoryResponse);
      socket.off(CallSocketEvents.missedCallsCountResponse);
      socket.off(CallSocketEvents.callStatisticsResponse);
    } catch (_) {}
  }

  /// Stop listening for call events
  void stopListening() {
    if (!_isListening) return;

    _removeListenersFromSocket();
    _isListening = false;
    _registeredSocket = null;

    debugPrint('[CALL] signaling: Listeners removed');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // EMIT EVENTS (Client → Server)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Initiate a call to another user
  /// Server will signal the callee and return ringing/unavailable/error
  Future<void> initiateCall({
    required String callId,
    required String callerId,
    required String calleeId,
    required CallType callType,
    required String channelName,
    String? callerName,
    String? callerProfilePic,
  }) async {
    final ready = await _socketRepo.ensureSocketReady(
      timeout: const Duration(seconds: 8),
    );
    if (!ready) {
      debugPrint('[CALL] initiate FAILED — socket not ready');
      _callErrorController.add('Not connected to server. Please try again.');
      return;
    }

    final socket = _socketRepo.connectionManager.socket;
    if (socket == null || !_socketRepo.isConnected) {
      debugPrint('[CALL] initiate FAILED — socket not connected');
      _callErrorController.add('Not connected to server');
      return;
    }

    // Ensure listeners are active
    startListening();

    debugPrint('[CALL] initiate callId=$callId from=$callerId to=$calleeId type=${callType.name} channel=$channelName');

    socket.emit(CallSocketEvents.initiateCall, {
      'callId': callId,
      'callerId': callerId,
      'calleeId': calleeId,
      'callType': callType.name,
      'channelName': channelName,
      'callerName': callerName,
      'callerProfilePic': callerProfilePic,
    });
  }

  /// Join the signaling room with user ID (Required for receiving calls)
  void joinSignalingRoom(String userId) {
    final socket = _socketRepo.connectionManager.socket;
    if (socket == null || !_socketRepo.isConnected) return;
    debugPrint('[CALL] socket reconnect user registered userId=$userId');
    socket.emit('join', userId);
  }

  /// Accept an incoming call
  Future<bool> acceptIncomingCall({
    required String callId,
    required String callerId,
    required String calleeId,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final ready = await _socketRepo.ensureSocketReady(timeout: timeout);
    if (!ready) {
      debugPrint('[CALL] accept FAILED — socket not ready');
      return false;
    }

    startListening();

    final socket = _socketRepo.connectionManager.socket;
    if (socket == null || !_socketRepo.isConnected) {
      debugPrint('[CALL] accept FAILED — socket not connected');
      return false;
    }

    debugPrint('[CALL] accepted callId=$callId callerId=$callerId calleeId=$calleeId');
    socket.emit(CallSocketEvents.acceptCall, {
      'callId': callId,
      'callerId': callerId,
      'calleeId': calleeId,
    });
    return true;
  }

  /// Reject an incoming call
  Future<bool> rejectIncomingCall({
    required String callId,
    required String callerId,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final ready = await _socketRepo.ensureSocketReady(timeout: timeout);
    if (!ready) {
      debugPrint('[CALL] reject FAILED — socket not ready');
      return false;
    }

    startListening();

    final socket = _socketRepo.connectionManager.socket;
    if (socket == null || !_socketRepo.isConnected) {
      debugPrint('[CALL] reject FAILED — socket not connected');
      return false;
    }

    debugPrint('[CALL] rejected callId=$callId callerId=$callerId');
    socket.emit(CallSocketEvents.rejectCall, {
      'callId': callId,
      'callerId': callerId,
    });
    return true;
  }

  /// End an active call
  Future<bool> endActiveCall({
    required String callId,
    required String otherUserId,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final ready = await _socketRepo.ensureSocketReady(timeout: timeout);
    if (!ready) {
      debugPrint('[CALL] end FAILED — socket not ready');
      return false;
    }

    startListening();

    final socket = _socketRepo.connectionManager.socket;
    if (socket == null || !_socketRepo.isConnected) {
      debugPrint('[CALL] end FAILED — socket not connected');
      return false;
    }

    debugPrint('[CALL] ended callId=$callId otherUserId=$otherUserId');
    socket.emit(CallSocketEvents.endCall, {
      'callId': callId,
      'otherUserId': otherUserId,
    });
    return true;
  }

  /// Signal that we're busy (already in a call)
  void sendBusy({required String callId, required String callerId}) {
    final socket = _socketRepo.connectionManager.socket;
    if (socket == null || !_socketRepo.isConnected) return;

    debugPrint('[CALL] busy sent callId=$callId callerId=$callerId');

    socket.emit(CallSocketEvents.callBusy, {
      'callId': callId,
      'callerId': callerId,
    });
  }

  /// Query the server for current active call state (for reconnection recovery)
  Future<Map<String, dynamic>?> queryCallState(String userId) async {
    final ready = await _socketRepo.ensureSocketReady(
      timeout: const Duration(seconds: 5),
    );
    if (!ready) return null;

    final socket = _socketRepo.connectionManager.socket;
    if (socket == null || !_socketRepo.isConnected) return null;

    final completer = Completer<Map<String, dynamic>?>();

    // Listen for one-time response
    void handler(dynamic data) {
      if (completer.isCompleted) return;
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        final activeCall = map['activeCall'];
        if (activeCall != null && activeCall is Map) {
          completer.complete(Map<String, dynamic>.from(activeCall));
        } else {
          completer.complete(null);
        }
      } else {
        completer.complete(null);
      }
    }

    socket.on(CallSocketEvents.callStateResponse, handler);
    socket.emit(CallSocketEvents.callState, {'userId': userId});

    try {
      final result = await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => null,
      );
      return result;
    } finally {
      socket.off(CallSocketEvents.callStateResponse, handler);
    }
  }

  /// Clear the processed incoming call IDs cache
  /// Call this periodically or when the user is in idle state
  void clearProcessedCallIds() {
    _processedIncomingCallIds.clear();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  String _extractCallId(dynamic data) {
    if (data is Map) {
      return (data['callId'] ?? '').toString();
    }
    return data?.toString() ?? '';
  }

  String _extractMessage(dynamic data) {
    if (data is Map) {
      return (data['message'] ?? data['error'] ?? 'Unknown error').toString();
    }
    return data?.toString() ?? 'Unknown error';
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CALL HISTORY & STATISTICS (Client → Server)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Fetch call history from server
  Future<void> fetchCallHistory({
    int limit = 50,
    int offset = 0,
    String? callType,
    String? status,
  }) async {
    final ready = await _socketRepo.ensureSocketReady(
      timeout: const Duration(seconds: 8),
    );
    if (!ready) return;

    final socket = _socketRepo.connectionManager.socket;
    if (socket == null || !_socketRepo.isConnected) return;

    if (!_isListening) startListening();

    debugPrint('[CALL] fetching history (limit=$limit, offset=$offset)');

    final payload = <String, dynamic>{'limit': limit, 'offset': offset};
    if (callType != null) payload['callType'] = callType;
    if (status != null) payload['status'] = status;

    socket.emit(CallSocketEvents.getCallHistory, payload);
  }

  /// Fetch missed calls count from server
  Future<void> fetchMissedCallsCount() async {
    final ready = await _socketRepo.ensureSocketReady(
      timeout: const Duration(seconds: 8),
    );
    if (!ready) return;

    final socket = _socketRepo.connectionManager.socket;
    if (socket == null || !_socketRepo.isConnected) return;

    if (!_isListening) startListening();

    socket.emit(CallSocketEvents.getMissedCallsCount);
  }

  /// Fetch call statistics from server
  void fetchCallStatistics({String? startDate, String? endDate}) {
    final socket = _socketRepo.connectionManager.socket;
    if (socket == null || !_socketRepo.isConnected) return;

    final payload = <String, dynamic>{};
    if (startDate != null) payload['startDate'] = startDate;
    if (endDate != null) payload['endDate'] = endDate;

    socket.emit(CallSocketEvents.getCallStatistics, payload);
  }

  /// Dispose all stream controllers
  void dispose() {
    stopListening();
    _incomingCallController.close();
    _callAcceptedController.close();
    _callRejectedController.close();
    _callEndedController.close();
    _callUnavailableController.close();
    _callRingingController.close();
    _callErrorController.close();
    _callMissedController.close();
    _callHistoryController.close();
    _missedCallsCountController.close();
    _callStatisticsController.close();
  }
}
