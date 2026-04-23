# Chat API Repository Index

Quick reference guide to locate chat-related APIs in the codebase.

## 📋 API Location Map

| API Name | HTTP Method | Endpoint | Repository File | Method |
|----------|-------------|----------|-----------------|--------|
| **Chat Contacts** | GET | `/api/mobile/chat/contacts` | `get_chat_contacts_repository.dart` | `getChatContacts()` |
| **Unread Count** | GET | `/api/mobile/chat/unread-count` | `get_chat_contacts_repository.dart` | `getUnreadCount()` |
| **Chat History** | GET | `/api/mobile/chat/history/{userId}` | `get_chat_history_repository.dart` | `getChatHistory()` |
| **Chat Sync** | POST | `/api/mobile/chat/messages/sync` | `get_chat_history_repository.dart` | `getChatHistory()` *(smart routing)* |
| **Search Messages** | GET | `/api/mobile/chat/search` | `get_chat_history_repository.dart` | `searchMessages()` |

## 🔄 Data Flow Summary

### Chat Contacts Flow
```
UI (ChatListNotifier) → GetChatContactsRepository → ChatRemoteDataSource → HTTP API
                     ↓
                Local DB (saveChatContacts) ← ChatLocalDataSource
```

### Chat History Flow  
```
UI (UnifiedChatService) → GetChatHistoryRepository → ChatRemoteDataSource → HTTP API
                       ↓
                Local DB (saveMessages) ← ChatLocalDataSource
```

### Chat Sync Flow (Incremental)
```
UI (UnifiedChatService) → GetChatHistoryRepository → ChatRemoteDataSource → HTTP API
                       ↓                            (syncMessages)
                Local DB (saveMessages) ← ChatLocalDataSource
```

## 🎯 Quick Navigation

- **Need to modify contacts API?** → `get_chat_contacts_repository.dart`
- **Need to modify chat history/sync?** → `get_chat_history_repository.dart`  
- **Need to modify HTTP calls?** → `chat_remote_datasource.dart`
- **Need to modify local DB?** → `chat_local_datasource.dart`
- **Need to modify UI logic?** → `chat_list_notifier.dart` or `unified_chat_service.dart`

## 🔍 Debug Logs

All repositories now have verbose logging enabled:
- `🌐 [REMOTE]` - HTTP API calls
- `💾 [LOCAL]` - Local database operations  
- `⚡ [CACHE]` - Memory cache operations
- `🔄 [SYNC]` - Sync operations

## 📝 Notes

- `chat_sync_repository.dart` exists but is **documentation only** - actual sync logic is in `get_chat_history_repository.dart`
- All APIs store data to local SQLite for offline support
- All APIs update UI via state notifiers or callbacks
- Sync API uses `ChatSyncMetadataTable` to track last sync timestamps
