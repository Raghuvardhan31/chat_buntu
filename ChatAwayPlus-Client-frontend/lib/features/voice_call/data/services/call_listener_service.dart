import 'dart:async';
import 'package:flutter/material.dart';
import 'package:chataway_plus/core/routes/navigation_service.dart';
import 'package:chataway_plus/core/storage/token_storage.dart';
import 'package:chataway_plus/features/contacts/data/datasources/contacts_database_service.dart';
import 'package:chataway_plus/features/contacts/utils/contact_display_name_helper.dart';
import 'package:chataway_plus/features/voice_call/data/services/call_signaling_service.dart';
import 'package:chataway_plus/features/voice_call/presentation/pages/incoming_call_page.dart';

/// Global listener for incoming call signals
/// Initialized once after ChatEngineService connects
/// Shows IncomingCallPage as a full-screen overlay when a call comes in
class CallListenerService {
  CallListenerService._();
  static final CallListenerService instance = CallListenerService._();

  StreamSubscription? _incomingCallSub;
  bool _isListening = false;
  bool _isShowingIncomingCall = false;

  /// Start listening for incoming calls
  /// Call this after WebSocket is connected and authenticated
  void startListening() {
    if (_isListening) return;
    _isListening = true;

    // Ensure signaling service is listening for socket events
    CallSignalingService.instance.startListening();

    _incomingCallSub = CallSignalingService.instance.incomingCallStream.listen((
      signal,
    ) {
      debugPrint(
        '📞 CallListener: Incoming call from ${signal.callerName} '
        '(${signal.callType.name}) callId=${signal.callId}',
      );

      // Prevent multiple incoming call screens
      if (_isShowingIncomingCall) {
        debugPrint(
          '📞 CallListener: Already showing incoming call, sending busy',
        );
        CallSignalingService.instance.sendBusy(
          callId: signal.callId,
          callerId: signal.callerId,
        );
        return;
      }

      _showIncomingCallPage(signal);
    });

    debugPrint('✅ CallListener: Listening for incoming calls');
  }

  /// Show the incoming call page as a full-screen route
  /// Resolves the device contact name before showing the page.
  void _showIncomingCallPage(IncomingCallSignal signal) async {
    final navigator = NavigationService.navigatorKey.currentState;
    if (navigator == null) {
      debugPrint(
        '❌ CallListener: Navigator is null, cannot show incoming call',
      );
      return;
    }

    _isShowingIncomingCall = true;

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
      debugPrint('⚠️ CallListener: Failed to resolve contact name: $e');
    }

    navigator
        .push(
          PageRouteBuilder(
            opaque: true,
            pageBuilder: (context, animation, secondaryAnimation) =>
                IncomingCallPage(
                  currentUserId: currentUserId, // Current user ID (callee)
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
        });
  }

  /// Handle incoming call from FCM push notification
  /// Called by FirebaseNotificationHandler when type == 'incoming_call'
  /// Uses the same IncomingCallPage as the socket path
  void handleFcmIncomingCall(IncomingCallSignal signal) {
    debugPrint(
      '📞 CallListener: FCM incoming call from ${signal.callerName} '
      '(${signal.callType.name}) callId=${signal.callId}',
    );

    if (_isShowingIncomingCall) {
      debugPrint(
        '📞 CallListener: Already showing incoming call, sending busy via FCM path',
      );
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
    _isListening = false;
    _isShowingIncomingCall = false;
    debugPrint('📴 CallListener: Stopped listening');
  }

  /// Dispose
  void dispose() {
    stopListening();
  }
}
