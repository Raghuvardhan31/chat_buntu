import 'package:flutter/material.dart';

/// Service to track app lifecycle state and current chat context
/// Implements WhatsApp-style notification behavior
class AppStateService with WidgetsBindingObserver {
  static AppStateService? _instance;
  static AppStateService get instance {
    _instance ??= AppStateService._();
    return _instance!;
  }

  AppStateService._();

  // App state tracking
  AppLifecycleState _currentState = AppLifecycleState.resumed;
  bool get isAppInBackground =>
      _currentState == AppLifecycleState.inactive ||
      _currentState == AppLifecycleState.paused ||
      _currentState == AppLifecycleState.detached;
  bool get isAppInForeground => _currentState == AppLifecycleState.resumed;

  // Current chat tracking
  String? _currentChatReceiverId;
  String? get currentChatReceiverId => _currentChatReceiverId;
  bool get isInChat => _currentChatReceiverId != null;

  // App lifecycle callbacks for WebSocket reconnection
  final List<VoidCallback> _onAppResumed = <VoidCallback>[];
  final List<VoidCallback> _onAppPaused = <VoidCallback>[];

  /// Initialize app state tracking
  void initialize() {
    WidgetsBinding.instance.addObserver(this);
  }

  /// Dispose resources
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final wasBackground = isAppInBackground;
    _currentState = state;
    final isBackground = isAppInBackground;

    if (wasBackground != isBackground) {
      // Detect app resume from background/sleep
      if (wasBackground && !isBackground) {
        for (final cb in List<VoidCallback>.from(_onAppResumed)) {
          cb();
        }
      }

      // Detect app going to background
      if (!wasBackground && isBackground) {
        for (final cb in List<VoidCallback>.from(_onAppPaused)) {
          cb();
        }
      }
    }
  }

  /// Set current chat conversation (call when entering chat)
  void setCurrentChat(String receiverId) {
    _currentChatReceiverId = receiverId;
  }

  /// Clear current chat (call when leaving chat)
  void clearCurrentChat() {
    if (_currentChatReceiverId != null) {
      _currentChatReceiverId = null;
    }
  }

  /// Should show notification based on WhatsApp logic
  bool shouldShowNotification(String messageSenderId) {
    // Rule 1: Always show if app is in background
    if (isAppInBackground) {
      return true;
    }

    // Rule 2: Show if app is foreground but user not in this chat
    if (isAppInForeground && _currentChatReceiverId != messageSenderId) {
      return true;
    }

    // Rule 3: Don't show if user is viewing this chat
    if (_currentChatReceiverId == messageSenderId) {
      return false;
    }

    // Default: show notification
    return true;
  }

  /// Register callback for app resume (wake from sleep)
  void onAppResumed(VoidCallback callback) {
    _onAppResumed.add(callback);
  }

  /// Register callback for app pause (going to sleep)
  void onAppPaused(VoidCallback callback) {
    _onAppPaused.add(callback);
  }

  /// Clear lifecycle callbacks
  void clearCallbacks() {
    _onAppResumed.clear();
    _onAppPaused.clear();
  }

  /// Get current app state for debugging
  String get debugState {
    return 'App: ${isAppInBackground ? "BACKGROUND" : "FOREGROUND"}, Chat: ${_currentChatReceiverId ?? "NONE"}';
  }
}
