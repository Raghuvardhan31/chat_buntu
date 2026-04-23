class DeleteUserResponseModel {
  final bool success;
  final String message;
  final int? statusCode;

  const DeleteUserResponseModel({
    required this.success,
    required this.message,
    this.statusCode,
  });

  factory DeleteUserResponseModel.fromJson(
    Map<String, dynamic> json, {
    int? statusCode,
  }) {
    return DeleteUserResponseModel(
      success: json['success'] as bool? ?? false,
      message: (json['message'] ?? '').toString(),
      statusCode: statusCode,
    );
  }

  factory DeleteUserResponseModel.error({
    required String message,
    int? statusCode,
  }) {
    return DeleteUserResponseModel(
      success: false,
      message: message,
      statusCode: statusCode,
    );
  }

  Map<String, dynamic> toJson() {
    return {'success': success, 'message': message, 'statusCode': statusCode};
  }
}
