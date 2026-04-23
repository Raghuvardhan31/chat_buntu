import 'package:flutter/foundation.dart';
import 'package:chataway_plus/core/database/tables/contacts/contacts_table.dart';
import '../models/contact_local.dart';

class ContactsDatabaseService {
  // Singleton
  static final ContactsDatabaseService _instance =
      ContactsDatabaseService._internal();
  factory ContactsDatabaseService() => _instance;
  ContactsDatabaseService._internal();
  static ContactsDatabaseService get instance => _instance;

  final ContactsTable _db = ContactsTable.instance;

  Future<void> saveContacts(List<ContactLocal> contacts) async {
    try {
      debugPrint(
        '[ContactsDatabaseService] Saving ${contacts.length} contacts',
      );
      if (contacts.isEmpty) return;

      final uniq = <String, ContactLocal>{};
      for (final c in contacts) {
        uniq[c.contactHash] = c;
      }
      final deduped = uniq.values.toList();

      await _db.insertOrUpdateContacts(deduped);

      debugPrint('[ContactsDatabaseService] Saved ${deduped.length} contacts');
    } catch (e) {
      debugPrint('[ContactsDatabaseService] Error saving contacts: $e');
      rethrow;
    }
  }

  Future<List<ContactLocal>> loadFromCache() => _db.getAllContacts();
  Future<List<ContactLocal>> loadRegisteredFromCache() =>
      _db.getRegisteredContacts();
  Future<List<ContactLocal>> loadNonRegisteredFromCache() =>
      _db.getNonRegisteredContacts();

  Future<void> updateContactRegistrationStatus(
    String contactHash,
    bool isRegistered,
  ) async {
    try {
      final contact = await _db.getContactById(contactHash);
      if (contact == null) return;
      await _db.updateContactRegistrationStatus(
        contactHash,
        isRegistered,
        clearUserDetails: !isRegistered,
      );
    } catch (e) {
      debugPrint(
        '[ContactsDatabaseService] Error updating registration status: $e',
      );
      rethrow;
    }
  }

  Future<int> pruneDeletedContacts(List<ContactLocal> currentDeviceContacts) {
    return _db.pruneDeletedContacts(currentDeviceContacts);
  }

  Future<void> clearCache() => _db.clearAllContacts();

  Future<Map<String, int>> getCacheStatistics() => _db.getCacheStatistics();

  Future<void> logCacheContents() => _db.logContacts();

  // ===== WHATSAPP-STYLE: Real-time Profile Updates =====

  /// Get contact by app user ID (for profile updates)
  Future<ContactLocal?> getContactByUserId(String userId) async {
    try {
      return await _db.getContactByAppUserId(userId);
    } catch (e) {
      debugPrint(
        '[ContactsDatabaseService] Error getting contact by userId: $e',
      );
      return null;
    }
  }

  Future<ContactLocal?> getContactByMobile(String mobileNo) async {
    try {
      return await _db.getContactByMobile(mobileNo);
    } catch (e) {
      debugPrint(
        '[ContactsDatabaseService] Error getting contact by mobile: $e',
      );
      return null;
    }
  }

  /// Update contact profile from real-time update (WebSocket/FCM)
  /// Called when a contact updates their name, profile pic, or status
  Future<bool> updateContactProfile({
    required String userId,
    String? name,
    String? chatPictureUrl,
    String? chatPictureVersion,
    String? statusContent,
    String? emoji,
    String? emojiCaption,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint(
          '[ContactsDatabaseService] updateContactProfile called - userId: $userId, emoji: $emoji, emojiCaption: $emojiCaption',
        );
      }
      final contact = await _db.getContactByAppUserId(userId);
      if (contact == null) {
        if (kDebugMode) {
          debugPrint(
            '[ContactsDatabaseService] Contact not found for userId: $userId',
          );
        }
        return false;
      }

      // Build updated UserDetails
      final currentDetails = contact.userDetails;

      UserStatus? resolveStatus(UserStatus? current) {
        if (statusContent == null) return current;
        final c = statusContent.trim();
        if (c.isEmpty) return null;
        return UserStatus(content: c, createdAt: DateTime.now());
      }

      Map<String, dynamic>? resolveEmojiUpdate(Map<String, dynamic>? current) {
        if (emoji == null && emojiCaption == null) return current;

        String? readEmoji(Map<String, dynamic>? m) {
          if (m == null) return null;
          return (m['emojis_update'] ??
                  m['emoji_updates'] ??
                  m['emojis_updates'] ??
                  m['emoji'] ??
                  m['emojisUpdate'] ??
                  m['emoji_update'])
              ?.toString();
        }

        String? readCaption(Map<String, dynamic>? m) {
          if (m == null) return null;
          return (m['emojis_caption'] ??
                  m['emoji_captions'] ??
                  m['emojis_captions'] ??
                  m['caption'] ??
                  m['emojisCaption'] ??
                  m['emoji_caption'])
              ?.toString();
        }

        final existingEmoji = readEmoji(current)?.trim();
        final existingCaption = readCaption(current)?.trim();

        final incomingEmoji = emoji?.trim();
        final incomingCaption = emojiCaption?.trim();

        if (incomingEmoji != null && incomingEmoji.isEmpty) {
          return null;
        }

        final effectiveEmoji = (incomingEmoji ?? existingEmoji ?? '').trim();
        if (effectiveEmoji.isEmpty) return null;

        final effectiveCaption = (incomingCaption ?? existingCaption)?.trim();

        return <String, dynamic>{
          'emojis_update': effectiveEmoji,
          'emojis_caption':
              (effectiveCaption != null && effectiveCaption.isNotEmpty)
              ? effectiveCaption
              : null,
          'createdAt': DateTime.now().toIso8601String(),
        };
      }

      String? resolveChatPictureUrl(String? current) {
        if (chatPictureUrl == null) return current;
        final v = chatPictureUrl.trim();
        if (v.isEmpty) return null;
        return v;
      }

      final resolvedChatPictureUrl = resolveChatPictureUrl(
        currentDetails?.chatPictureUrl,
      );

      final resolvedChatPictureVersion =
          (resolvedChatPictureUrl == null || resolvedChatPictureUrl.isEmpty)
          ? null
          : (chatPictureVersion ?? currentDetails?.chatPictureVersion);

      final resolvedEmojiUpdate = resolveEmojiUpdate(
        currentDetails?.recentEmojiUpdate,
      );
      if (kDebugMode) {
        debugPrint(
          '[ContactsDatabaseService] resolvedEmojiUpdate: $resolvedEmojiUpdate',
        );
      }

      final updatedDetails = UserDetails(
        userId: userId,
        chatPictureUrl: resolvedChatPictureUrl,
        chatPictureVersion: resolvedChatPictureVersion,
        appdisplayName:
            name ??
            currentDetails?.appdisplayName ??
            contact.preferredDisplayName,
        recentStatus: resolveStatus(currentDetails?.recentStatus),
        recentLocation: currentDetails?.recentLocation,
        recentEmojiUpdate: resolvedEmojiUpdate,
      );

      // Update contact with new details
      // IMPORTANT: Never overwrite the device-saved contact name with the app name
      // Device contact name is the user's saved name in their phone - always preserve it
      // App registered name goes only in userDetails.appdisplayName
      final updatedContact = contact.copyWith(userDetails: updatedDetails);

      await _db.insertOrUpdateContacts([updatedContact]);
      if (kDebugMode) {
        debugPrint('[ContactsDatabaseService] Profile updated for $userId');
      }
      return true;
    } catch (e) {
      debugPrint(
        '[ContactsDatabaseService] Error updating contact profile: $e',
      );
      return false;
    }
  }

  /// Upsert a single contact
  Future<void> upsertContact(ContactLocal contact) async {
    await _db.insertOrUpdateContacts([contact]);
  }

  Future<bool> handleContactsChanged({
    required String userId,
    required String mobileNo,
    String? name,
    String? chatPictureUrl,
    String? chatPictureVersion,
    String? statusContent,
    String? emoji,
    String? emojiCaption,
  }) async {
    try {
      final contact = await _db.getContactByMobile(mobileNo);
      if (contact == null) {
        debugPrint(
          '[ContactsDatabaseService] Contact not found for mobile: $mobileNo',
        );
        return false;
      }

      UserStatus? resolveStatus(UserStatus? current) {
        if (statusContent == null) return current;
        final c = statusContent.trim();
        if (c.isEmpty) return null;
        return UserStatus(content: c, createdAt: DateTime.now());
      }

      Map<String, dynamic>? resolveEmojiUpdate(Map<String, dynamic>? current) {
        if (emoji == null && emojiCaption == null) return current;

        String? readEmoji(Map<String, dynamic>? m) {
          if (m == null) return null;
          return (m['emojis_update'] ??
                  m['emoji_updates'] ??
                  m['emojis_updates'] ??
                  m['emoji'] ??
                  m['emojisUpdate'] ??
                  m['emoji_update'])
              ?.toString();
        }

        String? readCaption(Map<String, dynamic>? m) {
          if (m == null) return null;
          return (m['emojis_caption'] ??
                  m['emoji_captions'] ??
                  m['emojis_captions'] ??
                  m['caption'] ??
                  m['emojisCaption'] ??
                  m['emoji_caption'])
              ?.toString();
        }

        final existingEmoji = readEmoji(current)?.trim();
        final existingCaption = readCaption(current)?.trim();

        final incomingEmoji = emoji?.trim();
        final incomingCaption = emojiCaption?.trim();

        if (incomingEmoji != null && incomingEmoji.isEmpty) {
          return null;
        }

        final effectiveEmoji = (incomingEmoji ?? existingEmoji ?? '').trim();
        if (effectiveEmoji.isEmpty) return null;

        final effectiveCaption = (incomingCaption ?? existingCaption)?.trim();

        return <String, dynamic>{
          'emojis_update': effectiveEmoji,
          'emojis_caption':
              (effectiveCaption != null && effectiveCaption.isNotEmpty)
              ? effectiveCaption
              : null,
          'createdAt': DateTime.now().toIso8601String(),
        };
      }

      String? resolveChatPictureUrl(String? current) {
        if (chatPictureUrl == null) return current;
        final v = chatPictureUrl.trim();
        if (v.isEmpty) return null;
        return v;
      }

      String? resolveChatPictureVersion(String? current) {
        if (chatPictureVersion == null) return current;
        final v = chatPictureVersion.trim();
        if (v.isEmpty) return null;
        return v;
      }

      final currentDetails = contact.userDetails;
      final updatedDetails = UserDetails(
        userId: userId,
        chatPictureUrl: resolveChatPictureUrl(currentDetails?.chatPictureUrl),
        chatPictureVersion: resolveChatPictureVersion(
          currentDetails?.chatPictureVersion,
        ),
        appdisplayName:
            name ??
            currentDetails?.appdisplayName ??
            contact.preferredDisplayName,
        recentStatus: resolveStatus(currentDetails?.recentStatus),
        recentLocation: currentDetails?.recentLocation,
        recentEmojiUpdate: resolveEmojiUpdate(
          currentDetails?.recentEmojiUpdate,
        ),
      );

      final updatedContact = contact.copyWith(
        isRegistered: true,
        userDetails: updatedDetails,
        lastUpdated: DateTime.now(),
      );

      await _db.insertOrUpdateContacts([updatedContact]);
      return true;
    } catch (e) {
      debugPrint(
        '[ContactsDatabaseService] Error handling contacts changed: $e',
      );
      return false;
    }
  }

  // ===== WHATSAPP-STYLE: Contact Joined Notification =====

  /// Handle when a contact joins the app (from FCM notification)
  /// Updates the contact to registered status with user details
  /// Returns true if contact was found and updated
  Future<bool> handleContactJoined({
    required String userId,
    required String mobileNo,
    String? name,
    String? chatPictureUrl,
    String? chatPictureVersion,
  }) async {
    try {
      debugPrint('👤 [ContactsDB] Processing contact_joined: $mobileNo');

      // Find contact by mobile number
      final contact = await _db.getContactByMobile(mobileNo);

      if (contact == null) {
        debugPrint(
          '👤 [ContactsDB] Contact not found for mobile: $mobileNo - user may not have this number saved',
        );
        return false;
      }

      debugPrint(
        '👤 [ContactsDB] Found contact: ${contact.preferredDisplayName}',
      );

      // Build user details for the newly registered user
      final userDetails = UserDetails(
        userId: userId,
        chatPictureUrl: chatPictureUrl,
        chatPictureVersion: chatPictureVersion,
        appdisplayName: name ?? contact.preferredDisplayName,
        recentStatus: null,
        recentLocation: null,
        recentEmojiUpdate: null,
      );

      // Update contact to registered with user details
      final updatedContact = contact.copyWith(
        isRegistered: true,
        userDetails: userDetails,
        lastUpdated: DateTime.now(),
      );

      await _db.insertOrUpdateContacts([updatedContact]);

      debugPrint(
        '✅ [ContactsDB] Contact marked as registered: ${contact.preferredDisplayName} (${contact.mobileNo})',
      );
      return true;
    } catch (e) {
      debugPrint('❌ [ContactsDB] Error handling contact joined: $e');
      return false;
    }
  }
}
