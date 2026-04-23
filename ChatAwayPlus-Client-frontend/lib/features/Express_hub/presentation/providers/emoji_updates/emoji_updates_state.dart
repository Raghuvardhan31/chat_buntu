// lib/features/voice_hub/presentation/providers/emoji_updates/emoji_updates_state.dart

import '../../../data/models/emoji_update_model.dart';

/// State for emoji updates
class EmojiUpdatesState {
  final List<EmojiUpdateModel> emojiList;
  final bool isLoading;
  final bool isRefreshing;
  final String? errorMessage;

  const EmojiUpdatesState({
    this.emojiList = const [],
    this.isLoading = false,
    this.isRefreshing = false,
    this.errorMessage,
  });

  factory EmojiUpdatesState.initial() => const EmojiUpdatesState();

  EmojiUpdatesState copyWith({
    List<EmojiUpdateModel>? emojiList,
    bool? isLoading,
    bool? isRefreshing,
    String? errorMessage,
  }) {
    return EmojiUpdatesState(
      emojiList: emojiList ?? this.emojiList,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
