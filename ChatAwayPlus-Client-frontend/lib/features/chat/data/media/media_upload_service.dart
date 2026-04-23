// lib/features/chat/data/media/media_upload_service.dart

import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' as http_parser;
import 'dart:convert';
import 'package:chataway_plus/core/constants/api_url/api_urls.dart';
import 'package:chataway_plus/core/storage/token_storage.dart';
import 'package:chataway_plus/features/chat/utils/chat_image_utils.dart';

/// Media upload response model
class MediaUploadResponse {
  final String messageType; // 'image', 'video', 'pdf', 'audio'
  final String fileUrl; // S3 key: 'uploads/user-id/filename.jpg'
  final String
  mimeType; // 'image/jpeg', 'video/mp4', 'application/pdf', 'audio/mp4'
  final int? fileSize;
  final String? fileName;
  final int? pageCount; // For PDFs
  final int? imageWidth;
  final int? imageHeight;
  final double? audioDuration; // For audio messages (seconds)
  final String? thumbnailUrl; // For video messages (S3 key)
  final double? videoDuration; // For video messages (seconds)

  MediaUploadResponse({
    required this.messageType,
    required this.fileUrl,
    required this.mimeType,
    this.fileSize,
    this.fileName,
    this.pageCount,
    this.imageWidth,
    this.imageHeight,
    this.audioDuration,
    this.thumbnailUrl,
    this.videoDuration,
  });

  factory MediaUploadResponse.fromJson(Map<String, dynamic> json) {
    return MediaUploadResponse(
      messageType: json['messageType'] as String,
      fileUrl: json['fileUrl'] as String,
      mimeType: json['mimeType'] as String,
      fileSize: json['fileSize'] as int?,
      fileName: json['fileName'] as String?,
      pageCount: json['pageCount'] as int?,
      imageWidth: json['imageWidth'] as int?,
      imageHeight: json['imageHeight'] as int?,
      audioDuration: json['audioDuration'] != null
          ? (json['audioDuration'] as num).toDouble()
          : null,
      // Backend returns videoThumbnailUrl for videos
      thumbnailUrl:
          json['videoThumbnailUrl'] as String? ??
          json['thumbnailUrl'] as String?,
      videoDuration: json['videoDuration'] != null
          ? (json['videoDuration'] as num).toDouble()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'messageType': messageType,
      'fileUrl': fileUrl,
      'mimeType': mimeType,
      if (fileSize != null) 'fileSize': fileSize,
      if (fileName != null) 'fileName': fileName,
      if (pageCount != null) 'pageCount': pageCount,
      if (imageWidth != null) 'imageWidth': imageWidth,
      if (imageHeight != null) 'imageHeight': imageHeight,
      if (audioDuration != null) 'audioDuration': audioDuration,
      if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
      if (videoDuration != null) 'videoDuration': videoDuration,
    };
  }
}

/// Service to handle media uploads to the backend
/// Following WhatsApp-style flow: Upload to S3 (REST) → Send message (WebSocket)
class MediaUploadService {
  static final MediaUploadService _instance = MediaUploadService._internal();
  factory MediaUploadService() => _instance;
  static MediaUploadService get instance => _instance;
  MediaUploadService._internal();

  final http.Client _httpClient = http.Client();
  final TokenSecureStorage _tokenStorage = TokenSecureStorage.instance;

  /// Upload a file to the server (REST API)
  /// Returns the S3 key and metadata needed for WebSocket message
  Future<MediaUploadResponse> uploadFile({
    required File file,
    required String mimeType,
    String? fileName,
    int? imageWidth,
    int? imageHeight,
    Function(double progress)? onProgress,
  }) async {
    try {
      debugPrint('📤 MediaUploadService: Starting file upload');
      debugPrint('📤 File path: ${file.path}');
      debugPrint('📤 MIME type: $mimeType');
      debugPrint('📤 File size: ${await file.length()} bytes');
      if (imageWidth != null && imageHeight != null) {
        debugPrint('📤 Image dimensions: ${imageWidth}x$imageHeight');
      }

      // Get auth token
      final token = await _tokenStorage.getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Not authenticated');
      }

      // Prepare multipart request
      final uri = Uri.parse('${ApiUrls.apiBaseUrl}/chats/upload-file');
      final request = http.MultipartRequest('POST', uri);

      // Add headers
      request.headers['Authorization'] = 'Bearer $token';

      // Add file with proper content type
      final fileStream = http.ByteStream(file.openRead());
      final fileLength = await file.length();
      final multipartFile = http.MultipartFile(
        'file',
        fileStream,
        fileLength,
        filename: fileName ?? file.path.split(Platform.pathSeparator).last,
        contentType: http_parser.MediaType.parse(mimeType),
      );
      request.files.add(multipartFile);

      // Add image dimensions to request body if provided
      if (imageWidth != null && imageHeight != null) {
        request.fields['imageWidth'] = imageWidth.toString();
        request.fields['imageHeight'] = imageHeight.toString();
      }

      debugPrint('📤 Uploading to: $uri');

      // Send request
      final streamedResponse = await request.send();

      // Note: Cannot track upload progress after sending with http package
      // The response stream can only be listened to once
      // Use streamedResponse for the actual response

      // Get response
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('📤 Upload response status: ${response.statusCode}');
      debugPrint('📤 Upload response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        final uploadResponse = MediaUploadResponse.fromJson(jsonResponse);

        debugPrint('✅ File uploaded successfully');
        debugPrint('✅ Message type: ${uploadResponse.messageType}');
        debugPrint('✅ File URL: ${uploadResponse.fileUrl}');

        return uploadResponse;
      } else {
        final errorBody = response.body;
        debugPrint('❌ Upload failed: $errorBody');
        throw Exception(
          'Error uploading file: ${response.statusCode} - $errorBody',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('❌ MediaUploadService error: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Upload image file
  Future<MediaUploadResponse> uploadImage({
    required File imageFile,
    Function(double progress)? onProgress,
  }) async {
    final fileName = imageFile.path.split(Platform.pathSeparator).last;
    final ext = fileName.toLowerCase();
    final mimeType = ext.endsWith('.png')
        ? 'image/png'
        : (ext.endsWith('.webp') ? 'image/webp' : 'image/jpeg');

    // Get image dimensions before uploading
    int? imageWidth;
    int? imageHeight;
    try {
      final ui.Size dimensions = await ChatImageUtils.getImageDimensions(
        imageFile,
      );
      imageWidth = dimensions.width.toInt();
      imageHeight = dimensions.height.toInt();
      debugPrint('📐 Image dimensions obtained: ${imageWidth}x$imageHeight');
    } catch (e) {
      debugPrint('⚠️ Failed to get image dimensions: $e');
      // Continue without dimensions - backend will handle gracefully
    }

    final response = await uploadFile(
      file: imageFile,
      mimeType: mimeType,
      fileName: fileName,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      onProgress: onProgress,
    );

    // IMPORTANT: If server response doesn't include dimensions, use local dimensions
    // This ensures dimensions are always available for proper UI rendering
    final finalWidth = response.imageWidth ?? imageWidth;
    final finalHeight = response.imageHeight ?? imageHeight;

    if (finalWidth != response.imageWidth ||
        finalHeight != response.imageHeight) {
      debugPrint(
        '📐 Using local dimensions (server returned null): ${finalWidth}x$finalHeight',
      );
      return MediaUploadResponse(
        messageType: response.messageType,
        fileUrl: response.fileUrl,
        mimeType: response.mimeType,
        fileSize: response.fileSize,
        fileName: response.fileName,
        pageCount: response.pageCount,
        imageWidth: finalWidth,
        imageHeight: finalHeight,
      );
    }

    return response;
  }

  /// Upload video file with optional thumbnail
  Future<MediaUploadResponse> uploadVideo({
    required File videoFile,
    File? thumbnailFile,
    Function(double progress)? onProgress,
  }) async {
    final fileName = videoFile.path.split(Platform.pathSeparator).last;
    final ext = fileName.toLowerCase();
    final mimeType = ext.endsWith('.mov')
        ? 'video/quicktime'
        : (ext.endsWith('.mkv') ? 'video/x-matroska' : 'video/mp4');

    // If thumbnail provided, upload both in single request
    if (thumbnailFile != null) {
      return _uploadVideoWithThumbnail(
        videoFile: videoFile,
        thumbnailFile: thumbnailFile,
        mimeType: mimeType,
        fileName: fileName,
        onProgress: onProgress,
      );
    }

    // Otherwise use standard upload
    return uploadFile(
      file: videoFile,
      mimeType: mimeType,
      fileName: fileName,
      onProgress: onProgress,
    );
  }

  /// Upload video and thumbnail together in single request
  Future<MediaUploadResponse> _uploadVideoWithThumbnail({
    required File videoFile,
    required File thumbnailFile,
    required String mimeType,
    required String fileName,
    Function(double progress)? onProgress,
  }) async {
    try {
      debugPrint('📤 MediaUploadService: Uploading video with thumbnail');
      debugPrint('📤 Video: $fileName, MIME: $mimeType');
      debugPrint('📤 Video size: ${await videoFile.length()} bytes');
      debugPrint('📤 Thumbnail size: ${await thumbnailFile.length()} bytes');

      final token = await _tokenStorage.getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Not authenticated');
      }

      final uri = Uri.parse('${ApiUrls.apiBaseUrl}/chats/upload-file');
      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';

      // Add video file
      final videoStream = http.ByteStream(videoFile.openRead());
      final videoLength = await videoFile.length();
      final videoMultipart = http.MultipartFile(
        'file',
        videoStream,
        videoLength,
        filename: fileName,
        contentType: http_parser.MediaType.parse(mimeType),
      );
      request.files.add(videoMultipart);

      // Add thumbnail file
      debugPrint('📤 Adding thumbnail to upload...');
      final thumbStream = http.ByteStream(thumbnailFile.openRead());
      final thumbLength = await thumbnailFile.length();
      final thumbMultipart = http.MultipartFile(
        'thumbnail',
        thumbStream,
        thumbLength,
        filename: 'thumb.jpg',
        contentType: http_parser.MediaType.parse('image/jpeg'),
      );
      request.files.add(thumbMultipart);
      debugPrint('✅ Thumbnail added to upload');

      debugPrint('📤 Uploading to: $uri');
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('📤 Video upload response status: ${response.statusCode}');
      debugPrint('📤 Video upload response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        final uploadResponse = MediaUploadResponse.fromJson(jsonResponse);

        debugPrint('✅ Video uploaded successfully');
        debugPrint('✅ Video URL: ${uploadResponse.fileUrl}');
        if (uploadResponse.thumbnailUrl != null) {
          debugPrint('✅ Thumbnail URL: ${uploadResponse.thumbnailUrl}');
        }
        if (uploadResponse.videoDuration != null) {
          debugPrint('✅ Video duration: ${uploadResponse.videoDuration}s');
        }

        return uploadResponse;
      } else {
        final errorBody = response.body;
        debugPrint('❌ Video upload failed: $errorBody');
        throw Exception(
          'Error uploading video: ${response.statusCode} - $errorBody',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('❌ MediaUploadService video upload error: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Upload audio file (voice note)
  Future<MediaUploadResponse> uploadAudio({
    required File audioFile,
    required double audioDuration,
    Function(double progress)? onProgress,
  }) async {
    final fileName = audioFile.path.split(Platform.pathSeparator).last;
    final ext = fileName.toLowerCase();
    String mimeType;
    if (ext.endsWith('.m4a')) {
      mimeType = 'audio/mp4';
    } else if (ext.endsWith('.aac')) {
      mimeType = 'audio/aac';
    } else if (ext.endsWith('.ogg') || ext.endsWith('.opus')) {
      mimeType = 'audio/ogg';
    } else if (ext.endsWith('.wav')) {
      mimeType = 'audio/wav';
    } else if (ext.endsWith('.mp3')) {
      mimeType = 'audio/mpeg';
    } else if (ext.endsWith('.wma')) {
      mimeType = 'audio/x-ms-wma';
    } else {
      mimeType = 'audio/mp4';
    }

    // Get auth token
    final token = await _tokenStorage.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Not authenticated');
    }

    // Prepare multipart request with audioDuration field
    final uri = Uri.parse('${ApiUrls.apiBaseUrl}/chats/upload-file');
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';

    final fileStream = http.ByteStream(audioFile.openRead());
    final fileLength = await audioFile.length();
    final multipartFile = http.MultipartFile(
      'file',
      fileStream,
      fileLength,
      filename: fileName,
      contentType: http_parser.MediaType.parse(mimeType),
    );
    request.files.add(multipartFile);
    request.fields['audioDuration'] = audioDuration.toString();

    debugPrint('📤 Uploading audio to: $uri');
    debugPrint('📤 Audio duration: ${audioDuration}s, MIME: $mimeType');

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    debugPrint('📤 Audio upload response status: ${response.statusCode}');

    if (response.statusCode == 200 || response.statusCode == 201) {
      final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
      final uploadResponse = MediaUploadResponse.fromJson(jsonResponse);
      debugPrint('✅ Audio uploaded: ${uploadResponse.fileUrl}');
      return uploadResponse;
    } else {
      debugPrint('❌ Audio upload failed: ${response.body}');
      throw Exception(
        'Error uploading audio: ${response.statusCode} - ${response.body}',
      );
    }
  }

  /// Upload PDF file
  Future<MediaUploadResponse> uploadPdf({
    required File pdfFile,
    Function(double progress)? onProgress,
  }) async {
    final fileName = pdfFile.path.split(Platform.pathSeparator).last;

    return uploadFile(
      file: pdfFile,
      mimeType: 'application/pdf',
      fileName: fileName,
      onProgress: onProgress,
    );
  }

  /// Upload media for stories via the dedicated story upload endpoint
  /// Backend auto-generates thumbnail and extracts video duration via ffmpeg
  Future<StoryUploadResponse> uploadStoryMedia({
    required File mediaFile,
    File? thumbnailFile,
    Function(double progress)? onProgress,
  }) async {
    try {
      final fileName = mediaFile.path.split(Platform.pathSeparator).last;
      final ext = fileName.toLowerCase();

      // Determine MIME type
      String mimeType;
      if (ext.endsWith('.mp4') ||
          ext.endsWith('.mov') ||
          ext.endsWith('.mkv')) {
        mimeType = ext.endsWith('.mov')
            ? 'video/quicktime'
            : (ext.endsWith('.mkv') ? 'video/x-matroska' : 'video/mp4');
      } else if (ext.endsWith('.png')) {
        mimeType = 'image/png';
      } else if (ext.endsWith('.webp')) {
        mimeType = 'image/webp';
      } else {
        mimeType = 'image/jpeg';
      }

      debugPrint('📤 MediaUploadService: Uploading story media...');
      debugPrint('📤 File: $fileName, MIME: $mimeType');

      final token = await _tokenStorage.getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Not authenticated');
      }

      final uri = Uri.parse('${ApiUrls.apiBaseUrl}/stories/upload');
      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';

      final fileStream = http.ByteStream(mediaFile.openRead());
      final fileLength = await mediaFile.length();
      final multipartFile = http.MultipartFile(
        'media',
        fileStream,
        fileLength,
        filename: fileName,
        contentType: http_parser.MediaType.parse(mimeType),
      );
      request.files.add(multipartFile);

      // Add thumbnail file if provided
      if (thumbnailFile != null) {
        debugPrint('📤 Adding thumbnail to upload...');
        final thumbStream = http.ByteStream(thumbnailFile.openRead());
        final thumbLength = await thumbnailFile.length();
        final thumbMultipartFile = http.MultipartFile(
          'thumbnail',
          thumbStream,
          thumbLength,
          filename: 'thumb.jpg',
          contentType: http_parser.MediaType.parse('image/jpeg'),
        );
        request.files.add(thumbMultipartFile);
        debugPrint('✅ Thumbnail added to upload');
      }

      debugPrint('📤 Uploading to: $uri');
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('📤 Story upload response status: ${response.statusCode}');
      debugPrint('📤 Story upload response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        final data = jsonResponse['data'] as Map<String, dynamic>?;
        if (data == null) {
          throw Exception('Invalid story upload response: missing data');
        }

        final result = StoryUploadResponse(
          mediaUrl: data['mediaUrl'] as String? ?? '',
          mediaType: data['mediaType'] as String? ?? 'image',
          thumbnailUrl: data['thumbnailUrl'] as String?,
          videoDuration: (data['videoDuration'] as num?)?.toDouble(),
          size: data['size'] as int?,
          key: data['key'] as String?,
        );

        debugPrint('✅ Story media uploaded successfully');
        debugPrint('✅ Media URL: ${result.mediaUrl}');
        debugPrint('✅ Media type: ${result.mediaType}');
        if (result.thumbnailUrl != null) {
          debugPrint('✅ Thumbnail URL: ${result.thumbnailUrl}');
        }
        if (result.videoDuration != null) {
          debugPrint('✅ Video duration: ${result.videoDuration}s');
        }

        return result;
      } else {
        final errorBody = response.body;
        debugPrint('❌ Story upload failed: $errorBody');

        // Handle 413 error specifically with user-friendly message
        if (response.statusCode == 413) {
          throw Exception(
            'File too large (413). Please select a smaller file or shorter video.',
          );
        }

        throw Exception(
          'Error uploading story media: ${response.statusCode} - $errorBody',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('❌ MediaUploadService story upload error: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Dispose resources
  void dispose() {
    _httpClient.close();
  }
}

/// Response model for story media upload (/api/stories/upload)
/// Backend auto-generates thumbnailUrl and extracts videoDuration via ffmpeg
class StoryUploadResponse {
  final String mediaUrl;
  final String mediaType; // 'image' or 'video'
  final String? thumbnailUrl;
  final double? videoDuration;
  final int? size;
  final String? key;

  StoryUploadResponse({
    required this.mediaUrl,
    required this.mediaType,
    this.thumbnailUrl,
    this.videoDuration,
    this.size,
    this.key,
  });
}
