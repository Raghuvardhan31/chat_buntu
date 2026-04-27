import 'dart:async';
import 'package:flutter/material.dart';
import 'package:chataway_plus/features/voice_call/data/config/agora_config.dart';
import 'package:chataway_plus/features/voice_call/data/services/agora_call_service.dart';

/// Simple test page to verify Agora RTC Engine works
/// Two devices joining the same channel should hear each other
class AgoraTestPage extends StatefulWidget {
  const AgoraTestPage({super.key});

  @override
  State<AgoraTestPage> createState() => _AgoraTestPageState();
}

class _AgoraTestPageState extends State<AgoraTestPage> {
  final _agoraService = AgoraCallService.instance;
  final _channelController = TextEditingController(text: AgoraConfig.testChannel);

  String _status = 'Not connected';
  bool _isJoined = false;
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  bool _isInitializing = false;
  int? _remoteUid;
  StreamSubscription<String>? _connectionSub;

  @override
  void initState() {
    super.initState();
    _initAgora();
  }

  Future<void> _initAgora() async {
    setState(() {
      _isInitializing = true;
      _status = 'Requesting permissions...';
    });

    // Request microphone permission
    final granted = await _agoraService.requestPermissions();
    if (!granted) {
      setState(() {
        _status = '❌ Microphone permission denied';
        _isInitializing = false;
      });
      return;
    }

    setState(() => _status = 'Initializing Agora engine...');

    // Initialize engine
    final initialized = await _agoraService.initialize();
    if (!initialized) {
      setState(() {
        _status = '❌ Failed to initialize Agora engine';
        _isInitializing = false;
      });
      return;
    }

    // Set up callbacks
    _agoraService.onCallConnected = () {
      if (mounted) {
        setState(() {
          _isJoined = true;
          _status = '✅ Connected — waiting for remote user...';
        });
      }
    };

    _agoraService.onRemoteUserJoined = (int uid) {
      if (mounted) {
        setState(() {
          _remoteUid = uid;
          _status = '🎙️ In call with user $uid — speak now!';
        });
      }
    };

    _agoraService.onRemoteUserLeft = (int uid, String reason) {
      if (mounted) {
        setState(() {
          _remoteUid = null;
          _status = '👤 Remote user left: $reason';
        });
      }
    };

    _agoraService.onCallEnded = (String reason) {
      if (mounted) {
        setState(() {
          _isJoined = false;
          _remoteUid = null;
          _status = '📴 Call ended: $reason';
        });
      }
    };

    // Listen to connection state changes
    _connectionSub = _agoraService.connectionStateStream.listen((state) {
      debugPrint('🔌 Connection state: $state');
    });

    setState(() {
      _isInitializing = false;
      _status = '✅ Ready — tap "Join Channel" to test';
    });
  }

  Future<void> _joinChannel() async {
    final channel = _channelController.text.trim();
    if (channel.isEmpty) {
      setState(() => _status = '⚠️ Enter a channel name');
      return;
    }

    setState(() => _status = '📞 Joining channel "$channel"...');

    // Use a test UID for agora test page
    final testUid = 12345; // Test user ID
    final joined = await _agoraService.joinVoiceCall(
          channelName: channel,
          uid: 0,
        );
    if (!joined) {
      setState(() => _status = '❌ Failed to join channel');
    }
  }

  Future<void> _leaveChannel() async {
    await _agoraService.leaveChannel();
    setState(() {
      _isJoined = false;
      _remoteUid = null;
      _isMuted = false;
      _isSpeakerOn = false;
      _status = '📴 Left channel — ready to rejoin';
    });
  }

  Future<void> _toggleMute() async {
    final newMuted = !_isMuted;
    await _agoraService.setMicMuted(newMuted);
    setState(() => _isMuted = newMuted);
  }

  Future<void> _toggleSpeaker() async {
    final newSpeaker = !_isSpeakerOn;
    await _agoraService.setSpeakerOn(newSpeaker);
    setState(() => _isSpeakerOn = newSpeaker);
  }

  @override
  void dispose() {
    _connectionSub?.cancel();
    _channelController.dispose();
    // Don't dispose the service — it's a singleton
    // Just leave the channel if we're in one
    if (_isJoined) {
      _agoraService.leaveChannel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agora Test'),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
      ),
      backgroundColor: const Color(0xFF1E293B),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isJoined
                      ? const Color(0xFF22C55E).withValues(alpha: 0.5)
                      : Colors.white.withValues(alpha: 0.1),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    _isJoined
                        ? (_remoteUid != null ? Icons.call : Icons.phone_in_talk)
                        : Icons.phone_disabled,
                    color: _isJoined ? const Color(0xFF22C55E) : Colors.white54,
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _status,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (_remoteUid != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Remote UID: $_remoteUid',
                        style: const TextStyle(
                          color: Color(0xFF22C55E),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Channel name input
            TextField(
              controller: _channelController,
              enabled: !_isJoined,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Channel Name',
                labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                hintText: 'Enter same channel on both devices',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                filled: true,
                fillColor: const Color(0xFF0F172A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(Icons.tag, color: Colors.white54),
              ),
            ),
            const SizedBox(height: 16),

            // Info text
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0EA5E9).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Color(0xFF0EA5E9), size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Use the same channel name on two devices to test voice calling.',
                      style: TextStyle(color: Color(0xFF0EA5E9), fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Join/Leave button
            if (_isInitializing)
              const Center(
                child: CircularProgressIndicator(color: Color(0xFF0EA5E9)),
              )
            else
              ElevatedButton.icon(
                onPressed: _isJoined ? _leaveChannel : _joinChannel,
                icon: Icon(_isJoined ? Icons.call_end : Icons.call),
                label: Text(
                  _isJoined ? 'Leave Channel' : 'Join Channel',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isJoined
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF22C55E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // Audio controls (only when in channel)
            if (_isJoined) ...[
              Row(
                children: [
                  Expanded(
                    child: _buildControlButton(
                      icon: _isMuted ? Icons.mic_off : Icons.mic,
                      label: _isMuted ? 'Unmute' : 'Mute',
                      isActive: _isMuted,
                      onTap: _toggleMute,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildControlButton(
                      icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_down,
                      label: 'Speaker',
                      isActive: _isSpeakerOn,
                      onTap: _toggleSpeaker,
                    ),
                  ),
                ],
              ),
            ],

            const Spacer(),

            // App ID display (for debugging)
            Text(
              'App ID: ${AgoraConfig.appId.substring(0, 8)}...',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: 11,
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
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF0EA5E9).withValues(alpha: 0.2)
              : const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive
                ? const Color(0xFF0EA5E9).withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isActive ? const Color(0xFF0EA5E9) : Colors.white70,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? const Color(0xFF0EA5E9) : Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
