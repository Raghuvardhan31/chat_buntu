import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:chataway_plus/core/constants/api_url/api_urls.dart';
import 'package:chataway_plus/core/storage/token_storage.dart';
import '../models/blocked_contacts_models.dart';

abstract class BlockedContactsRemoteDataSource {
  Future<BlockedUsersResponseModel> getBlockedUsers();
  Future<BlockActionResponseModel> blockUser(String blockedUserId);
  Future<BlockActionResponseModel> unblockUser(String blockedUserId);
}

class BlockedContactsRemoteDataSourceImpl
    implements BlockedContactsRemoteDataSource {
  final http.Client httpClient;
  final TokenSecureStorage tokenStorage;
  BlockedContactsRemoteDataSourceImpl({
    required this.httpClient,
    required this.tokenStorage,
  });

  Future<Map<String, String>> _headers() async {
    final token = await tokenStorage.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
      'Accept': '*/*',
    };
  }

  @override
  Future<BlockedUsersResponseModel> getBlockedUsers() async {
    try {
      final res = await httpClient
          .get(Uri.parse(ApiUrls.getBlockedUsers), headers: await _headers())
          .timeout(const Duration(seconds: 15));

      Map<String, dynamic> parsed;
      try {
        final decoded = jsonDecode(res.body);
        parsed = decoded is Map ? Map<String, dynamic>.from(decoded) : {};
      } catch (_) {
        parsed = {};
      }

      if (res.statusCode == 200 || res.statusCode == 201) {
        return BlockedUsersResponseModel.fromJson(
          parsed,
          statusCode: res.statusCode,
        );
      }

      final err =
          (parsed['error'] ??
                  parsed['message'] ??
                  'Failed to fetch blocked users')
              .toString();
      return BlockedUsersResponseModel.error(
        error: err,
        statusCode: res.statusCode,
      );
    } on SocketException {
      return BlockedUsersResponseModel.error(error: 'Network unavailable');
    } on TimeoutException {
      return BlockedUsersResponseModel.error(error: 'Request timeout');
    } on http.ClientException {
      return BlockedUsersResponseModel.error(error: 'Network request failed');
    } catch (e) {
      return BlockedUsersResponseModel.error(error: e.toString());
    }
  }

  @override
  Future<BlockActionResponseModel> blockUser(String blockedUserId) async {
    try {
      final res = await httpClient
          .post(
            Uri.parse('${ApiUrls.blockUsers}/$blockedUserId'),
            headers: await _headers(),
          )
          .timeout(const Duration(seconds: 15));

      Map<String, dynamic> parsed;
      try {
        final decoded = jsonDecode(res.body);
        parsed = decoded is Map ? Map<String, dynamic>.from(decoded) : {};
      } catch (_) {
        parsed = {};
      }

      if (res.statusCode == 200 || res.statusCode == 201) {
        return BlockActionResponseModel.fromJson(
          parsed,
          statusCode: res.statusCode,
        );
      }

      final err =
          (parsed['error'] ?? parsed['message'] ?? 'Failed to block user')
              .toString();
      return BlockActionResponseModel.error(
        message: err,
        statusCode: res.statusCode,
      );
    } on SocketException {
      return BlockActionResponseModel.error(message: 'Network unavailable');
    } on TimeoutException {
      return BlockActionResponseModel.error(message: 'Request timeout');
    } on http.ClientException {
      return BlockActionResponseModel.error(message: 'Network request failed');
    } catch (e) {
      return BlockActionResponseModel.error(message: e.toString());
    }
  }

  @override
  Future<BlockActionResponseModel> unblockUser(String blockedUserId) async {
    try {
      final res = await httpClient
          .delete(
            Uri.parse('${ApiUrls.unblockUsers}/$blockedUserId'),
            headers: await _headers(),
          )
          .timeout(const Duration(seconds: 15));

      Map<String, dynamic> parsed;
      try {
        final decoded = jsonDecode(res.body);
        parsed = decoded is Map ? Map<String, dynamic>.from(decoded) : {};
      } catch (_) {
        parsed = {};
      }

      if (res.statusCode == 200 || res.statusCode == 201) {
        return BlockActionResponseModel.fromJson(
          parsed,
          statusCode: res.statusCode,
        );
      }

      final err =
          (parsed['error'] ?? parsed['message'] ?? 'Failed to unblock user')
              .toString();
      return BlockActionResponseModel.error(
        message: err,
        statusCode: res.statusCode,
      );
    } on SocketException {
      return BlockActionResponseModel.error(message: 'Network unavailable');
    } on TimeoutException {
      return BlockActionResponseModel.error(message: 'Request timeout');
    } on http.ClientException {
      return BlockActionResponseModel.error(message: 'Network request failed');
    } catch (e) {
      return BlockActionResponseModel.error(message: e.toString());
    }
  }
}
