import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:chataway_plus/features/chat/data/socket/socket_exports.dart';
import 'package:chataway_plus/core/database/tables/chat/messages_table.dart';
import '../local/message_reactions_local_db.dart';
import 'package:chataway_plus/core/notifications/local/notification_local_service.dart';
import 'package:chataway_plus/features/contacts/data/datasources/contacts_database_service.dart';

/// Service for managing message reactions
/// Handles WebSocket communication and local database sync
class MessageReactionService {
  static final MessageReactionService _instance =
      MessageReactionService._internal();
  factory MessageReactionService() => _instance;
  MessageReactionService._internal();

  static MessageReactionService get instance => _instance;

  final WebSocketChatRepository _chatRepository =
      WebSocketChatRepository.instance;
  final MessageReactionsDatabaseService _databaseService =
      MessageReactionsDatabaseService.instance;

  String? _currentUserId;
  bool _isInitialized = false;

  final Set<String> _fetchRequestedMessageIds = <String>{};

  // Stream controller for reaction updates
  final StreamController<SocketReactionUpdatedResponse>
  _reactionUpdateController =
      StreamController<SocketReactionUpdatedResponse>.broadcast();

  Stream<SocketReactionUpdatedResponse> get reactionUpdateStream =>
      _reactionUpdateController.stream;

  // Stream controller for reaction errors
  final StreamController<String> _reactionErrorController =
      StreamController<String>.broadcast();

  Stream<String> get reactionErrorStream => _reactionErrorController.stream;

  /// Initialize the reaction service
  void initialize({required String currentUserId}) {
    if (_isInitialized && _currentUserId == currentUserId) {
      debugPrint(
        '✅ MessageReactionService: Already initialized for user $currentUserId',
      );
      return;
    }

    _currentUserId = currentUserId;
    _isInitialized = true;

    _setupSocketListeners();
    debugPrint('✅ MessageReactionService: Initialized for user $currentUserId');
  }

  /// Setup socket event listeners
  void _setupSocketListeners() {
    _chatRepository.onReactionUpdated((data) {
      _handleReactionUpdated(data);
    });

    _chatRepository.onReactionError((error) {
      _handleReactionError(error);
    });
  }

  /// Handle reaction-updated event from server
  void _handleReactionUpdated(Map<String, dynamic> data) async {
    debugPrint('🟢 ═══════════════════════════════════════════════════════');
    debugPrint('🟢 MessageReactionService: REACTION-UPDATED EVENT RECEIVED');
    debugPrint('🟢 Raw data: $data');
    debugPrint('🟢 ═══════════════════════════════════════════════════════');

    try {
      final response = SocketReactionUpdatedResponse.fromJson(data);

      if (response.messageId.trim().isEmpty) {
        return;
      }

      debugPrint('📦 Parsed Response:');
      debugPrint('  - MessageId: ${response.messageId}');
      debugPrint('  - UserId: ${response.userId}');
      debugPrint('  - Action: ${response.action}');
      debugPrint('  - Reactions count: ${response.reactions.length}');
      debugPrint('  - Timestamp: ${response.timestamp}');

      // Update local database
      final normalizedAction = response.action.toLowerCase().trim();

      if ((normalizedAction == 'added' ||
              normalizedAction == 'updated' ||
              normalizedAction == 'created') &&
          response.reactions.isEmpty &&
          !_fetchRequestedMessageIds.contains(response.messageId)) {
        _fetchRequestedMessageIds.add(response.messageId);
        unawaited(
          _chatRepository.getMessageReactions(messageId: response.messageId),
        );
      }
      if (normalizedAction == 'added' ||
          normalizedAction == 'updated' ||
          normalizedAction == 'created') {
        // Save or update reactions in local DB
        debugPrint(
          '💾 Syncing ${response.reactions.length} reactions to local database...',
        );

        try {
          final currentUserId = _currentUserId;
          final actorUserId = response.userId;

          final isFromOtherUser =
              currentUserId != null &&
              currentUserId.isNotEmpty &&
              actorUserId.isNotEmpty &&
              actorUserId != currentUserId;

          if (isFromOtherUser &&
              (normalizedAction == 'added' || normalizedAction == 'updated')) {
            String? actorName;
            String? actorProfilePic;

            try {
              final contact = await ContactsDatabaseService.instance
                  .getContactByUserId(actorUserId);
              if (contact != null) {
                actorName = contact.preferredDisplayName;
                actorProfilePic = contact.userDetails?.chatPictureUrl;
              }
            } catch (_) {}

            if (actorName == null || actorName.trim().isEmpty) {
              try {
                final actorReaction = response.reactions.firstWhere(
                  (r) => r.userId == actorUserId,
                );
                final fullName =
                    '${actorReaction.userFirstName ?? ''} ${actorReaction.userLastName ?? ''}'
                        .trim();
                if (fullName.isNotEmpty) {
                  actorName = fullName;
                }
                actorProfilePic ??= actorReaction.userChatPicture;
              } catch (_) {}
            }

            actorName ??= 'Someone';

            final emoji = (response.emoji ?? '').trim();
            if (emoji.isNotEmpty) {
              await NotificationLocalService.instance.showChatMessageNotification(
                notificationId:
                    'reaction_${response.messageId}_${response.timestamp.millisecondsSinceEpoch}',
                senderName: actorName,
                messageText: 'reacted $emoji',
                conversationId: actorUserId,
                senderId: actorUserId,
                senderProfilePic: actorProfilePic,
                messageType: 'reaction',
              );
            }
          }
        } catch (_) {}

        if (response.reactions.isNotEmpty) {
          for (var reaction in response.reactions) {
            debugPrint('  - Storing: ${reaction.emoji} by ${reaction.userId}');
          }
          await _databaseService.upsertReactions(response.reactions);
          debugPrint('✅ Reactions synced to local database');

          // Also update reactionsJson on the messages table for offline consistency
          await _syncReactionsJsonToMessage(response.messageId);

          // Clear from fetch request set since we got the reactions
          _fetchRequestedMessageIds.remove(response.messageId);
        }
      } else if (normalizedAction == 'removed') {
        // Remove reaction from local DB
        debugPrint('🗑️ Removing reaction from local database...');
        await _databaseService.removeReaction(
          messageId: response.messageId,
          userId: response.userId,
        );
        debugPrint('✅ Reaction removed from local database');

        // Also update reactionsJson on the messages table for offline consistency
        await _syncReactionsJsonToMessage(response.messageId);
      }

      // Notify listeners
      debugPrint('📢 Notifying listeners via stream...');
      _reactionUpdateController.add(response);
      debugPrint('✅ Stream notification sent');
    } catch (e) {
      debugPrint(
        '❌ MessageReactionService: Error handling reaction-updated: $e',
      );
    }
  }

  /// Handle reaction-error event from server
  void _handleReactionError(String error) {
    debugPrint('❌ MessageReactionService: Reaction error: $error');
    _reactionErrorController.add(error);
  }

  /// Add or update a reaction (WhatsApp-style: same emoji toggles, different emoji updates)
  Future<bool> addReaction({
    required String messageId,
    required String emoji,
  }) async {
    if (_currentUserId == null) {
      debugPrint(
        '❌ MessageReactionService: Cannot add reaction - user not initialized',
      );
      return false;
    }

    debugPrint('🔵 ═══════════════════════════════════════════════════════');
    debugPrint('🔵 MessageReactionService: ADD REACTION STARTED');
    debugPrint('🔵 MessageId: $messageId');
    debugPrint('🔵 Emoji: $emoji');
    debugPrint('🔵 UserId: $_currentUserId');
    debugPrint('🔵 ═══════════════════════════════════════════════════════');

    try {
      // Optimistically update local database
      debugPrint('📊 Checking existing reaction in database...');
      final existingReaction = await _databaseService.getUserReactionForMessage(
        messageId: messageId,
        userId: _currentUserId!,
      );
      debugPrint('📊 Existing reaction: ${existingReaction?.emoji ?? "none"}');

      // Check if it's a toggle (same emoji)
      if (existingReaction != null && existingReaction.emoji == emoji) {
        // Toggle off - remove reaction
        debugPrint('🔄 TOGGLE OFF: Same emoji detected, removing reaction');
        await _databaseService.removeReaction(
          messageId: messageId,
          userId: _currentUserId!,
        );
        debugPrint('✅ Reaction removed from local database');
      } else {
        // Add or update reaction
        if (existingReaction != null) {
          debugPrint(
            '🔄 UPDATE: Different emoji detected (${existingReaction.emoji} → $emoji)',
          );
        } else {
          debugPrint('➕ ADD NEW: No existing reaction, adding $emoji');
        }

        final reaction = MessageReaction(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          messageId: messageId,
          userId: _currentUserId!,
          emoji: emoji,
          createdAt: DateTime.now(),
          isSynced: false, // Will be synced when server responds
        );

        debugPrint('💾 Saving to local database: ${reaction.toJson()}');
        await _databaseService.upsertReaction(reaction);
        debugPrint('✅ Reaction saved to local database');
      }

      // Send to server via WebSocket
      debugPrint('📡 Emitting add-reaction event to server...');
      final success = await _chatRepository.addReaction(
        messageId: messageId,
        emoji: emoji,
      );

      if (!success) {
        debugPrint(
          '❌ MessageReactionService: Failed to send reaction to server',
        );
        debugPrint('⚠️ Socket may be disconnected or not authenticated');
        // Could rollback optimistic update here if needed
      } else {
        debugPrint('✅ Reaction event emitted successfully');
      }

      debugPrint('🔵 ═══════════════════════════════════════════════════════');
      return success;
    } catch (e) {
      debugPrint('❌ MessageReactionService: Error adding reaction: $e');
      return false;
    }
  }

  /// Remove a reaction
  Future<bool> removeReaction({required String messageId}) async {
    if (_currentUserId == null) {
      debugPrint(
        '❌ MessageReactionService: Cannot remove reaction - user not initialized',
      );
      return false;
    }

    try {
      // Optimistically remove from local database
      await _databaseService.removeReaction(
        messageId: messageId,
        userId: _currentUserId!,
      );

      // Send to server via WebSocket
      final success = await _chatRepository.removeReaction(
        messageId: messageId,
      );

      if (!success) {
        debugPrint(
          '⚠️ MessageReactionService: Failed to remove reaction from server',
        );
      }

      return success;
    } catch (e) {
      debugPrint('❌ MessageReactionService: Error removing reaction: $e');
      return false;
    }
  }

  /// Get reactions for a specific message (from local DB)
  Future<List<MessageReaction>> getReactionsForMessage(String messageId) async {
    try {
      return await _databaseService.getReactionsForMessage(messageId);
    } catch (e) {
      debugPrint('❌ MessageReactionService: Error getting reactions: $e');
      return [];
    }
  }

  /// Get user's reaction for a specific message
  Future<MessageReaction?> getUserReaction(String messageId) async {
    if (_currentUserId == null) return null;

    try {
      return await _databaseService.getUserReactionForMessage(
        messageId: messageId,
        userId: _currentUserId!,
      );
    } catch (e) {
      debugPrint('❌ MessageReactionService: Error getting user reaction: $e');
      return null;
    }
  }

  /// Request reactions for a message from server
  Future<void> fetchMessageReactions(String messageId) async {
    try {
      await _chatRepository.getMessageReactions(messageId: messageId);
    } catch (e) {
      debugPrint(
        '❌ MessageReactionService: Error fetching message reactions: $e',
      );
    }
  }

  /// Dispose service resources
  /// Sync reactions from message_reactions table back to messages table reactionsJson
  /// This ensures offline consistency — when chat reloads from local DB,
  /// reactions are already embedded in the message.
  Future<void> _syncReactionsJsonToMessage(String messageId) async {
    try {
      final reactions = await _databaseService.getReactionsForMessage(
        messageId,
      );
      final reactionsJsonList = reactions.map((r) => r.toJson()).toList();
      final reactionsJsonStr = reactionsJsonList.isEmpty
          ? null
          : jsonEncode(reactionsJsonList);

      await MessagesTable.instance.updateMessageReactions(
        messageId: messageId,
        reactionsJson: reactionsJsonStr ?? '',
      );
    } catch (e) {
      debugPrint('⚠️ _syncReactionsJsonToMessage error: $e');
    }
  }

  void dispose() {
    _reactionUpdateController.close();
    _reactionErrorController.close();
    _isInitialized = false;
    _currentUserId = null;
    debugPrint('✅ MessageReactionService: Disposed');
  }
}
