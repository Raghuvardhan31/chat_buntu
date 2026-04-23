part of '../chat_engine_service.dart';

/// ChatEngineMessageOpsMixin - Message Operations
///
/// Handles public message operations:
/// - editMessage
/// - starMessage / unstarMessage
/// - deleteMessage
/// - addReaction
mixin ChatEngineMessageOpsMixin on ChatEngineServiceBase {
  /// Edit a message
  Future<bool> editMessage({
    required String chatId,
    required String newMessage,
  }) async {
    try {
      await _chatRepository.editMessage(chatId: chatId, newMessage: newMessage);
      return true;
    } catch (e) {
      final error = e.toString();
      debugPrint(' ChatEngineService: editMessage failed: $error');
      try {
        (this as ChatEngineService)._onEditMessageError?.call(error);
      } catch (_) {}
      return false;
    }
  }

  /// Star a message
  Future<bool> starMessage({required String chatId}) async {
    try {
      final ok = await _chatRepository.starMessage(chatId: chatId);
      if (!ok) {
        try {
          (this as ChatEngineService)._onStarMessageError?.call(
            'Failed to star message',
          );
        } catch (_) {}
      }
      return ok;
    } catch (e) {
      final error = e.toString();
      debugPrint(' ChatEngineService: starMessage failed: $error');
      try {
        (this as ChatEngineService)._onStarMessageError?.call(error);
      } catch (_) {}
      return false;
    }
  }

  /// Unstar a message
  Future<bool> unstarMessage({required String chatId}) async {
    try {
      final ok = await _chatRepository.unstarMessage(chatId: chatId);
      if (!ok) {
        try {
          (this as ChatEngineService)._onUnstarMessageError?.call(
            'Failed to unstar message',
          );
        } catch (_) {}
      }
      return ok;
    } catch (e) {
      final error = e.toString();
      debugPrint(' ChatEngineService: unstarMessage failed: $error');
      try {
        (this as ChatEngineService)._onUnstarMessageError?.call(error);
      } catch (_) {}
      return false;
    }
  }

  /// Delete a message
  Future<bool> deleteMessage({
    required String chatId,
    required String deleteType,
  }) async {
    try {
      final ok = await _chatRepository.deleteMessage(
        chatId: chatId,
        deleteType: deleteType,
      );
      if (!ok) {
        try {
          (this as ChatEngineService)._onDeleteMessageError?.call(
            'Failed to delete message',
          );
        } catch (_) {}
      }
      return ok;
    } catch (e) {
      final error = e.toString();
      debugPrint(' ChatEngineService: deleteMessage failed: $error');
      try {
        (this as ChatEngineService)._onDeleteMessageError?.call(error);
      } catch (_) {}
      return false;
    }
  }

  /// Add reaction to a message
  Future<bool> addReaction({
    required String chatId,
    required String emoji,
  }) async {
    try {
      final ok = await _chatRepository.addReaction(
        messageId: chatId,
        emoji: emoji,
      );
      if (!ok) {
        try {
          (this as ChatEngineService)._onReactionError?.call(
            'Failed to update reaction',
          );
        } catch (_) {}
      }
      return ok;
    } catch (e) {
      final error = e.toString();
      debugPrint(' ChatEngineService: addReaction failed: $error');
      try {
        (this as ChatEngineService)._onReactionError?.call(error);
      } catch (_) {}
      return false;
    }
  }
}
