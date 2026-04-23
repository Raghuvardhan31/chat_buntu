bool? _parseOptionalBool(dynamic v) {
  if (v is bool) return v;
  if (v is int) return v == 1;
  if (v is num) return v != 0;
  if (v is String) {
    final s = v.trim().toLowerCase();
    if (s == 'true' || s == '1' || s == 'yes') return true;
    if (s == 'false' || s == '0' || s == 'no') return false;
  }
  return null;
}

class StoreFcmTokenUserModel {
  final String? id;
  final String? email;
  final String? firstName;
  final String? lastName;
  final String? mobileNo;
  final bool? isVerified;
  final String? chatPicture;
  final String? chatPictureVersion;
  final Map<String, dynamic>? metadata;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const StoreFcmTokenUserModel({
    this.id,
    this.email,
    this.firstName,
    this.lastName,
    this.mobileNo,
    this.isVerified,
    this.chatPicture,
    this.chatPictureVersion,
    this.metadata,
    this.createdAt,
    this.updatedAt,
  });

  factory StoreFcmTokenUserModel.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? parseMetadata(dynamic v) {
      if (v is Map<String, dynamic>) return v;
      if (v is Map) return Map<String, dynamic>.from(v);
      return null;
    }

    DateTime? dt(dynamic v) =>
        (v is String && v.isNotEmpty) ? DateTime.tryParse(v) : null;

    return StoreFcmTokenUserModel(
      id: json['id']?.toString(),
      email: json['email']?.toString(),
      firstName: json['firstName']?.toString(),
      lastName: json['lastName']?.toString(),
      mobileNo: json['mobileNo']?.toString(),
      isVerified: _parseOptionalBool(json['isVerified']),
      chatPicture: (json['chat_picture'] ?? json['chatPicture'])?.toString(),
      chatPictureVersion:
          (json['chat_picture_version'] ?? json['chatPictureVersion'])
              ?.toString(),
      metadata: parseMetadata(json['metadata']),
      createdAt: dt(json['createdAt']),
      updatedAt: dt(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'mobileNo': mobileNo,
      'isVerified': isVerified,
      'chat_picture': chatPicture,
      'chat_picture_version': chatPictureVersion,
      'metadata': metadata,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}

class StoreFcmTokenDataModel {
  final StoreFcmTokenUserModel? user;
  final String? deviceTokenId;
  final bool? created;
  final String? message;

  const StoreFcmTokenDataModel({
    this.user,
    this.deviceTokenId,
    this.created,
    this.message,
  });

  factory StoreFcmTokenDataModel.fromJson(Map<String, dynamic> json) {
    final userJson = json['user'];
    return StoreFcmTokenDataModel(
      user: userJson is Map
          ? StoreFcmTokenUserModel.fromJson(Map<String, dynamic>.from(userJson))
          : null,
      deviceTokenId: (json['deviceTokenId'] ?? json['device_token_id'])
          ?.toString(),
      created: _parseOptionalBool(json['created']),
      message: (json['message'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user': user?.toJson(),
      'deviceTokenId': deviceTokenId,
      'created': created,
      'message': message,
    };
  }
}

class StoreFcmTokenResponseModel {
  final bool success;
  final String message;
  final StoreFcmTokenDataModel? data;
  final int? statusCode;

  const StoreFcmTokenResponseModel({
    required this.success,
    required this.message,
    this.data,
    this.statusCode,
  });

  factory StoreFcmTokenResponseModel.fromJson(
    Map<String, dynamic> json, {
    int? statusCode,
  }) {
    final dataJson = json['data'];
    final parsedData = dataJson is Map
        ? StoreFcmTokenDataModel.fromJson(Map<String, dynamic>.from(dataJson))
        : null;
    return StoreFcmTokenResponseModel(
      success: _parseOptionalBool(json['success']) ?? false,
      message: (json['message'] ?? '').toString().isNotEmpty
          ? (json['message'] ?? '').toString()
          : (parsedData?.message ?? '').toString(),
      data: parsedData,
      statusCode: statusCode,
    );
  }

  factory StoreFcmTokenResponseModel.error({
    required String message,
    int? statusCode,
  }) {
    return StoreFcmTokenResponseModel(
      success: false,
      message: message,
      data: null,
      statusCode: statusCode,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      'data': data?.toJson(),
      'statusCode': statusCode,
    };
  }
}
