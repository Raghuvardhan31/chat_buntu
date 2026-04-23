// ============================================================================
// AUTH LOCAL DATASOURCE - Saves ONLY mobile number to DATABASE
// ============================================================================

import 'package:flutter/foundation.dart';
// TODO: Import AppDatabaseManager when it's created
// import 'package:chataway_plus/core/local_storage/app_database_manager.dart';

/// Local datasource for authentication - ONLY handles mobile number storage
abstract class AuthLocalDataSource {
  /// Save mobile number to DATABASE
  Future<void> saveMobileNumber(String mobileNo);

  /// Get saved mobile number from DATABASE
  Future<String?> getMobileNumber();

  /// Clear mobile number from DATABASE (logout)
  Future<void> clearMobileNumber();
}

/// Implementation of [AuthLocalDataSource] using DATABASE (not secure storage)
/// SIMPLIFIED: Only stores mobile number in mobile_number table
class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  // No secure storage - we use database!

  //=================================================================
  // SAVE MOBILE NUMBER TO DATABASE
  // NOTE: Mobile number comes FROM API response (via repository)
  // Flow: API → Repository extracts mobile_no → Passes here → Save to DB
  //=================================================================

  @override
  Future<void> saveMobileNumber(String mobileNo) async {
    try {
      _logInfo(
        'SaveMobile',
        'Saving mobile number to database (from API response)',
      );

      // TODO: Uncomment when AppDatabaseManager is created
      // await AppDatabaseManager.instance.saveMobileNumber(
      //   mobileNo: mobileNo,  // This comes FROM server API response!
      //   countryCode: '+91',
      // );

      _logInfo('SaveMobile', 'Mobile number saved successfully to database');
    } catch (e) {
      _logError('SaveMobile', 'Failed to save mobile number: $e');
      rethrow;
    }
  }

  //=================================================================
  // GET MOBILE NUMBER FROM DATABASE
  //=================================================================

  @override
  Future<String?> getMobileNumber() async {
    try {
      _logInfo('GetMobile', 'Retrieving mobile number from database');

      // TODO: Uncomment when AppDatabaseManager is created
      // final mobileNo = await AppDatabaseManager.instance.getMobileNumber();
      final String? mobileNo = null; // Temporary

      if (mobileNo != null) {
        _logInfo(
          'GetMobile',
          'Mobile number retrieved successfully from database',
        );
      } else {
        _logInfo('GetMobile', 'No mobile number found in database');
      }

      return mobileNo;
    } catch (e) {
      _logError('GetMobile', 'Failed to retrieve mobile number: $e');
      return null;
    }
  }

  //=================================================================
  // CLEAR MOBILE NUMBER FROM DATABASE (LOGOUT)
  //=================================================================

  @override
  Future<void> clearMobileNumber() async {
    try {
      _logInfo('ClearMobile', 'Clearing mobile number from database');

      // TODO: Uncomment when AppDatabaseManager is created
      // await AppDatabaseManager.instance.clearMobileNumber();

      _logInfo(
        'ClearMobile',
        'Mobile number cleared successfully from database',
      );
    } catch (e) {
      _logError('ClearMobile', 'Failed to clear mobile number: $e');
      rethrow;
    }
  }

  //=================================================================
  // HELPER METHODS FOR LOGGING
  //=================================================================

  void _logInfo(String operation, String message) {
    if (kDebugMode) {
      print('💾 AUTH_LOCAL [$operation]: $message');
    }
  }

  void _logError(String operation, String message) {
    if (kDebugMode) {
      print('❌ AUTH_LOCAL [$operation]: $message');
    }
  }
}
