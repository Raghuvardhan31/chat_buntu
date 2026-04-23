import 'dart:async';
import 'dart:convert';

import 'package:chataway_plus/core/services/permissions/permission_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;

import 'package:chataway_plus/core/routes/app_router.dart';
import 'package:chataway_plus/core/routes/route_names.dart';
import 'package:chataway_plus/core/themes/app_theme.dart';
import 'package:chataway_plus/features/theme/theme.dart';
// Token check moved to AppGatePage - no longer needed here
import 'package:chataway_plus/core/app_lifecycle/first_run_cleaner.dart';
import 'package:chataway_plus/core/app_lifecycle/app_state_service.dart';
import 'package:chataway_plus/core/routes/navigation_service.dart';
import 'package:chataway_plus/core/notifications/local/notification_services.dart';
import 'package:chataway_plus/core/constants/api_url/api_urls.dart';
import 'package:chataway_plus/core/storage/token_storage.dart';
import 'package:video_player_media_kit/video_player_media_kit.dart';

import 'core/connectivity/root_scaffold_messager.dart';
import 'core/connectivity/connectivity_snapshot_refresher.dart';

/// Firebase background message handler.
/// Invoked when a push notification arrives and the app is in the background
/// or terminated.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  final coldStartTime = DateTime.now();
  debugPrint('');
  debugPrint('🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥');
  debugPrint('🔥 BACKGROUND HANDLER TRIGGERED!');
  debugPrint('🔥 App was TERMINATED/BACKGROUND and FCM woke it up');
  debugPrint('🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥');
  debugPrint(
    '🔔 [Background] Cold start at: ${coldStartTime.toIso8601String()}',
  );
  debugPrint('📦 [Background] Message ID: ${message.messageId}');
  debugPrint('📦 [Background] Data: ${message.data}');
  debugPrint('📦 [Background] Notification: ${message.notification?.toMap()}');

  // WHATSAPP-STYLE: Initialize Firebase FAST (required for token storage)
  await Firebase.initializeApp();
  debugPrint(
    '⏱️ [Background] Firebase init: ${DateTime.now().difference(coldStartTime).inMilliseconds}ms',
  );

  await _sendDeliveryAckImmediately(message.data);

  // Now handle the full notification flow (can take time)
  debugPrint('🔔 [Background] Calling handleBackgroundMessage...');
  await FirebaseNotificationHandler.instance.handleBackgroundMessage(message);
  debugPrint('✅ [Background] handleBackgroundMessage completed');

  debugPrint(
    '⏱️ [Background] Total cold start: ${DateTime.now().difference(coldStartTime).inMilliseconds}ms',
  );
  debugPrint('🔥🔥🔥 BACKGROUND HANDLER FINISHED 🔥🔥🔥');
  debugPrint('');
}

Future<void> _sendDeliveryAckImmediately(Map<String, dynamic> data) async {
  try {
    final type =
        data['type'] as String? ??
        data['chatType'] as String? ??
        data['notificationType'] as String? ??
        data['messageType'] as String? ??
        data['message_type'] as String? ??
        'unknown';

    if (type != 'chat_message' &&
        type != 'message' &&
        type != 'private_message') {
      return;
    }

    final messageIds = <String>[];

    void addId(dynamic v) {
      final s = v?.toString().trim();
      if (s == null || s.isEmpty) return;
      messageIds.add(s);
    }

    // Prefer explicit arrays first
    final rawMessageIds =
        data['messageIds'] ??
        data['message_ids'] ??
        data['message_ids_json'] ??
        data['messageIdsJson'];

    if (rawMessageIds is List) {
      for (final v in rawMessageIds) {
        addId(v);
      }
    } else if (rawMessageIds is String && rawMessageIds.trim().isNotEmpty) {
      final trimmed = rawMessageIds.trim();
      try {
        if (trimmed.startsWith('[')) {
          final decoded = jsonDecode(trimmed);
          if (decoded is List) {
            for (final v in decoded) {
              addId(v);
            }
          }
        } else if (trimmed.contains(',')) {
          for (final part in trimmed.split(',')) {
            addId(part);
          }
        } else {
          addId(trimmed);
        }
      } catch (_) {
        // Fallback: treat as single ID
        addId(trimmed);
      }
    }

    // Prefer true message UUID keys over chatId (chatId can be conversation id)
    if (messageIds.isEmpty) {
      addId(data['messageUuid']);
      addId(data['message_uuid']);
      addId(data['messageId']);
      addId(data['message_id']);
      addId(data['id']);
      addId(data['chatId']);
    }

    final uniqueIds = <String>{...messageIds}.toList();
    if (uniqueIds.isEmpty) {
      return;
    }

    final token = await TokenSecureStorage.instance.getToken();
    if (token == null || token.isEmpty) {
      return;
    }

    final uri = Uri.parse(ApiUrls.markMessagesAsDelivered);
    await http
        .put(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'messageIds': uniqueIds,
            'receiverDeliveryChannel': 'fcm',
          }),
        )
        .timeout(const Duration(seconds: 10));
  } catch (_) {
    return;
  }
}

/// Application entry point.
/// Responsibilities:
/// - Lock orientation and apply System UI styling
/// - Initialize Firebase
/// - Run first-install cleanup (secure storage + local DB)
/// - Register FCM background handler and initialize notification flow
/// - Resolve initial route (logged-in vs phone entry) and run the app
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Portrait orientation only
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    // Apply global System UI style once at startup (status + nav bar)
    _applySystemUIStyle();

    // Initialize Firebase
    await Firebase.initializeApp();

    // Use media_kit (FFmpeg) as video_player backend for reliable playback
    // Fixes MediaCodecVideoRenderer crashes on older/problematic Android devices
    VideoPlayerMediaKit.ensureInitialized(android: true, iOS: true);

    // CRITICAL: Initialize app lifecycle observer for WebSocket reconnection
    // This must be done early so lifecycle events are captured
    AppStateService.instance.initialize();

    // Clean on first install
    await FirstRunCleaner.run();

    // Register background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // ALWAYS start with AppGatePage (RouteNames.home)
    // AppGatePage will decide the correct route after proper initialization
    // This is how WhatsApp works - always show splash first, then decide
    // Never decide initial route in main() as token retrieval can be flaky
    const initialRoute = RouteNames.home;

    runApp(
      ProviderScope(
        child: SystemUIStyleScope(
          child: ChatAwayPlusApp(initialRoute: initialRoute),
        ),
      ),
    );

    // Initialize custom notification handler (local + push) AFTER first frame
    // to avoid blocking initial rendering.
    Future(() async {
      try {
        await FirebaseNotificationHandler.instance
            .preloadPendingNativeChatQueue();
        await FirebaseNotificationHandler.instance.initialize();
        await PermissionManager.instance.requestEssentialPermissions();
      } catch (e, stack) {
        debugPrint('⚠️ Post-runApp init failed: $e\n$stack');
      }
    });
  } catch (e, stack) {
    debugPrint('❌ Initialization error: $e\n$stack');
    runApp(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: Center(child: Text('Failed to initialize: $e'))),
        ),
      ),
    );
  }
}

/// Get theme-aware System UI overlay style
SystemUiOverlayStyle getSystemUiStyle(bool isDarkMode) {
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: isDarkMode ? Brightness.light : Brightness.dark,
    statusBarBrightness: isDarkMode ? Brightness.dark : Brightness.light,
    systemNavigationBarColor: isDarkMode
        ? const Color(0xFF121212)
        : Colors.white,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: isDarkMode
        ? Brightness.light
        : Brightness.dark,
    systemNavigationBarContrastEnforced: false,
  );
}

/// Global System UI overlay configuration (light mode default for startup)
const SystemUiOverlayStyle kAppSystemUiStyle = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.dark,
  systemNavigationBarColor: Colors.white,
  systemNavigationBarDividerColor: Colors.transparent,
  systemNavigationBarIconBrightness: Brightness.dark,
  systemNavigationBarContrastEnforced: false,
);

/// Applies the app's System UI overlay (status/navigation bar) colors.
/// Safe to call at startup and on lifecycle resume to prevent visual glitches.
void _applySystemUIStyle() {
  try {
    SystemChrome.setSystemUIOverlayStyle(kAppSystemUiStyle);
  } catch (e) {
    debugPrint('⚠️ Failed to apply system UI style: $e');
  }
}

/// Small utility widget that reapplies System UI overlay style when the app
/// resumes from background, preventing padding/overlay regressions on some
/// Android devices.
class SystemUIStyleScope extends StatefulWidget {
  final Widget child;
  const SystemUIStyleScope({super.key, required this.child});

  @override
  State<SystemUIStyleScope> createState() => _SystemUIStyleScopeState();
}

class _SystemUIStyleScopeState extends State<SystemUIStyleScope>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _applySystemUIStyle();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      // Small delay to let resume animation settle, then fix padding
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) {
          _applySystemUIStyle();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Theme-aware: just pass through child, let ChatAwayPlusApp handle system UI
    return widget.child;
  }
}

/// Root MaterialApp wrapper for ChatAway+.
/// Wires:
/// - Global ScaffoldMessenger for toasts/snacks
/// - NavigationService navigator key
/// - AppRouter for route generation
/// - Theme and initial route (with dynamic theme support)
class ChatAwayPlusApp extends ConsumerWidget {
  final String initialRoute;
  const ChatAwayPlusApp({
    super.key,
    this.initialRoute = RouteNames.home, // Always default to AppGatePage
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch theme mode from provider
    final themeMode = ref.watch(flutterThemeModeProvider);
    final isDarkMode = ref.watch(isDarkModeProvider);

    try {
      SystemChrome.setSystemUIOverlayStyle(getSystemUiStyle(isDarkMode));
    } catch (e) {
      debugPrint('⚠️ Failed to apply system UI style: $e');
    }

    return MaterialApp(
      // <-- wire global scaffold messenger key here
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      navigatorKey: NavigationService.navigatorKey,
      // No global connectivity banner; we'll show ephemeral notices only on blocked actions
      // Lock text scaling to 1.0 (WhatsApp approach) - ignores system font size
      builder: (context, child) {
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: getSystemUiStyle(isDarkMode),
          child: MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(1.0)),
            child: ConnectivitySnapshotRefresher(
              child: child ?? const SizedBox(),
            ),
          ),
        );
      },
      title: 'ChatAway+',
      debugShowCheckedModeBanner: false,
      onGenerateRoute: AppRouter.generateRoute,
      initialRoute: initialRoute,
      // Dynamic theme mode from provider
      themeMode: themeMode,
      // Light theme
      theme: AppTheme.lightTheme,
      // Dark theme
      darkTheme: AppTheme.darkTheme,
    );
  }
}
