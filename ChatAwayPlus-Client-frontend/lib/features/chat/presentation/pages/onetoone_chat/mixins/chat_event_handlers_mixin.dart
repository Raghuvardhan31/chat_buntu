import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chataway_plus/core/snackbar/app_snackbar.dart';
import 'package:chataway_plus/features/chat/data/services/chat_engine/index.dart';
import 'package:chataway_plus/features/chat/data/services/local/message_reactions_local_db.dart';
import 'package:chataway_plus/features/chat/data/socket/socket_models/index.dart';
import 'package:chataway_plus/features/chat/presentation/providers/chat_page_providers/chat_page_provider.dart';
import 'package:chataway_plus/features/chat/presentation/providers/chat_page_providers/user_status_provider.dart';
import 'package:chataway_plus/features/chat/presentation/providers/message_reactions/message_reaction_providers.dart';
import 'package:chataway_plus/features/chat/models/chat_message_model.dart';

mixin ChatEventHandlersMixin<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  ChatEngineService get unifiedChatService;
  Map<String, String> get providerParams;
  String get currentUserId;

  String? _lastShownEditError;
  String? _lastShownReactionError;
  String? _lastShownDeleteError;

  double snackbarBottomPosition();

  void setupEventListeners() {
    final otherUserId = providerParams['otherUserId']!;

    unifiedChatService.onMessagesUpdated((updatedMessages) {
      if (!mounted) return;

      // CRITICAL: Only accept messages that belong to THIS conversation.
      // The onMessagesUpdated callback is global (singleton ChatEngineService),
      // so a background sync for a different chat could fire this callback
      // with another user's messages — causing a brief flash of wrong chat.
      if (updatedMessages.isNotEmpty) {
        final first = updatedMessages.first;
        final belongsToThisChat =
            (first.senderId == currentUserId &&
                first.receiverId == otherUserId) ||
            (first.senderId == otherUserId &&
                first.receiverId == currentUserId);
        if (!belongsToThisChat) return;
      }

      final notifier = ref.read(
        chatPageNotifierProvider(providerParams).notifier,
      );

      notifier.refreshFromLocalMessages(updatedMessages);

      // Sync reactions from server history into message_reactions table
      loadReactionsForMessages(updatedMessages);
    });

    unifiedChatService.onNewMessage((newMessage) {
      if (!mounted) return;

      // Only accept messages belonging to THIS conversation
      final belongsToThisChat =
          (newMessage.senderId == currentUserId &&
              newMessage.receiverId == otherUserId) ||
          (newMessage.senderId == otherUserId &&
              newMessage.receiverId == currentUserId);
      if (!belongsToThisChat) return;

      // Only add incoming messages from other users to prevent duplicates
      // Our own sent messages are already handled optimistically
      if (newMessage.senderId != currentUserId) {
        ref
            .read(chatPageNotifierProvider(providerParams).notifier)
            .addIncomingMessage(newMessage);
      }
    });

    unifiedChatService.onMessageStatusChanged((messageId, status) {
      if (!mounted) return;
      try {
        ref
            .read(chatPageNotifierProvider(providerParams).notifier)
            .updateMessageStatus(messageId, status);
      } catch (e) {
        debugPrint('❌ Status update error: $e');
      }
    });

    unifiedChatService.onConnectionChanged((isConnected) {
      if (!mounted) return;

      if (!isConnected) {
        debugPrint('🔌 Connection lost - clearing all user online statuses');
        ref.read(userStatusProvider.notifier).clearAllStatuses();
      } else {
        debugPrint(
          '🔌 Connection restored - user statuses will refresh from server',
        );
      }
    });

    unifiedChatService.onEditMessageError((error) {
      if (!mounted) return;
      if (error == _lastShownEditError) return;
      _lastShownEditError = error;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await AppSnackbar.showError(
          context,
          error,
          bottomPosition: snackbarBottomPosition(),
        );
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) _lastShownEditError = null;
        });
      });
    });

    unifiedChatService.onReactionError((error) {
      if (!mounted) return;
      if (error == _lastShownReactionError) return;
      _lastShownReactionError = error;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await AppSnackbar.showError(
          context,
          error,
          bottomPosition: snackbarBottomPosition(),
        );
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) _lastShownReactionError = null;
        });
      });
    });

    unifiedChatService.onDeleteMessageError((error) {
      if (!mounted) return;
      if (error == _lastShownDeleteError) return;
      _lastShownDeleteError = error;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await AppSnackbar.showError(
          context,
          error,
          bottomPosition: snackbarBottomPosition(),
        );
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) _lastShownDeleteError = null;
        });
      });
    });
  }

  Future<void> loadReactionsForMessages(List<ChatMessageModel> messages) async {
    try {
      final reactionNotifier = ref.read(messageReactionProvider);
      final reactionsDb = MessageReactionsDatabaseService.instance;

      // Phase 1: Batch all DB sync operations
      // Collect all reactions to upsert and message IDs to clear in one pass
      final allReactionsToUpsert = <MessageReaction>[];
      final messageIdsToClear = <String>[];

      for (final message in messages) {
        if (message.hasReactions) {
          final parsed = _parseReactionsFromJson(
            message.reactionsJson!,
            message.id,
          );
          if (parsed.isNotEmpty) {
            allReactionsToUpsert.addAll(parsed);
          } else {
            messageIdsToClear.add(message.id);
          }
        } else {
          messageIdsToClear.add(message.id);
        }
      }

      // Single batch upsert for all reactions across all messages
      if (allReactionsToUpsert.isNotEmpty) {
        await reactionsDb.upsertReactions(allReactionsToUpsert);
      }

      // Clear reactions for messages that have none (parallel)
      if (messageIdsToClear.isNotEmpty) {
        await Future.wait(
          messageIdsToClear.map(
            (id) => reactionsDb.removeAllReactionsForMessage(id),
          ),
        );
      }

      // Phase 2: Load all reactions from DB in one batch (parallel + single notify)
      final allMessageIds = messages.map((m) => m.id).toList();
      await reactionNotifier.loadReactionsForMessagesBatch(allMessageIds);

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('❌ Error loading reactions: $e');
    }
  }

  /// Parse reactions from JSON string, handling both flat and grouped formats.
  /// Flat: [{id, userId, emoji, createdAt, user: {...}}]
  /// Grouped: [{emoji, count, users: [{id, firstName, lastName, chat_picture}]}]
  List<MessageReaction> _parseReactionsFromJson(
    String reactionsJsonStr,
    String messageId,
  ) {
    try {
      final decoded = jsonDecode(reactionsJsonStr);
      if (decoded is! List || decoded.isEmpty) return [];

      final first = decoded.first;
      if (first is! Map) return [];

      // Detect grouped format by checking for 'users' key
      final isGrouped = first.containsKey('users');

      if (isGrouped) {
        final reactions = <MessageReaction>[];
        for (final group in decoded) {
          if (group is! Map) continue;
          final groupMap = Map<String, dynamic>.from(group);
          final emoji = groupMap['emoji']?.toString() ?? '';
          final users = groupMap['users'];
          if (users is! List) continue;

          for (final user in users) {
            if (user is! Map) continue;
            final userMap = Map<String, dynamic>.from(user);
            final userId = userMap['id']?.toString() ?? '';
            if (userId.isEmpty) continue;

            reactions.add(
              MessageReaction(
                id: '${messageId}_$userId',
                messageId: messageId,
                userId: userId,
                emoji: emoji,
                createdAt: DateTime.now(),
                userFirstName: userMap['firstName']?.toString(),
                userLastName: userMap['lastName']?.toString(),
                userChatPicture:
                    userMap['chat_picture']?.toString() ??
                    userMap['chatPicture']?.toString() ??
                    userMap['profile_pic']?.toString(),
                isSynced: true,
              ),
            );
          }
        }
        return reactions;
      } else {
        // Flat format — use MessageReaction.fromJson
        return decoded
            .map<MessageReaction>((item) {
              if (item is! Map) {
                return MessageReaction(
                  id: '',
                  messageId: messageId,
                  userId: '',
                  emoji: '',
                  createdAt: DateTime.now(),
                  isSynced: true,
                );
              }
              final map = Map<String, dynamic>.from(item);
              final parsed = MessageReaction.fromJson(map);
              return parsed.copyWith(
                messageId: parsed.messageId.isEmpty ? messageId : null,
                isSynced: true,
              );
            })
            .where((r) => r.userId.isNotEmpty && r.emoji.isNotEmpty)
            .toList();
      }
    } catch (e) {
      debugPrint('⚠️ _parseReactionsFromJson error: $e');
      return [];
    }
  }
}
