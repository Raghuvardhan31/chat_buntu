class BlockedUserModel {
  final String userId;
  final String? firstName;
  final String? lastName;
  final String? chatPicture;

  const BlockedUserModel({
    required this.userId,
    this.firstName,
    this.lastName,
    this.chatPicture,
  });

  factory BlockedUserModel.fromMap(Map<String, dynamic> map) {
    final userId = (map['user_id'] ?? map['userId'] ?? map['id'])?.toString();
    return BlockedUserModel(
      userId: userId ?? '',
      firstName: map['first_name']?.toString() ?? map['firstName']?.toString(),
      lastName: map['last_name']?.toString() ?? map['lastName']?.toString(),
      chatPicture:
          map['chat_picture']?.toString() ?? map['profile_pic']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'first_name': firstName,
      'last_name': lastName,
      'chat_picture': chatPicture,
    };
  }

  String get displayName {
    final fn = (firstName ?? '').trim();
    final ln = (lastName ?? '').trim();
    if (fn.isEmpty && ln.isEmpty) return 'Unknown';
    if (ln.isEmpty) return fn;
    if (fn.isEmpty) return ln;
    return '$fn $ln';
  }
}

bool _isTruthy(dynamic value) {
  if (value == null) return false;
  if (value is bool) return value;
  if (value is num) return value != 0;
  final s = value.toString().trim().toLowerCase();
  return s == 'true' || s == '1' || s == 'yes' || s == 'y';
}

class BlockedContactUiModel {
  final String userId;
  final String name;
  final String mobile;
  final String? chatPictureUrl;

  const BlockedContactUiModel({
    required this.userId,
    required this.name,
    required this.mobile,
    this.chatPictureUrl,
  });
}

class BlockedUsersResponseModel {
  final bool success;
  final List<BlockedUserModel> data;
  final int count;
  final String? error;
  final int? statusCode;

  const BlockedUsersResponseModel({
    required this.success,
    required this.data,
    required this.count,
    this.error,
    this.statusCode,
  });

  factory BlockedUsersResponseModel.fromJson(
    Map<String, dynamic> json, {
    int? statusCode,
  }) {
    final raw = json['data'];
    final list = (raw is List)
        ? raw
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .map(BlockedUserModel.fromMap)
              .where((u) => u.userId.trim().isNotEmpty)
              .toList()
        : <BlockedUserModel>[];

    return BlockedUsersResponseModel(
      success: _isTruthy(json['success']),
      data: list,
      count: (json['count'] is int)
          ? json['count'] as int
          : int.tryParse((json['count'] ?? list.length).toString()) ??
                list.length,
      error: (json['error'] ?? json['message'])?.toString(),
      statusCode: statusCode,
    );
  }

  factory BlockedUsersResponseModel.error({
    required String error,
    int? statusCode,
  }) {
    return BlockedUsersResponseModel(
      success: false,
      data: const [],
      count: 0,
      error: error,
      statusCode: statusCode,
    );
  }

  bool get isSuccess => success;
}

class BlockActionResponseModel {
  final bool success;
  final String message;
  final int? statusCode;

  const BlockActionResponseModel({
    required this.success,
    required this.message,
    this.statusCode,
  });

  factory BlockActionResponseModel.fromJson(
    Map<String, dynamic> json, {
    int? statusCode,
  }) {
    final msg = (json['message'] ?? json['error'] ?? '').toString();
    return BlockActionResponseModel(
      success: _isTruthy(json['success']) || msg.trim().isNotEmpty,
      message: msg,
      statusCode: statusCode,
    );
  }

  factory BlockActionResponseModel.error({
    required String message,
    int? statusCode,
  }) {
    return BlockActionResponseModel(
      success: false,
      message: message,
      statusCode: statusCode,
    );
  }
}

class BlockActionResult {
  final bool isSuccess;
  final bool isPendingSync;
  final String message;
  final int? statusCode;

  const BlockActionResult({
    required this.isSuccess,
    required this.isPendingSync,
    required this.message,
    this.statusCode,
  });
}
