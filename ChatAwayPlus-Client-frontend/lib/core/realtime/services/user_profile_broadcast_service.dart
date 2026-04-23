import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:chataway_plus/core/notifications/cache/profile_picture_cache_manager.dart';
import 'package:chataway_plus/core/realtime/models/user_profile_broadcast_event.dart';
import 'package:chataway_plus/features/chat/data/services/local/chat_picture_likes_local_db.dart';
import 'package:chataway_plus/features/contacts/data/datasources/contacts_database_service.dart';

/// Handles realtime profile update broadcasts (WebSocket + FCM).
class UserProfileBroadcastService {
  UserProfileBroadcastService({
    required ValueGetter<String?> getCurrentUserId,
    required void Function(UserProfileBroadcastEvent) emitUpdate,
  }) : _getCurrentUserId = getCurrentUserId,
       _emitUpdate = emitUpdate;

  final ValueGetter<String?> _getCurrentUserId;
  final void Function(UserProfileBroadcastEvent) _emitUpdate;

  /// Handle profile update from WebSocket
  void handleProfileUpdateInternal(UserProfileBroadcastEvent update) {
    Future.microtask(() async {
      try {
        if (kDebugMode) {
          debugPrint('👤 PROCESSING PROFILE UPDATE for ${update.userId}');
        }

        // Skip profile updates for current user
        final currentUserId = _getCurrentUserId();
        if (currentUserId != null && update.userId == currentUserId) {
          if (kDebugMode) {
            debugPrint('👤 Profile update is for current user – ignoring');
          }
          return;
        }

        String? previousChatPictureUrl;
        try {
          final existing = await ContactsDatabaseService.instance
              .getContactByUserId(update.userId);
          previousChatPictureUrl = existing?.userDetails?.chatPictureUrl;
        } catch (_) {}

        final picUrl = update.chatPictureUrl;
        if (picUrl != null || update.chatPictureVersion != null) {
          _fireAndForget(
            ProfilePictureCacheManager.instance.invalidateCacheForUser(
              update.userId,
            ),
          );
        }

        // 1. Update local contacts database
        final updated = await ContactsDatabaseService.instance
            .updateContactProfile(
              userId: update.userId,
              name: update.name,
              chatPictureUrl: update.chatPictureUrl,
              chatPictureVersion: update.chatPictureVersion,
              statusContent: update.status,
              emoji: update.emoji,
              emojiCaption: update.emojiCaption,
            );

        if (currentUserId != null &&
            picUrl != null &&
            picUrl.isNotEmpty &&
            previousChatPictureUrl != picUrl) {
          await ChatPictureLikesDatabaseService.instance.clearForLikedUserId(
            currentUserId: currentUserId,
            likedUserId: update.userId,
          );
        }

        if (kDebugMode && updated) {
          debugPrint('👤 Local DB updated for ${update.userId}');
        }

        // 2. Notify all UI pages via stream
        _emitUpdate(update);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('❌ Error handling profile update: $e');
        }
      }
    });
  }

  /// Handle FCM profile update (for offline contacts)
  void handleFCMProfileUpdate(Map<String, dynamic> data) {
    try {
      if (kDebugMode) {
        debugPrint('👤 [FCM Profile] Raw data received');
      }

      final userId = data['userId'] as String?;

      if (userId == null) {
        if (kDebugMode) {
          debugPrint('👤 [FCM Profile] Invalid - no userId');
        }
        return;
      }

      String? name;
      String? rawChatPictureUrl;
      String? profilePicVersion;
      String? chatPictureVersion;
      String? status;
      String? emoji;
      String? emojiCaption;
      try {
        final updatedFieldsRaw = data['updatedFields'];
        if (updatedFieldsRaw is String && updatedFieldsRaw.trim().isNotEmpty) {
          final decoded = jsonDecode(updatedFieldsRaw);
          if (decoded is Map) {
            final m = Map<String, dynamic>.from(decoded);
            for (final entry in m.entries) {
              data.putIfAbsent(entry.key, () => entry.value);
            }
          }
        } else if (updatedFieldsRaw is Map) {
          final m = Map<String, dynamic>.from(updatedFieldsRaw);
          for (final entry in m.entries) {
            data.putIfAbsent(entry.key, () => entry.value);
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('👤 [FCM Profile] updatedFields parse error: $e');
        }
      }

      String applyVersionToUrl(String url, String? version) {
        final v = version?.trim();
        if (v == null || v.isEmpty) return url;
        final hasV = RegExp(r'([?&])v=').hasMatch(url);
        if (hasV) return url;
        final sep = url.contains('?') ? '&' : '?';
        return '$url${sep}v=$v';
      }

      Map<String, dynamic>? castMap(dynamic value) {
        if (value == null) return null;
        if (value is Map<String, dynamic>) return value;
        if (value is Map) return Map<String, dynamic>.from(value);
        return null;
      }

      String? buildNameFromUserMap(Map<String, dynamic> userMap) {
        final first = (userMap['firstName'] ?? userMap['first_name'])
            ?.toString()
            .trim();
        final last = (userMap['lastName'] ?? userMap['last_name'])
            ?.toString()
            .trim();
        final fullName = '${first ?? ''} ${last ?? ''}'.trim();
        if (fullName.isNotEmpty) return fullName;
        return (userMap['name'] ??
                userMap['fullName'] ??
                userMap['displayName'])
            ?.toString();
      }

      String? extractStatus(dynamic raw) {
        if (raw == null) return null;
        final m = castMap(raw);
        if (m != null) {
          return (m['share_your_voice'] ??
                  m['shareyourvoice'] ??
                  m['status'] ??
                  m['statusContent'] ??
                  m['content'] ??
                  m['text'])
              ?.toString();
        }
        return raw.toString();
      }

      void extractEmojiFromMap(Map<String, dynamic> m) {
        final extractedEmoji =
            (m['emojis_update'] ??
                    m['emoji_updates'] ??
                    m['emojis_updates'] ??
                    m['emoji_update'] ??
                    m['emoji'] ??
                    m['emojisUpdate'])
                ?.toString();
        if (extractedEmoji != null && extractedEmoji.trim().isNotEmpty) {
          emoji = extractedEmoji;
        }
        final extractedCaption =
            (m['emojis_caption'] ??
                    m['emoji_captions'] ??
                    m['emojis_captions'] ??
                    m['emoji_caption'] ??
                    m['emojiCaption'] ??
                    m['caption'] ??
                    m['emojisCaption'])
                ?.toString();
        if (extractedCaption != null && extractedCaption.trim().isNotEmpty) {
          emojiCaption = extractedCaption;
        }
      }

      // Extract from direct fields
      name = data['name'] as String?;
      rawChatPictureUrl = data.containsKey('chat_picture')
          ? (data['chat_picture'] ?? '').toString()
          : (data['profile_pic'] ??
                    data['profilePicUrl'] ??
                    data['profile_pic_url'])
                ?.toString();
      profilePicVersion =
          data['chat_picture_version']?.toString() ??
          data['chatPictureVersion']?.toString() ??
          data['profilePicVersion']?.toString() ??
          data['profile_pic_version']?.toString();
      chatPictureVersion =
          data['chat_picture_version']?.toString() ??
          data['chatPictureVersion']?.toString() ??
          profilePicVersion;
      status = extractStatus(
        data.containsKey('share_your_voice')
            ? data['share_your_voice']
            : (data.containsKey('shareyourvoice')
                  ? data['shareyourvoice']
                  : (data['statusUrl'] ??
                        data['status'] ??
                        data['statusContent'])),
      );

      // Extract emoji fields
      emoji = _extractEmojiField(data);
      emojiCaption = _extractEmojiCaptionField(data);

      final rawEmojiUpdate =
          data['emoji_update'] ??
          data['emojiUpdate'] ??
          data['recentEmojiUpdate'] ??
          data['recent_emoji_update'];
      try {
        final emojiMap = castMap(rawEmojiUpdate);
        if (emojiMap != null) {
          extractEmojiFromMap(emojiMap);
        } else if (rawEmojiUpdate is String &&
            rawEmojiUpdate.trim().isNotEmpty) {
          final decoded = jsonDecode(rawEmojiUpdate);
          if (decoded is Map) {
            extractEmojiFromMap(Map<String, dynamic>.from(decoded));
          }
        }
      } catch (_) {}

      // Process updatedData if present
      final updatedDataJson = data['updatedData'];
      if (updatedDataJson != null) {
        try {
          Map<String, dynamic> parsedData;

          if (updatedDataJson is String) {
            parsedData = Map<String, dynamic>.from(
              jsonDecode(updatedDataJson) as Map,
            );
          } else if (updatedDataJson is Map) {
            parsedData = Map<String, dynamic>.from(updatedDataJson);
          } else {
            parsedData = {};
          }

          final userMap = castMap(parsedData['user']);
          if (userMap != null) {
            name ??= buildNameFromUserMap(userMap);
            rawChatPictureUrl ??= userMap.containsKey('chat_picture')
                ? (userMap['chat_picture'] ?? '').toString()
                : (userMap['profile_pic'] ??
                          userMap['profilePicUrl'] ??
                          userMap['profilePic'] ??
                          userMap['profile_pic_url'])
                      ?.toString();
            profilePicVersion ??=
                userMap['chat_picture_version']?.toString() ??
                userMap['chatPictureVersion']?.toString() ??
                userMap['profilePicVersion']?.toString() ??
                userMap['profile_pic_version']?.toString();
            chatPictureVersion ??=
                userMap['chat_picture_version']?.toString() ??
                userMap['chatPictureVersion']?.toString() ??
                profilePicVersion;
          }

          final voiceMap = castMap(parsedData['share_your_voice']);
          if (voiceMap != null) {
            status ??= extractStatus(voiceMap['share_your_voice'] ?? voiceMap);
          }

          final emojiMap =
              castMap(parsedData['emoji_update']) ??
              castMap(parsedData['emojiUpdate']) ??
              castMap(parsedData['recentEmojiUpdate']) ??
              castMap(parsedData['recent_emoji_update']);
          if (emojiMap != null) {
            extractEmojiFromMap(emojiMap);
          }

          name ??=
              parsedData['name'] as String? ??
              parsedData['fullName'] as String?;
          rawChatPictureUrl ??= parsedData.containsKey('chat_picture')
              ? (parsedData['chat_picture'] ?? '').toString()
              : (parsedData['profile_pic'] ??
                        parsedData['profilePicUrl'] ??
                        parsedData['profile_pic_url'])
                    ?.toString();
          status ??= parsedData.containsKey('share_your_voice')
              ? extractStatus(parsedData['share_your_voice'])
              : (parsedData.containsKey('shareyourvoice')
                    ? (parsedData['shareyourvoice'] ?? '').toString()
                    : (parsedData['statusUrl'] ??
                              parsedData['status'] ??
                              parsedData['statusContent'] ??
                              parsedData['status_content'])
                          ?.toString());

          emoji ??= _extractEmojiField(parsedData);
          emojiCaption ??= _extractEmojiCaptionField(parsedData);
        } catch (e) {
          if (kDebugMode) {
            debugPrint('👤 [FCM Profile] updatedData parse error: $e');
          }
        }
      }

      if (kDebugMode) {
        debugPrint(
          '👤 [FCM Profile] Extracted - name: $name, pic: ${rawChatPictureUrl != null}, status: ${status != null}',
        );
      }

      final normalizedPicUrl =
          (rawChatPictureUrl != null && rawChatPictureUrl.isNotEmpty)
          ? applyVersionToUrl(rawChatPictureUrl, profilePicVersion)
          : rawChatPictureUrl;

      final update = UserProfileBroadcastEvent(
        userId: userId,
        name: name,
        chatPictureUrl: normalizedPicUrl,
        chatPictureVersion: chatPictureVersion,
        status: status,
        emoji: emoji,
        emojiCaption: emojiCaption,
      );

      if (update.hasUpdates) {
        if (kDebugMode) {
          debugPrint('👤 [FCM Profile] Processing update for $userId');
        }
        final picUrl = update.chatPictureUrl;
        if (picUrl != null || update.chatPictureVersion != null) {
          _fireAndForget(
            ProfilePictureCacheManager.instance.invalidateCacheForUser(userId),
          );
        }
        handleProfileUpdateInternal(update);
      } else {
        if (kDebugMode) {
          debugPrint('👤 [FCM Profile] No updates to process');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [FCM Profile] Error: $e');
      }
    }
  }

  String? _extractEmojiField(Map<String, dynamic> data) {
    if (data.containsKey('emojis_update')) {
      return (data['emojis_update'] ?? '').toString();
    }
    if (data.containsKey('emoji_updates')) {
      return (data['emoji_updates'] ?? '').toString();
    }
    if (data.containsKey('emojis_updates')) {
      return (data['emojis_updates'] ?? '').toString();
    }
    if (data.containsKey('emoji')) {
      return (data['emoji'] ?? '').toString();
    }
    if (data.containsKey('emojisUpdate')) {
      return (data['emojisUpdate'] ?? '').toString();
    }
    return null;
  }

  String? _extractEmojiCaptionField(Map<String, dynamic> data) {
    if (data.containsKey('emojis_caption')) {
      return (data['emojis_caption'] ?? '').toString();
    }
    if (data.containsKey('emoji_captions')) {
      return (data['emoji_captions'] ?? '').toString();
    }
    if (data.containsKey('emojis_captions')) {
      return (data['emojis_captions'] ?? '').toString();
    }
    if (data.containsKey('emoji_caption')) {
      return (data['emoji_caption'] ?? '').toString();
    }
    if (data.containsKey('emojiCaption')) {
      return (data['emojiCaption'] ?? '').toString();
    }
    if (data.containsKey('caption')) {
      return (data['caption'] ?? '').toString();
    }
    if (data.containsKey('emojisCaption')) {
      return (data['emojisCaption'] ?? '').toString();
    }
    return null;
  }

  /// Notify UI that a contact has joined the app
  void notifyContactJoined({
    required String userId,
    required String mobileNo,
    String? name,
    String? chatPictureUrl,
  }) {
    try {
      if (kDebugMode) {
        debugPrint('👥 Notifying UI about contact joined: $mobileNo');
      }

      final update = UserProfileBroadcastEvent(
        userId: userId,
        name: name,
        chatPictureUrl: chatPictureUrl,
        status: null,
      );

      _emitUpdate(update);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error notifying contact joined: $e');
      }
    }
  }

  void _fireAndForget(Future<void> future) {
    // ignore: unawaited_futures
    future.catchError((_) {});
  }
}
