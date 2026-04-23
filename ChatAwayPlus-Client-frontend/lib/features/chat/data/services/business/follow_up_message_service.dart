// lib/features/chat/data/services/business/follow_up_message_service.dart

import 'package:flutter/foundation.dart';
import 'package:chataway_plus/core/storage/token_storage.dart';
import 'package:chataway_plus/features/chat/data/socket/websocket_repository/websocket_chat_repository.dart';
import 'package:chataway_plus/features/chat/models/chat_message_model.dart';

/// Service for handling follow-up text messages
///
/// This service provides business logic for sending and managing follow-up messages
/// which are continuation messages in a conversation thread.
class FollowUpMessageService {
  static final FollowUpMessageService _instance =
      FollowUpMessageService._internal();
  factory FollowUpMessageService() => _instance;
  FollowUpMessageService._internal();

  static FollowUpMessageService get instance => _instance;

  final WebSocketChatRepository _chatRepository =
      WebSocketChatRepository.instance;
  final TokenSecureStorage _tokenStorage = TokenSecureStorage();

  /// Send a follow-up text message
  ///
  /// [receiverId] - The ID of the user receiving the message
  /// [messageText] - The follow-up message content
  ///
  /// Returns true if the message was sent successfully
  Future<bool> sendFollowUpMessage({
    required String receiverId,
    required String messageText,
  }) async {
    try {
      if (messageText.trim().isEmpty) {
        debugPrint(
          '❌ FollowUpMessageService: Cannot send empty follow-up message',
        );
        return false;
      }

      final currentUserId = await _tokenStorage.getCurrentUserIdUUID();
      if (currentUserId == null || currentUserId.isEmpty) {
        debugPrint('❌ FollowUpMessageService: No current user ID found');
        return false;
      }

      // Send follow-up message via WebSocket
      final success = await _chatRepository.sendMessage(
        receiverId: receiverId,
        message: messageText.trim(),
        messageType: 'text',
      );

      if (success) {
        debugPrint(
          '✅ FollowUpMessageService: Follow-up message sent successfully',
        );
      } else {
        debugPrint(
          '❌ FollowUpMessageService: Failed to send follow-up message',
        );
      }

      return success;
    } catch (e) {
      debugPrint(
        '❌ FollowUpMessageService: Error sending follow-up message: $e',
      );
      return false;
    }
  }

  /// Send multiple follow-up messages in sequence
  ///
  /// [receiverId] - The ID of the user receiving the messages
  /// [messages] - List of follow-up message texts
  /// [delayBetweenMessages] - Delay between sending each message (default: 1 second)
  ///
  /// Returns the number of messages sent successfully
  Future<int> sendMultipleFollowUpMessages({
    required String receiverId,
    required List<String> messages,
    Duration delayBetweenMessages = const Duration(seconds: 1),
  }) async {
    int successCount = 0;

    for (int i = 0; i < messages.length; i++) {
      final message = messages[i];
      if (message.trim().isEmpty) continue;

      final success = await sendFollowUpMessage(
        receiverId: receiverId,
        messageText: message,
      );

      if (success) {
        successCount++;
      }

      // Add delay between messages (except after the last message)
      if (i < messages.length - 1) {
        await Future.delayed(delayBetweenMessages);
      }
    }

    debugPrint(
      '✅ FollowUpMessageService: Sent $successCount/${messages.length} follow-up messages',
    );
    return successCount;
  }

  /// Check if a message is a follow-up message
  ///
  /// [message] - The ChatMessageModel to check
  ///
  /// Returns true if the message is marked as a follow-up
  bool isFollowUpMessage(ChatMessageModel message) {
    // Placeholder - follow-up detection can be added later
    return false;
  }

  /// Get follow-up message indicator text for UI
  ///
  /// Returns a string that can be displayed in the UI to indicate follow-up messages
  String getFollowUpIndicator() {
    return '↳'; // Unicode arrow indicating continuation/follow-up
  }

  /// Validate follow-up message content
  ///
  /// [messageText] - The message text to validate
  ///
  /// Returns validation result with error message if invalid
  FollowUpMessageValidation validateFollowUpMessage(String messageText) {
    if (messageText.trim().isEmpty) {
      return FollowUpMessageValidation(
        isValid: false,
        errorMessage: 'Follow-up message cannot be empty',
      );
    }

    if (messageText.length > 4000) {
      return FollowUpMessageValidation(
        isValid: false,
        errorMessage: 'Follow-up message is too long (max 4000 characters)',
      );
    }

    return FollowUpMessageValidation(isValid: true);
  }
}

/// Validation result for follow-up messages
class FollowUpMessageValidation {
  final bool isValid;
  final String? errorMessage;

  FollowUpMessageValidation({required this.isValid, this.errorMessage});
}
