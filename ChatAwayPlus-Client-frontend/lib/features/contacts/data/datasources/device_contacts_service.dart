import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../models/contact_local.dart';

/// Service to handle fetching contacts from the device
class DeviceContactsService {
  static final DeviceContactsService _instance =
      DeviceContactsService._internal();

  factory DeviceContactsService() => _instance;

  DeviceContactsService._internal();

  /// Fetch all contacts from device with proper phone number validation
  Future<List<ContactLocal>> fetchDeviceContacts() async {
    try {
      print('🔍 Requesting contacts permission...');
      // Request permission first
      final permissionGranted = await FlutterContacts.requestPermission();
      print('ℹ️ Permission granted: $permissionGranted');

      if (!permissionGranted) {
        print('❌ Contact permission not granted');
        throw Exception('Contact permission not granted');
      }

      print(
        '✅ Contact permission granted${permissionGranted ? ' (already had permission)' : ''}',
      );

      print('📱 Fetching device contacts...');
      // Fetch contacts from device
      final deviceContacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false, // Skip photos for better performance
        withThumbnail: false,
      );
      print('ℹ️ Found ${deviceContacts.length} raw contacts from device');

      // Convert to our ContactLocal format
      final contacts = <ContactLocal>[];
      int skippedNoName = 0;
      int skippedNoPhone = 0;

      print('🔄 Processing ${deviceContacts.length} raw contacts...');
      for (final contact in deviceContacts) {
        // Skip contacts without a name or phone numbers
        if (contact.displayName.isEmpty) {
          skippedNoName++;
          continue;
        }
        if (contact.phones.isEmpty) {
          skippedNoPhone++;
          continue;
        }

        // Process all phone numbers
        for (final phone in contact.phones) {
          // Clean and validate phone number
          String phoneNumber = _cleanPhoneNumber(phone.number);

          // Skip empty or invalid phone numbers
          if (phoneNumber.isEmpty || phoneNumber.length < 8) {
            continue;
          }

          // Add contact with this phone number
          contacts.add(
            ContactLocal(
              contactHash: '${contact.displayName.trim()}_$phoneNumber'.hashCode
                  .toString(),
              name: contact.displayName.trim(),
              mobileNo: phoneNumber,
              isRegistered: false, // Will be updated by the repository
              lastUpdated: DateTime.now(),
            ),
          );
        }
      }

      // Log detailed stats
      debugPrint(
        '📊 Contacts: ${contacts.length} valid (Total: ${deviceContacts.length}, Skipped: ${skippedNoName + skippedNoPhone})',
      );

      if (contacts.isEmpty) {
        debugPrint('⚠️ No valid contacts found after processing');
      }

      return contacts;
    } catch (e, stackTrace) {
      print('❌ Error fetching device contacts: $e\n$stackTrace');
      rethrow;
    }
  }

  /// Clean and format phone number
  String _cleanPhoneNumber(String phoneNumber) {
    // Remove all non-digit characters
    String cleaned = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');

    // Remove leading zeros and country code if present
    if (cleaned.startsWith('0')) {
      cleaned = cleaned.substring(1);
    } else if (cleaned.startsWith('91')) {
      // India country code
      cleaned = cleaned.substring(2);
    } else if (cleaned.startsWith('+91')) {
      cleaned = cleaned.substring(3);
    }

    return cleaned;
  }

  /// Fetch contacts with retry mechanism and better error handling
  Future<List<ContactLocal>> fetchDeviceContactsWithRetry({
    int maxRetries = 3,
  }) async {
    int retryCount = 0;
    Exception? lastError;

    while (retryCount < maxRetries) {
      try {
        print('🔍 Attempt ${retryCount + 1} to fetch device contacts...');
        final contacts = await fetchDeviceContacts();
        print('✅ Successfully fetched ${contacts.length} contacts');
        return contacts;
      } catch (e, _) {
        lastError = e is Exception ? e : Exception(e.toString());
        retryCount++;

        if (retryCount >= maxRetries) {
          print(
            '❌ Failed to fetch contacts after $maxRetries attempts. Last error: $lastError',
          );
          rethrow;
        }

        // Wait before retrying with exponential backoff
        final delay = Duration(seconds: 1 * retryCount);
        print(
          '⚠️ Attempt $retryCount failed. Retrying in ${delay.inSeconds}s...',
        );
        await Future.delayed(delay);
      }
    }

    // This should theoretically never be reached due to the rethrow above
    throw lastError ??
        Exception('Failed to fetch contacts after $maxRetries attempts');
  }
}
