import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:chataway_plus/features/chat/data/socket/socket_models/index.dart';

/// Model representing a user in chat context
class ChatUserModel {
  final String id;
  final String firstName;
  final String lastName;
  final String mobileNo;
  final String? chatPictureUrl;

  ChatUserModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.mobileNo,
    this.chatPictureUrl,
  });

  factory ChatUserModel.fromJson(Map<String, dynamic> json) {
    return ChatUserModel(
      id: (json['id'] as String?) ?? '',
      firstName: (json['firstName'] as String?) ?? '',
      lastName: (json['lastName'] as String?) ?? '',
      mobileNo: (json['mobileNo'] as String?) ?? '',
      chatPictureUrl:
          (json['chatPictureUrl'] ??
                  json['chat_picture'] ??
                  json['profile'
                      'PicUrl'] ??
                  json['profile_pic_url'] ??
                  json['profile_pic'])
              ?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'mobileNo': mobileNo,
      'chatPictureUrl': chatPictureUrl,
    };
  }

  String get fullName => '$firstName $lastName';
}

/// Message type enum for different content types
enum MessageType {
  text,
  deleted,
  image,
  video,
  audio,
  document,
  location,
  contact,
  poll,
}

/// Model representing a chat message
class ChatMessageModel {
  final String id;
  final String senderId;
  final String receiverId;
  final String message;
  final String? reactionsJson;
  final bool isStarred;
  final bool isEdited;
  final DateTime? editedAt;
  final String messageStatus; // 'sent', 'delivered', 'read'
  final bool isRead;
  final DateTime? deliveredAt;
  final DateTime? readAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String deliveryChannel; // 'socket' or 'fcm'
  final String? receiverDeliveryChannel; // 'socket', 'fcm', or null
  final ChatUserModel? sender;
  final ChatUserModel? receiver;

  // Media message fields
  final MessageType messageType;
  final String? imageUrl; // Server URL after upload
  final String? thumbnailUrl; // Compressed thumbnail URL
  final String? localImagePath; // Local file path before upload
  final int? imageWidth;
  final int? imageHeight;
  final int? fileSize; // File size in bytes
  final String? mimeType;
  final String? fileName;
  final int? pageCount;

  // Audio message fields
  final double? audioDuration; // Duration in seconds for audio messages

  // Follow-up message flag (sender-only feature)
  final bool isFollowUp;

  // Client message ID for matching local messages with server confirmations
  // This is set when server returns clientMessageId in message-sent event
  final String? clientMessageId;

  // Reply-to message fields for swipe-to-reply feature
  final String? replyToMessageId; // UUID of the message being replied to
  final ChatMessageModel?
  replyToMessage; // The replied-to message data (eager loaded)

  ChatMessageModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.message,
    this.reactionsJson,
    this.isStarred = false,
    this.isEdited = false,
    this.editedAt,
    required this.messageStatus,
    required this.isRead,
    this.deliveredAt,
    this.readAt,
    required this.createdAt,
    required this.updatedAt,
    this.deliveryChannel = 'socket',
    this.receiverDeliveryChannel,
    this.sender,
    this.receiver,
    this.messageType = MessageType.text,
    this.imageUrl,
    this.thumbnailUrl,
    this.localImagePath,
    this.imageWidth,
    this.imageHeight,
    this.fileSize,
    this.mimeType,
    this.fileName,
    this.pageCount,
    this.audioDuration,
    this.isFollowUp = false,
    this.clientMessageId,
    this.replyToMessageId,
    this.replyToMessage,
  });

  static String _normalizedContactJson(dynamic raw) {
    if (raw is! Map) return '';
    final data = Map<String, dynamic>.from(raw);
    final normalized = <String, dynamic>{
      'name':
          data['name']?.toString() ??
          data['contact_name']?.toString() ??
          data['contactName']?.toString() ??
          'Unknown',
      'phone':
          data['phone']?.toString() ??
          data['contact_mobile_number']?.toString() ??
          data['mobile']?.toString() ??
          '',
    };
    return jsonEncode(normalized);
  }

  static bool _looksLikeLocationJson(String raw) {
    final t = raw.trim();
    if (!t.startsWith('{') || !t.endsWith('}')) return false;
    try {
      final decoded = jsonDecode(t);
      if (decoded is! Map) return false;
      final map = Map<String, dynamic>.from(decoded);
      final hasLat = map.containsKey('latitude') || map.containsKey('lat');
      final hasLng =
          map.containsKey('longitude') ||
          map.containsKey('lng') ||
          map.containsKey('lon');
      if (!hasLat || !hasLng) return false;
      final latRaw = map['latitude'] ?? map['lat'];
      final lngRaw = map['longitude'] ?? map['lng'] ?? map['lon'];
      final lat = _tryParseDouble(latRaw);
      final lng = _tryParseDouble(lngRaw);
      return lat != null && lng != null;
    } catch (_) {
      return false;
    }
  }

  static bool _looksLikeLatLngText(String raw) {
    final t = raw.trim();
    final m = RegExp(
      r'^-?\d{1,3}(?:\.\d+)?\s*,\s*-?\d{1,3}(?:\.\d+)?$',
    ).firstMatch(t);
    if (m == null) return false;
    final parts = t.split(',');
    if (parts.length < 2) return false;
    final lat = _tryParseDouble(parts[0].trim());
    final lng = _tryParseDouble(parts[1].trim());
    if (lat == null || lng == null) return false;
    if (lat < -90 || lat > 90) return false;
    if (lng < -180 || lng > 180) return false;
    return true;
  }

  static String _normalizeLatLngTextToJson(String raw) {
    final t = raw.trim();
    final parts = t.split(',');
    if (parts.length < 2) return raw;
    final lat = _tryParseDouble(parts[0].trim());
    final lng = _tryParseDouble(parts[1].trim());
    if (lat == null || lng == null) return raw;
    return jsonEncode(<String, dynamic>{'latitude': lat, 'longitude': lng});
  }

  static String _normalizeLocationJsonString(String raw) {
    final t = raw.trim();
    try {
      final decoded = jsonDecode(t);
      if (decoded is! Map) return raw;
      final map = Map<String, dynamic>.from(decoded);
      final lat = _tryParseDouble(map['latitude'] ?? map['lat']);
      final lng = _tryParseDouble(map['longitude'] ?? map['lng'] ?? map['lon']);
      if (lat == null || lng == null) return raw;
      final normalized = <String, dynamic>{
        'latitude': lat,
        'longitude': lng,
        'address': map['address']?.toString(),
        'placeName': map['placeName']?.toString(),
        'timestamp': map['timestamp']?.toString(),
      };
      normalized.removeWhere((_, v) => v == null || v.toString().isEmpty);
      return jsonEncode(normalized);
    } catch (_) {
      return raw;
    }
  }

  /// Check if this is an image message
  bool get isImageMessage => messageType == MessageType.image;

  /// Check if this is a media message (image, video, audio, document)
  bool get isMediaMessage =>
      messageType == MessageType.image ||
      messageType == MessageType.video ||
      messageType == MessageType.audio ||
      messageType == MessageType.document;

  /// Get display image path (local or remote)
  String? get displayImagePath => localImagePath ?? imageUrl;

  /// Parse reactions from JSON string
  List<MessageReaction> get reactions {
    if (reactionsJson == null || reactionsJson!.isEmpty) {
      return [];
    }

    try {
      final dynamic decoded = jsonDecode(reactionsJson!);
      if (decoded is List) {
        return decoded
            .map(
              (r) =>
                  MessageReaction.fromJson(Map<String, dynamic>.from(r as Map)),
            )
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Get reaction count
  int get reactionCount => reactions.length;

  /// Check if message has reactions
  bool get hasReactions => reactionsJson != null && reactionsJson!.isNotEmpty;

  static int? _tryParseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  static double? _tryParseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static bool _tryParseBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) return value == 1;
    final s = value.toString().toLowerCase();
    return s == 'true' || s == '1';
  }

  static DateTime? _tryParseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    final s = value.toString();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  static String normalizeMessageStatus(String? status, {bool isRead = false}) {
    final raw = (status ?? '').toString().toLowerCase().trim();
    final s = raw.replaceAll('-', '_');

    if (s == 'read' || s == 'seen') return 'read';
    if (isRead) return 'read';

    switch (s) {
      case 'delivered':
      case 'received':
      case 'delivered_to':
      case 'delivered_to_device':
        return 'delivered';
      case 'sent':
      case 'server_received':
      case 'submitted':
        return 'sent';
      case 'sending':
      case 'uploading':
      case 'in_progress':
        return 'sending';
      case 'pending':
      case 'pending_sync':
      case 'queued':
      case 'offline':
      case 'retrying':
      case 'waiting':
        return 'pending_sync';
      case 'failed':
      case 'error':
      case 'undelivered':
        return 'failed';
      default:
        return s.isEmpty ? 'sent' : s;
    }
  }

  static int messageStatusPriority(String? status, {bool isRead = false}) {
    final s = normalizeMessageStatus(status, isRead: isRead);
    switch (s) {
      case 'read':
        return 3;
      case 'delivered':
        return 2;
      case 'sent':
        return 1;
      case 'sending':
      case 'pending_sync':
        return 0;
      case 'failed':
        return -1;
      default:
        return 0;
    }
  }

  static Map<String, dynamic>? _parseFileMetadata(dynamic raw) {
    try {
      if (raw == null) return null;
      if (raw is Map) {
        return Map<String, dynamic>.from(raw);
      }
      if (raw is String) {
        final s = raw.trim();
        if (s.isEmpty) return null;
        final decoded = jsonDecode(s);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      }
    } catch (_) {}
    return null;
  }

  static MessageType parseMessageType(String? type) => _parseMessageType(type);

  // Factory constructor to create a ChatMessageModel from JSON
  // Handles nullable fields from backend (messageObject in status updates)
  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    // Parse createdAt/updatedAt with fallback to now
    final now = DateTime.now();

    final reactionsRaw =
        json['reactionsJson'] ?? json['reactions_json'] ?? json['reactions'];
    final reactionsJson = reactionsRaw == null
        ? null
        : (reactionsRaw is String ? reactionsRaw : jsonEncode(reactionsRaw));

    final fileUrl =
        (json['fileUrl'] ?? json['file_url'] ?? json['imageUrl']) as String?;

    final fileMetadata = _parseFileMetadata(json['fileMetadata']);

    final metadataFileName = fileMetadata?['fileName']?.toString();
    final metadataFileSize = _tryParseInt(fileMetadata?['fileSize']);
    final metadataPageCount = _tryParseInt(fileMetadata?['pageCount']);
    final metadataThumbnailUrl = fileMetadata?['thumbnailUrl']?.toString();

    // Debug logging for video messages
    if (json['messageType']?.toString() == 'video') {
      debugPrint('🎥 VIDEO MESSAGE fromJson:');
      debugPrint('  - videoThumbnailUrl: ${json['videoThumbnailUrl']}');
      debugPrint('  - thumbnailUrl: ${json['thumbnailUrl']}');
      debugPrint('  - metadataThumbnailUrl: $metadataThumbnailUrl');
      debugPrint('  - fileUrl: $fileUrl');
      if (fileMetadata != null) {
        debugPrint('  - fileMetadata keys: ${fileMetadata.keys.toList()}');
      }
    }

    // Parse image dimensions from multiple possible sources:
    // 1. Direct fields: imageWidth/imageHeight or image_width/image_height
    // 2. Inside fileMetadata object
    final metadataImageWidth = _tryParseInt(
      fileMetadata?['imageWidth'] ??
          fileMetadata?['image_width'] ??
          fileMetadata?['width'],
    );
    final metadataImageHeight = _tryParseInt(
      fileMetadata?['imageHeight'] ??
          fileMetadata?['image_height'] ??
          fileMetadata?['height'],
    );
    final directImageWidth = _tryParseInt(
      json['imageWidth'] ?? json['image_width'] ?? json['width'],
    );
    final directImageHeight = _tryParseInt(
      json['imageHeight'] ?? json['image_height'] ?? json['height'],
    );

    final deletedForSender = _tryParseBool(
      json['deletedForSender'] ?? json['deleted_for_sender'],
    );
    final deletedForReceiver = _tryParseBool(
      json['deletedForReceiver'] ?? json['deleted_for_receiver'],
    );
    final isDeleted = deletedForSender || deletedForReceiver;

    final rawMessageType = json['messageType']?.toString();
    final messageType = isDeleted
        ? MessageType.deleted
        : _parseMessageType(rawMessageType);

    String messageContent =
        (json['messageText'] ??
                json['message_text'] ??
                json['message'] ??
                json['body'])
            ?.toString() ??
        '';

    if (messageContent == 'null') {
      messageContent = '';
    }

    // If message is empty and this is a contact type, extract from contactPayload
    if (messageContent.isEmpty && messageType == MessageType.contact) {
      final contactPayload = json['contactPayload'];
      if (contactPayload != null &&
          contactPayload is List &&
          contactPayload.isNotEmpty) {
        // Convert contactPayload to JSON string for storage
        final firstContact = contactPayload.first;
        messageContent = _normalizedContactJson(firstContact);
      }
    }

    // If message is empty and this is a poll type, extract from pollPayload
    if (messageContent.isEmpty && messageType == MessageType.poll) {
      final pollPayload = json['pollPayload'];
      if (pollPayload != null) {
        if (pollPayload is Map) {
          // Convert pollPayload Map to JSON string for storage
          messageContent = jsonEncode(pollPayload);
        } else if (pollPayload is String && pollPayload.isNotEmpty) {
          // Already a JSON string
          messageContent = pollPayload;
        }
      }
    }

    var effectiveMessageType = messageType;
    if (effectiveMessageType == MessageType.text &&
        (_looksLikeLocationJson(messageContent) ||
            _looksLikeLatLngText(messageContent))) {
      effectiveMessageType = MessageType.location;
      messageContent = _looksLikeLocationJson(messageContent)
          ? _normalizeLocationJsonString(messageContent)
          : _normalizeLatLngTextToJson(messageContent);
    }

    final rawStatus = (json['messageStatus'] as String?) ?? 'sent';
    final parsedIsRead =
        _tryParseBool(json['isRead']) ||
        rawStatus.toLowerCase().trim() == 'read' ||
        rawStatus.toLowerCase().trim() == 'seen';
    final normalizedStatus = normalizeMessageStatus(
      rawStatus,
      isRead: parsedIsRead,
    );

    return ChatMessageModel(
      id: json['id'] as String? ?? json['chatId'] as String? ?? '',
      senderId: json['senderId'] as String? ?? '',
      receiverId: json['receiverId'] as String? ?? '',
      message: messageContent,
      reactionsJson: reactionsJson,
      isStarred: _tryParseBool(
        json['isStarred'] ??
            json['is_starred'] ??
            json['starred'] ??
            json['isStar'] ??
            json['is_star'],
      ),
      isEdited: _tryParseBool(json['isEdited'] ?? json['is_edited']),
      editedAt: _tryParseDateTime(json['editedAt'] ?? json['edited_at']),
      messageStatus: normalizedStatus,
      isRead: parsedIsRead,
      deliveredAt: _tryParseDateTime(json['deliveredAt']),
      readAt: _tryParseDateTime(json['readAt']),
      createdAt: _tryParseDateTime(json['createdAt']) ?? now,
      updatedAt:
          _tryParseDateTime(json['updatedAt']) ??
          _tryParseDateTime(json['createdAt']) ??
          now,
      deliveryChannel: json['deliveryChannel'] as String? ?? 'socket',
      receiverDeliveryChannel: json['receiverDeliveryChannel'] as String?,
      sender: json['sender'] != null && json['sender'] is Map
          ? ChatUserModel.fromJson(json['sender'] as Map<String, dynamic>)
          : null,
      receiver: json['receiver'] != null && json['receiver'] is Map
          ? ChatUserModel.fromJson(json['receiver'] as Map<String, dynamic>)
          : null,
      messageType: effectiveMessageType,
      imageUrl: (json['imageUrl'] as String?) ?? fileUrl,
      thumbnailUrl:
          json['videoThumbnailUrl'] as String? ??
          json['thumbnailUrl'] as String? ??
          metadataThumbnailUrl,
      localImagePath: json['localImagePath'] as String?,
      imageWidth: metadataImageWidth ?? directImageWidth,
      imageHeight: metadataImageHeight ?? directImageHeight,
      fileSize: metadataFileSize ?? _tryParseInt(json['fileSize']),
      mimeType: json['mimeType'] as String?,
      fileName: metadataFileName ?? json['fileName'] as String?,
      pageCount: metadataPageCount ?? _tryParseInt(json['pageCount']),
      audioDuration: _tryParseDouble(
        json['audioDuration'] ?? json['audio_duration'],
      ),
      isFollowUp: _tryParseBool(json['isFollowUp'] ?? json['is_follow_up']),
      replyToMessageId:
          json['replyToMessageId'] as String? ??
          json['reply_to_message_id'] as String?,
      replyToMessage: _buildReplyToMessageFromFlat(json),
    );
  }

  /// Factory constructor for WebSocket incoming messages
  /// Backend sends: {chatId, senderId, message, messageStatus, createdAt, deliveryChannel}
  factory ChatMessageModel.fromSocketResponse(Map<String, dynamic> data) {
    final rawType = data['messageType'] as String?;
    var messageType = _parseMessageType(rawType);
    final fileUrl =
        (data['fileUrl'] ?? data['file_url'] ?? data['imageUrl']) as String?;

    final reactionsRaw = data['reactionsJson'] ?? data['reactions'];
    final reactionsJson = reactionsRaw == null
        ? null
        : (reactionsRaw is String ? reactionsRaw : jsonEncode(reactionsRaw));

    final fileMetadataRaw = data['fileMetadata'];
    final fileMetadata = _parseFileMetadata(fileMetadataRaw);

    final metadataFileName = fileMetadata?['fileName']?.toString();
    final metadataFileSize = _tryParseInt(fileMetadata?['fileSize']);
    final metadataPageCount = _tryParseInt(fileMetadata?['pageCount']);
    final metadataThumbnailUrl = fileMetadata?['thumbnailUrl']?.toString();

    // Debug logging for video messages
    if (messageType == MessageType.video) {
      debugPrint('🎥 VIDEO MESSAGE fromSocketResponse:');
      debugPrint('  - videoThumbnailUrl: ${data['videoThumbnailUrl']}');
      debugPrint('  - thumbnailUrl: ${data['thumbnailUrl']}');
      debugPrint('  - metadataThumbnailUrl: $metadataThumbnailUrl');
      debugPrint('  - fileUrl: $fileUrl');
      if (fileMetadata != null) {
        debugPrint('  - fileMetadata keys: ${fileMetadata.keys.toList()}');
      }
    }

    // Parse image dimensions from multiple possible sources
    final metadataImageWidth = _tryParseInt(
      fileMetadata?['imageWidth'] ??
          fileMetadata?['image_width'] ??
          fileMetadata?['width'],
    );
    final metadataImageHeight = _tryParseInt(
      fileMetadata?['imageHeight'] ??
          fileMetadata?['image_height'] ??
          fileMetadata?['height'],
    );
    final directImageWidth = _tryParseInt(
      data['imageWidth'] ?? data['image_width'] ?? data['width'],
    );
    final directImageHeight = _tryParseInt(
      data['imageHeight'] ?? data['image_height'] ?? data['height'],
    );

    // Handle contact messages - convert contactPayload to message string
    String messageContent =
        (data['messageText'] ??
                data['message_text'] ??
                data['message'] ??
                data['body'])
            ?.toString() ??
        '';

    if (messageContent == 'null') {
      messageContent = '';
    }

    // If message is empty and this is a contact type, extract from contactPayload
    if (messageContent.isEmpty && messageType == MessageType.contact) {
      final contactPayload = data['contactPayload'];
      if (contactPayload != null &&
          contactPayload is List &&
          contactPayload.isNotEmpty) {
        // Convert contactPayload to JSON string for storage
        final firstContact = contactPayload.first;
        messageContent = _normalizedContactJson(firstContact);
      }
    }

    // If message is empty and this is a poll type, extract from pollPayload
    if (messageContent.isEmpty && messageType == MessageType.poll) {
      final pollPayload = data['pollPayload'];
      if (pollPayload != null) {
        if (pollPayload is Map) {
          // Convert pollPayload Map to JSON string for storage
          messageContent = jsonEncode(pollPayload);
        } else if (pollPayload is String && pollPayload.isNotEmpty) {
          // Already a JSON string
          messageContent = pollPayload;
        }
      }
    }

    if (messageType == MessageType.text &&
        (_looksLikeLocationJson(messageContent) ||
            _looksLikeLatLngText(messageContent))) {
      messageType = MessageType.location;
      messageContent = _looksLikeLocationJson(messageContent)
          ? _normalizeLocationJsonString(messageContent)
          : _normalizeLatLngTextToJson(messageContent);
    }

    final rawStatus =
        data['messageStatus'] as String? ?? data['status'] as String? ?? 'sent';
    final parsedIsRead =
        _tryParseBool(data['isRead']) ||
        rawStatus.toLowerCase().trim() == 'read' ||
        rawStatus.toLowerCase().trim() == 'seen';
    final normalizedStatus = normalizeMessageStatus(
      rawStatus,
      isRead: parsedIsRead,
    );

    return ChatMessageModel(
      id:
          data['chatId'] as String? ??
          data['id'] as String? ??
          data['messageId'] as String? ??
          '',
      senderId: data['senderId'] as String? ?? '',
      receiverId: data['receiverId'] as String? ?? '',
      message: messageContent,
      reactionsJson: reactionsJson,
      isStarred: _tryParseBool(
        data['isStarred'] ?? data['is_starred'] ?? data['starred'],
      ),
      isEdited: _tryParseBool(data['isEdited'] ?? data['is_edited']),
      editedAt: _tryParseDateTime(data['editedAt'] ?? data['edited_at']),
      messageStatus: normalizedStatus,
      isRead: parsedIsRead,
      deliveredAt: _tryParseDateTime(data['deliveredAt']),
      readAt: _tryParseDateTime(data['readAt']),
      createdAt: _tryParseDateTime(data['createdAt']) ?? DateTime.now(),
      updatedAt:
          _tryParseDateTime(data['updatedAt']) ??
          _tryParseDateTime(data['createdAt']) ??
          DateTime.now(),
      deliveryChannel: (data['deliveryChannel'] as String?) ?? 'socket',
      receiverDeliveryChannel: data['receiverDeliveryChannel'] as String?,
      sender: null,
      receiver: null,
      messageType: messageType,
      imageUrl: fileUrl,
      thumbnailUrl:
          data['videoThumbnailUrl'] as String? ??
          data['thumbnailUrl'] as String? ??
          metadataThumbnailUrl,
      imageWidth: metadataImageWidth ?? directImageWidth,
      imageHeight: metadataImageHeight ?? directImageHeight,
      mimeType: data['mimeType'] as String?,
      fileName: metadataFileName,
      pageCount: metadataPageCount,
      fileSize: metadataFileSize,
      audioDuration: _tryParseDouble(
        data['audioDuration'] ?? data['audio_duration'],
      ),
      isFollowUp: _tryParseBool(data['isFollowUp'] ?? data['is_follow_up']),
      replyToMessageId:
          data['replyToMessageId'] as String? ??
          data['reply_to_message_id'] as String?,
      replyToMessage: _buildReplyToMessageFromFlat(data),
    );
  }

  /// Factory constructor for WebSocket sent confirmation
  factory ChatMessageModel.fromSentConfirmation(Map<String, dynamic> data) {
    final rawStatus = data['messageStatus'] as String? ?? 'sent';
    final rawType = data['messageType'] as String?;
    var messageType = _parseMessageType(rawType);
    final fileUrl =
        (data['fileUrl'] ?? data['file_url'] ?? data['imageUrl']) as String?;

    final reactionsRaw =
        data['reactionsJson'] ?? data['reactions_json'] ?? data['reactions'];
    final reactionsJson = reactionsRaw == null
        ? null
        : (reactionsRaw is String ? reactionsRaw : jsonEncode(reactionsRaw));

    final fileMetadataRaw = data['fileMetadata'];
    final fileMetadata = _parseFileMetadata(fileMetadataRaw);

    final metadataFileName = fileMetadata?['fileName']?.toString();
    final metadataFileSize = _tryParseInt(fileMetadata?['fileSize']);
    final metadataPageCount = _tryParseInt(fileMetadata?['pageCount']);
    final metadataThumbnailUrl = fileMetadata?['thumbnailUrl']?.toString();

    // Parse image/video dimensions from multiple possible sources
    final metadataImageWidth = _tryParseInt(
      fileMetadata?['imageWidth'] ??
          fileMetadata?['image_width'] ??
          fileMetadata?['width'],
    );
    final metadataImageHeight = _tryParseInt(
      fileMetadata?['imageHeight'] ??
          fileMetadata?['image_height'] ??
          fileMetadata?['height'],
    );
    final directImageWidth = _tryParseInt(
      data['imageWidth'] ?? data['image_width'] ?? data['width'],
    );
    final directImageHeight = _tryParseInt(
      data['imageHeight'] ?? data['image_height'] ?? data['height'],
    );

    // Debug logging for video messages
    if (messageType == MessageType.video) {
      debugPrint('🎥 VIDEO MESSAGE fromSentConfirmation:');
      debugPrint('  - videoThumbnailUrl: ${data['videoThumbnailUrl']}');
      debugPrint('  - thumbnailUrl: ${data['thumbnailUrl']}');
      debugPrint('  - metadataThumbnailUrl: $metadataThumbnailUrl');
      debugPrint('  - fileUrl: $fileUrl');
      if (fileMetadata != null) {
        debugPrint('  - fileMetadata keys: ${fileMetadata.keys.toList()}');
      }
    }

    // Handle contact messages - convert contactPayload to message string
    String messageContent =
        (data['messageText'] ??
                data['message_text'] ??
                data['message'] ??
                data['body'])
            ?.toString() ??
        '';

    // If message is empty and this is a contact type, extract from contactPayload
    if (messageContent.isEmpty && messageType == MessageType.contact) {
      final contactPayload = data['contactPayload'];
      if (contactPayload != null &&
          contactPayload is List &&
          contactPayload.isNotEmpty) {
        // Convert contactPayload to JSON string for storage
        final firstContact = contactPayload.first;
        messageContent = _normalizedContactJson(firstContact);
      }
    }

    // If message is empty and this is a poll type, extract from pollPayload
    if (messageContent.isEmpty && messageType == MessageType.poll) {
      final pollPayload = data['pollPayload'];
      if (pollPayload != null) {
        if (pollPayload is Map) {
          // Convert pollPayload Map to JSON string for storage
          messageContent = jsonEncode(pollPayload);
        } else if (pollPayload is String && pollPayload.isNotEmpty) {
          // Already a JSON string
          messageContent = pollPayload;
        }
      }
    }

    if (messageType == MessageType.text &&
        (_looksLikeLocationJson(messageContent) ||
            _looksLikeLatLngText(messageContent))) {
      messageType = MessageType.location;
      messageContent = _looksLikeLocationJson(messageContent)
          ? _normalizeLocationJsonString(messageContent)
          : _normalizeLatLngTextToJson(messageContent);
    }

    final parsedIsRead =
        _tryParseBool(data['isRead']) ||
        rawStatus.toLowerCase().trim() == 'read' ||
        rawStatus.toLowerCase().trim() == 'seen';
    final normalizedStatus = normalizeMessageStatus(
      rawStatus,
      isRead: parsedIsRead,
    );

    return ChatMessageModel(
      id:
          data['chatId'] as String? ??
          data['id'] as String? ??
          data['messageId'] as String? ??
          '',
      senderId: data['senderId'] as String? ?? '',
      receiverId: data['receiverId'] as String? ?? '',
      message: messageContent,
      reactionsJson: reactionsJson,
      isStarred: _tryParseBool(
        data['isStarred'] ?? data['is_starred'] ?? data['starred'],
      ),
      isEdited: _tryParseBool(data['isEdited'] ?? data['is_edited']),
      editedAt: _tryParseDateTime(data['editedAt'] ?? data['edited_at']),
      messageStatus: normalizedStatus,
      isRead: parsedIsRead,
      deliveredAt: _tryParseDateTime(data['deliveredAt']),
      readAt: _tryParseDateTime(data['readAt']),
      createdAt: _tryParseDateTime(data['createdAt']) ?? DateTime.now(),
      updatedAt:
          _tryParseDateTime(data['updatedAt']) ??
          _tryParseDateTime(data['createdAt']) ??
          DateTime.now(),
      deliveryChannel: (data['deliveryChannel'] as String?) ?? 'socket',
      receiverDeliveryChannel: data['receiverDeliveryChannel'] as String?,
      sender: null,
      receiver: null,
      messageType: messageType,
      imageUrl: fileUrl,
      thumbnailUrl:
          data['videoThumbnailUrl'] as String? ??
          data['thumbnailUrl'] as String? ??
          metadataThumbnailUrl,
      imageWidth: metadataImageWidth ?? directImageWidth,
      imageHeight: metadataImageHeight ?? directImageHeight,
      mimeType: data['mimeType'] as String?,
      fileName: metadataFileName,
      pageCount: metadataPageCount,
      fileSize: metadataFileSize,
      audioDuration: _tryParseDouble(
        data['audioDuration'] ?? data['audio_duration'],
      ),
      isFollowUp: _tryParseBool(data['isFollowUp'] ?? data['is_follow_up']),
      clientMessageId: data['clientMessageId'] as String?,
      replyToMessageId:
          data['replyToMessageId'] as String? ??
          data['reply_to_message_id'] as String?,
      replyToMessage: _buildReplyToMessageFromFlat(data),
    );
  }

  /// Factory constructor for REST API response
  factory ChatMessageModel.fromApiResponse(Map<String, dynamic> json) {
    return ChatMessageModel.fromJson(json);
  }

  // Method to convert ChatMessageModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderId': senderId,
      'receiverId': receiverId,
      'message': message,
      'reactionsJson': reactionsJson,
      'isStarred': isStarred,
      'isEdited': isEdited,
      'editedAt': editedAt?.toIso8601String(),
      'messageStatus': messageStatus,
      'isRead': isRead,
      'deliveredAt': deliveredAt?.toIso8601String(),
      'readAt': readAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'deliveryChannel': deliveryChannel,
      'receiverDeliveryChannel': receiverDeliveryChannel,
      'sender': sender?.toJson(),
      'receiver': receiver?.toJson(),
      'messageType': messageType.name,
      'imageUrl': imageUrl,
      'thumbnailUrl': thumbnailUrl,
      'localImagePath': localImagePath,
      'imageWidth': imageWidth,
      'imageHeight': imageHeight,
      'fileSize': fileSize,
      'mimeType': mimeType,
      'fileName': fileName,
      'pageCount': pageCount,
      'audioDuration': audioDuration,
      'replyToMessageId': replyToMessageId,
      'replyToMessage': replyToMessage?.toJson(),
    };
  }

  /// Build a replyToMessage from flat fields in JSON/socket data.
  /// Backend sends: replyToMessageId, replyToMessageText,
  ///                replyToMessageSenderId, replyToMessageType
  static ChatMessageModel? _buildReplyToMessageFromFlat(
    Map<String, dynamic> data,
  ) {
    // First check if there's a nested replyToMessage object
    if (data['replyToMessage'] != null && data['replyToMessage'] is Map) {
      return ChatMessageModel.fromJson(
        data['replyToMessage'] as Map<String, dynamic>,
      );
    }

    // Build from flat fields
    final replyId =
        data['replyToMessageId'] as String? ??
        data['reply_to_message_id'] as String?;
    final replyText =
        data['replyToMessageText'] as String? ??
        data['reply_to_message_text'] as String?;
    final replySenderId =
        data['replyToMessageSenderId'] as String? ??
        data['reply_to_message_sender_id'] as String?;
    final replyTypeStr =
        data['replyToMessageType'] as String? ??
        data['reply_to_message_type'] as String?;

    if (replyId != null && replyId.isNotEmpty && replyText != null) {
      return ChatMessageModel(
        id: replyId,
        senderId: replySenderId ?? '',
        receiverId: '',
        message: replyText,
        messageType: _parseMessageType(replyTypeStr),
        messageStatus: 'sent',
        isRead: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
    return null;
  }

  /// Parse message type from string
  static MessageType _parseMessageType(String? type) {
    final normalized = type?.toLowerCase().trim();
    final cleaned = normalized != null && normalized.contains('.')
        ? normalized.split('.').last
        : normalized;
    switch (cleaned) {
      case 'deleted':
        return MessageType.deleted;
      case 'image':
        return MessageType.image;
      case 'video':
        return MessageType.video;
      case 'audio':
        return MessageType.audio;
      case 'pdf':
      case 'document':
        return MessageType.document;
      case 'location':
        return MessageType.location;
      case 'contact':
        return MessageType.contact;
      case 'poll':
        return MessageType.poll;
      default:
        return MessageType.text;
    }
  }

  // CopyWith method to create a copy with updated fields
  ChatMessageModel copyWith({
    String? id,
    String? senderId,
    String? receiverId,
    String? message,
    String? reactionsJson,
    bool? isStarred,
    bool? isEdited,
    DateTime? editedAt,
    String? messageStatus,
    bool? isRead,
    DateTime? deliveredAt,
    DateTime? readAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? deliveryChannel,
    ChatUserModel? sender,
    ChatUserModel? receiver,
    String? receiverDeliveryChannel,
    MessageType? messageType,
    String? imageUrl,
    String? thumbnailUrl,
    String? localImagePath,
    int? imageWidth,
    int? imageHeight,
    int? fileSize,
    String? mimeType,
    String? fileName,
    int? pageCount,
    double? audioDuration,
    bool? isFollowUp,
    String? clientMessageId,
    String? replyToMessageId,
    ChatMessageModel? replyToMessage,
  }) {
    return ChatMessageModel(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      message: message ?? this.message,
      reactionsJson: reactionsJson ?? this.reactionsJson,
      isStarred: isStarred ?? this.isStarred,
      isEdited: isEdited ?? this.isEdited,
      editedAt: editedAt ?? this.editedAt,
      messageStatus: messageStatus ?? this.messageStatus,
      isRead: isRead ?? this.isRead,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deliveryChannel: deliveryChannel ?? this.deliveryChannel,
      sender: sender ?? this.sender,
      receiver: receiver ?? this.receiver,
      receiverDeliveryChannel:
          receiverDeliveryChannel ?? this.receiverDeliveryChannel,
      messageType: messageType ?? this.messageType,
      imageUrl: imageUrl ?? this.imageUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      localImagePath: localImagePath ?? this.localImagePath,
      imageWidth: imageWidth ?? this.imageWidth,
      imageHeight: imageHeight ?? this.imageHeight,
      fileSize: fileSize ?? this.fileSize,
      mimeType: mimeType ?? this.mimeType,
      fileName: fileName ?? this.fileName,
      pageCount: pageCount ?? this.pageCount,
      audioDuration: audioDuration ?? this.audioDuration,
      isFollowUp: isFollowUp ?? this.isFollowUp,
      clientMessageId: clientMessageId ?? this.clientMessageId,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      replyToMessage: replyToMessage ?? this.replyToMessage,
    );
  }

  @override
  String toString() {
    return 'ChatMessageModel(id: $id, senderId: $senderId, receiverId: $receiverId, message: $message, messageStatus: $messageStatus, isRead: $isRead, deliveredAt: $deliveredAt, readAt: $readAt, createdAt: $createdAt, updatedAt: $updatedAt, deliveryChannel: $deliveryChannel, sender: ${sender?.fullName}, receiver: ${receiver?.fullName})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ChatMessageModel &&
        other.id == id &&
        other.senderId == senderId &&
        other.receiverId == receiverId &&
        other.message == message &&
        other.reactionsJson == reactionsJson &&
        other.isStarred == isStarred &&
        other.isEdited == isEdited &&
        other.editedAt == editedAt &&
        other.messageStatus == messageStatus &&
        other.isRead == isRead &&
        other.deliveredAt == deliveredAt &&
        other.readAt == readAt &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.deliveryChannel == deliveryChannel &&
        other.receiverDeliveryChannel == receiverDeliveryChannel &&
        other.messageType == messageType &&
        other.imageUrl == imageUrl &&
        other.thumbnailUrl == thumbnailUrl &&
        other.localImagePath == localImagePath &&
        other.imageWidth == imageWidth &&
        other.imageHeight == imageHeight &&
        other.fileSize == fileSize &&
        other.mimeType == mimeType &&
        other.fileName == fileName &&
        other.pageCount == pageCount &&
        other.audioDuration == audioDuration &&
        other.isFollowUp == isFollowUp &&
        other.replyToMessageId == replyToMessageId;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        senderId.hashCode ^
        receiverId.hashCode ^
        message.hashCode ^
        reactionsJson.hashCode ^
        isStarred.hashCode ^
        isEdited.hashCode ^
        editedAt.hashCode ^
        messageStatus.hashCode ^
        isRead.hashCode ^
        deliveredAt.hashCode ^
        readAt.hashCode ^
        createdAt.hashCode ^
        updatedAt.hashCode ^
        deliveryChannel.hashCode ^
        receiverDeliveryChannel.hashCode ^
        messageType.hashCode ^
        imageUrl.hashCode ^
        thumbnailUrl.hashCode ^
        localImagePath.hashCode ^
        imageWidth.hashCode ^
        imageHeight.hashCode ^
        fileSize.hashCode ^
        mimeType.hashCode ^
        fileName.hashCode ^
        pageCount.hashCode ^
        audioDuration.hashCode ^
        isFollowUp.hashCode ^
        replyToMessageId.hashCode;
  }
}

class ChatLastActivityModel {
  final String? type;
  final String actorId;
  final String? emoji;
  final String? deleteType;
  final String messageId;
  final DateTime timestamp;

  ChatLastActivityModel({
    required this.type,
    required this.actorId,
    required this.emoji,
    this.deleteType,
    required this.messageId,
    required this.timestamp,
  });

  static DateTime? _tryParseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    final s = value.toString();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  static ChatLastActivityModel? tryFromJson(dynamic raw) {
    if (raw == null) return null;
    if (raw is! Map) return null;
    final json = Map<String, dynamic>.from(raw);
    final actorId =
        (json['actorId'] ??
                json['actor_id'] ??
                json['userId'] ??
                json['user_id'])
            ?.toString() ??
        '';
    final messageId =
        (json['messageId'] ?? json['message_id'])?.toString() ??
        (json['chatId'] ?? json['chat_id'])?.toString() ??
        '';
    final timestamp =
        _tryParseDateTime(
          json['timestamp'] ??
              json['time'] ??
              json['deletedAt'] ??
              json['deleted_at'] ??
              json['createdAt'] ??
              json['created_at'],
        ) ??
        DateTime.now();
    if (actorId.isEmpty || messageId.isEmpty) return null;

    return ChatLastActivityModel(
      type: (json['type'] ?? json['activityType'] ?? json['activity_type'])
          ?.toString(),
      actorId: actorId,
      emoji: json['emoji']?.toString(),
      deleteType: (json['deleteType'] ?? json['delete_type'])?.toString(),
      messageId: messageId,
      timestamp: timestamp,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'actorId': actorId,
      'emoji': emoji,
      'deleteType': deleteType,
      'messageId': messageId,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

/// Model for chat contact with last message information
class ChatContactModel {
  final ChatUserModel user;
  final ChatMessageModel? lastMessage;
  final ChatLastActivityModel? lastActivity;
  final int unreadCount;

  ChatContactModel({
    required this.user,
    this.lastMessage,
    this.lastActivity,
    this.unreadCount = 0,
  });

  factory ChatContactModel.fromJson(Map<String, dynamic> json) {
    final lastMsg = json['lastMessage'];
    final contactUserId = (json['userId'] ?? json['id'])?.toString() ?? '';
    final lastActivity = ChatLastActivityModel.tryFromJson(
      json['lastActivity'] ?? json['last_activity'],
    );

    return ChatContactModel(
      user: ChatUserModel.fromJson({
        'id': json['userId'] ?? json['id'],
        'firstName': json['firstName'],
        'lastName': json['lastName'],
        'mobileNo': json['mobileNo'],
        'chatPictureUrl':
            json['chatPictureUrl'] ??
            json['chat_picture'] ??
            json['profile'
                'PicUrl'],
      }),
      lastMessage: lastMsg != null
          ? ChatMessageModel.fromJson({
              'id':
                  lastMsg['chatId'] ??
                  lastMsg['messageId'] ??
                  lastMsg['id'] ??
                  '',
              'senderId': lastMsg['senderId'] ?? '',
              // Compute receiverId: if isFromCurrentUser is true, receiver is the contact
              // Otherwise, the current user is the receiver (we use empty string as placeholder,
              // saveChatContacts will fix this with actual currentUserId)
              'receiverId': (lastMsg['isFromCurrentUser'] == true)
                  ? contactUserId
                  : '',
              'message': lastMsg['message'] ?? '',
              // Use actual messageStatus from backend (sent/delivered/read)
              'messageStatus': lastMsg['messageStatus'] ?? 'sent',
              'isRead': lastMsg['isRead'] ?? false,
              'deliveredAt': lastMsg['deliveredAt'],
              'readAt': lastMsg['readAt'],
              'createdAt':
                  lastMsg['createdAt'] ?? DateTime.now().toIso8601String(),
              'updatedAt':
                  lastMsg['createdAt'] ?? DateTime.now().toIso8601String(),
              // Parse messageType, fileUrl, mimeType from backend response
              'messageType': lastMsg['messageType'] ?? 'text',
              'fileUrl': lastMsg['fileUrl'],
              'mimeType': lastMsg['mimeType'],
              'fileName': lastMsg['fileName'],
              'fileSize': lastMsg['fileSize'],
              'pageCount': lastMsg['pageCount'],
            })
          : null,
      lastActivity: lastActivity,
      unreadCount: (json['unreadCount'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user': user.toJson(),
      'lastMessage': lastMessage?.toJson(),
      'lastActivity': lastActivity?.toJson(),
      'unreadCount': unreadCount,
    };
  }

  ChatContactModel copyWith({
    ChatUserModel? user,
    ChatMessageModel? lastMessage,
    ChatLastActivityModel? lastActivity,
    int? unreadCount,
  }) {
    return ChatContactModel(
      user: user ?? this.user,
      lastMessage: lastMessage ?? this.lastMessage,
      lastActivity: lastActivity ?? this.lastActivity,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}
