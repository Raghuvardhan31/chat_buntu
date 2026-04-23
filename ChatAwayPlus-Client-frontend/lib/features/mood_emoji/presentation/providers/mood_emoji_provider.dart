import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chataway_plus/features/mood_emoji/data/datasources/mood_emoji_local_datasource.dart';
import 'package:chataway_plus/features/mood_emoji/data/models/mood_emoji_model.dart';
import 'package:chataway_plus/core/storage/token_storage.dart';

/// Global Riverpod provider for mood emoji state
/// This ensures the timer persists across navigation and app lifecycle
final moodEmojiProvider = ChangeNotifierProvider<MoodEmojiProvider>((ref) {
  final provider = MoodEmojiProvider();
  provider.initialize();
  return provider;
});

/// Provider for managing user's personal mood emoji state
class MoodEmojiProvider extends ChangeNotifier {
  final MoodEmojiLocalDatasource _datasource =
      MoodEmojiLocalDatasource.instance;

  MoodEmojiModel? _currentMoodEmoji;
  bool _isLoading = false;
  Timer? _expiryTimer;
  bool _disposed = false;

  /// Current mood emoji (null if expired or not set)
  MoodEmojiModel? get currentMoodEmoji => _currentMoodEmoji;

  /// Get the emoji string (returns grey default if not set/expired)
  String get emojiDisplay => _currentMoodEmoji?.emoji ?? '😊';

  /// Check if mood emoji is active (not expired)
  bool get isActive =>
      _currentMoodEmoji != null && !_currentMoodEmoji!.isExpired;

  /// Check if currently loading
  bool get isLoading => _isLoading;

  /// Initialize and load user's mood emoji
  Future<void> initialize() async {
    await loadMoodEmoji();
  }

  /// Load user's current mood emoji from database
  Future<void> loadMoodEmoji() async {
    try {
      _isLoading = true;
      if (!_disposed) notifyListeners();

      final userId = await TokenSecureStorage.instance.getCurrentUserIdUUID();
      if (userId == null || userId.isEmpty) {
        _currentMoodEmoji = null;
        _isLoading = false;
        if (!_disposed) notifyListeners();
        return;
      }

      final moodEmoji = await _datasource.getUserMoodEmoji(userId);
      _currentMoodEmoji = moodEmoji;

      // Setup expiry timer if emoji is active
      if (_currentMoodEmoji != null && !_currentMoodEmoji!.isExpired) {
        _setupExpiryTimer();
      }

      _isLoading = false;
      if (!_disposed) notifyListeners();
    } catch (e) {
      _isLoading = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// Update mood emoji with new emoji and expiry duration
  Future<bool> updateMoodEmoji({
    required String emoji,
    required Duration duration,
  }) async {
    try {
      _isLoading = true;
      if (!_disposed) notifyListeners();

      final userId = await TokenSecureStorage.instance.getCurrentUserIdUUID();
      if (userId == null || userId.isEmpty) {
        _isLoading = false;
        if (!_disposed) notifyListeners();
        return false;
      }

      final expiryTimestamp = DateTime.now().add(duration);
      final success = await _datasource.saveMoodEmoji(
        userId: userId,
        emoji: emoji,
        expiryTimestamp: expiryTimestamp,
      );

      if (success) {
        _currentMoodEmoji = MoodEmojiModel(
          userId: userId,
          emoji: emoji,
          expiryTimestamp: expiryTimestamp,
          createdAt: DateTime.now(),
        );
        _setupExpiryTimer();
      }

      _isLoading = false;
      if (!_disposed) notifyListeners();
      return success;
    } catch (e) {
      _isLoading = false;
      if (!_disposed) notifyListeners();
      return false;
    }
  }

  /// Reset mood emoji to default grey state
  Future<bool> resetMoodEmoji() async {
    try {
      final userId = await TokenSecureStorage.instance.getCurrentUserIdUUID();
      if (userId == null || userId.isEmpty) return false;

      final success = await _datasource.deleteUserMoodEmoji(userId);
      if (success) {
        _currentMoodEmoji = null;
        _cancelExpiryTimer();
        if (!_disposed) notifyListeners();
      }
      return success;
    } catch (e) {
      return false;
    }
  }

  /// Setup timer to auto-expire emoji when time is up
  void _setupExpiryTimer() {
    _cancelExpiryTimer();

    if (_currentMoodEmoji == null || _currentMoodEmoji!.isExpired) return;

    final timeUntilExpiry = _currentMoodEmoji!.expiryTimestamp.difference(
      DateTime.now(),
    );
    if (timeUntilExpiry.isNegative) {
      // Already expired, reset immediately
      resetMoodEmoji();
      return;
    }

    _expiryTimer = Timer(timeUntilExpiry, () {
      resetMoodEmoji();
    });
  }

  /// Cancel the expiry timer
  void _cancelExpiryTimer() {
    _expiryTimer?.cancel();
    _expiryTimer = null;
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelExpiryTimer();
    super.dispose();
  }
}
