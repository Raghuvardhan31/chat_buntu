// lib/features/voice_hub/presentation/providers/emoji_updates/emoji_updates_notifier.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'emoji_updates_state.dart';
import '../../../data/repositories/emoji_updates_repository.dart';

/// Notifier for managing emoji updates state
class EmojiUpdatesNotifier extends StateNotifier<EmojiUpdatesState> {
  final EmojiUpdatesRepository repository;

  void _safeSetState(EmojiUpdatesState s) {
    if (mounted) state = s;
  }

  EmojiUpdatesNotifier({required this.repository})
    : super(EmojiUpdatesState.initial());

  /// Load emoji updates from API
  Future<void> loadEmojiUpdates() async {
    if (state.isLoading) return;

    _safeSetState(state.copyWith(isLoading: true, errorMessage: null));

    try {
      final result = await repository.getAllEmojiUpdates();

      if (result.isSuccess && result.data != null) {
        final emojiList = result.data!.data ?? [];
        _safeSetState(
          state.copyWith(
            emojiList: emojiList,
            isLoading: false,
            errorMessage: null,
          ),
        );
        debugPrint('[EmojiUpdates] Loaded ${emojiList.length} emoji updates');
      } else {
        // Try loading from local database
        final localResult = await repository.getLocalEmojiUpdates();
        final emojiList = localResult.data?.data ?? [];
        _safeSetState(
          state.copyWith(
            emojiList: emojiList,
            isLoading: false,
            errorMessage: result.message,
          ),
        );
        debugPrint(
          '[EmojiUpdates] Loaded ${emojiList.length} from local cache',
        );
      }
    } catch (e) {
      debugPrint('[EmojiUpdates] Error loading: $e');
      _safeSetState(
        state.copyWith(isLoading: false, errorMessage: e.toString()),
      );
    }
  }

  /// Refresh emoji updates
  Future<void> refreshEmojiUpdates() async {
    if (state.isRefreshing) return;

    _safeSetState(state.copyWith(isRefreshing: true, errorMessage: null));

    try {
      final result = await repository.getAllEmojiUpdates();

      if (result.isSuccess && result.data != null) {
        final emojiList = result.data!.data ?? [];
        _safeSetState(
          state.copyWith(
            emojiList: emojiList,
            isRefreshing: false,
            errorMessage: null,
          ),
        );
        debugPrint(
          '[EmojiUpdates] Refreshed ${emojiList.length} emoji updates',
        );
      } else {
        _safeSetState(
          state.copyWith(isRefreshing: false, errorMessage: result.message),
        );
      }
    } catch (e) {
      debugPrint('[EmojiUpdates] Error refreshing: $e');
      _safeSetState(
        state.copyWith(isRefreshing: false, errorMessage: e.toString()),
      );
    }
  }

  /// Load from local database only
  Future<void> loadLocalEmojiUpdates() async {
    try {
      final result = await repository.getLocalEmojiUpdates();
      if (result.isSuccess && result.data != null) {
        final emojiList = result.data!.data ?? [];
        _safeSetState(state.copyWith(emojiList: emojiList));
      }
    } catch (e) {
      debugPrint('[EmojiUpdates] Error loading local: $e');
    }
  }
}
