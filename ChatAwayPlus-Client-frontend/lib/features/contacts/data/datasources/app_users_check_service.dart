import 'dart:convert';

import 'package:chataway_plus/core/storage/token_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../../core/constants/api_url/api_urls.dart';
import '../models/check_contacts_api_models.dart';
import '../models/contact_local.dart';

// Helper function to get auth headers
Future<Map<String, String>> getAuthHeaders() async {
  final token = await TokenSecureStorage().getToken();
  final headers = <String, String>{'Content-Type': 'application/json'};

  if (token != null && token.isNotEmpty) {
    headers['Authorization'] = 'Bearer $token';
  }

  return headers;
}

/// Service to check which contacts are registered app users
/// Optimized for large contact lists (6000+) with parallel batching
class AppUsersCheckService {
  static final AppUsersCheckService _instance =
      AppUsersCheckService._internal();

  factory AppUsersCheckService() => _instance;

  AppUsersCheckService._internal();

  // Configuration - OPTIMIZED FOR LARGE CONTACT LISTS
  static final String checkContactsApiUrl = ApiUrls.checkContacts;
  static const Duration _timeout = Duration(seconds: 60); // Increased from 15s
  static const int _batchSize = 500; // Increased from 50 for fewer API calls
  static const int _maxRetries = 3;
  static const int _maxParallelBatches = 3; // Process 3 batches in parallel

  String _normalizePhone(String input) {
    final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > 10) {
      return digits.substring(digits.length - 10);
    }
    return digits;
  }

  List<String> _phoneVariants(String input) {
    final normalized = _normalizePhone(input);
    if (normalized.isEmpty) return const [];
    final set = <String>{normalized};

    if (normalized.length == 10) {
      set.add('91$normalized');
      set.add('+91$normalized');
    }

    return set.toList();
  }

  /// Check which contacts are app users
  /// Optimized for large lists with parallel batch processing
  Future<List<ContactLocal>> checkAppUsers(
    List<ContactLocal> contacts, {
    void Function(int completed, int total)? onProgress,
  }) async {
    if (contacts.isEmpty) {
      return [];
    }

    try {
      final totalContacts = contacts.length;
      final totalBatches = (totalContacts / _batchSize).ceil();

      debugPrint(
        '[AppUsersCheckService] Processing $totalContacts contacts in $totalBatches batches '
        '(batch size: $_batchSize, parallel: $_maxParallelBatches)',
      );

      // Split contacts into batches
      final List<List<ContactLocal>> batches = [];
      for (var i = 0; i < contacts.length; i += _batchSize) {
        final end = (i + _batchSize < contacts.length)
            ? i + _batchSize
            : contacts.length;
        batches.add(contacts.sublist(i, end));
      }

      // Process batches in parallel groups
      final List<ContactLocal> result = [];
      int completedBatches = 0;

      for (var i = 0; i < batches.length; i += _maxParallelBatches) {
        final end = (i + _maxParallelBatches < batches.length)
            ? i + _maxParallelBatches
            : batches.length;
        final parallelBatches = batches.sublist(i, end);

        debugPrint(
          '[AppUsersCheckService] Processing batch group ${(i ~/ _maxParallelBatches) + 1}/${(batches.length / _maxParallelBatches).ceil()} '
          '(${parallelBatches.length} batches in parallel)',
        );

        // Process this group of batches in parallel
        final futures = parallelBatches.map((batch) async {
          try {
            return await _checkBatch(batch);
          } catch (e, stackTrace) {
            debugPrint(
              '[AppUsersCheckService] Error processing batch: $e\n$stackTrace',
            );
            // Return original batch if processing fails
            return batch;
          }
        }).toList();

        final batchResults = await Future.wait(futures);

        for (final batchResult in batchResults) {
          result.addAll(batchResult);
          completedBatches++;
          onProgress?.call(completedBatches, totalBatches);
        }
      }

      debugPrint(
        '[AppUsersCheckService] Completed processing all $totalBatches batches',
      );

      return result;
    } catch (e, stackTrace) {
      debugPrint('[AppUsersCheckService] Error: $e\n$stackTrace');
      return contacts;
    }
  }

  /// Check a batch of contacts
  Future<List<ContactLocal>> _checkBatch(List<ContactLocal> batch) async {
    final headers = await getAuthHeaders();
    final authHeader = headers['Authorization'];

    if (authHeader == null || authHeader.trim().isEmpty) {
      return batch;
    }

    return _checkBatchWithHeaders(batch, headers);
  }

  Future<List<ContactLocal>> _checkBatchWithHeaders(
    List<ContactLocal> batch,
    Map<String, String> headers,
  ) async {
    int retryCount = 0;

    while (retryCount < _maxRetries) {
      try {
        final seen = <String>{};
        final requestContacts = <Map<String, String>>[];
        for (final c in batch) {
          for (final v in _phoneVariants(c.mobileNo)) {
            if (v.isEmpty) continue;
            if (seen.add(v)) {
              requestContacts.add({
                'contact_mobile_number': v,
                'contact_name': c.name,
              });
            }
          }
        }

        final requestBody = {'contacts': requestContacts};

        final response = await http
            .post(
              Uri.parse(checkContactsApiUrl),
              headers: headers,
              body: jsonEncode(requestBody),
            )
            .timeout(_timeout);

        if (response.statusCode == 200) {
          final responseData = jsonDecode(response.body);
          return _processApiResponse(batch, responseData);
        }

        if (response.statusCode == 413 && batch.length > 1) {
          final mid = batch.length ~/ 2;
          final first = await _checkBatchWithHeaders(
            batch.sublist(0, mid),
            headers,
          );
          final second = await _checkBatchWithHeaders(
            batch.sublist(mid),
            headers,
          );
          return [...first, ...second];
        }

        throw Exception('API returned status code ${response.statusCode}');
      } catch (e) {
        retryCount++;

        if (retryCount >= _maxRetries) {
          rethrow;
        }

        final delay = Duration(seconds: retryCount);
        await Future.delayed(delay);
      }
    }

    return batch;
  }

  /// Process API response and update contacts
  List<ContactLocal> _processApiResponse(
    List<ContactLocal> originalContacts,
    dynamic responseData,
  ) {
    if (responseData is! Map<String, dynamic>) {
      debugPrint('[AppUsersCheckService] Invalid response data type');
      return originalContacts;
    }

    final parsed = CheckContactsResponse.fromJson(responseData);
    if (!parsed.success || parsed.data.isEmpty) {
      debugPrint('[AppUsersCheckService] Empty or unsuccessful response');
      return originalContacts;
    }

    // Build lookup map by normalized phone number
    final resultsByNormalized = <String, CheckContactItem>{};
    for (final item in parsed.data) {
      final normalized = _normalizePhone(item.contactMobileNumber);
      if (normalized.isEmpty) continue;

      // Only store if registered (to avoid overwriting with non-registered)
      if (item.isRegistered || item.userDetails != null) {
        resultsByNormalized[normalized] = item;
      }
    }

    debugPrint(
      '[AppUsersCheckService] Processing ${originalContacts.length} contacts against ${resultsByNormalized.length} registered results',
    );

    final processed = originalContacts.map((contact) {
      final normalizedKey = _normalizePhone(contact.mobileNo);
      if (normalizedKey.isEmpty) return contact;

      final item = resultsByNormalized[normalizedKey];
      if (item == null) {
        // Not a registered user - return original contact unchanged
        return contact;
      }

      final apiUserDetails = item.userDetails;
      final hasUserId = (apiUserDetails?.userId ?? '').trim().isNotEmpty;
      final isRegistered = item.isRegistered || hasUserId;

      if (!isRegistered) {
        return contact.copyWith(isRegistered: false, clearUserDetails: true);
      }

      if (apiUserDetails == null || !hasUserId) {
        return contact.copyWith(
          isRegistered: true,
          lastUpdated: DateTime.now(),
        );
      }

      final status = apiUserDetails.recentStatus;
      final mappedStatus = status == null
          ? null
          : UserStatus(
              statusId: status.statusId,
              content: status.shareYourVoice,
              createdAt: status.createdAt ?? DateTime.now(),
            );

      Map<String, dynamic>? mappedEmoji;
      final emoji = apiUserDetails.recentEmojiUpdate;
      if (emoji != null) {
        mappedEmoji = {
          'emojis_update': emoji.emojisUpdate,
          'emojis_caption': emoji.emojisCaption,
          'createdAt': emoji.createdAt?.toIso8601String(),
        };
      }

      final details = UserDetails(
        userId: apiUserDetails.userId,
        chatPictureUrl: apiUserDetails.chatPicture,
        chatPictureVersion: apiUserDetails.chatPictureVersion,
        appdisplayName: apiUserDetails.contactName.trim().isNotEmpty
            ? apiUserDetails.contactName
            : contact.preferredDisplayName,
        recentStatus: mappedStatus,
        recentLocation: null,
        recentEmojiUpdate: mappedEmoji,
      );

      return contact.copyWith(
        isRegistered: true,
        userDetails: details,
        lastUpdated: DateTime.now(),
      );
    }).toList();

    final registeredCount = processed.where((c) => c.isRegistered).length;
    debugPrint(
      '[AppUsersCheckService] Batch processed: $registeredCount registered out of ${processed.length} contacts',
    );

    return processed;
  }
}
