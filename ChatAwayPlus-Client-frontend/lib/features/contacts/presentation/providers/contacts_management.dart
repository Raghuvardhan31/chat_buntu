import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/contact_local.dart';
import '../../data/repositories/contacts_repository.dart';
import 'shared_providers.dart';

/// State class for contact management operations
/// Handles contact list categorization and basic state management
class ContactsState {
  final List<ContactLocal> allContacts;
  final List<ContactLocal> registeredContacts;
  final List<ContactLocal> nonRegisteredContacts;
  final bool hasReachedMax;
  final bool isLoading;
  final String? error;
  final int currentPage;

  const ContactsState({
    List<ContactLocal>? allContacts,
    List<ContactLocal>? registeredContacts,
    List<ContactLocal>? nonRegisteredContacts,
    this.hasReachedMax = false,
    this.isLoading = false,
    this.error,
    this.currentPage = 0,
  }) : allContacts = allContacts ?? const [],
       registeredContacts = registeredContacts ?? const [],
       nonRegisteredContacts = nonRegisteredContacts ?? const [];

  // Getters for backward compatibility
  List<ContactLocal> get contacts => allContacts;
  List<ContactLocal> get appUsers => registeredContacts;
  List<ContactLocal> get nonAppUsers => nonRegisteredContacts;

  ContactsState copyWith({
    List<ContactLocal>? allContacts,
    List<ContactLocal>? registeredContacts,
    List<ContactLocal>? nonRegisteredContacts,
    bool? hasReachedMax,
    bool? isLoading,
    String? error,
    int? currentPage,
  }) {
    return ContactsState(
      allContacts: allContacts ?? this.allContacts,
      registeredContacts: registeredContacts ?? this.registeredContacts,
      nonRegisteredContacts:
          nonRegisteredContacts ?? this.nonRegisteredContacts,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      currentPage: currentPage ?? this.currentPage,
    );
  }

  /// Helper method to create a new state with updated contact lists
  /// Automatically categorizes contacts by registration status
  ContactsState withUpdatedContacts(List<ContactLocal> updatedContacts) {
    // Normalize and sort all contacts by name (A->Z), case-insensitive, then by mobile
    int compareContacts(ContactLocal a, ContactLocal b) {
      final an = a.name.trim().toLowerCase();
      final bn = b.name.trim().toLowerCase();
      final aIsAlpha = RegExp(r'^[a-z]').hasMatch(an);
      final bIsAlpha = RegExp(r'^[a-z]').hasMatch(bn);
      if (aIsAlpha != bIsAlpha) return aIsAlpha ? -1 : 1; // letters first
      final n = an.compareTo(bn);
      if (n != 0) return n;
      return a.mobileNo.compareTo(b.mobileNo);
    }

    final sortedAll = List<ContactLocal>.from(updatedContacts)
      ..sort(compareContacts);

    // Separate contacts by registration status (keeps sorted order)
    final registeredContacts = sortedAll.where((c) => c.isRegistered).toList();
    final nonRegisteredContacts = sortedAll
        .where((c) => !c.isRegistered)
        .toList();

    if (kDebugMode) {
      debugPrint(
        '[ContactsState] Categorizing ${updatedContacts.length} contacts:',
      );
      debugPrint('   - Registered (app users): ${registeredContacts.length}');
      debugPrint('   - Non-registered: ${nonRegisteredContacts.length}');
    }

    return copyWith(
      allContacts: sortedAll,
      registeredContacts: registeredContacts,
      nonRegisteredContacts: nonRegisteredContacts,
    );
  }

  @override
  String toString() {
    return 'ContactsState(allContacts: ${allContacts.length}, registeredContacts: ${registeredContacts.length}, nonRegisteredContacts: ${nonRegisteredContacts.length}, isLoading: $isLoading, error: $error)';
  }
}

/// Notifier for basic contact management operations
/// Handles: contact list, categorization, basic CRUD operations
class ContactsManagementNotifier
    extends StateNotifier<AsyncValue<ContactsState>> {
  final ContactsRepository _repository;

  Future<void>? _inFlightCacheLoad;

  ContactsManagementNotifier({required ContactsRepository repository})
    : _repository = repository,
      super(const AsyncValue.data(ContactsState())) {
    _initialize();
  }

  //=================================================================
  // INITIALIZATION AND CORE LOADING METHODS
  //=================================================================

  /// Initialize with cached data only (no device fetching)
  Future<void> _initialize() async {
    try {
      if (kDebugMode) {
        debugPrint(
          '[ContactsManagement] Initializing contacts from cache only...',
        );
      }

      // Set loading state
      state = const AsyncValue.loading();

      // Load contacts from cache
      await _loadFromCache();
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          '[ContactsManagement] Error initializing contacts notifier: $e',
        );
        debugPrint('Stack trace: $stackTrace');
      }

      // Set error state
      state = AsyncValue.error(e, stackTrace);
    }
  }

  /// Load contacts from cache only (no device fetching)
  Future<void> _loadFromCache() async {
    if (_inFlightCacheLoad != null) {
      await _inFlightCacheLoad;
      return;
    }

    final future = () async {
      try {
        final contacts = await _repository.loadAllContacts();

        try {
          await _persistContactNamesByUserId(contacts);
        } catch (_) {}

        // Update state with contacts from cache
        state = AsyncValue.data(ContactsState().withUpdatedContacts(contacts));
      } catch (e) {
        state = AsyncValue.error(e, StackTrace.current);
        rethrow;
      } finally {
        _inFlightCacheLoad = null;
      }
    }();

    _inFlightCacheLoad = future;
    await future;
  }

  Future<void> _persistContactNamesByUserId(List<ContactLocal> contacts) async {
    final map = <String, String>{};
    for (final c in contacts) {
      final id = c.appUserId;
      if (id == null || id.isEmpty) continue;

      final deviceName = c.name.trim();
      if (deviceName.isEmpty) continue;

      final appName = c.userDetails?.appdisplayName.trim() ?? '';
      final existing = map[id];

      if (existing == null || existing.isEmpty) {
        map[id] = deviceName;
        continue;
      }

      if (existing == deviceName) continue;

      if (appName.isNotEmpty) {
        if (existing == appName && deviceName != appName) {
          map[id] = deviceName;
        }
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('contact_name_map_by_user_id', jsonEncode(map));
  }

  /// Public method to load from cache
  Future<void> loadFromCache() async {
    await _loadFromCache();
  }

  /// Refresh contacts from cache
  Future<void> refreshContacts() async {
    if (kDebugMode) {
      debugPrint('[ContactsManagement] Refreshing contacts...');
    }
    try {
      await _loadFromCache();
      if (kDebugMode) {
        debugPrint('[ContactsManagement] Contacts refreshed successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ContactsManagement] Error refreshing contacts: $e');
      }
      state = state.whenData(
        (s) => s.copyWith(
          error: 'Failed to refresh contacts: $e',
          isLoading: false,
        ),
      );
    }
  }

  Future<void> refreshAppUsersStatusFromApi() async {
    try {
      if (kDebugMode) {
        debugPrint('[ContactsManagement] Checking app users status via API...');
      }
      await _repository.checkAppUsersStatusFromAPI();
      await _loadFromCache();
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          '[ContactsManagement] Error refreshing app users from API: $e',
        );
        debugPrint('Stack trace: $stackTrace');
      }
    }
  }

  //=================================================================
  // CONTACT RETRIEVAL METHODS
  //=================================================================

  /// Get a single contact by ID
  Future<ContactLocal?> getContactById(String contactHash) async {
    try {
      // First try from memory
      final currentState = state.valueOrNull;
      if (currentState != null) {
        try {
          return currentState.allContacts.firstWhere(
            (c) => c.contactHash == contactHash,
          );
        } catch (_) {
          if (kDebugMode) {
            debugPrint(
              '[ContactsManagement] Contact not found in memory, trying repository...',
            );
          }
        }
      }

      // Try from repository
      final contact = await _repository.findContactById(contactHash);
      if (contact != null) {
        if (kDebugMode) {
          debugPrint(
            '[ContactsManagement] Contact found in repository: ${contact.preferredDisplayName}',
          );
        }
        return contact;
      }

      if (kDebugMode) {
        debugPrint(
          '[ContactsManagement] Contact not found with ID: $contactHash',
        );
      }
      return null;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('[ContactsManagement] Error in getContactById: $e');
        debugPrint('Stack trace: $stackTrace');
      }
      return null;
    }
  }

  /// Find contact by mobile number
  Future<ContactLocal?> findContactByMobile(String mobileNo) async {
    try {
      return await _repository.findContactByMobile(mobileNo);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ContactsManagement] Error finding contact by mobile: $e');
      }
      return null;
    }
  }

  /// Load only non-registered contacts
  Future<void> loadNonRegisteredContacts() async {
    try {
      if (kDebugMode) {
        debugPrint('[ContactsManagement] Loading non-registered contacts...');
      }

      final contacts = await _repository.loadNonRegisteredContacts();

      // Update state with only non-registered contacts
      state = AsyncValue.data(ContactsState().withUpdatedContacts(contacts));

      if (kDebugMode) {
        debugPrint(
          '[ContactsManagement] Loaded ${contacts.length} non-registered contacts',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[ContactsManagement] Error loading non-registered contacts: $e',
        );
      }
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  /// Update contact registration status
  Future<void> updateContactRegistrationStatus(
    String contactHash,
    bool isRegistered,
  ) async {
    try {
      await _repository.updateContactRegistrationStatus(
        contactHash,
        isRegistered,
      );

      // Refresh the contacts list to reflect the change
      await _loadFromCache();

      if (kDebugMode) {
        debugPrint(
          '[ContactsManagement] Updated registration status for contact: $contactHash',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[ContactsManagement] Error updating contact registration status: $e',
        );
      }
    }
  }

  //=================================================================
  // GETTERS FOR CONTACT CATEGORIES
  //=================================================================

  /// Get all registered contacts (app users)
  List<ContactLocal> get appUserContacts {
    final currentState = state.valueOrNull;
    if (currentState == null) return [];
    return currentState.registeredContacts;
  }

  /// Get all non-registered contacts
  List<ContactLocal> get nonAppUserContacts {
    final currentState = state.valueOrNull;
    if (currentState == null) return [];
    return currentState.nonRegisteredContacts;
  }

  /// Get all contacts
  List<ContactLocal> get allContacts {
    final currentState = state.valueOrNull;
    if (currentState == null) return [];
    return currentState.allContacts;
  }
}

/// Provider for the contacts management notifier
final contactsManagementNotifierProvider =
    StateNotifierProvider<
      ContactsManagementNotifier,
      AsyncValue<ContactsState>
    >((ref) {
      final contactsRepository = ref.watch(contactsRepositoryProvider);
      return ContactsManagementNotifier(repository: contactsRepository);
    });

/// Provider to access the contacts list from state
final contactsListProvider = Provider<List<ContactLocal>>((ref) {
  final contactsState = ref.watch(contactsManagementNotifierProvider);
  return contactsState.when(
    data: (state) => state.allContacts,
    loading: () => [],
    error: (_, __) => [],
  );
});

/// Provider to access app user contacts from state
final appUserContactsProvider = Provider<List<ContactLocal>>((ref) {
  final contactsState = ref.watch(contactsManagementNotifierProvider);
  return contactsState.when(
    data: (state) => state.registeredContacts,
    loading: () => [],
    error: (_, __) => [],
  );
});

/// Provider to access non-app user contacts from state
final nonAppUserContactsProvider = Provider<List<ContactLocal>>((ref) {
  final contactsState = ref.watch(contactsManagementNotifierProvider);
  return contactsState.when(
    data: (state) => state.nonRegisteredContacts,
    loading: () => [],
    error: (_, __) => [],
  );
});

/// Provider to get a contact by ID
final contactByIdProvider = FutureProvider.family<ContactLocal?, String>((
  ref,
  contactHash,
) async {
  final notifier = ref.read(contactsManagementNotifierProvider.notifier);
  return notifier.getContactById(contactHash);
});
