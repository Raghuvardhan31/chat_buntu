import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:chataway_plus/core/connectivity/connectivity_service.dart';
import 'package:chataway_plus/features/voice_call/data/models/call_model.dart';
import 'package:chataway_plus/features/voice_call/data/services/call_signaling_service.dart';
import 'package:chataway_plus/features/voice_call/data/config/agora_config.dart';
import 'package:chataway_plus/features/voice_call/presentation/providers/call_provider.dart';
import 'package:chataway_plus/features/voice_call/presentation/widgets/call_avatar.dart';
import 'package:chataway_plus/features/voice_call/presentation/widgets/call_action_button.dart';
import 'package:chataway_plus/features/voice_call/presentation/pages/active_call_page.dart';
import 'package:chataway_plus/features/voice_call/presentation/pages/video_call_page.dart';

/// Outgoing call page — shown to the CALLER after initiating a call
/// WhatsApp-style: Shows "Calling..." → "Ringing..." → transitions to ActiveCallPage
/// Handles: offline, unavailable, rejected, timeout (45s), and accepted scenarios
class OutgoingCallPage extends ConsumerStatefulWidget {
  final String currentUserId; // Current user ID
  final String contactId; // Target user ID
  final String contactName;
  final String? contactProfilePic;
  final CallType callType;
  final String channelName;
  final String callId;

  const OutgoingCallPage({
    super.key,
    required this.currentUserId,
    required this.contactId,
    required this.contactName,
    this.contactProfilePic,
    this.callType = CallType.voice,
    required this.channelName,
    required this.callId,
  });

  @override
  ConsumerState<OutgoingCallPage> createState() => _OutgoingCallPageState();
}

class _OutgoingCallPageState extends ConsumerState<OutgoingCallPage>
    with SingleTickerProviderStateMixin {
  final _signaling = CallSignalingService.instance;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  String _callStatus = 'Calling...';
  bool _isEnded = false;
  Timer? _ringTimeoutTimer;

  // Stream subscriptions
  StreamSubscription? _ringSub;
  StreamSubscription? _acceptSub;
  StreamSubscription? _rejectSub;
  StreamSubscription? _endSub;
  StreamSubscription? _unavailableSub;
  StreamSubscription? _errorSub;
  StreamSubscription? _missedSub;

  /// Ring timeout — WhatsApp uses ~45 seconds
  static const Duration _ringTimeout = Duration(seconds: 45);

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();

    _startCall();
  }

  void _startCall() {
    // Check connectivity first
    if (!ConnectivityCache.instance.isOnline) {
      setState(() => _callStatus = 'No internet connection');
      _scheduleAutoClose(CallStatus.failed);
      return;
    }

    // Register outgoing call in provider so history tracking uses the same callId
    ref
        .read(callProvider)
        .initiateCall(
          callId: widget.callId,
          contactId: widget.contactId,
          contactName: widget.contactName,
          contactProfilePic: widget.contactProfilePic,
          callType: widget.callType,
        );

    // Listen for signaling events
    _ringSub = _signaling.callRingingStream.listen((data) {
      final callId = data['callId'] ?? '';
      if (callId == widget.callId && mounted) {
        setState(() => _callStatus = 'Ringing...');
      }
    });

    _acceptSub = _signaling.callAcceptedStream.listen((data) {
      final callId = data['callId'] ?? '';
      debugPrint(
        '📞 OutgoingCall: call-accepted received: callId=$callId, widgetCallId=${widget.callId}',
      );
      if (callId == widget.callId && mounted) {
        debugPrint(
          '📞 OutgoingCall: Transitioning to ActiveCallPage',
        );
        _onCallAccepted();
      }
    });

    _rejectSub = _signaling.callRejectedStream.listen((callId) {
      if (callId == widget.callId && mounted) {
        setState(() => _callStatus = 'Call declined');
        _scheduleAutoClose(CallStatus.rejected);
      }
    });

    _endSub = _signaling.callEndedStream.listen((callId) {
      if (callId == widget.callId && mounted) {
        setState(() => _callStatus = 'Call ended');
        _scheduleAutoClose(CallStatus.ended);
      }
    });

    _unavailableSub = _signaling.callUnavailableStream.listen((callId) {
      if (callId == widget.callId && mounted) {
        setState(() => _callStatus = 'Unavailable');
        _scheduleAutoClose(CallStatus.failed);
      }
    });

    _errorSub = _signaling.callErrorStream.listen((message) {
      if (mounted) {
        setState(() => _callStatus = message);
        _scheduleAutoClose(CallStatus.failed);
      }
    });

    _missedSub = _signaling.callMissedStream.listen((callId) {
      if (callId == widget.callId && mounted) {
        setState(() => _callStatus = 'No answer');
        _scheduleAutoClose(CallStatus.missed);
      }
    });

    // Send call signal to server with proper user IDs
    _signaling.initiateCall(
      callId: widget.callId,
      callerId: widget.currentUserId, // Current user ID
      calleeId: widget.contactId, // Target user ID
      callType: widget.callType,
      channelName: widget.channelName,
    );

    // Start ring timeout (45 seconds)
    _ringTimeoutTimer = Timer(_ringTimeout, () {
      if (!_isEnded && mounted) {
        debugPrint(
          '⏰ OutgoingCall: Ring timeout after ${_ringTimeout.inSeconds}s',
        );
        setState(() => _callStatus = 'No answer');
        _signaling.endActiveCall(
          callId: widget.callId,
          otherUserId: widget.contactId,
        );
        _scheduleAutoClose(CallStatus.missed);
      }
    });
  }

  void _onCallAccepted() {
    _ringTimeoutTimer?.cancel();
    _isEnded = true;

    // Mark call active for correct duration tracking
    ref.read(callProvider).acceptCall();

    // Transition to active call page (voice or video)
    final Widget callPage = widget.callType == CallType.video
        ? VideoCallPage(
            currentUserId: widget.currentUserId, // Current user ID
            contactName: widget.contactName,
            contactProfilePic: widget.contactProfilePic,
            channelName: widget.channelName,
            callId: widget.callId,
            otherUserId: widget.contactId,
          )
        : ActiveCallPage(
            currentUserId: widget.currentUserId, // Current user ID
            contactName: widget.contactName,
            contactProfilePic: widget.contactProfilePic,
            callType: widget.callType,
            channelName: widget.channelName,
            callId: widget.callId,
            otherUserId: widget.contactId,
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

  void _scheduleAutoClose(CallStatus status) {
    _isEnded = true;
    _ringTimeoutTimer?.cancel();
    ref.read(callProvider).endCallWithStatus(status);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  void _cancelCall() {
    if (_isEnded) return;
    _isEnded = true;
    _ringTimeoutTimer?.cancel();

    _signaling.endActiveCall(
      callId: widget.callId,
      otherUserId: widget.contactId,
    );
    ref.read(callProvider).endCallWithStatus(CallStatus.ended);
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _ringTimeoutTimer?.cancel();
    _fadeController.dispose();
    _ringSub?.cancel();
    _acceptSub?.cancel();
    _rejectSub?.cancel();
    _endSub?.cancel();
    _unavailableSub?.cancel();
    _errorSub?.cancel();
    _missedSub?.cancel();
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
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) _cancelCall();
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
                          SizedBox(height: responsive.spacing(16)),
                          // Top bar
                          _buildTopBar(responsive),
                          SizedBox(height: responsive.spacing(60)),
                          // Encrypted label
                          _buildEncryptedLabel(responsive),
                          SizedBox(height: responsive.spacing(40)),
                          // Avatar with ripple animation
                          CallAvatar(
                            name: widget.contactName,
                            profilePicUrl: widget.contactProfilePic,
                            size: 120,
                            showRipple: !_isEnded,
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
                          SizedBox(height: responsive.spacing(12)),
                          // Call status
                          _buildCallStatus(responsive),
                          const Spacer(),
                          // Action buttons
                          _buildActionButtons(responsive),
                          SizedBox(height: responsive.spacing(30)),
                          // End call button
                          if (!_isEnded) ...[
                            EndCallButton(onTap: _cancelCall),
                            SizedBox(height: responsive.spacing(12)),
                            Text(
                              'Cancel',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: responsive.size(13),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
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

  Widget _buildTopBar(ResponsiveSize responsive) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: responsive.spacing(16)),
      child: Row(
        children: [
          GestureDetector(
            onTap: _cancelCall,
            child: Container(
              padding: EdgeInsets.all(responsive.spacing(8)),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(responsive.size(12)),
              ),
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Colors.white.withValues(alpha: 0.7),
                size: responsive.size(24),
              ),
            ),
          ),
          const Spacer(),
          // Call type indicator
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.callType == CallType.video
                    ? Icons.videocam_rounded
                    : Icons.call_rounded,
                color: Colors.white.withValues(alpha: 0.5),
                size: responsive.size(16),
              ),
              SizedBox(width: responsive.spacing(6)),
              Text(
                widget.callType == CallType.video ? 'Video Call' : 'Voice Call',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: responsive.size(13),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const Spacer(),
          SizedBox(width: responsive.size(40)),
        ],
      ),
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

  Widget _buildCallStatus(ResponsiveSize responsive) {
    final isError =
        _callStatus == 'Unavailable' ||
        _callStatus == 'Call declined' ||
        _callStatus == 'No answer' ||
        _callStatus == 'No internet connection' ||
        _callStatus == 'Call ended';

    final isRinging = _callStatus == 'Ringing...';

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (!_isEnded && !isError)
          Padding(
            padding: EdgeInsets.only(right: responsive.spacing(8)),
            child: SizedBox(
              width: responsive.size(14),
              height: responsive.size(14),
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
        if (isError)
          Padding(
            padding: EdgeInsets.only(right: responsive.spacing(8)),
            child: Icon(
              Icons.call_end_rounded,
              color: const Color(0xFFEF4444),
              size: responsive.size(18),
            ),
          ),
        if (isRinging)
          Padding(
            padding: EdgeInsets.only(right: responsive.spacing(8)),
            child: Icon(
              Icons.ring_volume_rounded,
              color: const Color(0xFF22C55E),
              size: responsive.size(18),
            ),
          ),
        Text(
          _callStatus,
          style: TextStyle(
            color: isError
                ? const Color(0xFFEF4444).withValues(alpha: 0.8)
                : isRinging
                ? const Color(0xFF22C55E)
                : Colors.white.withValues(alpha: 0.6),
            fontSize: responsive.size(16),
            fontWeight: isRinging ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(ResponsiveSize responsive) {
    if (_isEnded) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: responsive.spacing(50)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          CallActionButton(
            icon: Icons.volume_up_rounded,
            label: 'Speaker',
            onTap: () {
              // Pre-enable speaker before call connects
            },
            backgroundColor: Colors.white.withValues(alpha: 0.08),
          ),
          CallActionButton(
            icon: Icons.mic_off_rounded,
            label: 'Mute',
            onTap: () {
              // Pre-mute before call connects
            },
            backgroundColor: Colors.white.withValues(alpha: 0.08),
          ),
        ],
      ),
    );
  }
}
