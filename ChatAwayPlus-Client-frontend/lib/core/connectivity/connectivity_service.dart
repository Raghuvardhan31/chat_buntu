import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

/// WHATSAPP-STYLE: Singleton connectivity cache for instant access
/// No async calls needed - just read the cached value
class ConnectivityCache {
  static final ConnectivityCache _instance = ConnectivityCache._internal();
  static ConnectivityCache get instance => _instance;

  ConnectivityCache._internal();

  /// Cached connectivity state - accessed synchronously
  bool _isOnline = true; // Optimistic default
  bool get isOnline => _isOnline;

  StreamSubscription? _connectivitySub;
  StreamSubscription? _internetSub;
  bool _initialized = false;

  /// Initialize once at app startup (call from main.dart or app_gate)
  void initialize() {
    if (_initialized) return;
    _initialized = true;

    // Initial check
    InternetConnectionChecker().hasConnection
        .then((value) {
          _isOnline = value;
        })
        .catchError((_) {
          _isOnline = false;
        });

    // Listen to connectivity changes
    _connectivitySub = Connectivity().onConnectivityChanged.listen((_) async {
      try {
        _isOnline = await InternetConnectionChecker().hasConnection;
      } catch (_) {
        _isOnline = false;
      }
    });

    // Listen to internet checker (more authoritative)
    _internetSub = InternetConnectionChecker().onStatusChange.listen((status) {
      _isOnline = status == InternetConnectionStatus.connected;
    });
  }

  void dispose() {
    _connectivitySub?.cancel();
    _internetSub?.cancel();
    _initialized = false;
  }
}

/// StreamProvider`<bool>`: true = online, false = offline
final internetStatusStreamProvider = StreamProvider<bool>((ref) {
  final controller = StreamController<bool>.broadcast();
  Timer? debounceTimer;

  // Helper to emit with debounce (prevents flicker on short changes)
  void emitDebounced(bool value) {
    debounceTimer?.cancel();
    // 600ms debounce; tune as needed
    debounceTimer = Timer(const Duration(milliseconds: 600), () {
      if (!controller.isClosed) controller.add(value);
    });
  }

  // Initial lookup
  () async {
    try {
      final hasInternet = await InternetConnectionChecker().hasConnection;
      emitDebounced(hasInternet);
    } catch (_) {
      emitDebounced(false);
    }
  }();

  // Listen to connectivity changes (fast)
  final connectivitySub = Connectivity().onConnectivityChanged.listen((
    _,
  ) async {
    try {
      final hasInternet = await InternetConnectionChecker().hasConnection;
      emitDebounced(hasInternet);
    } catch (_) {
      emitDebounced(false);
    }
  });

  // Also listen to InternetConnectionChecker status changes (more authoritative)
  final internetSub = InternetConnectionChecker().onStatusChange.listen((
    status,
  ) {
    emitDebounced(status == InternetConnectionStatus.connected);
  });

  ref.onDispose(() {
    debounceTimer?.cancel();
    connectivitySub.cancel();
    internetSub.cancel();
    controller.close();
  });

  return controller.stream;
});
