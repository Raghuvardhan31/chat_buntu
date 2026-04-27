import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';

class CallScreen extends StatefulWidget {
  final String channelName;
  
  const CallScreen({super.key, required this.channelName});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  // Agora App ID (Static Key Authentication - No Token Required)
  static const String appId = 'fdae42cbb6f74e03ae0756be1ed3be67';
  
  int? _remoteUid;
  bool _localUserJoined = false;
  bool _isMuted = false;
  bool _isCameraOff = false;
  late RtcEngine _engine;
  bool _isFrontCamera = true;

  @override
  void initState() {
    super.initState();
    _initializeAgora();
  }

  Future<void> _initializeAgora() async {
    try {
      // Request permissions (only for mobile platforms)
      if (!kIsWeb) {
        await [Permission.camera, Permission.microphone].request();
      }
      
      // Create Agora engine
      _engine = createAgoraRtcEngine();
      await _engine.initialize(const RtcEngineContext(
        appId: appId,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ));

    // Set event handlers
    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          debugPrint("Local user uid: ${connection.localUid}");
          setState(() {
            _localUserJoined = true;
          });
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          debugPrint("Remote user uid: $remoteUid");
          setState(() {
            _remoteUid = remoteUid;
          });
        },
        onUserOffline: (RtcConnection connection, int remoteUid,
            UserOfflineReasonType reason) {
          debugPrint("Remote user left: $remoteUid");
          setState(() {
            _remoteUid = null;
          });
        },
      ),
    );

    // Enable video
    await _engine.enableVideo();
    await _engine.startPreview();
    
    // Join channel with token null (Static Key Authentication)
    await _engine.joinChannel(
      token: '', // Empty string for Static Key mode (no token)
      channelId: widget.channelName,
      uid: 0, // Set to 0 for automatic UID assignment
      options: const ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
      ),
    );
    } catch (e) {
      debugPrint("Error initializing Agora: $e");
      setState(() {
        _localUserJoined = false;
      });
    }
  }

  Future<void> _toggleMute() async {
    setState(() {
      _isMuted = !_isMuted;
    });
    await _engine.muteLocalAudioStream(_isMuted);
  }

  Future<void> _toggleCamera() async {
    setState(() {
      _isCameraOff = !_isCameraOff;
    });
    await _engine.enableLocalVideo(!_isCameraOff);
    await _engine.muteLocalVideoStream(_isCameraOff);
  }

  Future<void> _switchCamera() async {
    setState(() {
      _isFrontCamera = !_isFrontCamera;
    });
    await _engine.switchCamera();
  }

  Future<void> _leaveChannel() async {
    await _engine.leaveChannel();
    await _engine.release();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    super.dispose();
    _engine.release();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Video view
          _localUserJoined
              ? AgoraVideoView(
                  controller: VideoViewController(
                    rtcEngine: _engine,
                    canvas: const VideoCanvas(uid: 0),
                  ),
                )
              : const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                  ),
                ),
          
          // Remote user video
          if (_remoteUid != null)
            Positioned(
              top: 60,
              right: 20,
              width: 120,
              height: 160,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: AgoraVideoView(
                  controller: VideoViewController.remote(
                    rtcEngine: _engine,
                    canvas: VideoCanvas(uid: _remoteUid),
                    connection: RtcConnection(channelId: widget.channelName),
                  ),
                ),
              ),
            ),
          
          // Meeting info
          Positioned(
            top: 60,
            left: 20,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Meeting: ${widget.channelName}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _remoteUid != null 
                        ? 'Participants: 2' 
                        : 'Participants: 1',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Control buttons
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Mute/Unmute button
                FloatingActionButton(
                  onPressed: _toggleMute,
                  backgroundColor: _isMuted ? Colors.red : Colors.grey,
                  child: Icon(
                    _isMuted ? Icons.mic_off : Icons.mic,
                    color: Colors.white,
                  ),
                ),
                
                // Camera On/Off button
                FloatingActionButton(
                  onPressed: _toggleCamera,
                  backgroundColor: _isCameraOff ? Colors.red : Colors.grey,
                  child: Icon(
                    _isCameraOff ? Icons.videocam_off : Icons.videocam,
                    color: Colors.white,
                  ),
                ),
                
                // Switch Camera button
                FloatingActionButton(
                  onPressed: _switchCamera,
                  backgroundColor: Colors.grey,
                  child: const Icon(
                    Icons.flip_camera_ios,
                    color: Colors.white,
                  ),
                ),
                
                // Leave Meeting button
                FloatingActionButton(
                  onPressed: _leaveChannel,
                  backgroundColor: Colors.red,
                  child: const Icon(
                    Icons.call_end,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
