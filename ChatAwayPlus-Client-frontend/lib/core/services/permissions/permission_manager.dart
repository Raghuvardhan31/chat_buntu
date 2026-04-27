import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:permission_handler/permission_handler.dart' show PermissionStatus, Permission, openAppSettings;
import 'contacts_permission_service.dart';
import 'photos_permission_service.dart';

enum AppPermissionType {
  contacts,
  photosRead,
  photosWrite,
  camera,
  microphone,
  storage,
  location,
  notifications,
}

class PermissionResult {
  final AppPermissionType type;
  final PermissionStatus status;
  final String message;

  PermissionResult({
    required this.type,
    required this.status,
    required this.message,
  });

  bool get isGranted => status == PermissionStatus.granted;
  bool get isDenied => status == PermissionStatus.denied;
  bool get isPermanentlyDenied => status == PermissionStatus.permanentlyDenied;
  bool get isRestricted => status == PermissionStatus.restricted;
  bool get isLimited => status == PermissionStatus.limited;
}

class PermissionManager {
  static final PermissionManager _instance = PermissionManager._internal();
  factory PermissionManager() => _instance;
  PermissionManager._internal();

  static PermissionManager get instance => _instance;

  final ContactPermissionsService _contactsService =
      ContactPermissionsService.instance;
  final PhotosPermissionService _photosService =
      PhotosPermissionService.instance;

  // =============================================================================
  // INDIVIDUAL PERMISSION CHECKS
  // =============================================================================

  /// Check if a specific permission is granted
  Future<bool> isPermissionGranted(AppPermissionType type) async {
    switch (type) {
      case AppPermissionType.contacts:
        return await _contactsService.isPermissionGranted();
      case AppPermissionType.photosRead:
        return await _photosService.isReadPermissionGranted();
      case AppPermissionType.photosWrite:
        return await _photosService.isWritePermissionGranted();
      case AppPermissionType.camera:
        return await Permission.camera.isGranted;
      case AppPermissionType.microphone:
        return await Permission.microphone.isGranted;
      case AppPermissionType.storage:
        return await Permission.storage.isGranted;
      case AppPermissionType.location:
        return await Permission.location.isGranted;
      case AppPermissionType.notifications:
        return await Permission.notification.isGranted;
    }
  }

  /// Get the status of a specific permission
  Future<PermissionStatus> getPermissionStatus(AppPermissionType type) async {
    switch (type) {
      case AppPermissionType.contacts:
        return await _contactsService.getPermissionStatus();
      case AppPermissionType.photosRead:
      case AppPermissionType.photosWrite:
        if (Platform.isIOS) {
          return type == AppPermissionType.photosRead
              ? await Permission.photos.status
              : await Permission.photosAddOnly.status;
        } else {
          return await Permission.photos.status;
        }
      case AppPermissionType.camera:
        return await Permission.camera.status;
      case AppPermissionType.microphone:
        return await Permission.microphone.status;
      case AppPermissionType.storage:
        return await Permission.storage.status;
      case AppPermissionType.location:
        return await Permission.location.status;
      case AppPermissionType.notifications:
        return await Permission.notification.status;
    }
  }

  // =============================================================================
  // BATCH PERMISSION OPERATIONS
  // =============================================================================

  /// Request multiple permissions at once
  Future<Map<AppPermissionType, PermissionResult>> requestMultiplePermissions(
    List<AppPermissionType> permissions,
  ) async {
    Map<AppPermissionType, PermissionResult> results = {};

    for (AppPermissionType permission in permissions) {
      final result = await requestSinglePermission(permission);
      results[permission] = result;
    }

    return results;
  }

  /// Request a single permission with comprehensive result
  Future<PermissionResult> requestSinglePermission(
    AppPermissionType type,
  ) async {
    try {
      PermissionStatus status;
      String message;

      switch (type) {
        case AppPermissionType.contacts:
          status = await _contactsService.handlePermissionRequest();
          message = _contactsService.getStatusMessage(status);
          break;

        case AppPermissionType.photosRead:
          status = await _photosService.requestReadPermission();
          message = _photosService.getStatusMessage(status, isWrite: false);
          break;

        case AppPermissionType.photosWrite:
          status = await _photosService.requestWritePermission();
          message = _photosService.getStatusMessage(status, isWrite: true);
          break;

        case AppPermissionType.camera:
          status = await Permission.camera.request();
          message = _getGenericStatusMessage(status, 'camera');
          break;

        case AppPermissionType.microphone:
          status = await Permission.microphone.request();
          message = _getGenericStatusMessage(status, 'microphone');
          break;

        case AppPermissionType.storage:
          status = await Permission.storage.request();
          message = _getGenericStatusMessage(status, 'storage');
          break;

        case AppPermissionType.location:
          status = await Permission.location.request();
          message = _getGenericStatusMessage(status, 'location');
          break;

        case AppPermissionType.notifications:
          status = await Permission.notification.request();
          message = _getGenericStatusMessage(status, 'notifications');
          break;
      }

      return PermissionResult(type: type, status: status, message: message);
    } catch (e) {
      return PermissionResult(
        type: type,
        status: PermissionStatus.denied,
        message: 'Error requesting permission: $e',
      );
    }
  }

  // =============================================================================
  // ESSENTIAL PERMISSIONS FOR APP
  // =============================================================================

  /// Get list of essential permissions required for app functionality
  List<AppPermissionType> getEssentialPermissions() {
    return [AppPermissionType.contacts, AppPermissionType.photosRead];
  }

  /// Check if all essential permissions are granted
  Future<bool> hasAllEssentialPermissions() async {
    final essentialPermissions = getEssentialPermissions();

    for (AppPermissionType permission in essentialPermissions) {
      if (!await isPermissionGranted(permission)) {
        return false;
      }
    }

    return true;
  }

  /// Request all essential permissions
  Future<Map<AppPermissionType, PermissionResult>>
  requestEssentialPermissions() async {
    return await requestMultiplePermissions(getEssentialPermissions());
  }

  // =============================================================================
  // PERMISSION FLOW HELPERS
  // =============================================================================

  /// Check and request permissions with user-friendly flow
  Future<bool> ensurePermissionGranted(
    AppPermissionType type, {
    required BuildContext context,
    String? customRationale,
  }) async {
    final status = await getPermissionStatus(type);

    if (status == PermissionStatus.granted) {
      return true;
    }

    if (status == PermissionStatus.permanentlyDenied) {
      if (!context.mounted) return false;
      return await _showSettingsDialog(context, type);
    }

    // Show rationale if needed
    if (customRationale != null) {
      if (!context.mounted) return false;
      final shouldProceed = await _showRationaleDialog(
        context,
        type,
        customRationale,
      );
      if (!shouldProceed) return false;
    }

    final result = await requestSinglePermission(type);
    return result.isGranted;
  }

  /// Show rationale dialog before requesting permission
  Future<bool> _showRationaleDialog(
    BuildContext context,
    AppPermissionType type,
    String rationale,
  ) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Permission Required'),
            content: Text(rationale),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Continue'),
              ),
            ],
          ),
        ) ??
        false;
  }

  /// Show settings dialog for permanently denied permissions
  Future<bool> _showSettingsDialog(
    BuildContext context,
    AppPermissionType type,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Permission Required'),
        content: Text(
          'This permission has been permanently denied. Please enable it in app settings to continue.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context, true);
              await ph.openAppSettings();
            },
            child: Text('Open Settings'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  // =============================================================================
  // UTILITY METHODS
  // =============================================================================

  /// Get user-friendly permission name
  String getPermissionName(AppPermissionType type) {
    switch (type) {
      case AppPermissionType.contacts:
        return 'Contacts';
      case AppPermissionType.photosRead:
        return 'Photo Library (Read)';
      case AppPermissionType.photosWrite:
        return 'Photo Library (Write)';
      case AppPermissionType.camera:
        return 'Camera';
      case AppPermissionType.microphone:
        return 'Microphone';
      case AppPermissionType.storage:
        return 'Storage';
      case AppPermissionType.location:
        return 'Location';
      case AppPermissionType.notifications:
        return 'Notifications';
    }
  }

  /// Get generic status message for standard permissions
  String _getGenericStatusMessage(
    PermissionStatus status,
    String permissionName,
  ) {
    switch (status) {
      case PermissionStatus.granted:
        return '$permissionName access granted';
      case PermissionStatus.denied:
        return '$permissionName access denied';
      case PermissionStatus.permanentlyDenied:
        return '$permissionName access permanently denied. Please enable it in app settings.';
      case PermissionStatus.restricted:
        return '$permissionName access restricted by device policy';
      case PermissionStatus.limited:
        return 'Limited $permissionName access granted';
      case PermissionStatus.provisional:
        return 'Provisional $permissionName access granted';
    }
  }

  /// Open app settings
  Future<bool> openAppSettings() async {
    return await ph.openAppSettings();
  }

  /// Check if permission should show rationale (Android)
  Future<bool> shouldShowRationale(AppPermissionType type) async {
    if (!Platform.isAndroid) return false;

    switch (type) {
      case AppPermissionType.contacts:
        return await _contactsService.shouldShowRequestPermissionRationale();
      default:
        final status = await getPermissionStatus(type);
        return status == PermissionStatus.denied;
    }
  }
}
