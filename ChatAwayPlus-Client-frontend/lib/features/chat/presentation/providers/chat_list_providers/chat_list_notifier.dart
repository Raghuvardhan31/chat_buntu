// lib/features/chat/presentation/providers/chat_list_providers/chat_list_notifier.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'chat_list_state.dart';
import '../../../data/cache/chat_list_cache.dart';
import 'chat_list_stream.dart';
import '../../../data/datasources/chat_local_datasource.dart';
import '../../../models/chat_message_model.dart';
import '../../../data/repositories/chat_repository.dart';

/// Notifier for managing chat list state
class ChatListNotifier extends StateNotifier<ChatListState> {
  final ChatLocalDataSource _localDataSource;
  final ChatRepository _chatRepository;

  static const bool _verboseLogs = false;

  void _safeSetState(ChatListState newState) {
    if (mounted) state = newState;
  }

  // Track last load time to prevent duplicate loads
  DateTime? _lastLoadTime;
  static const _debounceWindow = Duration(seconds: 3);
  static const _contactsServerTtl = Duration(minutes: 5);

  bool _restFetchInProgress = false;
  bool _loadInProgress = false;

  ChatListNotifier(this._localDataSource, this._chatRepository)
    : super(const ChatListState(loading: true));

  /// Load chat contacts - Fetches from backend API with local fallback
  Future<void> loadContacts({
    bool force = false,
    bool bypassMemoryCache = false,
  }) async {
    if (state.loading && state.contacts.isNotEmpty) return;

    if (_loadInProgress) return;

    // DEBOUNCE: Skip if last load was too recent (within 3 seconds)
    if (!force && !bypassMemoryCache && _lastLoadTime != null) {
      final timeSinceLastLoad = DateTime.now().difference(_lastLoadTime!);
      if (timeSinceLastLoad < _debounceWindow) {
        return;
      }
    }

    if (_verboseLogs && kDebugMode) {
      debugPrint('ChatListNotifier: Loading chat contacts (force=$force)');
    }

    // Update last load time
    _lastLoadTime = DateTime.now();

    _loadInProgress = true;

    try {
      // WHATSAPP-STYLE: Check memory cache FIRST (instant, no DB query)
      final cachedInMemory = (!force && !bypassMemoryCache)
          ? ChatListCache.instance.contacts
          : null;
      final hasMemoryCache =
          cachedInMemory != null && cachedInMemory.isNotEmpty;

      // If we have nothing to render yet, mark loading immediately.
      // This avoids showing the empty state while we await the first local DB read.
      if (!hasMemoryCache && state.contacts.isEmpty) {
        _safeSetState(state.copyWith(loading: true, error: null));
      }

      if (hasMemoryCache) {
        if (_verboseLogs && kDebugMode) {
          debugPrint(
            '⚡ [CACHE] ChatList: Using MEMORY CACHE (${cachedInMemory.length} contacts)',
          );
        }
        _safeSetState(
          state.copyWith(loading: false, contacts: cachedInMemory, error: null),
        );
      }

      // DB-first: show local data ASAP so UI can render without waiting for REST.
      List<ChatContactModel> cachedLocal = const [];
      if (!hasMemoryCache || bypassMemoryCache) {
        if (!bypassMemoryCache) {
          await ChatListCache.instance.preload();
          final cachedAfterPreload = ChatListCache.instance.contacts;
          if (cachedAfterPreload != null && cachedAfterPreload.isNotEmpty) {
            _safeSetState(
              state.copyWith(
                loading: false,
                contacts: cachedAfterPreload,
                error: null,
              ),
            );
          }
        }

        final cachedAfterPreload = ChatListCache.instance.contacts;
        final hasFreshMemoryCache =
            cachedAfterPreload != null && cachedAfterPreload.isNotEmpty;

        if (hasFreshMemoryCache && !bypassMemoryCache) {
          if (state.loading) {
            _safeSetState(state.copyWith(loading: false));
          }
        } else {
          try {
            cachedLocal = await _localDataSource.getChatContactsFromLocal();
            if (_verboseLogs && kDebugMode) {
              debugPrint(
                'ChatListNotifier: Local DB size=${cachedLocal.length}',
              );
            }
          } catch (e) {
            if (_verboseLogs && kDebugMode) {
              debugPrint('ChatListNotifier: Local load failed: $e');
            }
          }

          if (cachedLocal.isNotEmpty) {
            ChatListCache.instance.cache(cachedLocal);
            ChatListStream.instance.syncFrom(cachedLocal);
            _safeSetState(
              state.copyWith(
                loading: false,
                contacts: cachedLocal,
                error: null,
              ),
            );
          } else if (!hasMemoryCache) {
            // Only show loading if we truly have nothing to render.
            _safeSetState(state.copyWith(loading: true, error: null));
          }
        }
      }

      // TTL-based REST refresh (WhatsApp-style): only when stale or forced.
      final shouldFetchFromServer =
          force ||
          !ChatListCache.instance.isServerSyncFresh(ttl: _contactsServerTtl);
      if (!shouldFetchFromServer) {
        if (_verboseLogs && kDebugMode) {
          debugPrint('⏳ ChatListNotifier: Skipping REST contacts (TTL fresh)');
        }
        if (state.loading) {
          _safeSetState(state.copyWith(loading: false));
        }
        return;
      }

      if (_restFetchInProgress) return;
      _restFetchInProgress = true;

      try {
        if (_verboseLogs && kDebugMode) {
          debugPrint(
            '🌐 [REMOTE] ChatList: Fetching from /api/mobile/chat/contacts',
          );
        }
        final result = await _chatRepository.getChatContacts();

        if (result.isSuccess && result.data != null) {
          List<ChatContactModel> contacts = result.data!.data ?? [];
          if (_verboseLogs && kDebugMode) {
            debugPrint(
              '✅ [REMOTE] ChatList: API returned ${contacts.length} contacts',
            );
          }

          final fallbackContacts = hasMemoryCache
              ? cachedInMemory
              : (cachedLocal.isNotEmpty ? cachedLocal : state.contacts);

          // If backend has no data but local has data, keep local data
          if (contacts.isEmpty && fallbackContacts.isNotEmpty) {
            if (_verboseLogs && kDebugMode) {
              debugPrint(
                '⚠️ ChatListNotifier: Backend empty, using local data',
              );
            }
            contacts = fallbackContacts;
          }

          if (contacts.isNotEmpty) {
            ChatListCache.instance.cacheFromServer(contacts);
            ChatListStream.instance.syncFrom(contacts);

            // Persist fresh server list for offline support (async)
            _localDataSource
                .saveChatContacts(contacts)
                .then((_) {
                  if (_verboseLogs && kDebugMode) {
                    debugPrint(
                      '💾 [LOCAL] ChatList: ${contacts.length} contacts saved to SQLite',
                    );
                  }
                })
                .catchError((e) {
                  if (_verboseLogs && kDebugMode) {
                    debugPrint(
                      '⚠️ ChatListNotifier: Failed to persist to local DB: $e',
                    );
                  }
                });
          }

          _safeSetState(
            state.copyWith(loading: false, contacts: contacts, error: null),
          );
        } else {
          debugPrint(
            '❌ [REMOTE] ChatList: API FAILED - ${result.errorMessage}',
          );
          final hasAny = state.contacts.isNotEmpty;
          _safeSetState(
            state.copyWith(
              loading: false,
              contacts: state.contacts,
              error: hasAny ? null : result.errorMessage,
            ),
          );
        }
      } catch (e) {
        debugPrint('❌ [REMOTE] ChatList: API EXCEPTION - $e');
        final hasAny = state.contacts.isNotEmpty;
        _safeSetState(
          state.copyWith(
            loading: false,
            contacts: state.contacts,
            error: hasAny ? null : 'An error occurred while loading contacts',
          ),
        );
      } finally {
        _restFetchInProgress = false;
      }
    } finally {
      _loadInProgress = false;
    }
  }

  /// Refresh contacts
  Future<void> refreshContacts() async {
    // DEBOUNCE: Skip if last load was too recent (within 3 seconds)
    if (_lastLoadTime != null) {
      final timeSinceLastLoad = DateTime.now().difference(_lastLoadTime!);
      if (timeSinceLastLoad < _debounceWindow) {
        if (_verboseLogs && kDebugMode) {
          debugPrint(
            'ChatListNotifier: Skipping refresh - last load was ${timeSinceLastLoad.inMilliseconds}ms ago '
            '(debounce: ${_debounceWindow.inSeconds}s)',
          );
        }
        return;
      }
    }

    if (_verboseLogs && kDebugMode) {
      debugPrint('ChatListNotifier: Refreshing contacts');
    }
    await loadContacts(force: false);
  }

  /// Force refresh contacts - bypasses debounce (use when returning from chat)
  /// This ensures message status ticks are always up-to-date
  Future<void> forceRefreshContacts({bool forceServer = false}) async {
    if (_verboseLogs && kDebugMode) {
      debugPrint(
        'ChatListNotifier: FORCE refreshing contacts (bypass debounce)',
      );
    }
    // Reset debounce timer
    _lastLoadTime = null;
    await loadContacts(force: forceServer, bypassMemoryCache: true);
  }

  // NOTE: Message status updates are now handled by ChatListStream (stream-based)
  // StreamBuilder in ChatListPage auto-rebuilds when ChatListStream emits
  // See: unified_chat_service.dart -> ChatListStream.instance.updateMessageStatus()

  /// Clear error message
  void clearError() {
    _safeSetState(state.copyWith(error: null));
  }
}
