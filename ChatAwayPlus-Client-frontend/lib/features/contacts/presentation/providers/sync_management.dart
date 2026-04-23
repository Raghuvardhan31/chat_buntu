import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/contacts_repository.dart';
import '../../../../core/isolates/contact_sync_isolate.dart';
import 'shared_providers.dart';

/// State class for contact synchronization operations
/// Handles sync status, timing, and statistics
class ContactsSyncState {
  static const _undefined = Object();

  final bool isLoading;
  final String? error;
  final DateTime? lastSyncTime;
  final int totalContacts;
  final int registeredContacts;
  final int nonRegisteredContacts;
  final bool hasError;

  const ContactsSyncState({
    this.isLoading = false,
    this.error,
    this.lastSyncTime,
    this.totalContacts = 0,
    this.registeredContacts = 0,
    this.nonRegisteredContacts = 0,
  }) : hasError = error != null;

  ContactsSyncState copyWith({
    bool? isLoading,
    Object? error = _undefined,
    DateTime? lastSyncTime,
    int? totalContacts,
    int? registeredContacts,
    int? nonRegisteredContacts,
  }) {
    return ContactsSyncState(
      isLoading: isLoading ?? this.isLoading,
      error: identical(error, _undefined) ? this.error : error as String?,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      totalContacts: totalContacts ?? this.totalContacts,
      registeredContacts: registeredContacts ?? this.registeredContacts,
      nonRegisteredContacts:
          nonRegisteredContacts ?? this.nonRegisteredContacts,
    );
  }

  /// Get sync status as a readable string
  String get syncStatus {
    if (isLoading) return 'Syncing...';
    if (hasError) return 'Sync failed';
    if (lastSyncTime == null) return 'Never synced';
    return 'Last synced: ${_formatSyncTime()}';
  }

  /// Format sync time for display
  String _formatSyncTime() {
    if (lastSyncTime == null) return 'Never';

    final now = DateTime.now();
    final difference = now.difference(lastSyncTime!);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  /// Get sync statistics summary
  String get syncSummary {
    if (totalContacts == 0) return 'No contacts';
    return '$totalContacts total ($registeredContacts app users, $nonRegisteredContacts others)';
  }

  @override
  String toString() {
    return 'ContactsSyncState(isLoading: $isLoading, error: $error, lastSyncTime: $lastSyncTime, totalContacts: $totalContacts, registeredContacts: $registeredContacts, nonRegisteredContacts: $nonRegisteredContacts)';
  }
}

/// Notifier for contact synchronization operations
/// Handles: API sync, device fetch, background updates, cache management
class ContactsSyncNotifier extends StateNotifier<ContactsSyncState> {
  final ContactsRepository _repository;

  // Fetching state
  bool _isFetching = false;

  ContactsSyncNotifier({required ContactsRepository repository})
    : _repository = repository,
      super(const ContactsSyncState());

  //=================================================================
  // API SYNC AND DEVICE FETCH METHODS
  //=================================================================

  /// Fetch contacts after OTP verification
  Future<bool> fetchContactsAfterVerification() async {
    if (_isFetching) {
      debugPrint(
        '?s??,? [ContactsSync] Already fetching contacts, skipping...',
      );
      return false;
    }

    _isFetching = true;
    state = state.copyWith(isLoading: true, error: null);

    try {
      debugPrint(
        'dYZ+ [ContactsSync] Starting OTP verification contact sync...',
      );
      int attempts = 0;
      bool success = false;

      // Attempt contact sync with retries
      while (attempts < 3 && !success) {
        attempts++;
        try {
          debugPrint(
            'dY", [ContactsSync] Attempting contact sync (attempt $attempts/3)...',
          );

          // Clear existing cache first
          await clearCache();
          debugPrint('dY-`?,? [ContactsSync] Cache cleared');

          // Use isolate for heavy contact sync operations
          debugPrint('dY"? [ContactsSync] Using isolate for contact sync...');
          final isolateHandler = ContactSyncIsolateHandler();
          final syncResponse = await isolateHandler.syncContacts();

          debugPrint(
            'dY"S [ContactsSync] Sync result: ${syncResponse.totalContacts} total, ${syncResponse.appUsers} registered',
          );

          // Update state with sync results
          state = state.copyWith(
            isLoading: false,
            lastSyncTime: DateTime.now(),
            totalContacts: syncResponse.totalContacts ?? 0,
            registeredContacts: syncResponse.appUsers ?? 0,
            nonRegisteredContacts: syncResponse.regularContacts ?? 0,
          );

          success = true;
          debugPrint('?o. [ContactsSync] Contact sync successful!');

          // Initialize profile sync timestamp after successful initial sync
          await _repository.initializeProfileSyncTime();
          debugPrint('✅ [ContactsSync] Profile sync timestamp initialized');
        } catch (innerError) {
          debugPrint(
            '??O [ContactsSync] Contact sync attempt $attempts failed: $innerError',
          );
          if (attempts >= 3) {
            state = state.copyWith(
              isLoading: false,
              error:
                  'Failed to sync contacts after $attempts attempts: $innerError',
            );
            rethrow;
          }
          await Future.delayed(const Duration(seconds: 2));
        }
      }

      debugPrint(
        'dYZ% [ContactsSync] Contacts synced successfully with ${success ? 'success' : 'failure'}',
      );
      return success;
    } catch (e) {
      debugPrint('[ContactsSync] Error during contact sync: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Critical error during contact sync: $e',
      );
      return false;
    } finally {
      _isFetching = false;
    }
  }

  /// Simplified fetch contacts method
  Future<void> fetchContacts({bool refresh = false}) async {
    if (_isFetching && !refresh) {
      debugPrint(
        '?s??,? [ContactsSync] Already fetching contacts, skipping...',
      );
      return;
    }

    _isFetching = true;
    state = state.copyWith(isLoading: true, error: null);

    try {
      debugPrint(
        'dY"? [ContactsSync] Fetching contacts (refresh: $refresh)...',
      );

      final isolateHandler = ContactSyncIsolateHandler();
      final syncResponse = await isolateHandler.syncContacts();

      state = state.copyWith(
        isLoading: false,
        lastSyncTime: DateTime.now(),
        totalContacts: syncResponse.totalContacts ?? 0,
        registeredContacts: syncResponse.appUsers ?? 0,
        nonRegisteredContacts: syncResponse.regularContacts ?? 0,
      );

      debugPrint('✅ [ContactsSync] Contacts fetched successfully');
    } catch (e) {
      debugPrint('[ContactsSync] Error fetching contacts: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to fetch contacts: $e',
      );
    } finally {
      _isFetching = false;
    }
  }

  /// Handle user-initiated manual refresh
  Future<Map<String, dynamic>> userManualRefresh() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      debugPrint('dY", [ContactsSync] User initiated manual refresh...');

      final isolateHandler = ContactSyncIsolateHandler();
      final syncResponse = await isolateHandler.syncContacts();

      state = state.copyWith(
        isLoading: false,
        lastSyncTime: DateTime.now(),
        totalContacts: syncResponse.totalContacts ?? 0,
        registeredContacts: syncResponse.appUsers ?? 0,
        nonRegisteredContacts: syncResponse.regularContacts ?? 0,
      );

      debugPrint('?o. [ContactsSync] Manual refresh completed successfully');
      debugPrint(
        'dY"S [ContactsSync] Results: ${syncResponse.totalContacts} total, ${syncResponse.appUsers} registered',
      );

      return {
        'success': syncResponse.success,
        'totalContacts': syncResponse.totalContacts,
        'registeredContacts': syncResponse.appUsers,
        'nonRegisteredContacts': syncResponse.regularContacts,
        'error': syncResponse.error,
        'message': syncResponse.success
            ? 'Manual refresh completed successfully'
            : 'Manual refresh failed',
      };
    } catch (e) {
      debugPrint('[ContactsSync] Error during manual refresh: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Manual refresh failed: $e',
      );

      return {
        'success': false,
        'error': e.toString(),
        'message': 'Manual refresh failed',
      };
    }
  }

  //=================================================================
  // CACHE MANAGEMENT METHODS
  //=================================================================

  /// Clear contacts cache
  Future<void> clearCache() async {
    try {
      await _repository.clearCache();
      debugPrint('?o. [ContactsSync] Cache cleared successfully');

      // Reset sync state
      state = state.copyWith(
        totalContacts: 0,
        registeredContacts: 0,
        nonRegisteredContacts: 0,
        lastSyncTime: null,
      );
    } catch (e) {
      debugPrint('[ContactsSync] Error clearing cache: $e');
      state = state.copyWith(error: 'Failed to clear cache: $e');
    }
  }

  /// Get cache statistics for debugging
  Future<Map<String, dynamic>> getCacheStatistics() async {
    try {
      return await _repository.getCacheStatistics();
    } catch (e) {
      debugPrint('??O [ContactsSync] Error getting cache statistics: $e');
      return {'error': e.toString()};
    }
  }

  /// Log cache contents for debugging
  Future<void> logCacheContents() async {
    try {
      await _repository.logCacheContents();
    } catch (e) {
      debugPrint('??O [ContactsSync] Error logging cache contents: $e');
    }
  }

  //=================================================================
  // UTILITY METHODS
  //=================================================================

  /// Check if currently syncing
  bool get isSyncing => _isFetching || state.isLoading;

  /// Get last sync time
  DateTime? get lastSyncTime => state.lastSyncTime;

  /// Get sync statistics
  Map<String, int> get syncStatistics => {
    'total': state.totalContacts,
    'registered': state.registeredContacts,
    'nonRegistered': state.nonRegisteredContacts,
  };
}

/// Provider for the contacts sync notifier
final contactsSyncNotifierProvider =
    StateNotifierProvider<ContactsSyncNotifier, ContactsSyncState>((ref) {
      final contactsRepository = ref.watch(contactsRepositoryProvider);
      return ContactsSyncNotifier(repository: contactsRepository);
    });

/// Provider to check if currently syncing
final isSyncingProvider = Provider<bool>((ref) {
  final syncState = ref.watch(contactsSyncNotifierProvider);
  return syncState.isLoading;
});

/// Provider to get last sync time
final lastSyncTimeProvider = Provider<DateTime?>((ref) {
  final syncState = ref.watch(contactsSyncNotifierProvider);
  return syncState.lastSyncTime;
});

/// Provider to get sync status string
final syncStatusProvider = Provider<String>((ref) {
  final syncState = ref.watch(contactsSyncNotifierProvider);
  return syncState.syncStatus;
});

/// Provider to get sync statistics
final syncStatisticsProvider = Provider<Map<String, int>>((ref) {
  final syncState = ref.watch(contactsSyncNotifierProvider);
  return {
    'total': syncState.totalContacts,
    'registered': syncState.registeredContacts,
    'nonRegistered': syncState.nonRegisteredContacts,
  };
});

/// Provider to get sync summary string
final syncSummaryProvider = Provider<String>((ref) {
  final syncState = ref.watch(contactsSyncNotifierProvider);
  return syncState.syncSummary;
});
