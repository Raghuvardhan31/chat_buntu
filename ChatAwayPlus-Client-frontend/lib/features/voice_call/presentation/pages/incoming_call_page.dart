import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:chataway_plus/features/chat/data/socket/websocket_repository/websocket_chat_repository.dart';
import 'package:chataway_plus/features/voice_call/data/models/call_model.dart';
import 'package:chataway_plus/features/voice_call/data/services/call_signaling_service.dart';
import 'package:chataway_plus/features/voice_call/presentation/providers/call_provider.dart';
import 'package:chataway_plus/features/voice_call/presentation/widgets/call_avatar.dart';
import 'package:chataway_plus/features/voice_call/presentation/widgets/call_action_button.dart';
import 'package:chataway_plus/features/voice_call/presentation/pages/active_call_page.dart';
import 'package:chataway_plus/features/voice_call/presentation/pages/video_call_page.dart';


/// Full-screen incoming call page
/// Shown when a call is received — displays caller info with accept/reject buttons
/// Inspired by WhatsApp / iOS incoming call design
class IncomingCallPage extends ConsumerStatefulWidget {
  final String currentUserId; // Current user ID (callee)
  final String callId;
  final String callerId; // Who is calling
  final String contactName;
  final String? contactProfilePic;
  final CallType callType;
  final String channelName;

  const IncomingCallPage({
    super.key,
    required this.currentUserId,
    required this.callId,
    required this.callerId,
    required this.contactName,
    this.contactProfilePic,
    this.callType = CallType.voice,
    required this.channelName,
  });

  @override
  ConsumerState<IncomingCallPage> createState() => _IncomingCallPageState();
}

class _IncomingCallPageState extends ConsumerState<IncomingCallPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  Timer? _autoRejectTimer;
  StreamSubscription? _callEndedSub;
  StreamSubscription? _callMissedSub;
  StreamSubscription? _callAcceptedSub;
  StreamSubscription? _callRejectedSub;
  bool _handled = false;

  /// Auto-reject after 30 seconds (Requirement: 30s timeout)
  /// Auto-reject after 35 seconds (Safety margin: favor server-side 30s timeout)
  static const Duration _autoRejectTimeout = Duration(seconds: 35);

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();

    // Set up active call state so it gets recorded to history
    ref
        .read(callProvider)
        .registerIncomingCall(
          callId: widget.callId,
          contactId: widget.callerId,
          contactName: widget.contactName,
          contactProfilePic: widget.contactProfilePic,
          callType: widget.callType,
        );

    // Prepare socket/listeners so we can receive `call-ended` even while ringing
    _prepareSignalingWhileRinging();

    // Auto-reject after timeout (missed call)
    _autoRejectTimer = Timer(_autoRejectTimeout, () {
      if (!_handled && mounted) {
        _handled = true;
        ref.read(callProvider).endCallWithStatus(CallStatus.missed);
        Navigator.of(context).pop();
      }
    });

    // Listen for caller ending the call while we're ringing
    // Filter by callId to prevent stale events from other calls
    _callEndedSub = CallSignalingService.instance.callEndedStream.listen((
      callId,
    ) {
      if (callId == widget.callId && !_handled && mounted) {
        debugPrint('[CALL] incoming_page: call ended remotely');
        _handled = true;
        _autoRejectTimer?.cancel();
        ref.read(callProvider).endCallWithStatus(CallStatus.missed);
        Navigator.of(context).pop();
      }
    });

    // Listen for missed call signal (server timeout)
    _callMissedSub = CallSignalingService.instance.callMissedStream.listen((
      callId,
    ) {
      if (callId == widget.callId && !_handled && mounted) {
        debugPrint('[CALL] incoming_page: call missed (server timeout)');
        _handled = true;
        _autoRejectTimer?.cancel();
        ref.read(callProvider).endCallWithStatus(CallStatus.missed);
        Navigator.of(context).pop();
      }
    });

    // Listen for call accepted (e.g. by another device of same user)
    _callAcceptedSub = CallSignalingService.instance.callAcceptedStream.listen((
      data,
    ) {
      final callId = data['callId'];
      if (callId == widget.callId && !_handled && mounted) {
        debugPrint('[CALL] incoming_page: call accepted by another device');
        _handled = true;
        _autoRejectTimer?.cancel();
        // Just pop, don't update callProvider status as it was handled elsewhere
        Navigator.of(context).pop();
      }
    });

    // Listen for call rejected (e.g. by another device of same user)
    _callRejectedSub = CallSignalingService.instance.callRejectedStream.listen((
      callId,
    ) {
      if (callId == widget.callId && !_handled && mounted) {
        debugPrint('[CALL] incoming_page: call rejected remotely');
        _handled = true;
        _autoRejectTimer?.cancel();
        ref.read(callProvider).endCallWithStatus(CallStatus.missed);
        Navigator.of(context).pop();
      }
    });
  }

  Future<void> _prepareSignalingWhileRinging() async {
    try {
      final ready = await WebSocketChatRepository.instance.ensureSocketReady(
        timeout: const Duration(seconds: 8),
      );
      debugPrint(
        '📞 IncomingCallPage: ensureSocketReady while ringing = $ready',
      );
      CallSignalingService.instance.startListening();
    } catch (e) {
      debugPrint('❌ IncomingCallPage: prepare signaling failed: $e');
    }
  }

  @override
  void dispose() {
    _autoRejectTimer?.cancel();
    _callEndedSub?.cancel();
    _callMissedSub?.cancel();
    _callAcceptedSub?.cancel();
    _callRejectedSub?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayoutBuilder(
      builder: (context, constraints, breakpoint) {
        final responsive = ResponsiveSize(
          context: context,
          constraints: constraints,
          breakpoint: breakpoint,
        );

        return PopScope(
          // Block back navigation — user must accept or reject
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            // Do nothing — no back navigation during incoming call
          },
          child: Scaffold(
            resizeToAvoidBottomInset: false,
            body: Container(
              width: double.infinity,
              height: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF0F172A),
                    Color(0xFF1E293B),
                    Color(0xFF0F172A),
                  ],
                ),
              ),
              child: SafeArea(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
                    ),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        children: [
                          SizedBox(height: responsive.spacing(60)),
                          // Encrypted label
                          _buildEncryptedLabel(responsive),
                          SizedBox(height: responsive.spacing(40)),
                          // Avatar with ripple
                          CallAvatar(
                            name: widget.contactName,
                            profilePicUrl: widget.contactProfilePic,
                            size: 120,
                            showRipple: true,
                          ),
                          SizedBox(height: responsive.spacing(30)),
                          // Contact name
                          Text(
                            widget.contactName,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: responsive.size(28),
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(height: responsive.spacing(10)),
                          // Call type label
                          Text(
                            widget.callType == CallType.video
                                ? 'Incoming Video Call...'
                                : 'Incoming Voice Call...',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: responsive.size(16),
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          SizedBox(height: responsive.spacing(40)),
                          // Action buttons row — ONLY accept and reject
                          _buildActionButtons(responsive),
                          SizedBox(height: responsive.spacing(40)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEncryptedLabel(ResponsiveSize responsive) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.lock_rounded,
          color: Colors.white.withValues(alpha: 0.4),
          size: responsive.size(14),
        ),
        SizedBox(width: responsive.spacing(6)),
        Text(
          'End-to-end encrypted',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: responsive.size(12),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(ResponsiveSize responsive) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: responsive.spacing(60)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Reject
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RejectCallButton(onTap: _rejectCall),
              SizedBox(height: responsive.spacing(10)),
              Text(
                'Decline',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: responsive.size(13),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          // Accept
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AcceptCallButton(onTap: _acceptCall),
              SizedBox(height: responsive.spacing(10)),
              Text(
                'Accept',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: responsive.size(13),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _acceptCall() {
    _acceptCallAsync();
  }

  Future<void> _acceptCallAsync() async {
    if (_handled) return;
    _handled = true;
    _autoRejectTimer?.cancel();

    // Signal server that we accepted
    debugPrint(
      '📞 IncomingCallPage: Accept pressed for callId=${widget.callId}',
    );
    final ok = await CallSignalingService.instance.acceptIncomingCall(
      callId: widget.callId,
      callerId: widget.callerId,
      calleeId: widget.currentUserId, // Current user ID accepting the call
    );
    if (!ok) {
      debugPrint(
        '❌ IncomingCallPage: acceptIncomingCall failed; keeping incoming screen',
      );
      if (mounted) {
        _handled = false;
        _autoRejectTimer = Timer(_autoRejectTimeout, () {
          if (!_handled && mounted) {
            _handled = true;
            ref.read(callProvider).endCallWithStatus(CallStatus.missed);
            Navigator.of(context).pop();
          }
        });
      }
      return;
    }

    ref.read(callProvider).acceptCall();

    if (!mounted) return;
    
    // Navigate directly to the call page (skip JoinCallPage for seamless experience)
    final Widget callPage = widget.callType == CallType.video
        ? VideoCallPage(
            currentUserId: widget.currentUserId,
            contactName: widget.contactName,
            contactProfilePic: widget.contactProfilePic,
            channelName: widget.channelName,
            callId: widget.callId,
            otherUserId: widget.callerId,
          )
        : ActiveCallPage(
            currentUserId: widget.currentUserId,
            contactName: widget.contactName,
            contactProfilePic: widget.contactProfilePic,
            callType: widget.callType,
            channelName: widget.channelName,
            callId: widget.callId,
            otherUserId: widget.callerId,
          );

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => callPage,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  void _rejectCall() {
    _rejectCallAsync();
  }

  Future<void> _rejectCallAsync() async {
    if (_handled) return;
    _handled = true;
    _autoRejectTimer?.cancel();

    // Signal server that we rejected
    debugPrint(
      '📞 IncomingCallPage: Reject pressed for callId=${widget.callId}',
    );
    final ok = await CallSignalingService.instance.rejectIncomingCall(
      callId: widget.callId,
      callerId: widget.callerId,
    );
    if (!ok) {
      debugPrint(
        '❌ IncomingCallPage: rejectIncomingCall failed; keeping incoming screen',
      );
      if (mounted) {
        _handled = false;
        _autoRejectTimer = Timer(_autoRejectTimeout, () {
          if (!_handled && mounted) {
            _handled = true;
            ref.read(callProvider).endCallWithStatus(CallStatus.missed);
            Navigator.of(context).pop();
          }
        });
      }
      return;
    }

    ref.read(callProvider).rejectCall();
    if (mounted) Navigator.of(context).pop();
  }
}
