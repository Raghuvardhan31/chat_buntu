import 'dart:async';
import 'package:flutter/material.dart';
import 'package:chataway_plus/core/routes/navigation_service.dart';
import 'package:chataway_plus/core/storage/token_storage.dart';
import 'package:chataway_plus/features/contacts/data/datasources/contacts_database_service.dart';
import 'package:chataway_plus/features/contacts/utils/contact_display_name_helper.dart';
import 'package:chataway_plus/features/voice_call/data/services/call_signaling_service.dart';
import 'package:chataway_plus/features/voice_call/presentation/pages/incoming_call_page.dart';
import 'package:chataway_plus/features/chat/data/socket/websocket_repository/websocket_chat_repository.dart';

/// Global listener for incoming call signals
/// Initialized once after ChatEngineService connects
/// Shows IncomingCallPage as a full-screen overlay when a call comes in
///
/// **Reliability features:**
/// - Expiry validation: ignores incoming calls that have already expired
/// - Reconnect handling: re-registers userId in signaling room after reconnect
/// - Dedup: handled by CallSignalingService (processedIncomingCallIds)
class CallListenerService {
  CallListenerService._();
  static final CallListenerService instance = CallListenerService._();

  StreamSubscription? _incomingCallSub;
  StreamSubscription? _callEndedSub;
  bool _isListening = false;
  bool _isShowingIncomingCall = false;

  /// The callId currently being shown on the incoming call page
  String? _currentIncomingCallId;

  /// Start listening for incoming calls
  /// Call this after WebSocket is connected and authenticated
  void startListening() {
    if (_isListening) return;
    _isListening = true;

    // Ensure signaling service is listening for socket events
    CallSignalingService.instance.startListening();

    // Ensure user is in their signaling room
    _ensureSignalingRoom();

    // Listen for socket reconnections to re-register
    _setupReconnectHandler();

    _incomingCallSub = CallSignalingService.instance.incomingCallStream.listen((
      signal,
    ) {
      debugPrint(
        '[CALL] listener: Incoming from ${signal.callerName} '
        '(${signal.callType.name}) callId=${signal.callId}',
      );

      // ── Expiry guard ──
      if (signal.isExpired) {
        debugPrint('[CALL] listener: IGNORED stale/expired callId=${signal.callId}');
        return;
      }

      // ── Busy guard: already showing incoming call ──
      if (_isShowingIncomingCall) {
        debugPrint('[CALL] listener: Already showing incoming call, sending busy');
        CallSignalingService.instance.sendBusy(
          callId: signal.callId,
          callerId: signal.callerId,
        );
        return;
      }

      _showIncomingCallPage(signal);
    });

    // Listen for call:ended to dismiss any showing incoming call page
    // (handles case where caller cancels before callee acts)
    _callEndedSub = CallSignalingService.instance.callEndedStream.listen((callId) {
      if (_isShowingIncomingCall && _currentIncomingCallId == callId) {
        debugPrint('[CALL] listener: Call $callId ended while showing incoming — will be handled by IncomingCallPage');
      }
    });

    debugPrint('[CALL] listener: Started listening for incoming calls');
  }

  /// Ensure we're in our signaling room
  void _ensureSignalingRoom() {
    TokenSecureStorage.instance.getCurrentUserIdUUID().then((userId) {
      if (userId != null) {
        CallSignalingService.instance.joinSignalingRoom(userId);
      }
    });
  }

  /// Set up reconnect handler to re-register userId after socket reconnect
  void _setupReconnectHandler() {
    final socket = WebSocketChatRepository.instance.connectionManager.socket;
    if (socket == null) return;

    // socket.io-client fires 'connect' on reconnect
    socket.on('connect', (_) {
      debugPrint('[CALL] socket reconnect — re-registering signaling room');
      _ensureSignalingRoom();
      // Re-register listeners on new socket
      CallSignalingService.instance.restartListening();
    });
  }

  /// Show the incoming call page as a full-screen route
  /// Resolves the device contact name before showing the page.
  void _showIncomingCallPage(IncomingCallSignal signal) async {
    final navigator = NavigationService.navigatorKey.currentState;
    if (navigator == null) {
      debugPrint('[CALL] listener: Navigator is null, cannot show incoming call');
      return;
    }

    _isShowingIncomingCall = true;
    _currentIncomingCallId = signal.callId;

    // Get current user ID (callee)
    final currentUserId = await TokenSecureStorage.instance.getCurrentUserIdUUID() ?? '';

    // Resolve device contact name (prefer phone contact name over app name)
    String displayName = signal.callerName;
    try {
      final contacts = await ContactsDatabaseService.instance.loadFromCache();
      displayName = ContactDisplayNameHelper.resolveDisplayName(
        contacts: contacts,
        userId: signal.callerId,
        mobileNo: '',
        backendDisplayName: signal.callerName,
      );
    } catch (e) {
      debugPrint('[CALL] listener: Failed to resolve contact name: $e');
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navigator.mounted) {
        navigator
            .push(
              PageRouteBuilder(
                opaque: true,
                pageBuilder: (context, animation, secondaryAnimation) =>
                    IncomingCallPage(
                      currentUserId: currentUserId,
                      callId: signal.callId,
                      callerId: signal.callerId,
                      contactName: displayName,
                      contactProfilePic: signal.callerProfilePic,
                      callType: signal.callType,
                      channelName: signal.channelName,
                    ),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                transitionDuration: const Duration(milliseconds: 300),
              ),
            )
            .then((_) {
              _isShowingIncomingCall = false;
              _currentIncomingCallId = null;
            });
      } else {
        _isShowingIncomingCall = false;
        _currentIncomingCallId = null;
      }
    });
  }

  /// Handle incoming call from FCM push notification
  /// Called by FirebaseNotificationHandler when type == 'incoming_call'
  /// Uses the same IncomingCallPage as the socket path
  void handleFcmIncomingCall(IncomingCallSignal signal) {
    debugPrint(
      '[CALL] listener: FCM incoming from ${signal.callerName} '
      '(${signal.callType.name}) callId=${signal.callId}',
    );

    // Expiry guard
    if (signal.isExpired) {
      debugPrint('[CALL] listener: FCM incoming IGNORED — expired');
      return;
    }

    if (_isShowingIncomingCall) {
      debugPrint('[CALL] listener: Already showing incoming call, sending busy via FCM path');
      CallSignalingService.instance.sendBusy(
        callId: signal.callId,
        callerId: signal.callerId,
      );
      return;
    }

    _showIncomingCallPage(signal);
  }

  /// Stop listening for incoming calls
  void stopListening() {
    _incomingCallSub?.cancel();
    _incomingCallSub = null;
    _callEndedSub?.cancel();
    _callEndedSub = null;
    _isListening = false;
    _isShowingIncomingCall = false;
    _currentIncomingCallId = null;
    debugPrint('[CALL] listener: Stopped listening');
  }

  /// Dispose
  void dispose() {
    stopListening();
  }
}
