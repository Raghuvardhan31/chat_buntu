part of '../chat_engine_service.dart';

mixin ChatEngineStreamsMixin {
  final StreamController<ChatMessageModel> _globalNewMessageController =
      StreamController<ChatMessageModel>.broadcast();
  Stream<ChatMessageModel> get globalNewMessageStream =>
      _globalNewMessageController.stream;

  final StreamController<UserStatus> _userStatusStreamController =
      StreamController<UserStatus>.broadcast();
  Stream<UserStatus> get userStatusStream => _userStatusStreamController.stream;

  final StreamController<ChatMessageModel> _messageSentStreamController =
      StreamController<ChatMessageModel>.broadcast();
  Stream<ChatMessageModel> get messageSentStream =>
      _messageSentStreamController.stream;

  final StreamController<TypingStatus> _typingStreamController =
      StreamController<TypingStatus>.broadcast();
  Stream<TypingStatus> get typingStream => _typingStreamController.stream;

  final StreamController<bool> _connectionStreamController =
      StreamController<bool>.broadcast();
  Stream<bool> get connectionStream => _connectionStreamController.stream;

  final StreamController<ProfileUpdate> _profileUpdateController =
      StreamController<ProfileUpdate>.broadcast();
  Stream<ProfileUpdate> get profileUpdateStream =>
      _profileUpdateController.stream;

  final StreamController<ChatMessageStatusUpdate> _messageStatusController =
      StreamController<ChatMessageStatusUpdate>.broadcast();
  Stream<ChatMessageStatusUpdate> get messageStatusStream =>
      _messageStatusController.stream;

  final StreamController<String> _messageDeletedStreamController =
      StreamController<String>.broadcast();
  Stream<String> get messageDeletedStream =>
      _messageDeletedStreamController.stream;

  final StreamController<Map<String, dynamic>> _forceDisconnectController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get forceDisconnectStream =>
      _forceDisconnectController.stream;

  void _disposeStreams() {
    try {
      _globalNewMessageController.close();
    } catch (_) {}
    try {
      _userStatusStreamController.close();
    } catch (_) {}
    try {
      _messageSentStreamController.close();
    } catch (_) {}
    try {
      _profileUpdateController.close();
    } catch (_) {}
    try {
      _messageStatusController.close();
    } catch (_) {}
    try {
      _typingStreamController.close();
    } catch (_) {}
    try {
      _connectionStreamController.close();
    } catch (_) {}
    try {
      _messageDeletedStreamController.close();
    } catch (_) {}
    try {
      _forceDisconnectController.close();
    } catch (_) {}
  }
}
