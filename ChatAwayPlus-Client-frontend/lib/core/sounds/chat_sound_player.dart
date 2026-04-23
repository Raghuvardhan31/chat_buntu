import 'package:audioplayers/audioplayers.dart';

/// Centralized sound player for chat-related sounds.
///
/// Handles short UI effects like send-message ticks and
/// optional notification tones.
class ChatSoundPlayer {
  ChatSoundPlayer._internal();

  static final ChatSoundPlayer instance = ChatSoundPlayer._internal();

  final AudioPlayer _sendPlayer = AudioPlayer();
  final AudioPlayer _notificationPlayer = AudioPlayer();

  /// Play the send-message sound (short tick like WhatsApp).
  Future<void> playSendSound() async {
    try {
      await _sendPlayer.stop();
      await _sendPlayer.play(AssetSource('sounds/send_message_sound.mp3'));
    } catch (_) {
      // Silent failure - sound effects must never break chat flow.
    }
  }

  /// Play the notification sound (if used inside the app).
  Future<void> playNotificationSound() async {
    try {
      await _notificationPlayer.stop();
      await _notificationPlayer.play(
        AssetSource('sounds/notification_sound1.mp3'),
      );
    } catch (_) {
      // Silent failure.
    }
  }
}
