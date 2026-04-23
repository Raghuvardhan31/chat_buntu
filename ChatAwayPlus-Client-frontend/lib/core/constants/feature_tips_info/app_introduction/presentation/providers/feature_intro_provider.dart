import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chataway_plus/core/constants/feature_tips_info/app_introduction/data/feature_intro_model.dart';

/// State for the feature introduction system.
/// Tracks which features have been dismissed by the user.
class FeatureIntroState {
  final List<FeatureIntroModel> visibleFeatures;
  final Set<String> dismissedIds;

  const FeatureIntroState({
    required this.visibleFeatures,
    required this.dismissedIds,
  });

  FeatureIntroState copyWith({
    List<FeatureIntroModel>? visibleFeatures,
    Set<String>? dismissedIds,
  }) {
    return FeatureIntroState(
      visibleFeatures: visibleFeatures ?? this.visibleFeatures,
      dismissedIds: dismissedIds ?? this.dismissedIds,
    );
  }
}

/// Notifier that manages feature introduction dismissed state.
/// Uses Riverpod StateNotifier — no SharedPreferences.
class FeatureIntroNotifier extends StateNotifier<FeatureIntroState> {
  FeatureIntroNotifier()
    : super(
        FeatureIntroState(
          visibleFeatures: List.from(FeatureIntroData.features),
          dismissedIds: const {},
        ),
      );

  /// Dismiss a single feature by its id.
  /// Once dismissed, it won't appear again in this session.
  void dismissFeature(String featureId) {
    final updatedDismissed = {...state.dismissedIds, featureId};
    final updatedVisible = FeatureIntroData.features
        .where((f) => !updatedDismissed.contains(f.id))
        .toList();

    state = state.copyWith(
      visibleFeatures: updatedVisible,
      dismissedIds: updatedDismissed,
    );
  }

  /// Dismiss all features at once.
  void dismissAll() {
    final allIds = FeatureIntroData.features.map((f) => f.id).toSet();
    state = state.copyWith(visibleFeatures: [], dismissedIds: allIds);
  }

  /// Reset — show all features again (useful for Settings → "App Tour").
  void resetAll() {
    state = FeatureIntroState(
      visibleFeatures: List.from(FeatureIntroData.features),
      dismissedIds: const {},
    );
  }

  /// Check if all features have been dismissed.
  bool get allDismissed =>
      state.dismissedIds.length >= FeatureIntroData.features.length;
}

/// Provider for feature introduction state management.
final featureIntroProvider =
    StateNotifierProvider<FeatureIntroNotifier, FeatureIntroState>(
      (ref) => FeatureIntroNotifier(),
    );

/// Convenience provider: visible features list.
final visibleFeaturesProvider = Provider<List<FeatureIntroModel>>((ref) {
  return ref.watch(featureIntroProvider).visibleFeatures;
});

/// Convenience provider: whether all features are dismissed.
final allFeaturesDismissedProvider = Provider<bool>((ref) {
  return ref.watch(featureIntroProvider).visibleFeatures.isEmpty;
});
