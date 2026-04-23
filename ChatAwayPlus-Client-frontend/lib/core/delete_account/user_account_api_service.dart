import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../constants/api_url/api_urls.dart';
import '../storage/token_storage.dart';
import 'user_account_api_models.dart';

class UserAccountApiService {
  UserAccountApiService._();

  static final UserAccountApiService instance = UserAccountApiService._();

  final http.Client _httpClient = http.Client();
  final TokenSecureStorage _tokenStorage = TokenSecureStorage.instance;

  Future<DeleteUserResponseModel> requestDeleteAccount({
    bool deleteAccount = true,
  }) async {
    final token = await _tokenStorage.getToken();
    if (token == null || token.trim().isEmpty) {
      return DeleteUserResponseModel.error(message: 'Authentication required');
    }

    try {
      final res = await _httpClient
          .post(
            Uri.parse(ApiUrls.deleteUser),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
              'Accept': '*/*',
            },
            body: jsonEncode({'deleteAccount': deleteAccount}),
          )
          .timeout(const Duration(seconds: 15));

      Map<String, dynamic> parsed;
      try {
        final decoded = jsonDecode(res.body);
        parsed = decoded is Map ? Map<String, dynamic>.from(decoded) : {};
      } catch (_) {
        parsed = {};
      }

      final apiSuccess = parsed['success'] == true;
      final apiMessage = (parsed['message'] ?? '').toString();

      if (res.statusCode == 200 || res.statusCode == 201) {
        if (apiSuccess) {
          return DeleteUserResponseModel.fromJson(
            parsed,
            statusCode: res.statusCode,
          );
        }

        return DeleteUserResponseModel.error(
          message: apiMessage.isNotEmpty ? apiMessage : 'Invalid request',
          statusCode: res.statusCode,
        );
      }

      return DeleteUserResponseModel.error(
        message: apiMessage.isNotEmpty
            ? apiMessage
            : 'Failed to delete account (${res.statusCode})',
        statusCode: res.statusCode,
      );
    } on SocketException {
      return DeleteUserResponseModel.error(message: 'Network unavailable');
    } on TimeoutException {
      return DeleteUserResponseModel.error(message: 'Request timeout');
    } on http.ClientException {
      return DeleteUserResponseModel.error(message: 'Network request failed');
    } catch (e) {
      return DeleteUserResponseModel.error(message: e.toString());
    }
  }
}
