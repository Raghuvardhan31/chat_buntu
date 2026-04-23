// lib/features/profile/presentation/providers/emoji/emoji_notifier.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../../../data/repositories/emoji/emoji_repository.dart';
import 'emoji_state.dart';

/// Emoji page notifier - handles all emoji-related business logic
class EmojiNotifier extends StateNotifier<EmojiUIState> {
  final EmojiRepository _repository;

  bool _isInitializing = false;
  bool _isPerformingOp = false;

  void _log(String message) {
    if (kDebugMode) debugPrint(message);
  }

  EmojiNotifier(this._repository) : super(const EmojiUIState()) {
    // Start local-first load immediately so UI receives cached data without waiting
    _initLoadLocal();
  }

  // -------------------------
  // Initialization / Local Load
  // -------------------------
  Future<void> _initLoadLocal() async {
    if (_isInitializing) return;
    _isInitializing = true;

    try {
      _log('[EmojiNotifier] _initLoadLocal(): starting local read');
      state = state.copyWith(
        loadingState: EmojiLoadingState.loading,
        showShimmer: !state.hasEverLoaded,
      );

      final localEmoji = await _repository.getLocalEmoji();

      if (localEmoji != null) {
        _log('[EmojiNotifier] _initLoadLocal(): local HIT -> applying state');
        _log(
          '[EmojiNotifier] _initLoadLocal(): snapshot emoji="${localEmoji.emoji}" caption="${localEmoji.caption}"',
        );
        state = state.copyWith(
          loadingState: EmojiLoadingState.loaded,
          emoji: localEmoji,
          hasEverLoaded: true,
          showShimmer: false,
          errorMessage: null,
        );
      } else {
        _log('[EmojiNotifier] _initLoadLocal(): local MISS -> empty state');
        state = state.copyWith(
          loadingState: EmojiLoadingState.loaded,
          emoji: null,
          hasEverLoaded: true,
          showShimmer: false,
          errorMessage: null,
        );
      }
    } catch (e, st) {
      _log('[EmojiNotifier] _initLoadLocal() error: $e\n$st');
      state = state.copyWith(
        loadingState: EmojiLoadingState.loaded,
        hasEverLoaded: true,
        showShimmer: false,
        errorMessage: 'Failed to load local emoji',
      );
    } finally {
      _isInitializing = false;
    }
  }

  /// Public method to force a local reload (UI can call this when needed)
  Future<void> reloadLocal() async => _initLoadLocal();

  // =============================
  // Load Current Emoji (kept for compatibility)
  // =============================
  /// NOTE: kept for compatibility with callers that expect `loadEmoji()`.
  /// Internally this will behave like reloadLocal() but respects the in-flight guard.
  Future<void> loadEmoji() async {
    await _initLoadLocal();
  }

  // =============================
  // Refresh Emoji (server)
  // =============================
  Future<void> refreshEmoji() async {
    if (state.isRefreshing) return;

    state = state.copyWith(loadingState: EmojiLoadingState.refreshing);

    final result = await _repository.getCurrentEmoji();

    if (result.isSuccess && result.data != null) {
      state = state.copyWith(
        loadingState: EmojiLoadingState.loaded,
        emoji: result.data!.data,
        errorMessage: null,
      );
    } else {
      state = state.copyWith(
        loadingState: EmojiLoadingState.error,
        errorMessage: result.errorMessage ?? 'Failed to refresh emoji',
      );
    }
  }

  // =============================
  // Create Emoji
  // =============================
  Future<bool> createEmoji(String emoji, String caption) async {
    if (_isPerformingOp) return false;
    _isPerformingOp = true;
    state = state.copyWith(isProcessing: true, errorMessage: null);

    try {
      _log(
        '[EmojiNotifier] createEmoji(len=${emoji.length}) -> repository call',
      );
      _log(
        '[EmojiNotifier] createEmoji(): sending emoji="$emoji" caption="$caption"',
      );
      final result = await _repository.createEmoji(emoji, caption);

      if (result.isSuccess && result.data != null) {
        _log('[EmojiNotifier] createEmoji(): success -> update state');
        state = state.copyWith(
          emoji: result.data!.data,
          isProcessing: false,
          isEditing: false,
          errorMessage: null,
          forceNextCreate: false,
          hasEverLoaded: true,
        );
        return true;
      } else {
        _log(
          '[EmojiNotifier] createEmoji(): failure -> ${result.errorMessage}',
        );
        state = state.copyWith(
          isProcessing: false,
          errorMessage: result.errorMessage ?? 'Failed to create emoji',
        );
        return false;
      }
    } catch (e, st) {
      _log('[EmojiNotifier] createEmoji() exception: $e\n$st');
      state = state.copyWith(
        isProcessing: false,
        errorMessage: 'Failed to create emoji',
      );
      return false;
    } finally {
      _isPerformingOp = false;
    }
  }

  // =============================
  // Update Emoji
  // =============================
  Future<bool> updateEmoji(String id, String emoji, String caption) async {
    if (_isPerformingOp) return false;
    _isPerformingOp = true;
    state = state.copyWith(isProcessing: true, errorMessage: null);

    try {
      _log('[EmojiNotifier] updateEmoji(id=$id, len=${emoji.length})');
      _log(
        '[EmojiNotifier] updateEmoji(): payload emoji="$emoji" caption="$caption"',
      );

      // If we don't have an id locally, fallback to create flow
      if (state.emoji?.id == null || state.forceNextCreate) {
        _log(
          '[EmojiNotifier] updateEmoji(): no local id or forceNextCreate -> create instead',
        );
        final create = await _repository.createEmoji(emoji, caption);
        if (create.isSuccess && create.data != null) {
          state = state.copyWith(
            emoji: create.data!.data,
            isProcessing: false,
            isEditing: false,
            errorMessage: null,
            forceNextCreate: false,
            hasEverLoaded: true,
          );
          return true;
        } else {
          state = state.copyWith(
            isProcessing: false,
            errorMessage: create.errorMessage ?? 'Failed to create emoji',
          );
          return false;
        }
      }

      final result = await _repository.updateEmoji(id, emoji, caption);

      if (result.isSuccess && result.data != null) {
        _log('[EmojiNotifier] updateEmoji(): success');
        state = state.copyWith(
          emoji: result.data!.data,
          isProcessing: false,
          isEditing: false,
          errorMessage: null,
          hasEverLoaded: true,
        );
        return true;
      } else {
        _log(
          '[EmojiNotifier] updateEmoji(): failure -> ${result.errorMessage}',
        );
        if (result.statusCode == 404) {
          _log(
            '[EmojiNotifier] updateEmoji(): 404 -> create new emoji instead',
          );
          final create = await _repository.createEmoji(emoji, caption);
          if (create.isSuccess && create.data != null) {
            state = state.copyWith(
              emoji: create.data!.data,
              isProcessing: false,
              isEditing: false,
              errorMessage: null,
              forceNextCreate: false,
              hasEverLoaded: true,
            );
            return true;
          } else {
            state = state.copyWith(
              isProcessing: false,
              errorMessage:
                  create.errorMessage ?? 'Failed to create emoji after 404',
            );
            return false;
          }
        } else {
          state = state.copyWith(
            isProcessing: false,
            errorMessage: result.errorMessage ?? 'Failed to update emoji',
          );
          return false;
        }
      }
    } catch (e, st) {
      _log('[EmojiNotifier] updateEmoji() exception: $e\n$st');
      state = state.copyWith(
        isProcessing: false,
        errorMessage: 'Failed to update emoji',
      );
      return false;
    } finally {
      _isPerformingOp = false;
    }
  }

  // =============================
  // Delete Emoji
  // =============================
  Future<bool> deleteEmoji(String id, String emoji, String caption) async {
    if (_isPerformingOp) return false;
    _isPerformingOp = true;

    _log('[EmojiNotifier] deleteEmoji(id=$id) -> optimistic clear');
    final original = state.emoji;
    state = state.copyWith(
      isProcessing: true,
      emoji: null,
      forceNextCreate: true,
      errorMessage: null,
    );

    try {
      final result = await _repository.deleteEmoji(id, emoji, caption);

      if (result.isSuccess) {
        _log('[EmojiNotifier] deleteEmoji(): success -> verifying local DB');
        // Verify local DB after delete (useful for debugging)
        final localAfter = await _repository.getLocalEmoji();
        if (localAfter == null) {
          _log('[EmojiLocal] after delete: EMPTY in local DB');
        } else {
          _log('[EmojiLocal] after delete: FOUND -> ${localAfter.emoji}');
        }

        state = state.copyWith(isProcessing: false, errorMessage: null);
        return true;
      } else {
        _log(
          '[EmojiNotifier] deleteEmoji(): failure -> ${result.errorMessage}',
        );
        // Restore previous emoji if delete failed
        state = state.copyWith(
          emoji: original,
          isProcessing: false,
          errorMessage: result.errorMessage ?? 'Failed to delete emoji',
          forceNextCreate: false,
        );
        return false;
      }
    } catch (e, st) {
      _log('[EmojiNotifier] deleteEmoji() exception: $e\n$st');
      state = state.copyWith(
        emoji: original,
        isProcessing: false,
        errorMessage: 'Failed to delete emoji',
        forceNextCreate: false,
      );
      return false;
    } finally {
      _isPerformingOp = false;
    }
  }

  // =============================
  // Edit Mode Helpers
  // =============================
  void startEditing() {
    state = state.copyWith(
      isEditing: true,
      editingEmoji: state.displayEmoji,
      editingCaption: state.displayCaption,
      emojiCharacterCount: state.displayEmoji.length,
      captionCharacterCount: state.displayCaption.length,
    );
  }

  void cancelEditing() {
    state = state.copyWith(
      isEditing: false,
      editingEmoji: '',
      editingCaption: '',
      emojiCharacterCount: 0,
      captionCharacterCount: 0,
      errorMessage: null,
    );
  }

  void updateEditingEmoji(String emoji) {
    state = state.copyWith(
      editingEmoji: emoji,
      emojiCharacterCount: emoji.length,
    );
  }

  void updateEditingCaption(String caption) {
    state = state.copyWith(
      editingCaption: caption,
      captionCharacterCount: caption.length,
    );
  }

  // =============================
  // Clear Error
  // =============================
  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  // =============================
  // Clear Emoji (Logout)
  // =============================
  Future<void> clearEmoji() async {
    await _repository.clearEmoji();
    state = const EmojiUIState();
  }
}
