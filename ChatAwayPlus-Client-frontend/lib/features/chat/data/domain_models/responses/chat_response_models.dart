// lib/features/chat/data/domain_models/responses/chat_response_models.dart

import '../../../models/chat_message_model.dart';

/// Base class for all chat response models
/// Provides common functionality for API response handling
abstract class ChatResponseModel {
  const ChatResponseModel();

  /// Indicates if the API response was successful
  bool get isSuccess;

  /// Error message if the response failed
  String? get errorMessage;

  /// HTTP status code from the API response
  int? get statusCode;
}

/// Model for send message response
class SendMessageResponseModel extends ChatResponseModel {
  final bool success;
  final ChatMessageModel? data;
  final String? error;
  @override
  final int? statusCode;

  const SendMessageResponseModel({
    required this.success,
    this.data,
    this.error,
    this.statusCode,
  });

  factory SendMessageResponseModel.fromJson(Map<String, dynamic> json) {
    return SendMessageResponseModel(
      success: json['success'] == true,
      data: json['data'] != null
          ? ChatMessageModel.fromJson(json['data'] as Map<String, dynamic>)
          : null,
      error: json['error']?.toString(),
      statusCode: json['statusCode'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'data': data?.toJson(),
      'error': error,
      'statusCode': statusCode,
    };
  }

  factory SendMessageResponseModel.error({
    required String message,
    int? statusCode,
  }) {
    return SendMessageResponseModel(
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

/// Model for delete message response
class DeleteMessageResponseModel extends ChatResponseModel {
  final bool success;
  final String? message;
  final String? messageId;
  final String? error;
  @override
  final int? statusCode;

  const DeleteMessageResponseModel({
    required this.success,
    this.message,
    this.messageId,
    this.error,
    this.statusCode,
  });

  factory DeleteMessageResponseModel.fromJson(Map<String, dynamic> json) {
    return DeleteMessageResponseModel(
      success: json['success'] == true,
      message: json['message']?.toString(),
      messageId: json['messageId']?.toString(),
      error: json['error']?.toString(),
      statusCode: json['statusCode'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      'messageId': messageId,
      'error': error,
      'statusCode': statusCode,
    };
  }

  factory DeleteMessageResponseModel.error({
    required String message,
    int? statusCode,
  }) {
    return DeleteMessageResponseModel(
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

/// Model for message status information
class MessageStatusModel {
  final String id;
  final String messageStatus;
  final DateTime? deliveredAt;
  final DateTime? readAt;

  const MessageStatusModel({
    required this.id,
    required this.messageStatus,
    this.deliveredAt,
    this.readAt,
  });

  factory MessageStatusModel.fromJson(Map<String, dynamic> json) {
    return MessageStatusModel(
      id: json['id']?.toString() ?? '',
      messageStatus: json['messageStatus']?.toString() ?? 'sent',
      deliveredAt: json['deliveredAt'] != null
          ? DateTime.tryParse(json['deliveredAt'].toString())
          : null,
      readAt: json['readAt'] != null
          ? DateTime.tryParse(json['readAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'messageStatus': messageStatus,
      'deliveredAt': deliveredAt?.toIso8601String(),
      'readAt': readAt?.toIso8601String(),
    };
  }
}

/// Model for get message status response
class GetMessageStatusResponseModel extends ChatResponseModel {
  final bool success;
  final List<MessageStatusModel>? data;
  final String? error;
  @override
  final int? statusCode;

  const GetMessageStatusResponseModel({
    required this.success,
    this.data,
    this.error,
    this.statusCode,
  });

  factory GetMessageStatusResponseModel.fromJson(Map<String, dynamic> json) {
    return GetMessageStatusResponseModel(
      success: json['success'] == true,
      data: json['data'] != null
          ? (json['data'] as List<dynamic>)
                .map(
                  (e) => MessageStatusModel.fromJson(e as Map<String, dynamic>),
                )
                .toList()
          : null,
      error: json['error']?.toString(),
      statusCode: json['statusCode'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'data': data?.map((e) => e.toJson()).toList(),
      'error': error,
      'statusCode': statusCode,
    };
  }

  factory GetMessageStatusResponseModel.error({
    required String message,
    int? statusCode,
  }) {
    return GetMessageStatusResponseModel(
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

/// Model for pagination information
class PaginationModel {
  final int page;
  final int limit;
  final int total;
  final int totalPages;
  final bool? hasMore;
  final int? currentPageCount;

  const PaginationModel({
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
    this.hasMore,
    this.currentPageCount,
  });

  factory PaginationModel.fromJson(Map<String, dynamic> json) {
    bool? parseBool(dynamic raw) {
      if (raw is bool) return raw;
      final s = raw?.toString().toLowerCase();
      if (s == 'true') return true;
      if (s == 'false') return false;
      return null;
    }

    final currentPageCountRaw =
        json['currentPageCount'] ?? json['current_page_count'];

    return PaginationModel(
      page: json['page'] as int? ?? 1,
      limit: json['limit'] as int? ?? 50,
      total: json['total'] as int? ?? 0,
      totalPages: json['totalPages'] as int? ?? 0,
      hasMore: parseBool(json['hasMore'] ?? json['has_more']),
      currentPageCount: (currentPageCountRaw is num)
          ? currentPageCountRaw.toInt()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'page': page,
      'limit': limit,
      'total': total,
      'totalPages': totalPages,
      'hasMore': hasMore,
      'currentPageCount': currentPageCount,
    };
  }
}

/// Model for chat history response
class ChatHistoryResponseModel extends ChatResponseModel {
  final bool success;
  final List<ChatMessageModel>? messages;
  final bool? hasMore;
  final PaginationModel? pagination;
  final String? error;
  @override
  final int? statusCode;

  const ChatHistoryResponseModel({
    required this.success,
    this.messages,
    this.hasMore,
    this.pagination,
    this.error,
    this.statusCode,
  });

  factory ChatHistoryResponseModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    final pagination = (data is Map && data['pagination'] != null)
        ? PaginationModel.fromJson(
            Map<String, dynamic>.from(data['pagination'] as Map),
          )
        : null;

    bool? fallbackHasMoreFromPagination(PaginationModel? p) {
      if (p == null) return null;
      if (p.hasMore != null) return p.hasMore;
      if (p.totalPages > 0) return p.page < p.totalPages;
      if (p.total > 0 && p.limit > 0) return (p.page * p.limit) < p.total;
      return null;
    }

    final parsedHasMore = (data is Map)
        ? (data['hasMore'] is bool
              ? data['hasMore'] as bool
              : (data['hasMore']?.toString().toLowerCase() == 'true'
                    ? true
                    : (data['hasMore']?.toString().toLowerCase() == 'false'
                          ? false
                          : null)))
        : null;

    return ChatHistoryResponseModel(
      success: json['success'] == true,
      messages: data is Map && data['messages'] != null
          ? (data['messages'] as List<dynamic>)
                .map(
                  (e) => ChatMessageModel.fromJson(e as Map<String, dynamic>),
                )
                .toList()
          : null,
      hasMore: parsedHasMore ?? fallbackHasMoreFromPagination(pagination),
      pagination: pagination,
      error: json['error']?.toString(),
      statusCode: json['statusCode'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'data': {
        'messages': messages?.map((e) => e.toJson()).toList(),
        'hasMore': hasMore,
        'pagination': pagination?.toJson(),
      },
      'error': error,
      'statusCode': statusCode,
    };
  }

  factory ChatHistoryResponseModel.error({
    required String message,
    int? statusCode,
  }) {
    return ChatHistoryResponseModel(
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

/// Model for sync info from sync API
class SyncInfoModel {
  final String? currentSyncTime;
  final String? lastSyncTime;
  final String? conversationWith;

  const SyncInfoModel({
    this.currentSyncTime,
    this.lastSyncTime,
    this.conversationWith,
  });

  factory SyncInfoModel.fromJson(Map<String, dynamic> json) {
    return SyncInfoModel(
      currentSyncTime: json['currentSyncTime'] as String?,
      lastSyncTime: json['lastSyncTime'] as String?,
      conversationWith:
          json['conversationWith'] as String? ??
          json['conversation_with'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'currentSyncTime': currentSyncTime,
      'lastSyncTime': lastSyncTime,
      'conversationWith': conversationWith,
    };
  }
}

/// Model for sync messages response (optimized with last sync time)
class SyncMessagesResponseModel extends ChatResponseModel {
  final bool success;
  final List<ChatMessageModel>? messages;
  final bool? hasMore;
  final PaginationModel? pagination;
  final SyncInfoModel? syncInfo;
  final String? error;
  @override
  final int? statusCode;

  const SyncMessagesResponseModel({
    required this.success,
    this.messages,
    this.hasMore,
    this.pagination,
    this.syncInfo,
    this.error,
    this.statusCode,
  });

  factory SyncMessagesResponseModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    final pagination = (data is Map && data['pagination'] != null)
        ? PaginationModel.fromJson(
            Map<String, dynamic>.from(data['pagination'] as Map),
          )
        : null;

    bool? fallbackHasMoreFromPagination(PaginationModel? p) {
      if (p == null) return null;
      if (p.hasMore != null) return p.hasMore;
      if (p.totalPages > 0) return p.page < p.totalPages;
      if (p.total > 0 && p.limit > 0) return (p.page * p.limit) < p.total;
      return null;
    }

    bool? parseHasMore(dynamic raw) {
      if (raw is bool) return raw;
      final s = raw?.toString().toLowerCase();
      if (s == 'true') return true;
      if (s == 'false') return false;
      return null;
    }

    final parsedHasMore = (data is Map)
        ? parseHasMore(data['hasMore'] ?? data['has_more'])
        : null;

    return SyncMessagesResponseModel(
      success: json['success'] == true,
      messages: data is Map && data['messages'] != null
          ? (data['messages'] as List<dynamic>)
                .map(
                  (e) => ChatMessageModel.fromJson(e as Map<String, dynamic>),
                )
                .toList()
          : null,
      hasMore: parsedHasMore ?? fallbackHasMoreFromPagination(pagination),
      pagination: pagination,
      syncInfo: data is Map && data['syncInfo'] != null
          ? SyncInfoModel.fromJson(
              Map<String, dynamic>.from(data['syncInfo'] as Map),
            )
          : null,
      error: json['error']?.toString(),
      statusCode: json['statusCode'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'data': {
        'messages': messages?.map((e) => e.toJson()).toList(),
        'hasMore': hasMore,
        'pagination': pagination?.toJson(),
        'syncInfo': syncInfo?.toJson(),
      },
      'error': error,
      'statusCode': statusCode,
    };
  }

  factory SyncMessagesResponseModel.error({
    required String message,
    int? statusCode,
  }) {
    return SyncMessagesResponseModel(
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

/// Model for chat contacts response
class ChatContactsResponseModel extends ChatResponseModel {
  final bool success;
  final List<ChatContactModel>? data;
  final String? error;
  @override
  final int? statusCode;

  const ChatContactsResponseModel({
    required this.success,
    this.data,
    this.error,
    this.statusCode,
  });

  factory ChatContactsResponseModel.fromJson(Map<String, dynamic> json) {
    return ChatContactsResponseModel(
      success: json['success'] == true,
      data: json['data'] != null
          ? (json['data'] as List<dynamic>)
                .map(
                  (e) => ChatContactModel.fromJson(e as Map<String, dynamic>),
                )
                .toList()
          : null,
      error: json['error']?.toString(),
      statusCode: json['statusCode'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'data': data?.map((e) => e.toJson()).toList(),
      'error': error,
      'statusCode': statusCode,
    };
  }

  factory ChatContactsResponseModel.error({
    required String message,
    int? statusCode,
  }) {
    return ChatContactsResponseModel(
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

/// Model for unread count response
class UnreadCountResponseModel extends ChatResponseModel {
  final bool success;
  final int? unreadCount;
  final String? error;
  @override
  final int? statusCode;

  const UnreadCountResponseModel({
    required this.success,
    this.unreadCount,
    this.error,
    this.statusCode,
  });

  factory UnreadCountResponseModel.fromJson(Map<String, dynamic> json) {
    return UnreadCountResponseModel(
      success: json['success'] == true,
      unreadCount: json['data'] != null
          ? (json['data']['unreadCount'] as int?)
          : null,
      error: json['error']?.toString(),
      statusCode: json['statusCode'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'data': unreadCount != null ? {'unreadCount': unreadCount} : null,
      'error': error,
      'statusCode': statusCode,
    };
  }

  factory UnreadCountResponseModel.error({
    required String message,
    int? statusCode,
  }) {
    return UnreadCountResponseModel(
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
