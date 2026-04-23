// lib/features/chat/presentation/pages/individual_chat/mixins/media_attachment_mixin.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:chataway_plus/core/snackbar/app_snackbar.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:chataway_plus/features/chat/models/chat_message_model.dart';
import 'package:chataway_plus/features/chat/presentation/providers/chat_page_providers/chat_page_provider.dart';
import 'package:chataway_plus/features/chat/presentation/providers/chat_list_providers/chat_list_stream.dart';
import 'package:chataway_plus/features/chat/data/media/media_upload_service.dart';
import 'package:chataway_plus/features/chat/data/media/media_cache_service.dart';
import 'package:chataway_plus/features/chat/data/socket/socket_exports.dart';
import 'package:chataway_plus/features/chat/presentation/widgets/media_preview/image_preview_page.dart';
import 'package:chataway_plus/features/chat/presentation/widgets/media_preview/video_preview_page.dart';
import 'package:chataway_plus/features/chat/presentation/widgets/media_preview/pdf_preview_page.dart';
import 'package:chataway_plus/features/chat/utils/chat_image_utils.dart';
import 'package:chataway_plus/features/chat/data/services/local/messages_local_db.dart';
import 'package:chataway_plus/core/connectivity/connectivity_service.dart';
import 'package:chataway_plus/features/location_sharing/data/models/location_model.dart';

/// Mixin that handles all media attachment operations for individual chat
/// Includes camera, gallery, video, and document attachment handlers
mixin MediaAttachmentMixin<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  final ImagePicker _imagePicker = ImagePicker();

  double _snackbarBottomPosition() {
    final width = context.screenWidth;
    final responsive = ResponsiveSize(
      context: context,
      constraints: BoxConstraints(maxWidth: width),
      breakpoint: DeviceBreakpoint.fromWidth(width),
    );
    return responsive.size(120);
  }

  /// Handle sending location message
  Future<void> handleSendLocationMessage(LocationModel location) async {
    final now = DateTime.now();
    final tempId = 'local_location_${now.millisecondsSinceEpoch}';

    // Capture notifier BEFORE any async gap to avoid 'ref after dispose' error
    final notifier = ref.read(
      chatPageNotifierProvider(providerParams).notifier,
    );

    try {
      debugPrint('📍 Sending location message...');

      final payload = {
        'latitude': location.latitude,
        'longitude': location.longitude,
        'address': location.address,
        'placeName': location.placeName,
        'timestamp': location.timestamp.toIso8601String(),
      };
      payload.removeWhere((_, v) => v == null);
      final locationJson = jsonEncode(payload);

      // Step 1: Create optimistic local message for instant UI feedback
      final optimisticMessage = ChatMessageModel(
        id: tempId,
        senderId: currentUserId,
        receiverId: receiverId,
        message: locationJson,
        messageStatus: 'sending',
        isRead: false,
        createdAt: now,
        updatedAt: now,
        messageType: MessageType.location,
      );

      // Save to LOCAL DATABASE immediately (for ID replacement to work)
      await MessagesLocalDatabaseService.instance.saveMessage(
        message: optimisticMessage,
        currentUserId: currentUserId,
        otherUserId: receiverId,
      );
      debugPrint('💾 Saved location message to local DB with id: $tempId');

      // Show in UI immediately (WhatsApp-style optimistic UI)
      notifier.addIncomingMessage(optimisticMessage);

      // Bump chat list to top immediately
      ChatListStream.instance.bumpWithMessage(
        otherUserId: receiverId,
        message: optimisticMessage,
        unreadDelta: 0,
      );

      // Step 2: Send message via WebSocket
      debugPrint('📤 Sending location message via WebSocket...');
      debugPrint('📤 Using tempId as clientMessageId: $tempId');
      final sent = await WebSocketChatRepository.instance.sendMessage(
        receiverId: receiverId,
        message: locationJson,
        messageType: 'location',
        clientMessageId: tempId,
      );

      if (sent) {
        debugPrint('✅ Location message sent successfully!');
        unawaited(ChatListStream.instance.reload());
      } else {
        throw Exception('Failed to send location message via WebSocket');
      }
    } catch (e) {
      debugPrint('❌ Failed to send location message: $e');

      // Mark message as failed for retry
      notifier.markUploadFailed(tempId);

      if (!mounted) return;
      AppSnackbar.showError(
        context,
        'Failed to send location: ${e.toString()}',
        bottomPosition: _snackbarBottomPosition(),
        duration: const Duration(seconds: 3),
      );
    }
  }

  // These must be provided by the implementing class
  String get receiverId;
  String get currentUserId;
  String get contactName;
  Map<String, String> get providerParams;

  /// Handle camera attachment - capture photo and prepare for sending
  Future<void> handleCameraAttachment() async {
    debugPrint('📷 Camera button tapped');
    try {
      // Check camera permission
      var status = await Permission.camera.status;
      debugPrint('📷 Camera permission status: $status');
      if (status.isDenied) {
        status = await Permission.camera.request();
        if (status.isDenied) {
          if (!mounted) return;
          AppSnackbar.showError(
            context,
            'Camera permission is required',
            bottomPosition: _snackbarBottomPosition(),
            duration: const Duration(seconds: 2),
          );
          return;
        }
      }

      if (status.isPermanentlyDenied) {
        if (!mounted) return;
        AppSnackbar.showError(
          context,
          'Please enable camera permission in settings',
          bottomPosition: _snackbarBottomPosition(),
          duration: const Duration(seconds: 2),
        );
        await openAppSettings();
        return;
      }

      // Capture photo - don't pre-resize, let user see original photo
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
      );

      if (photo != null) {
        handleSelectedImage(File(photo.path));
      }
    } catch (e) {
      debugPrint('Camera error: $e');
      if (!mounted) return;
      AppSnackbar.showError(
        context,
        'Failed to capture photo',
        bottomPosition: _snackbarBottomPosition(),
        duration: const Duration(seconds: 2),
      );
    }
  }

  /// Handle gallery attachment - pick image from gallery
  Future<void> handleGalleryAttachment() async {
    debugPrint('🖼️ Gallery button tapped');
    try {
      // Check photos permission
      var permission = await Permission.photos.isGranted
          ? Permission.photos
          : Permission.storage;
      var status = await permission.status;

      if (status.isDenied) {
        status = await permission.request();
        if (status.isDenied && permission == Permission.photos) {
          permission = Permission.storage;
          status = await permission.request();
        }
        if (status.isDenied) {
          if (!mounted) return;
          AppSnackbar.showError(
            context,
            'Permission to access photos is required',
            bottomPosition: _snackbarBottomPosition(),
            duration: const Duration(seconds: 2),
          );
          return;
        }
      }

      if (status.isPermanentlyDenied) {
        if (!mounted) return;
        AppSnackbar.showError(
          context,
          'Please enable photo permission in settings',
          bottomPosition: _snackbarBottomPosition(),
          duration: const Duration(seconds: 2),
        );
        await openAppSettings();
        return;
      }

      // Pick image or video from gallery
      final XFile? media = await _imagePicker.pickMedia();

      if (media != null) {
        final mimeType = media.mimeType ?? '';
        final path = media.path.toLowerCase();
        // Determine if the picked file is a video
        final isVideo =
            mimeType.startsWith('video/') ||
            path.endsWith('.mp4') ||
            path.endsWith('.mov') ||
            path.endsWith('.avi') ||
            path.endsWith('.mkv') ||
            path.endsWith('.webm') ||
            path.endsWith('.3gp');
        if (isVideo) {
          handleSelectedVideo(File(media.path));
        } else {
          handleSelectedImage(File(media.path));
        }
      }
    } catch (e) {
      debugPrint('Gallery error: $e');
      if (!mounted) return;
      AppSnackbar.showError(
        context,
        'Failed to pick media',
        bottomPosition: _snackbarBottomPosition(),
        duration: const Duration(seconds: 2),
      );
    }
  }

  /// Handle video attachment - pick video from gallery
  Future<void> handleVideoAttachment() async {
    debugPrint('🎥 Video button tapped');
    try {
      var permission = await Permission.photos.isGranted
          ? Permission.photos
          : Permission.storage;
      var status = await permission.status;

      if (status.isDenied) {
        status = await permission.request();
        if (status.isDenied && permission == Permission.photos) {
          permission = Permission.storage;
          status = await permission.request();
        }
        if (status.isDenied) {
          if (!mounted) return;
          AppSnackbar.showError(
            context,
            'Permission to access videos is required',
            bottomPosition: _snackbarBottomPosition(),
            duration: const Duration(seconds: 2),
          );
          return;
        }
      }

      if (status.isPermanentlyDenied) {
        if (!mounted) return;
        AppSnackbar.showError(
          context,
          'Please enable permission in settings',
          bottomPosition: _snackbarBottomPosition(),
          duration: const Duration(seconds: 2),
        );
        await openAppSettings();
        return;
      }

      final XFile? video = await _imagePicker.pickVideo(
        source: ImageSource.gallery,
      );

      if (video != null) {
        handleSelectedVideo(File(video.path));
      }
    } catch (e) {
      debugPrint('Video picker error: $e');
      if (!mounted) return;
      AppSnackbar.showError(
        context,
        'Failed to pick video',
        bottomPosition: _snackbarBottomPosition(),
        duration: const Duration(seconds: 2),
      );
    }
  }

  /// Handle document attachment - pick PDF from files
  Future<void> handleDocumentAttachment() async {
    debugPrint('📄 Document button tapped');
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      final path = result?.files.single.path;
      if (path == null || path.isEmpty) return;

      final file = File(path);
      handleSelectedPdf(file);
    } catch (e) {
      debugPrint('Document picker error: $e');
      if (!mounted) return;
      AppSnackbar.showError(
        context,
        'Failed to pick document',
        bottomPosition: _snackbarBottomPosition(),
        duration: const Duration(seconds: 2),
      );
    }
  }

  /// Handle selected image - show preview and prepare for sending
  void handleSelectedImage(File imageFile) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ImagePreviewPage(
          imageFile: imageFile,
          receiverName: contactName,
          onSend: handleSendImageMessage,
        ),
      ),
    );
  }

  /// Handle selected video - show preview
  Future<void> handleSelectedVideo(File videoFile) async {
    // Check video file size (max 60MB to match server limit)
    final fileSizeInBytes = await videoFile.length();
    final fileSizeInMB = fileSizeInBytes / (1024 * 1024);

    debugPrint('📦 Video size: ${fileSizeInMB.toStringAsFixed(2)} MB');

    if (fileSizeInMB > 60) {
      if (!mounted) return;
      AppSnackbar.showError(
        context,
        'Video too large (${fileSizeInMB.toStringAsFixed(1)}MB). Max: 60MB',
        bottomPosition: _snackbarBottomPosition(),
        duration: const Duration(seconds: 3),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => VideoPreviewPage(
          videoFile: videoFile,
          receiverName: contactName,
          onSend: handleSendVideoMessage,
        ),
      ),
    );
  }

  /// Handle selected PDF - show preview
  void handleSelectedPdf(File pdfFile) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PdfPreviewPage(
          pdfFile: pdfFile,
          receiverName: contactName,
          onSend: handleSendPdfMessage,
        ),
      ),
    );
  }

  /// Handle sending image message from preview page
  Future<void> handleSendImageMessage(File imageFile, String caption) async {
    final now = DateTime.now();
    final tempId = 'temp_${now.millisecondsSinceEpoch}';

    // Capture notifier BEFORE any async gap to avoid 'ref after dispose' error
    final notifier = ref.read(
      chatPageNotifierProvider(providerParams).notifier,
    );

    try {
      debugPrint('📤 Starting image upload and send flow...');

      int? imageWidth;
      int? imageHeight;
      int fileSize = 0;
      try {
        final results = await Future.wait([
          ChatImageUtils.getImageDimensions(imageFile),
          imageFile.length(),
        ]);
        final dimensions = results[0] as Size;
        imageWidth = dimensions.width.toInt();
        imageHeight = dimensions.height.toInt();
        fileSize = results[1] as int;
      } catch (e) {
        debugPrint('⚠️ Failed to get dimensions/size: $e');
      }

      // Show in UI INSTANTLY — no async gap before the user sees the bubble.
      final fileName = imageFile.path.split(Platform.pathSeparator).last;

      final optimisticMessage = ChatMessageModel(
        id: tempId,
        senderId: currentUserId,
        receiverId: receiverId,
        message: caption,
        messageStatus: 'sending',
        isRead: false,
        createdAt: now,
        updatedAt: now,
        messageType: MessageType.image,
        localImagePath: imageFile.path,
        fileName: fileName,
        fileSize: fileSize,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
      );

      // Save to LOCAL DATABASE so message survives navigation away
      await MessagesLocalDatabaseService.instance.saveMessage(
        message: optimisticMessage,
        currentUserId: currentUserId,
        otherUserId: receiverId,
      );

      // Show in UI immediately (WhatsApp-style optimistic UI)
      notifier.addIncomingMessage(optimisticMessage);

      // WHATSAPP-STYLE: Bump chat to top immediately in chat list
      ChatListStream.instance.bumpWithMessage(
        otherUserId: receiverId,
        message: optimisticMessage,
        unreadDelta: 0,
      );

      // Cache the local file to permanent storage so it survives temp cleanup
      unawaited(
        MediaCacheService.instance.cacheLocalFile(
          messageId: tempId,
          sourceFile: imageFile,
          messageType: 'image',
        ),
      );

      // Step 3: Upload file to server (REST API) with progress tracking
      debugPrint('📤 Step 2: Uploading image to server...');

      final uploadResponse = await MediaUploadService.instance.uploadImage(
        imageFile: imageFile,
        onProgress: (progress) {
          debugPrint('📤 Upload progress: ${progress.toStringAsFixed(1)}%');
          notifier.updateUploadProgress(tempId, progress / 100);
        },
      );

      // Clear upload progress on success
      notifier.clearUploadProgress(tempId);

      debugPrint('✅ Upload successful!');
      debugPrint('✅ S3 key: ${uploadResponse.fileUrl}');
      debugPrint('✅ Message type: ${uploadResponse.messageType}');

      // Step 3: Send message via WebSocket
      debugPrint('📤 Step 2: Sending message via WebSocket...');
      final fileMetadataToSend = {
        'fileName': fileName,
        'fileSize': fileSize,
        if (imageWidth != null) 'imageWidth': imageWidth,
        if (imageHeight != null) 'imageHeight': imageHeight,
      };
      final sent = await WebSocketChatRepository.instance.sendMessage(
        receiverId: receiverId,
        message: caption,
        messageType: uploadResponse.messageType,
        fileUrl: uploadResponse.fileUrl,
        mimeType: uploadResponse.mimeType,
        imageWidth: uploadResponse.imageWidth,
        imageHeight: uploadResponse.imageHeight,
        fileMetadata: fileMetadataToSend,
      );

      if (sent) {
        debugPrint('✅ Message sent via WebSocket successfully!');
        unawaited(ChatListStream.instance.reload());
      } else {
        throw Exception('Failed to send message via WebSocket');
      }
    } catch (e) {
      debugPrint('❌ Failed to send image: $e');

      // Mark upload as failed for retry (notifier captured before async)
      notifier.markUploadFailed(tempId);

      // Persist failed status to local DB so it shows on re-enter
      await _markMessageFailedInDb(tempId, currentUserId, receiverId);

      if (!mounted) return;

      // Check if this is an offline/network error
      final errorStr = e.toString().toLowerCase();
      final isOfflineError =
          errorStr.contains('socketexception') ||
          errorStr.contains('clientexception') ||
          errorStr.contains('host lookup') ||
          errorStr.contains('network') ||
          errorStr.contains('connection') ||
          !ConnectivityCache.instance.isOnline;

      if (isOfflineError) {
        AppSnackbar.showOfflineWarning(
          context,
          "You're offline. Connect to internet",
        );
      } else {
        AppSnackbar.showError(
          context,
          'Failed to send image',
          bottomPosition: _snackbarBottomPosition(),
          duration: const Duration(seconds: 3),
        );
      }
    }
  }

  /// Handle sending video message from preview page
  Future<void> handleSendVideoMessage(
    File videoFile,
    String caption,
    File? thumbnailFile,
  ) async {
    final now = DateTime.now();
    final tempId = 'temp_${now.millisecondsSinceEpoch}';

    // Capture notifier BEFORE any async gap to avoid 'ref after dispose' error
    final notifier = ref.read(
      chatPageNotifierProvider(providerParams).notifier,
    );

    try {
      debugPrint('📤 Starting video upload and send flow...');

      final fileSize = await videoFile.length();
      int? videoWidth;
      int? videoHeight;
      if (thumbnailFile != null) {
        try {
          final dimensions = await ChatImageUtils.getImageDimensions(
            thumbnailFile,
          );
          videoWidth = dimensions.width.toInt();
          videoHeight = dimensions.height.toInt();
          debugPrint(
            '📐 Video dimensions from thumbnail: ${videoWidth}x$videoHeight',
          );
        } catch (e) {
          debugPrint('⚠️ Failed to get video dimensions from thumbnail: $e');
        }
      }

      // Show in UI INSTANTLY — no async gap before the user sees the bubble.
      final fileName = videoFile.path.split(Platform.pathSeparator).last;

      final optimisticMessage = ChatMessageModel(
        id: tempId,
        senderId: currentUserId,
        receiverId: receiverId,
        message: caption,
        messageStatus: 'sending',
        isRead: false,
        createdAt: now,
        updatedAt: now,
        messageType: MessageType.video,
        localImagePath: videoFile.path,
        thumbnailUrl: thumbnailFile?.path,
        fileName: fileName,
        fileSize: fileSize,
        imageWidth: videoWidth,
        imageHeight: videoHeight,
      );

      // Save to LOCAL DATABASE so message survives navigation away
      await MessagesLocalDatabaseService.instance.saveMessage(
        message: optimisticMessage,
        currentUserId: currentUserId,
        otherUserId: receiverId,
      );

      // Show in UI immediately
      notifier.addIncomingMessage(optimisticMessage);

      // WHATSAPP-STYLE: Bump chat to top immediately in chat list
      ChatListStream.instance.bumpWithMessage(
        otherUserId: receiverId,
        message: optimisticMessage,
        unreadDelta: 0,
      );

      // Step 2: Upload video with thumbnail to server in single request
      debugPrint('📤 Step 1: Uploading video to server...');

      final uploadResponse = await MediaUploadService.instance.uploadVideo(
        videoFile: videoFile,
        thumbnailFile: thumbnailFile,
        onProgress: (progress) {
          debugPrint('📤 Upload progress: ${progress.toStringAsFixed(1)}%');
          notifier.updateUploadProgress(tempId, progress / 100);
        },
      );

      // Clear upload progress on success
      notifier.clearUploadProgress(tempId);

      debugPrint('✅ Upload successful!');
      debugPrint('✅ S3 key: ${uploadResponse.fileUrl}');
      debugPrint('✅ Message type: ${uploadResponse.messageType}');
      debugPrint('✅ Video duration: ${uploadResponse.videoDuration}');
      if (uploadResponse.thumbnailUrl != null) {
        debugPrint(
          '✅ Thumbnail URL from upload: ${uploadResponse.thumbnailUrl}',
        );
      } else {
        debugPrint('⚠️ WARNING: Upload response has NULL thumbnailUrl!');
      }

      // Get thumbnail URL from response
      final thumbnailKey = uploadResponse.thumbnailUrl;
      debugPrint('📤 thumbnailKey to send in WebSocket: $thumbnailKey');

      // Step 3: Cache video locally BEFORE WebSocket send
      // File picker returns temp paths that get cleaned up — copy to permanent cache now
      // Must happen before WebSocket send so the cached path is in DB when server response merges
      unawaited(
        MediaCacheService.instance.cacheLocalFile(
          messageId: tempId,
          sourceFile: videoFile,
          messageType: 'video',
        ),
      );

      // Step 3b: Cache thumbnail to permanent storage so it survives
      // offline/online transitions and temp file cleanup
      if (thumbnailFile != null) {
        unawaited(
          MediaCacheService.instance
              .cacheLocalFile(
                messageId: 'thumb_$tempId',
                sourceFile: thumbnailFile,
                messageType: 'image',
              )
              .then((cachedThumbPath) {
                if (cachedThumbPath != null) {
                  debugPrint(
                    '✅ Thumbnail cached permanently: $cachedThumbPath',
                  );
                  // Update the in-memory message's thumbnailUrl to the permanent path
                  notifier.updateThumbnailUrl(tempId, cachedThumbPath);
                }
              }),
        );
      }

      // Step 4: Send message via WebSocket
      debugPrint('📤 Step 3: Sending message via WebSocket...');
      final fileMetadataToSend = {
        'fileName': fileName,
        'fileSize': fileSize,
        if (videoWidth != null) 'imageWidth': videoWidth,
        if (videoHeight != null) 'imageHeight': videoHeight,
        if (thumbnailKey != null && thumbnailKey.trim().isNotEmpty)
          'thumbnailUrl': thumbnailKey.trim(),
      };
      debugPrint('📤 fileMetadata to send: $fileMetadataToSend');
      debugPrint('📤 videoThumbnailUrl to send: $thumbnailKey');
      debugPrint('📤 videoDuration to send: ${uploadResponse.videoDuration}');

      final sent = await WebSocketChatRepository.instance.sendMessage(
        receiverId: receiverId,
        message: caption,
        messageType: uploadResponse.messageType,
        fileUrl: uploadResponse.fileUrl,
        mimeType: uploadResponse.mimeType,
        imageWidth: videoWidth,
        imageHeight: videoHeight,
        fileMetadata: fileMetadataToSend,
        videoThumbnailUrl: thumbnailKey,
        videoDuration: uploadResponse.videoDuration,
      );

      if (sent) {
        debugPrint('✅ Video message sent successfully!');
        unawaited(ChatListStream.instance.reload());
      } else {
        throw Exception('Failed to send message via WebSocket');
      }
    } catch (e) {
      debugPrint('❌ Failed to send video: $e');

      // Mark upload as failed for retry (notifier captured before async)
      notifier.markUploadFailed(tempId);

      // Persist failed status to local DB so it shows on re-enter
      await _markMessageFailedInDb(tempId, currentUserId, receiverId);

      if (!mounted) return;

      // Check if this is an offline/network error
      final errorStr = e.toString().toLowerCase();
      final isOfflineError =
          errorStr.contains('socketexception') ||
          errorStr.contains('clientexception') ||
          errorStr.contains('host lookup') ||
          errorStr.contains('network') ||
          errorStr.contains('connection') ||
          !ConnectivityCache.instance.isOnline;

      if (isOfflineError) {
        AppSnackbar.showOfflineWarning(
          context,
          "You're offline. Connect to internet",
        );
      } else {
        AppSnackbar.showError(
          context,
          'Failed to send video',
          bottomPosition: _snackbarBottomPosition(),
          duration: const Duration(seconds: 3),
        );
      }
    }
  }

  /// Handle sending PDF message from preview page
  Future<void> handleSendPdfMessage(File pdfFile, String caption) async {
    final now = DateTime.now();
    final tempId = 'temp_${now.millisecondsSinceEpoch}';

    // Capture notifier BEFORE any async gap to avoid 'ref after dispose' error
    final notifier = ref.read(
      chatPageNotifierProvider(providerParams).notifier,
    );

    try {
      debugPrint('📤 Starting PDF upload and send flow...');

      // Step 1: Create optimistic local message
      final fileName = pdfFile.path.split(Platform.pathSeparator).last;
      final fileSize = await pdfFile.length();

      final optimisticMessage = ChatMessageModel(
        id: tempId,
        senderId: currentUserId,
        receiverId: receiverId,
        message: caption,
        messageStatus: 'sending',
        isRead: false,
        createdAt: now,
        updatedAt: now,
        messageType: MessageType.document,
        localImagePath: pdfFile.path,
        mimeType: 'application/pdf',
        fileName: fileName,
        fileSize: fileSize,
      );

      // Save to LOCAL DATABASE immediately so message survives navigation away
      await MessagesLocalDatabaseService.instance.saveMessage(
        message: optimisticMessage,
        currentUserId: currentUserId,
        otherUserId: receiverId,
      );

      // Cache the local file to permanent storage so it survives temp cleanup
      unawaited(
        MediaCacheService.instance.cacheLocalFile(
          messageId: tempId,
          sourceFile: pdfFile,
          messageType: 'document',
        ),
      );

      // Show in UI immediately
      notifier.addIncomingMessage(optimisticMessage);

      // WHATSAPP-STYLE: Bump chat to top immediately in chat list
      ChatListStream.instance.bumpWithMessage(
        otherUserId: receiverId,
        message: optimisticMessage,
        unreadDelta: 0,
      );

      // Step 2: Upload PDF to server with progress tracking
      debugPrint('📤 Step 1: Uploading PDF to server...');

      final uploadResponse = await MediaUploadService.instance.uploadPdf(
        pdfFile: pdfFile,
        onProgress: (progress) {
          debugPrint('📤 Upload progress: ${progress.toStringAsFixed(1)}%');
          notifier.updateUploadProgress(tempId, progress / 100);
        },
      );

      // Clear upload progress on success
      notifier.clearUploadProgress(tempId);

      debugPrint('✅ Upload successful!');
      debugPrint('✅ S3 key: ${uploadResponse.fileUrl}');

      // Step 2.5: Cache the PDF locally so sender can view without re-downloading
      // File picker returns temp paths that get cleaned up - copy to permanent cache
      unawaited(
        MediaCacheService.instance.cacheLocalFile(
          messageId: tempId,
          sourceFile: pdfFile,
          messageType: 'document',
        ),
      );

      // Step 3: Send message via WebSocket with metadata
      debugPrint('📤 Step 2: Sending message via WebSocket...');
      final sent = await WebSocketChatRepository.instance.sendMessage(
        receiverId: receiverId,
        message: caption,
        messageType: uploadResponse.messageType,
        fileUrl: uploadResponse.fileUrl,
        mimeType: uploadResponse.mimeType,
        fileMetadata: {
          'fileName': fileName,
          'fileSize': fileSize,
          if (uploadResponse.pageCount != null)
            'pageCount': uploadResponse.pageCount!,
        },
      );

      if (sent) {
        debugPrint('✅ PDF message sent successfully!');
        unawaited(ChatListStream.instance.reload());
      } else {
        throw Exception('Failed to send message via WebSocket');
      }
    } catch (e) {
      debugPrint('❌ Failed to send document: $e');

      // Mark upload as failed for retry (notifier captured before async)
      notifier.markUploadFailed(tempId);

      // Persist failed status to local DB so it shows on re-enter
      await _markMessageFailedInDb(tempId, currentUserId, receiverId);

      if (!mounted) return;

      // Check if this is an offline/network error
      final errorStr = e.toString().toLowerCase();
      final isOfflineError =
          errorStr.contains('socketexception') ||
          errorStr.contains('clientexception') ||
          errorStr.contains('host lookup') ||
          errorStr.contains('network') ||
          errorStr.contains('connection') ||
          !ConnectivityCache.instance.isOnline;

      if (isOfflineError) {
        AppSnackbar.showOfflineWarning(
          context,
          "You're offline. Connect to internet",
        );
      } else {
        AppSnackbar.showError(
          context,
          'Failed to send document',
          bottomPosition: _snackbarBottomPosition(),
          duration: const Duration(seconds: 3),
        );
      }
    }
  }

  /// Handle sending audio (voice note) message
  Future<void> handleSendAudioMessage(
    File audioFile,
    double audioDuration,
  ) async {
    final now = DateTime.now();
    final tempId = 'temp_${now.millisecondsSinceEpoch}';

    // Capture notifier BEFORE any async gap to avoid 'ref after dispose' error
    final notifier = ref.read(
      chatPageNotifierProvider(providerParams).notifier,
    );

    try {
      debugPrint('🎤 Starting audio upload and send flow...');
      debugPrint('🎤 Duration: ${audioDuration}s');

      final fileName = audioFile.path.split(Platform.pathSeparator).last;
      final fileSize = await audioFile.length();

      // Step 1: Create optimistic local message
      final optimisticMessage = ChatMessageModel(
        id: tempId,
        senderId: currentUserId,
        receiverId: receiverId,
        message: '',
        messageStatus: 'sending',
        isRead: false,
        createdAt: now,
        updatedAt: now,
        messageType: MessageType.audio,
        localImagePath: audioFile.path,
        mimeType: 'audio/mp4',
        fileName: fileName,
        fileSize: fileSize,
        audioDuration: audioDuration,
      );

      // Save to LOCAL DATABASE immediately so message survives navigation away
      await MessagesLocalDatabaseService.instance.saveMessage(
        message: optimisticMessage,
        currentUserId: currentUserId,
        otherUserId: receiverId,
      );

      // Cache the local file to permanent storage so it survives temp cleanup
      unawaited(
        MediaCacheService.instance.cacheLocalFile(
          messageId: tempId,
          sourceFile: audioFile,
          messageType: 'audio',
        ),
      );

      // Show in UI immediately
      notifier.addIncomingMessage(optimisticMessage);

      // Bump chat to top in chat list
      ChatListStream.instance.bumpWithMessage(
        otherUserId: receiverId,
        message: optimisticMessage,
        unreadDelta: 0,
      );

      // Step 2: Upload audio to server
      debugPrint('📤 Uploading audio to server...');

      final uploadResponse = await MediaUploadService.instance.uploadAudio(
        audioFile: audioFile,
        audioDuration: audioDuration,
        onProgress: (progress) {
          debugPrint(
            '📤 Audio upload progress: ${progress.toStringAsFixed(1)}%',
          );
          notifier.updateUploadProgress(tempId, progress / 100);
        },
      );

      // Clear upload progress
      notifier.clearUploadProgress(tempId);

      debugPrint('✅ Audio upload successful: ${uploadResponse.fileUrl}');

      // Step 3: Cache audio locally
      unawaited(
        MediaCacheService.instance.cacheLocalFile(
          messageId: tempId,
          sourceFile: audioFile,
          messageType: 'audio',
        ),
      );

      // Step 4: Send message via WebSocket
      debugPrint('📤 Sending audio message via WebSocket...');
      final sent = await WebSocketChatRepository.instance.sendMessage(
        receiverId: receiverId,
        message: '',
        messageType: uploadResponse.messageType,
        fileUrl: uploadResponse.fileUrl,
        mimeType: uploadResponse.mimeType,
        audioDuration: audioDuration,
      );

      if (sent) {
        debugPrint('✅ Audio message sent successfully!');
        unawaited(ChatListStream.instance.reload());
      } else {
        throw Exception('Failed to send audio message via WebSocket');
      }
    } catch (e) {
      debugPrint('❌ Failed to send audio: $e');

      // Mark upload as failed for retry (notifier captured before async)
      notifier.markUploadFailed(tempId);

      // Persist failed status to local DB so it shows on re-enter
      await _markMessageFailedInDb(tempId, currentUserId, receiverId);

      if (!mounted) return;

      final errorStr = e.toString().toLowerCase();
      final isOfflineError =
          errorStr.contains('socketexception') ||
          errorStr.contains('clientexception') ||
          errorStr.contains('host lookup') ||
          errorStr.contains('network') ||
          errorStr.contains('connection') ||
          !ConnectivityCache.instance.isOnline;

      if (isOfflineError) {
        AppSnackbar.showOfflineWarning(
          context,
          "You're offline. Connect to internet",
        );
      } else {
        AppSnackbar.showError(
          context,
          'Failed to send voice message',
          bottomPosition: _snackbarBottomPosition(),
          duration: const Duration(seconds: 3),
        );
      }
    }
  }

  /// Retry failed media upload
  Future<void> retryFailedUpload(ChatMessageModel message) async {
    debugPrint('🔄 Retrying failed upload for message: ${message.id}');

    // Capture notifier BEFORE any async gap to avoid 'ref after dispose' error
    final notifier = ref.read(
      chatPageNotifierProvider(providerParams).notifier,
    );

    // Try original local path first, then fall back to permanent media cache
    File? file;
    final localPath = message.localImagePath;
    if (localPath != null && localPath.isNotEmpty) {
      final candidate = File(localPath);
      if (await candidate.exists()) {
        file = candidate;
      }
    }

    // Fallback: check permanent media cache (we cached the file before upload)
    if (file == null) {
      final cachedPath = await MediaCacheService.instance.getCachedFile(
        message.id,
      );
      if (cachedPath != null && await File(cachedPath).exists()) {
        file = File(cachedPath);
        debugPrint('🔄 Found file in media cache: $cachedPath');
      }
    }

    if (file == null) {
      debugPrint('❌ Cannot retry: file not found anywhere');
      if (!mounted) return;
      AppSnackbar.showError(
        context,
        'Cannot retry: file no longer exists',
        bottomPosition: _snackbarBottomPosition(),
        duration: const Duration(seconds: 2),
      );
      return;
    }

    // Remove the failed message from UI and mark as deleted in DB
    notifier.deleteMessageForMe(message.id);
    // Overwrite the failed message in DB with 'deleted' status so it won't
    // reappear on next load. The re-send creates a fresh temp message.
    try {
      await MessagesLocalDatabaseService.instance.updateMessageStatus(
        messageId: message.id,
        newStatus: 'deleted',
      );
    } catch (_) {}

    // Re-send based on message type
    final caption = message.message;
    switch (message.messageType) {
      case MessageType.image:
        await handleSendImageMessage(file, caption);
        break;
      case MessageType.video:
        File? thumb;
        final thumbPath = message.thumbnailUrl;
        if (thumbPath != null && thumbPath.isNotEmpty) {
          final thumbFile = File(thumbPath);
          if (await thumbFile.exists()) {
            thumb = thumbFile;
          }
        }
        await handleSendVideoMessage(file, caption, thumb);
        break;
      case MessageType.document:
        await handleSendPdfMessage(file, caption);
        break;
      case MessageType.audio:
        await handleSendAudioMessage(file, message.audioDuration ?? 0);
        break;
      default:
        debugPrint('❌ Unknown message type for retry: ${message.messageType}');
    }
  }

  /// Persist 'failed' status to local DB so the message shows with retry
  /// indicator when the user re-enters the chat.
  Future<void> _markMessageFailedInDb(
    String messageId,
    String currentUserId,
    String otherUserId,
  ) async {
    try {
      await MessagesLocalDatabaseService.instance.updateMessageStatus(
        messageId: messageId,
        newStatus: 'failed',
      );
    } catch (e) {
      debugPrint('⚠️ Failed to persist failed status to DB: $e');
    }
  }

  /// Handle event attachment (placeholder)
  void handleEventAttachment() {
    AppSnackbar.showInfo(
      context,
      'Event feature coming soon',
      bottomPosition: _snackbarBottomPosition(),
      duration: const Duration(seconds: 2),
    );
  }

  /// Handle contact sharing attachment
  Future<void> handleContactShare() async {
    debugPrint('👤 Contact share button tapped');

    try {
      // Navigate to contact picker
      final result = await Navigator.of(context).pushNamed('/contact-picker');

      if (result == null) {
        debugPrint('📱 Contact picker cancelled by user');
        return;
      }

      // Cast result to contact data map
      final contactData = result as Map<String, dynamic>;
      await handleSendContactMessage(contactData);
    } catch (e) {
      debugPrint('❌ Contact sharing error: $e');
      if (!mounted) return;
      AppSnackbar.showError(
        context,
        'Failed to share contact',
        bottomPosition: _snackbarBottomPosition(),
        duration: const Duration(seconds: 2),
      );
    }
  }

  /// Handle sending contact message
  Future<void> handleSendContactMessage(
    Map<String, dynamic> contactData,
  ) async {
    final now = DateTime.now();
    // Use local_ prefix to match what findLocalMessageId expects
    final tempId = 'local_contact_${now.millisecondsSinceEpoch}';

    // Capture notifier BEFORE any async gap to avoid 'ref after dispose' error
    final notifier = ref.read(
      chatPageNotifierProvider(providerParams).notifier,
    );

    try {
      debugPrint('📤 Sending contact message...');

      final normalizedContact = <String, dynamic>{
        'name': contactData['name'] ?? contactData['contact_name'] ?? 'Unknown',
        'phone':
            contactData['phone'] ?? contactData['contact_mobile_number'] ?? '',
      };

      final contactJson = jsonEncode(normalizedContact);

      // Step 1: Create optimistic local message for instant UI feedback
      final optimisticMessage = ChatMessageModel(
        id: tempId,
        senderId: currentUserId,
        receiverId: receiverId,
        message: contactJson,
        messageStatus: 'sending',
        isRead: false,
        createdAt: now,
        updatedAt: now,
        messageType: MessageType.contact,
      );

      // Save to LOCAL DATABASE immediately (for ID replacement to work)
      await MessagesLocalDatabaseService.instance.saveMessage(
        message: optimisticMessage,
        currentUserId: currentUserId,
        otherUserId: receiverId,
      );
      debugPrint('💾 Saved contact message to local DB with id: $tempId');

      // Show in UI immediately (WhatsApp-style optimistic UI)
      notifier.addIncomingMessage(optimisticMessage);

      // WHATSAPP-STYLE: Bump chat to top immediately in chat list
      ChatListStream.instance.bumpWithMessage(
        otherUserId: receiverId,
        message: optimisticMessage,
        unreadDelta: 0,
      );

      // Step 2: Send message via WebSocket with correct payload format
      debugPrint('📤 Sending contact message via WebSocket...');
      debugPrint('📤 Using tempId as clientMessageId: $tempId');
      final sent = await WebSocketChatRepository.instance.sendContactMessage(
        receiverId: receiverId,
        contactPayload: [normalizedContact],
        clientMessageId:
            tempId, // Pass the temp ID for message confirmation tracking
      );

      if (sent) {
        debugPrint('✅ Contact message sent successfully!');
        unawaited(ChatListStream.instance.reload());
      } else {
        throw Exception('Failed to send contact message via WebSocket');
      }
    } catch (e) {
      debugPrint('❌ Failed to send contact message: $e');

      // Mark message as failed for retry (notifier captured before async)
      notifier.markUploadFailed(tempId);

      if (!mounted) return;
      AppSnackbar.showError(
        context,
        'Failed to send contact: ${e.toString()}',
        bottomPosition: _snackbarBottomPosition(),
        duration: const Duration(seconds: 3),
      );
    }
  }

  /// Handle poll sharing attachment
  Future<void> handlePollShare(Map<String, dynamic> pollData) async {
    debugPrint('📊 Poll share initiated');
    debugPrint('📊 Poll data: $pollData');

    try {
      await handleSendPollMessage(pollData);
    } catch (e) {
      debugPrint('❌ Poll sharing error: $e');
      if (!mounted) return;
      AppSnackbar.showError(
        context,
        'Failed to share poll',
        bottomPosition: _snackbarBottomPosition(),
        duration: const Duration(seconds: 2),
      );
    }
  }

  /// Handle sending poll message
  Future<void> handleSendPollMessage(Map<String, dynamic> pollData) async {
    final now = DateTime.now();
    // Use local_ prefix to match what findLocalMessageId expects
    final tempId = 'local_poll_${now.millisecondsSinceEpoch}';

    // Capture notifier BEFORE any async gap to avoid 'ref after dispose' error
    final notifier = ref.read(
      chatPageNotifierProvider(providerParams).notifier,
    );

    try {
      debugPrint('📤 Sending poll message...');

      // Create poll payload with proper structure
      final question = pollData['question'] as String? ?? 'Poll';
      final rawOptions = pollData['options'] as List? ?? [];

      // Generate unique IDs for options
      final options = rawOptions.asMap().entries.map((entry) {
        final option = entry.value as Map<String, dynamic>;
        return {
          'id': option['id'] ?? 'option-${entry.key + 1}',
          'text': option['text'] ?? 'Option ${entry.key + 1}',
        };
      }).toList();

      final pollPayload = {'question': question, 'options': options};

      // Create poll message JSON for local display
      final pollJson = json.encode(pollPayload);

      // Step 1: Create optimistic local message for instant UI feedback
      final optimisticMessage = ChatMessageModel(
        id: tempId,
        senderId: currentUserId,
        receiverId: receiverId,
        message: pollJson,
        messageStatus: 'sending',
        isRead: false,
        createdAt: now,
        updatedAt: now,
        messageType: MessageType.poll,
      );

      // Save to LOCAL DATABASE immediately (for ID replacement to work)
      await MessagesLocalDatabaseService.instance.saveMessage(
        message: optimisticMessage,
        currentUserId: currentUserId,
        otherUserId: receiverId,
      );
      debugPrint('💾 Saved poll message to local DB with id: $tempId');

      // Show in UI immediately (WhatsApp-style optimistic UI)
      notifier.addIncomingMessage(optimisticMessage);

      // WHATSAPP-STYLE: Bump chat to top immediately in chat list
      ChatListStream.instance.bumpWithMessage(
        otherUserId: receiverId,
        message: optimisticMessage,
        unreadDelta: 0,
      );

      // Step 2: Send message via WebSocket with correct payload format
      debugPrint('📤 Sending poll message via WebSocket...');
      debugPrint('📤 Using tempId as clientMessageId: $tempId');
      final sent = await WebSocketChatRepository.instance.sendPollMessage(
        receiverId: receiverId,
        pollPayload: pollPayload,
        clientMessageId: tempId,
      );

      if (sent) {
        debugPrint('✅ Poll message sent successfully!');
        unawaited(ChatListStream.instance.reload());
      } else {
        throw Exception('Failed to send poll message via WebSocket');
      }
    } catch (e) {
      debugPrint('❌ Failed to send poll message: $e');

      // Mark message as failed for retry (notifier captured before async)
      notifier.markUploadFailed(tempId);

      if (!mounted) return;
      AppSnackbar.showError(
        context,
        'Failed to send poll: ${e.toString()}',
        bottomPosition: _snackbarBottomPosition(),
        duration: const Duration(seconds: 3),
      );
    }
  }
}
