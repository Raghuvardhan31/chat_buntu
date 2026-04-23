import '../models/notification_model.dart';
import 'package:chataway_plus/features/chat/data/domain_models/responses/chat_response_models.dart';

/// Response model for getting notifications
class GetNotificationsResponseModel extends ChatResponseModel {
  final bool success;
  final List<NotificationModel>? data;
  final String? error;
  @override
  final int? statusCode;

  const GetNotificationsResponseModel({
    required this.success,
    this.data,
    this.error,
    this.statusCode,
  });

  factory GetNotificationsResponseModel.fromJson(Map<String, dynamic> json) {
    return GetNotificationsResponseModel(
      success: json['success'] == true,
      data: json['data'] != null
          ? (json['data'] as List<dynamic>)
                .map((e) => NotificationModel.fromJson(e as Map<String, dynamic>))
                .toList()
          : null,
      error: json['error']?.toString(),
      statusCode: json['statusCode'] as int?,
    );
  }

  factory GetNotificationsResponseModel.error({
    required String message,
    int? statusCode,
  }) {
    return GetNotificationsResponseModel(
      success: false,
      error: message,
      statusCode: statusCode,
    );
  }

  @override
  bool get isSuccess => success;

  @override
  String? get errorMessage => error;
}

/// Generic success/failure response for notification actions (read, delete)
class NotificationActionResponseModel extends ChatResponseModel {
  final bool success;
  final String? message;
  final String? error;
  @override
  final int? statusCode;

  const NotificationActionResponseModel({
    required this.success,
    this.message,
    this.error,
    this.statusCode,
  });

  factory NotificationActionResponseModel.fromJson(Map<String, dynamic> json) {
    return NotificationActionResponseModel(
      success: json['success'] == true,
      message: json['message']?.toString(),
      error: json['error']?.toString(),
      statusCode: json['statusCode'] as int?,
    );
  }

  factory NotificationActionResponseModel.error({
    required String message,
    int? statusCode,
  }) {
    return NotificationActionResponseModel(
      success: false,
      error: message,
      statusCode: statusCode,
    );
  }

  @override
  bool get isSuccess => success;

  @override
  String? get errorMessage => error;
}
