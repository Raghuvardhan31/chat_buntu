import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:chataway_plus/features/voice_call/data/config/agora_config.dart';

/// Callback types for call events
typedef OnCallConnected = void Function();
typedef OnCallEnded = void Function(String reason);
typedef OnRemoteUserJoined = void Function(int uid);
typedef OnRemoteUserLeft = void Function(int uid, String reason);
typedef OnCallError = void Function(String error);
typedef OnConnectionStateChanged = void Function(ConnectionStateType state, ConnectionChangedReasonType reason);

/// Service that wraps Agora RTC Engine for voice/video calling
/// Handles engine lifecycle, channel join/leave, and audio controls
class AgoraCallService {
  AgoraCallService._();
  static final AgoraCallService instance = AgoraCallService._();

  RtcEngine? _engine;
  bool _isInitialized = false;
  bool _isInChannel = false;
  ConnectionStateType _connectionState = ConnectionStateType.connectionStateDisconnected;

  bool get isInitialized => _isInitialized;
  bool get isInChannel => _isInChannel;
  ConnectionStateType get connectionState => _connectionState;

  // Event callbacks
  OnCallConnected? onCallConnected;
  OnCallEnded? onCallEnded;
  OnRemoteUserJoined? onRemoteUserJoined;
  OnRemoteUserLeft? onRemoteUserLeft;
  OnCallError? onCallError;
  OnConnectionStateChanged? onConnectionStateChanged;

  // Stream controllers for reactive state
  final _connectionStateController = StreamController<String>.broadcast();
  Stream<String> get connectionStateStream => _connectionStateController.stream;

  /// Request microphone and camera permissions
  Future<bool> requestPermissions({bool video = false}) async {
    final permissions = <Permission>[Permission.microphone];
    if (video) {
      permissions.add(Permission.camera);
    }

    final statuses = await permissions.request();

    final micGranted = statuses[Permission.microphone]?.isGranted ?? false;
    final camGranted =
        !video || (statuses[Permission.camera]?.isGranted ?? false);

    if (!micGranted) {
      debugPrint('❌ AgoraCallService: Microphone permission denied');
    }
    if (video && !camGranted) {
      debugPrint('❌ AgoraCallService: Camera permission denied');
    }

    return micGranted && camGranted;
  }

  /// Initialize the Agora RTC Engine
  Future<bool> initialize() async {
    if (_isInitialized && _engine != null) {
      debugPrint('✅ AgoraCallService: Already initialized');
      return true;
    }

    try {
      debugPrint('🔧 AgoraCallService: Initializing engine...');

      _engine = createAgoraRtcEngine();
      await _engine!.initialize(
        const RtcEngineContext(
          appId: AgoraConfig.appId,
          channelProfile: ChannelProfileType.channelProfileCommunication,
        ),
      );

      // Register event handlers
      _engine!.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            debugPrint(
              '✅ AgoraCallService: Joined channel ${connection.channelId} in ${elapsed}ms',
            );
            _isInChannel = true;
            _connectionStateController.add('connected');
            onCallConnected?.call();
          },
          onLeaveChannel: (RtcConnection connection, RtcStats stats) {
            debugPrint(
              '📴 AgoraCallService: Left channel. Duration: ${stats.duration}s',
            );
            _isInChannel = false;
            _connectionStateController.add('disconnected');
          },
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            debugPrint('👤 AgoraCallService: Remote user $remoteUid joined');
            onRemoteUserJoined?.call(remoteUid);
          },
          onUserOffline:
              (
                RtcConnection connection,
                int remoteUid,
                UserOfflineReasonType reason,
              ) {
                debugPrint(
                  '👤 AgoraCallService: Remote user $remoteUid left (${reason.name})',
                );
                final reasonStr =
                    reason == UserOfflineReasonType.userOfflineDropped
                    ? 'Connection lost'
                    : 'User left';
                onRemoteUserLeft?.call(remoteUid, reasonStr);
              },
          onConnectionStateChanged:
              (
                RtcConnection connection,
                ConnectionStateType state,
                ConnectionChangedReasonType reason,
              ) {
                debugPrint(
                  '🔌 AgoraCallService: Connection state changed: ${state.name} reason: ${reason.name}',
                );
                _connectionState = state;
                _connectionStateController.add(state.name);
                onConnectionStateChanged?.call(state, reason);
              },
          onError: (ErrorCodeType err, String msg) {
            debugPrint('❌ AgoraCallService: Error ${err.name}: $msg');
            onCallError?.call('Agora Error: ${err.name} - $msg');
          },
          onAudioRoutingChanged: (int routing) {
            debugPrint('🎧 AgoraCallService: Audio routing changed to $routing');
          },
          onTokenPrivilegeWillExpire: (RtcConnection connection, String token) {
            debugPrint('⚠️ AgoraCallService: Token will expire soon');
          },
        ),
      );


      // Set audio profile for voice calls — Default scenario ensures
      // proper earpiece/speaker routing like a real phone call
      await _engine!.setAudioProfile(
        profile: AudioProfileType.audioProfileDefault,
        scenario: AudioScenarioType.audioScenarioDefault,
      );

      // Enable audio
      await _engine!.enableAudio();

      // Default to earpiece for voice, but video calls will override this
      await _engine!.setDefaultAudioRouteToSpeakerphone(false);

      _isInitialized = true;
      debugPrint('✅ AgoraCallService: Engine initialized successfully');
      return true;
    } catch (e) {
      debugPrint('❌ AgoraCallService: Initialize failed: $e');
      _isInitialized = false;
      return false;
    }
  }

  /// Join a voice call channel
  /// [channelName] — unique channel ID (e.g., conversation ID between two users)
  /// [uid] — local user ID (0 = auto-assign)
  Future<bool> joinVoiceCall({
    required String channelName,
    String? token,
    int uid = 0,
  }) async {
    if (_engine == null || !_isInitialized) {
      debugPrint('❌ AgoraCallService: Engine not initialized');
      return false;
    }

    if (_isInChannel) {
      debugPrint('⚠️ AgoraCallService: Already in a channel, leaving first...');
      await leaveChannel();
    }

    try {
      debugPrint(
        '📞 AgoraCallService: Joining voice channel "$channelName"...',
      );

      // Disable video for voice-only call
      await _engine!.disableVideo();

      // Ensure speaker is off by default for voice calls (earpiece)
      await _engine!.setEnableSpeakerphone(false);

      final effectiveToken = (token != null && token.isNotEmpty)
          ? token
          : AgoraConfig.token;
      debugPrint(
        '\uD83D\uDD11 AgoraCallService: Using token: ${effectiveToken.isEmpty ? "(empty)" : "${effectiveToken.substring(0, 10)}..."}',
      );

      await _engine!.joinChannel(
        token: effectiveToken,
        channelId: channelName,
        uid: uid,
        options: const ChannelMediaOptions(
          autoSubscribeAudio: true,
          publishMicrophoneTrack: true,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
        ),
      );

      return true;
    } catch (e) {
      debugPrint('❌ AgoraCallService: Join channel failed: $e');
      return false;
    }
  }

  /// Join a video call channel
  Future<bool> joinVideoCall({
    required String channelName,
    String? token,
    int uid = 0,
  }) async {
    if (_engine == null || !_isInitialized) {
      debugPrint('❌ AgoraCallService: Engine not initialized');
      return false;
    }

    if (_isInChannel) {
      debugPrint('⚠️ AgoraCallService: Already in a channel, leaving first...');
      await leaveChannel();
    }

    try {
      debugPrint(
        '📹 AgoraCallService: Joining video channel "$channelName"...',
      );

      await _engine!.enableVideo();
      
      // Video calls always use speakerphone by default
      await _engine!.setEnableSpeakerphone(true);

      final effectiveToken = (token != null && token.isNotEmpty)
          ? token
          : AgoraConfig.token;
      debugPrint(
        '\uD83D\uDD11 AgoraCallService: Using token: ${effectiveToken.isEmpty ? "(empty)" : "${effectiveToken.substring(0, 10)}..."}',
      );

      await _engine!.joinChannel(
        token: effectiveToken,
        channelId: channelName,
        uid: uid,
        options: const ChannelMediaOptions(
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
          publishMicrophoneTrack: true,
          publishCameraTrack: true,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
        ),
      );

      return true;
    } catch (e) {
      debugPrint('❌ AgoraCallService: Join video channel failed: $e');
      return false;
    }
  }


  /// Leave the current channel
  Future<void> leaveChannel() async {
    if (_engine == null) return;

    try {
      if (_isInChannel) {
        await _engine!.leaveChannel();
      }
      _isInChannel = false;
      debugPrint('📴 AgoraCallService: Left channel');
    } catch (e) {
      debugPrint('❌ AgoraCallService: Leave channel failed: $e');
      _isInChannel = false;
    }
  }

  /// Toggle microphone mute
  Future<void> setMicMuted(bool muted) async {
    if (_engine == null) return;
    await _engine!.muteLocalAudioStream(muted);
    debugPrint('🎤 AgoraCallService: Mic ${muted ? "muted" : "unmuted"}');
  }

  /// Toggle speaker phone
  Future<void> setSpeakerOn(bool speakerOn) async {
    if (_engine == null) return;
    await _engine!.setEnableSpeakerphone(speakerOn);
    debugPrint('🔊 AgoraCallService: Speaker ${speakerOn ? "on" : "off"}');
  }

  /// Set explicit audio route (e.g., Bluetooth, Earpiece)
  /// Note: setEnableSpeakerphone(true) usually overrides this to Speaker.
  Future<void> setAudioRoute(AudioRoute route) async {
    if (_engine == null) return;
    try {
      // In some SDK versions, we use setAudioRoute explicitly
      // For others, setEnableSpeakerphone is enough.
      // We'll use the engine's direct method if available via the native channel
      // but for now, we'll log and use the standard routing logic.
      debugPrint('🎧 AgoraCallService: Setting audio route to $route');
      
      if (route == AudioRoute.routeSpeakerphone) {
        await setSpeakerOn(true);
      } else {
        await setSpeakerOn(false);
      }
    } catch (e) {
      debugPrint('❌ AgoraCallService: Failed to set audio route: $e');
    }
  }

  /// Switch camera (front/back) for video calls
  Future<void> switchCamera() async {
    if (_engine == null) return;
    await _engine!.switchCamera();
    debugPrint('📷 AgoraCallService: Camera switched');
  }

  /// Enable/disable local video
  Future<void> setVideoEnabled(bool enabled) async {
    if (_engine == null) return;
    await _engine!.muteLocalVideoStream(!enabled);
    debugPrint(
      '📹 AgoraCallService: Video ${enabled ? "enabled" : "disabled"}',
    );
  }

  /// Dispose the engine — call when app is closing or feature is no longer needed
  /// NOTE: Does NOT close _connectionStateController since this is a singleton.
  /// Closing it would make the stream permanently unusable on next call.
  Future<void> dispose() async {
    try {
      if (_isInChannel) {
        await leaveChannel();
      }
      if (_engine != null) {
        await _engine!.release();
        _engine = null;
      }
      _isInitialized = false;
      debugPrint('🧹 AgoraCallService: Disposed');
    } catch (e) {
      debugPrint('❌ AgoraCallService: Dispose failed: $e');
    }
  }

  /// Get the RTC engine instance (for advanced use cases)
  RtcEngine? get engine => _engine;
}
