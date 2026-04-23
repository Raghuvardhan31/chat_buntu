// lib/features/voice_hub/data/datasources/emoji_updates_remote_datasource.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:chataway_plus/core/constants/api_url/api_urls.dart';
import 'package:chataway_plus/core/storage/token_storage.dart';
import '../models/responses/emoji_updates_response.dart';

/// Remote datasource for fetching emoji updates from all users
abstract class EmojiUpdatesRemoteDataSource {
  Future<GetAllEmojiUpdatesResponse> getAllEmojiUpdates();
}

/// Implementation of [EmojiUpdatesRemoteDataSource]
class EmojiUpdatesRemoteDataSourceImpl implements EmojiUpdatesRemoteDataSource {
  final http.Client httpClient;
  final TokenSecureStorage tokenStorage;

  static const Duration requestTimeout = Duration(seconds: 20);

  EmojiUpdatesRemoteDataSourceImpl({
    http.Client? httpClient,
    TokenSecureStorage? tokenStorage,
  })  : httpClient = httpClient ?? http.Client(),
        tokenStorage = tokenStorage ?? TokenSecureStorage.instance;

  @override
  Future<GetAllEmojiUpdatesResponse> getAllEmojiUpdates() async {
    final token = await tokenStorage.getToken();
    if (token == null) {
      return GetAllEmojiUpdatesResponse.error(
        message: 'Authentication required',
        statusCode: 401,
      );
    }

    final url = ApiUrls.emojiAllUpdates;
    debugPrint('[EmojiUpdates] GET $url');

    try {
      final response = await httpClient
          .get(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(requestTimeout);

      debugPrint('[EmojiUpdates] <- status=${response.statusCode} bodyLen=${response.body.length}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return GetAllEmojiUpdatesResponse.fromJson(json);
      } else {
        return GetAllEmojiUpdatesResponse.error(
          message: _extractErrorMessage(response),
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return GetAllEmojiUpdatesResponse.error(
        message: e.toString(),
      );
    }
  }

  String _extractErrorMessage(http.Response response) {
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['message'] as String? ?? 'Request failed';
    } catch (_) {
      return 'Request failed with status ${response.statusCode}';
    }
  }
}
