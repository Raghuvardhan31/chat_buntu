// lib/features/auth/data/models/auth_response_models.dart

import 'dart:convert';

/// Base class for all authentication response models
/// Provides common functionality for API response handling
abstract class AuthResponseModel {
  const AuthResponseModel();

  /// Indicates if the API response was successful
  bool get isSuccess;

  /// Error message if the response failed
  String? get errorMessage;

  /// HTTP status code from the API response
  int? get statusCode;
}

/// Model for OTP request response
/// Received after requesting OTP for a mobile number
class OtpRequestResponseModel extends AuthResponseModel {
  /// Whether the OTP was sent successfully
  final bool success;

  /// Message from the server (success or error message)
  final String message;

  /// HTTP status code from the response
  @override
  final int? statusCode;

  /// Unique request ID for tracking (optional)
  final String? requestId;

  /// Time when OTP was sent (for expiration calculation)
  final DateTime? sentAt;

  /// OTP expiration time in seconds (usually 90 or 120)
  final int? expiresInSeconds;

  /// Rate limiting information
  final RateLimitInfo? rateLimit;

  const OtpRequestResponseModel({
    required this.success,
    required this.message,
    this.statusCode,
    this.requestId,
    this.sentAt,
    this.expiresInSeconds,
    this.rateLimit,
  });

  /// Create model from API JSON response
  factory OtpRequestResponseModel.fromJson(Map<String, dynamic> json) {
    return OtpRequestResponseModel(
      success: json['success'] == true,
      message:
          json['message']?.toString() ??
          (json['success'] == true
              ? 'OTP sent successfully'
              : 'Failed to send OTP'),
      statusCode: json['statusCode'] is int
          ? json['statusCode'] as int
          : (json['statusCode'] != null
                ? int.tryParse(json['statusCode'].toString())
                : null),
      requestId: json['requestId']?.toString() ?? json['id']?.toString(),
      sentAt: json['sentAt'] != null
          ? DateTime.tryParse(json['sentAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      expiresInSeconds: json['expiresIn'] is int
          ? json['expiresIn'] as int
          : (json['expiresIn'] != null
                ? int.tryParse(json['expiresIn'].toString())
                : (json['expirationTime'] is int
                      ? json['expirationTime'] as int
                      : (json['expirationTime'] != null
                            ? int.tryParse(json['expirationTime'].toString())
                            : 90))),
      rateLimit: json['rateLimit'] != null
          ? RateLimitInfo.fromJson(json['rateLimit'])
          : null,
    );
  }

  /// Convert model to JSON
  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      'statusCode': statusCode,
      'requestId': requestId,
      'sentAt': sentAt?.toIso8601String(),
      'expiresInSeconds': expiresInSeconds,
      'rateLimit': rateLimit?.toJson(),
    };
  }

  /// Create error response
  factory OtpRequestResponseModel.error({
    required String message,
    int? statusCode,
    RateLimitInfo? rateLimit,
  }) {
    return OtpRequestResponseModel(
      success: false,
      message: message,
      statusCode: statusCode,
      rateLimit: rateLimit,
    );
  }

  /// Create success response
  factory OtpRequestResponseModel.success({
    String message = 'OTP sent successfully',
    String? requestId,
    int expiresInSeconds = 90,
  }) {
    return OtpRequestResponseModel(
      success: true,
      message: message,
      requestId: requestId,
      sentAt: DateTime.now(),
      expiresInSeconds: expiresInSeconds,
    );
  }

  @override
  bool get isSuccess => success;

  @override
  String? get errorMessage => success ? null : message;

  /// Check if OTP has expired based on sent time and expiration
  bool get isExpired {
    if (sentAt == null || expiresInSeconds == null) return false;
    final now = DateTime.now();
    final expirationTime = sentAt!.add(Duration(seconds: expiresInSeconds!));
    return now.isAfter(expirationTime);
  }

  /// Get remaining time in seconds before OTP expires
  int get remainingSeconds {
    if (sentAt == null || expiresInSeconds == null) return 0;
    final now = DateTime.now();
    final expirationTime = sentAt!.add(Duration(seconds: expiresInSeconds!));
    if (now.isAfter(expirationTime)) return 0;
    return expirationTime.difference(now).inSeconds;
  }

  @override
  String toString() =>
      'OtpRequestResponseModel(success: $success, message: $message)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OtpRequestResponseModel &&
        other.success == success &&
        other.message == message &&
        other.statusCode == statusCode &&
        other.requestId == requestId &&
        other.sentAt == sentAt &&
        other.expiresInSeconds == expiresInSeconds &&
        other.rateLimit == rateLimit;
  }

  @override
  int get hashCode => Object.hashAll([
    success,
    message,
    statusCode,
    requestId,
    sentAt,
    expiresInSeconds,
    rateLimit,
  ]);
}

/// Model for OTP verification response
/// Received after verifying the OTP code
class OtpVerificationResponseModel extends AuthResponseModel {
  /// Whether the OTP verification was successful
  final bool success;

  /// Message from the server
  final String message;

  /// HTTP status code from the response
  @override
  final int? statusCode;

  /// Authentication data if verification was successful
  final AuthenticationData? authData;

  /// User profile data if available
  final UserProfileData? userProfile;

  /// Session information
  final SessionInfo? sessionInfo;

  const OtpVerificationResponseModel({
    required this.success,
    required this.message,
    this.statusCode,
    this.authData,
    this.userProfile,
    this.sessionInfo,
  });

  /// Create model from API JSON response
  factory OtpVerificationResponseModel.fromJson(Map<String, dynamic> json) {
    return OtpVerificationResponseModel(
      success: json['success'] == true,
      message:
          json['message']?.toString() ??
          (json['success'] == true
              ? 'OTP verified successfully'
              : 'Invalid OTP'),
      statusCode: json['statusCode'] is int
          ? json['statusCode'] as int
          : (json['statusCode'] != null
                ? int.tryParse(json['statusCode'].toString())
                : null),
      authData: json['data'] != null
          ? AuthenticationData.fromJson(json['data'])
          : null,
      userProfile: json['user'] != null
          ? UserProfileData.fromJson(json['user'])
          : (json['data']?['user'] != null
                ? UserProfileData.fromJson(json['data']['user'])
                : null),
      sessionInfo: json['session'] != null
          ? SessionInfo.fromJson(json['session'])
          : null,
    );
  }

  /// Convert model to JSON
  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      'statusCode': statusCode,
      'data': authData?.toJson(),
      'user': userProfile?.toJson(),
      'session': sessionInfo?.toJson(),
    };
  }

  /// Create error response
  factory OtpVerificationResponseModel.error({
    required String message,
    int? statusCode,
  }) {
    return OtpVerificationResponseModel(
      success: false,
      message: message,
      statusCode: statusCode,
    );
  }

  /// Create success response
  factory OtpVerificationResponseModel.success({
    required AuthenticationData authData,
    UserProfileData? userProfile,
    SessionInfo? sessionInfo,
    String message = 'OTP verified successfully',
  }) {
    return OtpVerificationResponseModel(
      success: true,
      message: message,
      authData: authData,
      userProfile: userProfile,
      sessionInfo: sessionInfo,
    );
  }

  @override
  bool get isSuccess => success;

  @override
  String? get errorMessage => success ? null : message;

  /// Check if user is authenticated (has valid token)
  bool get isAuthenticated => success && authData?.token.isNotEmpty == true;

  /// Check if user profile is complete
  bool get isProfileComplete {
    if (userProfile == null) return false;
    return userProfile!.isComplete;
  }

  @override
  String toString() =>
      'OtpVerificationResponseModel(success: $success, isAuthenticated: $isAuthenticated)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OtpVerificationResponseModel &&
        other.success == success &&
        other.message == message &&
        other.statusCode == statusCode &&
        other.authData == authData &&
        other.userProfile == userProfile &&
        other.sessionInfo == sessionInfo;
  }

  @override
  int get hashCode => Object.hashAll([
    success,
    message,
    statusCode,
    authData,
    userProfile,
    sessionInfo,
  ]);
}

/// Authentication data from successful OTP verification
class AuthenticationData {
  /// JWT authentication token
  final String token;

  /// Token type (usually "Bearer")
  final String tokenType;

  /// Token expiration time
  final DateTime? expiresAt;

  /// Refresh token for getting new access tokens
  final String? refreshToken;

  /// User ID from the authentication system
  final String userId;

  /// Device ID for this authentication session
  final String? deviceId;

  const AuthenticationData({
    required this.token,
    required this.userId,
    this.tokenType = 'Bearer',
    this.expiresAt,
    this.refreshToken,
    this.deviceId,
  });

  /// Create from JSON response
  factory AuthenticationData.fromJson(Map<String, dynamic> json) {
    return AuthenticationData(
      token: json['token']?.toString() ?? '',
      tokenType:
          json['tokenType']?.toString() ??
          json['token_type']?.toString() ??
          'Bearer',
      userId:
          json['userId']?.toString() ??
          json['user_id']?.toString() ??
          json['user']?['id']?.toString() ??
          '',
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'].toString())
          : (json['expires_at'] != null
                ? DateTime.tryParse(json['expires_at'].toString())
                : null),
      refreshToken:
          json['refreshToken']?.toString() ?? json['refresh_token']?.toString(),
      deviceId: json['deviceId']?.toString() ?? json['device_id']?.toString(),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'tokenType': tokenType,
      'userId': userId,
      'expiresAt': expiresAt?.toIso8601String(),
      'refreshToken': refreshToken,
      'deviceId': deviceId,
    };
  }

  /// Check if token is expired
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// Get formatted authorization header value
  String get authorizationHeader => '$tokenType $token';

  @override
  String toString() =>
      'AuthenticationData(userId: $userId, tokenType: $tokenType, isExpired: $isExpired)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AuthenticationData &&
        other.token == token &&
        other.tokenType == tokenType &&
        other.expiresAt == expiresAt &&
        other.refreshToken == refreshToken &&
        other.userId == userId &&
        other.deviceId == deviceId;
  }

  @override
  int get hashCode => Object.hashAll([
    token,
    tokenType,
    expiresAt,
    refreshToken,
    userId,
    deviceId,
  ]);
}

/// User profile data from authentication response
class UserProfileData {
  /// User's unique identifier
  final String id;

  /// Mobile number
  final String mobileNo;

  /// First name (optional)
  final String? firstName;

  /// Last name (optional)
  final String? lastName;

  /// Profile picture URL (optional)
  final String? chatPictureUrl;

  /// User status/bio (optional)
  final String? status;

  /// Whether profile is verified
  final bool isVerified;

  /// Account creation timestamp
  final DateTime? createdAt;

  /// Last activity timestamp
  final DateTime? lastActiveAt;

  const UserProfileData({
    required this.id,
    required this.mobileNo,
    this.firstName,
    this.lastName,
    this.chatPictureUrl,
    this.status,
    this.isVerified = false,
    this.createdAt,
    this.lastActiveAt,
  });

  /// Create from JSON response
  factory UserProfileData.fromJson(Map<String, dynamic> json) {
    return UserProfileData(
      id: json['id']?.toString() ?? '',
      mobileNo:
          json['mobileNo']?.toString() ??
          json['mobile_no']?.toString() ??
          json['phone']?.toString() ??
          '',
      firstName:
          json['firstName']?.toString() ?? json['first_name']?.toString(),
      lastName: json['lastName']?.toString() ?? json['last_name']?.toString(),
      chatPictureUrl:
          json['chatPictureUrl']?.toString() ??
          json['chat_picture']?.toString() ??
          json['profile'
                  'PicUrl']
              ?.toString() ??
          json['profile_pic_url']?.toString() ??
          json['avatar']?.toString(),
      status:
          json['status']?.toString() ??
          json['content']?.toString() ??
          json['bio']?.toString(),
      isVerified:
          json['isVerified'] == true ||
          json['is_verified'] == true ||
          json['verified'] == true,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : (json['created_at'] != null
                ? DateTime.tryParse(json['created_at'].toString())
                : null),
      lastActiveAt: json['lastActiveAt'] != null
          ? DateTime.tryParse(json['lastActiveAt'].toString())
          : (json['last_active_at'] != null
                ? DateTime.tryParse(json['last_active_at'].toString())
                : null),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'mobileNo': mobileNo,
      'firstName': firstName,
      'lastName': lastName,
      'chatPictureUrl': chatPictureUrl,
      'profile'
              'PicUrl':
          chatPictureUrl,
      'status': status,
      'isVerified': isVerified,
      'createdAt': createdAt?.toIso8601String(),
      'lastActiveAt': lastActiveAt?.toIso8601String(),
    };
  }

  /// Get full display name
  String get displayName {
    if (firstName != null && lastName != null) {
      return '$firstName $lastName'.trim();
    }
    if (firstName != null) return firstName!;
    if (lastName != null) return lastName!;
    return mobileNo; // Fallback to mobile number
  }

  /// Get initials for avatar
  String get initials {
    if (firstName != null && firstName!.isNotEmpty) {
      final first = firstName![0].toUpperCase();
      final last = lastName?.isNotEmpty == true
          ? lastName![0].toUpperCase()
          : '';
      return '$first$last';
    }
    return mobileNo.isNotEmpty ? mobileNo[0] : 'U';
  }

  /// Check if profile is considered complete
  bool get isComplete {
    return firstName?.isNotEmpty == true && status?.isNotEmpty == true;
  }

  /// Get masked mobile number for display
  String get maskedMobileNo {
    if (mobileNo.length <= 4) return mobileNo;
    final masked = '*' * (mobileNo.length - 4);
    return masked + mobileNo.substring(mobileNo.length - 4);
  }

  @override
  String toString() =>
      'UserProfileData(id: $id, displayName: $displayName, isComplete: $isComplete)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserProfileData &&
        other.id == id &&
        other.mobileNo == mobileNo &&
        other.firstName == firstName &&
        other.lastName == lastName &&
        other.chatPictureUrl == chatPictureUrl &&
        other.status == status &&
        other.isVerified == isVerified &&
        other.createdAt == createdAt &&
        other.lastActiveAt == lastActiveAt;
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    mobileNo,
    firstName,
    lastName,
    chatPictureUrl,
    status,
    isVerified,
    createdAt,
    lastActiveAt,
  ]);
}

/// Session information for the authenticated user
class SessionInfo {
  /// Session ID
  final String sessionId;

  /// Device information
  final String? deviceInfo;

  /// IP address of the session
  final String? ipAddress;

  /// Session creation time
  final DateTime createdAt;

  /// Session expiration time
  final DateTime? expiresAt;

  /// Whether this is the first login
  final bool isFirstLogin;

  const SessionInfo({
    required this.sessionId,
    required this.createdAt,
    this.deviceInfo,
    this.ipAddress,
    this.expiresAt,
    this.isFirstLogin = false,
  });

  /// Create from JSON response
  factory SessionInfo.fromJson(Map<String, dynamic> json) {
    return SessionInfo(
      sessionId:
          json['sessionId']?.toString() ?? json['session_id']?.toString() ?? '',
      deviceInfo:
          json['deviceInfo']?.toString() ?? json['device_info']?.toString(),
      ipAddress:
          json['ipAddress']?.toString() ?? json['ip_address']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : (json['created_at'] != null
                ? DateTime.tryParse(json['created_at'].toString()) ??
                      DateTime.now()
                : DateTime.now()),
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'].toString())
          : (json['expires_at'] != null
                ? DateTime.tryParse(json['expires_at'].toString())
                : null),
      isFirstLogin:
          json['isFirstLogin'] == true ||
          json['is_first_login'] == true ||
          json['first_login'] == true,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'deviceInfo': deviceInfo,
      'ipAddress': ipAddress,
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
      'isFirstLogin': isFirstLogin,
    };
  }

  /// Check if session is expired
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  @override
  String toString() =>
      'SessionInfo(sessionId: $sessionId, isFirstLogin: $isFirstLogin, isExpired: $isExpired)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SessionInfo &&
        other.sessionId == sessionId &&
        other.deviceInfo == deviceInfo &&
        other.ipAddress == ipAddress &&
        other.createdAt == createdAt &&
        other.expiresAt == expiresAt &&
        other.isFirstLogin == isFirstLogin;
  }

  @override
  int get hashCode => Object.hashAll([
    sessionId,
    deviceInfo,
    ipAddress,
    createdAt,
    expiresAt,
    isFirstLogin,
  ]);
}

/// Rate limiting information
class RateLimitInfo {
  /// Maximum requests allowed in the time window
  final int maxRequests;

  /// Time window in seconds
  final int windowSeconds;

  /// Remaining requests in current window
  final int remainingRequests;

  /// Time when the window resets
  final DateTime resetTime;

  const RateLimitInfo({
    required this.maxRequests,
    required this.windowSeconds,
    required this.remainingRequests,
    required this.resetTime,
  });

  /// Create from JSON response
  factory RateLimitInfo.fromJson(Map<String, dynamic> json) {
    final maxReq = json['maxRequests'] is int
        ? json['maxRequests'] as int
        : (json['max_requests'] is int
              ? json['max_requests'] as int
              : (json['max_requests'] != null
                    ? int.tryParse(json['max_requests'].toString())
                    : 5));
    final window = json['windowSeconds'] is int
        ? json['windowSeconds'] as int
        : (json['window_seconds'] is int
              ? json['window_seconds'] as int
              : (json['window_seconds'] != null
                    ? int.tryParse(json['window_seconds'].toString())
                    : 3600));
    final remaining = json['remainingRequests'] is int
        ? json['remainingRequests'] as int
        : (json['remaining_requests'] is int
              ? json['remaining_requests'] as int
              : (json['remaining_requests'] != null
                    ? int.tryParse(json['remaining_requests'].toString())
                    : maxReq));
    final reset = json['resetTime'] != null
        ? DateTime.tryParse(json['resetTime'].toString()) ?? DateTime.now()
        : (json['reset_time'] != null
              ? DateTime.tryParse(json['reset_time'].toString()) ??
                    DateTime.now()
              : DateTime.now().add(Duration(seconds: window ?? 3600)));

    return RateLimitInfo(
      maxRequests: maxReq ?? 0,
      windowSeconds: window ?? 0,
      remainingRequests: remaining ?? 0,
      resetTime: reset,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'maxRequests': maxRequests,
      'windowSeconds': windowSeconds,
      'remainingRequests': remainingRequests,
      'resetTime': resetTime.toIso8601String(),
    };
  }

  /// Check if rate limit is exceeded
  bool get isExceeded => remainingRequests <= 0;

  /// Get seconds until reset
  int get secondsUntilReset {
    final now = DateTime.now();
    if (now.isAfter(resetTime)) return 0;
    return resetTime.difference(now).inSeconds;
  }

  @override
  String toString() =>
      'RateLimitInfo(remaining: $remainingRequests/$maxRequests, resetIn: ${secondsUntilReset}s)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RateLimitInfo &&
        other.maxRequests == maxRequests &&
        other.windowSeconds == windowSeconds &&
        other.remainingRequests == remainingRequests &&
        other.resetTime == resetTime;
  }

  @override
  int get hashCode => Object.hashAll([
    maxRequests,
    windowSeconds,
    remainingRequests,
    resetTime,
  ]);
}

/// Common API error response model
class ApiErrorResponse extends AuthResponseModel {
  /// Error code from the API
  final String errorCode;

  /// Human readable error message
  final String message;

  /// HTTP status code
  @override
  final int statusCode;

  /// Additional error details
  final Map<String, dynamic>? details;

  /// Timestamp when error occurred
  final DateTime timestamp;

  ApiErrorResponse({
    required this.errorCode,
    required this.message,
    required this.statusCode,
    this.details,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create from JSON response
  factory ApiErrorResponse.fromJson(Map<String, dynamic> json, int statusCode) {
    return ApiErrorResponse(
      errorCode:
          json['errorCode']?.toString() ??
          json['error_code']?.toString() ??
          json['code']?.toString() ??
          'UNKNOWN_ERROR',
      message:
          json['message']?.toString() ??
          json['error']?.toString() ??
          'An unknown error occurred',
      statusCode: statusCode,
      details: json['details'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['details'])
          : null,
      timestamp: json['timestamp'] != null
          ? (DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'errorCode': errorCode,
      'message': message,
      'statusCode': statusCode,
      'details': details,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  @override
  bool get isSuccess => false;

  @override
  String? get errorMessage => message;

  @override
  String toString() =>
      'ApiErrorResponse(code: $errorCode, message: $message, status: $statusCode)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ApiErrorResponse &&
        other.errorCode == errorCode &&
        other.message == message &&
        other.statusCode == statusCode &&
        _mapEquals(other.details, details) &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode => Object.hashAll([
    errorCode,
    message,
    statusCode,
    _mapHash(details),
    timestamp,
  ]);

  // small helpers for map equality/hash (since we removed Equatable)
  static bool _mapEquals(Map<String, dynamic>? a, Map<String, dynamic>? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return a == b;
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || a[key] != b[key]) return false;
    }
    return true;
  }

  static int _mapHash(Map<String, dynamic>? m) {
    if (m == null) return 0;
    // stable-ish hash: combine key/value pairs
    final pairs =
        m.entries.map((e) => '${e.key}:${jsonEncode(e.value)}').toList()
          ..sort();
    return Object.hashAll(pairs);
  }
}
