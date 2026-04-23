import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chataway_plus/core/storage/token_storage.dart';
import '../../data/datasources/draggable_emoji_local_datasource.dart';

/// Provider for managing draggable emoji state
final draggableEmojiProvider = ChangeNotifierProvider<DraggableEmojiProvider>((
  ref,
) {
  return DraggableEmojiProvider();
});

class DraggableEmojiProvider extends ChangeNotifier {
  String _emoji = '😊';
  String? _currentUserId;
  bool _isLoading = false;

  // Getters
  String get emoji => _emoji;
  bool get isLoading => _isLoading;
  String? get currentUserId => _currentUserId;

  /// Initialize provider and load user's emoji
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Get current user ID
      _currentUserId = await TokenSecureStorage.instance.getCurrentUserIdUUID();

      if (_currentUserId != null) {
        await loadUserEmoji(_currentUserId!);
      }
    } catch (e) {
      debugPrint('Error initializing DraggableEmojiProvider: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load emoji for specific user
  Future<void> loadUserEmoji(String userId) async {
    try {
      _emoji = await DraggableEmojiLocalDataSource.getUserEmoji(userId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading user emoji: $e');
      _emoji = '😊';
      notifyListeners();
    }
  }

  /// Update emoji for current user
  Future<void> updateEmoji(String emoji) async {
    if (_currentUserId == null) {
      debugPrint('Cannot update emoji: No current user ID');
      return;
    }

    try {
      _isLoading = true;
      notifyListeners();

      await DraggableEmojiLocalDataSource.saveUserEmoji(emoji, _currentUserId!);
      _emoji = emoji;

      debugPrint('Emoji updated to: $emoji for user: $_currentUserId');
    } catch (e) {
      debugPrint('Error updating emoji: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Reset emoji to default
  Future<void> resetEmoji() async {
    await updateEmoji('😊');
  }

  /// Set user ID manually (for testing or specific use cases)
  void setUserId(String userId) {
    _currentUserId = userId;
    notifyListeners();
  }

  /// Get emoji for specific user without changing current state
  Future<String> getEmojiForUser(String userId) async {
    try {
      return await DraggableEmojiLocalDataSource.getUserEmoji(userId);
    } catch (e) {
      return '😊';
    }
  }

}
