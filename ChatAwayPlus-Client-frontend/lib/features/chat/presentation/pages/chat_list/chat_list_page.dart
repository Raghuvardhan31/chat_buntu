import 'package:chataway_plus/features/chat/presentation/widgets/common/chat_profile_quick_actions_sheet.dart';
import 'package:chataway_plus/features/voice_call/presentation/pages/outgoing_call_page.dart';
import 'package:chataway_plus/features/voice_call/data/models/call_model.dart';
import 'package:chataway_plus/features/chat/presentation/pages/media_viewer/app_user_chat_picture_view.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/core/themes/app_text_styles.dart';
import 'package:chataway_plus/core/routes/route_names.dart';
import 'package:chataway_plus/features/chat/models/chat_message_model.dart';
import 'package:chataway_plus/features/chat/utils/chat_helper.dart';
import 'package:chataway_plus/features/chat/presentation/providers/chat_list_providers/chat_list_provider.dart';
import 'package:chataway_plus/core/notifications/cache/notification_cache_manager.dart';
import 'package:chataway_plus/features/chat/presentation/providers/chat_page_providers/notification_stream_provider.dart';
import 'package:chataway_plus/features/chat/data/services/chat_engine/index.dart';
import 'package:chataway_plus/features/contacts/presentation/providers/contacts_management.dart';
import 'package:chataway_plus/features/contacts/data/models/contact_local.dart';
import 'package:chataway_plus/features/contacts/utils/contact_display_name_helper.dart';
import 'package:chataway_plus/core/sync/authenticated_image_cache_manager.dart';
import 'package:chataway_plus/core/constants/api_url/api_urls.dart';
import 'package:chataway_plus/core/connectivity/connectivity_service.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:chataway_plus/features/chat/presentation/providers/chat_list_providers/chat_list_stream.dart';
import 'package:chataway_plus/core/snackbar/app_snackbar.dart';
import 'package:chataway_plus/features/chat/data/services/business/chat_picture_likes_service.dart';
import 'package:chataway_plus/features/chat/data/services/local/chat_picture_likes_local_db.dart';
import 'package:chataway_plus/features/chat/presentation/pages/chat_list/widgets/chat_list_tile_widget.dart';
import 'package:chataway_plus/features/chat/presentation/pages/chat_list/widgets/chat_list_empty_states.dart';
import 'package:chataway_plus/features/chat/presentation/pages/chat_list/widgets/speed_dial_fab_widget.dart';

/// Global key for accessing ChatListPage state from MainNavigationPage
final chatListPageKey = GlobalKey<_ChatListPageState>();

class ChatListPage extends ConsumerStatefulWidget {
  const ChatListPage({super.key});
  @override
  ConsumerState<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends ConsumerState<ChatListPage>
    with WidgetsBindingObserver {
  static const bool _verboseLogs = false;

  String _sanitizePreviewText(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return raw;

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

    if (decoded is Map) {
      final map = Map<String, dynamic>.from(decoded);
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
          if (t.isNotEmpty) return t;
        }
      }

      // If message is null/empty but we have messageType, return friendly label
      final msgType = (map['messageType'] ?? map['message_type'])
          ?.toString()
          .toLowerCase();
      if (msgType != null) {
        if (msgType == 'image' || msgType.startsWith('i')) {
          return 'Photo';
        } else if (msgType == 'document' || msgType == 'pdf') {
          final fileName = (map['fileName'] ?? map['file_name'])?.toString();
          return (fileName != null && fileName.trim().isNotEmpty)
              ? fileName
              : 'PDF';
        } else if (msgType == 'video') {
          return 'Video';
        } else if (msgType == 'poll') {
          return 'Poll';
        }
      }
    }

    return raw;
  }

  bool _isSearching = false;
  bool _isSpeedDialOpen = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final NotificationCacheManager _cacheManager = NotificationCacheManager();
  StreamSubscription<ChatMessageModel>? _hybridNewMessageSub;
  StreamSubscription? _profileUpdateSub; // WhatsApp-style profile updates
  StreamSubscription? _messageStatusSub; // WhatsApp-style tick status sync
  DateTime? _lastAvatarPrefetch;
  bool _avatarPrefetchInProgress = false;
  String? _currentUserId; // Cache current user ID to avoid repeated async calls

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _searchController.addListener(_filterChats);
    _loadCurrentUserId(); // Load current user ID once
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Ensure contacts are loaded first before loading chat contacts
      // This prevents the "ChatAway user" -> real name flicker
      _ensureContactsLoaded().then((_) {
        if (!mounted) return;
        // COLD START: Force server refresh to get messages received while app was killed
        // This ensures chat list shows latest messages and unread counts
        ref.read(chatListNotifierProvider.notifier).loadContacts(force: true);
        final m = ScaffoldMessenger.of(context);
        m.hideCurrentSnackBar();
        m.clearSnackBars();
        _loadNotificationCounts();
        _prefetchAvatarsIfOnline();
      });
    });

    // Listen to notification stream
    ref.listenManual(notificationStreamProvider, (previous, next) {
      next.whenData((event) {
        if (_verboseLogs) {
          debugPrint(
            '🔔 [ChatList] Notification event received for: ${event.senderId}',
          );
        }
        unawaited(_refreshNotificationCountForSender(event.senderId));
      });
    });

    // Refresh cached notification counts once chat contacts finish loading
    ref.listenManual(chatListNotifierProvider, (previous, next) {
      final wasLoading = previous?.loading ?? true;
      final nowLoaded = !next.loading;
      final contactsChanged = previous?.contacts != next.contacts;
      if (nowLoaded && (wasLoading || contactsChanged)) {
        _loadNotificationCounts();
      }
    });
    // WHATSAPP-STYLE: Listen for profile updates from contacts
    _profileUpdateSub = ChatEngineService.instance.profileUpdateStream.listen((
      update,
    ) async {
      if (_verboseLogs) {
        debugPrint('👤 [ChatList] Profile update from: ${update.userId}');
      }
      // Refresh from DB and reload UI - use forceRefresh to bypass cache
      if (mounted) {
        // Wait for notifier to reload from database
        await ref
            .read(contactsManagementNotifierProvider.notifier)
            .loadFromCache();
        // Force refresh chat list to bypass debounce and memory cache
        // This ensures deleted chat pictures show default icon immediately
        if (mounted) {
          ref
              .read(chatListNotifierProvider.notifier)
              .forceRefreshContacts(forceServer: false);
        }
      }
    });

    // WHATSAPP-STYLE: Message status updates are now handled by ChatListStream
    // StreamBuilder in _buildBodyWithHeader() automatically rebuilds on stream events
    // ChatEngineService updates ChatListStream directly, no need for manual listener here
    _messageStatusSub = ChatEngineService.instance.messageStatusStream.listen((
      statusUpdate,
    ) {
      if (_verboseLogs) {
        debugPrint(
          '✓✓ [ChatList] Status update received: ${statusUpdate.messageId} → ${statusUpdate.status}',
        );
      }
      // ChatListStream is already updated by ChatEngineService
      // StreamBuilder will automatically rebuild the UI
    });
  }

  /// Load notification counts for all contacts
  Future<void> _loadCurrentUserId() async {
    _currentUserId = await ChatHelper.getCurrentUserId();
    if (mounted) {
      setState(() {}); // Trigger rebuild with cached user ID
    }
  }

  Future<void> _showContactQuickActionsSheet({
    required BuildContext context,
    required String name,
    required String contactId,
    required String mobileNumber,
    String? chatPictureUrl,
    String? chatPictureVersion,
  }) async {
    // Resolve contact's Share Your Voice Text (SYVT) for display in sheet
    String? syvtText;
    try {
      final allContacts = [
        ...ref.read(appUserContactsProvider),
        ...ref.read(nonAppUserContactsProvider),
      ];
      for (final c in allContacts) {
        if ((c.userDetails?.userId ?? '').trim() == contactId.trim()) {
          syvtText = c.userDetails?.recentStatus?.content;
          break;
        }
      }
    } catch (_) {}

    ImageProvider<Object>? avatarImageProvider;
    String? chatPictureUrlValue = chatPictureUrl;
    String? chatPictureVersionValue = chatPictureVersion;

    String? resolveAvatarUrl(String? rawUrl, String? version) {
      final url = rawUrl?.trim() ?? '';
      if (url.isEmpty) return null;

      final base = url.startsWith('http') ? url : '${ApiUrls.mediaBaseUrl}$url';
      final v = version?.trim() ?? '';
      if (v.isEmpty) return base;

      try {
        final uri = Uri.parse(base);
        final params = Map<String, String>.from(uri.queryParameters);
        params['v'] = v;
        return uri.replace(queryParameters: params).toString();
      } catch (_) {
        final sep = base.contains('?') ? '&' : '?';
        return '$base${sep}v=$v';
      }
    }

    void syncAvatarProviderFromCurrentValues() {
      final resolved = resolveAvatarUrl(
        chatPictureUrlValue,
        chatPictureVersionValue,
      );
      if (resolved != null && resolved.isNotEmpty) {
        avatarImageProvider = CachedNetworkImageProvider(
          resolved,
          cacheManager: AuthenticatedImageCacheManager.instance,
        );
      } else {
        avatarImageProvider = null;
      }
    }

    syncAvatarProviderFromCurrentValues();

    bool? isLoved;
    bool loveRequestInProgress = false;
    bool loveInitStarted = false;
    bool dialogMounted = true; // Track if dialog is still mounted

    StateSetter? dialogSetState;
    final dialogProfileUpdateSub = ChatEngineService
        .instance
        .profileUpdateStream
        .listen((update) {
          if (!dialogMounted) return; // Don't update if dialog is closed
          if (update.userId != contactId) return;
          final newPic = update.chatPictureUrl;
          if (newPic == null || newPic.isEmpty) return;
          if (chatPictureUrlValue == newPic) return;

          chatPictureUrlValue = newPic;
          chatPictureVersionValue = update.chatPictureVersion;
          syncAvatarProviderFromCurrentValues();

          isLoved = false;
          loveInitStarted = false;
          loveRequestInProgress = false;
          dialogSetState?.call(() {});
        });

    try {
      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierColor: Colors.black.withAlpha((0.4 * 255).round()),
        barrierLabel: 'Dismiss',
        pageBuilder: (dialogContext, _, __) {
          return Material(
            color: Colors.transparent,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(dialogContext).maybePop(),
              child: Center(
                child: StatefulBuilder(
                  builder: (context, setDialogState) {
                    dialogSetState = setDialogState;

                    // Safe setState that checks if dialog is still mounted
                    void safeSetDialogState(VoidCallback fn) {
                      if (dialogMounted) {
                        setDialogState(fn);
                      }
                    }

                    Future<void> ensureInitialLovedLoaded() async {
                      if (loveInitStarted) return;
                      loveInitStarted = true;

                      if (isLoved != null) return;
                      final targetChatPictureId = chatPictureVersionValue ?? '';
                      if (targetChatPictureId.isEmpty) {
                        isLoved = false;
                        safeSetDialogState(() {});
                        return;
                      }

                      final currentUserId = _currentUserId;
                      if (currentUserId == null || currentUserId.isEmpty) {
                        isLoved = false;
                        safeSetDialogState(() {});
                        return;
                      }

                      final cached = await ChatPictureLikesDatabaseService
                          .instance
                          .getLikeState(
                            currentUserId: currentUserId,
                            likedUserId: contactId,
                            targetChatPictureId: targetChatPictureId,
                          );
                      if (!dialogMounted) return; // Check after async call
                      if (cached != null) {
                        isLoved = cached;
                        debugPrint(
                          '💾 [QuickActionsSheet] Using cached chat picture like state=$isLoved (no server check on open)',
                        );
                        safeSetDialogState(() {});
                        return;
                      }

                      debugPrint(
                        '🕒 [QuickActionsSheet] No cached chat picture like state; skipping server check on open',
                      );
                      safeSetDialogState(() {});
                    }

                    ensureInitialLovedLoaded();

                    return GestureDetector(
                      onTap: () {},
                      child: ChatProfileQuickActionsSheet(
                        displayName: name,
                        avatarImageProvider: avatarImageProvider,
                        isLoved: isLoved ?? false,
                        syvtText: syvtText,
                        onPictureTap: () async {
                          Navigator.of(
                            dialogContext,
                            rootNavigator: true,
                          ).pop();

                          if (!mounted) return;

                          await Navigator.of(context, rootNavigator: true).push(
                            MaterialPageRoute(
                              builder: (context) => AppUserChatPictureView(
                                displayName: name,
                                chatPictureUrl: resolveAvatarUrl(
                                  chatPictureUrlValue,
                                  chatPictureVersionValue,
                                ),
                                contactId: contactId,
                                chatPictureVersion: chatPictureVersionValue,
                              ),
                            ),
                          );
                        },
                        onChat: () async {
                          // Mirror the same navigation behavior as tapping the chat tile.
                          if (_currentUserId == null) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('User not authenticated'),
                                ),
                              );
                            }
                            return;
                          }

                          // Close the overlay route on the root navigator first
                          Navigator.of(
                            dialogContext,
                            rootNavigator: true,
                          ).pop();

                          if (!mounted) return;

                          // Navigate to individual chat page
                          await Navigator.of(
                            context,
                            rootNavigator: true,
                          ).pushNamed(
                            RouteNames.oneToOneChat,
                            arguments: {
                              'contactName': name,
                              'receiverId': contactId,
                              'currentUserId': _currentUserId,
                            },
                          );

                          // Refresh chat list and notification counts on return
                          if (mounted) {
                            ref
                                .read(chatListNotifierProvider.notifier)
                                .forceRefreshContacts();
                            await _loadNotificationCounts();
                          }
                        },
                        onLove: () async {
                          if (loveRequestInProgress) return;
                          if (avatarImageProvider == null) {
                            AppSnackbar.showTopInfo(
                              dialogContext,
                              'No picture available to like',
                            );
                            return;
                          }
                          if (!ConnectivityCache.instance.isOnline) {
                            AppSnackbar.showOfflineWarning(
                              context,
                              "You're offline",
                            );
                            return;
                          }
                          final targetChatPictureId =
                              chatPictureVersionValue ?? '';
                          if (targetChatPictureId.isEmpty) {
                            AppSnackbar.showTopInfo(
                              dialogContext,
                              'No picture available to like',
                            );
                            return;
                          }

                          final currentUserId = _currentUserId;
                          if (currentUserId == null || currentUserId.isEmpty) {
                            AppSnackbar.showTopInfo(
                              dialogContext,
                              'User not authenticated',
                            );
                            return;
                          }

                          // If we don't know the current state (no cache), check once
                          // only when the user taps Love.
                          if (isLoved == null) {
                            try {
                              debugPrint(
                                '🌐 [QuickActionsSheet] isLoved unknown; checking server now (user tapped Love)...',
                              );
                              final liked = await ChatPictureLikesService
                                  .instance
                                  .check(
                                    likedUserId: contactId,
                                    targetChatPictureId: targetChatPictureId,
                                  );
                              if (!dialogMounted) return;
                              isLoved = liked;
                              safeSetDialogState(() {});
                              await ChatPictureLikesDatabaseService.instance
                                  .upsert(
                                    currentUserId: currentUserId,
                                    likedUserId: contactId,
                                    targetChatPictureId: targetChatPictureId,
                                    isLiked: liked,
                                  );
                            } catch (e) {
                              debugPrint(
                                '⚠️ [QuickActionsSheet] Failed to check like state on Love tap: $e',
                              );
                              isLoved = isLoved ?? false;
                              safeSetDialogState(() {});
                            }
                          }

                          // Check rate limit (max 4 toggles per picture)
                          final canToggle =
                              await ChatPictureLikesDatabaseService.instance
                                  .canToggle(
                                    currentUserId: currentUserId,
                                    likedUserId: contactId,
                                    targetChatPictureId: targetChatPictureId,
                                  );
                          if (!canToggle) {
                            if (!dialogMounted || !context.mounted) return;
                            AppSnackbar.showTopInfo(
                              dialogContext,
                              'Limit reached. New picture = new chance!',
                            );
                            return;
                          }

                          final beforeLoved = isLoved ?? false;
                          final optimistic = !beforeLoved;

                          // Set optimistic state and mark request in progress
                          isLoved = optimistic;
                          loveRequestInProgress = true;
                          safeSetDialogState(() {});

                          try {
                            final result = await ChatPictureLikesService
                                .instance
                                .toggle(
                                  likedUserId: contactId,
                                  targetChatPictureId: targetChatPictureId,
                                  currentUiState: beforeLoved,
                                );

                            if (!dialogMounted) return;

                            // Increment toggle count after successful toggle
                            await ChatPictureLikesDatabaseService.instance
                                .incrementToggleCount(
                                  currentUserId: currentUserId,
                                  likedUserId: contactId,
                                  targetChatPictureId: targetChatPictureId,
                                );

                            await ChatPictureLikesDatabaseService.instance
                                .upsert(
                                  currentUserId: currentUserId,
                                  likedUserId: contactId,
                                  targetChatPictureId: targetChatPictureId,
                                  isLiked: result.isLiked,
                                  likeId: result.likeId,
                                  likeCount: result.likeCount,
                                );

                            // Reconcile UI with server response
                            loveRequestInProgress = false;
                            if (result.isLiked != isLoved) {
                              isLoved = result.isLiked;
                            }
                            safeSetDialogState(() {});
                          } catch (e) {
                            debugPrint('❤️ [LIKE] Error: $e');
                            if (!dialogMounted) return;
                            // Revert to previous state on error
                            isLoved = beforeLoved;
                            loveRequestInProgress = false;
                            try {
                              await ChatPictureLikesDatabaseService.instance
                                  .upsert(
                                    currentUserId: currentUserId,
                                    likedUserId: contactId,
                                    targetChatPictureId: targetChatPictureId,
                                    isLiked: beforeLoved,
                                  );
                            } catch (_) {}
                            safeSetDialogState(() {});
                            if (mounted) {
                              AppSnackbar.showTopInfo(
                                dialogContext,
                                'Failed to update',
                              );
                            }
                          }
                        },
                        onVoiceCall: () async {
                          Navigator.of(
                            dialogContext,
                            rootNavigator: true,
                          ).pop();

                          if (!mounted) return;

                          final callId =
                              'call_${DateTime.now().millisecondsSinceEpoch}';
                          final channelName = 'channel_$callId';
                          await Navigator.of(context, rootNavigator: true).push(
                            MaterialPageRoute(
                              builder: (_) => OutgoingCallPage(
                                currentUserId: _currentUserId ?? '',
                                contactId: contactId,
                                contactName: name,
                                callType: CallType.voice,
                                channelName: channelName,
                                callId: callId,
                              ),
                            ),
                          );
                        },
                        onProfile: () async {
                          // Ensure the quick-actions overlay is completely dismissed
                          Navigator.of(
                            dialogContext,
                            rootNavigator: true,
                          ).pop();

                          if (!mounted) return;

                          // Then navigate to Connection Insight Hub (profile)
                          await Navigator.of(
                            context,
                            rootNavigator: true,
                          ).pushNamed(
                            RouteNames.profile,
                            arguments: {
                              'contactName': name,
                              'contactId': contactId,
                              'mobileNumber': mobileNumber,
                              'chatPictureUrl': resolveAvatarUrl(
                                chatPictureUrlValue,
                                chatPictureVersionValue,
                              ),
                            },
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
        transitionBuilder: (context, animation, secondaryAnimation, child) {
          final curvedAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutBack,
          );
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(
                begin: 0.85,
                end: 1,
              ).animate(curvedAnimation),
              child: child,
            ),
          );
        },
      );
    } finally {
      dialogMounted = false; // Mark dialog as unmounted
      await dialogProfileUpdateSub.cancel();
    }
  }

  /// Ensure contacts are loaded before displaying chat list
  /// This prevents the "ChatAway user" -> real name flicker
  Future<void> _ensureContactsLoaded() async {
    try {
      // Force refresh contacts if they're not loaded yet
      final contactsAsyncValue = ref.read(contactsManagementNotifierProvider);
      final contactsState = contactsAsyncValue.valueOrNull;

      if (contactsState == null ||
          (contactsState.registeredContacts.isEmpty &&
              contactsState.nonRegisteredContacts.isEmpty)) {
        if (_verboseLogs) {
          debugPrint('🔄 [ChatList] Loading contacts to prevent name flicker');
        }
        await ref
            .read(contactsManagementNotifierProvider.notifier)
            .loadFromCache();
      }
    } catch (e) {
      debugPrint('⚠️ [ChatList] Error ensuring contacts loaded: $e');
    }
  }

  Future<void> _loadNotificationCounts() async {
    try {
      final chatState = ref.read(chatListNotifierProvider);
      final Map<String, NotificationData> notificationData = {};

      // Load notification counts in parallel batches to avoid blocking UI
      final contacts = chatState.contacts;
      const batchSize = 20;
      for (var i = 0; i < contacts.length; i += batchSize) {
        final batch = contacts.skip(i).take(batchSize);
        final futures = batch.map((contact) async {
          final userId = contact.user.id;
          final cachedMessages = await _cacheManager.getCachedMessages(userId);
          if (cachedMessages.isNotEmpty) {
            return MapEntry(
              userId,
              NotificationData(
                count: cachedMessages.length,
                lastMessage: _sanitizePreviewText(
                  (cachedMessages.last['text'] as String?) ?? '',
                ),
              ),
            );
          }
          return null;
        });
        final results = await Future.wait(futures);
        for (final entry in results) {
          if (entry != null) {
            notificationData[entry.key] = entry.value;
          }
        }
      }

      if (!mounted) return;
      // Update the provider state
      ref.read(notificationCountsProvider.notifier).setAll(notificationData);
    } catch (e) {
      debugPrint('❌ [ChatList] Error loading notification counts: $e');
    }
  }

  Future<void> _refreshNotificationCountForSender(String senderId) async {
    if (senderId.isEmpty) return;
    try {
      final cachedMessages = await _cacheManager.getCachedMessages(senderId);
      if (!mounted) return;

      if (cachedMessages.isNotEmpty) {
        final count = cachedMessages.length;
        final lastMessage = _sanitizePreviewText(
          (cachedMessages.last['text'] as String?) ?? '',
        );
        ref
            .read(notificationCountsProvider.notifier)
            .updateNotification(senderId, count, lastMessage);
      } else {
        ref
            .read(notificationCountsProvider.notifier)
            .clearNotification(senderId);
      }
    } catch (e) {
      debugPrint(
        '❌ [ChatList] Error refreshing notification count for $senderId: $e',
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Refresh chat list when app comes back to foreground or page becomes visible
    if (state == AppLifecycleState.resumed) {
      ref.read(chatListNotifierProvider.notifier).refreshContacts();
      _loadNotificationCounts(); // Reload notification counts
      _prefetchAvatarsIfOnline();
    }
  }

  Future<void> _prefetchAvatarsIfOnline() async {
    if (_avatarPrefetchInProgress) return;
    final online = ref
        .read(internetStatusStreamProvider)
        .maybeWhen(data: (v) => v, orElse: () => false);
    if (!online) return;
    final now = DateTime.now();
    if (_lastAvatarPrefetch != null &&
        now.difference(_lastAvatarPrefetch!) < const Duration(minutes: 15)) {
      return;
    }
    _avatarPrefetchInProgress = true;
    try {
      final chatState = ref.read(chatListNotifierProvider);
      if (chatState.contacts.isEmpty) return;

      // Get contacts list for profile picture merging
      final allContacts = ref.read(contactsListProvider);

      final maxCount = 30;
      int count = 0;
      for (final contact in chatState.contacts) {
        if (count >= maxCount) break;

        // Merge profile picture from contacts table (same as display logic)
        final ContactLocal? matchedContact =
            ContactDisplayNameHelper.findByUserIdOrPhone(
              contacts: allContacts,
              userId: contact.user.id,
              mobileNo: contact.user.mobileNo,
            );

        final chatPictureUrl =
            contact.user.chatPictureUrl ??
            matchedContact?.userDetails?.chatPictureUrl;
        final chatPictureVersion =
            matchedContact?.userDetails?.chatPictureVersion;

        if (chatPictureUrl == null || chatPictureUrl.isEmpty) continue;
        final base = chatPictureUrl.startsWith('http')
            ? chatPictureUrl
            : '${ApiUrls.mediaBaseUrl}$chatPictureUrl';

        String fullUrl;
        if (chatPictureVersion == null || chatPictureVersion.trim().isEmpty) {
          fullUrl = base;
        } else {
          try {
            final uri = Uri.parse(base);
            final params = Map<String, String>.from(uri.queryParameters);
            params['v'] = chatPictureVersion;
            fullUrl = uri.replace(queryParameters: params).toString();
          } catch (_) {
            final sep = base.contains('?') ? '&' : '?';
            fullUrl = '$base${sep}v=$chatPictureVersion';
          }
        }
        try {
          final urlsToPrefetch = <String>[fullUrl];
          if (base != fullUrl) {
            urlsToPrefetch.add(base);
          }

          for (final url in urlsToPrefetch) {
            final cached = await AuthenticatedImageCacheManager.instance
                .getFileFromCache(url);
            if (cached?.file == null) {
              await AuthenticatedImageCacheManager.instance.getSingleFile(url);
            }
          }

          count++;
        } catch (_) {
          // ignore
        }
      }
    } finally {
      _lastAvatarPrefetch = DateTime.now();
      _avatarPrefetchInProgress = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.removeListener(_filterChats);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _hybridNewMessageSub?.cancel();
    _profileUpdateSub?.cancel();
    _messageStatusSub?.cancel();
    super.dispose();
  }

  void _filterChats() {
    // Trigger rebuild; filtered results are derived from the latest stream data
    // inside the StreamBuilder to keep search and main list in sync.
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayoutBuilder(
      builder: (context, constraints, breakpoint) {
        final responsive = ResponsiveSize(
          context: context,
          constraints: constraints,
          breakpoint: breakpoint,
        );
        final bottomPadding = MediaQuery.of(context).padding.bottom;

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            if (_isSearching) {
              if (_searchController.text.isNotEmpty) {
                setState(() => _searchController.clear());
              } else {
                setState(() => _isSearching = false);
              }
            } else {
              SystemNavigator.pop();
            }
          },
          child: Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            resizeToAvoidBottomInset: false,
            body: MediaQuery.removeViewInsets(
              removeBottom: true,
              context: context,
              child: Stack(
                children: [
                  _buildBodyWithHeader(responsive),
                  if (!_isSearching && _isSpeedDialOpen)
                    SpeedDialButtonsOverlay(
                      responsive: responsive,
                      bottomPadding: bottomPadding,
                      onClose: () => setState(() => _isSpeedDialOpen = false),
                    ),
                  if (!_isSearching)
                    SpeedDialFabWidget(
                      responsive: responsive,
                      bottomPadding: bottomPadding,
                      isOpen: _isSpeedDialOpen,
                      onToggle: () =>
                          setState(() => _isSpeedDialOpen = !_isSpeedDialOpen),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Public method: enter search mode (called from MainNavigationPage)
  void startSearch() {
    if (!mounted) return;
    setState(() {
      _isSearching = true;
    });
    _searchFocusNode.requestFocus();
  }

  /// Public method: exit search mode
  void stopSearch() {
    if (!mounted) return;
    setState(() {
      _searchController.clear();
      _isSearching = false;
    });
  }

  /// Public method: clear search text
  void clearSearch() {
    if (!mounted) return;
    setState(() {
      _searchController.clear();
    });
  }

  /// Whether search mode is active (read by MainNavigationPage)
  bool get isSearching => _isSearching;

  Widget _buildBodyWithHeader(ResponsiveSize responsive) {
    // Watch chat list state from provider (for loading/error states)
    final chatState = ref.watch(chatListNotifierProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      top: false,
      child: Column(
        children: [
          // ── Messages header with search ──
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: responsive.spacing(16),
              vertical: responsive.spacing(6),
            ),
            child: _isSearching
                ? Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          autofocus: true,
                          style: AppTextSizes.regular(context).copyWith(
                            color: isDark ? Colors.white : AppColors.colorBlack,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search chats...',
                            hintStyle: AppTextSizes.regular(context).copyWith(
                              color: isDark
                                  ? Colors.white38
                                  : AppColors.colorGrey,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            focusedErrorBorder: InputBorder.none,
                            filled: false,
                            contentPadding: EdgeInsets.symmetric(
                              vertical: responsive.spacing(8),
                            ),
                            isDense: true,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _searchController.clear();
                            _isSearching = false;
                          });
                        },
                        child: Icon(
                          Icons.close,
                          size: responsive.size(22),
                          color: isDark ? Colors.white54 : AppColors.colorGrey,
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Messages',
                        style: AppTextSizes.regular(context).copyWith(
                          color: isDark ? Colors.white70 : AppColors.colorGrey,
                          fontWeight: FontWeight.w600,
                          fontSize: responsive.size(19),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() => _isSearching = true);
                          _searchFocusNode.requestFocus();
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Search',
                              style: AppTextSizes.regular(context).copyWith(
                                color: isDark
                                    ? Colors.white38
                                    : AppColors.colorGrey.withAlpha(
                                        (0.6 * 255).round(),
                                      ),
                                fontSize: responsive.size(14),
                              ),
                            ),
                            SizedBox(width: responsive.spacing(4)),
                            Icon(
                              Icons.manage_search,
                              size: responsive.size(24),
                              color: isDark
                                  ? Colors.white54
                                  : AppColors.colorGrey,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
          Expanded(
            // WHATSAPP-STYLE: StreamBuilder for real-time reactive updates
            // ChatListStream is the single source of truth
            child: StreamBuilder<List<ChatContactModel>>(
              stream: ChatListStream.instance.stream,
              initialData: ChatListStream.instance.currentList.isNotEmpty
                  ? ChatListStream.instance.currentList
                  : chatState.contacts,
              builder: (context, snapshot) {
                // Use stream data if available, fallback to provider
                final streamData = snapshot.data ?? [];
                final baseData = streamData.isNotEmpty
                    ? streamData
                    : chatState.contacts;

                final searchText = _searchController.text.toLowerCase();
                final filteredData = searchText.isEmpty
                    ? baseData
                    : baseData.where((contact) {
                        final name =
                            '${contact.user.firstName} ${contact.user.lastName}'
                                .toLowerCase();
                        return name.contains(searchText);
                      }).toList();

                final data = _isSearching ? filteredData : baseData;

                if (chatState.error != null) {
                  return ChatListErrorState(
                    responsive: responsive,
                    errorMessage: chatState.error!,
                  );
                }

                if (data.isNotEmpty) {
                  return ListView.builder(
                    padding: EdgeInsets.only(
                      top: responsive.spacing(4),
                      bottom: responsive.spacing(110),
                    ),
                    itemCount: data.length,
                    itemBuilder: (context, index) {
                      return ChatListTileWidget(
                        contact: data[index],
                        currentUserId: _currentUserId,
                        responsive: responsive,
                        onAvatarTap:
                            (
                              name,
                              contactId,
                              mobileNumber,
                              chatPictureUrl,
                              chatPictureVersion,
                            ) {
                              _showContactQuickActionsSheet(
                                context: context,
                                name: name,
                                contactId: contactId,
                                mobileNumber: mobileNumber,
                                chatPictureUrl: chatPictureUrl,
                                chatPictureVersion: chatPictureVersion,
                              );
                            },
                        onNavigateBack: () async {
                          if (mounted) {
                            ref
                                .read(chatListNotifierProvider.notifier)
                                .forceRefreshContacts();
                            await _loadNotificationCounts();
                          }
                        },
                      );
                    },
                  );
                }

                if (chatState.loading) {
                  return Center(
                    child: SizedBox(
                      width: responsive.size(28),
                      height: responsive.size(28),
                      child: CircularProgressIndicator(
                        strokeWidth: responsive.size(2.5),
                        color: AppColors.primary,
                      ),
                    ),
                  );
                }

                return _isSearching
                    ? ChatListNoSearchResults(responsive: responsive)
                    : ChatListEmptyState(responsive: responsive);
              },
            ),
          ),
        ],
      ),
    );
  }
}
