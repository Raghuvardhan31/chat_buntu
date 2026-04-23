import 'dart:io';
import 'package:permission_handler/permission_handler.dart' as permission_handler;
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

class PhotosPermissionService {
  static final PhotosPermissionService _instance =
      PhotosPermissionService._internal();
  factory PhotosPermissionService() => _instance;
  PhotosPermissionService._internal();

  static PhotosPermissionService get instance => _instance;

  /// Check if gallery/photos read permission is granted with proper Android SDK detection
  Future<bool> isReadPermissionGranted() async {
    try {
      if (Platform.isIOS) {
        final status = await Permission.photos.status;
        return status == PermissionStatus.granted ||
            status == PermissionStatus.limited;
      } else if (Platform.isAndroid) {
        final AndroidDeviceInfo android = await DeviceInfoPlugin().androidInfo;
        final int sdkInt = android.version.sdkInt;
        
        // Android 13+ (API 33+) uses READ_MEDIA_IMAGES (Permission.photos)
        // Android 12 and below (API 32-) uses READ_EXTERNAL_STORAGE (Permission.storage)
        if (sdkInt > 32) {
          final status = await Permission.photos.status;
          return status == PermissionStatus.granted;
        } else {
          final status = await Permission.storage.status;
          return status == PermissionStatus.granted;
        }
      }
      return false;
    } catch (e) {
      print('Error checking photo permission: $e');
      return false;
    }
  }

  /// Check if photos write permission is granted
  Future<bool> isWritePermissionGranted() async {
    if (Platform.isIOS) {
      final status = await Permission.photosAddOnly.status;
      return status == PermissionStatus.granted;
    } else {
      // Android: Use Permission.photos (handles API differences automatically)
      final status = await Permission.photos.status;
      return status == PermissionStatus.granted;
    }
  }

  /// Request gallery/photos read permission with proper Android SDK detection
  Future<PermissionStatus> requestReadPermission() async {
    try {
      if (Platform.isIOS) {
        return await Permission.photos.request();
      } else if (Platform.isAndroid) {
        final AndroidDeviceInfo android = await DeviceInfoPlugin().androidInfo;
        final int sdkInt = android.version.sdkInt;
        
        // Android 13+ (API 33+) uses READ_MEDIA_IMAGES (Permission.photos)
        // Android 12 and below (API 32-) uses READ_EXTERNAL_STORAGE (Permission.storage)
        if (sdkInt > 32) {
          return await Permission.photos.request();
        } else {
          return await Permission.storage.request();
        }
      }
      return PermissionStatus.denied;
    } catch (e) {
      print('Error requesting photo permission: $e');
      return PermissionStatus.denied;
    }
  }

  /// Request photos write permission
  Future<PermissionStatus> requestWritePermission() async {
    if (Platform.isIOS) {
      return await Permission.photosAddOnly.request();
    } else {
      // Android: Use Permission.photos (handles API differences automatically)
      return await Permission.photos.request();
    }
  }

  /// Request both read and write permissions
  Future<Map<String, PermissionStatus>> requestBothPermissions() async {
    if (Platform.isIOS) {
      // iOS requires separate permissions for read and write
      final readStatus = await Permission.photos.request();
      final writeStatus = await Permission.photosAddOnly.request();

      return {'read': readStatus, 'write': writeStatus};
    } else {
      // Android: Use Permission.photos (handles API differences automatically)
      final status = await Permission.photos.request();
      return {'read': status, 'write': status};
    }
  }

  /// Handle comprehensive gallery permission request
  Future<PermissionStatus> handlePermissionRequest() async {
    try {
      // Check current permission status using same logic as isReadPermissionGranted
      final isGranted = await isReadPermissionGranted();
      
      if (isGranted) {
        // Return appropriate granted status for the current platform/API level
        if (Platform.isIOS) {
          final status = await Permission.photos.status;
          return status; // Could be granted or limited on iOS
        } else if (Platform.isAndroid) {
          final AndroidDeviceInfo android = await DeviceInfoPlugin().androidInfo;
          final int sdkInt = android.version.sdkInt;
          
          if (sdkInt > 32) {
            return await Permission.photos.status;
          } else {
            return await Permission.storage.status;
          }
        }
      }
      
      // If not granted, request using proper Android SDK detection
      return await requestReadPermission();
    } catch (e) {
      print('Error in handlePermissionRequest: $e');
      return PermissionStatus.denied;
    }
  }



  /// Get platform-specific permission rationale for read access
  String getReadPermissionRationale() {
    if (Platform.isIOS) {
      return 'ChatAway+ needs access to your photo library to let you share photos and memories with your friends.';
    } else {
      return 'To share photos in your conversations, ChatAway+ needs access to your photo gallery.';
    }
  }

  /// Get platform-specific permission rationale for write access
  String getWritePermissionRationale() {
    if (Platform.isIOS) {
      return 'ChatAway+ needs permission to save photos to your library when you download images from conversations.';
    } else {
      return 'To save photos from your conversations to your gallery, ChatAway+ needs storage access.';
    }
  }

  /// Get user-friendly status message
  String getStatusMessage(PermissionStatus status, {bool isWrite = false}) {
    final action = isWrite ? 'save photos' : 'access photos';

    switch (status) {
      case PermissionStatus.granted:
        return 'Permission granted to $action';
      case PermissionStatus.denied:
        return 'Permission denied to $action';
      case PermissionStatus.permanentlyDenied:
        return 'Permission to $action permanently denied. Please enable it in app settings.';
      case PermissionStatus.restricted:
        return 'Permission to $action restricted by device policy';
      case PermissionStatus.limited:
        return 'Limited permission granted to $action';
      case PermissionStatus.provisional:
        return 'Provisional permission granted to $action';
    }
  }

  /// Open app settings for manual permission grant
  Future<bool> openAppSettings() async {
    return await permission_handler.openAppSettings();
  }
}
