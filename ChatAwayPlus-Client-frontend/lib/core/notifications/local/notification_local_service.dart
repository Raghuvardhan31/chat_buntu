import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:app_badge_plus/app_badge_plus.dart';

import 'package:chataway_plus/core/database/app_database.dart';
import 'package:chataway_plus/core/storage/token_storage.dart';
import 'package:chataway_plus/core/routes/navigation_service.dart';
import 'package:sqflite/sqflite.dart';
import 'package:chataway_plus/core/notifications/cache/notification_cache_manager.dart';
import 'package:chataway_plus/core/notifications/cache/profile_picture_cache_manager.dart';
import 'package:chataway_plus/features/contacts/data/repositories/contacts_repository.dart';
import 'package:chataway_plus/features/contacts/data/datasources/contacts_database_service.dart';
import 'package:chataway_plus/features/chat/presentation/providers/chat_page_providers/notification_stream_provider.dart';
import 'package:chataway_plus/core/app_lifecycle/app_state_service.dart';
import 'package:chataway_plus/core/notifications/notifications/image_notification.dart';

/// Local Notification Service for displaying notifications when app is in foreground
///
/// 📱 LOCAL NOTIFICATION FEATURES:
/// • Display notifications when app is open (foreground)
/// • Custom notification channels for different types
/// • Sound, vibration, and LED customization
/// • Badge count management
/// • Notification action buttons
/// • WhatsApp-style grouped notifications
///
/// 🔔 NOTIFICATION TYPES:
/// • Chat messages with sender info
/// • Voice calls with accept/decline actions
/// • Friend requests with accept/decline actions
/// • General app notifications
class NotificationLocalService {
  static NotificationLocalService? _instance;
  // UPDATED: Must match backend FCM channelId for killed-app notifications
  static const String _channelId = 'chat_messages';
  static const String _channelName = 'ChatAway+ Messages';
  static const String _channelDescription =
      'Message notifications with badge count';
  // Old channels to delete (cleanup on app update)
  static const List<String> _oldChannelIds = [
    'chataway_plus_notifications',
    'chataway_plus_notifications_v2', // Previous channel before backend sync
    'chataway_plus_group_notifications',
  ];

  // Singleton pattern
  NotificationLocalService._();

  static NotificationLocalService get instance {
    _instance ??= NotificationLocalService._();
    return _instance!;
  }

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  final AppDatabaseManager _databaseManager = AppDatabaseManager.instance;
  final TokenSecureStorage _tokenStorage = TokenSecureStorage();
  final NotificationCacheManager _cacheManager = NotificationCacheManager();
  final ContactsRepository _contactsRepository = ContactsRepository.instance;
  final ProfilePictureCacheManager _profilePicCache =
      ProfilePictureCacheManager.instance;

  static const String _followUpReplyStart = '<<FU_REPLY>>';
  static const String _followUpReplyEnd = '<<FU_REPLY_END>>';
  static const String _expressHubReplyStart = '<<EH_REPLY>>';
  static const String _expressHubReplyEnd = '<<EH_REPLY_END>>';

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

  String _sanitizeMessageText(String raw) {
    final unwrapped = _stripFollowUpReplyWrapper(raw);
    final s = unwrapped.trim();

    // Handle literal "null" string (common issue when backend sends null as string)
    if (s.isEmpty || s.toLowerCase() == 'null') {
      return '';
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(s);
    } catch (_) {
      decoded = null;
    }

    if (decoded == null && s.startsWith('{') && s.contains(r'\"')) {
      try {
        decoded = jsonDecode(s.replaceAll(r'\"', '"'));
      } catch (_) {
        decoded = null;
      }
    }

    if (decoded is String) {
      final inner = decoded.trim();
      if (inner.startsWith('{') && inner.endsWith('}')) {
        try {
          decoded = jsonDecode(inner);
        } catch (_) {}
      }
    }

    if (decoded is Map) {
      final map = Map<String, dynamic>.from(decoded);
      final candidates = <dynamic>[
        map['displayText'],
        map['display_text'],
        map['messageText'],
        map['message_text'],
        map['message'],
        map['text'],
        map['body'],
      ];

      for (final v in candidates) {
        if (v is String) {
          final t = _stripFollowUpReplyWrapper(v).trim();
          if (t.isNotEmpty && t.toLowerCase() != 'null') {
            if (t.startsWith('{') && t.endsWith('}')) {
              final inner = _sanitizeMessageText(t);
              if (inner.trim().isNotEmpty) return inner;
              continue;
            }
            return t;
          }
        }
      }

      // JSON payload present but no usable text found -> allow messageType fallback.
      return '';
    }

    return unwrapped;
  }

  bool _looksLikeLatLngText(String raw) {
    final t = raw.trim();
    final m = RegExp(
      r'^-?\d{1,3}(?:\.\d+)?\s*,\s*-?\d{1,3}(?:\.\d+)?$',
    ).firstMatch(t);
    if (m == null) return false;
    final parts = t.split(',');
    if (parts.length < 2) return false;
    final lat = double.tryParse(parts[0].trim());
    final lng = double.tryParse(parts[1].trim());
    if (lat == null || lng == null) return false;
    if (lat < -90 || lat > 90) return false;
    if (lng < -180 || lng > 180) return false;
    return true;
  }

  // Group key for summary notification
  static const String _groupKey = 'com.chataway.MESSAGES';
  static const String _groupChannelId = 'chataway_plus_group_notifications';
  static const int _summaryNotificationId = 0;

  // Initialization flag for cold start optimization
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  //=================================================================
  // INITIALIZATION AND CONFIGURATION
  //=================================================================

  /// Initialize local notifications
  Future<void> initialize() async {
    try {
      // Android initialization settings
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS initialization settings
      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
          );

      // Combined initialization settings
      const InitializationSettings initializationSettings =
          InitializationSettings(
            android: initializationSettingsAndroid,
            iOS: initializationSettingsIOS,
          );

      // Initialize the plugin
      await _flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Create notification channel for Android
      await _createNotificationChannel();

      // Cleanup old profile picture cache entries (run in background)
      _cleanupProfilePictureCache();

      _isInitialized = true;
    } catch (e) {
      debugPrint('❌ [LocalNotificationService] Initialization failed: $e');
    }
  }

  /// Cleanup old profile picture cache entries
  /// Runs in background without blocking initialization
  Future<void> _cleanupProfilePictureCache() async {
    try {
      // Run cleanup in background
      Future.delayed(const Duration(seconds: 5), () async {
        await _profilePicCache.cleanupOldCache(daysOld: 30);
      });
    } catch (e) {
      debugPrint('⚠️ [ProfileCache] Cleanup failed: $e');
    }
  }

  /// Create Android notification channel
  Future<void> _createNotificationChannel() async {
    try {
      final androidPlugin = _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      try {
        await androidPlugin?.deleteNotificationChannel(_channelId);
      } catch (e) {
        // Ignore if channel doesn't exist
      }

      // Delete old channels that had "Dot" badge locked
      for (final oldChannelId in _oldChannelIds) {
        try {
          await androidPlugin?.deleteNotificationChannel(oldChannelId);
        } catch (e) {
          // Ignore if channel doesn't exist
        }
      }

      if (!_oldChannelIds.contains(_groupChannelId)) {
        try {
          await androidPlugin?.deleteNotificationChannel(_groupChannelId);
        } catch (_) {
          // Ignore if channel doesn't exist
        }
      }

      // Create new channel with proper badge settings
      final AndroidNotificationChannel channel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('notification_sound1'),
        enableVibration: true,
        enableLights: true,
        ledColor: const Color(0xFF0EA5E9), // App primary color
        showBadge: true,
      );

      await androidPlugin?.createNotificationChannel(channel);
    } catch (e) {
      debugPrint('❌ [LocalNotificationService] Channel creation failed: $e');
    }
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse notificationResponse) {
    try {
      final payload = notificationResponse.payload;
      if (payload != null) {
        final data = jsonDecode(payload) as Map<String, dynamic>;
        final type = data['type'] as String?;

        switch (type) {
          case 'chat_message':
            _handleChatNotificationTap(data);
            break;
          case 'chat_picture_like':
            break;
          case 'status_like':
            break;
          case 'voice_call':
            _handleVoiceCallNotificationTap(data);
            break;
          case 'friend_request':
            _handleFriendRequestNotificationTap(data);
            break;
          default:
            debugPrint('Unknown notification type: $type');
        }
      }
    } catch (e) {
      debugPrint(
        '❌ [LocalNotificationService] Error handling notification tap: $e',
      );
    }
  }

  //=================================================================
  // BADGE MANAGEMENT METHODS
  //=================================================================

  /// Clear notifications and cache when opening a chat
  /// Call this when user opens an individual chat screen
  ///
  /// Usage:
  /// ```dart
  /// await NotificationLocalService.clearChatNotifications(senderId);
  /// ```
  static Future<void> clearChatNotifications(String senderId) async {
    try {
      final service = NotificationLocalService.instance;
      await service.clearNotificationsForSender(senderId);
      debugPrint('✅ [Clear] Notifications cleared for chat: $senderId');
    } catch (e) {
      debugPrint('❌ [Clear] Failed to clear notifications: $e');
    }
  }

  /// Clear notification badge for specific conversation
  Future<void> clearBadgeForConversation(String conversationId) async {
    try {
      // Get current user ID for badge counting
      final currentUserId = await _getCurrentUserId();
      if (currentUserId != null) {
        await _updateBadgeCount(currentUserId);
      }

      // Clear notifications for this sender
      await clearNotificationsForSender(conversationId);
    } catch (e) {
      debugPrint('❌ [LocalNotificationService] Failed to clear badge: $e');
    }
  }

  /// Clear all app badges
  Future<void> clearAllBadges() async {
    try {
      await AppBadgePlus.updateBadge(0);
    } catch (e) {
      debugPrint('❌ [LocalNotificationService] Failed to clear all badges: $e');
    }
  }

  /// Update badge count based on total unread messages
  Future<void> _updateBadgeCount(String userId) async {
    try {
      // Count unread messages from database
      final db = await _databaseManager.database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM messages WHERE receiver_id = ? AND is_read = 0',
        [userId],
      );

      final totalUnreadCount = result.first['count'] as int? ?? 0;

      // Update app icon badge
      await AppBadgePlus.updateBadge(totalUnreadCount);
    } catch (e) {
      debugPrint('❌ [Badge] Failed to update badge: $e');
    }
  }

  /// Get current user ID from secure storage
  Future<String?> _getCurrentUserId() async {
    try {
      return await _tokenStorage.getCurrentUserIdUUID();
    } catch (e) {
      debugPrint('❌ [LocalNotificationService] Failed to get user ID: $e');
      return null;
    }
  }

  //=================================================================
  // PROFILE PICTURE HELPERS
  //=================================================================

  /// Load profile picture for notification with CACHE-FIRST approach ⚡
  ///
  /// OPTIMIZED FLOW:
  /// 1. Check SQLite cache first
  /// 2. If cached → Return instantly (20-50x faster) ⚡
  /// 3. If not cached → Download, process, save to cache
  ///
  /// This replaces the old slow method that downloaded and processed
  /// the image every single time.
  Future<ByteArrayAndroidBitmap?> _loadProfilePictureForNotification(
    String userId,
    String? profilePicPath,
  ) async {
    if (profilePicPath == null || profilePicPath.isEmpty) {
      debugPrint('🖼️ [ProfilePic] No profile picture path provided');
      return null;
    }

    try {
      debugPrint('🖼️ [ProfilePic] Loading profile picture: $profilePicPath');

      // 🚀 USE CACHE-FIRST APPROACH (Fast!)
      final circularBitmap = await _profilePicCache.getCircularProfilePicture(
        userId: userId,
        chatPictureUrl: profilePicPath,
      );

      if (circularBitmap != null) {
        debugPrint('✅ [ProfilePic] Profile picture loaded successfully');
      } else {
        debugPrint('⚠️ [ProfilePic] Could not load profile picture');
      }

      return circularBitmap;
    } catch (e, stackTrace) {
      debugPrint('❌ [ProfilePic] Error loading profile picture: $e');
      debugPrint('❌ [ProfilePic] Stack trace: $stackTrace');
      return null;
    }
  }

  //=================================================================
  // NOTIFICATION DISPLAY METHODS
  //=================================================================

  Future<void> showChatPictureLikeNotification({
    required String notificationId,
    required String fromUserId,
    required String fromUserName,
    required String messageText,
    String? targetChatPictureId,
    String? fromUserProfilePic,
  }) async {
    try {
      if (!_isInitialized) await initialize();

      String displayName = fromUserName;
      String? profilePicPath = fromUserProfilePic;
      try {
        final contact = await ContactsDatabaseService.instance
            .getContactByUserId(fromUserId);
        if (contact != null) {
          displayName = contact.preferredDisplayName;
          profilePicPath ??= contact.userDetails?.chatPictureUrl;
        }
      } catch (_) {}

      final title = displayName;
      final body = 'New like on your chat picture! ❤️';

      final payload = jsonEncode({
        'type': 'chat_picture_like',
        'notification_id': notificationId,
        'from_user_id': fromUserId,
        'from_user_name': fromUserName,
        'message_text': messageText,
        'target_chat_picture_id': targetChatPictureId,
      });

      ByteArrayAndroidBitmap? circularProfilePic;
      if (profilePicPath != null && profilePicPath.trim().isNotEmpty) {
        circularProfilePic = await _loadProfilePictureForNotification(
          fromUserId,
          profilePicPath,
        );
      }

      ByteArrayAndroidIcon? profileIcon;
      if (circularProfilePic != null) {
        profileIcon = ByteArrayAndroidIcon(circularProfilePic.data);
      }
      final sender = Person(name: title, icon: profileIcon as dynamic);

      final StyleInformation styleInformation = MessagingStyleInformation(
        sender,
        groupConversation: false,
        messages: [Message(body, DateTime.now(), sender)],
      );

      final AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            largeIcon: null,
            styleInformation: styleInformation,
            category: AndroidNotificationCategory.message,
            enableVibration: true,
          );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _flutterLocalNotificationsPlugin.show(
        notificationId.hashCode,
        title,
        body,
        details,
        payload: payload,
      );
    } catch (e) {
      debugPrint('❌ [ChatPictureLikeNotif] Failed: $e');
    }
  }

  Future<void> showStatusLikeNotification({
    required String notificationId,
    required String fromUserId,
    required String fromUserName,
    String? statusId,
    String? statusText,
    String? fromUserProfilePic,
  }) async {
    try {
      if (!_isInitialized) await initialize();

      String displayName = fromUserName;
      String? profilePicPath = fromUserProfilePic;
      try {
        final contact = await ContactsDatabaseService.instance
            .getContactByUserId(fromUserId);
        if (contact != null) {
          displayName = contact.preferredDisplayName;
          profilePicPath ??= contact.userDetails?.chatPictureUrl;
        }
      } catch (_) {}

      final title = displayName;
      final snippet = statusText?.trim();
      final body = snippet != null && snippet.isNotEmpty
          ? snippet
          : 'New like on your SYVT text! ❤️';

      final payload = jsonEncode({
        'type': 'status_like',
        'notification_id': notificationId,
        'from_user_id': fromUserId,
        'from_user_name': fromUserName,
        'status_id': statusId,
        'status_text': statusText,
      });

      ByteArrayAndroidBitmap? circularProfilePic;
      if (profilePicPath != null && profilePicPath.trim().isNotEmpty) {
        circularProfilePic = await _loadProfilePictureForNotification(
          fromUserId,
          profilePicPath,
        );
      }

      ByteArrayAndroidIcon? profileIcon;
      if (circularProfilePic != null) {
        profileIcon = ByteArrayAndroidIcon(circularProfilePic.data);
      }
      final sender = Person(name: title, icon: profileIcon as dynamic);

      final StyleInformation styleInformation = MessagingStyleInformation(
        sender,
        groupConversation: false,
        messages: [Message(body, DateTime.now(), sender)],
      );

      final AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            largeIcon: null,
            styleInformation: styleInformation,
            category: AndroidNotificationCategory.message,
            enableVibration: true,
          );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _flutterLocalNotificationsPlugin.show(
        notificationId.hashCode,
        title,
        body,
        details,
        payload: payload,
      );
    } catch (e) {
      debugPrint('❌ [StatusLikeNotif] Failed: $e');
    }
  }

  /// Show chat message notification with WhatsApp-style grouping
  /// OPTIMIZED: Shows notification FAST first, then does background work
  Future<void> showChatMessageNotification({
    required String notificationId,
    required String senderName,
    required String messageText,
    required String conversationId,
    required String senderId,
    String? senderProfilePic,
    String? messageType,
  }) async {
    final notifStartTime = DateTime.now();
    var sanitizedMessageText = _sanitizeMessageText(messageText);

    final normalizedType = messageType?.toLowerCase().trim();
    if (normalizedType == 'location' ||
        _looksLikeLatLngText(sanitizedMessageText) ||
        _looksLikeLatLngText(messageText)) {
      sanitizedMessageText = 'Location';
    }

    // Fallback for empty/null messages based on media type (like backend does)
    if (sanitizedMessageText.trim().isEmpty) {
      sanitizedMessageText = ImageNotificationHandler.normalizeMessageText(
        messageText: sanitizedMessageText,
        messageType: messageType,
        withEmoji: true,
      );
      debugPrint(
        '📷 [Notif] Empty message, using fallback: $sanitizedMessageText (type: $messageType)',
      );
    }

    try {
      debugPrint('');
      debugPrint('🔔🔔🔔🔔🔔🔔🔔🔔🔔🔔🔔🔔🔔🔔🔔🔔🔔🔔🔔🔔🔔🔔🔔');
      debugPrint('🔔 showChatMessageNotification CALLED!');
      debugPrint('🔔 Sender: $senderName ($senderId)');
      debugPrint('🔔 Message: $messageText');
      debugPrint('🔔 NotificationId: $notificationId');
      debugPrint('🔔 Initialized: $_isInitialized');
      debugPrint('🔔🔔🔔🔔🔔🔔🔔🔔🔔🔔🔔🔔🔔🔔🔔🔔🔔🔔🔔🔔🔔🔔🔔');
      debugPrint('⏱️ [Notif TIMING] showChatMessageNotification START');
      debugPrint('📝 [Notif] senderName=$senderName, senderId=$senderId');

      // CRITICAL: Ensure notification plugin is initialized (especially for background isolate)
      // When app is terminated and FCM wakes it, this runs in a fresh isolate
      if (!_isInitialized) {
        debugPrint('⚠️ [Notif] Plugin not initialized, initializing now...');
        await initialize();
        debugPrint(
          '✅ [Notif] Plugin initialized in showChatMessageNotification',
        );
      }

      // ROCK-SOLID SUPPRESSION: If the app is in foreground and the user is
      // already viewing this one-to-one chat, never show a notification.
      final shouldShowByAppState = AppStateService.instance
          .shouldShowNotification(senderId);
      debugPrint('🔍 [Notif] AppStateService check: $shouldShowByAppState');
      debugPrint(
        '🔍 [Notif] AppState debug: ${AppStateService.instance.debugState}',
      );

      if (!shouldShowByAppState) {
        debugPrint(
          '🔕 [Notif] Suppressed at NotificationLocalService '
          '(senderId=$senderId, state=${AppStateService.instance.debugState})',
        );
        return;
      }

      // Final safety check - if senderName looks like UUID, use fallback
      String displayName = senderName;
      if (senderName.contains('-') && senderName.length > 30) {
        displayName = 'ChatAway User';
        debugPrint('⚠️ [Notif] Detected UUID as name, using fallback');
      }

      // 🔔 BROADCAST: Notify UI about new notification (fast - no await)
      NotificationStreamController().notifyNewNotification(
        senderId: senderId,
        message: sanitizedMessageText,
      );

      final payload = jsonEncode({
        'type': 'chat_message',
        'conversation_id': conversationId,
        'sender_id': senderId,
        'sender_name': displayName,
        'notification_id': notificationId,
      });

      // Load profile picture for notification (cache-first, will download on miss)
      ByteArrayAndroidBitmap? circularProfilePic;

      if (senderProfilePic != null && senderProfilePic.isNotEmpty) {
        try {
          circularProfilePic = await _loadProfilePictureForNotification(
            senderId,
            senderProfilePic,
          );

          if (circularProfilePic != null) {
            debugPrint(
              '✅ [ProfilePic] Loaded for notification (cache/download)',
            );
          }
        } catch (e) {
          debugPrint('⚠️ [ProfilePic] Failed to load for notification: $e');
        }
      }

      // -----------------------------------------------------------------
      // WHATSAPP-STYLE: Use MessagingStyleInformation for profile pic on LEFT
      // This creates the authentic WhatsApp notification layout
      // -----------------------------------------------------------------
      // Load unread messages for this sender from local DB so that the
      // expanded notification only shows messages that are still UNREAD.
      List<Map<String, dynamic>> unreadMessages = [];
      try {
        final currentUserId = await _getCurrentUserId();
        if (currentUserId != null) {
          final db = await _databaseManager.database;
          unreadMessages = await db.query(
            'messages',
            columns: ['message', 'created_at'],
            where: 'receiver_id = ? AND sender_id = ? AND is_read = 0',
            whereArgs: [currentUserId, senderId],
            orderBy: 'created_at ASC',
            limit: 10,
          );
        }
      } catch (e) {
        debugPrint('⚠️ [Notif] Failed to load unread messages for style: $e');
      }

      // Build style information - try MessagingStyle first, fallback to BigText
      StyleInformation styleInformation;

      try {
        // Build Message objects for MessagingStyle (WhatsApp-style)
        final List<Message> messages = [];

        // Create Person with profile pic for WhatsApp-style notification
        // Convert cached circular bitmap (ByteArrayAndroidBitmap) into an icon
        ByteArrayAndroidIcon? profileIcon;
        if (circularProfilePic != null) {
          profileIcon = ByteArrayAndroidIcon(circularProfilePic.data);
        }

        final sender = Person(
          name: displayName,
          // Use ByteArrayAndroidIcon so Android shows actual avatar instead of initial letter
          icon: profileIcon as dynamic,
        );

        // Add unread messages from DB first (if any)
        for (final row in unreadMessages) {
          final text = _sanitizeMessageText(
            (row['message'] as String?)?.trim() ?? '',
          ).trim();
          if (text.isNotEmpty) {
            DateTime timestamp;
            final createdAtRaw = row['created_at'];
            if (createdAtRaw is int) {
              timestamp = DateTime.fromMillisecondsSinceEpoch(createdAtRaw);
            } else {
              timestamp = DateTime.now();
            }
            messages.add(Message(text, timestamp, sender));
          }
        }

        // Ensure the latest message is included (in case DB query lagged)
        final trimmedLatest = sanitizedMessageText.trim();
        final hasLatest = messages.any((m) => m.text == trimmedLatest);
        if (!hasLatest) {
          messages.add(Message(trimmedLatest, DateTime.now(), sender));
        }

        // Create MessagingStyleInformation (WhatsApp-style with profile pic on LEFT)
        styleInformation = MessagingStyleInformation(
          sender,
          messages: messages,
          conversationTitle: null,
          groupConversation: false,
        );
        // Using MessagingStyle (WhatsApp-style)
      } catch (e) {
        // Fallback to BigTextStyleInformation if MessagingStyle fails
        debugPrint('⚠️ [Notif] MessagingStyle failed, using BigText: $e');
        styleInformation = BigTextStyleInformation(
          sanitizedMessageText,
          contentTitle: displayName,
        );
      }

      // Get quick badge count for notification (runs fast from cache)
      int badgeCount = 1;
      try {
        final currentUserId = await _getCurrentUserId();
        if (currentUserId != null) {
          final db = await _databaseManager.database;
          final result = await db.rawQuery(
            'SELECT COUNT(*) as count FROM messages WHERE receiver_id = ? AND is_read = 0',
            [currentUserId],
          );
          badgeCount =
              (result.first['count'] as int? ?? 0) +
              1; // +1 for this new message
        }
      } catch (e) {
        debugPrint('⚠️ [Badge] Quick count failed, using 1: $e');
      }

      // Create notification with MessagingStyle (profile pic via Person icon on LEFT)
      AndroidNotificationDetails
      androidPlatformChannelSpecifics = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        styleInformation: styleInformation,
        icon: '@mipmap/ic_launcher',
        // NOTE: Do NOT set largeIcon here; that forces avatar to the RIGHT side.
        // We rely on MessagingStyleInformation + Person(icon: ...) for LEFT-side avatar.
        category: AndroidNotificationCategory.message,
        groupKey: _groupKey,
        setAsGroupSummary: false,
        autoCancel: true,
        enableVibration: true,
        sound: const RawResourceAndroidNotificationSound('notification_sound1'),
        playSound: true,
        number: badgeCount, // Shows count on app icon badge
      );

      final DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            sound: 'notification_sound1.mp3',
            badgeNumber: badgeCount, // Dynamic badge count
          );

      NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      // Use sender ID as notification ID (updates existing notification)
      final senderNotificationId = senderId.hashCode;

      try {
        await _flutterLocalNotificationsPlugin.show(
          senderNotificationId,
          displayName,
          sanitizedMessageText,
          platformChannelSpecifics,
          payload: payload,
        );
        // Notification shown successfully
      } catch (showError, stackTrace) {
        debugPrint(
          '❌ [Notif] _flutterLocalNotificationsPlugin.show() FAILED: $showError',
        );
        debugPrint('❌ [Notif] Stack trace: $stackTrace');

        // FALLBACK: Try showing a simple notification without MessagingStyle
        debugPrint('🔄 [Notif] Attempting fallback simple notification...');
        try {
          final simpleAndroidDetails = AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            autoCancel: true,
          );

          final simpleDetails = NotificationDetails(
            android: simpleAndroidDetails,
          );

          await _flutterLocalNotificationsPlugin.show(
            senderNotificationId,
            displayName,
            sanitizedMessageText,
            simpleDetails,
            payload: payload,
          );
          debugPrint('✅ [Notif] Fallback simple notification shown');
        } catch (fallbackError) {
          debugPrint(
            '❌ [Notif] Fallback notification also failed: $fallbackError',
          );
        }
      }

      // CRITICAL: Explicitly update app badge for OEM devices (Realme/Oppo/Xiaomi)
      // Some devices don't respect notification's `number` property
      try {
        await AppBadgePlus.updateBadge(badgeCount);
        debugPrint('🔢 Badge updated to $badgeCount');
      } catch (badgeError) {
        debugPrint(
          '⚠️ Badge update failed (some launchers don\'t support): $badgeError',
        );
      }

      // Post group summary notification (REQUIRED for Android badge count)
      await _showSummaryNotification(badgeCount);

      final elapsed = DateTime.now().difference(notifStartTime).inMilliseconds;
      debugPrint('⏱️ [Notif TIMING] Notification SHOWN in ${elapsed}ms');

      // BACKGROUND WORK: Don't block notification display
      // Cache message, update badge, save to DB in background
      _doBackgroundNotificationWork(
        notificationId: notificationId,
        senderId: senderId,
        messageText: sanitizedMessageText,
        displayName: displayName,
        conversationId: conversationId,
      );
    } catch (e) {
      debugPrint('❌ [Notification] Failed to show notification: $e');
    }
  }

  /// Post/update the group summary notification (Android badge count fix)
  ///
  /// On Android, when using grouped notifications (groupKey), a SUMMARY
  /// notification with setAsGroupSummary: true MUST exist for the launcher
  /// to show the correct badge count on the app icon.
  /// Without this, most launchers (Samsung, Pixel, Xiaomi, etc.) show no badge.
  Future<void> _showSummaryNotification(int badgeCount) async {
    try {
      final androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.min,
        priority: Priority.min,
        groupKey: _groupKey,
        setAsGroupSummary: true,
        autoCancel: true,
        number: badgeCount,
        icon: '@mipmap/ic_launcher',
        // Silent — the individual notification already played sound
        playSound: false,
        enableVibration: false,
        onlyAlertOnce: true,
      );

      final details = NotificationDetails(android: androidDetails);

      await _flutterLocalNotificationsPlugin.show(
        _summaryNotificationId,
        'ChatAway+',
        '$badgeCount new messages',
        details,
      );
    } catch (e) {
      debugPrint('⚠️ [Badge] Summary notification failed: $e');
    }
  }

  /// Background work after notification is shown (non-blocking)
  void _doBackgroundNotificationWork({
    required String notificationId,
    required String senderId,
    required String messageText,
    required String displayName,
    required String conversationId,
  }) {
    // Run all background work asynchronously without blocking
    Future(() async {
      try {
        // Cache the message for grouped notifications
        await _cacheManager.addMessageToCache(
          senderId: senderId,
          messageText: messageText,
          senderName: displayName,
        );

        // Save to database
        final currentUserId = await _getCurrentUserId();
        if (currentUserId != null) {
          try {
            final db = await _databaseManager.database;
            await db.insert('chat_notifications', {
              'notification_id': notificationId,
              'user_id': currentUserId,
              'sender_id': senderId,
              'message_content': messageText,
              'conversation_id': conversationId,
              'notification_title': displayName,
              'notification_body': messageText,
              'is_read': 0,
              'is_displayed': 1,
              'created_at': DateTime.now().millisecondsSinceEpoch,
            }, conflictAlgorithm: ConflictAlgorithm.replace);
          } catch (e) {
            debugPrint('⚠️ [Background] DB save failed: $e');
          }

          // Update badge count
          await _updateBadgeCount(currentUserId);
        }
      } catch (e) {
        debugPrint('⚠️ [Background] Background work failed: $e');
      }
    });
  }

  /// Clear notifications for a specific sender
  Future<void> clearNotificationsForSender(String senderId) async {
    try {
      // Cancel the notification for this sender
      final senderNotificationId = senderId.hashCode;
      await _flutterLocalNotificationsPlugin.cancel(senderNotificationId);

      // Clear the cache for this sender
      await _cacheManager.clearCacheForSender(senderId);

      // 🔔 BROADCAST: Notify UI that notifications were cleared
      NotificationStreamController().notifyNotificationsCleared(senderId);

      final currentUserId = await _getCurrentUserId();

      // Update summary notification
      final allSenderIds = await _cacheManager.getAllCachedSenderIds();

      if (allSenderIds.isEmpty) {
        // No more cached messages, remove summary notification
        await _flutterLocalNotificationsPlugin.cancel(_summaryNotificationId);
      } else if (currentUserId != null) {
        // Still have cached messages, update summary with remaining count
        final db = await _databaseManager.database;
        final result = await db.rawQuery(
          'SELECT COUNT(*) as count FROM messages WHERE receiver_id = ? AND is_read = 0',
          [currentUserId],
        );
        final remaining = result.first['count'] as int? ?? 0;
        if (remaining > 0) {
          await _showSummaryNotification(remaining);
        } else {
          await _flutterLocalNotificationsPlugin.cancel(_summaryNotificationId);
        }
      }

      // Update badge count
      if (currentUserId != null) {
        await _updateBadgeCount(currentUserId);
      }
    } catch (e) {
      debugPrint('❌ [Notification] Failed to clear for sender: $e');
    }
  }

  /// Show voice call notification
  Future<void> showVoiceCallNotification({
    required String callId,
    required String callerName,
    required String callerId,
    String? callerProfilePic,
  }) async {
    try {
      debugPrint('📞 [VoiceCall] Showing call notification from: $callerName');

      final payload = jsonEncode({
        'type': 'voice_call',
        'call_id': callId,
        'caller_id': callerId,
        'caller_name': callerName,
      });

      final AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            'voice_calls',
            'Voice Calls',
            channelDescription: 'Incoming voice call notifications',
            importance: Importance.max,
            priority: Priority.max,
            fullScreenIntent: true,
            category: AndroidNotificationCategory.call,
            icon: '@mipmap/ic_launcher',
            playSound: true,
            enableVibration: true,
            actions: [
              const AndroidNotificationAction(
                'accept_call',
                'Accept',
                showsUserInterface: true,
              ),
              const AndroidNotificationAction(
                'decline_call',
                'Decline',
                cancelNotification: true,
              ),
            ],
          );

      const DarwinNotificationDetails iOSDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        categoryIdentifier: 'call',
      );

      NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iOSDetails,
      );

      await _flutterLocalNotificationsPlugin.show(
        callId.hashCode,
        'Incoming Call',
        callerName,
        details,
        payload: payload,
      );

      debugPrint('✅ [VoiceCall] Call notification shown');
    } catch (e) {
      debugPrint('❌ [VoiceCall] Failed to show call notification: $e');
    }
  }

  /// Show friend request notification
  Future<void> showFriendRequestNotification({
    required String requestId,
    required String senderName,
    required String senderId,
    String? senderProfilePic,
  }) async {
    try {
      debugPrint('👥 [FriendRequest] Showing notification from: $senderName');

      final payload = jsonEncode({
        'type': 'friend_request',
        'request_id': requestId,
        'sender_id': senderId,
        'sender_name': senderName,
      });

      final AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            'friend_requests',
            'Friend Requests',
            channelDescription: 'Friend request notifications',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            actions: [
              const AndroidNotificationAction(
                'accept_friend',
                'Accept',
                showsUserInterface: true,
              ),
              const AndroidNotificationAction(
                'decline_friend',
                'Decline',
                cancelNotification: true,
              ),
            ],
          );

      const DarwinNotificationDetails iOSDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iOSDetails,
      );

      await _flutterLocalNotificationsPlugin.show(
        requestId.hashCode,
        'Friend Request',
        '$senderName wants to connect',
        details,
        payload: payload,
      );

      debugPrint('✅ [FriendRequest] Notification shown');
    } catch (e) {
      debugPrint('❌ [FriendRequest] Failed to show notification: $e');
    }
  }

  //=================================================================
  // NOTIFICATION TAP HANDLERS
  //=================================================================

  void _handleChatNotificationTap(Map<String, dynamic> data) async {
    final conversationId = data['conversation_id'] as String?;
    final senderId = data['sender_id'] as String?;

    if (conversationId == null || senderId == null) {
      debugPrint('❌ [Navigation] Missing required data for chat navigation');
      return;
    }

    try {
      debugPrint('💬 [Navigation] Opening chat: $conversationId');
      debugPrint('💬 [Navigation] Sender ID: $senderId');

      // Get current user ID
      final currentUserId = await _getCurrentUserId();
      if (currentUserId == null) {
        debugPrint('❌ [Navigation] Current user ID not found');
        return;
      }

      // Get sender's name from contacts (same logic as notification display)
      String displayName = data['sender_name'] as String? ?? 'Unknown';

      try {
        final contact = await _contactsRepository.findContactById(senderId);
        if (contact != null) {
          displayName = contact.preferredDisplayName;
          debugPrint('✅ [Navigation] Found contact: $displayName');
        } else {
          debugPrint('⚠️ [Navigation] Contact not found, using fallback name');
        }
      } catch (e) {
        debugPrint('⚠️ [Navigation] Could not find contact: $e');
      }

      debugPrint('💬 [Navigation] Navigating to chat with: $displayName');

      // Navigate to individual chat page
      await NavigationService.goToIndividualChat(
        contactName: displayName,
        receiverId: senderId,
        currentUserId: currentUserId,
      );

      debugPrint('✅ [Navigation] Successfully navigated to chat');
    } catch (e) {
      debugPrint('❌ [Navigation] Failed to navigate to chat: $e');
    }
  }

  void _handleVoiceCallNotificationTap(Map<String, dynamic> data) {
    final callId = data['call_id'] as String?;

    if (callId != null) {
      debugPrint('📞 [Navigation] Opening call: $callId');
      // TODO: Navigate to call screen
    }
  }

  void _handleFriendRequestNotificationTap(Map<String, dynamic> data) {
    final requestId = data['request_id'] as String?;

    if (requestId != null) {
      debugPrint('👥 [Navigation] Opening friend request: $requestId');
      // TODO: Navigate to friend requests screen
    }
  }

  //=================================================================
  // UTILITY METHODS
  //=================================================================

  /// Cancel specific notification
  Future<void> cancelNotification(int notificationId) async {
    try {
      await _flutterLocalNotificationsPlugin.cancel(notificationId);
      debugPrint('✅ [Notification] Cancelled: $notificationId');
    } catch (e) {
      debugPrint('❌ [Notification] Failed to cancel: $e');
    }
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    try {
      await _flutterLocalNotificationsPlugin.cancelAll();
      await _cacheManager.clearAllCache();
      debugPrint('✅ [Notification] Cancelled all notifications');
    } catch (e) {
      debugPrint('❌ [Notification] Failed to cancel all: $e');
    }
  }

  /// Cancel native Kotlin FCM notifications (IDs 1000+)
  /// Called when Flutter shows its own notification with proper contact name
  /// to replace the native notification that shows app register name
  Future<void> cancelNativeNotifications() async {
    try {
      final androidPlugin = _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidPlugin == null) return;

      // Get all active notifications
      final activeNotifications = await androidPlugin.getActiveNotifications();

      // Cancel notifications with IDs >= 1000 (native Kotlin range)
      int cancelledCount = 0;
      for (final notification in activeNotifications) {
        final id = notification.id;
        if (id != null && id >= 1000) {
          await _flutterLocalNotificationsPlugin.cancel(id);
          cancelledCount++;
        }
      }

      if (cancelledCount > 0) {
        debugPrint(
          '🗑️ [Notification] Cancelled $cancelledCount native notifications',
        );
      }
    } catch (e) {
      debugPrint('⚠️ [Notification] Failed to cancel native notifications: $e');
    }
  }

  /// Get pending notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    try {
      return await _flutterLocalNotificationsPlugin
          .pendingNotificationRequests();
    } catch (e) {
      debugPrint('❌ [Notification] Failed to get pending: $e');
      return [];
    }
  }

  /// Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    try {
      final result = await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.areNotificationsEnabled();
      return result ?? true;
    } catch (e) {
      debugPrint('❌ [Notification] Failed to check enabled: $e');
      return true;
    }
  }
}
