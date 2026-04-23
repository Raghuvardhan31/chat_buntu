import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

// Import the top-level function from permission_handler
import 'package:permission_handler/permission_handler.dart' as permission_handler;

class ContactPermissionsService {
  static final ContactPermissionsService _instance = ContactPermissionsService._internal();
  factory ContactPermissionsService() => _instance;
  ContactPermissionsService._internal();

  static ContactPermissionsService get instance => _instance;

  /// Check if contacts permission is granted
  Future<bool> isPermissionGranted() async {
    final status = await Permission.contacts.status;
    return status == PermissionStatus.granted;
  }

  /// Check the current permission status
  Future<PermissionStatus> getPermissionStatus() async {
    return await Permission.contacts.status;
  }

  /// Request contacts permission
  Future<PermissionStatus> requestPermission() async {
    final status = await Permission.contacts.request();
    return status;
  }

  /// Handle permission request with comprehensive logic
  Future<PermissionStatus> handlePermissionRequest() async {
    // Check current status
    PermissionStatus status = await Permission.contacts.status;
    
    switch (status) {
      case PermissionStatus.granted:
        return status;
        
      case PermissionStatus.denied:
        // Request permission
        status = await Permission.contacts.request();
        return status;
        
      case PermissionStatus.permanentlyDenied:
        // Permission permanently denied, user needs to enable it manually
        return status;
        
      case PermissionStatus.restricted:
        // Permission restricted (iOS parental controls, etc.)
        return status;
        
      case PermissionStatus.limited:
        // Limited access (iOS 14+)
        return status;
        
      case PermissionStatus.provisional:
        // Provisional permission (rare case)
        return status;
    }
  }

  /// Open app settings for manual permission grant
  Future<bool> openAppSettings() async {
    return await permission_handler.openAppSettings();
  }

  /// Get platform-specific permission rationale
  String getPermissionRationale() {
    if (Platform.isIOS) {
      return 'ChatAway+ needs access to your contacts to help you find friends who are already using the app and to make it easier to connect with them.';
    } else {
      return 'To help you find friends on ChatAway+ and make connecting easier, we need access to your contacts. Your contact information will be kept secure and private.';
    }
  }

  /// Check if we should show rationale (Android specific)
  Future<bool> shouldShowRequestPermissionRationale() async {
    if (Platform.isAndroid) {
      final status = await Permission.contacts.status;
      return status == PermissionStatus.denied;
    }
    return false;
  }

  /// Get user-friendly status message
  String getStatusMessage(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.granted:
        return 'Contacts access granted';
      case PermissionStatus.denied:
        return 'Contacts access denied';
      case PermissionStatus.permanentlyDenied:
        return 'Contacts access permanently denied. Please enable it in app settings.';
      case PermissionStatus.restricted:
        return 'Contacts access restricted by device policy';
      case PermissionStatus.limited:
        return 'Limited contacts access granted';
      case PermissionStatus.provisional:
        return 'Provisional contacts access granted';
    }
  }
}
