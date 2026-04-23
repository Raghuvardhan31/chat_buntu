import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:chataway_plus/features/chat/data/socket/socket_models/index.dart';
import 'package:chataway_plus/features/chat/data/services/business/message_reaction_service.dart';
import 'package:chataway_plus/features/profile/data/datasources/profile_local_datasource.dart';
import 'package:chataway_plus/features/profile/data/datasources/profile_remote_datasource.dart';
import 'package:chataway_plus/core/storage/token_storage.dart';
import 'message_reaction_state.dart';

/// Notifier for managing message reactions
class MessageReactionNotifier extends ChangeNotifier {
  final MessageReactionService _reactionService;
  final ProfileLocalDataSource _profileDataSource;
  String _currentUserId = '';
  String get currentUserId => _currentUserId;

  final Set<String> _serverFetchRequestedMessageIds = <String>{};

  // Cached current user profile data for optimistic updates
  String? _currentUserFirstName;
  String? _currentUserLastName;
  String? _currentUserChatPicture;

  MessageReactionState _state = const MessageReactionState();
  MessageReactionState get state => _state;

  StreamSubscription<SocketReactionUpdatedResponse>?
  _reactionUpdateSubscription;
  StreamSubscription<String>? _reactionErrorSubscription;

  MessageReactionNotifier({
    String currentUserId = '',
    MessageReactionService? reactionService,
    ProfileLocalDataSource? profileDataSource,
  }) : _currentUserId = currentUserId,
       _reactionService = reactionService ?? MessageReactionService.instance,
       _profileDataSource = profileDataSource ?? ProfileLocalDataSourceImpl() {
    _initialize();
  }

  Future<void> _initialize() async {
    // Load userId internally if not provided
    if (_currentUserId.isEmpty) {
      final tokenStorage = TokenSecureStorage();
      _currentUserId = await tokenStorage.getCurrentUserIdUUID() ?? '';
      if (kDebugMode) {
        debugPrint('📱 MessageReactionNotifier initialized');
      }
    }

    // Load current user profile data for optimistic updates
    await _loadCurrentUserProfile();

    // Initialize the reaction service
    _reactionService.initialize(currentUserId: _currentUserId);

    // Listen to reaction updates
    _reactionUpdateSubscription = _reactionService.reactionUpdateStream.listen(
      _handleReactionUpdate,
      onError: (error) {
        if (kDebugMode) {
          debugPrint(
            '❌ MessageReactionNotifier: Error in reaction stream: $error',
          );
        }
      },
    );

    // Listen to reaction errors
    _reactionErrorSubscription = _reactionService.reactionErrorStream.listen(
      _handleReactionError,
      onError: (error) {
        if (kDebugMode) {
          debugPrint(
            '❌ MessageReactionNotifier: Error in error stream: $error',
          );
        }
      },
    );
  }

  /// Load current user profile data for optimistic updates
  Future<void> _loadCurrentUserProfile() async {
    try {
      final profile = await _profileDataSource.getProfile();
      if (profile != null) {
        _currentUserFirstName = profile.firstName;
        _currentUserLastName = profile.lastName;
        _currentUserChatPicture = profile.profilePic;

        // If profile picture is null from local DB, try fetching from backend
        if (_currentUserChatPicture == null ||
            _currentUserChatPicture!.isEmpty) {
          try {
            final remoteDataSource = ProfileRemoteDataSourceImpl();
            final remoteProfile = await remoteDataSource
                .getCurrentUserProfile();
            if (remoteProfile.isSuccess && remoteProfile.data != null) {
              final remotePic = remoteProfile.data!.profilePic;
              if (remotePic != null && remotePic.isNotEmpty) {
                _currentUserChatPicture = remotePic;

                // Also update local DB for next time
                await _profileDataSource.updateProfilePicture(remotePic);
              }
            }
          } catch (e) {
            if (kDebugMode) {
              debugPrint('⚠️ MessageReactionNotifier: profile fetch failed');
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ MessageReactionNotifier: profile load failed');
      }
    }
  }

  /// Handle reaction update from service
  void _handleReactionUpdate(SocketReactionUpdatedResponse response) {
    if (kDebugMode) {
      debugPrint(
        '🔔 Reaction update: ${response.action} message=${response.messageId} count=${response.reactions.length}',
      );
    }

    final Map<String, List<MessageReaction>> updatedReactions = Map.from(
      _state.messageReactions,
    );

    final updatedLoadedIds = Set<String>.from(_state.loadedMessageIds)
      ..add(response.messageId);

    final existing = List<MessageReaction>.from(
      updatedReactions[response.messageId] ?? const <MessageReaction>[],
    );

    // IMPORTANT:
    // Some backends send a reaction-updated event with an empty `reactions` array
    // (or partial payload) briefly after the optimistic update.
    // If we blindly overwrite state with an empty list, reactions will flicker/disappear
    // until the user reloads the chat (which re-reads from local DB).
    if (response.reactions.isEmpty) {
      final normalizedAction = response.action.toLowerCase().trim();
      if (normalizedAction == 'removed') {
        existing.removeWhere((r) => r.userId == response.userId);
        if (existing.isEmpty) {
          updatedReactions.remove(response.messageId);
        } else {
          updatedReactions[response.messageId] = existing;
        }
      } else {
        // For "added" with empty reactions, keep current state.
        // If we have no cached state yet, load from local DB.
        if (existing.isEmpty) {
          unawaited(loadReactionsForMessage(response.messageId));
        }
      }
    } else {
      updatedReactions[response.messageId] = response.reactions;
    }

    _state = _state.copyWith(
      messageReactions: updatedReactions,
      loadedMessageIds: updatedLoadedIds,
      error: null,
    );
    if (hasListeners) {
      notifyListeners();
    }
  }

  /// Handle reaction error
  void _handleReactionError(String error) {
    _state = _state.copyWith(error: error);
    if (hasListeners) {
      notifyListeners();
    }

    // Clear error after a delay
    Future.delayed(const Duration(seconds: 3), () {
      if (_state.error == error && hasListeners) {
        _state = _state.copyWith(error: null);
        notifyListeners();
      }
    });
  }

  /// Add or update a reaction (WhatsApp-style)
  Future<void> addReaction({
    required String messageId,
    required String emoji,
  }) async {
    if (kDebugMode) {
      debugPrint('🎯 Reaction action: add message=$messageId emoji=$emoji');
    }

    // Ensure userId is loaded
    if (_currentUserId.isEmpty) {
      final tokenStorage = TokenSecureStorage();
      _currentUserId = await tokenStorage.getCurrentUserIdUUID() ?? '';
    }

    try {
      _state = _state.copyWith(isLoading: true);

      // Reload profile if not loaded yet
      if (_currentUserFirstName == null || _currentUserChatPicture == null) {
        await _loadCurrentUserProfile();
      }

      final Map<String, List<MessageReaction>> updatedReactions = Map.from(
        _state.messageReactions,
      );

      final updatedLoadedIds = Set<String>.from(_state.loadedMessageIds)
        ..add(messageId);

      // Get existing reactions for this message
      final existingReactions = List<MessageReaction>.from(
        updatedReactions[messageId] ?? [],
      );

      MessageReaction? existingUserReaction;
      try {
        existingUserReaction = existingReactions.firstWhere(
          (r) => r.userId == _currentUserId,
        );
      } catch (_) {
        existingUserReaction = null;
      }

      // WhatsApp-style toggle: tapping the same emoji again removes it.
      final isToggleOff =
          existingUserReaction != null && existingUserReaction.emoji == emoji;

      if (isToggleOff) {
        existingReactions.removeWhere((r) => r.userId == _currentUserId);
        if (existingReactions.isEmpty) {
          updatedReactions.remove(messageId);
        } else {
          updatedReactions[messageId] = existingReactions;
        }

        _state = _state.copyWith(
          messageReactions: updatedReactions,
          loadedMessageIds: updatedLoadedIds,
        );
        notifyListeners();

        final success = await _reactionService.addReaction(
          messageId: messageId,
          emoji: emoji,
        );

        if (!success) {
          _state = _state.copyWith(
            isLoading: false,
            error: 'Failed to remove reaction',
          );
          notifyListeners();
          unawaited(loadReactionsForMessage(messageId));
        } else {
          _state = _state.copyWith(isLoading: false);
          notifyListeners();
        }

        return;
      }

      // OPTIMISTIC UPDATE: Add reaction to local state immediately with user profile data
      final newReaction = MessageReaction(
        id: 'local_${DateTime.now().millisecondsSinceEpoch}',
        messageId: messageId,
        userId: _currentUserId,
        emoji: emoji,
        createdAt: DateTime.now(),
        userFirstName: _currentUserFirstName,
        userLastName: _currentUserLastName,
        userChatPicture: _currentUserChatPicture,
        isSynced: false,
      );

      // Remove any existing reaction from current user (WhatsApp-style: one reaction per user)
      existingReactions.removeWhere((r) => r.userId == _currentUserId);

      // Add the new reaction
      existingReactions.add(newReaction);
      updatedReactions[messageId] = existingReactions;

      _state = _state.copyWith(
        messageReactions: updatedReactions,
        loadedMessageIds: updatedLoadedIds,
      );
      notifyListeners();
      final success = await _reactionService.addReaction(
        messageId: messageId,
        emoji: emoji,
      );

      if (!success) {
        _state = _state.copyWith(
          isLoading: false,
          error: 'Failed to add reaction',
        );
        notifyListeners();
      } else {
        _state = _state.copyWith(isLoading: false);
        notifyListeners();
      }
    } catch (e) {
      _state = _state.copyWith(
        isLoading: false,
        error: 'Error adding reaction: $e',
      );
      notifyListeners();
    }
  }

  /// Remove a reaction
  Future<void> removeReaction({required String messageId}) async {
    try {
      // Ensure userId is loaded
      if (_currentUserId.isEmpty) {
        final tokenStorage = TokenSecureStorage();
        _currentUserId = await tokenStorage.getCurrentUserIdUUID() ?? '';
      }

      _state = _state.copyWith(isLoading: true);
      notifyListeners();

      // OPTIMISTIC UPDATE: remove from local state immediately
      final Map<String, List<MessageReaction>> updatedReactions = Map.from(
        _state.messageReactions,
      );
      final updatedLoadedIds = Set<String>.from(_state.loadedMessageIds)
        ..add(messageId);
      final existingReactions = List<MessageReaction>.from(
        updatedReactions[messageId] ?? const <MessageReaction>[],
      );
      existingReactions.removeWhere((r) => r.userId == _currentUserId);
      if (existingReactions.isEmpty) {
        updatedReactions.remove(messageId);
      } else {
        updatedReactions[messageId] = existingReactions;
      }
      _state = _state.copyWith(
        messageReactions: updatedReactions,
        loadedMessageIds: updatedLoadedIds,
      );
      notifyListeners();

      final success = await _reactionService.removeReaction(
        messageId: messageId,
      );

      if (!success) {
        _state = _state.copyWith(
          isLoading: false,
          error: 'Failed to remove reaction',
        );
        notifyListeners();
        unawaited(loadReactionsForMessage(messageId));
      } else {
        _state = _state.copyWith(isLoading: false);
        notifyListeners();
      }
    } catch (e) {
      _state = _state.copyWith(
        isLoading: false,
        error: 'Error removing reaction: $e',
      );
      notifyListeners();
      unawaited(loadReactionsForMessage(messageId));
    }
  }

  /// Load reactions for a message from local database
  Future<void> loadReactionsForMessage(
    String messageId, {
    bool fetchFromServerIfEmpty = true,
  }) async {
    try {
      final reactions = await _reactionService.getReactionsForMessage(
        messageId,
      );

      if (fetchFromServerIfEmpty &&
          reactions.isEmpty &&
          !_serverFetchRequestedMessageIds.contains(messageId)) {
        _serverFetchRequestedMessageIds.add(messageId);
        unawaited(_reactionService.fetchMessageReactions(messageId));
      }

      final Map<String, List<MessageReaction>> updatedReactions = Map.from(
        _state.messageReactions,
      );
      updatedReactions[messageId] = reactions;

      final updatedLoadedIds = Set<String>.from(_state.loadedMessageIds)
        ..add(messageId);

      _state = _state.copyWith(
        messageReactions: updatedReactions,
        loadedMessageIds: updatedLoadedIds,
      );

      // Notify listeners if notifier is still active (prevents crashes during disposal)
      try {
        notifyListeners();
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️ MessageReactionNotifier: notifyListeners failed: $e');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ MessageReactionNotifier: loadReactions failed');
      }
    }
  }

  /// Load reactions for multiple messages at once from local database.
  /// Updates state in a single batch with one notifyListeners() call.
  /// This eliminates the 1-second delay caused by sequential per-message loads.
  Future<void> loadReactionsForMessagesBatch(List<String> messageIds) async {
    if (messageIds.isEmpty) return;
    try {
      // Load all reactions in parallel
      final futures = messageIds.map(
        (id) => _reactionService.getReactionsForMessage(id),
      );
      final results = await Future.wait(futures);

      // Build updated state in one pass
      final Map<String, List<MessageReaction>> updatedReactions = Map.from(
        _state.messageReactions,
      );
      final updatedLoadedIds = Set<String>.from(_state.loadedMessageIds);

      for (int i = 0; i < messageIds.length; i++) {
        updatedReactions[messageIds[i]] = results[i];
        updatedLoadedIds.add(messageIds[i]);
      }

      _state = _state.copyWith(
        messageReactions: updatedReactions,
        loadedMessageIds: updatedLoadedIds,
      );

      // Single notify for all messages
      try {
        notifyListeners();
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
            '⚠️ MessageReactionNotifier: batch notifyListeners failed: $e',
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '❌ MessageReactionNotifier: loadReactionsForMessagesBatch failed: $e',
        );
      }
    }
  }

  /// Fetch reactions for a message from server
  Future<void> fetchMessageReactions(String messageId) async {
    try {
      await _reactionService.fetchMessageReactions(messageId);
    } catch (e) {
      debugPrint('❌ MessageReactionNotifier: Error fetching reactions: $e');
    }
  }

  /// Get reactions for a message
  List<MessageReaction> getReactions(String messageId) {
    return _state.getReactionsForMessage(messageId);
  }

  /// Get user's reaction for a message
  MessageReaction? getUserReaction(String messageId) {
    return _state.getUserReaction(messageId, currentUserId);
  }

  /// Check if user has reacted to a message
  bool hasUserReacted(String messageId) {
    return _state.hasUserReacted(messageId, currentUserId);
  }

  /// Get grouped reactions for display
  Map<String, ReactionGroup> getGroupedReactions(String messageId) {
    return _state.getGroupedReactions(messageId);
  }

  @override
  void dispose() {
    _reactionUpdateSubscription?.cancel();
    _reactionErrorSubscription?.cancel();
    super.dispose();
  }
}
