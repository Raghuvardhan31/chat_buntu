// lib/features/auth/data/datasources/auth_remote_datasource.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:chataway_plus/core/constants/api_url/api_urls.dart';


import '../models/requests/auth_request_models.dart';
import '../models/response/auth_response_model.dart';


// 🔹 This file handles all AUTH API calls (Send OTP, Verify OTP, Resend OTP)
// 🔸 ApiUrls.signup → Used for sending & resending OTP ---Line Number 137 And 212
// 🔸 ApiUrls.verifyOtp → Used for verifying the OTP   ----   Line Numbere 171
// 🔸 Each API call uses retry logic, timeout handling, and proper response/error models
// 🔸 Follows clean separation: DataSource → Repository → Notifier/Provider → UI

/// Remote datasource for authentication operations
/// Handles all HTTP API calls related to authentication
/// Implements retry logic, error handling, and proper logging
abstract class AuthRemoteDataSource {
  /// Send OTP to mobile number for registration/login
  /// [request] - Mobile number request model with validation
  /// Returns [OtpRequestResponseModel] with success/failure information
  Future<OtpRequestResponseModel> sendOtp(OtpRequestModel request);

  /// Verify OTP code for authentication
  /// [request] - OTP verification request model with mobile number and code
  /// Returns [OtpVerificationResponseModel] with authentication data if successful
  Future<OtpVerificationResponseModel> verifyOtp(
    OtpVerificationRequestModel request,
  );

  /// Resend OTP code to the same mobile number
  /// [request] - Resend OTP request model with tracking information
  /// Returns [OtpRequestResponseModel] with success/failure information
  Future<OtpRequestResponseModel> resendOtp(ResendOtpRequestModel request);
}

/// Implementation of [AuthRemoteDataSource] using HTTP client
/// Provides comprehensive error handling, retry logic, and logging
class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final http.Client httpClient;

  /// Maximum number of retry attempts for failed requests
  static const int maxRetries = 2;

  /// Request timeout duration
  static const Duration requestTimeout = Duration(seconds: 20);

  /// Base delay between retries (exponential backoff)
  static const Duration baseRetryDelay = Duration(seconds: 2);

  /// Create instance with optional HTTP client (for testing)
  /// [httpClient] - HTTP client instance, defaults to http.Client()
  AuthRemoteDataSourceImpl({http.Client? httpClient})
    : httpClient = httpClient ?? http.Client();

  @override
  Future<OtpRequestResponseModel> sendOtp(OtpRequestModel request) async {
    // Validate request model before making API call
    if (!request.isValid()) {
      _logError('SendOTP', 'Invalid request: ${request.validationError}');
      return OtpRequestResponseModel.error(
        message: request.validationError ?? 'Invalid mobile number',
        statusCode: 400,
      );
    }

    return _executeWithRetry<OtpRequestResponseModel>(
      operation: () => _sendOtpRequest(request),
      operationName: 'SendOTP',
      requestData: {
        'mobileNo': request.maskedNumber,
        'countryCode': request.countryCode,
      },
    );
  }

  @override
  Future<OtpVerificationResponseModel> verifyOtp(
    OtpVerificationRequestModel request,
  ) async {
    // Validate request model before making API call
    if (!request.isValid()) {
      _logError('VerifyOTP', 'Invalid request: ${request.validationError}');
      return OtpVerificationResponseModel.error(
        message: request.validationError ?? 'Invalid OTP or mobile number',
        statusCode: 400,
      );
    }

    return _executeWithRetry<OtpVerificationResponseModel>(
      operation: () => _verifyOtpRequest(request),
      operationName: 'VerifyOTP',
      requestData: {
        'mobileNo': request.maskedNumber,
        'otp': request.maskedOtp,
        'countryCode': request.countryCode,
      },
    );
  }

  @override
  Future<OtpRequestResponseModel> resendOtp(
    ResendOtpRequestModel request,
  ) async {
    // Validate request model before making API call
    if (!request.isValid()) {
      _logError('ResendOTP', 'Invalid request: ${request.validationError}');
      return OtpRequestResponseModel.error(
        message: request.validationError ?? 'Invalid mobile number',
        statusCode: 400,
      );
    }

    return _executeWithRetry<OtpRequestResponseModel>(
      operation: () => _resendOtpRequest(request),
      operationName: 'ResendOTP',
      requestData: {
        'mobileNo': request.maskedNumber,
        'reason': request.reason,
        'attemptCount': request.attemptCount,
      },
    );
  }

  /// Execute HTTP request to send OTP
  /// Internal method that performs the actual API call
  Future<OtpRequestResponseModel> _sendOtpRequest(
    OtpRequestModel request,
  ) async {
    _logInfo('SendOTP', 'Sending OTP to ${request.maskedNumber}');

    final response = await httpClient
        .post(
          Uri.parse(ApiUrls.signup),
          headers: _getDefaultHeaders(),
          body: jsonEncode(request.toJson()),
        )
        .timeout(requestTimeout);

    _logResponse('SendOTP', response);

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body) as Map<String, dynamic>;
      return OtpRequestResponseModel.fromJson({
        ...responseData,
        'statusCode': response.statusCode,
      });
    } else {
      // Handle non-200 status codes
      final errorData = _parseErrorResponse(response);
      return OtpRequestResponseModel.error(
        message: errorData['message'] ?? 'Failed to send OTP',
        statusCode: response.statusCode,
      );
    }
  }

  /// Execute HTTP request to verify OTP
  /// Internal method that performs the actual API call
  Future<OtpVerificationResponseModel> _verifyOtpRequest(
    OtpVerificationRequestModel request,
  ) async {
    _logInfo('VerifyOTP', 'Verifying OTP for ${request.maskedNumber}');

    final response = await httpClient
        .post(
          Uri.parse(ApiUrls.verifyOtp),
          headers: _getDefaultHeaders(),
          body: jsonEncode(request.toJson()),
        )
        .timeout(requestTimeout);

    _logResponse('VerifyOTP', response);

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body) as Map<String, dynamic>;
      return OtpVerificationResponseModel.fromJson({
        ...responseData,
        'statusCode': response.statusCode,
      });
    } else {
      // Handle non-200 status codes
      final errorData = _parseErrorResponse(response);
      return OtpVerificationResponseModel.error(
        message: errorData['message'] ?? 'Invalid OTP or verification failed',
        statusCode: response.statusCode,
      );
    }
  }

  /// Execute HTTP request to resend OTP
  /// Internal method that performs the actual API call
  Future<OtpRequestResponseModel> _resendOtpRequest(
    ResendOtpRequestModel request,
  ) async {
    _logInfo(
      'ResendOTP',
      'Resending OTP to ${request.maskedNumber} (attempt: ${request.attemptCount})',
    );

    // For resend, we use the same signup endpoint as initial OTP request
    final otpRequest = OtpRequestModel(
      mobileNo: request.mobileNo,
      countryCode: request.countryCode,
    );

    final response = await httpClient
        .post(
          Uri.parse(ApiUrls.signup),
          headers: _getDefaultHeaders(),
          body: jsonEncode({
            ...otpRequest.toJson(),
            'isResend': true,
            'reason': request.reason,
            'attemptCount': request.attemptCount,
          }),
        )
        .timeout(requestTimeout);

    _logResponse('ResendOTP', response);

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body) as Map<String, dynamic>;
      return OtpRequestResponseModel.fromJson({
        ...responseData,
        'statusCode': response.statusCode,
      });
    } else {
      // Handle non-200 status codes
      final errorData = _parseErrorResponse(response);
      return OtpRequestResponseModel.error(
        message: errorData['message'] ?? 'Failed to resend OTP',
        statusCode: response.statusCode,
      );
    }
  }

  /// Execute operation with retry logic
  /// Generic method that handles retry logic for any operation
  /// [T] - Return type of the operation
  /// [operation] - The operation to execute
  /// [operationName] - Name for logging purposes
  /// [requestData] - Request data for logging (sensitive data should be masked)
  Future<T> _executeWithRetry<T extends AuthResponseModel>({
    required Future<T> Function() operation,
    required String operationName,
    Map<String, dynamic>? requestData,
  }) async {
    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        _logInfo(
          operationName,
          'Attempt ${attempt + 1}/${maxRetries + 1}',
          requestData,
        );

        final result = await operation();

        // If successful, return result immediately
        if (result.isSuccess) {
          _logInfo(operationName, 'Success on attempt ${attempt + 1}');
          return result;
        }

        // If not successful but not retryable, return error
        if (!_shouldRetry(result.statusCode, attempt)) {
          _logError(
            operationName,
            'Non-retryable error: ${result.errorMessage}',
          );
          return result;
        }

        // Log retry attempt
        _logInfo(
          operationName,
          'Retrying in ${_getRetryDelay(attempt).inSeconds} seconds...',
        );

        // Wait before retry with exponential backoff
        if (attempt < maxRetries) {
          await Future.delayed(_getRetryDelay(attempt));
        }
      } on TimeoutException catch (e) {
        _logError(operationName, 'Timeout on attempt ${attempt + 1}: $e');

        if (attempt >= maxRetries) {
          return _createTimeoutErrorResponse<T>(operationName);
        }

        // Wait before retry
        await Future.delayed(_getRetryDelay(attempt));
      } on SocketException catch (e) {
        _logError(operationName, 'Network error on attempt ${attempt + 1}: $e');

        if (attempt >= maxRetries) {
          return _createNetworkErrorResponse<T>(operationName);
        }

        // Wait before retry
        await Future.delayed(_getRetryDelay(attempt));
      } on HttpException catch (e) {
        _logError(operationName, 'HTTP error on attempt ${attempt + 1}: $e');

        if (attempt >= maxRetries) {
          return _createHttpErrorResponse<T>(operationName);
        }

        // Wait before retry
        await Future.delayed(_getRetryDelay(attempt));
      } on FormatException catch (e) {
        _logError(operationName, 'JSON parsing error: $e');
        // Format errors are not retryable
        return _createFormatErrorResponse<T>(operationName);
      } catch (e, stackTrace) {
        _logError(
          operationName,
          'Unknown error on attempt ${attempt + 1}: $e\n$stackTrace',
        );

        if (attempt >= maxRetries) {
          return _createUnknownErrorResponse<T>(operationName, e.toString());
        }

        // Wait before retry
        await Future.delayed(_getRetryDelay(attempt));
      }
    }

    // Should never reach here, but just in case
    return _createUnknownErrorResponse<T>(
      operationName,
      'Max retries exceeded',
    );
  }

  /// Get default HTTP headers for API requests
  Map<String, String> _getDefaultHeaders() {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'User-Agent': 'ChatAwayPlus/1.0.0 (Flutter Mobile App)',
      'Accept-Encoding': 'gzip, deflate, br',
      'Accept-Language': 'en-US,en;q=0.9',
      'Cache-Control': 'no-cache',
      'Connection': 'keep-alive',
    };
  }

  /// Parse error response from HTTP response
  Map<String, dynamic> _parseErrorResponse(http.Response response) {
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return {
        'message': body['message'] ?? body['error'] ?? 'Request failed',
        'errorCode': body['errorCode'] ?? body['code'] ?? 'UNKNOWN_ERROR',
        'details': body['details'],
      };
    } catch (e) {
      return {
        'message': 'Request failed with status ${response.statusCode}',
        'errorCode': 'HTTP_${response.statusCode}',
        'details': null,
      };
    }
  }

  /// Determine if request should be retried based on status code and attempt number
  bool _shouldRetry(int? statusCode, int attempt) {
    // Don't retry if max attempts reached
    if (attempt >= maxRetries) return false;

    // Retry server errors (5xx) and timeout-related errors
    if (statusCode == null) return true; // Network/timeout errors
    if (statusCode >= 500) return true; // Server errors
    if (statusCode == 429) return true; // Rate limiting

    // Don't retry client errors (4xx)
    return false;
  }

  /// Get delay duration for retry attempt using exponential backoff
  Duration _getRetryDelay(int attempt) {
    return baseRetryDelay * (attempt + 1);
  }

  /// Create timeout error response for given type
  T _createTimeoutErrorResponse<T extends AuthResponseModel>(
    String operationName,
  ) {
    const message =
        'Request timed out after multiple attempts. Please try again later.';

    if (T == OtpRequestResponseModel) {
      return OtpRequestResponseModel.error(message: message, statusCode: 408)
          as T;
    } else if (T == OtpVerificationResponseModel) {
      return OtpVerificationResponseModel.error(
            message: message,
            statusCode: 408,
          )
          as T;
    }

    throw UnimplementedError(
      'Timeout error response not implemented for type $T',
    );
  }

  /// Create network error response for given type
  T _createNetworkErrorResponse<T extends AuthResponseModel>(
    String operationName,
  ) {
    const message =
        'Network error: Please check your internet connection and try again.';

    if (T == OtpRequestResponseModel) {
      return OtpRequestResponseModel.error(message: message, statusCode: 0)
          as T;
    } else if (T == OtpVerificationResponseModel) {
      return OtpVerificationResponseModel.error(message: message, statusCode: 0)
          as T;
    }

    throw UnimplementedError(
      'Network error response not implemented for type $T',
    );
  }

  /// Create HTTP error response for given type
  T _createHttpErrorResponse<T extends AuthResponseModel>(
    String operationName,
  ) {
    const message =
        'Server error: Unable to process your request. Please try again.';

    if (T == OtpRequestResponseModel) {
      return OtpRequestResponseModel.error(message: message, statusCode: 500)
          as T;
    } else if (T == OtpVerificationResponseModel) {
      return OtpVerificationResponseModel.error(
            message: message,
            statusCode: 500,
          )
          as T;
    }

    throw UnimplementedError('HTTP error response not implemented for type $T');
  }

  /// Create format error response for given type
  T _createFormatErrorResponse<T extends AuthResponseModel>(
    String operationName,
  ) {
    const message =
        'Data format error: The server response could not be processed.';

    if (T == OtpRequestResponseModel) {
      return OtpRequestResponseModel.error(message: message, statusCode: 422)
          as T;
    } else if (T == OtpVerificationResponseModel) {
      return OtpVerificationResponseModel.error(
            message: message,
            statusCode: 422,
          )
          as T;
    }

    throw UnimplementedError(
      'Format error response not implemented for type $T',
    );
  }

  /// Create unknown error response for given type
  T _createUnknownErrorResponse<T extends AuthResponseModel>(
    String operationName,
    String error,
  ) {
    final message =
        'An unexpected error occurred: $error. Please try again later.';

    if (T == OtpRequestResponseModel) {
      return OtpRequestResponseModel.error(message: message, statusCode: 500)
          as T;
    } else if (T == OtpVerificationResponseModel) {
      return OtpVerificationResponseModel.error(
            message: message,
            statusCode: 500,
          )
          as T;
    }

    throw UnimplementedError(
      'Unknown error response not implemented for type $T',
    );
  }

  /// Log information message with optional data
  void _logInfo(
    String operation,
    String message, [
    Map<String, dynamic>? data,
  ]) {
    if (kDebugMode) {
      final dataStr = data != null ? ' | Data: $data' : '';
      print('🚀 AUTH_REMOTE [$operation]: $message$dataStr');
    }
  }

  /// Log error message
  void _logError(String operation, String message) {
    if (kDebugMode) {
      print('❌ AUTH_REMOTE [$operation]: $message');
    }
  }

  /// Log HTTP response details
  void _logResponse(String operation, http.Response response) {
    if (kDebugMode) {
      print(
        '📡 AUTH_REMOTE [$operation]: ${response.statusCode} | Body: ${response.body}',
      );
    }
  }

  /// Clean up resources
  void dispose() {
    httpClient.close();
  }
}

/// Mock implementation for testing
/// Provides controllable responses for unit testing
class MockAuthRemoteDataSource implements AuthRemoteDataSource {
  /// Controls the success/failure of sendOtp calls
  bool shouldSucceedSendOtp = true;

  /// Controls the success/failure of verifyOtp calls
  bool shouldSucceedVerifyOtp = true;

  /// Controls the success/failure of resendOtp calls
  bool shouldSucceedResendOtp = true;

  /// Delay to simulate network latency
  Duration networkDelay = const Duration(milliseconds: 500);

  /// Error message to return on failure
  String errorMessage = 'Mock error';

  @override
  Future<OtpRequestResponseModel> sendOtp(OtpRequestModel request) async {
    await Future.delayed(networkDelay);

    if (shouldSucceedSendOtp) {
      return OtpRequestResponseModel.success(
        message: 'Mock OTP sent successfully',
        requestId: 'mock-request-id',
      );
    } else {
      return OtpRequestResponseModel.error(
        message: errorMessage,
        statusCode: 400,
      );
    }
  }

  @override
  Future<OtpVerificationResponseModel> verifyOtp(
    OtpVerificationRequestModel request,
  ) async {
    await Future.delayed(networkDelay);

    if (shouldSucceedVerifyOtp) {
      return OtpVerificationResponseModel.success(
        authData: const AuthenticationData(
          token: 'mock-jwt-token',
          userId: 'mock-user-id',
        ),
        userProfile: UserProfileData(
          id: 'mock-user-id',
          mobileNo: request.mobileNo,
          firstName: 'Mock',
          lastName: 'User',
        ),
        message: 'Mock OTP verified successfully',
      );
    } else {
      return OtpVerificationResponseModel.error(
        message: errorMessage,
        statusCode: 400,
      );
    }
  }

  @override
  Future<OtpRequestResponseModel> resendOtp(
    ResendOtpRequestModel request,
  ) async {
    await Future.delayed(networkDelay);

    if (shouldSucceedResendOtp) {
      return OtpRequestResponseModel.success(
        message: 'Mock OTP resent successfully',
        requestId: 'mock-resend-request-id',
      );
    } else {
      return OtpRequestResponseModel.error(
        message: errorMessage,
        statusCode: 400,
      );
    }
  }
}
