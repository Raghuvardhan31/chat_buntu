# ChatEngine Migration Plan

This document outlines the planned refactoring of `UnifiedChatService` into the modular `ChatEngine` structure.

## Current Status: PHASE 3 - FULLY COMPLETED ✅

**Completed:**
- ✅ Renamed `UnifiedChatService` class → `ChatEngineService`
- ✅ Renamed `unified_chat_service.dart` file → `chat_engine/chat_engine_service.dart`
- ✅ Moved all mixins to the new `chat_engine/` folder structure
- ✅ Updated all 17 files with new import paths
- ✅ Replaced all `UnifiedChatService` references with `ChatEngineService`
- ✅ Deleted old `unified_chat_service.dart` file

**New Import:**
```dart
import 'package:chataway_plus/features/chat/data/services/chat_engine/index.dart';
// Use: ChatEngineService.instance
```

---

## Target Folder Structure

```
lib/features/chat/data/services/chat_engine/
├─ chat_engine_service.dart            // Main public class
├─ core/
│  └─ chat_engine_core.dart            // ChatEngineCoreMixin
├─ sync/
│  └─ chat_engine_sync.dart            // ChatEngineSyncMixin
├─ streams/
│  └─ chat_engine_streams.dart         // ChatEngineStreamsMixin
├─ processors/
│  ├─ chat_engine_fcm_processor.dart   // ChatEngineFcmProcessorMixin
│  └─ chat_engine_socket_processor.dart // ChatEngineSocketProcessorMixin
├─ queues/
│  ├─ chat_engine_pending_queue.dart   // ChatEnginePendingQueueMixin
│  └─ chat_engine_unread_override.dart // ChatEngineUnreadOverrideMixin
├─ integration/
│  └─ chat_engine_socket_integration.dart // ChatEngineSocketIntegrationMixin
├─ monitoring/
│  ├─ chat_engine_connectivity_monitor.dart // ChatEngineConnectivityMonitorMixin
│  └─ chat_engine_sync_timer.dart      // ChatEngineSyncTimerMixin
└─ utils/
   └─ chat_engine_utils.dart           // Shared helpers
```

---

## Method Mapping: Old → New

### chat_engine_core.dart (ChatEngineCoreMixin)
From `unified_chat_service.dart` main class:
- `init()`
- `dispose()`
- `setCurrentUser()`
- `joinChat()`
- `leaveChat()`
- `sendMessage()`
- `sendMessageSilently()`
- `editMessage()`
- `deleteMessage()`
- `starMessage()`
- `unstarMessage()`
- `addReaction()`
- `markChatMessagesAsRead()`
- `getConversation()`
- `clearEventCallbacks()`
- `onMessagesUpdated()`
- `onNewMessage()`
- `onConnectionChanged()`
- `onUserStatusChanged()`
- State: `_currentUserId`, `_activeConversationUserId`, `_isOnline`, `_isInitialized`

### chat_engine_sync.dart (ChatEngineSyncMixin)
From `unified_chat_service.dart`:
- `_syncPendingMessages()`
- `_syncConversationWithServer()`
- `_syncAllPendingIncomingMessages()`
- `syncUnreadCountAndContacts()`
- `_loadConversationFromLocal()`
- State: `_pendingMessages`, `_lastSyncTimestamps`

### chat_engine_streams.dart (ChatEngineStreamsMixin)
From `chat_service/streams/unified_streams.dart`:
- `_globalNewMessageController` / `globalNewMessageStream`
- `_userStatusStreamController` / `userStatusStream`
- `_messageSentStreamController` / `messageSentStream`
- `_typingStreamController` / `typingStream`
- `_connectionStreamController` / `connectionStream`
- `_profileUpdateController` / `profileUpdateStream`
- `_messageStatusController` / `messageStatusStream`
- `_messageDeletedStreamController` / `messageDeletedStream`
- `_disposeStreams()`

### chat_engine_fcm_processor.dart (ChatEngineFcmProcessorMixin)
From `chat_service/processors/fcm_message_processor.dart`:
- `_saveFCMMessageInternal()`
- `saveFCMMessage()` (public wrapper)

### chat_engine_socket_processor.dart (ChatEngineSocketProcessorMixin)
From `chat_service/processors/websocket_message_processor.dart`:
- `_handleIncomingMessageInternal()`
- `_handleIncomingMessage()` (public wrapper)

### chat_engine_pending_queue.dart (ChatEnginePendingQueueMixin)
From `chat_service/queue/pending_status_queue.dart`:
- `_enqueuePendingReadIds()`
- `_enqueuePendingDeliveredIds()`
- `_getPendingReadIds()`
- `_getPendingDeliveredIds()`
- `_removePendingReadIds()`
- `_removePendingDeliveredIds()`
- `_flushPendingReadIds()`
- `_flushPendingDeliveredIds()`
- State: `_pendingReadFlushInProgress`, `_pendingDeliveredFlushInProgress`

### chat_engine_unread_override.dart (ChatEngineUnreadOverrideMixin)
From `chat_service/queue/unread_override_manager.dart`:
- `_addClearedUnreadOverride()`
- `_removeClearedUnreadOverride()`

### chat_engine_socket_integration.dart (ChatEngineSocketIntegrationMixin)
From `chat_service/integration/socket_integration.dart`:
- `_setupWebSocketListeners()` / `_setupWebSocketListenersImpl()`
- `_setupAppLifecycleListeners()` / `_setupAppLifecycleListenersImpl()`
- `_handleAppResume()` / `_handleAppResumeImpl()`
- `_handleAppPause()` / `_handleAppPauseImpl()`
- All WebSocket event handlers
- State: `_typingSubscription`, `_messageDeletedSubscription`

### chat_engine_connectivity_monitor.dart (ChatEngineConnectivityMonitorMixin)
From `chat_service/monitoring/connectivity_monitoring.dart`:
- `_setupConnectivityMonitoring()` / `_setupConnectivityMonitoringImpl()`
- `_onConnectivityChanged()` / `_onConnectivityChangedImpl()`
- State: `_connectivitySubscription`

### chat_engine_sync_timer.dart (ChatEngineSyncTimerMixin)
From `chat_service/monitoring/periodic_sync_timer.dart`:
- `_startPeriodicSync()` / `_startPeriodicSyncImpl()`
- State: `_syncTimer`

### chat_engine_utils.dart
From `unified_chat_service.dart`:
- `unawaited()` helper function
- `ChatMessageStatusUpdate` class
- SharedPreferences keys constants

---

## Migration Phases

### Phase 1: Compatibility Layer ✅ (Current)
- Create `chat_engine/index.dart` with typedef
- `ChatEngineService = UnifiedChatService`
- All existing code works unchanged

### Phase 2: Create New Part Files
- Create skeleton files in new folder structure
- Add `part of` directives pointing to new main file
- Move mixin code from old files to new files

### Phase 3: Update Main Service
- Create `chat_engine_service.dart` as new main file
- Update all `part` directives
- Rename mixins with `ChatEngine` prefix

### Phase 4: Update Imports
- Search/replace imports across codebase
- Update from `unified_chat_service.dart` to `chat_engine/index.dart`

### Phase 5: Cleanup
- Remove old `chat_service/` folder
- Remove typedef, make `ChatEngineService` the real class
- Delete `unified_chat_service.dart`

---

## Usage (Current)

```dart
// Old way (still works)
import 'package:chataway_plus/features/chat/data/services/unified_chat_service.dart';
UnifiedChatService.instance.sendMessage(...);

// New way (preferred for new code)
import 'package:chataway_plus/features/chat/data/services/chat_engine/index.dart';
ChatEngineService.instance.sendMessage(...);
```

Both are identical - `ChatEngineService` is just an alias for `UnifiedChatService`.
