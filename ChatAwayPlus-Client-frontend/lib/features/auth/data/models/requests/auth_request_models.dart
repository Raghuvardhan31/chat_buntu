// lib/features/auth/data/models/auth_request_models.dart

/// Base class for all authentication request models
/// Provides common validation and serialization functionality
abstract class AuthRequestModel {
  const AuthRequestModel();

  /// Convert model to JSON for API requests
  Map<String, dynamic> toJson();

  /// Validate the model data before sending to API
  bool isValid();

  /// Get validation error message if model is invalid
  String? get validationError;
}

/// Model for OTP request (mobile number registration/login)
/// Used when sending OTP to a mobile number
class OtpRequestModel extends AuthRequestModel {
  /// The mobile number to send OTP to (without country code)
  final String mobileNo;

  /// Optional country code (defaults to +91 for India)
  final String countryCode;

  const OtpRequestModel({required this.mobileNo, this.countryCode = '+91'});

  /// Create model from JSON response
  factory OtpRequestModel.fromJson(Map<String, dynamic> json) {
    return OtpRequestModel(
      mobileNo: json['mobileNo']?.toString() ?? '',
      countryCode: json['countryCode']?.toString() ?? '+91',
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {'mobileNo': mobileNo, 'countryCode': countryCode};
  }

  /// Validate mobile number format
  /// Mobile number should be 10 digits for Indian numbers
  @override
  bool isValid() {
    // Check if mobile number is not empty
    if (mobileNo.isEmpty) return false;

    // Check if mobile number contains only digits
    if (!RegExp(r'^\d+$').hasMatch(mobileNo)) return false;

    // For Indian numbers (+91), should be exactly 10 digits
    if (countryCode == '+91' && mobileNo.length != 10) return false;

    // Indian mobile numbers start with 6, 7, 8, or 9
    if (countryCode == '+91' && !RegExp(r'^[6-9]').hasMatch(mobileNo)) {
      return false;
    }

    return true;
  }

  @override
  String? get validationError {
    if (mobileNo.isEmpty) {
      return 'Mobile number is required';
    }

    if (!RegExp(r'^\d+$').hasMatch(mobileNo)) {
      return 'Mobile number should contain only digits';
    }

    if (countryCode == '+91') {
      if (mobileNo.length != 10) {
        return 'Mobile number should be exactly 10 digits';
      }

      if (!RegExp(r'^[6-9]').hasMatch(mobileNo)) {
        return 'Mobile number should start with 6, 7, 8, or 9';
      }
    }

    return null;
  }

  /// Get formatted mobile number with country code
  String get formattedNumber => '$countryCode$mobileNo';

  /// Get masked mobile number for display (e.g., ******1234)
  String get maskedNumber {
    if (mobileNo.length <= 4) return mobileNo;
    final masked = '*' * (mobileNo.length - 4);
    return masked + mobileNo.substring(mobileNo.length - 4);
  }

  /// Create a copy with updated values
  OtpRequestModel copyWith({String? mobileNo, String? countryCode}) {
    return OtpRequestModel(
      mobileNo: mobileNo ?? this.mobileNo,
      countryCode: countryCode ?? this.countryCode,
    );
  }

  @override
  String toString() =>
      'OtpRequestModel(mobileNo: $maskedNumber, countryCode: $countryCode)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OtpRequestModel &&
        other.mobileNo == mobileNo &&
        other.countryCode == countryCode;
  }

  @override
  int get hashCode => Object.hashAll([mobileNo, countryCode]);
}

/// Model for OTP verification request
/// Used when verifying the OTP sent to mobile number
class OtpVerificationRequestModel extends AuthRequestModel {
  /// The mobile number that received the OTP
  final String mobileNo;

  /// The OTP code entered by user
  final String otp;

  /// Optional country code (defaults to +91 for India)
  final String countryCode;

  /// Optional device information for security
  final String? deviceId;

  /// Optional FCM token for push notifications
  final String? fcmToken;

  const OtpVerificationRequestModel({
    required this.mobileNo,
    required this.otp,
    this.countryCode = '+91',
    this.deviceId,
    this.fcmToken,
  });

  /// Create model from JSON response
  factory OtpVerificationRequestModel.fromJson(Map<String, dynamic> json) {
    return OtpVerificationRequestModel(
      mobileNo: json['mobileNo']?.toString() ?? '',
      otp: json['otp']?.toString() ?? '',
      countryCode: json['countryCode']?.toString() ?? '+91',
      deviceId: json['deviceId']?.toString(),
      fcmToken: json['fcmToken']?.toString(),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'mobileNo': mobileNo,
      'otp': otp,
      'countryCode': countryCode,
    };

    // Add optional fields only if they exist
    if (deviceId != null) json['deviceId'] = deviceId;
    if (fcmToken != null) json['fcmToken'] = fcmToken;

    return json;
  }

  /// Validate OTP verification data
  @override
  bool isValid() {
    // Validate mobile number first
    final otpRequest = OtpRequestModel(
      mobileNo: mobileNo,
      countryCode: countryCode,
    );
    if (!otpRequest.isValid()) return false;

    // Validate OTP format
    if (otp.isEmpty) return false;
    if (otp.length != 6) return false;
    if (!RegExp(r'^\d{6}$').hasMatch(otp)) return false;

    return true;
  }

  @override
  String? get validationError {
    // Check mobile number validation first
    final otpRequest = OtpRequestModel(
      mobileNo: mobileNo,
      countryCode: countryCode,
    );
    final mobileError = otpRequest.validationError;
    if (mobileError != null) return mobileError;

    // Validate OTP
    if (otp.isEmpty) {
      return 'OTP is required';
    }

    if (otp.length != 6) {
      return 'OTP should be exactly 6 digits';
    }

    if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
      return 'OTP should contain only digits';
    }

    return null;
  }

  /// Get formatted mobile number with country code
  String get formattedNumber => '$countryCode$mobileNo';

  /// Get masked mobile number for display
  String get maskedNumber {
    if (mobileNo.length <= 4) return mobileNo;
    final masked = '*' * (mobileNo.length - 4);
    return masked + mobileNo.substring(mobileNo.length - 4);
  }

  /// Get masked OTP for logging (never log actual OTP)
  String get maskedOtp => '******';

  /// Create a copy with updated values
  OtpVerificationRequestModel copyWith({
    String? mobileNo,
    String? otp,
    String? countryCode,
    String? deviceId,
    String? fcmToken,
  }) {
    return OtpVerificationRequestModel(
      mobileNo: mobileNo ?? this.mobileNo,
      otp: otp ?? this.otp,
      countryCode: countryCode ?? this.countryCode,
      deviceId: deviceId ?? this.deviceId,
      fcmToken: fcmToken ?? this.fcmToken,
    );
  }

  @override
  String toString() =>
      'OtpVerificationRequestModel(mobileNo: $maskedNumber, otp: $maskedOtp, countryCode: $countryCode)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OtpVerificationRequestModel &&
        other.mobileNo == mobileNo &&
        other.otp == otp &&
        other.countryCode == countryCode &&
        other.deviceId == deviceId &&
        other.fcmToken == fcmToken;
  }

  @override
  int get hashCode =>
      Object.hashAll([mobileNo, otp, countryCode, deviceId, fcmToken]);
}

/// Model for resend OTP request
/// Used when user requests to resend OTP
class ResendOtpRequestModel extends AuthRequestModel {
  /// The mobile number to resend OTP to
  final String mobileNo;

  /// Optional country code (defaults to +91 for India)
  final String countryCode;

  /// Reason for resending (for analytics/logging)
  final String reason;

  /// Previous attempt count (for rate limiting)
  final int attemptCount;

  const ResendOtpRequestModel({
    required this.mobileNo,
    this.countryCode = '+91',
    this.reason = 'user_request',
    this.attemptCount = 1,
  });

  /// Create model from JSON response
  factory ResendOtpRequestModel.fromJson(Map<String, dynamic> json) {
    return ResendOtpRequestModel(
      mobileNo: json['mobileNo']?.toString() ?? '',
      countryCode: json['countryCode']?.toString() ?? '+91',
      reason: json['reason']?.toString() ?? 'user_request',
      attemptCount: json['attemptCount'] is int
          ? json['attemptCount'] as int
          : (json['attemptCount'] != null
                ? int.tryParse(json['attemptCount'].toString()) ?? 1
                : 1),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'mobileNo': mobileNo,
      'countryCode': countryCode,
      'reason': reason,
      'attemptCount': attemptCount,
    };
  }

  @override
  bool isValid() {
    // Validate using OtpRequestModel validation
    final otpRequest = OtpRequestModel(
      mobileNo: mobileNo,
      countryCode: countryCode,
    );
    return otpRequest.isValid() && attemptCount > 0;
  }

  @override
  String? get validationError {
    final otpRequest = OtpRequestModel(
      mobileNo: mobileNo,
      countryCode: countryCode,
    );
    final mobileError = otpRequest.validationError;
    if (mobileError != null) return mobileError;

    if (attemptCount <= 0) {
      return 'Invalid attempt count';
    }

    return null;
  }

  /// Get formatted mobile number with country code
  String get formattedNumber => '$countryCode$mobileNo';

  /// Get masked mobile number for display
  String get maskedNumber {
    if (mobileNo.length <= 4) return mobileNo;
    final masked = '*' * (mobileNo.length - 4);
    return masked + mobileNo.substring(mobileNo.length - 4);
  }

  /// Create a copy with updated values
  ResendOtpRequestModel copyWith({
    String? mobileNo,
    String? countryCode,
    String? reason,
    int? attemptCount,
  }) {
    return ResendOtpRequestModel(
      mobileNo: mobileNo ?? this.mobileNo,
      countryCode: countryCode ?? this.countryCode,
      reason: reason ?? this.reason,
      attemptCount: attemptCount ?? this.attemptCount,
    );
  }

  @override
  String toString() =>
      'ResendOtpRequestModel(mobileNo: $maskedNumber, reason: $reason, attemptCount: $attemptCount)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ResendOtpRequestModel &&
        other.mobileNo == mobileNo &&
        other.countryCode == countryCode &&
        other.reason == reason &&
        other.attemptCount == attemptCount;
  }

  @override
  int get hashCode =>
      Object.hashAll([mobileNo, countryCode, reason, attemptCount]);
}
