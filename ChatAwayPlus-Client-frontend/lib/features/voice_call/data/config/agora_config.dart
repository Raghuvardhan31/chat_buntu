import 'package:flutter/foundation.dart';

/// Agora RTC configuration
/// Static mode: APP ID only (no tokens required)
/// Uses Agora's testing/development mode for simplicity
class AgoraConfig {
  AgoraConfig._();

  /// Agora App ID — ChatAway+ project (static authentication)
  /// Production: consider loading from environment/remote config
  static const String appId = 'fdae42cbb6f74e03ae0756be1ed3be67';

  /// Default channel name for testing
  static const String testChannel = 'test_channel';

  /// Generate deterministic channel name for 1-to-1 calls
  /// Format: CHAT_<smallerId>_<largerId>
  static String generateOneToOneChannelName(String userId1, String userId2) {
    // Sort IDs to ensure same channel name regardless of who initiates
    final ids = [userId1, userId2]..sort();
    final channelName = 'CHAT_${ids[0]}_${ids[1]}';
    debugPrint('🔧 AgoraConfig: Generated 1-to-1 channel: $channelName');
    return channelName;
  }

  /// Map a string UUID to a 32-bit unsigned integer for Agora UIDs
  /// Agora UIDs must be integers.
  static int uuidToUint32(String uuid) {
    if (uuid.isEmpty) return 0;
    // Simple deterministic hash that fits in 32-bit
    return uuid.hashCode.abs() & 0xFFFFFFFF;
  }

  /// Generate deterministic channel name for group calls
  /// Format: GROUP_<chatRoomId>
  static String generateGroupChannelName(String chatRoomId) {
    final channelName = 'GROUP_$chatRoomId';
    debugPrint(
      '🔧 AgoraConfig: Generated group channel: $channelName for room $chatRoomId',
    );
    return channelName;
  }
}
