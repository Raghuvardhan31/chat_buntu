// ============================================================================
// MOBILE NUMBER TABLE - Schema Definition & CRUD Operations
// ============================================================================
// Stores authenticated user's mobile number
// Single-row table design (id always = 1)
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../../app_database.dart';

class MobileNumberTable {
  // ============================================================================
  // SCHEMA DEFINITIONS
  // ============================================================================

  /// Table name constant
  static const String tableName = 'mobile_number';

  /// Column name constants
  static const String columnId = 'id'; // Always 1 (single row table)
  static const String columnMobileNo = 'mobile_no'; // User's mobile number
  static const String columnCountryCode = 'country_code'; // Country code
  static const String columnLastUpdated =
      'last_updated'; // Last update timestamp

  /// SQL CREATE TABLE statement - Mobile Number Table
  /// Single-row table with id constraint (always = 1)
  static const String createTableSQL =
      '''
CREATE TABLE $tableName (
  $columnId INTEGER PRIMARY KEY CHECK ($columnId = 1),  -- Always single row
  $columnMobileNo TEXT NOT NULL,         -- Mobile number
  $columnCountryCode TEXT DEFAULT '+91', -- Country code
  $columnLastUpdated INTEGER NOT NULL    -- Last updated timestamp
)
''';

  // ============================================================================
  // SINGLETON INSTANCE
  // ============================================================================

  MobileNumberTable._();
  static final MobileNumberTable _instance = MobileNumberTable._();
  static MobileNumberTable get instance => _instance;

  // Get database from AppDatabaseManager
  Future<Database> get _database async {
    return await AppDatabaseManager.instance.database;
  }

  // ============================================================================
  // CRUD OPERATIONS (Single-row table)
  // ============================================================================

  /// Save or update mobile number (always id = 1)
  Future<void> saveMobileNumber({
    required String mobileNo,
    String countryCode = '+91',
  }) async {
    try {
      final db = await _database;
      await db.insert(tableName, {
        columnId: 1,
        columnMobileNo: mobileNo,
        columnCountryCode: countryCode,
        columnLastUpdated: DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      debugPrint('✅ Mobile number saved: $countryCode $mobileNo');
    } catch (e) {
      debugPrint('❌ Error saving mobile number: $e');
      rethrow;
    }
  }

  /// Get saved mobile number
  Future<Map<String, dynamic>?> getMobileNumber() async {
    try {
      final db = await _database;
      final rows = await db.query(
        tableName,
        where: '$columnId = ?',
        whereArgs: [1],
        limit: 1,
      );

      if (rows.isEmpty) return null;

      return {
        'mobile_no': rows.first[columnMobileNo] as String,
        'country_code': rows.first[columnCountryCode] as String,
        'last_updated': rows.first[columnLastUpdated] as int,
      };
    } catch (e) {
      debugPrint('❌ Error getting mobile number: $e');
      return null;
    }
  }

  /// Update mobile number
  Future<void> updateMobileNumber({
    required String mobileNo,
    String? countryCode,
  }) async {
    try {
      final db = await _database;
      final updates = <String, dynamic>{
        columnMobileNo: mobileNo,
        columnLastUpdated: DateTime.now().millisecondsSinceEpoch,
      };

      if (countryCode != null) {
        updates[columnCountryCode] = countryCode;
      }

      await db.update(
        tableName,
        updates,
        where: '$columnId = ?',
        whereArgs: [1],
      );
      debugPrint('✅ Mobile number updated: $mobileNo');
    } catch (e) {
      debugPrint('❌ Error updating mobile number: $e');
      rethrow;
    }
  }

  /// Clear mobile number
  Future<void> clearMobileNumber() async {
    try {
      final db = await _database;
      await db.delete(tableName, where: '$columnId = ?', whereArgs: [1]);
      debugPrint('✅ Mobile number cleared');
    } catch (e) {
      debugPrint('❌ Error clearing mobile number: $e');
      rethrow;
    }
  }

  /// Check if mobile number exists
  Future<bool> hasMobileNumber() async {
    try {
      final result = await getMobileNumber();
      return result != null;
    } catch (e) {
      debugPrint('❌ Error checking mobile number: $e');
      return false;
    }
  }
}
