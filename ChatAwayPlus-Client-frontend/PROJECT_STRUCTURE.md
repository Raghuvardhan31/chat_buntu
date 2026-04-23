# ChatAwayPlus - Complete Project Structure Guide

> This document explains every folder and important file so new developers can understand the codebase quickly.

---

## Tech Stack

- **Framework:** Flutter (Dart)
- **State Management:** Riverpod (StateNotifier + Provider pattern)
- **Real-time:** Socket.IO (WebSocket)
- **Push Notifications:** Firebase Cloud Messaging (FCM)
- **Local Database:** Drift (SQLite)
- **Secure Storage:** FlutterSecureStorage (for tokens)
- **Voice/Video Calls:** Agora SDK
- **Backend:** Node.js + AWS S3

---

## How Riverpod State Management Works

Every feature follows this pattern:

- **State** (`*_state.dart`) — Dart class holding data: list of items, isLoading, error message.
- **Notifier** (`*_notifier.dart`) — Extends `StateNotifier<State>`. Contains all logic (fetch, update, delete). Changes state → UI auto-rebuilds.
- **Provider** (`*_providers.dart`) — Riverpod provider exposing the Notifier. UI uses `ref.watch(provider)` to listen and `ref.read(provider.notifier)` to call methods.

**Flow:** Widget → watches Provider → Provider creates Notifier → Notifier updates State → UI rebuilds.

---

## How Socket (Real-time) Works

- Server sends event → `websocket_chat_repository.dart` receives → Event handler parses → Stream broadcasts → Provider listens → UI updates.
- User action → Notifier calls method → Emitter sends socket event → Server receives.
- **Event handlers** (`events/`) — Parse incoming socket data.
- **Emitters** (`emitters/`) — Send data to server.
- **Socket models** (`socket_models/`) — Data classes for payloads.

---

## How Local Database Works

Drift (SQLite) for offline-first storage.

- **Tables** (`core/database/tables/`) — DB table schema.
- **Local datasources** (`*_local_datasource.dart`) — CRUD on tables.
- **Remote datasources** (`*_remote_datasource.dart`) — REST API calls.
- **Repositories** (`*_repository.dart`) — Combine local + remote. Decide server vs local DB.

**Flow:** UI → Notifier → Repository → (Local + Remote Datasource) → DB / API.

---

# CORE FOLDER (`lib/core/`)

Shared infrastructure used by ALL features.

---

## core/config/
| File | Purpose |
|------|---------|
| `app_config.dart` | Base URLs, API keys, Agora App ID, server endpoints. **Check first when setting up.** |
| `environment.dart` | Dev/staging/production environment switching. |

## core/database/
| File | Purpose |
|------|---------|
| `app_database.dart` | Main Drift database class. All tables and DAOs defined here. |
| `migrations/` | Schema migration scripts for DB upgrades. |

### core/database/tables/cache/
| File | Purpose |
|------|---------|
| `app_startup_snapshot_table.dart` | Caches chat list snapshot for instant loading on app open. |
| `profile_picture_cache_table.dart` | Caches profile picture URLs and local paths. |

### core/database/tables/chat/
| File | Purpose |
|------|---------|
| `messages_table.dart` | Main messages table — all message types stored here. |
| `chat_users_table.dart` | Chat conversation metadata (last message, unread count). |
| `chat_sync_metadata_table.dart` | Tracks message sync status with server. |
| `message_reactions_table.dart` | Emoji reactions on messages. |
| `chat_picture_likes_table.dart` | Profile picture likes data. |
| `contacts_stories_table.dart` | Cached contacts' stories. |
| `my_stories_table.dart` | Cached current user's stories. |
| `story_viewers_table.dart` | Who viewed your stories. |
| `status_likes_table.dart` | Story likes. |
| `received_likes_table.dart` | Received profile likes. |
| `follow_ups_table.dart` | Follow-up reminders. |
| `call_history_table.dart` | Call history records. |

### core/database/tables/contacts/
| File | Purpose |
|------|---------|
| `contacts_table.dart` | All synced contacts with phone, name, picture, app user status. |
| `blocked_contacts_table.dart` | Blocked contacts list. |
| `app_users_emoji_table.dart` | Emoji data for contacts. |

### core/database/tables/user/
| File | Purpose |
|------|---------|
| `current_user_table.dart` | Current user's profile data. |
| `mobile_number_table.dart` | User's phone number for auth. |
| `emoji_table.dart` | User's custom emoji data. |
| `draggable_emoji_table.dart` | Draggable emoji preference. |
| `feature_tip_dismissals_table.dart` | Dismissed feature tips. |

## core/storage/
| File | Purpose |
|------|---------|
| `token_storage.dart` | **Critical.** JWT token, refresh token, user ID in FlutterSecureStorage. All auth depends on this. |
| `fcm_token_storage.dart` | Firebase device token management. |
| `user_preferences_storage.dart` | Local user preferences. |

## core/connectivity/
| File | Purpose |
|------|---------|
| `connectivity_service.dart` | Monitors online/offline status. |
| `connectivity_banner.dart` | "No Internet" banner widget. |
| `connectivity_snapshot_refresher.dart` | Auto-refresh when connection restores. |

## core/notifications/
| File | Purpose |
|------|---------|
| `notification_repository.dart` | Central notification coordinator. |
| `firebase/firebase_notification_handler.dart` | **Most important.** Handles FCM in all states (foreground/background/terminated). Saves messages to DB. |
| `firebase/fcm_token_service.dart` | FCM token lifecycle. |
| `firebase/fcm_token_sending.dart` | Sends FCM token to backend. |
| `local/notification_local_service.dart` | Creates local notifications using flutter_local_notifications. |
| `handlers/chat_notification_handler.dart` | Navigate to chat on notification tap. |
| `handlers/system_notification_handler.dart` | Navigate to correct screen on system notification tap. |
| `notifications/` | Display templates for each notification type (message, image, reaction, story, voice). |
| `cache/` | Caches notification data and profile pictures for notifications. |
| `helpers/` | Battery optimization guide and debug utilities. |
| `silent/` | Silent FCM handlers for background profile/story sync. |

## core/realtime/
| File | Purpose |
|------|---------|
| `services/user_profile_broadcast_service.dart` | Broadcasts profile changes to all screens. |
| `services/user_status_broadcast_service.dart` | Broadcasts online/offline changes. |
| `services/user_stories_broadcast_service.dart` | Broadcasts new story updates. |
| `mixins/` | Mixins widgets use to listen to broadcasts. |
| `models/` | Broadcast event data models. |

## core/routes/
| File | Purpose |
|------|---------|
| `app_router.dart` | GoRouter route definitions and navigation guards. |
| `navigation_service.dart` | Programmatic navigation and deep linking. |
| `route_names.dart` | All route path constants. |

## core/constants/api_url/
| File | Purpose |
|------|---------|
| `api_urls.dart` | **All REST API endpoints and socket event names.** Update here when backend changes. |

## core/services/
| File | Purpose |
|------|---------|
| `device_id_service.dart` | Unique device ID generation. |
| `permissions/permission_manager.dart` | Central permission manager (camera, mic, contacts, storage, notifications). |
| `background/foreground_service_helper.dart` | Android foreground service for long tasks. |

## core/app_lifecycle/
| File | Purpose |
|------|---------|
| `app_state_service.dart` | Tracks foreground/background and active chat screen. Used for smart notification suppression. |
| `first_run_cleaner.dart` | Cleans stale data on first launch after reinstall. |

## core/themes/
| File | Purpose |
|------|---------|
| `app_theme.dart` | Light/dark theme definition. |
| `app_dimensions.dart` | Responsive sizing constants. |
| `colors/app_colors.dart` | All color constants. |

## Other core/
| File | Purpose |
|------|---------|
| `app_upgrade/app_upgrade_manager.dart` | Checks for mandatory app updates. |
| `media/media_cache_manager.dart` | Global media file cache. |
| `sync/authenticated_image_cache_manager.dart` | Image cache with JWT auth for private images. |
| `isolates/contact_sync_isolate.dart` | Background isolate for contact sync. |
| `delete_account/user_account_api_service.dart` | Account deletion API. |

---

# FEATURES FOLDER (`lib/features/`)

See **PROJECT_STRUCTURE_FEATURES.md** for detailed feature documentation.
