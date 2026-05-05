import 'package:chataway_plus/core/themes/app_text_styles.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:chataway_plus/core/routes/route_names.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/core/constants/assets/image_assets.dart';
import 'package:chataway_plus/core/storage/token_storage.dart';
import 'package:chataway_plus/core/database/app_database.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:chataway_plus/features/chat/data/services/chat_engine/index.dart';
import 'package:chataway_plus/core/media/media_cache_manager.dart';
import 'package:chataway_plus/features/chat/data/cache/chat_list_cache.dart';
import 'package:chataway_plus/features/chat/presentation/providers/chat_list_providers/chat_list_stream.dart';
import 'package:chataway_plus/core/connectivity/connectivity_service.dart';
// WHATSAPP-STYLE: Use cached connectivity state for instant access
import 'package:chataway_plus/features/draggable_emoji/data/datasources/draggable_emoji_local_datasource.dart';
import 'package:chataway_plus/core/notifications/firebase/firebase_notification_handler.dart';
import 'package:chataway_plus/core/app_upgrade/app_upgrade_manager.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:chataway_plus/features/contacts/data/repositories/contacts_repository.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chataway_plus/features/group_chat/presentation/providers/group_providers.dart';

const bool _enableAppGateVerboseLogs = false; // Disable verbose logs by default

const String _statusPlaceholder = 'Write custom or tap to choose preset';

bool _isMeaningfulStatus(String? status) {
  final v = status?.trim() ?? '';
  if (v.isEmpty) return false;
  if (v == _statusPlaceholder) return false;
  return true;
}

void _appGateDecisionLog(String message) {
  if (!kDebugMode) return;
  debugPrint(message);
}

void _appGateLog(String message) {
  if (!kDebugMode || !_enableAppGateVerboseLogs) return;
  debugPrint(message);
}

/// App entry gate that determines the initial route based on authentication
/// and profile completion status.
///
/// Flow:
/// 1. Prewarms database in background
/// 2. Checks token existence and validity
/// 3. Validates user profile completeness
/// 4. Initializes global chat services (non-blocking)
/// 5. Routes to appropriate screen (phone entry, profile, or chat list)
///
/// Includes timeout protection to prevent indefinite loading.
class AppGatePage extends ConsumerStatefulWidget {
  const AppGatePage({super.key});

  @override
  ConsumerState<AppGatePage> createState() => _AppGatePageState();
}

class _AppGatePageState extends ConsumerState<AppGatePage> {
  Timer? _maxWaitTimer;
  bool _navigated = false;
  String? _pendingRoute;
  bool _hasToken = false;
  String _userEmoji = '😊';
  bool _showEmojiInAppIcon = false;

  @override
  void initState() {
    super.initState();
    _appGateLog('🚺 [AppGate] initState: prewarm + route decision');

    // WHATSAPP-STYLE: Initialize connectivity cache for instant access across app
    ConnectivityCache.instance.initialize();

    _loadUserEmoji();
    _loadEmojiDisplayPreference();
    _maxWaitTimer = Timer(const Duration(seconds: 5), _onTimeout);

    // CRITICAL: Ensure DB is ready BEFORE route decision to prevent race condition
    // On fast devices, route decision was running before DB was initialized
    _initializeAndRoute();
  }

  /// WHATSAPP-STYLE: Initialize DB first, then decide route
  /// This prevents race condition where fast devices route to profile
  /// because DB query fails before DB is ready
  Future<void> _initializeAndRoute() async {
    try {
      _appGateLog('🚪 [AppGate] DB prewarm: start');
      await AppDatabaseManager.instance.database;
      _appGateLog('🚪 [AppGate] DB prewarm: ready');
    } catch (e) {
      debugPrint('🚪 [AppGate] DB prewarm failed: $e');
    }

    // Initialize media cache folder structure (do NOT block routing)
    try {
      _appGateLog('📁 [AppGate] Media cache init: start (background)');
      unawaited(
        MediaCacheManager.instance.initialize().catchError(
          (e) => debugPrint('📁 [AppGate] Media cache init failed: $e'),
        ),
      );
    } catch (e) {
      debugPrint('📁 [AppGate] Media cache init failed: $e');
    }

    // Now safe to check route
    await _checkNotificationAndRoute();
  }

  /// Load preference for showing emoji in app icon
  Future<void> _loadEmojiDisplayPreference() async {
    try {
      final v = await TokenSecureStorage.instance.getShowEmojiInAppIcon();
      if (mounted) setState(() => _showEmojiInAppIcon = v);
    } catch (_) {}
  }

  /// Load user's emoji from database
  Future<void> _loadUserEmoji() async {
    try {
      final userId = await TokenSecureStorage.instance.getCurrentUserIdUUID();
      if (userId != null) {
        final emoji = await DraggableEmojiLocalDataSource.getUserEmoji(userId);
        if (mounted) {
          setState(() => _userEmoji = emoji);
        }
      }
    } catch (e) {
      debugPrint('⚠️ [AppGate] Error loading emoji: $e');
    }
  }

  /// Check if app was opened from notification, if so handle it, otherwise proceed with normal routing
  Future<void> _checkNotificationAndRoute() async {
    try {
      _appGateLog('');
      _appGateLog('🚺 ═══════════════════════════════════════════════════════');
      _appGateLog('🚺 [AppGate] CHECKING NOTIFICATION AND ROUTING');
      _appGateLog('🚺 ═══════════════════════════════════════════════════════');

      // First check if app was opened from a notification
      final hasNotification = await _hasTerminatedNotification();
      _appGateLog('🚺 [AppGate] Has terminated notification: $hasNotification');

      if (hasNotification) {
        _appGateLog('🔔 [AppGate] ✅ App OPENED FROM NOTIFICATION');
        _appGateLog(
          '🔔 [AppGate] Step 1: Setting up app state with normal route',
        );

        // Still do normal route decision to set up the app state properly
        await _decideRoute();

        _appGateLog(
          '🔔 [AppGate] Step 2: Waiting 400ms for navigation to settle',
        );
        await Future.delayed(const Duration(milliseconds: 400));

        _appGateLog('🔔 [AppGate] Step 3: Calling checkTerminatedMessage');
        await FirebaseNotificationHandler.instance.checkTerminatedMessage();

        _appGateLog('✅ [AppGate] Notification handling completed');
      } else {
        _appGateLog('📱 [AppGate] Normal app launch (no notification)');
        await _decideRoute();
      }

      _appGateLog('🚺 ═══════════════════════════════════════════════════════');
      _appGateLog('');
    } catch (e) {
      debugPrint('❌ [AppGate] Error in notification check: $e');
      debugPrint('❌ Stack trace: ${StackTrace.current}');
      // Fallback to normal routing
      await _decideRoute();
    }
  }

  /// Check if there's a terminated notification without consuming it
  Future<bool> _hasTerminatedNotification() async {
    try {
      final message = await FirebaseMessaging.instance
          .getInitialMessage()
          .timeout(const Duration(seconds: 2), onTimeout: () => null);
      return message != null;
    } catch (e) {
      debugPrint('❌ [AppGate] Error checking initial message: $e');
      return false;
    }
  }

  /// WHATSAPP-STYLE: Fast routing using LOCAL DB only (no network checks)
  ///
  /// Flow:
  /// 1. Get token + userId from local storage (parallel, instant)
  /// 2. Check local DB for user profile (instant)
  /// 3. Navigate IMMEDIATELY based on local data
  /// 4. Initialize WebSocket in BACKGROUND (non-blocking)
  ///
  /// Routes:
  /// - No token → phone number entry
  /// - No userId or incomplete profile → user profile setup
  /// - Complete profile → chat list (main app)
  Future<void> _decideRoute() async {
    try {
      _appGateLog(
        '🚀 [AppGate] WHATSAPP-STYLE: Fast route decision (local DB only)',
      );
      final startTime = DateTime.now();

      // STEP 1: Get token + userId in PARALLEL (both are local storage - instant)
      final results = await Future.wait([
        TokenSecureStorage.instance.getToken(),
        TokenSecureStorage.instance.getCurrentUserIdUUID(),
      ]);

      final token = results[0];
      final userId = results[1];

      _appGateLog(
        '⚡ [AppGate] Token+UserId fetched in ${DateTime.now().difference(startTime).inMilliseconds}ms',
      );

      _hasToken = token != null && token.isNotEmpty;
      if (!mounted) return;

      // STEP 2: No token = not logged in
      if (token == null || token.isEmpty) {
        _appGateLog('🔑 [AppGate] No token → Phone entry');
        _completeWith(RouteNames.phoneNumberEntry);
        return;
      }

      // STEP 3: No userId = incomplete auth
      if (userId == null || userId.isEmpty) {
        _appGateLog('👤 [AppGate] No userId → Profile setup');
        _completeWith(RouteNames.currentUserProfile);
        return;
      }
      _appGateLog('👤 [AppGate] UserId: $userId');

      // STEP 4: Check LOCAL snapshot first (fastest path)
      Map<String, dynamic>? snap;
      try {
        snap = await AppStartupSnapshotTable.instance.getByUserId(userId);
      } catch (_) {}

      // WHATSAPP-STYLE: Trust snapshot for up to 6 months (matches backend JWT/FCM expiry).
      // We only skip the DB when snapshot says profile is COMPLETE. If it
      // says INCOMPLETE, we fall through to DB check so offline profile
      // updates (name + status in local DB) can still unlock the chat list.
      if (snap != null) {
        const maxStaleDuration = Duration(days: 180);
        final lastVerified =
            (snap[AppStartupSnapshotTable.columnLastVerifiedAt] as int?) ?? 0;
        final ageMs = DateTime.now().millisecondsSinceEpoch - lastVerified;

        if (ageMs <= maxStaleDuration.inMilliseconds) {
          final profileComplete =
              (snap[AppStartupSnapshotTable.columnProfileComplete] as int? ??
                  0) ==
              1;

          if (profileComplete) {
            _appGateDecisionLog(
              '⚡ [AppGateDecision] Snapshot says complete (age=${ageMs}ms) → fast-routing to mainNavigation',
            );
            _completeWith(RouteNames.mainNavigation);
            _initializeServicesInBackground(userId);
            return;
          }

          _appGateLog(
            '⚠️ [AppGate] Snapshot says incomplete → double-check DB',
          );
        }
      }

      // STEP 5: No valid snapshot - check profile from local DB
      final row = await CurrentUserProfileTable.instance.getByUserId(userId);
      if (!mounted) return;

      if (row == null) {
        _appGateLog(
          '👤 [AppGate] No profile in DB and no snapshot → Profile setup',
        );
        _completeWith(RouteNames.currentUserProfile);
        _initializeServicesInBackground(userId);
        return;
      }

      // STEP 6: Check profile completeness
      final firstName = row[CurrentUserProfileTable.columnFirstName]
          ?.toString()
          .trim();
      final statusContent = row[CurrentUserProfileTable.columnStatusContent]
          ?.toString()
          .trim();
      final isProfileComplete =
          (firstName?.isNotEmpty ?? false) &&
          _isMeaningfulStatus(statusContent);

      final route = isProfileComplete
          ? RouteNames.mainNavigation
          : RouteNames.currentUserProfile;

      final statusPreview = (statusContent == null)
          ? 'null'
          : (statusContent.length > 80
                ? '${statusContent.substring(0, 80)}...'
                : statusContent);
      _appGateDecisionLog(
        '🧭 [AppGateDecision] userId=$userId firstName="${firstName ?? ''}" status="$statusPreview" meaningful=${_isMeaningfulStatus(statusContent)} -> complete=$isProfileComplete route=$route',
      );
      _appGateLog(
        '✅ [AppGate] Profile ${isProfileComplete ? "complete" : "incomplete"} → $route',
      );
      _appGateLog(
        '⏱️ Total time: ${DateTime.now().difference(startTime).inMilliseconds}ms',
      );

      _completeWith(route);

      // Update snapshot + initialize services in BACKGROUND
      _initializeServicesInBackground(userId);
      unawaited(
        AppStartupSnapshotTable.instance
            .upsertSnapshot(
              userId: userId,
              profileComplete: isProfileComplete,
              lastKnownRoute: route,
            )
            .catchError((_) {}),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ [AppGate] Error: $e\n$stackTrace');
      if (!mounted) return;
      // STRICT: on errors, never route to chat list unless we proved profile complete.
      _completeWith(
        _hasToken ? RouteNames.currentUserProfile : RouteNames.phoneNumberEntry,
      );
    }
  }

  /// Initialize WebSocket and services in BACKGROUND (non-blocking)
  /// WhatsApp-style: User sees UI first, connection happens after
  void _initializeServicesInBackground(String userId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Future(() async {
        try {
          _appGateLog('⚡ [Background] Preloading chat list into memory...');
          await ChatListCache.instance.preload();

          // WHATSAPP-STYLE: Initialize reactive stream for real-time updates
          _appGateLog('📡 [Background] Initializing ChatListStream...');
          await ChatListStream.instance.initialize();

          _appGateLog('🔌 [Background] Starting ChatEngineService...');
          final connected = await ChatEngineService.instance.initialize(userId);
          _appGateLog(
            '🔌 [Background] ChatEngineService: ${connected ? "CONNECTED ✅" : "offline mode"}',
          );

          unawaited(
            AppUpgradeManager.instance.runIfNeeded(currentUserId: userId),
          );

          // Sync unread count + contacts via REST on app launch (fire-and-forget)
          unawaited(
            ChatEngineService.instance.syncUnreadCountAndContacts(
              reason: 'app_launch',
              force: false,
            ),
          );

          // WHATSAPP-STYLE: Sync profile updates (delta sync) on app launch
          // Fetches only contacts whose profiles changed since last sync
          _appGateLog('🔄 [Background] Starting profile delta sync...');
          unawaited(
            ContactsRepository.instance
                .syncProfileUpdates()
                .then((count) {
                  if (count > 0) {
                    _appGateLog(
                      '✅ [Background] Profile sync: Updated $count contact(s)',
                    );
                  } else {
                    _appGateLog(
                      '✅ [Background] Profile sync: No updates found',
                    );
                  }
                })
                .catchError((e) {
                  debugPrint('❌ [Background] Profile sync failed: $e');
                }),
          );
        } catch (e) {
          debugPrint('❌ [Background] Service init failed: $e');
        }
      });
    });
  }

  /// Timeout handler that fires after 5 seconds to prevent indefinite loading.
  /// Uses pending route if available, otherwise defaults to phone number entry.
  void _onTimeout() async {
    if (_navigated || !mounted) return;
    debugPrint('⏰ [AppGate] Timeout fired after 5 seconds');
    if (_pendingRoute != null) {
      debugPrint('⏰ [AppGate] Using pending route: $_pendingRoute');
      _safeNavigate(_pendingRoute!);
      return;
    }

    // If route decision is slow, do a minimal LOCAL route decision here.
    // IMPORTANT: be conservative: only go to chat list when profile is COMPLETE.
    String? token;
    try {
      debugPrint('⏰ [AppGate] No cached token, re-checking storage...');
      token = await TokenSecureStorage.instance.getToken();
      if (_navigated || !mounted) return;
      if (_pendingRoute != null) {
        debugPrint(
          '⏰ [AppGate] Pending route resolved during timeout: $_pendingRoute',
        );
        _safeNavigate(_pendingRoute!);
        return;
      }
      final hasTokenNow = token != null && token.isNotEmpty;
      debugPrint(
        '⏰ [AppGate] Token re-check result: ${hasTokenNow ? "FOUND" : "NOT FOUND"}',
      );
      if (!hasTokenNow) {
        _safeNavigate(RouteNames.phoneNumberEntry);
        return;
      }
    } catch (e) {
      debugPrint('⏰ [AppGate] Token re-check failed: $e');
      _safeNavigate(RouteNames.phoneNumberEntry);
      return;
    }

    String? userId;
    try {
      userId = await TokenSecureStorage.instance.getCurrentUserIdUUID();
    } catch (_) {}

    if (_navigated || !mounted) return;
    if (_pendingRoute != null) {
      debugPrint(
        '⏰ [AppGate] Pending route resolved during timeout: $_pendingRoute',
      );
      _safeNavigate(_pendingRoute!);
      return;
    }

    // Ensure DB is available (best effort) so we can check local profile completeness.
    try {
      await AppDatabaseManager.instance.database.timeout(
        const Duration(seconds: 1),
      );
    } catch (_) {}

    if (_navigated || !mounted) return;
    if (_pendingRoute != null) {
      debugPrint(
        '⏰ [AppGate] Pending route resolved during timeout: $_pendingRoute',
      );
      _safeNavigate(_pendingRoute!);
      return;
    }

    bool isProfileComplete = false;
    if (userId != null && userId.isNotEmpty) {
      try {
        final row = await CurrentUserProfileTable.instance.getByUserId(userId);
        if (_navigated || !mounted) return;
        if (_pendingRoute != null) {
          debugPrint(
            '⏰ [AppGate] Pending route resolved during timeout: $_pendingRoute',
          );
          _safeNavigate(_pendingRoute!);
          return;
        }
        final firstName = row?[CurrentUserProfileTable.columnFirstName]
            ?.toString()
            .trim();
        final statusContent = row?[CurrentUserProfileTable.columnStatusContent]
            ?.toString()
            .trim();
        isProfileComplete =
            (firstName?.isNotEmpty ?? false) &&
            _isMeaningfulStatus(statusContent);

        final statusPreview = (statusContent == null)
            ? 'null'
            : (statusContent.length > 80
                  ? '${statusContent.substring(0, 80)}...'
                  : statusContent);
        _appGateDecisionLog(
          '⏰ [AppGateTimeoutDecision] userId=$userId firstName="${firstName ?? ''}" status="$statusPreview" meaningful=${_isMeaningfulStatus(statusContent)} -> complete=$isProfileComplete',
        );
      } catch (_) {}
    }

    final fallback = isProfileComplete
        ? RouteNames.mainNavigation
        : RouteNames.currentUserProfile;

    if (_navigated || !mounted) return;
    if (_pendingRoute != null) {
      debugPrint(
        '⏰ [AppGate] Pending route resolved during timeout: $_pendingRoute',
      );
      _safeNavigate(_pendingRoute!);
      return;
    }
    debugPrint(
      '⏰ [AppGate] Timeout fallback: navigating to ${fallback == RouteNames.chatList ? 'chat list (profile complete)' : 'current user profile (profile incomplete/unknown)'}',
    );
    _safeNavigate(fallback);
  }

  /// Sets the pending route and navigates immediately if timeout has already fired.
  /// This ensures navigation happens either when route is decided or timeout occurs,
  /// whichever comes first.
  void _completeWith(String routeName) {
    if (_navigated || !mounted) return;
    _pendingRoute = routeName;
    _maxWaitTimer?.cancel();
    _appGateLog('🚪 [AppGate] Route resolved: $routeName');
    Future(() {
      if (mounted && !_navigated) {
        _safeNavigate(routeName);
      }
    });
  }

  /// Performs the actual navigation with safety checks to prevent double navigation.
  /// Cancels the timeout timer and uses pushReplacementNamed to replace the gate.
  void _safeNavigate(String routeName) {
    if (_navigated || !mounted) return;
    _navigated = true;
    _maxWaitTimer?.cancel();
    _appGateLog('🚪 [AppGate] Navigating -> $routeName');
    Navigator.of(context).pushReplacementNamed(routeName);
  }

  @override
  void dispose() {
    _maxWaitTimer?.cancel();
    super.dispose();
  }

  /// Builds the loading screen UI with app logo and name.
  /// Displays while route decision and database prewarming are in progress.
  @override
  Widget build(BuildContext context) {
    // Initialize group chat listeners and re-join rooms
    ref.watch(groupChatInitializerProvider);

    return ResponsiveLayoutBuilder(
      builder: (context, constraints, breakpoint) {
        final responsive = ResponsiveSize(
          context: context,
          constraints: constraints,
          breakpoint: breakpoint,
        );

        final logoSize = responsive.size(140);
        final emojiSize = responsive.size(24);
        final labelTop =
            (constraints.maxHeight * 0.5) +
            (logoSize * 0.5) +
            responsive.spacing(24);

        return Scaffold(
          backgroundColor: Colors.white,
          body: Stack(
            children: [
              // App icon - fixed position in center
              Center(
                child: Image.asset(
                  ImageAssets.appGateLogo,
                  width: logoSize,
                  height: logoSize,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.chat_bubble_outline,
                      size: logoSize,
                      color: AppColors.primary,
                    );
                  },
                ),
              ),
              // Text below icon - positioned independently
              if (_showEmojiInAppIcon)
                Positioned(
                  left: 0,
                  right: 0,
                  top: labelTop,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'ChatAway+ .........',
                        style: AppTextSizes.large(
                          context,
                        ).copyWith(color: AppColors.iconPrimary),
                      ),
                      Text(
                        ' $_userEmoji',
                        style: AppTextSizes.custom(
                          context,
                          emojiSize,
                        ).copyWith(color: AppColors.iconPrimary),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
