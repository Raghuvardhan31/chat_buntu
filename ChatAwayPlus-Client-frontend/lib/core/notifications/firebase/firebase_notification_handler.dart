import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:chataway_plus/core/notifications/local/notification_local_service.dart';
import 'package:chataway_plus/core/notifications/notification_repository.dart';
import 'package:chataway_plus/core/notifications/firebase/fcm_token_sending.dart';
import 'package:chataway_plus/core/storage/fcm_token_storage.dart';
import 'package:chataway_plus/core/storage/token_storage.dart';
import 'package:chataway_plus/core/database/app_database.dart';
import 'package:chataway_plus/core/routes/navigation_service.dart';
import 'package:chataway_plus/core/sounds/chat_sound_player.dart';
import 'package:chataway_plus/features/contacts/data/repositories/contacts_repository.dart';
import 'package:chataway_plus/features/contacts/data/models/contact_local.dart';
import 'package:chataway_plus/features/chat/data/services/chat_engine/index.dart';
import 'package:chataway_plus/core/app_lifecycle/app_state_service.dart';
import 'package:chataway_plus/features/chat/models/chat_message_model.dart';
import 'package:chataway_plus/features/contacts/data/datasources/contacts_database_service.dart';
import 'package:chataway_plus/core/isolates/contact_sync_isolate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chataway_plus/core/notifications/silent/profile_update_silent_fcm_handler.dart';
import 'package:chataway_plus/core/notifications/silent/stories_silent_fcm_handler.dart';
import 'package:chataway_plus/core/notifications/notifications/stories_notification.dart';
import 'package:chataway_plus/core/notifications/notifications/message_notification.dart';
import 'package:chataway_plus/core/notifications/notifications/chat_picture_notification.dart';
import 'package:chataway_plus/core/notifications/notifications/share_your_voice_notification.dart';
import 'package:chataway_plus/core/notifications/notifications/image_notification.dart';
import 'package:chataway_plus/core/notifications/notifications/reaction_notification.dart';
import 'package:chataway_plus/features/voice_call/data/services/call_listener_service.dart';
import 'package:chataway_plus/features/voice_call/data/services/call_signaling_service.dart';
import 'package:chataway_plus/features/voice_call/data/models/call_model.dart';

/// Firebase Notification Handler
///
/// Handles all Firebase Cloud Messaging (FCM) notifications
/// - Foreground notifications (app is open)
/// - Background notifications (app is in background)
/// - Terminated notifications (app is closed)
///
/// 📱 NOTIFICATION FLOW:
/// 1. FCM sends message from backend
/// 2. FirebaseNotificationHandler receives it
/// 3. Parses message type (chat, call, friend_request)
/// 4. Shows local notification via NotificationLocalService
/// 5. Saves to database for offline access
/// 6. Updates badge count
///
/// 🔔 SUPPORTED TYPES:
/// • chat_message - New message in chat
/// • voice_call - Incoming voice call
/// • friend_request - New friend request
/// • group_message - New group message
// @pragma('vm:entry-point')
// Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
//   debugPrint(
//     '🔔 [Background] Handling background message: ${message.messageId}',
//   );
//   await FirebaseNotificationHandler.instance.handleBackgroundMessage(message);
// }

class FirebaseNotificationHandler {
  static FirebaseNotificationHandler? _instance;

  FirebaseNotificationHandler._();

  static FirebaseNotificationHandler get instance {
    _instance ??= FirebaseNotificationHandler._();
    return _instance!;
  }

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final NotificationLocalService _localNotificationService =
      NotificationLocalService.instance;
  final NotificationRepository _notificationRepository =
      NotificationRepository();
  final TokenSecureStorage _tokenStorage = TokenSecureStorage();
  final ContactsRepository _contactsRepository = ContactsRepository.instance;

  static const String _contactsDirtyKey = 'contacts_dirty';
  static const String _contactsDirtyAtKey = 'contacts_dirty_at';
  static const String _pendingNativeChatQueueKey = 'pending_fcm_chat_queue';
  static const String _pendingNativeLikesQueueKey = 'pending_fcm_likes_queue';
  static const String _pendingNativeChatQueueKeyFlutter =
      'flutter.pending_fcm_chat_queue';
  static const String _pendingNativeLikesQueueKeyFlutter =
      'flutter.pending_fcm_likes_queue';

  static const String _followUpReplyStart = '<<FU_REPLY>>';
  static const String _followUpReplyEnd = '<<FU_REPLY_END>>';
  static const String _expressHubReplyStart = '<<EH_REPLY>>';
  static const String _expressHubReplyEnd = '<<EH_REPLY_END>>';

  bool _isInitialized = false;

  StreamSubscription<String>? _tokenRefreshSub;

  //=================================================================
  // INITIALIZATION
  //=================================================================

  /// Initialize Firebase Messaging handlers
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('⚠️ [FCMHandler] Already initialized');
      return;
    }

    try {
      // Initialize local notification service first
      await _localNotificationService.initialize();

      // Ensure notification tables exist
      await _notificationRepository.ensureNotificationTables();

      // Request permission only if needed
      await _ensurePermissionIfNeeded();

      await _ensureCurrentTokenStoredAndSentIfPossible();

      await _drainPendingNativeChatQueue();
      await _drainPendingNativeLikesQueue();

      // Setup message handlers
      _setupMessageHandlers();

      _registerTokenRefreshListenerOnce();

      AppStateService.instance.onAppResumed(() {
        Future.microtask(() async {
          try {
            try {
              await _drainPendingNativeChatQueue();
            } catch (_) {}
            try {
              await _drainPendingNativeLikesQueue();
            } catch (_) {}

            final prefs = await SharedPreferences.getInstance();
            final dirty = prefs.getBool(_contactsDirtyKey) ?? false;
            if (!dirty) return;
            await prefs.setBool(_contactsDirtyKey, false);

            ChatEngineService.instance.notifyContactJoined(
              userId: 'contacts_dirty',
              mobileNo: 'contacts_dirty',
            );
          } catch (e) {
            debugPrint('⚠️ [ContactsDirty] Resume check failed: $e');
          }
        });
      });

      _isInitialized = true;
    } catch (e) {
      debugPrint('❌ [FCMHandler] Initialization failed: $e');
    }
  }

  Future<void> _drainPendingNativeChatQueue() async {
    try {
      if (!Platform.isAndroid) return;

      final currentUserId = await _tokenStorage.getCurrentUserIdUUID();
      if (currentUserId == null || currentUserId.trim().isEmpty) return;

      try {
        await ChatEngineService.instance.initialize(currentUserId);
      } catch (_) {}

      final prefs = await SharedPreferences.getInstance();
      final rawLegacy = prefs.getString(_pendingNativeChatQueueKey);
      final rawFlutter = prefs.getString(_pendingNativeChatQueueKeyFlutter);

      final raws = <String>[];
      if (rawLegacy != null && rawLegacy.trim().isNotEmpty) {
        raws.add(rawLegacy);
      }
      if (rawFlutter != null && rawFlutter.trim().isNotEmpty) {
        raws.add(rawFlutter);
      }
      if (raws.isEmpty) return;

      for (final raw in raws) {
        dynamic decoded;
        try {
          decoded = jsonDecode(raw);
        } catch (_) {
          continue;
        }
        if (decoded is! List) continue;

        for (final entry in decoded) {
          if (entry is! Map) continue;
          final data = Map<String, dynamic>.from(entry);
          await _saveMessageDataToDatabase(data);
        }
      }

      await prefs.remove(_pendingNativeChatQueueKey);
      await prefs.remove(_pendingNativeChatQueueKeyFlutter);
    } catch (_) {}
  }

  Future<void> preloadPendingNativeChatQueue() async {
    await _drainPendingNativeChatQueue();
    await _drainPendingNativeLikesQueue();
  }

  Future<void> _drainPendingNativeLikesQueue() async {
    try {
      if (!Platform.isAndroid) return;

      final currentUserId = await _tokenStorage.getCurrentUserIdUUID();
      if (currentUserId == null || currentUserId.trim().isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      final rawLegacy = prefs.getString(_pendingNativeLikesQueueKey);
      final rawFlutter = prefs.getString(_pendingNativeLikesQueueKeyFlutter);

      final raws = <String>[];
      if (rawLegacy != null && rawLegacy.trim().isNotEmpty) {
        raws.add(rawLegacy);
      }
      if (rawFlutter != null && rawFlutter.trim().isNotEmpty) {
        raws.add(rawFlutter);
      }
      if (raws.isEmpty) return;

      int processed = 0;
      for (final raw in raws) {
        dynamic decoded;
        try {
          decoded = jsonDecode(raw);
        } catch (_) {
          continue;
        }
        if (decoded is! List) continue;

        debugPrint(
          '🔔 [FCM] Draining ${decoded.length} pending native like(s)...',
        );

        for (final entry in decoded) {
          if (entry is! Map) continue;
          final data = Map<String, dynamic>.from(entry);
          try {
            if (ChatPictureNotificationHandler.isChatPictureNotification(
              data,
            )) {
              await ChatPictureNotificationHandler.handle(data);
              processed++;
            } else if (ShareYourVoiceNotificationHandler.isShareYourVoiceNotification(
              data,
            )) {
              await ShareYourVoiceNotificationHandler.handle(data);
              processed++;
            }
          } catch (e) {
            debugPrint('⚠️ [FCM] Failed to process pending like: $e');
          }
        }
      }

      await prefs.remove(_pendingNativeLikesQueueKey);
      await prefs.remove(_pendingNativeLikesQueueKeyFlutter);
      debugPrint(
        '✅ [FCM] Pending native likes queue drained (processed=$processed)',
      );
    } catch (e) {
      debugPrint('⚠️ [FCM] _drainPendingNativeLikesQueue error: $e');
    }
  }

  Future<void> _handleReactionNotification(RemoteMessage message) async {
    await ReactionNotificationHandler.handle(
      message.data,
      fcmMessageId: message.messageId,
    );
  }

  Future<void> _ensureCurrentTokenStoredAndSentIfPossible() async {
    try {
      final token = await _firebaseMessaging.getToken();
      if (token == null || token.isEmpty) {
        return;
      }

      final phone = await _tokenStorage.getPhoneNumber();
      if (phone != null && phone.isNotEmpty) {
        await FCMTokenStorage.instance.saveFCMToken(token, phone);
      } else {
        await FCMTokenStorage.instance.updateFCMToken(token);
      }

      final authToken = await _tokenStorage.getToken();
      if (authToken == null || authToken.isEmpty) {
        return;
      }

      await FCMTokenApiService.instance.ensureFCMTokenSentToBackend();
    } catch (e, st) {
      debugPrint('⚠️ [FCMHandler] Ensure token stored/sent failed: $e\n$st');
    }
  }

  void _registerTokenRefreshListenerOnce() {
    if (_tokenRefreshSub != null) {
      return;
    }

    _tokenRefreshSub = _firebaseMessaging.onTokenRefresh.listen((String token) {
      () async {
        try {
          debugPrint('🔄 [FCMHandler] Token refreshed');

          final phone = await _tokenStorage.getPhoneNumber();
          if (phone != null && phone.isNotEmpty) {
            await FCMTokenStorage.instance.saveFCMToken(token, phone);
          } else {
            await FCMTokenStorage.instance.updateFCMToken(token);
          }

          final authToken = await _tokenStorage.getToken();
          if (authToken == null || authToken.isEmpty) {
            return;
          }

          await FCMTokenApiService.instance.ensureFCMTokenSentToBackend();
        } catch (e, st) {
          debugPrint('🔄 [FCMHandler] Token refresh handling failed: $e\n$st');
        }
      }();
    });
  }

  /// Ensure permission exists; request only when needed
  Future<void> _ensurePermissionIfNeeded() async {
    try {
      if (Platform.isIOS) {
        final settings = await _firebaseMessaging.getNotificationSettings();
        final status = settings.authorizationStatus;
        if (status == AuthorizationStatus.authorized ||
            status == AuthorizationStatus.provisional) {
          return;
        }
        await _firebaseMessaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        );
      } else {
        final status = await Permission.notification.status;
        if (status == PermissionStatus.granted) {
          return;
        }
        await Permission.notification.request();
      }
    } catch (e) {
      debugPrint('❌ [FCMHandler] Permission check/request failed: $e');
    }
  }

  /// Setup message handlers for different app states
  void _setupMessageHandlers() {
    // FOREGROUND: App is open and in view
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // BACKGROUND: App is in background but not terminated
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // TERMINATED: Don't check here - navigation context not ready yet
    // Will be checked in AppGatePage after app is fully initialized
  }

  //=================================================================
  // MESSAGE HANDLERS
  //=================================================================

  /// Handle foreground message (app is open)
  /// Flutter handles BOTH notification display and data persistence.
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final fcmStartTime = DateTime.now();
    try {
      // Parse and show notification via Flutter (with profile picture, etc.)
      await _parseAndShowNotification(message);

      // Play in-app notification sound for chat messages when NOT in the
      // active one-to-one chat with this sender.
      try {
        final data = message.data;
        if (data.isNotEmpty) {
          final type =
              data['type'] as String? ??
              data['chatType'] as String? ??
              data['notificationType'] as String? ??
              'unknown';

          if (type == 'chat_message' ||
              type == 'message' ||
              type == 'private_message') {
            final senderId =
                data['sender_id'] as String? ?? data['senderId'] as String?;
            final activeWith =
                ChatEngineService.instance.activeConversationUserId;
            final isInActiveOneToOneChat =
                activeWith != null &&
                senderId != null &&
                activeWith == senderId;

            if (!isInActiveOneToOneChat) {
              ChatSoundPlayer.instance.playNotificationSound();
            }
          }
        }
      } catch (e) {
        debugPrint(
          '⚠️ [Foreground] Failed to play in-app notification sound: $e',
        );
      }

      final elapsed = DateTime.now().difference(fcmStartTime).inMilliseconds;
      debugPrint('⏱️ [FCM TIMING] Foreground total: ${elapsed}ms');
    } catch (e) {
      debugPrint('❌ [Foreground] Error handling message: $e');
    }
  }

  /// Handle background message (app is in background/terminated)
  /// NOTE: In socket-only mode, delivery/read acks are flushed when the socket reconnects.
  ///
  /// WHATSAPP-STYLE OPTIMIZATION:
  /// - On Android: Native FCM service (ChatAwayFirebaseMessagingService) handles notification display
  ///   Flutter only handles data persistence (saving message to DB)
  /// - On iOS: Flutter handles both notification and data persistence
  Future<void> handleBackgroundMessage(RemoteMessage message) async {
    final fcmStartTime = DateTime.now();
    try {
      debugPrint('🔔 [FCM BACKGROUND] Handler started');

      // STEP 1: Initialize services (REQUIRED for contact lookup)
      if (!_isInitialized) {
        final initStart = DateTime.now();
        debugPrint('⏱️ [FCM] Cold start - initializing services...');
        await _localNotificationService.initialize();
        await _notificationRepository.ensureNotificationTables();
        _isInitialized = true;
        debugPrint(
          '⏱️ [FCM] Services ready: ${DateTime.now().difference(initStart).inMilliseconds}ms',
        );
      }

      // STEP 2: Parse and show notification (Flutter handles display)
      // NOTE: In socket-only mode, delivery/read acks are flushed when the socket reconnects.
      final notifStart = DateTime.now();
      await _parseAndProcessData(message);
      debugPrint(
        '⏱️ [FCM] Notification SHOWN: ${DateTime.now().difference(notifStart).inMilliseconds}ms',
      );

      final totalElapsed = DateTime.now()
          .difference(fcmStartTime)
          .inMilliseconds;
      debugPrint('⏱️ [FCM] Background handler TOTAL: ${totalElapsed}ms');
    } catch (e) {
      debugPrint('❌ [Background] Error handling message: $e');
    }
  }

  /// Save FCM message to local database (for chat history)
  /// Used on Android where native handler shows notification but Flutter saves data
  Future<void> _saveMessageToDatabase(RemoteMessage message) async {
    try {
      await _saveMessageDataToDatabase(message.data);
    } catch (e) {
      debugPrint('❌ [FCM] Error saving to DB: $e');
    }
  }

  Future<void> _saveMessageDataToDatabase(Map<String, dynamic> data) async {
    final type = (data['type'] ?? 'chat_message').toString();
    if (type != 'chat_message' &&
        type != 'message' &&
        type != 'private_message') {
      return;
    }

    final senderId = (data['sender_id'] ?? data['senderId'] ?? '').toString();

    Map<String, dynamic>? embedded;
    String? rawMessageType =
        data['messageType']?.toString() ?? data['message_type']?.toString();
    if (rawMessageType == null || rawMessageType.trim().isEmpty) {
      embedded = _tryDecodeEmbeddedBodyMap(data);
      rawMessageType =
          embedded?['messageType']?.toString() ??
          embedded?['message_type']?.toString();
    }
    final parsedType = ChatMessageModel.parseMessageType(rawMessageType);

    dynamic fileUrl =
        data['fileUrl'] ??
        data['file_url'] ??
        data['imageUrl'] ??
        data['image_url'] ??
        data['videoUrl'] ??
        data['video_url'];
    if (fileUrl == null) {
      embedded ??= _tryDecodeEmbeddedBodyMap(data);
      fileUrl =
          embedded?['fileUrl'] ??
          embedded?['file_url'] ??
          embedded?['imageUrl'] ??
          embedded?['image_url'] ??
          embedded?['videoUrl'] ??
          embedded?['video_url'];
    }

    dynamic mimeType = data['mimeType'] ?? data['mime_type'];
    if (mimeType == null) {
      embedded ??= _tryDecodeEmbeddedBodyMap(data);
      mimeType = embedded?['mimeType'] ?? embedded?['mime_type'];
    }

    Map<String, dynamic>? fileMetadata;
    try {
      final raw = data['fileMetadata'];
      if (raw is Map) {
        fileMetadata = Map<String, dynamic>.from(raw);
      } else if (raw is String && raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          fileMetadata = Map<String, dynamic>.from(decoded);
        }
      }
    } catch (_) {}

    final fileName =
        (fileMetadata?['fileName'] ?? data['fileName'] ?? data['file_name'])
            ?.toString();

    int? tryParseInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      return int.tryParse(v.toString());
    }

    final fileSize =
        tryParseInt(fileMetadata?['fileSize']) ??
        tryParseInt(data['fileSize'] ?? data['file_size']);
    final pageCount =
        tryParseInt(fileMetadata?['pageCount']) ??
        tryParseInt(data['pageCount'] ?? data['page_count']);

    final rawMessageText =
        data['messageText'] ?? data['message'] ?? data['text'] ?? data['body'];
    var messageText = _extractMessageText(rawMessageText) ?? '';
    messageText = _stripFollowUpReplyWrapper(messageText);

    // Check if messageText looks like raw JSON (backend sometimes sends entire object as string)
    final looksLikeJson =
        messageText.trim().startsWith('{') ||
        messageText.trim().startsWith('[') ||
        messageText.contains('"messageType"') ||
        messageText.contains('"message":null');

    // For non-text messages, use friendly labels instead of raw JSON or empty text
    if ((messageText.trim().isEmpty || looksLikeJson) &&
        parsedType != MessageType.text) {
      messageText = ImageNotificationHandler.normalizeMessageText(
        messageText: messageText,
        messageType: rawMessageType,
        fileName: fileName,
        looksLikeJson: looksLikeJson,
      );
    }

    if (parsedType == MessageType.text && looksLikeJson) {
      final extracted = _extractMessageText(messageText);
      if (extracted != null && extracted.trim().isNotEmpty) {
        messageText = _stripFollowUpReplyWrapper(extracted);
      }
    }

    final messageId =
        data['messageUuid'] ??
        data['message_uuid'] ??
        data['messageId'] ??
        data['message_id'] ??
        data['id'] ??
        data['chatId'] ??
        '';

    if (senderId.isEmpty || messageId.toString().trim().isEmpty) {
      return;
    }

    try {
      final existing = await MessagesTable.instance.getMessageById(
        messageId.toString(),
      );
      if (existing != null) {
        return;
      }
    } catch (_) {}

    final currentUserId = await _tokenStorage.getCurrentUserIdUUID();
    if (currentUserId == null || currentUserId.isEmpty) {
      return;
    }

    DateTime createdAt;
    try {
      final receivedAtMs = int.tryParse(data['_receivedAt']?.toString() ?? '');
      if (receivedAtMs != null) {
        createdAt = DateTime.fromMillisecondsSinceEpoch(receivedAtMs);
      } else {
        final createdAtRaw =
            data['createdAt']?.toString() ??
            data['created_at']?.toString() ??
            data['timestamp']?.toString() ??
            data['sentAt']?.toString() ??
            data['sent_at']?.toString() ??
            data['time']?.toString();
        createdAt = (createdAtRaw != null)
            ? (DateTime.tryParse(createdAtRaw) ?? DateTime.now())
            : DateTime.now();
      }
    } catch (_) {
      createdAt = DateTime.now();
    }

    DateTime updatedAt;
    try {
      final updatedAtRaw =
          data['updatedAt']?.toString() ?? data['updated_at']?.toString();
      updatedAt = updatedAtRaw != null
          ? (DateTime.tryParse(updatedAtRaw) ?? createdAt)
          : createdAt;
    } catch (_) {
      updatedAt = createdAt;
    }

    final fcmMessage = ChatMessageModel(
      id: messageId.isNotEmpty
          ? messageId.toString()
          : 'fcm_${DateTime.now().millisecondsSinceEpoch}',
      senderId: senderId,
      receiverId: currentUserId,
      message: messageText,
      messageStatus: 'delivered',
      isRead: false,
      createdAt: createdAt,
      updatedAt: updatedAt,
      deliveryChannel: 'fcm',
      messageType: parsedType,
      imageUrl: fileUrl?.toString(),
      mimeType: mimeType?.toString(),
      fileName: fileName?.toString(),
      fileSize: fileSize,
      pageCount: pageCount,
    );

    await ChatEngineService.instance.saveFCMMessage(fcmMessage);
  }

  String _stripFollowUpReplyWrapper(String raw) {
    var result = raw;

    // Strip Express Hub reply wrapper
    final ehTrimmed = result.trimLeft();
    if (ehTrimmed.startsWith(_expressHubReplyStart)) {
      final ehEndIndex = ehTrimmed.indexOf(_expressHubReplyEnd);
      if (ehEndIndex != -1) {
        result = ehTrimmed
            .substring(ehEndIndex + _expressHubReplyEnd.length)
            .trimLeft();
      }
    }

    // Strip Follow-up reply wrapper
    final fuTrimmed = result.trimLeft();
    if (fuTrimmed.startsWith(_followUpReplyStart)) {
      final fuEndIndex = fuTrimmed.indexOf(_followUpReplyEnd);
      if (fuEndIndex != -1) {
        result = fuTrimmed
            .substring(fuEndIndex + _followUpReplyEnd.length)
            .trimLeft();
      }
    }

    return result;
  }

  String? _extractMessageText(dynamic raw) {
    if (raw == null) return null;

    if (raw is String) {
      final t = raw.trim();
      if (t.isEmpty) return '';

      final decoded = _tryDecodeJsonLike(t);
      if (decoded is Map) {
        final extracted = _extractMessageTextFromMap(
          Map<String, dynamic>.from(decoded),
        );
        if (extracted != null && extracted.trim().isNotEmpty) return extracted;
      }

      return raw;
    }

    if (raw is Map) {
      final extracted = _extractMessageTextFromMap(
        Map<String, dynamic>.from(raw),
      );
      if (extracted != null) return extracted;
      try {
        return jsonEncode(raw);
      } catch (_) {
        return raw.toString();
      }
    }

    return raw.toString();
  }

  String? _extractMessageTextFromMap(Map<String, dynamic> map) {
    final candidates = <dynamic>[
      map['messageText'],
      map['message_text'],
      map['message'],
      map['text'],
      map['body'],
    ];

    for (final v in candidates) {
      if (v is String) {
        final t = v.trim();
        if (t.isNotEmpty && t != 'null') return t;
      } else if (v is Map) {
        final nested = _extractMessageTextFromMap(Map<String, dynamic>.from(v));
        if (nested != null && nested.trim().isNotEmpty) return nested;
      }
    }

    return null;
  }

  dynamic _tryDecodeJsonLike(String s) {
    dynamic decoded;
    try {
      decoded = jsonDecode(s);
    } catch (_) {
      decoded = null;
    }

    if (decoded == null) {
      try {
        final uriDecoded = Uri.decodeComponent(s);
        if (uriDecoded != s) {
          decoded = jsonDecode(uriDecoded);
        }
      } catch (_) {}
    }

    if (decoded == null && s.startsWith('{') && s.contains(r'\"')) {
      try {
        decoded = jsonDecode(s.replaceAll(r'\"', '"'));
      } catch (_) {
        decoded = null;
      }
    }

    return decoded;
  }

  Map<String, dynamic>? _tryDecodeEmbeddedBodyMap(Map<String, dynamic> data) {
    final raw =
        data['body'] ?? data['messageText'] ?? data['message'] ?? data['text'];

    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }

    if (raw is String) {
      final t = raw.trim();
      if (t.isEmpty) return null;
      final decoded = _tryDecodeJsonLike(t);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    }

    return null;
  }

  /// Handle message when app is opened from notification
  Future<void> _handleMessageOpenedApp(RemoteMessage message) async {
    try {
      debugPrint(
        '🔔 [OpenedApp] User tapped notification: ${message.messageId}',
      );
      debugPrint('🔔 [OpenedApp] Data: ${message.data}');

      // Handle navigation based on message type
      await _handleNotificationTap(message.data);
    } catch (e) {
      debugPrint('❌ [OpenedApp] Error handling message: $e');
    }
  }

  /// Handle message when app was terminated
  /// Should be called from AppGatePage after navigation context is ready
  Future<void> checkTerminatedMessage() async {
    try {
      final message = await _firebaseMessaging.getInitialMessage();

      if (message != null) {
        // Small delay to ensure navigation context is fully ready
        await Future.delayed(const Duration(milliseconds: 500));

        debugPrint('🔔 [Terminated] Now calling _handleNotificationTap...');
        await _handleNotificationTap(message.data);
      }
    } catch (e) {
      debugPrint('❌ [Terminated] Error handling message: $e');
      debugPrint('❌ Stack trace: ${StackTrace.current}');
    }
  }

  //=================================================================
  // DATA PROCESSING (Kotlin handles notification display on Android)
  //=================================================================

  /// Parse FCM data and process it (no notification display - Kotlin handles that)
  /// On Android: Kotlin shows notification with phonebook contact name
  /// This method only saves data to DB and handles silent updates
  Future<void> _parseAndProcessData(RemoteMessage message) async {
    // ALWAYS parse and show notification - regardless of platform or payload type
    // The notification field is just metadata from FCM, we need to process data field
    await _parseAndShowNotification(message);

    if (Platform.isAndroid) {
      await _saveMessageToDatabase(message);
    }
  }

  //=================================================================
  // NOTIFICATION PARSING AND DISPLAY (iOS only now)
  //=================================================================

  /// Parse FCM message and show appropriate notification (iOS only)
  Future<void> _parseAndShowNotification(RemoteMessage message) async {
    try {
      final data = message.data;

      if (data.isEmpty) {
        debugPrint(
          '⚠️ [Parser] Empty data payload. Falling back to notification fields.',
        );
        await _handleNotificationPayloadOnly(message);
        return;
      }

      // Get message type - support multiple formats from backend
      final type =
          data['type'] as String? ??
          data['chatType'] as String? ??
          data['notificationType'] as String? ??
          data['messageType'] as String? ??
          data['message_type'] as String? ??
          'unknown';

      final handledAsChatMessage = await MessageNotificationHandler.tryHandle(
        message: message,
        type: type,
        handle: _handleChatMessage,
      );
      if (handledAsChatMessage) {
        return;
      }

      final handledAsStoryChat = await StoriesNotificationHandler.tryHandle(
        message: message,
        type: type,
        handleAsChatMessage: _handleChatMessage,
      );
      if (handledAsStoryChat) {
        return;
      }

      debugPrint(
        '📩 [DEVICE_B_FLUTTER_FCM] Checking isChatPictureNotification...',
      );
      if (ChatPictureNotificationHandler.isChatPictureNotification(data)) {
        debugPrint(
          '✅ [DEVICE_B_FLUTTER_FCM] MATCHED! Calling ChatPictureNotificationHandler.handle()',
        );
        await ChatPictureNotificationHandler.handle(data);
        return;
      } else {
        debugPrint(
          '❌ [DEVICE_B_FLUTTER_FCM] NOT a chat picture notification by structure',
        );
      }

      if (ShareYourVoiceNotificationHandler.isShareYourVoiceNotification(
        data,
      )) {
        await ShareYourVoiceNotificationHandler.handle(data);
        return;
      }

      switch (type) {
        case 'chat_message':
        case 'message':
        case 'private_message': // Support backend's format
          await _handleChatMessage(message);
          break;
        case 'reaction':
        case 'message_reaction':
        case 'message-reaction':
        case 'reaction_updated':
        case 'reaction-updated':
          await _handleReactionNotification(message);
          break;
        case 'voice_call':
        case 'call':
        case 'incoming_call':
          await _handleVoiceCall(message);
          break;
        case 'friend_request':
          await _handleFriendRequest(message);
          break;
        case 'profile_update':
        case 'profile-updated':
          // WHATSAPP-STYLE: Silent update - no notification shown
          await ProfileUpdateSilentFcmHandler.handle(data);
          break;
        case 'CONTACTS_CHANGED':
        case 'contacts_changed':
          await _handleContactsChangedFCM(data);
          break;
        case 'contact_joined':
          // WHATSAPP-STYLE: Contact joined - update local DB silently
          await _handleContactJoinedFCM(data);
          break;
        case 'chat_picture_like':
        case 'chatPictureLike':
        case 'picture_like':
        case 'profile_picture_like':
          debugPrint('✅ [DEVICE_B_FLUTTER_FCM] SWITCH CASE MATCHED: $type');
          await ChatPictureNotificationHandler.handle(data);
          break;
        case 'status_like':
          await ShareYourVoiceNotificationHandler.handle(data);
          break;
        // STORY NOTIFICATIONS - SILENT (no user-facing notification)
        case 'story_created':
        case 'story-created':
        case 'new_story':
        case 'contact_story':
        case 'story_viewed':
        case 'story-viewed':
        case 'story_view':
        case 'story_deleted':
        case 'story-deleted':
        case 'delete_story':
        case 'story_expired':
        case 'story-expired':
          // WHATSAPP-STYLE: Silent update - no notification shown
          await StoriesSilentFcmHandler.handle(data);
          break;
        default:
          // Check if this is a profile update by data fields
          if ((data.containsKey('updatedData') ||
                  data.containsKey('updatedFields')) &&
              data.containsKey('userId')) {
            await ProfileUpdateSilentFcmHandler.handle(data);
            break;
          }
          // Check if this is a story notification by data fields or type pattern
          if (StoriesSilentFcmHandler.isStoryNotification(data)) {
            await StoriesSilentFcmHandler.handle(data);
            break;
          }
          await _handleGenericNotification(message);
      }
    } catch (e) {
      debugPrint('❌ [Parser] Error parsing notification: $e');
    }
  }

  /// Handle contact joined FCM (SILENT - no notification)
  /// WhatsApp-style: When a contact joins the app, update their status in local DB
  /// and notify UI so the contacts list updates automatically
  Future<void> _handleContactJoinedFCM(Map<String, dynamic> data) async {
    try {
      debugPrint('👥 [FCM] Processing contact_joined silently...');
      debugPrint('👥 [FCM] Data: $data');

      final userId = data['userId'] as String?;
      final mobileNo = data['mobileNo'] as String?;
      final name = data['name'] as String?;
      final profilePic =
          data['profilePic'] as String? ??
          data['profile'
                  'PicUrl']
              as String? ??
          data['profile_pic'] as String? ??
          data['chat_picture'] as String?;

      final chatPictureVersion =
          data['chat_picture_version']?.toString() ??
          data['chatPictureVersion']?.toString() ??
          data['profilePicVersion']?.toString() ??
          data['profile_pic_version']?.toString();

      if (userId == null || mobileNo == null) {
        debugPrint(
          '👥 [FCM] Invalid contact_joined - missing userId or mobileNo',
        );
        return;
      }

      debugPrint('👥 [FCM] Contact joined: $name ($mobileNo)');

      // Update local contacts database
      final updated = await ContactsDatabaseService.instance
          .handleContactJoined(
            userId: userId,
            mobileNo: mobileNo,
            name: name,
            chatPictureUrl: profilePic,
            chatPictureVersion: chatPictureVersion,
          );

      if (updated) {
        debugPrint('✅ [FCM] Contact updated in local DB');

        // Notify UI via ChatEngineService stream (same as profile updates)
        ChatEngineService.instance.notifyContactJoined(
          userId: userId,
          mobileNo: mobileNo,
          name: name,
          chatPictureUrl: profilePic,
        );
      } else {
        debugPrint(
          '⚠️ [FCM] Contact not found in local DB (user may not have this number saved)',
        );
      }

      debugPrint('👥 [FCM] contact_joined processed - NO notification shown');
    } catch (e) {
      debugPrint('❌ [FCM] Error handling contact_joined: $e');
    }
  }

  Future<void> _handleContactsChangedFCM(Map<String, dynamic> data) async {
    try {
      debugPrint('📇 [FCM] Processing CONTACTS_CHANGED silently...');
      debugPrint('📇 [FCM] Data: $data');

      final userId =
          data['userId'] as String? ??
          data['appUserId'] as String? ??
          data['app_user_id'] as String?;
      final mobileNo =
          data['mobileNo'] as String? ??
          data['mobile_no'] as String? ??
          data['phone'] as String? ??
          data['phoneNumber'] as String?;

      final hasIdentifier =
          (userId != null && userId.trim().isNotEmpty) ||
          (mobileNo != null && mobileNo.trim().isNotEmpty);

      if (hasIdentifier) {
        // Shape 1: Device B joins - has userId/mobileNo → refresh single contact
        debugPrint(
          '📇 [FCM] CONTACTS_CHANGED with identifier - refreshing single contact',
        );

        final resolvedUserId = (userId ?? '').toString().trim();
        final resolvedMobileNo = (mobileNo ?? '').toString().trim();

        final rawName = data['name']?.toString();
        final name = (rawName != null && rawName.trim().isNotEmpty)
            ? rawName.trim()
            : null;

        final rawChatPicture =
            data['chat_picture']?.toString() ??
            data['profilePic']?.toString() ??
            data['profile_pic']?.toString() ??
            data['profilePicUrl']?.toString();
        final chatPicture =
            (rawChatPicture != null && rawChatPicture.trim().isNotEmpty)
            ? rawChatPicture.trim()
            : null;

        final rawChatPictureVersion =
            data['chat_picture_version']?.toString() ??
            data['chatPictureVersion']?.toString() ??
            data['profilePicVersion']?.toString() ??
            data['profile_pic_version']?.toString();
        final chatPictureVersion =
            (rawChatPictureVersion != null &&
                rawChatPictureVersion.trim().isNotEmpty)
            ? rawChatPictureVersion.trim()
            : null;

        final rawStatus = data['share_your_voice']?.toString();
        final statusContent = (rawStatus != null && rawStatus.trim().isNotEmpty)
            ? rawStatus.trim()
            : null;

        final rawEmoji = data['emojis_update']?.toString();
        final emoji = (rawEmoji != null && rawEmoji.trim().isNotEmpty)
            ? rawEmoji.trim()
            : null;

        final rawEmojiCaption = data['emojis_caption']?.toString();
        final emojiCaption =
            (rawEmojiCaption != null && rawEmojiCaption.trim().isNotEmpty)
            ? rawEmojiCaption.trim()
            : null;

        var updatedLocally = false;
        if (resolvedUserId.isNotEmpty && resolvedMobileNo.isNotEmpty) {
          updatedLocally = await ContactsDatabaseService.instance
              .handleContactsChanged(
                userId: resolvedUserId,
                mobileNo: resolvedMobileNo,
                name: name,
                chatPictureUrl: chatPicture,
                chatPictureVersion: chatPictureVersion,
                statusContent: statusContent,
                emoji: emoji,
                emojiCaption: emojiCaption,
              );
        }

        if (!updatedLocally) {
          final updated = await _contactsRepository.refreshSingleContactFromApi(
            mobileNo: mobileNo,
            userId: userId,
          );
          if (updated == null) {
            debugPrint('📇 [FCM] No local contact found to update');
            return;
          }
        }

        // Set dirty flag for app resume
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(_contactsDirtyKey, true);
          await prefs.setInt(
            _contactsDirtyAtKey,
            DateTime.now().millisecondsSinceEpoch,
          );
        } catch (e) {
          debugPrint('⚠️ [ContactsDirty] Failed to set dirty: $e');
        }

        // Notify UI
        final idToNotify = resolvedUserId.isNotEmpty
            ? resolvedUserId
            : (resolvedMobileNo.isNotEmpty
                  ? resolvedMobileNo
                  : 'contacts_changed');
        ChatEngineService.instance.notifyContactJoined(
          userId: idToNotify,
          mobileNo: resolvedMobileNo.isNotEmpty
              ? resolvedMobileNo
              : 'contacts_changed',
          name: name,
          chatPictureUrl: chatPicture,
        );
        debugPrint(
          '📇 [FCM] CONTACTS_CHANGED (single) processed - UI notified',
        );
      } else {
        // Shape 2: Contact sync - no identifier → trigger full contacts re-sync
        debugPrint(
          '📇 [FCM] CONTACTS_CHANGED without identifier - triggering full sync',
        );

        // Set dirty flag
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(_contactsDirtyKey, true);
          await prefs.setInt(
            _contactsDirtyAtKey,
            DateTime.now().millisecondsSinceEpoch,
          );
        } catch (e) {
          debugPrint('⚠️ [ContactsDirty] Failed to set dirty: $e');
        }

        // Trigger full contacts sync in background isolate
        try {
          final syncResult = await ContactSyncIsolateHandler().syncContacts();
          debugPrint(
            '📇 [FCM] Full sync completed: ${syncResult.success}, contacts: ${syncResult.contactCount}',
          );
        } catch (e) {
          debugPrint('⚠️ [FCM] Full sync failed: $e');
        }

        // Notify UI to refresh from cache
        ChatEngineService.instance.notifyContactJoined(
          userId: 'contacts_changed_full',
          mobileNo: 'contacts_changed_full',
        );
        debugPrint(
          '📇 [FCM] CONTACTS_CHANGED (full sync) processed - UI notified',
        );
      }
    } catch (e) {
      debugPrint('❌ [FCM] Error handling CONTACTS_CHANGED: $e');
    }
  }

  Future<void> _handleNotificationPayloadOnly(RemoteMessage message) async {
    try {
      final notif = message.notification;
      if (notif == null) {
        debugPrint(
          '⚠️ [Fallback] No notification fields present; cannot show.',
        );
        return;
      }

      final title = notif.title ?? 'New message';
      final body = notif.body ?? 'You have a new message';

      // WHATSAPP-STYLE: Suppress ANY notification with generic body "You have a new message"
      // These are ALWAYS duplicates - we always show a richer notification with actual message content
      // Covers cases like "sanjay / You have a new message" (sender's app name + generic body)
      final lowerBody = body.trim().toLowerCase();
      final isGenericBody =
          lowerBody == 'you have a new message' || lowerBody == 'new message';
      if (isGenericBody) {
        debugPrint(
          '🔕 [Fallback] Skipping generic notification (body="$body") to avoid duplicates',
        );
        return;
      }

      // Check if title looks like a UUID
      final isUuidTitle = title.contains('-') && title.length > 30;

      final rawKey = message.from ?? title;
      final sanitized = rawKey
          .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
          .toLowerCase();
      final fallbackSenderId = sanitized.isNotEmpty
          ? 'fcm_$sanitized'
          : 'fcm_unknown';

      // If title is UUID, try to use it as senderId for contact lookup
      String displayName = isUuidTitle ? 'ChatAway User' : title;
      String senderIdToUse = isUuidTitle ? title : fallbackSenderId;
      String? chatPictureUrl;

      debugPrint(
        '🔍 [Fallback] Looking up contact, isUuidTitle=$isUuidTitle, title=$title',
      );

      try {
        final db = await AppDatabaseManager.instance.database;

        // If title is UUID, lookup contact by that UUID using multiple methods
        if (isUuidTitle) {
          // Method 1: Direct app_user_id lookup
          var rows = await db.query(
            'contacts',
            where: 'app_user_id = ?',
            whereArgs: [title],
            limit: 1,
          );
          debugPrint(
            '🔍 [Fallback] Method 1 (app_user_id): ${rows.length} results',
          );

          // Method 2: Search in user_details JSON
          if (rows.isEmpty) {
            rows = await db.rawQuery(
              "SELECT * FROM contacts WHERE user_details LIKE ? LIMIT 1",
              ['%"id":"$title"%'],
            );
            debugPrint(
              '🔍 [Fallback] Method 2 (user_details JSON): ${rows.length} results',
            );
          }

          // Method 3: Try with "userId" key in JSON
          if (rows.isEmpty) {
            rows = await db.rawQuery(
              "SELECT * FROM contacts WHERE user_details LIKE ? LIMIT 1",
              ['%"userId":"$title"%'],
            );
            debugPrint(
              '🔍 [Fallback] Method 3 (userId JSON): ${rows.length} results',
            );
          }

          if (rows.isNotEmpty) {
            final contact = ContactLocal.fromMap(rows.first);
            displayName = contact.preferredDisplayName;
            senderIdToUse = title;
            chatPictureUrl = contact.userDetails?.chatPictureUrl;
            debugPrint('✅ [Fallback] Found contact by UUID: $displayName');
          } else {
            debugPrint('⚠️ [Fallback] No contact found for UUID: $title');
          }
        } else {
          // Try to match by name
          final contacts = await _contactsRepository.loadAllContacts();
          final lowerTitle = title.trim().toLowerCase();
          ContactLocal? matched;
          for (final c in contacts) {
            final n1 = c.name.trim().toLowerCase();
            final n2 = c.userDetails?.appdisplayName.trim().toLowerCase();
            if (n1 == lowerTitle || (n2 != null && n2 == lowerTitle)) {
              matched = c;
              break;
            }
          }
          if (matched != null) {
            final uid = matched.userDetails?.userId;
            if (uid != null && uid.isNotEmpty) {
              senderIdToUse = uid;
              displayName = matched
                  .preferredDisplayName; // Use device contact name, not app name
              chatPictureUrl = matched.userDetails?.chatPictureUrl;
              debugPrint('✅ [Fallback] Found contact by name: $displayName');
            }
          }
        }
      } catch (e) {
        debugPrint('⚠️ [Fallback] Contact lookup failed: $e');
      }

      debugPrint('📝 [Fallback] Final displayName: $displayName');

      final conversationId = senderIdToUse;

      final activeWith = ChatEngineService.instance.activeConversationUserId;
      final isActiveChat = activeWith != null && activeWith == senderIdToUse;

      final shouldShowByAppState = AppStateService.instance
          .shouldShowNotification(senderIdToUse);

      if (!shouldShowByAppState || isActiveChat) {
        debugPrint(
          '🔕 [Fallback] Suppressed notification (AppStateService / active chat). '
          'senderId=$senderIdToUse state=${AppStateService.instance.debugState}',
        );
        return;
      }

      final rawMessageId = message.messageId;
      final shouldShow = ChatEngineService.instance
          .markNotificationShownIfFirst(rawMessageId);
      if (!shouldShow) {
        debugPrint(
          '🔕 [Fallback] Notification already shown for this messageId - skipping',
        );
        return;
      }

      await _localNotificationService.showChatMessageNotification(
        notificationId:
            rawMessageId ?? message.messageId ?? DateTime.now().toString(),
        senderName: displayName,
        messageText: body,
        conversationId: conversationId,
        senderId: senderIdToUse,
        senderProfilePic: chatPictureUrl,
        messageType: null, // Fallback path doesn't have messageType info
      );
    } catch (e) {
      debugPrint('❌ [Fallback] Error handling notification-only message: $e');
    }
  }

  /// Handle chat message notification
  Future<void> _handleChatMessage(RemoteMessage message) async {
    final chatMsgStartTime = DateTime.now();
    try {
      final data = message.data;
      // final notification = message.notification;

      // If this FCM actually represents a profile update, route it to the
      // silent profile-update handler instead of treating it as a chat message.
      final notificationType =
          (data['notificationType'] as String?) ??
          (data['type'] as String?) ??
          (data['messageType'] as String?) ??
          (data['message_type'] as String?);
      final looksLikeProfileUpdate =
          notificationType == 'profile_update' ||
          notificationType == 'profile-updated' ||
          ((data.containsKey('updatedData') ||
                  data.containsKey('updatedFields')) &&
              data.containsKey('userId'));
      if (looksLikeProfileUpdate) {
        debugPrint(
          '👤 [ChatMessage] Detected profile update via chat_message path → routing to ProfileUpdateSilentFcmHandler',
        );
        await ProfileUpdateSilentFcmHandler.handle(data);
        return;
      }

      // Log all FCM data fields for debugging contact lookup issues
      debugPrint('📦 [ChatMessage] FCM data keys: ${data.keys.toList()}');

      // Extract message details - support multiple backend formats
      final senderId =
          data['sender_id'] as String? ??
          data['senderId'] as String? ??
          data['from_user_id'] as String? ??
          data['fromUserId'] as String? ??
          data['actor_id'] as String? ??
          data['actorId'] as String? ??
          data['user_id'] as String? ??
          data['userId'] as String? ??
          'unknown';
      final senderPhone =
          data['senderPhone'] as String? ??
          data['sender_phone'] as String? ??
          data['phone'] as String? ??
          data['senderMobile'] as String? ??
          data['sender_mobile_number'] as String? ??
          data['senderMobileNumber'] as String?;
      final senderName =
          data['senderFirstName']
              as String? ?? // Support your backend format - PRIORITY
          data['senderName'] as String? ??
          data['sender_name'] as String? ??
          // notification?.title ?? // Only use notification as last resort
          'Unknown';

      debugPrint('📱 [ChatMessage] Sender phone from FCM: $senderPhone');
      Map<String, dynamic>? embedded;
      String? rawMessageType =
          data['messageType']?.toString() ?? data['message_type']?.toString();
      if (rawMessageType == null || rawMessageType.trim().isEmpty) {
        embedded = _tryDecodeEmbeddedBodyMap(data);
        rawMessageType =
            embedded?['messageType']?.toString() ??
            embedded?['message_type']?.toString();
      }
      final parsedType = ChatMessageModel.parseMessageType(rawMessageType);

      dynamic fileUrl =
          data['fileUrl'] ??
          data['file_url'] ??
          data['imageUrl'] ??
          data['image_url'] ??
          data['videoUrl'] ??
          data['video_url'];
      if (fileUrl == null) {
        embedded ??= _tryDecodeEmbeddedBodyMap(data);
        fileUrl =
            embedded?['fileUrl'] ??
            embedded?['file_url'] ??
            embedded?['imageUrl'] ??
            embedded?['image_url'] ??
            embedded?['videoUrl'] ??
            embedded?['video_url'];
      }

      dynamic mimeType = data['mimeType'] ?? data['mime_type'];
      if (mimeType == null) {
        embedded ??= _tryDecodeEmbeddedBodyMap(data);
        mimeType = embedded?['mimeType'] ?? embedded?['mime_type'];
      }

      Map<String, dynamic>? fileMetadata;
      try {
        final raw = data['fileMetadata'];
        if (raw is Map) {
          fileMetadata = Map<String, dynamic>.from(raw);
        } else if (raw is String && raw.trim().isNotEmpty) {
          final decoded = jsonDecode(raw);
          if (decoded is Map) {
            fileMetadata = Map<String, dynamic>.from(decoded);
          }
        }
      } catch (_) {}

      int? tryParseInt(dynamic v) {
        if (v == null) return null;
        if (v is int) return v;
        return int.tryParse(v.toString());
      }

      final fileName =
          (fileMetadata?['fileName'] ?? data['fileName'] ?? data['file_name'])
              ?.toString();
      final fileSize =
          tryParseInt(fileMetadata?['fileSize']) ??
          tryParseInt(data['fileSize'] ?? data['file_size']);
      final pageCount =
          tryParseInt(fileMetadata?['pageCount']) ??
          tryParseInt(data['pageCount'] ?? data['page_count']);

      var messageText =
          data['messageText'] as String? ?? // Support your backend format
          data['message'] as String? ??
          data['body'] as String? ??
          '';

      final looksLikeJson =
          messageText.trim().startsWith('{') ||
          messageText.trim().startsWith('[') ||
          messageText.contains('"messageType"') ||
          messageText.contains('"message":null');

      if ((messageText.trim().isEmpty || looksLikeJson) &&
          parsedType != MessageType.text) {
        if (parsedType == MessageType.image) {
          messageText = ImageNotificationHandler.normalizeMessageText(
            messageText: messageText,
            messageType: rawMessageType ?? 'image',
            looksLikeJson: looksLikeJson,
          );
        } else if (parsedType == MessageType.document) {
          messageText = (fileName ?? '').trim().isNotEmpty ? fileName! : 'PDF';
        } else if (parsedType == MessageType.video) {
          messageText = 'Video';
        } else if (parsedType == MessageType.audio) {
          messageText = 'Voice message';
        } else {
          messageText = ImageNotificationHandler.normalizeMessageText(
            messageText: messageText,
            messageType: rawMessageType,
            fileName: fileName,
            looksLikeJson: looksLikeJson,
          );
        }
      }

      if (messageText.trim().isEmpty) {
        messageText = 'New message';
      }
      final conversationId =
          data['conversation_id'] as String? ??
          data['conversationId'] as String? ??
          data['messageId'] as String? ?? // Support your backend format
          senderId;
      final senderProfilePic =
          data['sender_profile_pic'] as String? ??
          data['senderProfilePic'] as String? ?? // Support your backend format
          data['profile_pic'] as String? ??
          data['profilePic'] as String? ??
          data['sender_chat_picture'] as String? ??
          data['senderChatPicture'] as String?;

      debugPrint('💬 [ChatMessage] From: $senderName ($senderId)');
      debugPrint('💬 [ChatMessage] Message: $messageText');
      debugPrint('💬 [ChatMessage] Conversation: $conversationId');

      // Debug: Log all FCM data to identify timestamp field from backend
      debugPrint('📦 [FCM DEBUG] All data keys: ${data.keys.toList()}');
      debugPrint('📦 [FCM DEBUG] Full data: $data');

      // Build ChatMessageModel for local persistence via ChatEngineService
      final dbStartTime = DateTime.now();
      final currentUserId = await _tokenStorage.getCurrentUserIdUUID();
      debugPrint(
        '⏱️ [FCM TIMING] Got userId: ${DateTime.now().difference(dbStartTime).inMilliseconds}ms',
      );

      if (currentUserId != null && currentUserId.isNotEmpty) {
        try {
          // Ensure chat service knows the current user before saving to DB
          final initStart = DateTime.now();
          await ChatEngineService.instance.initialize(currentUserId);
          debugPrint(
            '⏱️ [FCM TIMING] ChatEngineService init: ${DateTime.now().difference(initStart).inMilliseconds}ms',
          );

          // CRITICAL: Extract server timestamp for correct message ordering
          // Backend may send timestamp with different keys - try all possible formats
          final createdAtRaw =
              data['createdAt'] as String? ??
              data['created_at'] as String? ??
              data['timestamp'] as String? ??
              data['sentAt'] as String? ??
              data['sent_at'] as String? ??
              data['time'] as String?;

          // Also try numeric timestamp (milliseconds since epoch)
          final timestampMs =
              int.tryParse(data['timestampMs']?.toString() ?? '') ??
              int.tryParse(data['timestamp_ms']?.toString() ?? '') ??
              int.tryParse(data['createdAtMs']?.toString() ?? '');

          DateTime messageCreatedAt;
          if (createdAtRaw != null) {
            messageCreatedAt =
                DateTime.tryParse(createdAtRaw) ?? DateTime.now();
            debugPrint('📅 [FCM] Using server createdAt: $messageCreatedAt');
          } else if (timestampMs != null) {
            messageCreatedAt = DateTime.fromMillisecondsSinceEpoch(timestampMs);
            debugPrint('📅 [FCM] Using server timestampMs: $messageCreatedAt');
          } else {
            messageCreatedAt = DateTime.now();
            debugPrint('⚠️ [FCM] No server timestamp - using DateTime.now()');
          }

          final updatedAt =
              data['updatedAt'] as String? ?? data['updated_at'] as String?;
          final chatId =
              data['messageUuid'] as String? ??
              data['message_uuid'] as String? ??
              data['messageId'] as String? ??
              data['message_id'] as String? ??
              data['id'] as String? ??
              data['chatId'] as String? ??
              message.messageId ??
              'fcm_${DateTime.now().millisecondsSinceEpoch}';

          // If this message already exists in local DB, skip processing entirely
          try {
            if (chatId.isNotEmpty) {
              final existing = await MessagesTable.instance.getMessageById(
                chatId,
              );
              if (existing != null) {
                debugPrint(
                  '🔕 [FCM] Message already exists in DB - skipping FCM processing: $chatId',
                );
                return;
              }
            }
          } catch (e) {
            debugPrint('⚠️ [FCM] Failed to check existing message in DB: $e');
            // continue - attempt to save if DB lookup failed
          }

          final fcmChatMessage = ChatMessageModel(
            id: chatId,
            senderId: senderId,
            receiverId: currentUserId,
            message: messageText,
            messageStatus: 'delivered',
            isRead: false,
            createdAt: messageCreatedAt,
            updatedAt: updatedAt != null
                ? DateTime.tryParse(updatedAt) ?? messageCreatedAt
                : messageCreatedAt,
            deliveryChannel: 'fcm',
            messageType: parsedType,
            imageUrl: fileUrl?.toString(),
            mimeType: mimeType?.toString(),
            fileName: fileName?.toString(),
            fileSize: fileSize,
            pageCount: pageCount,
          );

          // Persist to chat DB using hybrid flow (fire-and-forget for speed)
          final saveStart = DateTime.now();
          // Don't await - let it save in background for faster notification
          ChatEngineService.instance
              .saveFCMMessage(fcmChatMessage)
              .then((_) {
                debugPrint(
                  '⏱️ [FCM TIMING] saveFCMMessage completed: ${DateTime.now().difference(saveStart).inMilliseconds}ms',
                );
              })
              .catchError((e) {
                debugPrint(
                  '❌ [ChatMessage] Failed to persist FCM to chat DB: $e',
                );
              });
        } catch (e) {
          debugPrint('❌ [ChatMessage] Failed to persist FCM to chat DB: $e');
        }
      }
      debugPrint(
        '⏱️ [FCM TIMING] DB setup: ${DateTime.now().difference(chatMsgStartTime).inMilliseconds}ms',
      );

      // Get sender name from local contacts (phone's saved name)
      // ALWAYS prefer contact name over backend name (user recognizes their saved name)
      String displayName = senderName;
      String? chatPictureUrl = senderProfilePic;

      // Check if backend sent a UUID as name (common issue)
      final isUuidName = senderName.contains('-') && senderName.length > 30;

      debugPrint('🔍 [ChatMessage] Looking up contact for senderId: $senderId');
      debugPrint('🔍 [ChatMessage] Backend senderName: $senderName');

      // Quick contact lookup - try multiple methods
      final contactLookupStart = DateTime.now();
      try {
        final db = await AppDatabaseManager.instance.database;

        // Method 1: Direct app_user_id lookup
        var rows = await db.query(
          'contacts',
          where: 'app_user_id = ?',
          whereArgs: [senderId],
          limit: 1,
        );
        debugPrint(
          '🔍 [ChatMessage] Method 1 (app_user_id): ${rows.length} results',
        );

        // Method 2: Search in user_details JSON if Method 1 fails
        if (rows.isEmpty) {
          rows = await db.rawQuery(
            "SELECT * FROM contacts WHERE user_details LIKE ? LIMIT 1",
            ['%"id":"$senderId"%'],
          );
          debugPrint(
            '🔍 [ChatMessage] Method 2 (user_details JSON): ${rows.length} results',
          );
        }

        // Method 3: Try with "userId" key in JSON
        if (rows.isEmpty) {
          rows = await db.rawQuery(
            "SELECT * FROM contacts WHERE user_details LIKE ? LIMIT 1",
            ['%"userId":"$senderId"%'],
          );
          debugPrint(
            '🔍 [ChatMessage] Method 3 (userId JSON): ${rows.length} results',
          );
        }

        // Method 4: Try by phone number if available (WHATSAPP-STYLE)
        if (rows.isEmpty && senderPhone != null && senderPhone.isNotEmpty) {
          // Normalize phone number (remove +, spaces, etc.)
          final normalizedPhone = senderPhone.replaceAll(RegExp(r'[^\d]'), '');
          final lastDigits = normalizedPhone.length >= 10
              ? normalizedPhone.substring(normalizedPhone.length - 10)
              : normalizedPhone;

          rows = await db.rawQuery(
            "SELECT * FROM contacts WHERE mobile_no LIKE ? LIMIT 1",
            ['%$lastDigits%'],
          );
          debugPrint(
            '🔍 [ChatMessage] Method 4 (phone): ${rows.length} results for $lastDigits',
          );
        }

        // Method 5: Search by backend name in contacts (last resort before giving up)
        if (rows.isEmpty && senderName != 'Unknown' && !isUuidName) {
          final lowerName = senderName.toLowerCase().trim();
          rows = await db.rawQuery(
            "SELECT * FROM contacts WHERE LOWER(name) LIKE ? OR user_details LIKE ? OR user_details LIKE ? LIMIT 1",
            [
              '%$lowerName%',
              '%"fullName":"$senderName"%',
              '%"contact_name":"$senderName"%',
            ],
          );
          debugPrint(
            ' [ChatMessage] Method 5 (name match): ${rows.length} results for "$senderName"',
          );
        }

        if (rows.isNotEmpty) {
          final contact = ContactLocal.fromMap(rows.first);
          // Use contact name (phone's saved name) - this is what user recognizes
          displayName = contact.preferredDisplayName;
          chatPictureUrl =
              contact.userDetails?.chatPictureUrl ?? senderProfilePic;
          debugPrint(
            ' [ChatMessage] Found contact: $displayName (profile: $chatPictureUrl)',
          );

          // IMPORTANT: Update app_user_id mapping for faster future lookups
          if (contact.appUserId == null || contact.appUserId!.isEmpty) {
            try {
              await db.update(
                'contacts',
                {'app_user_id': senderId},
                where: 'contact_hash = ?',
                whereArgs: [contact.contactHash],
              );
              debugPrint(
                ' [ChatMessage] Updated app_user_id mapping for ${contact.preferredDisplayName}',
              );
            } catch (_) {}
          }
        } else {
          debugPrint(' [ChatMessage] No contact found for senderId: $senderId');

          if (isUuidName || senderName == 'Unknown') {
            displayName = 'ChatAway User';
            debugPrint(' [ChatMessage] Using fallback name: ChatAway User');
          }
          // Keep backend name if it's a real name (not UUID/Unknown)
        }
      } catch (e) {
        debugPrint(' [ChatMessage] Contact lookup failed: $e');
        if (isUuidName) displayName = 'ChatAway User';
      }
      debugPrint(
        ' [FCM TIMING] Contact lookup: ${DateTime.now().difference(contactLookupStart).inMilliseconds}ms',
      );
      debugPrint(' [ChatMessage] Final displayName: $displayName');

      // WhatsApp-style suppression check (fast - no await)
      final activeWith = ChatEngineService.instance.activeConversationUserId;
      final isActiveChat = (activeWith != null && activeWith == senderId);

      final shouldShowByAppState = AppStateService.instance
          .shouldShowNotification(senderId);

      if (!shouldShowByAppState || isActiveChat) {
        debugPrint(
          ' [ChatMessage] Notification suppressed by AppStateService '
          '(senderId=$senderId, state=${AppStateService.instance.debugState})',
        );
      } else {
        final rawMessageId =
            data['messageUuid'] as String? ??
            data['message_uuid'] as String? ??
            data['messageId'] as String? ??
            data['message_id'] as String? ??
            data['id'] as String? ??
            data['chatId'] as String? ??
            message.messageId;

        // Use in-memory dedup FIRST (fast, no DB race condition)
        // This prevents showing duplicate notifications for the same message
        final shouldShow = ChatEngineService.instance
            .markNotificationShownIfFirst(rawMessageId);
        if (!shouldShow) {
          debugPrint(
            ' [ChatMessage] Notification already shown for this messageId - skipping',
          );
          return;
        }

        // NOTE: Removed the duplicate DB check here to avoid race condition
        // The check at line ~1347 already verifies message doesn't exist in DB
        // Adding another check here can cause race with fire-and-forget save

        final notifStart = DateTime.now();
        await _localNotificationService.showChatMessageNotification(
          notificationId:
              rawMessageId ?? message.messageId ?? DateTime.now().toString(),
          senderName: displayName,
          messageText: messageText,
          conversationId: conversationId,
          senderId: senderId,
          senderProfilePic: chatPictureUrl,
          messageType: rawMessageType,
        );
        debugPrint(
          ' [FCM TIMING] showNotification: ${DateTime.now().difference(notifStart).inMilliseconds}ms',
        );
      }

      // Save to database (fire-and-forget - don't block)
      _saveNotificationToDatabase(
        notificationId: message.messageId ?? DateTime.now().toString(),
        type: 'chat_message',
        data: data,
        title: displayName,
        body: messageText,
      );
    } catch (e) {
      debugPrint(' [ChatMessage] Error handling: $e');
    }
  }

  /// Handle voice call notification (FCM push for app closed/background)
  /// WhatsApp-style: Show full-screen incoming call UI, not just a banner
  Future<void> _handleVoiceCall(RemoteMessage message) async {
    try {
      final data = message.data;

      final callId =
          data['call_id'] as String? ??
          data['callId'] as String? ??
          'call_${DateTime.now().millisecondsSinceEpoch}';
      final callerId =
          data['caller_id'] as String? ??
          data['callerId'] as String? ??
          'unknown';
      final callerName =
          data['callerName'] as String? ??
          data['caller_name'] as String? ??
          'Unknown Caller';
      final callerProfilePic =
          data['callerProfilePic'] as String? ??
          data['caller_profile_pic'] as String? ??
          data['profile_pic'] as String?;
      final callTypeStr =
          data['callType'] as String? ??
          data['call_type'] as String? ??
          'voice';
      final channelName =
          data['channelName'] as String? ??
          data['channel_name'] as String? ??
          'ch_${callerId}_$callId';

      debugPrint('📞 [VoiceCall/FCM] From: $callerName ($callerId)');
      debugPrint('📞 [VoiceCall/FCM] Call ID: $callId, type: $callTypeStr');

      // Build IncomingCallSignal and route through CallListenerService
      // This shows the full-screen IncomingCallPage (same as socket path)
      final signal = IncomingCallSignal(
        callId: callId,
        callerId: callerId,
        callerName: callerName,
        callerProfilePic: callerProfilePic,
        callType: callTypeStr == 'video' ? CallType.video : CallType.voice,
        channelName: channelName,
      );

      // Try to show incoming call page directly via navigator
      final navigator = NavigationService.navigatorKey.currentState;
      if (navigator != null) {
        // App is alive — show IncomingCallPage directly
        debugPrint(
          '📞 [VoiceCall/FCM] Navigator available, showing IncomingCallPage',
        );
        CallListenerService.instance.handleFcmIncomingCall(signal);
      } else {
        // App not fully initialized — fall back to notification banner
        debugPrint(
          '📞 [VoiceCall/FCM] Navigator null, showing notification banner',
        );
        await _localNotificationService.showVoiceCallNotification(
          callId: callId,
          callerName: callerName,
          callerId: callerId,
          callerProfilePic: callerProfilePic,
        );
      }

      // Save to database
      await _saveNotificationToDatabase(
        notificationId: message.messageId ?? DateTime.now().toString(),
        type: 'voice_call',
        data: data,
        title: 'Incoming Call',
        body: callerName,
      );
    } catch (e) {
      debugPrint('❌ [VoiceCall/FCM] Error handling: $e');
    }
  }

  /// Handle friend request notification
  Future<void> _handleFriendRequest(RemoteMessage message) async {
    try {
      final data = message.data;

      final requestId =
          data['request_id'] as String? ??
          data['requestId'] as String? ??
          DateTime.now().toString();
      final senderId =
          data['sender_id'] as String? ??
          data['senderId'] as String? ??
          'unknown';
      final senderName =
          data['senderName'] as String? ?? // Priority: backend data first
          data['sender_name'] as String? ??
          'Unknown User';
      final senderProfilePic =
          data['sender_profile_pic'] as String? ??
          data['profile_pic'] as String?;

      debugPrint(' [FriendRequest] From: $senderName ($senderId)');
      debugPrint(' [FriendRequest] Request ID: $requestId');

      // Show friend request notification
      await _localNotificationService.showFriendRequestNotification(
        requestId: requestId,
        senderName: senderName,
        senderId: senderId,
        senderProfilePic: senderProfilePic,
      );

      // Save to database
      await _saveNotificationToDatabase(
        notificationId: message.messageId ?? DateTime.now().toString(),
        type: 'friend_request',
        data: data,
        title: 'Friend Request',
        body: senderName,
      );
    } catch (e) {
      debugPrint(' [FriendRequest] Error handling: $e');
    }
  }

  /// Handle generic notification (fallback for unknown types)
  Future<void> _handleGenericNotification(RemoteMessage message) async {
    try {
      final data = message.data;

      // If this FCM actually represents a profile update, route it to the
      // silent profile-update handler instead of showing a generic message.
      final notificationType =
          (data['notificationType'] as String?) ??
          (data['type'] as String?) ??
          (data['messageType'] as String?) ??
          (data['message_type'] as String?);
      final looksLikeProfileUpdate =
          notificationType == 'profile_update' ||
          notificationType == 'profile-updated' ||
          ((data.containsKey('updatedData') ||
                  data.containsKey('updatedFields')) &&
              data.containsKey('userId'));
      if (looksLikeProfileUpdate) {
        debugPrint(
          '👤 [Generic] Detected profile update via generic path → routing to ProfileUpdateSilentFcmHandler',
        );
        await ProfileUpdateSilentFcmHandler.handle(data);
        return;
      }

      // Extract sender info from data fields only
      final senderId =
          data['sender_id'] as String? ??
          data['senderId'] as String? ??
          'unknown';
      final backendSenderName =
          data['senderFirstName'] as String? ??
          data['senderName'] as String? ??
          data['sender_name'] as String?;
      final messageText =
          data['messageText'] as String? ??
          data['message'] as String? ??
          data['body'] as String? ??
          'New notification';
      final backendProfilePic =
          data['sender_profile_pic'] as String? ??
          data['senderProfilePic'] as String? ??
          data['profile_pic'] as String?;

      // ALWAYS look up contact from local DB for real name & profile pic
      String displayName = backendSenderName ?? 'Unknown Sender';
      String? chatPictureUrl = backendProfilePic;

      // Check if backend sent a UUID as name (common issue)
      final isUuidName = displayName.contains('-') && displayName.length > 30;

      debugPrint(' [Generic] Looking up contact for senderId: $senderId');

      try {
        final db = await AppDatabaseManager.instance.database;

        // Method 1: Direct app_user_id lookup
        var rows = await db.query(
          'contacts',
          where: 'app_user_id = ?',
          whereArgs: [senderId],
          limit: 1,
        );
        debugPrint(' [Generic] Method 1 (app_user_id): ${rows.length} results');

        // Method 2: Search in user_details JSON if Method 1 fails
        if (rows.isEmpty) {
          rows = await db.rawQuery(
            "SELECT * FROM contacts WHERE user_details LIKE ? LIMIT 1",
            ['%"id":"$senderId"%'],
          );
          debugPrint(
            ' [Generic] Method 2 (user_details JSON): ${rows.length} results',
          );
        }

        // Method 3: Try with "userId" key in JSON
        if (rows.isEmpty) {
          rows = await db.rawQuery(
            "SELECT * FROM contacts WHERE user_details LIKE ? LIMIT 1",
            ['%"userId":"$senderId"%'],
          );
          debugPrint(
            ' [Generic] Method 3 (userId JSON): ${rows.length} results',
          );
        }

        if (rows.isNotEmpty) {
          final contact = ContactLocal.fromMap(rows.first);
          // Use contact name (phone's saved name) - this is what user recognizes
          displayName = contact.preferredDisplayName;
          chatPictureUrl =
              contact.userDetails?.chatPictureUrl ?? backendProfilePic;
          debugPrint(' [Generic] Found contact: $displayName');
        } else if (isUuidName) {
          // Backend sent UUID as name, but no contact found
          displayName = 'ChatAway User';
          debugPrint(
            ' [Generic] No contact for $senderId, using fallback name',
          );
        }
      } catch (e) {
        debugPrint(' [Generic] Contact lookup failed: $e');
        debugPrint('⚠️ [Generic] Contact lookup failed: $e');
        if (isUuidName) displayName = 'ChatAway User';
      }

      debugPrint('🔔 [Generic] From: $displayName ($senderId)');
      debugPrint('🔔 [Generic] Message: $messageText');

      // Show notification with real contact name
      final rawMessageType =
          data['messageType']?.toString() ?? data['message_type']?.toString();
      await _localNotificationService.showChatMessageNotification(
        notificationId: message.messageId ?? DateTime.now().toString(),
        senderName: displayName,
        messageText: messageText,
        conversationId: senderId,
        senderId: senderId,
        senderProfilePic: chatPictureUrl,
        messageType: rawMessageType,
      );

      // Save to database
      await _saveNotificationToDatabase(
        notificationId: message.messageId ?? DateTime.now().toString(),
        type: 'generic',
        data: data,
        title: displayName,
        body: messageText,
      );
    } catch (e) {
      debugPrint('❌ [Generic] Error handling: $e');
    }
  }

  //=================================================================
  // DATABASE OPERATIONS
  //=================================================================

  /// Save notification to database
  Future<void> _saveNotificationToDatabase({
    required String notificationId,
    required String type,
    required Map<String, dynamic> data,
    required String title,
    required String body,
  }) async {
    try {
      final currentUserId = await _tokenStorage.getCurrentUserIdUUID();
      if (currentUserId == null) {
        debugPrint('⚠️ [Database] No user ID, skipping save');
        return;
      }

      final senderId =
          data['sender_id'] as String? ??
          data['senderId'] as String? ??
          'unknown';
      final conversationId =
          data['conversation_id'] as String? ??
          data['conversationId'] as String? ??
          senderId;

      await _notificationRepository.saveChatNotification(
        notificationId: notificationId,
        userId: currentUserId,
        senderId: senderId,
        messageContent: body,
        conversationId: conversationId,
        notificationTitle: title,
        notificationBody: body,
        dataPayload: data,
        firebaseMessageId: notificationId,
      );

      debugPrint('✅ [Database] Notification saved: $notificationId');
    } catch (e) {
      debugPrint('❌ [Database] Failed to save notification: $e');
    }
  }

  //=================================================================
  // NAVIGATION HANDLERS
  //=================================================================

  /// Handle notification tap navigation
  Future<void> _handleNotificationTap(Map<String, dynamic> data) async {
    try {
      final type = data['type'] as String? ?? 'unknown';

      debugPrint('');
      debugPrint('🎯 ═══════════════════════════════════════════════════════');
      debugPrint('🎯 NOTIFICATION TAP NAVIGATION');
      debugPrint('🎯 ═══════════════════════════════════════════════════════');
      debugPrint('🎯 [Navigation] Type: $type');
      debugPrint('🎯 [Navigation] Data: $data');

      switch (type) {
        case 'chat_message':
        case 'message':
        case 'private_message':
          await _handleChatNotificationTap(data);
          break;

        case 'reaction':
        case 'message_reaction':
        case 'message-reaction':
        case 'reaction_updated':
        case 'reaction-updated':
          await _handleChatNotificationTap(data);
          break;

        case 'voice_call':
        case 'call':
          final callId =
              data['call_id'] as String? ?? data['callId'] as String?;
          if (callId != null) {
            debugPrint('📞 [Navigation] Opening call: $callId');
            // TODO: Navigate to call screen when call feature is implemented
          }
          break;

        case 'friend_request':
          final requestId =
              data['request_id'] as String? ?? data['requestId'] as String?;
          if (requestId != null) {
            debugPrint('👥 [Navigation] Opening friend request: $requestId');
            // TODO: Navigate to friend requests screen when feature is implemented
          }
          break;

        default:
          debugPrint('⚠️ [Navigation] Unknown type: $type');
          debugPrint('   Attempting to handle as chat message...');
          await _handleChatNotificationTap(data);
      }
      debugPrint('🎯 ═══════════════════════════════════════════════════════');
      debugPrint('');
    } catch (e) {
      debugPrint('❌ [Navigation] Error handling tap: $e');
    }
  }

  /// Handle chat message notification tap - navigate to specific chat
  Future<void> _handleChatNotificationTap(Map<String, dynamic> data) async {
    try {
      // Extract sender ID from notification data
      final senderId =
          data['sender_id'] as String? ??
          data['senderId'] as String? ??
          data['from_user_id'] as String? ??
          data['fromUserId'] as String? ??
          data['actor_id'] as String? ??
          data['actorId'] as String? ??
          data['user_id'] as String? ??
          data['userId'] as String? ??
          data['conversation_id'] as String? ??
          data['conversationId'] as String?;

      if (senderId == null || senderId.isEmpty) {
        debugPrint('❌ [Navigation] No senderId in notification data');
        return;
      }

      debugPrint('👤 [Navigation] Sender ID: $senderId');

      // Get current user ID from token storage
      final currentUserId = await _tokenStorage.getCurrentUserIdUUID();
      if (currentUserId == null || currentUserId.isEmpty) {
        debugPrint('❌ [Navigation] No current user ID found');
        return;
      }
      debugPrint('👤 [Navigation] Current User ID: $currentUserId');

      // Get contact name from local contacts or notification data
      String contactName = 'ChatAway User';
      try {
        // Try to find contact in local database
        ContactLocal? contact;

        // Method 1: Try by app user ID (UUID)
        final db = await AppDatabaseManager.instance.database;
        final rows = await db.query(
          'contacts',
          where: 'app_user_id = ?',
          whereArgs: [senderId],
          limit: 1,
        );

        if (rows.isNotEmpty) {
          contact = ContactLocal.fromMap(rows.first);
          contactName = contact.preferredDisplayName;
          debugPrint('✅ [Navigation] Found contact by UUID: $contactName');
        } else {
          // Method 2: Try by mobile number if backend sent it
          final senderMobile =
              data['senderMobileNo'] as String? ??
              data['sender_mobile'] as String? ??
              data['mobileNo'] as String? ??
              data['mobile_no'] as String? ??
              data['mobile_no'] as String?;

          if (senderMobile != null) {
            contact = await _contactsRepository.findContactByMobile(
              senderMobile,
            );
            if (contact != null) {
              contactName = contact.preferredDisplayName;
              debugPrint(
                '✅ [Navigation] Found contact by mobile: $contactName',
              );
            }
          }
        }

        // Fallback to notification data if contact not found
        if (contact == null) {
          contactName =
              data['senderFirstName'] as String? ??
              data['senderName'] as String? ??
              data['sender_name'] as String? ??
              'ChatAway User';
          debugPrint('⚠️ [Navigation] Contact not found, using: $contactName');
        }
      } catch (e) {
        debugPrint('❌ [Navigation] Error finding contact: $e');
        contactName =
            data['senderFirstName'] as String? ??
            data['senderName'] as String? ??
            'ChatAway User';
      }

      debugPrint('');
      debugPrint('🚀 [Navigation] Navigating to chat:');
      debugPrint('   📱 Contact: $contactName');
      debugPrint('   👤 Receiver ID: $senderId');
      debugPrint('   👤 Current User ID: $currentUserId');
      debugPrint('');

      // Navigate to enhanced one-to-one chat
      await NavigationService.goToEnhancedOneToOneChat(
        contactName: contactName,
        receiverId: senderId,
        currentUserId: currentUserId,
      );

      debugPrint('✅ [Navigation] Navigation to chat completed');
    } catch (e) {
      debugPrint('❌ [Navigation] Error navigating to chat: $e');
    }
  }

  //=================================================================
  // UTILITY METHODS
  //=================================================================

  /// Get FCM token
  Future<String?> getToken() async {
    try {
      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        debugPrint('🔑 [FCMHandler] Token: ${token.substring(0, 20)}...');
      }
      return token;
    } catch (e) {
      debugPrint('❌ [FCMHandler] Failed to get token: $e');
      return null;
    }
  }

  /// Listen for token refresh
  void onTokenRefresh(Function(String) callback) {
    _firebaseMessaging.onTokenRefresh.listen((String token) {
      debugPrint('🔄 [FCMHandler] Token refreshed');
      callback(token);
    });
  }

  /// Delete FCM token
  Future<void> deleteToken() async {
    try {
      await _firebaseMessaging.deleteToken();
      debugPrint('🗑️ [FCMHandler] Token deleted');
    } catch (e) {
      debugPrint('❌ [FCMHandler] Failed to delete token: $e');
    }
  }

  /// Clear all notifications
  Future<void> clearAllNotifications() async {
    try {
      await _localNotificationService.cancelAllNotifications();
      debugPrint('✅ [FCMHandler] All notifications cleared');
    } catch (e) {
      debugPrint('❌ [FCMHandler] Failed to clear notifications: $e');
    }
  }

  /// Clear notification badge
  Future<void> clearBadge() async {
    try {
      await _localNotificationService.clearAllBadges();
      debugPrint('✅ [FCMHandler] Badge cleared');
    } catch (e) {
      debugPrint('❌ [FCMHandler] Failed to clear badge: $e');
    }
  }
}
