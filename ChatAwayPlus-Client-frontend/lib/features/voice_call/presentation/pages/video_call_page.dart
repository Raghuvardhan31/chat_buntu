import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:chataway_plus/features/voice_call/data/services/agora_call_service.dart';
import 'package:chataway_plus/features/voice_call/data/services/call_signaling_service.dart';
import 'package:chataway_plus/features/voice_call/presentation/providers/call_provider.dart';
import 'package:chataway_plus/features/voice_call/presentation/widgets/call_avatar.dart';
import 'package:chataway_plus/features/voice_call/data/config/agora_config.dart';

/// Full-screen video call page with real Agora RTC integration
/// Shows local preview (small PiP), remote video (full screen),
/// and action buttons (mute, camera switch, video toggle, end)
///
/// IMPORTANT: User can ONLY leave by pressing the end-call button.
/// No back button, no system back gesture — just like a real phone call.
class VideoCallPage extends ConsumerStatefulWidget {
  final String currentUserId; // Current user ID
  final String contactName;
  final String? contactProfilePic;
  final String channelName;
  final String callId;
  final String otherUserId; // Remote user ID

  const VideoCallPage({
    super.key,
    required this.currentUserId,
    required this.contactName,
    this.contactProfilePic,
    required this.channelName,
    required this.callId,
    required this.otherUserId,
  });

  @override
  ConsumerState<VideoCallPage> createState() => _VideoCallPageState();
}

class _VideoCallPageState extends ConsumerState<VideoCallPage> {
  final _agoraService = AgoraCallService.instance;

  Timer? _callTimer;
  Timer? _connectionTimeoutTimer;
  int _elapsedSeconds = 0;
  bool _isConnected = false;
  bool _isMuted = false;
  bool _isSpeakerOn = true; // Speaker on by default for video calls
  bool _isVideoEnabled = true;
  bool _isFrontCamera = true;
  bool _isConnecting = true;
  bool _showControls = true;
  int? _remoteUid;
  String _callStatus = 'Connecting...';
  Timer? _hideControlsTimer;
  StreamSubscription? _callEndedSub;
  StreamSubscription? _callMissedSub;
  bool _hasEnded = false;

  @override
  void initState() {
    super.initState();
    _initializeCall();
    _startHideControlsTimer();

    // Listen for call-ended signal from other party
    // Filter by callId to prevent cross-call interference
    _callEndedSub = CallSignalingService.instance.callEndedStream.listen((callId) {
      if (!_hasEnded && mounted && callId == widget.callId) {
        _endCall(reason: 'Other party ended the call');
      }
    });

    // Listen for missed call signal (server timeout)
    _callMissedSub = CallSignalingService.instance.callMissedStream.listen((callId) {
      if (!_hasEnded && mounted && callId == widget.callId) {
        _endCall(reason: 'Call timed out');
      }
    });
  }

  Future<void> _initializeCall() async {
    // Request permissions (video + audio)
    final granted = await _agoraService.requestPermissions(video: true);
    if (!granted || !mounted) {
      if (mounted) {
        setState(() {
          _callStatus = 'Permission denied';
          _isConnecting = false;
        });
      }
      return;
    }

    // Initialize engine — always creates a fresh engine
    final initialized = await _agoraService.initialize();
    if (!initialized || !mounted) {
      if (mounted) {
        setState(() {
          _callStatus = 'Failed to initialize';
          _isConnecting = false;
        });
      }
      return;
    }

    // Set up callbacks
    _agoraService.onCallConnected = () {
      debugPrint('✅ VideoCallPage: Local user joined Agora channel');
      if (mounted) {
        setState(() => _callStatus = 'Waiting for other party...');
      }
    };

    _agoraService.onRemoteUserJoined = (int uid) {
      debugPrint('📹 VideoCallPage: Remote user joined with UID: $uid');
      if (mounted) {
        setState(() {
          _remoteUid = uid;
          _isConnected = true;
          _isConnecting = false;
          _callStatus = 'Connected';
        });
        _startTimer();
        debugPrint('📹 VideoCallPage: State updated - Remote video should now be visible');
      }
    };

    _agoraService.onRemoteUserLeft = (int uid, String reason) {
      if (mounted && !_hasEnded) _endCall(reason: reason);
    };

    _agoraService.onCallEnded = (String reason) {
      if (mounted && !_hasEnded) _endCall(reason: reason);
    };

    _agoraService.onCallError = (error) {
      debugPrint('❌ VideoCallPage: Agora Error: $error');
      if (mounted) {
        setState(() {
          _callStatus = 'Connection error';
          _isConnecting = false;
        });
        // Auto-end call on critical error after a short delay
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted && !_isConnected && !_hasEnded) {
            _endCall(reason: error);
          }
        });
      }
    };

    _agoraService.onConnectionStateChanged = (state, reason) {
      debugPrint('🔌 VideoCallPage: Connection state: ${state.name}, reason: ${reason.name}');
      if (mounted) {
        setState(() {
          if (state == ConnectionStateType.connectionStateConnecting) {
            _callStatus = 'Connecting...';
          } else if (state == ConnectionStateType.connectionStateReconnecting) {
            _callStatus = 'Reconnecting...';
          } else if (state == ConnectionStateType.connectionStateFailed) {
            _callStatus = 'Connection failed';
            _isConnecting = false;
          }
        });
      }
    };


    // Check if already in Agora channel (caller pre-joined in OutgoingCallPage)
    if (_agoraService.isInChannel && _agoraService.currentChannelName == widget.channelName) {
      debugPrint('✅ VideoCallPage: Already in Agora channel (caller pre-joined)');
      if (mounted) {
        setState(() => _callStatus = 'Waiting for other party...');
      }
      await _agoraService.setSpeakerOn(true);
    } else {
      // Join video channel (callee flow or fallback)
      if (mounted) {
        setState(() => _callStatus = 'Connecting...');
      }

      // Convert current user ID to int for Agora UID
      final currentUserId = AgoraConfig.uuidToUint32(widget.currentUserId);
      debugPrint('📹 VideoCallPage: Using mapped UID for Agora: $currentUserId from UUID: ${widget.currentUserId}');

      final joined = await _agoraService.joinVideoCall(
        channelName: widget.channelName,
        uid: currentUserId,
      );

      // Enable speaker by default for video calls
      await _agoraService.setSpeakerOn(true);

      if (!joined && mounted) {
        setState(() {
          _callStatus = 'Connection failed';
          _isConnecting = false;
        });
        return;
      }
    }

    // Start connection timeout
    _connectionTimeoutTimer = Timer(const Duration(seconds: 45), () {
      if (!_isConnected && !_hasEnded && mounted) {
        debugPrint('⏰ VideoCallPage: Connection timeout. Other party never joined.');
        _endCall(reason: 'Connection timed out');
      }
    });
  }


  void _startTimer() {
    _connectionTimeoutTimer?.cancel(); // Connection succeeded, cancel timeout
    _callTimer?.cancel();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _elapsedSeconds++);
    });
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _isConnected) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      _startHideControlsTimer();
    }
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _connectionTimeoutTimer?.cancel();
    _hideControlsTimer?.cancel();
    _callEndedSub?.cancel();
    _callMissedSub?.cancel();
    _agoraService.onCallConnected = null;
    _agoraService.onRemoteUserJoined = null;
    _agoraService.onRemoteUserLeft = null;
    _agoraService.onCallEnded = null;
    if (!_hasEnded) {
      _agoraService.leaveChannel();
    }
    super.dispose();
  }

  String get _formattedTime {
    final minutes = _elapsedSeconds ~/ 60;
    final seconds = _elapsedSeconds % 60;
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      return '$hours:${mins.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
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
          // Block ALL back navigation — user MUST use the end-call button
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            // Do nothing — no back navigation allowed during call
          },
          child: Scaffold(
            backgroundColor: const Color(0xFF0F172A),
            body: GestureDetector(
              onTap: _toggleControls,
              child: Stack(
                children: [
                  // Full screen remote video or waiting state
                  _buildRemoteVideo(responsive),

                  // Local video preview (PiP)
                  if (_isVideoEnabled) _buildLocalVideoPreview(responsive),

                  // Top bar overlay — NO back button, just info
                  if (_showControls) _buildTopOverlay(responsive),

                  // Bottom controls overlay
                  if (_showControls) _buildBottomOverlay(responsive),

                  // Connecting overlay (shown before remote user joins)
                  if (!_isConnected) _buildConnectingOverlay(responsive),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRemoteVideo(ResponsiveSize responsive) {
    if (_remoteUid != null && _agoraService.engine != null) {
      debugPrint('📹 VideoCallPage: Building remote video for UID: $_remoteUid');
      return SizedBox.expand(
        child: AgoraVideoView(
          controller: VideoViewController.remote(
            rtcEngine: _agoraService.engine!,
            canvas: VideoCanvas(uid: _remoteUid!),
            connection: RtcConnection(channelId: widget.channelName),
            useFlutterTexture: false, // Use SurfaceView for better compatibility
          ),
        ),
      );
    }

    // Waiting state — show contact avatar
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0F172A)],
        ),
      ),
    );
  }

  Widget _buildLocalVideoPreview(ResponsiveSize responsive) {
    if (_agoraService.engine == null) return const SizedBox.shrink();

    return Positioned(
      top: responsive.spacing(60),
      right: responsive.spacing(16),
      child: GestureDetector(
        onTap: () {}, // Prevent tap-through
        child: Container(
          width: responsive.size(120),
          height: responsive.size(160),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(responsive.size(16)),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(responsive.size(14)),
            child: AgoraVideoView(
              controller: VideoViewController(
                rtcEngine: _agoraService.engine!,
                canvas: const VideoCanvas(uid: 0),
                useFlutterTexture: false, // Use SurfaceView
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopOverlay(ResponsiveSize responsive) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + responsive.spacing(8),
          left: responsive.spacing(16),
          right: responsive.spacing(16),
          bottom: responsive.spacing(16),
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
          ),
        ),
        child: Row(
          children: [
            SizedBox(width: responsive.spacing(12)),
            // Contact info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.contactName,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: responsive.size(17),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: responsive.spacing(2)),
                  Text(
                    _isConnected ? _formattedTime : _callStatus,
                    style: TextStyle(
                      color: _isConnected
                          ? const Color(0xFF22C55E)
                          : Colors.white.withValues(alpha: 0.6),
                      fontSize: responsive.size(13),
                      fontWeight: FontWeight.w500,
                      fontFeatures: _isConnected
                          ? const [FontFeature.tabularFigures()]
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            // Encryption badge
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_rounded,
                  color: Colors.white.withValues(alpha: 0.5),
                  size: responsive.size(12),
                ),
                SizedBox(width: responsive.spacing(4)),
                Text(
                  'Encrypted',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: responsive.size(11),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomOverlay(ResponsiveSize responsive) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          top: responsive.spacing(24),
          bottom:
              MediaQuery.of(context).padding.bottom + responsive.spacing(24),
          left: responsive.spacing(20),
          right: responsive.spacing(20),
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Mute
            _buildVideoControlButton(
              icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
              label: _isMuted ? 'Unmute' : 'Mute',
              isActive: _isMuted,
              onTap: _toggleMute,
              responsive: responsive,
            ),
            // Camera switch
            _buildVideoControlButton(
              icon: Icons.cameraswitch_rounded,
              label: 'Flip',
              onTap: _switchCamera,
              responsive: responsive,
            ),
            // Video toggle
            _buildVideoControlButton(
              icon: _isVideoEnabled
                  ? Icons.videocam_rounded
                  : Icons.videocam_off_rounded,
              label: _isVideoEnabled ? 'Camera' : 'Camera Off',
              isActive: !_isVideoEnabled,
              onTap: _toggleVideo,
              responsive: responsive,
            ),
            // End call
            GestureDetector(
              onTap: () => _endCall(),
              child: Container(
                width: responsive.size(56),
                height: responsive.size(56),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                  ),
                ),
                child: Icon(
                  Icons.call_end_rounded,
                  color: Colors.white,
                  size: responsive.size(26),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoControlButton({
    required IconData icon,
    required String label,
    bool isActive = false,
    required VoidCallback onTap,
    required ResponsiveSize responsive,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: responsive.size(48),
            height: responsive.size(48),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive
                  ? Colors.white.withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.12),
            ),
            child: Icon(icon, color: Colors.white, size: responsive.size(22)),
          ),
          SizedBox(height: responsive.spacing(6)),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: responsive.size(10),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectingOverlay(ResponsiveSize responsive) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFF0F172A).withValues(alpha: 0.85),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CallAvatar(
            name: widget.contactName,
            profilePicUrl: widget.contactProfilePic,
            size: 120,
            showRipple: true,
          ),
          SizedBox(height: responsive.spacing(30)),
          Text(
            widget.contactName,
            style: TextStyle(
              color: Colors.white,
              fontSize: responsive.size(26),
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: responsive.spacing(10)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isConnecting)
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
              Text(
                _callStatus,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: responsive.size(16),
                ),
              ),
            ],
          ),
          // Show end-call button during connecting too
          SizedBox(height: responsive.spacing(40)),
          GestureDetector(
            onTap: () => _endCall(),
            child: Container(
              width: responsive.size(64),
              height: responsive.size(64),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                ),
              ),
              child: Icon(
                Icons.call_end_rounded,
                color: Colors.white,
                size: responsive.size(30),
              ),
            ),
          ),
          SizedBox(height: responsive.spacing(8)),
          Text(
            'End Call',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: responsive.size(13),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleMute() async {
    final newMuted = !_isMuted;
    await _agoraService.setMicMuted(newMuted);
    if (mounted) setState(() => _isMuted = newMuted);
  }

  Future<void> _toggleSpeaker() async {
    final newSpeaker = !_isSpeakerOn;
    await _agoraService.setSpeakerOn(newSpeaker);
    if (mounted) setState(() => _isSpeakerOn = newSpeaker);
  }

  Future<void> _switchCamera() async {
    await _agoraService.switchCamera();
    if (mounted) setState(() => _isFrontCamera = !_isFrontCamera);
  }

  Future<void> _toggleVideo() async {
    final newEnabled = !_isVideoEnabled;
    await _agoraService.setVideoEnabled(newEnabled);
    if (mounted) setState(() => _isVideoEnabled = newEnabled);
  }

  void _endCall({String? reason}) {
    if (_hasEnded) return;
    _hasEnded = true;
    _callTimer?.cancel();
    _hideControlsTimer?.cancel();
    _connectionTimeoutTimer?.cancel();

    // Signal server that the call has ended
    CallSignalingService.instance.endActiveCall(
      callId: widget.callId,
      otherUserId: widget.otherUserId,
    );

    ref.read(callProvider).endCall();
    _agoraService.leaveChannel();
    if (mounted) Navigator.of(context).pop();
  }
}
