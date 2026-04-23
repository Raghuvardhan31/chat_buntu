# ChatAwayPlus - Unused / Orphan Files

> These files exist in the project but are **NOT imported or used** by any other code.
> They are safe to delete or can be implemented in the future if needed.

---

## 1. Empty Placeholder Files (0 bytes — No Code Inside)

These files were created as placeholders but never implemented. They have no code inside.

| File Path | Status |
|-----------|--------|
| `lib/core/realtime/services/realtime_broadcast_hub.dart` | Empty, never imported |
| `lib/core/realtime/services/user_location_broadcast_service.dart` | Empty, never imported |
| `lib/core/realtime/services/user_status_broadcast_service.dart` | Empty, never imported |
| `lib/core/realtime/services/user_stories_broadcast_service.dart` | Empty, never imported |
| `lib/core/realtime/models/user_location_broadcast_event.dart` | Empty, never imported |
| `lib/core/realtime/models/user_status_broadcast_event.dart` | Empty, never imported |
| `lib/core/realtime/models/user_stories_broadcast_event.dart` | Empty, never imported |
| `lib/core/realtime/mixins/user_location_broadcast_mixin.dart` | Empty, never imported |
| `lib/core/realtime/mixins/user_status_broadcast_mixin.dart` | Empty, never imported |
| `lib/core/realtime/mixins/user_stories_broadcast_mixin.dart` | Empty, never imported |

**Note:** Only the **profile** versions of these files are actually used in the app:
- `user_profile_broadcast_service.dart` — Used
- `user_profile_broadcast_event.dart` — Used
- `user_profile_broadcast_mixin.dart` — Used

The location, status, and stories broadcast files were planned but never implemented.

---

## 2. Code Files That Exist But Are Never Imported

These files have code inside but no other file in the project imports or uses them.

| File Path | What It Contains |
|-----------|-----------------|
| `lib/core/notifications/helpers/battery_optimization_helper.dart` | Battery optimization disable guide for notifications. Never used. |
| `lib/core/services/background/foreground_service_helper.dart` | Android foreground service helper. Never imported by any file. |
| `lib/features/follow_up/data/follow_up_store.dart` | Follow-up reminder local storage. Never imported. |
| `lib/features/contacts/data/models/contact_loading_progress.dart` | Contact sync progress model. Never imported. |

---

## 3. Debug / Test Pages (Development Only)

These pages were created for development testing. They are never imported or shown in the app.

| File Path | What It Is |
|-----------|-----------|
| `lib/features/chat/data/socket/providers/socket_debug_page.dart` | Debug page to view socket connection state and test events. |
| `lib/features/voice_call/presentation/pages/agora_test_page.dart` | Test page for debugging Agora voice/video call connection. |

---

## 4. Documentation Files (MD Files — Not Code)

These are markdown documentation files. They don't affect the app but are not linked to any code.

| File Path | What It Contains |
|-----------|-----------------|
| `lib/features/chat/data/services/chat_engine/MIGRATION.md` | Migration notes for chat engine refactoring. |
| `lib/features/chat/presentation/widgets/message_interactions/COMPLETE_FLOW.md` | Documentation of message interaction flow. |
| `lib/features/chat/data/repositories/helper_repos/chat_api_index.md` | Index of chat API endpoints. |
| `lib/features/connection_insight_hub/data/README.md` | Readme for connection insight hub data layer. |

---

## Summary

| Category | Count | Action |
|----------|-------|--------|
| Empty placeholder files | 10 | Safe to delete |
| Unused code files | 4 | Safe to delete |
| Debug/test pages | 2 | Delete before production or keep for development |
| Documentation MD files | 4 | Keep for reference or delete if not needed |
| **Total** | **20** | |
