import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:chataway_plus/features/voice_call/data/services/agora_call_service.dart';
import 'package:chataway_plus/features/voice_call/data/config/agora_config.dart';
import 'package:chataway_plus/features/voice_call/presentation/widgets/call_action_button.dart';
import 'package:chataway_plus/features/voice_call/presentation/providers/call_provider.dart';

/// Professional Meeting Page (Group Video Call)
/// Supports multiple participants in a grid/list view
/// Users can join via a "Meeting ID" (Agora Channel Name)
class MeetingPage extends ConsumerStatefulWidget {
  final String meetingId;
  final String currentUserId;
  final String? initialMeetingTitle;

  const MeetingPage({
    super.key,
    required this.meetingId,
    required this.currentUserId,
    this.initialMeetingTitle,
  });

  @override
  ConsumerState<MeetingPage> createState() => _MeetingPageState();
}

class _MeetingPageState extends ConsumerState<MeetingPage> {
  final _agoraService = AgoraCallService.instance;
  
  final List<int> _remoteUids = [];
  bool _isJoined = false;
  bool _isMuted = false;
  bool _isSpeakerOn = true;
  bool _isVideoEnabled = true;
  bool _isFrontCamera = true;
  bool _isConnecting = true;
  String _status = 'Connecting...';
  
  Timer? _meetingTimer;
  int _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
    _initializeMeeting();
  }

  Future<void> _initializeMeeting() async {
    // 1. Request permissions
    final granted = await _agoraService.requestPermissions(video: true);
    if (!granted) {
      if (mounted) {
        setState(() {
          _status = 'Permission denied';
          _isConnecting = false;
        });
      }
      return;
    }

    // 2. Initialize engine
    final initialized = await _agoraService.initialize();
    if (!initialized) {
      if (mounted) {
        setState(() {
          _status = 'Failed to initialize engine';
          _isConnecting = false;
        });
      }
      return;
    }

    // 3. Set up callbacks for group logic
    _agoraService.onCallConnected = () {
      if (mounted) {
        setState(() {
          _isJoined = true;
          _isConnecting = false;
          _status = 'Joined Meeting';
        });
        _startTimer();
      }
    };

    _agoraService.onRemoteUserJoined = (int uid) {
      debugPrint('👤 Meeting: Remote user joined: $uid');
      if (mounted) {
        setState(() {
          if (!_remoteUids.contains(uid)) {
            _remoteUids.add(uid);
          }
        });
      }
    };

    _agoraService.onRemoteUserLeft = (int uid, String reason) {
      debugPrint('👤 Meeting: Remote user left: $uid ($reason)');
      if (mounted) {
        setState(() {
          _remoteUids.remove(uid);
        });
      }
    };

    _agoraService.onCallError = (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red),
        );
      }
    };

    // 4. Join the channel
    final myUid = AgoraConfig.uuidToUint32(widget.currentUserId);
    final joined = await _agoraService.joinVideoCall(
      channelName: widget.meetingId,
      uid: myUid,
    );

    if (!joined && mounted) {
      setState(() {
        _status = 'Connection failed';
        _isConnecting = false;
      });
    }
  }

  void _startTimer() {
    _meetingTimer?.cancel();
    _meetingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _elapsedSeconds++);
    });
  }

  String get _formattedTime {
    final minutes = _elapsedSeconds ~/ 60;
    final seconds = _elapsedSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _meetingTimer?.cancel();
    _agoraService.onCallConnected = null;
    _agoraService.onRemoteUserJoined = null;
    _agoraService.onRemoteUserLeft = null;
    _agoraService.leaveChannel();
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
          onPopInvokedWithResult: (didPop, _) {
            // Block back navigation — user must use end-call button
          },
          child: Scaffold(
            backgroundColor: const Color(0xFF0F172A),
            body: Stack(
              children: [
                // 1. Participant Grid
                _buildParticipantGrid(responsive),

                // 2. Top Header
                _buildHeader(responsive),

                // 3. Bottom Controls
                _buildControls(responsive),

                // 4. Connecting Overlay
                if (_isConnecting) _buildConnectingOverlay(responsive),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildParticipantGrid(ResponsiveSize responsive) {
    // In a real meeting app, we'd use a more complex layout based on number of users.
    // For now, we'll do a simple list/grid.
    final totalParticipants = _remoteUids.length + (_isJoined ? 1 : 0);

    if (totalParticipants == 0) {
      return const Center(child: Text('Waiting for participants...', style: TextStyle(color: Colors.white54)));
    }

    if (totalParticipants == 1) {
      // Just me
      return _buildLocalView(responsive, fullScreen: true);
    }

    if (totalParticipants == 2) {
      // 1-to-1 style
      return Stack(
        children: [
          _buildRemoteView(_remoteUids[0], responsive, fullScreen: true),
          Positioned(
            top: responsive.spacing(100),
            right: responsive.spacing(16),
            child: _buildLocalView(responsive, width: 120, height: 160),
          ),
        ],
      );
    }

    // Grid for 3+ participants
    return GridView.builder(
      padding: EdgeInsets.only(
        top: responsive.spacing(100),
        bottom: responsive.spacing(120),
        left: responsive.spacing(8),
        right: responsive.spacing(8),
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.75,
      ),
      itemCount: totalParticipants,
      itemBuilder: (context, index) {
        if (index == totalParticipants - 1) {
          return _buildLocalView(responsive);
        }
        return _buildRemoteView(_remoteUids[index], responsive);
      },
    );
  }

  Widget _buildLocalView(ResponsiveSize responsive, {double? width, double? height, bool fullScreen = false}) {
    if (_agoraService.engine == null || !_isVideoEnabled) {
      return _buildPlaceholder('Me', responsive, width: width, height: height);
    }

    final view = AgoraVideoView(
      controller: VideoViewController(
        rtcEngine: _agoraService.engine!,
        canvas: const VideoCanvas(uid: 0),
        useFlutterTexture: false,
      ),
    );

    if (fullScreen) return SizedBox.expand(child: view);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: view,
      ),
    );
  }

  Widget _buildRemoteView(int uid, ResponsiveSize responsive, {bool fullScreen = false}) {
    if (_agoraService.engine == null) return const SizedBox.shrink();

    final view = AgoraVideoView(
      controller: VideoViewController.remote(
        rtcEngine: _agoraService.engine!,
        canvas: VideoCanvas(uid: uid),
        connection: RtcConnection(channelId: widget.meetingId),
        useFlutterTexture: false,
      ),
    );

    if (fullScreen) return SizedBox.expand(child: view);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            view,
            Positioned(
              bottom: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'User $uid',
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(String label, ResponsiveSize responsive, {double? width, double? height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off_rounded, color: Colors.white24, size: 32),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ResponsiveSize responsive) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + responsive.spacing(12),
          left: responsive.spacing(16),
          right: responsive.spacing(16),
          bottom: responsive.spacing(16),
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black87, Colors.transparent],
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.initialMeetingTitle ?? 'Meeting',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  Text(
                    'ID: ${widget.meetingId} • $_formattedTime',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.people, color: Colors.white, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    '${_remoteUids.length + 1}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls(ResponsiveSize responsive) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          top: responsive.spacing(20),
          bottom: MediaQuery.of(context).padding.bottom + responsive.spacing(20),
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black87, Colors.transparent],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildControlButton(
              icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
              label: 'Mute',
              isActive: _isMuted,
              onTap: _toggleMute,
              responsive: responsive,
            ),
            _buildControlButton(
              icon: _isVideoEnabled ? Icons.videocam_rounded : Icons.videocam_off_rounded,
              label: 'Video',
              isActive: !_isVideoEnabled,
              onTap: _toggleVideo,
              responsive: responsive,
            ),
            _buildControlButton(
              icon: Icons.cameraswitch_rounded,
              label: 'Flip',
              onTap: _switchCamera,
              responsive: responsive,
            ),
            _buildControlButton(
              icon: _isSpeakerOn ? Icons.volume_up_rounded : Icons.volume_down_rounded,
              label: 'Speaker',
              isActive: _isSpeakerOn,
              onTap: _toggleSpeaker,
              responsive: responsive,
            ),
            GestureDetector(
              onTap: _leaveMeeting,
              child: Container(
                width: responsive.size(56),
                height: responsive.size(56),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red,
                ),
                child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 28),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
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
              color: isActive ? Colors.white24 : Colors.white12,
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildConnectingOverlay(ResponsiveSize responsive) {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.blue),
            const SizedBox(height: 20),
            Text(_status, style: const TextStyle(color: Colors.white70, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  void _toggleMute() async {
    final next = !_isMuted;
    await _agoraService.setMicMuted(next);
    setState(() => _isMuted = next);
  }

  void _toggleVideo() async {
    final next = !_isVideoEnabled;
    await _agoraService.setVideoEnabled(next);
    setState(() => _isVideoEnabled = next);
  }

  void _toggleSpeaker() async {
    final next = !_isSpeakerOn;
    await _agoraService.setSpeakerOn(next);
    setState(() => _isSpeakerOn = next);
  }

  void _switchCamera() async {
    await _agoraService.switchCamera();
    setState(() => _isFrontCamera = !_isFrontCamera);
  }

  void _leaveMeeting() {
    _agoraService.leaveChannel();
    Navigator.of(context).pop();
  }
}
