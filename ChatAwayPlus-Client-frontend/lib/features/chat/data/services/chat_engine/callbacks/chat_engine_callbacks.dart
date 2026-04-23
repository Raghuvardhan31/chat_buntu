part of '../chat_engine_service.dart';

mixin ChatEngineCallbacksMixin on ChatEngineServiceBase {
  final Set<String> _notifiedMessageIds = <String>{};

  @override
  Function(List<ChatMessageModel>)? _onMessagesUpdated;

  @override
  Function(ChatMessageModel)? _onNewMessage;

  Function(String messageId, String status)? _onMessageStatusChanged;
  Function(bool)? _onConnectionChanged;
  Function(UserStatus)? _onUserStatusChanged;
  Function(String)? _onEditMessageError;
  Function(String)? _onReactionError;
  Function(String)? _onDeleteMessageError;
  Function(String)? _onStarMessageError;
  Function(String)? _onUnstarMessageError;

  void onMessagesUpdated(Function(List<ChatMessageModel>) callback) {
    _onMessagesUpdated = callback;
  }

  void onEditMessageError(Function(String) callback) {
    _onEditMessageError = callback;
  }

  void onDeleteMessageError(Function(String) callback) {
    _onDeleteMessageError = callback;
  }

  void onReactionError(Function(String) callback) {
    _onReactionError = callback;
  }

  void onStarMessageError(Function(String) callback) {
    _onStarMessageError = callback;
  }

  void onUnstarMessageError(Function(String) callback) {
    _onUnstarMessageError = callback;
  }

  void onNewMessage(Function(ChatMessageModel) callback) {
    _onNewMessage = callback;
  }

  void onMessageStatusChanged(
    Function(String messageId, String status) callback,
  ) {
    _onMessageStatusChanged = callback;
  }

  void onConnectionChanged(Function(bool) callback) {
    _onConnectionChanged = callback;
  }

  void onUserStatusChanged(Function(UserStatus) callback) {
    _onUserStatusChanged = callback;
  }

  void clearEventCallbacks() {
    debugPrint(
      '🧹 ${ChatEngineService._logPrefix}: Clearing all event callbacks',
    );
    _onMessagesUpdated = null;
    _onNewMessage = null;
    _onMessageStatusChanged = null;
    _onConnectionChanged = null;
    _onUserStatusChanged = null;
    _onEditMessageError = null;
    _onReactionError = null;
    _onDeleteMessageError = null;
    _onStarMessageError = null;
    _onUnstarMessageError = null;
  }

  @override
  bool markNotificationShownIfFirst(String? messageId) {
    if (messageId == null || messageId.isEmpty) {
      return true;
    }
    if (_notifiedMessageIds.contains(messageId)) {
      return false;
    }
    _notifiedMessageIds.add(messageId);
    return true;
  }
}
