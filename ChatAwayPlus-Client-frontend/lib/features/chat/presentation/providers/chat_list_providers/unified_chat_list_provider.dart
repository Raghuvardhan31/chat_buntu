import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chataway_plus/features/chat/models/chat_message_model.dart';
import 'package:chataway_plus/features/group_chat/models/group_models.dart';
import 'package:chataway_plus/features/group_chat/presentation/providers/group_providers.dart';
import 'chat_list_stream.dart';

class UnifiedChatItem {
  final ChatContactModel? contact;
  final GroupModel? group;

  UnifiedChatItem({this.contact, this.group});

  DateTime get lastActivityTime {
    if (group != null) {
      return group!.lastMessage?.createdAt ?? group!.createdAt;
    }
    if (contact != null) {
      final last = contact!.lastMessage;
      final msgTime = last == null
          ? DateTime(1970)
          : (last.messageType == MessageType.deleted
                ? last.updatedAt
                : last.createdAt);
      final activity = contact!.lastActivity;
      if (activity == null) return msgTime;

      final normalizedType = (activity.type ?? '')
          .toLowerCase()
          .trim()
          .replaceAll('-', '_');

      if (normalizedType == 'message_deleted' &&
          activity.timestamp.isAfter(msgTime)) {
        return activity.timestamp;
      }
      return msgTime;
    }
    return DateTime(1970);
  }

  bool get isGroup => group != null;
  String get id => isGroup ? group!.id : contact!.user.id;
  String get name => isGroup ? group!.name : contact!.user.fullName;
}

final unifiedChatListProvider = StreamProvider<List<UnifiedChatItem>>((ref) async* {
  final groupAsync = ref.watch(myGroupsProvider);
  
  // We want to re-emit whenever ChatListStream changes OR myGroupsProvider changes
  await for (final contacts in ChatListStream.instance.stream) {
    final groups = groupAsync.valueOrNull ?? [];
    
    final List<UnifiedChatItem> unified = [];
    unified.addAll(contacts.map((c) => UnifiedChatItem(contact: c)));
    unified.addAll(groups.map((g) => UnifiedChatItem(group: g)));
    
    // Sort by last activity time
    unified.sort((a, b) => b.lastActivityTime.compareTo(a.lastActivityTime));
    
    yield unified;
  }
});
