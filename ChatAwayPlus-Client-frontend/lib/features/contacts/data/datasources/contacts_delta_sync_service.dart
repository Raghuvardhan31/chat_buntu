import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:chataway_plus/core/constants/api_url/api_urls.dart';
import 'package:chataway_plus/core/storage/token_storage.dart';
import '../models/contact_local.dart';

class ContactsDeltaSyncService {
  static final ContactsDeltaSyncService _instance =
      ContactsDeltaSyncService._internal();

  factory ContactsDeltaSyncService() => _instance;
  ContactsDeltaSyncService._internal();

  static const Duration _timeout = Duration(seconds: 30);

  /// Get authorization headers with JWT token
  Future<Map<String, String>> _getAuthHeaders() async {
    final token = await TokenSecureStorage().getToken();
    final headers = <String, String>{'Content-Type': 'application/json'};

    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  /// Fetch contacts updated since the given timestamp
  /// Returns list of ContactLocal with updated profile information
  Future<List<ContactLocal>> fetchUpdatedContacts(DateTime since) async {
    try {
      // Convert timestamp to ISO 8601 format for API
      final isoTimestamp = since.toUtc().toIso8601String();

      debugPrint(
        '🔄 [ContactsDeltaSync] Fetching contacts updated since: $isoTimestamp',
      );

      // Build API URL with query parameter
      final uri = Uri.parse(
        ApiUrls.getUpdatedContactsSince,
      ).replace(queryParameters: {'timestamp': isoTimestamp});

      // Get authorization headers
      final headers = await _getAuthHeaders();

      // Make API request
      final response = await http.get(uri, headers: headers).timeout(_timeout);

      debugPrint(
        '🔄 [ContactsDeltaSync] Response status: ${response.statusCode}',
      );

      // Handle response
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (responseData['success'] == true) {
          final data = responseData['data'] as List<dynamic>?;

          if (data == null || data.isEmpty) {
            debugPrint(
              '✅ [ContactsDeltaSync] No contacts updated since $isoTimestamp',
            );
            return [];
          }

          debugPrint(
            '✅ [ContactsDeltaSync] Found ${data.length} updated contact(s)',
          );

          // Parse updated contacts
          final updatedContacts = _parseUpdatedContacts(data);

          debugPrint(
            '✅ [ContactsDeltaSync] Parsed ${updatedContacts.length} contact(s)',
          );

          return updatedContacts;
        } else {
          final errorMsg = responseData['message'] ?? 'Unknown error';
          debugPrint('❌ [ContactsDeltaSync] API returned error: $errorMsg');
          return [];
        }
      } else if (response.statusCode == 400) {
        final errorData = jsonDecode(response.body);
        final errorMsg = errorData['message'] ?? 'Bad request';
        debugPrint('❌ [ContactsDeltaSync] Bad request (400): $errorMsg');
        return [];
      } else if (response.statusCode == 401) {
        debugPrint(
          '❌ [ContactsDeltaSync] Unauthorized (401) - token may be expired',
        );
        return [];
      } else {
        debugPrint(
          '❌ [ContactsDeltaSync] Unexpected status code: ${response.statusCode}',
        );
        return [];
      }
    } catch (e, stackTrace) {
      debugPrint('❌ [ContactsDeltaSync] Error fetching updated contacts: $e');
      debugPrint('Stack trace: $stackTrace');
      return [];
    }
  }

  /// Parse API response data into ContactLocal objects
  List<ContactLocal> _parseUpdatedContacts(List<dynamic> data) {
    final contacts = <ContactLocal>[];

    for (final item in data) {
      try {
        final contactMap = item as Map<String, dynamic>;

        // Parse user details from backend response
        final userDetails = _parseUserDetails(contactMap);

        // Create ContactLocal from API data
        final name = contactMap['name']?.toString() ?? '';
        final mobileNo = contactMap['mobileNo']?.toString() ?? '';

        // Generate contact hash from mobile number (same as device contacts)
        final contactHash = mobileNo.hashCode.toString();

        final contact = ContactLocal(
          contactHash: contactHash,
          name: name,
          mobileNo: mobileNo,
          isRegistered: true,
          lastUpdated: DateTime.now(),
          userDetails: userDetails,
        );

        contacts.add(contact);

        if (kDebugMode) {
          debugPrint(
            '📝 [ContactsDeltaSync] Parsed: ${contact.preferredDisplayName} '
            '(${contact.mobileNo})',
          );
        }
      } catch (e) {
        debugPrint('⚠️ [ContactsDeltaSync] Error parsing contact: $e');
        continue;
      }
    }

    return contacts;
  }

  /// Parse user details from backend response
  UserDetails? _parseUserDetails(Map<String, dynamic> data) {
    try {
      // Parse recent status
      UserStatus? recentStatus;
      final statusData = data['recentStatus'] as Map<String, dynamic>?;
      if (statusData != null) {
        debugPrint('🔍 [DeltaSync] recentStatus payload: $statusData');
        recentStatus = UserStatus(
          statusId:
              (statusData['statusId'] ??
                      statusData['status_id'] ??
                      statusData['id'])
                  ?.toString(),
          content: statusData['share_your_voice']?.toString() ?? '',
          createdAt: _parseDateTime(statusData['createdAt']),
        );
        debugPrint('🔍 [DeltaSync] Parsed statusId: ${recentStatus.statusId}');
      }

      // Parse recent emoji update
      Map<String, dynamic>? recentEmojiUpdate;
      final emojiData = data['recentEmojiUpdate'] as Map<String, dynamic>?;
      if (emojiData != null) {
        recentEmojiUpdate = {
          'emojis_update': emojiData['emojis_update']?.toString() ?? '',
          'emojis_caption': emojiData['emojis_caption']?.toString() ?? '',
          'createdAt': emojiData['createdAt']?.toString() ?? '',
        };
      }

      // Parse chat picture
      String? chatPicture = data['chat_picture']?.toString();
      if (chatPicture != null && chatPicture.isNotEmpty) {
        // If relative path, prepend base URL
        if (!chatPicture.startsWith('http')) {
          chatPicture = '${ApiUrls.mediaBaseUrl}$chatPicture';
        }
      }

      return UserDetails(
        userId: data['id']?.toString() ?? '',
        appdisplayName: data['name']?.toString() ?? '',
        chatPictureUrl: chatPicture,
        chatPictureVersion: data['chat_picture_version']?.toString(),
        recentStatus: recentStatus,
        recentEmojiUpdate: recentEmojiUpdate,
      );
    } catch (e) {
      debugPrint('⚠️ [ContactsDeltaSync] Error parsing user details: $e');
      return null;
    }
  }

  /// Parse DateTime from various formats
  DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();

    try {
      if (value is String) {
        return DateTime.parse(value);
      } else if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
    } catch (e) {
      debugPrint('⚠️ [ContactsDeltaSync] Error parsing datetime: $e');
    }

    return DateTime.now();
  }
}
