// lib/features/profile/data/datasources/profile_local_datasource.dart

import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';
import 'package:chataway_plus/core/database/app_database.dart';
import 'package:chataway_plus/core/storage/token_storage.dart';
import '../models/current_user_profile_model.dart';

/// Local datasource for profile - handles profile caching in database
/// Provides offline support and faster profile loading
abstract class ProfileLocalDataSource {
  /// Save/update current user profile to local database
  Future<void> saveProfile(CurrentUserProfileModel profile);

  /// Get current user profile from local database
  Future<CurrentUserProfileModel?> getProfile();

  /// Update profile name
  Future<void> updateName(String firstName, String? lastName);

  /// Update profile status
  Future<void> updateStatus(String statusContent);

  /// Update profile picture
  Future<void> updateProfilePicture(String? chatPictureUrl);

  /// Delete profile picture (set to null)
  Future<void> deleteProfilePicture();

  /// Clear profile data (logout)
  Future<void> clearProfile();

  /// Check if profile exists in local database
  Future<bool> profileExists();
}

/// Implementation of [ProfileLocalDataSource] using local database
class ProfileLocalDataSourceImpl implements ProfileLocalDataSource {
  ProfileLocalDataSourceImpl();

  void _log(String message) {
    if (kDebugMode) debugPrint(message);
  }

  @override
  Future<void> saveProfile(CurrentUserProfileModel profile) async {
    try {
      _log(
        '[ProfileLocal] saveProfile(): id=${profile.id} name=${profile.firstName} profilePic=${profile.profilePic ?? 'null'}',
      );
      final db = await AppDatabaseManager.instance.database;
      // Guard: never save without a valid user_id (prevents duplicate empty-key rows)
      var userId = profile.id?.trim() ?? '';
      if (userId.isEmpty) {
        userId =
            (await TokenSecureStorage.instance.getCurrentUserIdUUID())
                ?.trim() ??
            '';
      }
      if (userId.isEmpty) {
        _log('[ProfileLocal] saveProfile(): SKIP save — missing user_id');
        return;
      }
      final profileData = {
        CurrentUserProfileTable.columnUserId: userId,
        CurrentUserProfileTable.columnFirstName: profile.firstName ?? '',
        CurrentUserProfileTable.columnLastName: profile.lastName ?? '',
        CurrentUserProfileTable.columnMobileNo: profile.mobileNo ?? '',
        CurrentUserProfileTable.columnProfilePic: profile.profilePic,
        CurrentUserProfileTable.columnChatPictureVersion:
            profile.chatPictureVersion,
        CurrentUserProfileTable.columnStatusContent: profile.content ?? '',
        CurrentUserProfileTable.columnStatusCreatedAt:
            profile.statusCreatedAt?.millisecondsSinceEpoch,
        CurrentUserProfileTable.columnCurrentEmoji: profile.currentEmoji ?? '',
        CurrentUserProfileTable.columnEmojiCaption: profile.emojiCaption ?? '',
        CurrentUserProfileTable.columnEmojiUpdatedAt:
            profile.emojiUpdatedAt?.millisecondsSinceEpoch,
        CurrentUserProfileTable.columnCreatedAt:
            profile.createdAt?.millisecondsSinceEpoch ??
            DateTime.now().millisecondsSinceEpoch,
        CurrentUserProfileTable.columnLastUpdated:
            DateTime.now().millisecondsSinceEpoch,
      };

      // UPSERT by PRIMARY KEY (user_id) — WhatsApp-style single-source-of-truth
      await db.insert(
        CurrentUserProfileTable.tableName,
        profileData,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Also keep emoji_updates table in sync when profile response includes emoji_update
      final emojiId = profile.emojiUpdateId?.trim() ?? '';
      if (emojiId.isNotEmpty) {
        final emojiData = {
          EmojiTable.columnId: emojiId,
          EmojiTable.columnUserId:
              (profile.emojiUpdateUserId?.trim().isNotEmpty ?? false)
              ? profile.emojiUpdateUserId!.trim()
              : userId,
          EmojiTable.columnEmoji: profile.currentEmoji ?? '',
          EmojiTable.columnCaption: profile.emojiCaption ?? '',
          EmojiTable.columnDeletedAt: profile.emojiDeletedAt?.toIso8601String(),
          EmojiTable.columnCreatedAt: (profile.emojiCreatedAt ?? DateTime.now())
              .toIso8601String(),
          EmojiTable.columnUpdatedAt: (profile.emojiUpdatedAt ?? DateTime.now())
              .toIso8601String(),
          EmojiTable.columnUserFirstName: profile.firstName ?? '',
          EmojiTable.columnUserLastName: profile.lastName ?? '',
          EmojiTable.columnUserProfilePic: profile.profilePic ?? '',
        };
        await db.insert(
          EmojiTable.tableName,
          emojiData,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      _log('[ProfileLocal] saveProfile(): completed');
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<CurrentUserProfileModel?> getProfile() async {
    try {
      _log('[ProfileLocal] getProfile(): reading');
      final db = await AppDatabaseManager.instance.database;

      final List<Map<String, dynamic>> results = await db.query(
        CurrentUserProfileTable.tableName,
        where:
            '${CurrentUserProfileTable.columnUserId} IS NOT NULL AND ${CurrentUserProfileTable.columnUserId} != ?',
        whereArgs: [''],
        orderBy: '${CurrentUserProfileTable.columnLastUpdated} DESC',
        limit: 1,
      );

      if (results.isEmpty) {
        _log('[ProfileLocal] getProfile(): MISS');
        return null;
      }

      final row = results.first;
      _log(
        '[ProfileLocal] getProfile(): HIT -> name=${row[CurrentUserProfileTable.columnFirstName]}',
      );

      return CurrentUserProfileModel(
        id: row[CurrentUserProfileTable.columnUserId] as String?,
        firstName: row[CurrentUserProfileTable.columnFirstName] as String?,
        lastName: row[CurrentUserProfileTable.columnLastName] as String?,
        mobileNo: row[CurrentUserProfileTable.columnMobileNo] as String?,
        profilePic: row[CurrentUserProfileTable.columnProfilePic] as String?,
        chatPictureVersion:
            row[CurrentUserProfileTable.columnChatPictureVersion] as String?,
        content: row[CurrentUserProfileTable.columnStatusContent] as String?,
        statusCreatedAt: _parseDateTime(
          row[CurrentUserProfileTable.columnStatusCreatedAt],
        ),
        currentEmoji:
            row[CurrentUserProfileTable.columnCurrentEmoji] as String?,
        emojiCaption:
            row[CurrentUserProfileTable.columnEmojiCaption] as String?,
        emojiUpdatedAt: _parseDateTime(
          row[CurrentUserProfileTable.columnEmojiUpdatedAt],
        ),
        createdAt: _parseDateTime(row[CurrentUserProfileTable.columnCreatedAt]),
        updatedAt: _parseDateTime(
          row[CurrentUserProfileTable.columnLastUpdated],
        ),
      );
    } catch (e) {
      _log('[ProfileLocal] getProfile(): error: $e');
      return null;
    }
  }

  @override
  Future<void> updateName(String firstName, String? lastName) async {
    try {
      _log('[ProfileLocal] updateName(): $firstName');
      final db = await AppDatabaseManager.instance.database;

      await db.update(CurrentUserProfileTable.tableName, {
        CurrentUserProfileTable.columnFirstName: firstName,
        CurrentUserProfileTable.columnLastName: lastName ?? '',
        CurrentUserProfileTable.columnLastUpdated:
            DateTime.now().millisecondsSinceEpoch,
      });
      _log('[ProfileLocal] updateName(): completed');
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> updateStatus(String statusContent) async {
    try {
      _log('[ProfileLocal] updateStatus(): len=${statusContent.length}');
      final db = await AppDatabaseManager.instance.database;

      await db.update(CurrentUserProfileTable.tableName, {
        CurrentUserProfileTable.columnStatusContent: statusContent,
        CurrentUserProfileTable.columnStatusCreatedAt:
            DateTime.now().millisecondsSinceEpoch,
        CurrentUserProfileTable.columnLastUpdated:
            DateTime.now().millisecondsSinceEpoch,
      });
      _log('[ProfileLocal] updateStatus(): completed');
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> updateProfilePicture(String? chatPictureUrl) async {
    try {
      _log(
        '[ProfileLocal] updateProfilePicture(): ${chatPictureUrl != null ? 'set' : 'null'}',
      );
      final db = await AppDatabaseManager.instance.database;

      final values = <String, Object?>{
        CurrentUserProfileTable.columnProfilePic: chatPictureUrl,
        CurrentUserProfileTable.columnLastUpdated:
            DateTime.now().millisecondsSinceEpoch,
      };
      if (chatPictureUrl == null) {
        values[CurrentUserProfileTable.columnChatPictureVersion] = null;
      }
      await db.update(CurrentUserProfileTable.tableName, values);
      _log('[ProfileLocal] updateProfilePicture(): completed');
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> deleteProfilePicture() async {
    _log('[ProfileLocal] deleteProfilePicture()');
    await updateProfilePicture(null);
  }

  @override
  Future<void> clearProfile() async {
    try {
      _log('[ProfileLocal] clearProfile()');
      final db = await AppDatabaseManager.instance.database;
      await db.delete(CurrentUserProfileTable.tableName);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<bool> profileExists() async {
    try {
      _log('[ProfileLocal] profileExists()');
      final db = await AppDatabaseManager.instance.database;
      final count = Sqflite.firstIntValue(
        await db.rawQuery(
          'SELECT COUNT(*) FROM ${CurrentUserProfileTable.tableName}',
        ),
      );
      _log('[ProfileLocal] profileExists(): ${(count ?? 0) > 0}');
      return (count ?? 0) > 0;
    } catch (e) {
      return false;
    }
  }

  /// Helper to parse DateTime from milliseconds
  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    return null;
  }
}
