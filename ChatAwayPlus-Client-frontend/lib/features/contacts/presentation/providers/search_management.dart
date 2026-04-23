import 'dart:async';

import '../../data/models/contact_local.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/contacts_repository.dart';
import 'shared_providers.dart';

/// Enum for contact filter types
enum ContactFilterType { all, registered, nonRegistered }

/// Enum for contact sort types
enum ContactSortType { nameAsc, nameDesc, recentFirst, oldestFirst }

/// State class for contact search and filtering operations
/// Handles search query, results, filters, and sorting
class ContactsSearchState {
  final String query;
  final bool isSearching;
  final List<ContactLocal> searchResults;
  final int resultCount;
  final String? error;
  final ContactFilterType activeFilter;
  final ContactSortType activeSortType;

  const ContactsSearchState({
    this.query = '',
    this.isSearching = false,
    this.searchResults = const [],
    this.resultCount = 0,
    this.error,
    this.activeFilter = ContactFilterType.all,
    this.activeSortType = ContactSortType.nameAsc,
  });

  ContactsSearchState copyWith({
    String? query,
    bool? isSearching,
    List<ContactLocal>? searchResults,
    int? resultCount,
    String? error,
    ContactFilterType? activeFilter,
    ContactSortType? activeSortType,
  }) {
    return ContactsSearchState(
      query: query ?? this.query,
      isSearching: isSearching ?? this.isSearching,
      searchResults: searchResults ?? this.searchResults,
      resultCount: resultCount ?? this.resultCount,
      error: error,
      activeFilter: activeFilter ?? this.activeFilter,
      activeSortType: activeSortType ?? this.activeSortType,
    );
  }

  /// Check if search is active (has query)
  bool get hasActiveSearch => query.isNotEmpty;

  /// Check if any filter is applied
  bool get hasActiveFilter => activeFilter != ContactFilterType.all;

  /// Get filter display name
  String get filterDisplayName {
    switch (activeFilter) {
      case ContactFilterType.all:
        return 'All Contacts';
      case ContactFilterType.registered:
        return 'App Users';
      case ContactFilterType.nonRegistered:
        return 'Other Contacts';
    }
  }

  /// Get sort display name
  String get sortDisplayName {
    switch (activeSortType) {
      case ContactSortType.nameAsc:
        return 'Name (A-Z)';
      case ContactSortType.nameDesc:
        return 'Name (Z-A)';
      case ContactSortType.recentFirst:
        return 'Recently Added';
      case ContactSortType.oldestFirst:
        return 'Oldest First';
    }
  }

  /// Get search status message
  String get searchStatusMessage {
    if (isSearching) {
      return 'Searching...';
    }

    if (error != null) {
      return 'Search failed';
    }

    if (hasActiveSearch) {
      return 'Found $resultCount results for "$query"';
    }

    if (hasActiveFilter) {
      return 'Showing $resultCount ${filterDisplayName.toLowerCase()}';
    }

    return 'Showing $resultCount contacts';
  }

  /// Get registered contacts from search results
  List<ContactLocal> get registeredResults {
    return searchResults.where((contact) => contact.isRegistered).toList();
  }

  /// Get non-registered contacts from search results
  List<ContactLocal> get nonRegisteredResults {
    return searchResults.where((contact) => !contact.isRegistered).toList();
  }

  @override
  String toString() {
    return 'ContactsSearchState(query: "$query", isSearching: $isSearching, resultCount: $resultCount, activeFilter: ${activeFilter.name}, activeSortType: ${activeSortType.name})';
  }
}

/// Notifier for contact search and filtering operations
/// Handles: search, filter, sort contacts with debouncing
class ContactsSearchNotifier extends StateNotifier<ContactsSearchState> {
  final ContactsRepository _repository;

  // Debounce timer for search
  Timer? _searchDebounce;

  ContactsSearchNotifier({required ContactsRepository repository})
    : _repository = repository,
      super(const ContactsSearchState());

  //=================================================================
  // SEARCH METHODS
  //=================================================================

  /// Search contacts by name or number with debouncing
  Future<void> searchContacts(String query) async {
    // Cancel previous search timer
    _searchDebounce?.cancel();

    // Update state immediately with new query
    state = state.copyWith(query: query, isSearching: true);

    // Debounce the actual search
    _searchDebounce = Timer(const Duration(milliseconds: 300), () async {
      await _performSearch(query);
    });
  }

  /// Perform the actual search operation
  Future<void> _performSearch(String query) async {
    try {
      debugPrint(
        'dY"? [ContactsSearch] Searching contacts with query: "$query"',
      );

      // Get all contacts from repository
      final allContacts = await _repository.loadAllContacts();

      List<ContactLocal> filteredContacts;

      if (query.isEmpty) {
        // If query is empty, return all contacts
        filteredContacts = allContacts;
      } else {
        // Filter contacts based on query
        filteredContacts = _filterContacts(allContacts, query);
      }

      // Update state with search results
      state = state.copyWith(
        isSearching: false,
        searchResults: filteredContacts,
        resultCount: filteredContacts.length,
      );

      debugPrint(
        '?o. [ContactsSearch] Search completed, found ${filteredContacts.length} contacts',
      );
    } catch (e) {
      debugPrint('??O [ContactsSearch] Error searching contacts: $e');
      state = state.copyWith(isSearching: false, error: 'Search failed: $e');
    }
  }

  /// Filter contacts based on search query
  List<ContactLocal> _filterContacts(
    List<ContactLocal> contacts,
    String query,
  ) {
    final lowercaseQuery = query.toLowerCase();

    return contacts.where((contact) {
      // Search in contact name
      final nameMatch = contact.preferredDisplayName.toLowerCase().contains(
        lowercaseQuery,
      );

      // Search in mobile number
      final numberMatch = contact.mobileNo.contains(query);

      // Search in display name from user details (if available)
      final displayNameMatch =
          contact.userDetails?.appdisplayName.toLowerCase().contains(
            lowercaseQuery,
          ) ??
          false;

      return nameMatch || numberMatch || displayNameMatch;
    }).toList();
  }

  //=================================================================
  // FILTER METHODS
  //=================================================================

  /// Filter contacts by registration status
  Future<void> filterByRegistrationStatus(ContactFilterType filterType) async {
    state = state.copyWith(isSearching: true, activeFilter: filterType);

    try {
      List<ContactLocal> filteredContacts;

      switch (filterType) {
        case ContactFilterType.all:
          filteredContacts = await _repository.loadAllContacts();
          break;
        case ContactFilterType.registered:
          filteredContacts = await _repository.loadRegisteredContacts();
          break;
        case ContactFilterType.nonRegistered:
          filteredContacts = await _repository.loadNonRegisteredContacts();
          break;
      }

      // Apply current search query if any
      if (state.query.isNotEmpty) {
        filteredContacts = _filterContacts(filteredContacts, state.query);
      }

      state = state.copyWith(
        isSearching: false,
        searchResults: filteredContacts,
        resultCount: filteredContacts.length,
      );

      debugPrint(
        '?o. [ContactsSearch] Filter applied: ${filterType.name}, found ${filteredContacts.length} contacts',
      );
    } catch (e) {
      debugPrint('??O [ContactsSearch] Error filtering contacts: $e');
      state = state.copyWith(isSearching: false, error: 'Filter failed: $e');
    }
  }

  //=================================================================
  // SORT METHODS
  //=================================================================

  /// Sort contacts by specified criteria
  void sortContacts(ContactSortType sortType) {
    final currentResults = List<ContactLocal>.from(state.searchResults);

    switch (sortType) {
      case ContactSortType.nameAsc:
        currentResults.sort(
          (a, b) => a.preferredDisplayName.compareTo(b.preferredDisplayName),
        );
        break;
      case ContactSortType.nameDesc:
        currentResults.sort(
          (a, b) => b.preferredDisplayName.compareTo(a.preferredDisplayName),
        );
        break;
      case ContactSortType.recentFirst:
        currentResults.sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));
        break;
      case ContactSortType.oldestFirst:
        currentResults.sort((a, b) => a.lastUpdated.compareTo(b.lastUpdated));
        break;
    }

    state = state.copyWith(
      searchResults: currentResults,
      activeSortType: sortType,
    );

    debugPrint('?o. [ContactsSearch] Contacts sorted by: ${sortType.name}');
  }

  //=================================================================
  // UTILITY METHODS
  //=================================================================

  /// Clear search and reset to all contacts
  Future<void> clearSearch() async {
    _searchDebounce?.cancel();

    state = state.copyWith(
      query: '',
      isSearching: true,
      activeFilter: ContactFilterType.all,
      activeSortType: ContactSortType.nameAsc,
    );

    // Load all contacts
    await filterByRegistrationStatus(ContactFilterType.all);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }
}

/// Provider for the contacts search notifier
final contactsSearchNotifierProvider =
    StateNotifierProvider<ContactsSearchNotifier, ContactsSearchState>((ref) {
      final contactsRepository = ref.watch(contactsRepositoryProvider);
      return ContactsSearchNotifier(repository: contactsRepository);
    });

/// Provider to get search results
final searchResultsProvider = Provider<List<ContactLocal>>((ref) {
  final searchState = ref.watch(contactsSearchNotifierProvider);
  return searchState.searchResults;
});

/// Provider to get registered search results
final registeredSearchResultsProvider = Provider<List<ContactLocal>>((ref) {
  final searchState = ref.watch(contactsSearchNotifierProvider);
  return searchState.registeredResults;
});

/// Provider to get non-registered search results
final nonRegisteredSearchResultsProvider = Provider<List<ContactLocal>>((ref) {
  final searchState = ref.watch(contactsSearchNotifierProvider);
  return searchState.nonRegisteredResults;
});

/// Provider to check if currently searching
final isSearchingProvider = Provider<bool>((ref) {
  final searchState = ref.watch(contactsSearchNotifierProvider);
  return searchState.isSearching;
});

/// Provider to get current search query
final searchQueryProvider = Provider<String>((ref) {
  final searchState = ref.watch(contactsSearchNotifierProvider);
  return searchState.query;
});

/// Provider to get search status message
final searchStatusProvider = Provider<String>((ref) {
  final searchState = ref.watch(contactsSearchNotifierProvider);
  return searchState.searchStatusMessage;
});

/// Provider to get active filter type
final activeFilterProvider = Provider<ContactFilterType>((ref) {
  final searchState = ref.watch(contactsSearchNotifierProvider);
  return searchState.activeFilter;
});

/// Provider to get active sort type
final activeSortTypeProvider = Provider<ContactSortType>((ref) {
  final searchState = ref.watch(contactsSearchNotifierProvider);
  return searchState.activeSortType;
});

/// Provider to check if search has active query
final hasActiveSearchProvider = Provider<bool>((ref) {
  final searchState = ref.watch(contactsSearchNotifierProvider);
  return searchState.hasActiveSearch;
});

/// Provider to check if filter is applied
final hasActiveFilterProvider = Provider<bool>((ref) {
  final searchState = ref.watch(contactsSearchNotifierProvider);
  return searchState.hasActiveFilter;
});
