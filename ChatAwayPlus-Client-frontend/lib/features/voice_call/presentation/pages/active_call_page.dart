import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:chataway_plus/features/voice_call/data/models/call_model.dart';
import 'package:chataway_plus/features/voice_call/data/services/agora_call_service.dart';
import 'package:chataway_plus/features/voice_call/data/services/call_signaling_service.dart';
import 'package:chataway_plus/features/voice_call/presentation/providers/call_provider.dart';
import 'package:chataway_plus/features/voice_call/presentation/widgets/call_avatar.dart';
import 'package:chataway_plus/features/voice_call/presentation/widgets/call_action_button.dart';
import 'package:chataway_plus/features/voice_call/data/config/agora_config.dart';

/// Active/Ongoing voice call page with real Agora RTC integration
/// Shows call timer, contact info, and action buttons (mute, speaker, end)
/// Modern dark gradient design inspired by WhatsApp & iOS call screens
class ActiveCallPage extends ConsumerStatefulWidget {
  final String currentUserId; // Current user ID
  final String contactName;
  final String? contactProfilePic;
  final CallType callType;
  final String channelName;
  final String callId;
  final String otherUserId; // Remote user ID

  const ActiveCallPage({
    super.key,
    required this.currentUserId,
    required this.contactName,
    this.contactProfilePic,
    required this.callType,
    required this.channelName,
    required this.callId,
    required this.otherUserId,
  });

  @override
  ConsumerState<ActiveCallPage> createState() => _ActiveCallPageState();
}

class _ActiveCallPageState extends ConsumerState<ActiveCallPage>
    with SingleTickerProviderStateMixin {
  final _agoraService = AgoraCallService.instance;

  Timer? _callTimer;
  Timer? _connectionTimeoutTimer;
  int _elapsedSeconds = 0;
  bool _isConnected = false;
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  bool _isConnecting = true;
  String _callStatus = 'Connecting...';
  StreamSubscription? _callEndedSub;
  bool _hasEnded = false;

  /// Timeout for Agora connection — if no remote user joins within this time,
  /// auto-end the call instead of staying stuck on 'Connecting...' forever.
  static const Duration _connectionTimeout = Duration(seconds: 30);

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

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

    _initializeCall();

    // Listen for call-ended signal from other party (Scenario F: disconnect)
    // Filter by callId to prevent stale events from previous calls
    _callEndedSub = CallSignalingService.instance.callEndedStream.listen((
      callId,
    ) {
      if (!_hasEnded &&
          mounted &&
          (widget.callId == null || callId == widget.callId)) {
        _endCall(reason: 'Other party ended the call');
      }
    });
  }

  Future<void> _initializeCall() async {
    // Request permissions
    final granted = await _agoraService.requestPermissions(
      video: widget.callType == CallType.video,
    );
    if (!granted || !mounted) {
      if (mounted) {
        setState(() {
          _callStatus = 'Permission denied';
          _isConnecting = false;
        });
      }
      return;
    }

    // Initialize engine
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

    // Apply any early UI toggles that may have happened before engine init
    await _agoraService.setSpeakerOn(_isSpeakerOn);

    // Set up callbacks
    _agoraService.onCallConnected = () {
      debugPrint('✅ ActiveCallPage: Local user joined Agora channel: ${widget.channelName}');
      if (mounted) {
        setState(() {
          _callStatus = 'Waiting for other party...';
        });
      }
    };

    _agoraService.onRemoteUserJoined = (int uid) {
      debugPrint(
        '🚀 ActiveCallPage: REMOTE USER JOINED! uid=$uid — call is now active!',
      );
      if (mounted) {
        setState(() {
          _isConnected = true;
          _isConnecting = false;
          _callStatus = 'Connected';
        });
        _startTimer();
      }
    };

    _agoraService.onRemoteUserLeft = (int uid, String reason) {
      debugPrint('📴 ActiveCallPage: Remote user $uid left. Reason: $reason');
      if (mounted) {
        _endCall(reason: reason);
      }
    };

    _agoraService.onCallEnded = (String reason) {
      debugPrint('📴 ActiveCallPage: Call ended event. Reason: $reason');
      if (mounted) {
        _endCall(reason: reason);
      }
    };

    _agoraService.onCallError = (error) {
      debugPrint('❌ ActiveCallPage: Agora Error: $error');
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
      debugPrint('🔌 ActiveCallPage: Connection state: ${state.name}, reason: ${reason.name}');
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


    // Join Agora channel with static authentication
    debugPrint(
      '📞 ActiveCallPage: Joining Agora channel="${widget.channelName}" (static auth)',
    );

    if (mounted) {
      setState(() => _callStatus = 'Connecting...');
    }

    // Convert current user ID to int for Agora UID
    final currentUserId = AgoraConfig.uuidToUint32(widget.currentUserId);
    debugPrint('📞 ActiveCallPage: Using mapped UID for Agora: $currentUserId from UUID: ${widget.currentUserId}');

    final joined = await _agoraService.joinVoiceCall(
      channelName: widget.channelName,
      uid: currentUserId, // Use backend user ID as Agora UID
    );

    // Ensure speaker state is applied after join too
    await _agoraService.setSpeakerOn(_isSpeakerOn);

    debugPrint('📞 ActiveCallPage: joinVoiceCall result=$joined');
    if (!joined && mounted) {
      debugPrint('❌ ActiveCallPage: FAILED TO JOIN CHANNEL');
      setState(() {
        _callStatus = 'Connection failed';
        _isConnecting = false;
      });
      return;
    }

    // Start connection timeout — if remote user doesn't join within the
    // timeout, end the call automatically to avoid stuck 'Connecting...' state
    _connectionTimeoutTimer = Timer(_connectionTimeout, () {
      if (!_isConnected && !_hasEnded && mounted) {
        debugPrint(
          '⏰ ActiveCallPage: Connection timeout after ${_connectionTimeout.inSeconds}s. Other party never joined.',
        );
        _endCall(reason: 'Connection timed out');
      }
    });
  }

  void _startTimer() {
    _connectionTimeoutTimer?.cancel(); // Connection succeeded, cancel timeout
    _callTimer?.cancel();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _elapsedSeconds++);
      }
    });
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _connectionTimeoutTimer?.cancel();
    _callEndedSub?.cancel();
    _fadeController.dispose();
    // Clean up Agora callbacks
    _agoraService.onCallConnected = null;
    _agoraService.onRemoteUserJoined = null;
    _agoraService.onRemoteUserLeft = null;
    _agoraService.onCallEnded = null;
    // Only leave channel if _endCall hasn't already done it
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
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            _handleBackPress();
          },
          child: Scaffold(
            body: Container(
              width: double.infinity,
              height: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0F172A),
                    Color(0xFF1E293B),
                    Color(0xFF0F172A),
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
              child: SafeArea(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    children: [
                      SizedBox(height: responsive.spacing(16)),
                      // Top bar with back button and encryption label
                      _buildTopBar(responsive),
                      SizedBox(height: responsive.spacing(50)),
                      // Avatar
                      CallAvatar(
                        name: widget.contactName,
                        profilePicUrl: widget.contactProfilePic,
                        size: 110,
                        showRipple: !_isConnected,
                      ),
                      SizedBox(height: responsive.spacing(28)),
                      // Contact name
                      Text(
                        widget.contactName,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: responsive.size(26),
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                      SizedBox(height: responsive.spacing(8)),
                      // Status / Timer
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _isConnected
                            ? Text(
                                _formattedTime,
                                key: ValueKey(_formattedTime),
                                style: TextStyle(
                                  color: const Color(0xFF22C55E),
                                  fontSize: responsive.size(18),
                                  fontWeight: FontWeight.w600,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              )
                            : _buildConnectingStatus(responsive),
                      ),
                      const Spacer(),
                      // Audio wave visualization (decorative)
                      if (_isConnected) _buildAudioWave(responsive),
                      if (_isConnected)
                        SizedBox(height: responsive.spacing(40)),
                      // Action buttons
                      _buildActionButtons(responsive),
                      SizedBox(height: responsive.spacing(30)),
                      // End call button
                      EndCallButton(onTap: () => _endCall()),
                      SizedBox(height: responsive.spacing(40)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleBackPress() {
    if (_hasEnded) {
      Navigator.of(context).pop();
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Call in progress'),
        content: const Text('Please disconnect the call before leaving.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Continue call'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _endCall(reason: 'User ended call');
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('End call'),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(ResponsiveSize responsive) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: responsive.spacing(16)),
      child: Row(
        children: [
          GestureDetector(
            onTap: _handleBackPress,
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
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_rounded,
                color: Colors.white.withValues(alpha: 0.4),
                size: responsive.size(14),
              ),
              SizedBox(width: responsive.spacing(4)),
              Text(
                'End-to-end encrypted',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: responsive.size(12),
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

  Widget _buildConnectingStatus(ResponsiveSize responsive) {
    return Row(
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
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: responsive.size(15),
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildAudioWave(ResponsiveSize responsive) {
    return SizedBox(
      height: responsive.size(40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(20, (index) {
          final height =
              (index % 5 + 1) * responsive.size(5) +
              (_elapsedSeconds % 3 == index % 3 ? responsive.size(8) : 0);
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: responsive.size(3),
            height: height.clamp(responsive.size(4), responsive.size(35)),
            margin: EdgeInsets.symmetric(horizontal: responsive.size(1.5)),
            decoration: BoxDecoration(
              color: const Color(
                0xFF0EA5E9,
              ).withValues(alpha: 0.3 + (index % 5) * 0.1),
              borderRadius: BorderRadius.circular(responsive.size(2)),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildActionButtons(ResponsiveSize responsive) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: responsive.spacing(30)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          CallActionButton(
            icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
            label: _isMuted ? 'Unmute' : 'Mute',
            isActive: _isMuted,
            onTap: _toggleMute,
          ),
          CallActionButton(
            icon: _isSpeakerOn
                ? Icons.volume_up_rounded
                : Icons.volume_down_rounded,
            label: 'Speaker',
            isActive: _isSpeakerOn,
            onTap: _toggleSpeaker,
          ),
          CallActionButton(
            icon: Icons.bluetooth_audio_rounded,
            label: 'Bluetooth',
            onTap: () {
              // Cycle through Bluetooth or just try to enable it
              // Typically the OS handles this if a headset is connected,
              // but we can explicitly request the route.
              _agoraService.setAudioRoute(AudioRoute.routeBluetoothDeviceHfp);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Attempting to connect Bluetooth audio...'), duration: Duration(seconds: 1)),
              );
            },
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

  void _endCall({String? reason}) {
    if (_hasEnded) return;
    _hasEnded = true;
    _callTimer?.cancel();

    // Signal server that the call has ended
    if (widget.callId != null && widget.otherUserId != null) {
      CallSignalingService.instance
          .endActiveCall(
            callId: widget.callId!,
            otherUserId: widget.otherUserId!,
          )
          .then((ok) {
            if (!ok) {
              debugPrint(
                '❌ ActiveCallPage: endActiveCall failed for callId=${widget.callId}',
              );
            }
          });
    }

    ref.read(callProvider).endCall();
    _agoraService.leaveChannel();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}
