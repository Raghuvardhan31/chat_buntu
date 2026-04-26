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
}
