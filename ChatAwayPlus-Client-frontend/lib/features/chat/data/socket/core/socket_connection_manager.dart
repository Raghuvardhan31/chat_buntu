import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class SocketInitializationResult {
  final bool connected;
  final String? currentUserId;

  const SocketInitializationResult({
    required this.connected,
    required this.currentUserId,
  });
}

class SocketConnectionManager {
  io.Socket? _socket;
  bool _isConnected = false;

  Completer<bool>? _connectCompleter;
  DateTime? _lastConnectAttemptAt;
  static const Duration _minReconnectInterval = Duration(seconds: 2);

  void allowImmediateReconnect() {
    _lastConnectAttemptAt = null;
    _reconnectAttempts = 0; // Reset backoff so reconnect isn't blocked
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // EXPONENTIAL BACKOFF - Smarter reconnection strategy
  // ═══════════════════════════════════════════════════════════════════════════
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _baseReconnectDelay = Duration(seconds: 1);
  static const Duration _maxReconnectDelay = Duration(seconds: 30);

  // ═══════════════════════════════════════════════════════════════════════════
  // HEARTBEAT/PING - Detect zombie connections
  // ═══════════════════════════════════════════════════════════════════════════
  Timer? _heartbeatTimer;
  Timer? _pongTimeoutTimer;
  static const Duration _heartbeatInterval = Duration(seconds: 25);
  DateTime? _lastPongAt;

  String? _currentUserId;

  io.Socket? get socket => _socket;
  bool get isConnected => _isConnected;
  String? get currentUserId => _currentUserId;
  int get reconnectAttempts => _reconnectAttempts;

  /// Calculate delay with exponential backoff: 1s, 2s, 4s, 8s, 16s (capped at 30s)
  Duration get nextReconnectDelay {
    final delay = _baseReconnectDelay * (1 << _reconnectAttempts.clamp(0, 4));
    return delay > _maxReconnectDelay ? _maxReconnectDelay : delay;
  }

  /// Reset backoff on successful connection
  void _resetBackoff() {
    _reconnectAttempts = 0;
  }

  /// Increment backoff counter
  void _incrementBackoff() {
    if (_reconnectAttempts < _maxReconnectAttempts) {
      _reconnectAttempts++;
    }
  }

  /// Check if we should attempt reconnection
  bool get canAttemptReconnect => _reconnectAttempts < _maxReconnectAttempts;

  final StreamController<void> _connectedController =
      StreamController<void>.broadcast();
  final StreamController<void> _disconnectedController =
      StreamController<void>.broadcast();

  Stream<void> get onConnected => _connectedController.stream;
  Stream<void> get onDisconnected => _disconnectedController.stream;

  void attachSocket(io.Socket socket) {
    _socket = socket;
  }

  void detachSocket() {
    _stopHeartbeat();
    _socket = null;
    _currentUserId = null;
    _isConnected = false;
  }

  Future<SocketInitializationResult> initializeSocket({
    required Future<String?> Function() getAuthToken,
    required Future<String?> Function() getCurrentUserIdUUID,
    required String serverUrl,
    required void Function(io.Socket socket) setupListeners,
  }) async {
    if (_isConnected && _socket?.connected == true) {
      return SocketInitializationResult(
        connected: true,
        currentUserId: _currentUserId,
      );
    }

    final existingCompleter = _connectCompleter;
    if (existingCompleter != null) {
      final ok = await existingCompleter.future;
      return SocketInitializationResult(
        connected: ok,
        currentUserId: _currentUserId,
      );
    }

    final lastAttemptAt = _lastConnectAttemptAt;
    if (lastAttemptAt != null &&
        DateTime.now().difference(lastAttemptAt) < _minReconnectInterval) {
      return SocketInitializationResult(
        connected: false,
        currentUserId: _currentUserId,
      );
    }

    _lastConnectAttemptAt = DateTime.now();
    final completer = Completer<bool>();
    _connectCompleter = completer;

    try {
      final ok = await _initializeSocketInternal(
        getAuthToken: getAuthToken,
        getCurrentUserIdUUID: getCurrentUserIdUUID,
        serverUrl: serverUrl,
        setupListeners: setupListeners,
      );
      if (!completer.isCompleted) {
        completer.complete(ok);
      }
      return SocketInitializationResult(
        connected: ok,
        currentUserId: _currentUserId,
      );
    } catch (_) {
      if (!completer.isCompleted) {
        completer.complete(false);
      }
      return SocketInitializationResult(
        connected: false,
        currentUserId: _currentUserId,
      );
    } finally {
      _connectCompleter = null;
    }
  }

  Future<bool> _initializeSocketInternal({
    required Future<String?> Function() getAuthToken,
    required Future<String?> Function() getCurrentUserIdUUID,
    required String serverUrl,
    required void Function(io.Socket socket) setupListeners,
  }) async {
    try {
      if (_socket != null) {
        _socket!.disconnect();
        _socket!.dispose();
        _socket = null;
        _currentUserId = null;
        setConnected(false);
      }

      final authToken = await getAuthToken();
      final currentUserIdUUID = await getCurrentUserIdUUID();

      if (authToken == null || authToken.isEmpty) {
        debugPrint('❌ Socket: No auth token found');
        return false;
      }

      if (currentUserIdUUID == null || currentUserIdUUID.isEmpty) {
        debugPrint('❌ Socket: No user ID found');
        return false;
      }

      _currentUserId = currentUserIdUUID;

      _socket = io.io(
        serverUrl,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .setExtraHeaders({'Authorization': 'Bearer $authToken'})
            .disableAutoConnect()
            .disableReconnection() // We handle reconnection manually on app resume
            .setTimeout(15000)
            .build(),
      );

      final createdSocket = _socket;
      if (createdSocket == null) {
        debugPrint('❌ Socket became null after creation');
        return false;
      }

      setupListeners(createdSocket);
      createdSocket.connect();

      int waitTime = 0;
      const maxWaitTime = 20000;
      const checkInterval = 200;

      while (!_isConnected &&
          _socket?.connected != true &&
          waitTime < maxWaitTime) {
        await Future.delayed(const Duration(milliseconds: checkInterval));
        waitTime += checkInterval;
      }

      final isActuallyConnected = _isConnected && _socket?.connected == true;

      if (isActuallyConnected) {
        debugPrint('✅ Socket connected (user: $_currentUserId)');
        _resetBackoff();
        _startHeartbeat();
      } else {
        debugPrint('❌ Socket connection failed after ${waitTime}ms');
        _incrementBackoff();
      }

      return isActuallyConnected;
    } catch (e) {
      debugPrint('❌ Socket initialization error: $e');
      return false;
    }
  }

  void setConnected(bool value) {
    final changed = _isConnected != value;
    _isConnected = value;
    if (!changed) return;

    if (value) {
      _resetBackoff();
      _startHeartbeat();
      if (!_connectedController.isClosed) {
        _connectedController.add(null);
      }
    } else {
      _stopHeartbeat();
      if (!_disconnectedController.isClosed) {
        _disconnectedController.add(null);
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HEARTBEAT METHODS - Detect zombie/stale connections
  // ═══════════════════════════════════════════════════════════════════════════

  /// Start heartbeat timer to detect zombie connections.
  ///
  /// Instead of a custom ping-check/pong-check event (which the server
  /// does not implement), we rely on the socket.io transport-level
  /// connection state (`socket.connected`). Socket.io already handles
  /// keep-alive ping/pong at the engine level automatically.
  /// We only trigger a zombie disconnect when the underlying socket
  /// reports itself as disconnected but our `_isConnected` flag is
  /// still true (stale state).
  void _startHeartbeat() {
    _stopHeartbeat();
    _lastPongAt = DateTime.now();

    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      _checkConnectionHealth();
    });

    if (kDebugMode) {
      debugPrint(
        '💓 Heartbeat started (interval: ${_heartbeatInterval.inSeconds}s)',
      );
    }
  }

  /// Stop heartbeat timer
  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _pongTimeoutTimer?.cancel();
    _pongTimeoutTimer = null;
  }

  /// Check if the socket is still genuinely connected.
  /// Only trigger zombie handling when the transport reports disconnected
  /// but our local state still thinks we are connected.
  void _checkConnectionHealth() {
    final socket = _socket;
    if (socket == null || !_isConnected) return;

    if (socket.connected == true) {
      // Transport says connected — everything is fine.
      _lastPongAt = DateTime.now();
      return;
    }

    // Transport says disconnected but _isConnected is still true — zombie.
    if (kDebugMode) {
      debugPrint(
        '🧟 Zombie connection detected - socket.connected=false but _isConnected=true, forcing disconnect',
      );
    }
    _handleZombieConnection();
  }

  /// Handle zombie connection - disconnect and allow reconnect
  void _handleZombieConnection() {
    _stopHeartbeat();

    // Force disconnect the zombie socket
    try {
      _socket?.disconnect();
    } catch (_) {}

    setConnected(false);
  }

  /// Get time since last successful pong
  Duration? get timeSinceLastPong {
    if (_lastPongAt == null) return null;
    return DateTime.now().difference(_lastPongAt!);
  }

  void dispose() {
    _stopHeartbeat();
    try {
      _socket?.dispose();
    } catch (_) {}
    _socket = null;
    _isConnected = false;
    _currentUserId = null;
    _reconnectAttempts = 0;
    _connectedController.close();
    _disconnectedController.close();
  }
}
