import 'package:flutter/foundation.dart';
import 'package:chataway_plus/core/storage/token_storage.dart';
import '../datasources/contacts_database_service.dart';
import '../models/contact_local.dart';
import '../datasources/app_users_check_service.dart';
import '../datasources/device_contacts_service.dart';
import '../datasources/contacts_delta_sync_service.dart';
import '../datasources/profile_sync_storage.dart';

/// Repository for managing contacts using ContactLocal model
/// Handles both local database operations and API communication
class ContactsRepository {
  static final ContactsRepository _instance = ContactsRepository._internal();
  static ContactsRepository get instance => _instance;
  ContactsRepository._internal();

  final ContactsDatabaseService _contactsService =
      ContactsDatabaseService.instance;
  final AppUsersCheckService _appUsersCheckService = AppUsersCheckService();
  final DeviceContactsService _deviceContactsService = DeviceContactsService();
  final ContactsDeltaSyncService _deltaSyncService = ContactsDeltaSyncService();
  final ProfileSyncStorage _syncStorage = ProfileSyncStorage.instance;

  String _normalizePhone(String input) {
    final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length > 10 ? digits.substring(digits.length - 10) : digits;
  }

  Future<List<ContactLocal>> _excludeCurrentUser(
    List<ContactLocal> contacts,
  ) async {
    try {
      final currentUserPhone = await TokenSecureStorage.instance
          .getPhoneNumber();
      final currentUserIdRaw = await TokenSecureStorage.instance
          .getCurrentUserIdUUID();

      final currentUserId = (currentUserIdRaw ?? '').trim();

      final normalizedCurrentPhone = _normalizePhone(currentUserPhone ?? '');
      final hasPhone = normalizedCurrentPhone.isNotEmpty;
      final hasUserId = currentUserId.isNotEmpty;

      if (!hasPhone && !hasUserId) return contacts;

      return contacts.where((contact) {
        if (hasUserId) {
          final appUserId = contact.appUserId;
          final detailsUserId = contact.userDetails?.userId;
          if ((appUserId != null && appUserId == currentUserId) ||
              (detailsUserId != null && detailsUserId == currentUserId)) {
            return false;
          }
        }

        if (hasPhone) {
          final normalizedContactPhone = _normalizePhone(contact.mobileNo);
          if (normalizedContactPhone.isNotEmpty &&
              normalizedContactPhone == normalizedCurrentPhone) {
            return false;
          }
        }

        return true;
      }).toList();
    } catch (_) {
      return contacts;
    }
  }

  Future<ContactLocal?> refreshSingleContactFromApi({
    String? mobileNo,
    String? userId,
  }) async {
    try {
      if ((mobileNo == null || mobileNo.trim().isEmpty) &&
          (userId == null || userId.trim().isEmpty)) {
        return null;
      }

      ContactLocal? contact;
      if (userId != null && userId.trim().isNotEmpty) {
        contact = await _contactsService.getContactByUserId(userId.trim());
      }

      contact ??= mobileNo != null && mobileNo.trim().isNotEmpty
          ? await _contactsService.getContactByMobile(mobileNo.trim())
          : null;

      if (contact == null) {
        return null;
      }

      final updatedList = await _appUsersCheckService.checkAppUsers([contact]);
      if (updatedList.isEmpty) {
        return contact;
      }

      final updated = updatedList.first.copyWith(lastUpdated: DateTime.now());
      await _contactsService.upsertContact(updated);
      return updated;
    } catch (e) {
      return null;
    }
  }

  // =============================================
  // API Response Methods
  // =============================================

  /// Fetch contacts from device and check app users via API
  Future<List<ContactLocal>> fetchContactsFromDeviceAndAPI() async {
    try {
      debugPrint(
        'ContactsRepository: Starting device contacts fetch and API check...',
      );

      // Step 1: Fetch contacts from device
      final rawDeviceContacts = await _deviceContactsService
          .fetchDeviceContactsWithRetry();

      final deviceContacts = await _excludeCurrentUser(rawDeviceContacts);
      debugPrint(
        'ContactsRepository: Fetched ${deviceContacts.length} contacts from device',
      );

      if (deviceContacts.isEmpty) {
        debugPrint('ContactsRepository: No device contacts found');
        return [];
      }

      // Step 2: Check which contacts are app users via API
      final contactsWithAppUsers = await _appUsersCheckService.checkAppUsers(
        deviceContacts,
      );
      debugPrint(
        'ContactsRepository: API check completed for ${contactsWithAppUsers.length} contacts',
      );

      final filteredContactsWithAppUsers = await _excludeCurrentUser(
        contactsWithAppUsers,
      );

      // Stats
      final registeredCount = contactsWithAppUsers
          .where((c) => c.isRegistered || (c.userDetails?.userId != null))
          .length;
      final nonRegisteredCount = contactsWithAppUsers.length - registeredCount;
      final userDetailsCount = contactsWithAppUsers
          .where((c) => c.userDetails != null)
          .length;
      debugPrint('🟩 Registered app users: $registeredCount');
      debugPrint('🟥 Non-app users: $nonRegisteredCount');
      debugPrint('🧾 With userDetails: $userDetailsCount');

      if (kDebugMode) {
        final registeredList = contactsWithAppUsers
            .where((c) => c.isRegistered || (c.userDetails?.userId != null))
            .toList();
        debugPrint(
          '👥 Registered contacts details (${registeredList.length}):',
        );
        for (final c in registeredList) {
          final d = c.userDetails;
          final userId = d?.userId ?? '-';
          final displayName = d?.appdisplayName ?? c.name;
          final chatPictureUrl = d?.chatPictureUrl;
          debugPrint(
            ' • name="$displayName" phone=${c.mobileNo} userId=$userId chatPictureUrl=${chatPictureUrl ?? 'null'}',
          );
        }
      }

      // Step 3: Save to cache
      await _contactsService.saveContacts(filteredContactsWithAppUsers);
      debugPrint(
        'ContactsRepository: Saved ${contactsWithAppUsers.length} contacts to cache',
      );
      debugPrint('💾 Saved to database successfully');

      return filteredContactsWithAppUsers;
    } catch (e) {
      debugPrint(
        'ContactsRepository: Error in fetchContactsFromDeviceAndAPI: $e',
      );
      rethrow;
    }
  }

  /// Sync contacts with server (fetch device + API check + cache)
  Future<Map<String, dynamic>> syncContactsWithServer() async {
    try {
      debugPrint(
        'ContactsRepository: Starting full contact sync with server...',
      );

      // Step 1: Fetch contacts from device and check with API
      final rawDeviceContacts = await _deviceContactsService
          .fetchDeviceContactsWithRetry();

      final deviceContacts = await _excludeCurrentUser(rawDeviceContacts);
      debugPrint(
        'ContactsRepository: Fetched ${deviceContacts.length} contacts from device',
      );

      // Step 2: Prune contacts that exist in database but no longer exist on device
      final prunedCount = await ContactsDatabaseService.instance
          .pruneDeletedContacts(deviceContacts);
      debugPrint(
        'ContactsRepository: Pruned $prunedCount contacts that were deleted from device',
      );

      // Step 3: Check which contacts are app users and update the database
      final contactsWithAppUsers = await _appUsersCheckService.checkAppUsers(
        deviceContacts,
      );
      debugPrint(
        'ContactsRepository: API check completed for ${contactsWithAppUsers.length} contacts',
      );

      final filteredContactsWithAppUsers = await _excludeCurrentUser(
        contactsWithAppUsers,
      );

      // Stats
      final registeredCount = contactsWithAppUsers
          .where((c) => c.isRegistered || (c.userDetails?.userId != null))
          .length;
      final nonRegisteredCount = contactsWithAppUsers.length - registeredCount;
      final userDetailsCount = contactsWithAppUsers
          .where((c) => c.userDetails != null)
          .length;
      debugPrint('🟩 Registered app users: $registeredCount');
      debugPrint('🟥 Non-app users: $nonRegisteredCount');
      debugPrint('🧾 With userDetails: $userDetailsCount');

      // Step 4: Save updated contacts to cache
      await _contactsService.saveContacts(filteredContactsWithAppUsers);
      debugPrint(
        '💾 Saved to database: ${contactsWithAppUsers.length} contacts',
      );

      // Get final statistics
      final stats = await getCacheStatistics();

      final result = {
        'success': true,
        'totalContacts': filteredContactsWithAppUsers.length,
        'registeredContacts': stats['registered'] ?? 0,
        'nonRegisteredContacts': stats['non_registered'] ?? 0,
        'prunedContacts': prunedCount,
        'message': 'Contacts synced successfully with server',
      };

      debugPrint(
        'ContactsRepository: Sync completed - ${result['totalContacts']} total, ${result['registeredContacts']} registered, ${result['prunedContacts']} pruned',
      );
      return result;
    } catch (e) {
      debugPrint('ContactsRepository: Error in syncContactsWithServer: $e');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to sync contacts with server',
      };
    }
  }

  /// Check app users status via API for existing contacts
  Future<List<ContactLocal>> checkAppUsersStatusFromAPI() async {
    try {
      debugPrint('ContactsRepository: Checking app users status via API...');

      // Get existing contacts from cache
      final existingContacts = await loadAllContacts();
      if (existingContacts.isEmpty) {
        debugPrint('ContactsRepository: No contacts in cache to check');
        return [];
      }

      final filteredExisting = await _excludeCurrentUser(existingContacts);

      // Check app users status via API
      final updatedContacts = await _appUsersCheckService.checkAppUsers(
        filteredExisting,
      );
      debugPrint(
        'ContactsRepository: Updated ${updatedContacts.length} contacts with app user status',
      );

      // Save updated contacts back to cache
      // Debug: Log sample of what we're saving
      for (final c in updatedContacts.take(3)) {
        final status = c.userDetails?.recentStatus;
        final emoji = c.userDetails?.recentEmojiUpdate;
        debugPrint(
          '💾 [ContactsRepo] Saving: ${c.preferredDisplayName} | '
          'hasUserDetails=${c.userDetails != null} | '
          'recentStatus=${status != null ? "content=${status.content}" : "null"} | '
          'recentEmoji=${emoji != null ? "emoji=${emoji['emojis_update']}" : "null"}',
        );
      }
      await _contactsService.saveContacts(updatedContacts);

      return updatedContacts;
    } catch (e) {
      debugPrint('ContactsRepository: Error in checkAppUsersStatusFromAPI: $e');
      rethrow;
    }
  }

  /// Refresh contacts from device (without API check)
  Future<List<ContactLocal>> refreshDeviceContacts() async {
    try {
      debugPrint('ContactsRepository: Refreshing contacts from device...');

      final rawDeviceContacts = await _deviceContactsService
          .fetchDeviceContactsWithRetry();

      final deviceContacts = await _excludeCurrentUser(rawDeviceContacts);
      debugPrint(
        'ContactsRepository: Refreshed ${deviceContacts.length} contacts from device',
      );

      // Save to cache (keeps existing registration status)
      await _contactsService.saveContacts(deviceContacts);

      return deviceContacts;
    } catch (e) {
      debugPrint('ContactsRepository: Error in refreshDeviceContacts: $e');
      rethrow;
    }
  }

  // =============================================
  // Profile Delta Sync (Update profiles changed while offline)
  // =============================================

  /// Sync profile updates for contacts that changed while user was offline
  /// This is called on app launch to fetch delta updates since last sync
  /// Returns number of contacts updated
  Future<int> syncProfileUpdates() async {
    try {
      debugPrint('ContactsRepository: Starting profile delta sync...');

      // Get last sync time or use 1 day ago as fallback
      DateTime effectiveSyncTime;
      final lastSyncTime = await _syncStorage.getLastSyncTime();

      if (lastSyncTime == null) {
        // First time - fetch updates from last 24 hours
        effectiveSyncTime = DateTime.now().subtract(const Duration(days: 1));
        debugPrint(
          'ContactsRepository: No previous sync time found, using fallback: 24 hours ago',
        );
      } else {
        effectiveSyncTime = lastSyncTime;
      }

      debugPrint(
        'ContactsRepository: Fetching profiles updated since: ${effectiveSyncTime.toIso8601String()}',
      );

      // Fetch updated contacts from backend
      final updatedContacts = await _deltaSyncService.fetchUpdatedContacts(
        effectiveSyncTime,
      );

      if (updatedContacts.isEmpty) {
        debugPrint(
          'ContactsRepository: No profile updates found since last sync',
        );
        // Update sync time even if no updates (to advance the watermark)
        await _syncStorage.saveLastSyncTime(DateTime.now());
        return 0;
      }

      debugPrint(
        'ContactsRepository: Received ${updatedContacts.length} profile update(s)',
      );

      // Update local database with new profile data
      int updateCount = 0;
      for (final updatedContact in updatedContacts) {
        try {
          // Find existing contact in database by mobile number or user ID
          ContactLocal? existingContact;

          // Try to find by user ID from userDetails
          final userId = updatedContact.userDetails?.userId;
          if (userId != null && userId.isNotEmpty) {
            existingContact = await _contactsService.getContactByUserId(userId);
          }

          // Fallback to finding by mobile number
          existingContact ??= await _contactsService.getContactByMobile(
            updatedContact.mobileNo,
          );

          if (existingContact != null) {
            // Merge updated profile data with existing contact
            // IMPORTANT: Keep the local contact name, only update userDetails
            final mergedContact = existingContact.copyWith(
              userDetails: updatedContact.userDetails,
              isRegistered:
                  true, // If they're in the update list, they're registered
              lastUpdated: DateTime.now(),
            );

            // Save updated contact
            await _contactsService.upsertContact(mergedContact);
            updateCount++;

            debugPrint(
              '✅ ContactsRepository: Updated profile for ${mergedContact.preferredDisplayName}',
            );
          } else {
            debugPrint(
              '⚠️ ContactsRepository: Contact not found locally: ${updatedContact.mobileNo}',
            );
          }
        } catch (e) {
          debugPrint('❌ ContactsRepository: Error updating contact: $e');
          continue;
        }
      }

      // Save current time as last sync time
      await _syncStorage.saveLastSyncTime(DateTime.now());

      debugPrint(
        '✅ ContactsRepository: Profile delta sync complete - Updated $updateCount contact(s)',
      );

      return updateCount;
    } catch (e, stackTrace) {
      debugPrint('❌ ContactsRepository: Error in syncProfileUpdates: $e');
      debugPrint('Stack trace: $stackTrace');
      return 0;
    }
  }

  /// Initialize profile sync timestamp (called after initial contacts sync)
  /// This sets the baseline for delta sync
  Future<void> initializeProfileSyncTime() async {
    try {
      final lastSyncTime = await _syncStorage.getLastSyncTime();

      if (lastSyncTime == null) {
        // First time - set initial sync time
        await _syncStorage.saveLastSyncTime(DateTime.now());
        debugPrint('ContactsRepository: Initialized profile sync timestamp');
      }
    } catch (e) {
      debugPrint(
        'ContactsRepository: Error initializing profile sync time: $e',
      );
    }
  }

  // =============================================
  // Cache Methods (Existing)
  // =============================================

  /// Save contacts to cache
  Future<void> saveContacts(List<ContactLocal> contacts) async {
    try {
      await _contactsService.saveContacts(contacts);
      debugPrint('ContactsRepository: Saved ${contacts.length} contacts');
    } catch (e) {
      debugPrint('ContactsRepository: Error saving contacts: $e');
      rethrow;
    }
  }

  /// Load all contacts from cache
  Future<List<ContactLocal>> loadAllContacts() async {
    try {
      final contacts = await _contactsService.loadFromCache();
      debugPrint(
        'ContactsRepository: Loaded ${contacts.length} total contacts',
      );
      return await _excludeCurrentUser(contacts);
    } catch (e) {
      debugPrint('ContactsRepository: Error loading contacts: $e');
      return [];
    }
  }

  /// Load only registered contacts (app users)
  Future<List<ContactLocal>> loadRegisteredContacts() async {
    try {
      final registeredContacts = await _contactsService
          .loadRegisteredFromCache();
      debugPrint(
        'ContactsRepository: Loaded ${registeredContacts.length} registered contacts',
      );
      return await _excludeCurrentUser(registeredContacts);
    } catch (e) {
      debugPrint('ContactsRepository: Error loading registered contacts: $e');
      return [];
    }
  }

  /// Load only non-registered contacts
  Future<List<ContactLocal>> loadNonRegisteredContacts() async {
    try {
      final nonRegisteredContacts = await _contactsService
          .loadNonRegisteredFromCache();
      debugPrint(
        'ContactsRepository: Loaded ${nonRegisteredContacts.length} non-registered contacts',
      );
      return await _excludeCurrentUser(nonRegisteredContacts);
    } catch (e) {
      debugPrint(
        'ContactsRepository: Error loading non-registered contacts: $e',
      );
      return [];
    }
  }

  /// Update contact registration status
  Future<void> updateContactRegistrationStatus(
    String contactHash,
    bool isRegistered,
  ) async {
    try {
      await _contactsService.updateContactRegistrationStatus(
        contactHash,
        isRegistered,
      );
      debugPrint(
        'ContactsRepository: Updated contact $contactHash registration status to $isRegistered',
      );
    } catch (e) {
      debugPrint('ContactsRepository: Error updating contact registration: $e');
      rethrow;
    }
  }

  /// Get cache statistics for debugging
  Future<Map<String, int>> getCacheStatistics() async {
    try {
      return await _contactsService.getCacheStatistics();
    } catch (e) {
      debugPrint('ContactsRepository: Error getting cache statistics: $e');
      return {'total': 0, 'registered': 0, 'nonRegistered': 0};
    }
  }

  /// Clear contacts cache
  Future<void> clearCache() async {
    try {
      await _contactsService.clearCache();
      debugPrint('ContactsRepository: Cache cleared successfully');
    } catch (e) {
      debugPrint('ContactsRepository: Error clearing cache: $e');
      rethrow;
    }
  }

  /// Log cache contents for debugging
  Future<void> logCacheContents() async {
    try {
      await _contactsService.logCacheContents();
    } catch (e) {
      debugPrint('ContactsRepository: Error logging cache contents: $e');
    }
  }

  /// Find contact by mobile number
  Future<ContactLocal?> findContactByMobile(String mobileNo) async {
    try {
      final allContacts = await loadAllContacts();
      return allContacts
          .where((contact) => contact.mobileNo == mobileNo)
          .firstOrNull;
    } catch (e) {
      debugPrint('ContactsRepository: Error finding contact by mobile: $e');
      return null;
    }
  }

  /// Find contact by ID
  Future<ContactLocal?> findContactById(String contactHash) async {
    try {
      final allContacts = await loadAllContacts();
      return allContacts
          .where((contact) => contact.contactHash == contactHash)
          .firstOrNull;
    } catch (e) {
      debugPrint('ContactsRepository: Error finding contact by ID: $e');
      return null;
    }
  }
}
