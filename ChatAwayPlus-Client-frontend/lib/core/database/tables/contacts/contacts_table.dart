// ============================================================================
// CONTACTS TABLE - Schema Definition & CRUD Operations
// ============================================================================
// This file defines the structure of the contacts table.
// Stores device contacts with their ChatAway+ registration status
// ============================================================================

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:chataway_plus/features/contacts/data/models/contact_local.dart';
import '../../app_database.dart';

// ============================================================================
// CONTACTS TABLE - Schema Definition & CRUD Operations
// ============================================================================

class ContactsTable {
  // ============================================================================
  // SCHEMA DEFINITIONS
  // ============================================================================

  /// Table name constant
  static const String tableName = 'contacts';

  /// Column name constants
  static const String columnContactHash = 'contact_hash';
  static const String columnContactName = 'name';
  static const String columnContactMobileNumber = 'mobile_no';
  static const String columnIsRegistered = 'is_registered';
  static const String columnLastUpdated = 'last_updated';
  static const String columnUserDetails = 'user_details';
  static const String columnAppUserId = 'app_user_id';

  /// SQL CREATE TABLE statement - Contacts Table
  ///
  /// Stores device contacts with their ChatAway+ registration status
  /// Example user_details JSON:
  /// {
  ///   "user_id": "bb008d15-dda6-44d1-b56f-8cfa926e966e",
  ///   "contact_name": "M Gangadhar",
  ///   "chat_picture": "/api/images/stream/profile/{userId}/{file}",
  ///   "chat_picture_version": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  ///   "recentStatus": {
  ///     "share_your_voice": "Hello Chataway+",
  ///     "createdAt": "2025-09-11T18:00:44.000Z"
  ///   },
  ///   "recentEmojiUpdate": null
  /// }
  static const String createTableSQL =
      '''
CREATE TABLE $tableName (
  $columnContactHash TEXT PRIMARY KEY,     -- Hash of phone number (unique identifier)
  $columnContactName TEXT NOT NULL,          -- Display name from device contacts
  $columnContactMobileNumber TEXT NOT NULL,  -- Phone number
  $columnIsRegistered INTEGER DEFAULT 0,    -- 1 = has ChatAway+ account, 0 = not registered
  $columnLastUpdated INTEGER NOT NULL,      -- Timestamp of last sync
  $columnUserDetails TEXT,                  -- JSON string with ChatAway+ user data (if registered)
  $columnAppUserId TEXT                     -- ChatAway+ user UUID (if registered)
)
''';

  // ============================================================================
  // SINGLETON INSTANCE
  // ============================================================================

  ContactsTable._();
  static final ContactsTable _instance = ContactsTable._();
  static ContactsTable get instance => _instance;

  // Get database from AppDatabaseManager
  Future<Database> get _database async {
    return await AppDatabaseManager.instance.database;
  }

  // --------------------------------------------------------------------------
  // INSERT/UPDATE OPERATIONS
  // --------------------------------------------------------------------------

  Future<void> insertOrUpdateContact(ContactLocal contact) async {
    final db = await _database;
    final map = Map<String, dynamic>.from(contact.toMap());

    // Ensure last_updated stored as epoch ms
    if (map['last_updated'] is DateTime) {
      map['last_updated'] =
          (map['last_updated'] as DateTime).millisecondsSinceEpoch;
    }

    // Convert userDetails to JSON if present
    if (map['user_details'] != null && map['user_details'] is Map) {
      map['user_details'] = jsonEncode(map['user_details']);
    }

    await db.insert(
      tableName,
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertOrUpdateContacts(List<ContactLocal> contacts) async {
    final db = await _database;
    final batch = db.batch();

    for (final c in contacts) {
      final map = Map<String, dynamic>.from(c.toMap());
      if (map['last_updated'] is DateTime) {
        map['last_updated'] =
            (map['last_updated'] as DateTime).millisecondsSinceEpoch;
      }
      if (map['user_details'] != null && map['user_details'] is Map) {
        map['user_details'] = jsonEncode(map['user_details']);
      }
      batch.insert(
        tableName,
        map,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  // --------------------------------------------------------------------------
  // QUERY OPERATIONS
  // --------------------------------------------------------------------------

  /// Helper: convert DB rows to ContactLocal objects
  List<ContactLocal> _mapContactsFromDb(List<Map<String, dynamic>> maps) {
    return maps.map((map) {
      // parse user_details JSON string to Map if present
      Map<String, dynamic>? userDetails;
      if (map[columnUserDetails] != null && map[columnUserDetails] is String) {
        try {
          final decoded = jsonDecode(map[columnUserDetails] as String);
          if (decoded is Map<String, dynamic>) {
            userDetails = decoded;
          }
        } catch (_) {
          userDetails = null;
        }
      }

      final contactMap = {
        columnContactHash: map[columnContactHash],
        columnContactName: map[columnContactName],
        columnContactMobileNumber: map[columnContactMobileNumber],
        columnIsRegistered: map[columnIsRegistered],
        columnLastUpdated: map[columnLastUpdated],
        columnUserDetails: userDetails,
        columnAppUserId: map[columnAppUserId],
      };

      return ContactLocal.fromMap(contactMap);
    }).toList();
  }

  /// Get all contacts
  Future<List<ContactLocal>> getAllContacts() async {
    try {
      final db = await _database;
      final rows = await db.query(
        tableName,
        orderBy: 'name COLLATE NOCASE ASC',
      );
      return _mapContactsFromDb(rows);
    } catch (e) {
      debugPrint('❌ Error getting all contacts: $e');
      return [];
    }
  }

  /// Get registered contacts
  Future<List<ContactLocal>> getRegisteredContacts() async {
    try {
      final db = await _database;
      final rows = await db.query(
        tableName,
        where: 'is_registered = ?',
        whereArgs: [1],
        orderBy: 'name COLLATE NOCASE ASC',
      );
      return _mapContactsFromDb(rows);
    } catch (e) {
      debugPrint('❌ Error getting registered contacts: $e');
      return [];
    }
  }

  /// Get non-registered contacts
  Future<List<ContactLocal>> getNonRegisteredContacts() async {
    try {
      final db = await _database;
      final rows = await db.query(
        tableName,
        where: 'is_registered = ?',
        whereArgs: [0],
        orderBy: 'name COLLATE NOCASE ASC',
      );
      return _mapContactsFromDb(rows);
    } catch (e) {
      debugPrint('❌ Error getting non-registered contacts: $e');
      return [];
    }
  }

  Future<ContactLocal?> getContactById(String contactHash) async {
    try {
      final db = await _database;
      final rows = await db.query(
        tableName,
        where: 'contact_hash = ?',
        whereArgs: [contactHash],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return _mapContactsFromDb(rows).first;
    } catch (e) {
      debugPrint('❌ Error getting contact by id: $e');
      return null;
    }
  }

  Future<ContactLocal?> getContactByAppUserId(String appUserId) async {
    try {
      final db = await _database;
      final rows = await db.query(
        tableName,
        where: 'app_user_id = ?',
        whereArgs: [appUserId],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return _mapContactsFromDb(rows).first;
    } catch (e) {
      debugPrint('❌ Error getting contact by appUserId: $e');
      return null;
    }
  }

  /// Get contact by mobile number (for contact_joined FCM)
  Future<ContactLocal?> getContactByMobile(String mobileNo) async {
    try {
      final db = await _database;

      // Normalize the mobile number - remove non-digits and get last 10 digits
      final normalizedInput = mobileNo.replaceAll(RegExp(r'[^0-9]'), '');
      final last10 = normalizedInput.length > 10
          ? normalizedInput.substring(normalizedInput.length - 10)
          : normalizedInput;

      // Try exact match first
      var rows = await db.query(
        tableName,
        where: 'mobile_no = ?',
        whereArgs: [mobileNo],
        limit: 1,
      );

      // If not found, try matching last 10 digits
      if (rows.isEmpty && last10.length >= 10) {
        rows = await db.query(
          tableName,
          where: 'mobile_no LIKE ?',
          whereArgs: ['%$last10'],
          limit: 1,
        );
      }

      if (rows.isEmpty) return null;
      return _mapContactsFromDb(rows).first;
    } catch (e) {
      debugPrint('❌ Error getting contact by mobile: $e');
      return null;
    }
  }

  // --------------------------------------------------------------------------
  // UPDATE OPERATIONS
  // --------------------------------------------------------------------------

  Future<void> updateContactRegistrationStatus(
    String contactHash,
    bool isRegistered, {
    bool clearUserDetails = false,
  }) async {
    try {
      final db = await _database;
      final Map<String, Object?> updates = {
        'is_registered': isRegistered ? 1 : 0,
      };
      if (clearUserDetails) {
        updates['user_details'] = null;
        updates['app_user_id'] = null;
      }
      await db.update(
        tableName,
        updates,
        where: 'contact_hash = ?',
        whereArgs: [contactHash],
      );
    } catch (e) {
      debugPrint('❌ Error updating contact registration status: $e');
      rethrow;
    }
  }

  // --------------------------------------------------------------------------
  // DELETE OPERATIONS
  // --------------------------------------------------------------------------

  Future<int> pruneDeletedContacts(
    List<ContactLocal> currentDeviceContacts,
  ) async {
    try {
      final db = await _database;
      final deviceIds = currentDeviceContacts.map((c) => c.contactHash).toSet();

      final rows = await db.query(tableName, columns: ['contact_hash']);
      final dbIds = rows.map((r) => r['contact_hash'] as String).toSet();

      final toDelete = dbIds.difference(deviceIds);
      if (toDelete.isEmpty) return 0;

      int deleted = 0;
      for (final id in toDelete) {
        deleted += await db.delete(
          tableName,
          where: 'contact_hash = ?',
          whereArgs: [id],
        );
      }
      return deleted;
    } catch (e) {
      debugPrint('❌ Error pruning contacts: $e');
      return 0;
    }
  }

  Future<void> clearAllContacts() async {
    try {
      final db = await _database;
      await db.delete(tableName);
    } catch (e) {
      debugPrint('❌ Error clearing contacts: $e');
      rethrow;
    }
  }

  // --------------------------------------------------------------------------
  // STATISTICS OPERATIONS
  // --------------------------------------------------------------------------

  Future<Map<String, int>> getCacheStatistics() async {
    try {
      final db = await _database;
      final totalRow = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $tableName',
      );
      final regRow = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $tableName WHERE is_registered = 1',
      );
      final total = totalRow.first['count'] as int? ?? 0;
      final registered = regRow.first['count'] as int? ?? 0;
      return {
        'total': total,
        'registered': registered,
        'non_registered': total - registered,
      };
    } catch (e) {
      debugPrint('❌ Error getting cache statistics: $e');
      return {'total': 0, 'registered': 0, 'non_registered': 0};
    }
  }

  Future<void> logContacts() async {
    final stats = await getCacheStatistics();
    debugPrint(
      'Contacts: total=${stats['total']}, registered=${stats['registered']}, non_registered=${stats['non_registered']}',
    );
  }
}
