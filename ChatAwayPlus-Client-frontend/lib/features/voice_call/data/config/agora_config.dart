/// Agora RTC configuration
/// Secure mode: APP ID + Token (token fetched from backend)
/// App Certificate is kept server-side only — never in client code
class AgoraConfig {
  AgoraConfig._();

  /// Agora App ID — ChatAway+ project (secure mode)
  /// Production: consider loading from environment/remote config
  static const String appId = '7c90c7a383ec49bc9d8a82d35c7c5be2';

  /// Token — fetched from backend before joining a channel
  /// Empty string for now until backend token endpoint is ready
  static const String token = '';

  /// Default channel name for testing
  static const String testChannel = 'chataway_test';
}
