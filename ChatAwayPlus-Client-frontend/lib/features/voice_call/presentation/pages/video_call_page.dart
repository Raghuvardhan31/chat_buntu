import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:chataway_plus/features/voice_call/data/services/agora_call_service.dart';
import 'package:chataway_plus/features/voice_call/data/services/call_signaling_service.dart';
import 'package:chataway_plus/features/voice_call/presentation/providers/call_provider.dart';
import 'package:chataway_plus/features/voice_call/presentation/widgets/call_avatar.dart';
import 'package:chataway_plus/features/voice_call/data/config/agora_config.dart';

class VideoCallPage extends ConsumerStatefulWidget {
  final String currentUserId;
  final String contactName;
  final String? contactProfilePic;
  final String channelName;
  final String callId;
  final String otherUserId;

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
  Timer? _hideControlsTimer;

  int _elapsedSeconds = 0;
  bool _isConnected = false;
  bool _isMuted = false;
  bool _isSpeakerOn = true;
  bool _isVideoEnabled = true;
  bool _isFrontCamera = true;
  bool _isConnecting = true;
  bool _showControls = true;
  bool _hasEnded = false;

  // ✅ false = remote big, local small. true = local big, remote small.
  bool _isLocalVideoBig = false;

  int? _remoteUid;
  String _callStatus = 'Connecting...';

  StreamSubscription? _callEndedSub;
  StreamSubscription? _callMissedSub;

  @override
  void initState() {
    super.initState();
    _initializeCall();
    _startHideControlsTimer();

    _callEndedSub =
        CallSignalingService.instance.callEndedStream.listen((callId) {
      if (!_hasEnded && mounted && callId == widget.callId) {
        _endCall(reason: 'Other party ended the call');
      }
    });

    _callMissedSub =
        CallSignalingService.instance.callMissedStream.listen((callId) {
      if (!_hasEnded && mounted && callId == widget.callId) {
        _endCall(reason: 'Call timed out');
      }
    });
  }

  Future<void> _initializeCall() async {
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
      }
    };

    _agoraService.onRemoteUserLeft = (int uid, String reason) {
      if (mounted && !_hasEnded) {
        _endCall(reason: reason);
      }
    };

    _agoraService.onCallEnded = (String reason) {
      if (mounted && !_hasEnded) {
        _endCall(reason: reason);
      }
    };

    _agoraService.onCallError = (error) {
      debugPrint('❌ VideoCallPage: Agora Error: $error');
      if (mounted) {
        setState(() {
          _callStatus = 'Connection error';
          _isConnecting = false;
        });

        Future.delayed(const Duration(seconds: 3), () {
          if (mounted && !_isConnected && !_hasEnded) {
            _endCall(reason: error);
          }
        });
      }
    };

    _agoraService.onConnectionStateChanged = (state, reason) {
      debugPrint(
        '🔌 VideoCallPage: Connection state: ${state.name}, reason: ${reason.name}',
      );

      if (mounted) {
        setState(() {
          if (state == ConnectionStateType.connectionStateConnecting) {
            _callStatus = 'Connecting...';
          } else if (state ==
              ConnectionStateType.connectionStateReconnecting) {
            _callStatus = 'Reconnecting...';
          } else if (state == ConnectionStateType.connectionStateFailed) {
            _callStatus = 'Connection failed';
            _isConnecting = false;
          }
        });
      }
    };

    if (_agoraService.isInChannel &&
        _agoraService.currentChannelName == widget.channelName) {
      debugPrint('✅ VideoCallPage: Already in Agora channel');
      if (mounted) {
        setState(() => _callStatus = 'Waiting for other party...');
      }

      await _agoraService.setSpeakerOn(true);
    } else {
      if (mounted) {
        setState(() => _callStatus = 'Connecting...');
      }

      final currentUserId = AgoraConfig.uuidToUint32(widget.currentUserId);

      final joined = await _agoraService.joinVideoCall(
        channelName: widget.channelName,
        uid: currentUserId,
      );

      await _agoraService.setSpeakerOn(true);

      if (!joined && mounted) {
        setState(() {
          _callStatus = 'Connection failed';
          _isConnecting = false;
        });
        return;
      }
    }

    _connectionTimeoutTimer = Timer(const Duration(seconds: 45), () {
      if (!_isConnected && !_hasEnded && mounted) {
        _endCall(reason: 'Connection timed out');
      }
    });
  }

  void _startTimer() {
    _connectionTimeoutTimer?.cancel();
    _callTimer?.cancel();

    _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _elapsedSeconds++);
      }
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
    _agoraService.onCallError = null;
    _agoraService.onConnectionStateChanged = null;

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
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {},
          child: Scaffold(
            backgroundColor: const Color(0xFF0F172A),
            body: GestureDetector(
              onTap: _toggleControls,
              child: Stack(
                children: [
                  // ✅ Big video area
                  _isLocalVideoBig
                      ? _buildLocalVideoFullScreen(responsive)
                      : _buildRemoteVideo(responsive),

                  // ✅ Small video preview
                  if (_isConnected)
                    _isLocalVideoBig
                        ? _buildRemoteVideoPreview(responsive)
                        : _buildLocalVideoPreview(responsive),

                  if (_showControls) _buildTopOverlay(responsive),
                  if (_showControls) _buildBottomOverlay(responsive),
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
      return GestureDetector(
        onTap: _toggleControls,
        child: SizedBox.expand(
          child: AgoraVideoView(
            controller: VideoViewController.remote(
              rtcEngine: _agoraService.engine!,
              canvas: VideoCanvas(uid: _remoteUid!),
              connection: RtcConnection(channelId: widget.channelName),
              useFlutterTexture: false,
            ),
          ),
        ),
      );
    }

    return _buildWaitingBackground();
  }

  Widget _buildLocalVideoFullScreen(ResponsiveSize responsive) {
    if (_agoraService.engine == null || !_isVideoEnabled) {
      return _buildWaitingBackground();
    }

    return GestureDetector(
      onTap: _toggleControls,
      child: SizedBox.expand(
        child: AgoraVideoView(
          controller: VideoViewController(
            rtcEngine: _agoraService.engine!,
            canvas: const VideoCanvas(uid: 0),
            useFlutterTexture: false,
          ),
        ),
      ),
    );
  }

  Widget _buildLocalVideoPreview(ResponsiveSize responsive) {
    if (_agoraService.engine == null || !_isVideoEnabled) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: responsive.spacing(60),
      right: responsive.spacing(16),
      child: GestureDetector(
        onTap: () {
          setState(() => _isLocalVideoBig = true);
          _startHideControlsTimer();
        },
        child: _previewContainer(
          responsive: responsive,
          child: AgoraVideoView(
            controller: VideoViewController(
              rtcEngine: _agoraService.engine!,
              canvas: const VideoCanvas(uid: 0),
              useFlutterTexture: false,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRemoteVideoPreview(ResponsiveSize responsive) {
    if (_remoteUid == null || _agoraService.engine == null) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: responsive.spacing(60),
      right: responsive.spacing(16),
      child: GestureDetector(
        onTap: () {
          setState(() => _isLocalVideoBig = false);
          _startHideControlsTimer();
        },
        child: _previewContainer(
          responsive: responsive,
          child: AgoraVideoView(
            controller: VideoViewController.remote(
              rtcEngine: _agoraService.engine!,
              canvas: VideoCanvas(uid: _remoteUid!),
              connection: RtcConnection(channelId: widget.channelName),
              useFlutterTexture: false,
            ),
          ),
        ),
      ),
    );
  }

  Widget _previewContainer({
    required ResponsiveSize responsive,
    required Widget child,
  }) {
    return Container(
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
        child: child,
      ),
    );
  }

  Widget _buildWaitingBackground() {
    return Container(
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
            colors: [
              Colors.black.withValues(alpha: 0.7),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          children: [
            SizedBox(width: responsive.spacing(12)),
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
          left: responsive.spacing(12),
          right: responsive.spacing(12),
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withValues(alpha: 0.8),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildVideoControlButton(
              icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
              label: _isMuted ? 'Unmute' : 'Mute',
              isActive: _isMuted,
              onTap: _toggleMute,
              responsive: responsive,
            ),
            _buildVideoControlButton(
              icon: _isSpeakerOn
                  ? Icons.volume_up_rounded
                  : Icons.hearing_rounded,
              label: _isSpeakerOn ? 'Speaker' : 'Earpiece',
              isActive: _isSpeakerOn,
              onTap: _toggleSpeaker,
              responsive: responsive,
            ),
            _buildVideoControlButton(
              icon: Icons.cameraswitch_rounded,
              label: 'Flip',
              onTap: _switchCamera,
              responsive: responsive,
            ),
            _buildVideoControlButton(
              icon: _isVideoEnabled
                  ? Icons.videocam_rounded
                  : Icons.videocam_off_rounded,
              label: _isVideoEnabled ? 'Camera' : 'Camera Off',
              isActive: !_isVideoEnabled,
              onTap: _toggleVideo,
              responsive: responsive,
            ),
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
            width: responsive.size(46),
            height: responsive.size(46),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive
                  ? Colors.white.withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.12),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: responsive.size(21),
            ),
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

    if (mounted) {
      setState(() => _isMuted = newMuted);
    }
  }

  Future<void> _toggleSpeaker() async {
    final newSpeaker = !_isSpeakerOn;
    await _agoraService.setSpeakerOn(newSpeaker);

    if (mounted) {
      setState(() => _isSpeakerOn = newSpeaker);
    }
  }

  Future<void> _switchCamera() async {
    await _agoraService.switchCamera();

    if (mounted) {
      setState(() => _isFrontCamera = !_isFrontCamera);
    }
  }

  Future<void> _toggleVideo() async {
    final newEnabled = !_isVideoEnabled;
    await _agoraService.setVideoEnabled(newEnabled);

    if (mounted) {
      setState(() {
        _isVideoEnabled = newEnabled;
        if (!_isVideoEnabled) {
          _isLocalVideoBig = false;
        }
      });
    }
  }

  void _endCall({String? reason}) {
    if (_hasEnded) return;

    _hasEnded = true;

    _callTimer?.cancel();
    _hideControlsTimer?.cancel();
    _connectionTimeoutTimer?.cancel();

    CallSignalingService.instance.endActiveCall(
      callId: widget.callId,
      otherUserId: widget.otherUserId,
    );

    ref.read(callProvider).endCall();
    _agoraService.leaveChannel();

    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}