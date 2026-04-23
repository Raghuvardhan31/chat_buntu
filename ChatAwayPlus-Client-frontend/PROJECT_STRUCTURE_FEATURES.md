# ChatAwayPlus - Features Documentation

> Detailed breakdown of every feature folder, every file, and how they connect.

---

# features/auth/ — Authentication

Handles phone number + OTP login.

## auth/data/datasources/
| File | Purpose |
|------|---------|
| `auth_remote_datasource.dart` | REST API: send OTP, verify OTP, register, login, refresh token. |
| `auth_local_datasource.dart` | Saves auth data locally after successful login. |

## auth/data/models/
| File | Purpose |
|------|---------|
| `requests/auth_request_models.dart` | Request bodies for all auth APIs. |
| `requests/otp_request_model.dart` | OTP request model. |
| `response/auth_response_model.dart` | Parses JWT token, refresh token, user profile from server response. |
| `response/auth_result.dart` | Success/error wrapper. |
| `response/otp_response_model.dart` | OTP response parser. |

## auth/data/repositories/
| File | Purpose |
|------|---------|
| `auth_repository.dart` | Abstract interface for auth operations. |
| `auth_repository_impl.dart` | Implementation — calls remote datasource, saves tokens. |
| `helper_repos/send_otp_repository.dart` | Send OTP to phone number. |
| `helper_repos/verify_otp_repository.dart` | Verify OTP and extract tokens. |
| `helper_repos/resend_otp_repository.dart` | Resend OTP with cooldown. |

## auth/presentation/pages/
| File | Purpose |
|------|---------|
| `phone_number_entry_page.dart` | Phone input screen with country code picker. |
| `otp_verification_page.dart` | OTP input with auto-fill, timer, resend. |

## auth/presentation/widgets/
| File | Purpose |
|------|---------|
| `phone_number_input.dart` | Phone text field with validation. |
| `otp_input_field.dart` | OTP digit input boxes. |
| `get_otp_button.dart` | "Get OTP" button. |

## auth/presentation/providers/mobile_number/ — Riverpod (Phone Screen)
| File | Purpose |
|------|---------|
| `mobile_number_state.dart` | State: phone number, country code, validation error, loading. |
| `mobile_number_notifier.dart` | StateNotifier: validates phone, calls send OTP API. |
| `mobile_number_provider.dart` | Provider exposing notifier to UI. |

## auth/presentation/providers/otp/ — Riverpod (OTP Screen)
| File | Purpose |
|------|---------|
| `otp_state.dart` | State: OTP digits, timer, verification status, error. |
| `otp_notifier.dart` | StateNotifier: verifies OTP, handles resend, manages timer. |
| `otp_provider.dart` | Provider exposing notifier to UI. |

---

# features/chat/ — One-to-One Chat (Core Feature)

The biggest feature. Handles messaging, media, reactions, typing, status.

## chat/data/socket/ — WebSocket Layer

### chat/data/socket/core/
| File | Purpose |
|------|---------|
| `socket_connection_manager.dart` | **Core.** Socket.IO connect, disconnect, reconnect with backoff, auth refresh, state tracking. |
| `socket_auth_manager.dart` | Sends JWT to socket server on connect. |

### chat/data/socket/websocket_repository/
| File | Purpose |
|------|---------|
| `websocket_chat_repository.dart` | **THE most important file (85K lines).** Central hub for ALL socket events. Every real-time feature flows through this. |

### chat/data/socket/events/ — Incoming Event Handlers
| File | Purpose |
|------|---------|
| `message_events_handler.dart` | Parses incoming messages. |
| `typing_events_handler.dart` | Parses typing events (userId, isTyping, senderId, receiverId). |
| `status_events_handler.dart` | Parses online/offline/last-seen events. |
| `message_status_events_handler.dart` | Parses sent/delivered/read status updates. |
| `reaction_events_handler.dart` | Parses reaction add/remove events. |
| `delete_events_handler.dart` | Parses message deletion events. |
| `star_message_events_handler.dart` | Parses star/unstar events. |
| `profile_events_handler.dart` | Parses profile update events. |
| `auth_events_handler.dart` | Parses socket auth success/failure. |
| `connection_events_handler.dart` | Parses connect/disconnect events. |
| `notification_events_handler.dart` | Parses notification events. |

### chat/data/socket/emitters/ — Outgoing Event Senders
| File | Purpose |
|------|---------|
| `message_emitter.dart` | Sends messages via socket. |
| `typing_emitter.dart` | Sends typing start/stop. |
| `status_emitter.dart` | Sends online/offline and read receipts. |
| `reaction_emitter.dart` | Sends reaction add/remove. |
| `delete_emitter.dart` | Sends delete request. |
| `star_message_emitter.dart` | Sends star/unstar. |
| `chat_picture_like_emitter.dart` | Sends profile picture like/unlike. |
| `status_like_emitter.dart` | Sends story like. |

### chat/data/socket/socket_models/ — Socket Data Models

**messages/**
| File | Purpose |
|------|---------|
| `socket_message_response.dart` | Incoming message model. |
| `socket_private_message_request.dart` | Outgoing message model. |
| `message_status.dart` | Enum: sent, delivered, read. |
| `message_status_update.dart` | Status change model. |

**user_status/**
| File | Purpose |
|------|---------|
| `typing_status.dart` | Model: userId, isTyping, senderId, receiverId. |
| `user_status.dart` | Model: userId, isOnline, lastSeen. |

**reactions/**
| File | Purpose |
|------|---------|
| `message_reaction.dart` | Single reaction model. |
| `socket_reaction_updated_response.dart` | Reaction update event model. |

**auth/** — `socket_auth_request.dart` — Socket auth payload.
**user/** — `socket_user_model.dart` — User data from socket.
**profile/** — `profile_update.dart` — Profile change event model.

### chat/data/socket/socket_constants/
| File | Purpose |
|------|---------|
| `socket_event_names.dart` | **All socket event name constants.** Update here when backend changes events. |

### chat/data/socket/providers/
| File | Purpose |
|------|---------|
| `socket_providers.dart` | Riverpod providers for socket connection and repository. |
| `socket_debug_page.dart` | Debug screen for socket testing. |

---

## chat/data/services/chat_engine/ — Message Pipeline

### Main File
| File | Purpose |
|------|---------|
| `chat_engine_service.dart` | **Main orchestrator (41K lines).** Initializes all sub-services, provides top-level API for UI. |

### Sub-services
| File | Purpose |
|------|---------|
| `streams/chat_engine_streams.dart` | Stream controllers for typing, messages, status, connection. UI listens via providers. |
| `send/chat_engine_send.dart` | Message sending: validate, queue, send via socket, retry on failure. |
| `queues/chat_engine_pending_queue.dart` | Offline message queue. Messages queued here, sent when online. |
| `queues/chat_engine_unread_override.dart` | Unread count optimistic updates. |
| `offline/chat_engine_offline.dart` | Saves unsent messages to DB, retries when online. |
| `sync/chat_engine_sync.dart` | Syncs messages between local DB and server. |
| `processors/chat_engine_socket_processor.dart` | Processes incoming socket messages: dedup, validate, save, update UI. |
| `processors/chat_engine_fcm_processor.dart` | Processes FCM messages: extract, save to DB, show notification. |
| `message/chat_engine_message_handlers.dart` | Mark read, delete, edit, star operations. |
| `message/chat_engine_message_ops.dart` | Low-level DB operations. |
| `conversation/chat_engine_conversation.dart` | Conversation management: create, update last message, manage chat list. |
| `integration/chat_engine_socket_integration.dart` | Connects engine to socket events. |
| `callbacks/chat_engine_callbacks.dart` | UI callbacks for engine events. |
| `monitoring/chat_engine_connectivity_monitor.dart` | Triggers sync on connection restore. |
| `monitoring/chat_engine_sync_timer.dart` | Periodic background sync timer. |

---

## chat/data/services/local/ — Local DB Services
| File | Purpose |
|------|---------|
| `messages_local_db.dart` | **Main message DB (48K).** All CRUD for all message types. |
| `message_reactions_local_db.dart` | Reactions CRUD. |
| `chat_picture_likes_local_db.dart` | Profile likes CRUD. |
| `follow_ups_local_db_service.dart` | Follow-ups CRUD. |
| `status_likes_local_db.dart` | Story likes CRUD. |
| `received_likes_local_db.dart` | Received likes CRUD. |

## chat/data/services/business/ — Business Logic
| File | Purpose |
|------|---------|
| `message_reaction_service.dart` | Reaction logic: socket + local DB sync. |
| `chat_picture_likes_service.dart` | Profile like via socket + local DB. |
| `status_likes_service.dart` | Story like logic. |
| `follow_up_message_service.dart` | Follow-up scheduling. |

## chat/data/datasources/
| File | Purpose |
|------|---------|
| `chat_local_datasource.dart` | All local DB queries for chat (41K). |
| `chat_remote_datasource.dart` | All REST API calls for chat (23K). |

## chat/data/repositories/
| File | Purpose |
|------|---------|
| `chat_repository.dart` | Abstract interface. |
| `chat_repository_impl.dart` | Implementation: local + remote, offline-first. |
| `helper_repos/chat_sync_repository.dart` | Message sync with server. |
| `helper_repos/get_chat_contacts_repository.dart` | Fetch chat contacts. |
| `helper_repos/get_chat_history_repository.dart` | Fetch paginated chat history. |

## chat/data/cache/ — In-memory Caches
| File | Purpose |
|------|---------|
| `chat_list_cache.dart` | Caches chat list for instant loading. |
| `opened_chats_cache.dart` | Caches messages for open conversations. |
| `chat_cache_manager.dart` | Cache lifecycle management. |

## chat/data/media/
| File | Purpose |
|------|---------|
| `media_upload_service.dart` | Upload to AWS S3 with progress. |
| `media_cache_service.dart` | Download and cache received media. |

## chat/models/
| File | Purpose |
|------|---------|
| `chat_message_model.dart` | **Main message model (47K).** All message types, status, reactions, media. |

---

## chat/presentation/pages/

### chat_list/
| File | Purpose |
|------|---------|
| `chat_list_page.dart` | **Chat list screen (48K).** All conversations, unread, typing, search. |
| `widgets/chat_list_tile_widget.dart` | Single conversation row. |
| `widgets/chat_list_header_widget.dart` | Header with search. |
| `widgets/chat_list_empty_states.dart` | Empty state UI. |
| `widgets/speed_dial_fab_widget.dart` | FAB with expandable options. |

### onetoone_chat/
| File | Purpose |
|------|---------|
| `one_to_one_chat_page.dart` | **Chat screen (72K).** Messages, input, send, reply, reactions. |
| `mixins/chat_event_handlers_mixin.dart` | Event handler methods. |
| `mixins/media_attachment_mixin.dart` | Media attachment logic (camera, gallery, file, audio, location). |
| `widgets/chat_message_list.dart` | Scrollable message list with pagination. |
| `widgets/message_bubble_builder.dart` | Routes to correct bubble widget by message type. |
| `widgets/blocked_inline_banner.dart` | Blocked contact banner. |

### Other pages
| File | Purpose |
|------|---------|
| `contact_picker/contact_picker_page.dart` | Select contact for new chat. |
| `forward_message/forward_message_page.dart` | Forward message to contacts. |
| `media_viewer/chat_image_viewer_page.dart` | Full-screen image viewer. |
| `media_viewer/chat_video_viewer_page.dart` | Full-screen video player. |
| `media_viewer/chat_pdf_viewer_page.dart` | PDF viewer. |
| `media_viewer/app_user_chat_picture_view.dart` | Profile picture viewer with like. |

---

## chat/presentation/providers/

### chat_list_providers/ — Riverpod (Chat List)
| File | Purpose |
|------|---------|
| `chat_list_state.dart` | State: chat items, loading, error. |
| `chat_list_notifier.dart` | StateNotifier: fetch, search, delete, pin chats. |
| `chat_list_provider.dart` | Provider exposing notifier. |
| `chat_list_stream.dart` | Stream provider for real-time chat list updates. |

### chat_page_providers/ — Riverpod (Individual Chat)
| File | Purpose |
|------|---------|
| `chat_page_state.dart` | State: messages, loading, hasMore, error. |
| `chat_page_notifier.dart` | **Main chat notifier (47K).** Load, send, receive, delete, edit, react, paginate. |
| `chat_page_provider.dart` | Provider for specific conversation. |
| `typing_indicator_provider.dart` | Tracks typing per user via socket stream. Shows "Typing..." in UI. |
| `user_status_provider.dart` | User online/offline/last-seen. |
| `message_status_stream_provider.dart` | Real-time message status stream. |
| `notification_stream_provider.dart` | Notification events for current chat. |

### cache_providers/
| File | Purpose |
|------|---------|
| `cache_state.dart` | Cache status state. |
| `cache_notifier.dart` | Cache load/refresh/invalidate. |
| `cache_providers.dart` | Providers. |

### message_reactions/
| File | Purpose |
|------|---------|
| `message_reaction_state.dart` | State: reactions per message. |
| `message_reaction_notifier.dart` | Add/remove/fetch reactions. |
| `message_reaction_providers.dart` | Providers. |

---

## chat/presentation/widgets/

### chat_ui/ — Chat Screen Components
| File | Purpose |
|------|---------|
| `chat_app_bar_widget.dart` | App bar: name, status, picture, call buttons. |
| `chat_background_widget.dart` | Background wallpaper. |
| `chat_date_divider.dart` | Date dividers ("Today", "Yesterday"). |
| `message_delivery_status_icon.dart` | Single tick, double tick, blue tick icons. |
| `message_info_sheet_widget.dart` | Message info: sent/delivered/read times. |
| `jump_to_latest_button.dart` | Scroll-to-bottom button. |
| `blocked_contact_panel.dart` | Blocked contact bottom panel. |

### common/chat_input/ — Input Bar Components
| File | Purpose |
|------|---------|
| `input_pill_widget.dart` | Main text input with attachment/emoji buttons. |
| `attachment_panel_widget.dart` | Attachment options (camera, gallery, file, location). |
| `emoji_picker_section.dart` | Emoji keyboard. |
| `send_button_widget.dart` | Send button. |
| `audio_record_overlay_widget.dart` | Audio recording with waveform. |
| `audio_confirmation_widget.dart` | Audio preview before send. |
| `edit_mode_banner.dart` | Edit message banner. |

### common/
| File | Purpose |
|------|---------|
| `chat_input_field.dart` | Full input bar widget. |
| `chat_profile_quick_actions_sheet.dart` | Quick actions on profile tap. |

### message_bubbles/ — One Widget Per Message Type
| File | Purpose |
|------|---------|
| `text_message_bubble.dart` | Text with links, copy, timestamp. |
| `image_message_bubble_one.dart` | Image with thumbnail, full-screen tap. |
| `video_message_bubble.dart` | Video with thumbnail, play, download. |
| `audio_message_bubble.dart` | Audio with waveform, play/pause. |
| `pdf_message_bubble.dart` | File with name, size, download. |
| `location_message_bubble.dart` | Map preview thumbnail. |
| `poll_message_bubble.dart` | Poll with options and voting. |
| `contact_message_bubble.dart` | Contact share. |
| `emoji_message_bubble.dart` | Large emoji display. |
| `reply_preview_in_bubble.dart` | Original message in reply. |
| `swipe_reply_bubble.dart` | Swipe-to-reply gesture. |
| `follow_up_message_bubble.dart` | Follow-up reminder. |

### message_interactions/ — Action Widgets
| File | Purpose |
|------|---------|
| `message_action_bar.dart` | Long-press: reply, forward, copy, delete, star. |
| `message_reaction_bar.dart` | Emoji reaction picker. |
| `message_reaction_display.dart` | Reaction badges below bubble. |
| `message_selection_overlay.dart` | Multi-select mode. |
| `delete_selection_dialog.dart` | Delete confirmation. |
| `edit_message_dialog.dart` | Edit message. |

### media_preview/ — Preview Before Sending
| File | Purpose |
|------|---------|
| `image_preview_page.dart` | Image preview with crop/edit. |
| `video_preview_page.dart` | Video preview with trim. |
| `pdf_preview_page.dart` | PDF preview. |

## chat/utils/
| File | Purpose |
|------|---------|
| `chat_helper.dart` | Date formatting, message grouping. |
| `chat_image_utils.dart` | Image compression, thumbnails. |

---

# features/chat_stories/ — Stories/Status

WhatsApp-like stories (image, video, text) expiring after 24 hours.

## chat_stories/data/
| File | Purpose |
|------|---------|
| `models/chat_story_models.dart` | Story models: ChatStoryModel, StorySlide, UserStoriesGroup. |
| `repositories/story_repository.dart` | **Main story repo (26K).** Fetch, create, delete, view, like stories via socket. Manages caching. |

### chat_stories/data/services/
| File | Purpose |
|------|---------|
| `business/stories_cache_service.dart` | Story caching for offline access. |
| `local/contacts_stories_local_db.dart` | Contacts' stories CRUD in DB. |
| `local/my_stories_local_db.dart` | My stories CRUD in DB. |
| `local/story_viewers_local_db.dart` | Story viewer data CRUD. |
| `sync/stories_fcm_sync_service.dart` | Background story sync via FCM. |

### chat_stories/data/socket/
| File | Purpose |
|------|---------|
| `story_socket_constants.dart` | Story socket event names. |
| `story_socket_models.dart` | Story socket payload models (15K). |
| `story_emitter.dart` | Sends story events to server. |
| `story_events_handler.dart` | Parses incoming story events. |

## chat_stories/presentation/pages/
| File | Purpose |
|------|---------|
| `chat_stories_page.dart` | **Main stories screen (38K).** My Story + Latest Stories from contacts. |
| `story_viewers/contact_story_viewer_page.dart` | Full-screen viewer for contact stories. |
| `story_viewers/my_story_viewer_page.dart` | Full-screen viewer for your stories with viewer list. |
| `story_management/my_stories_list_page.dart` | Manage your stories list. |

## chat_stories/presentation/providers/ — Riverpod
| File | Purpose |
|------|---------|
| `story_state.dart` | State: stories list, loading, error. |
| `story_notifier.dart` | **Main notifier (35K).** `ContactsStoriesNotifier` + `MyStoriesNotifier`. Fetch, cache, filter, listen to socket. |
| `story_providers.dart` | Providers: `contactsStoriesProvider`, `myStoriesProvider`. |

## chat_stories/presentation/widgets/
| File | Purpose |
|------|---------|
| `chat_story_tile.dart` | Story tile with ring indicator. |
| `my_story_tile.dart` | "My Story" tile with add button. |
| `story_progress_bar.dart` | Segmented progress bar. |
| `story_slide_renderer.dart` | Image story slide renderer. |
| `video_story_slide_renderer.dart` | Video story slide renderer. |
| `story_video_player.dart` | Video player for stories. |
| `video_story_preview_page.dart` | Video preview before posting. |
| `story_viewer_header.dart` | Poster name, time, close button. |
| `story_viewer_bottom_action_bar.dart` | Reply and like bar. |
| `story_navigation_gesture_layer.dart` | Tap/swipe gesture handling. |
| `story_management/story_thumbnail_card.dart` | Story thumbnail with delete. |

## chat_stories/presentation/painters/
| File | Purpose |
|------|---------|
| `story_ring_painter.dart` | Custom painter for colored ring around avatars. |

---

# features/voice_call/ — Audio and Video Calling

Agora SDK for calls, socket for signaling.

## voice_call/data/
| File | Purpose |
|------|---------|
| `config/agora_config.dart` | Agora App ID and settings. |
| `models/call_model.dart` | Call model: id, caller, receiver, type, status, duration. |
| `datasources/call_history_local_datasource.dart` | Call history CRUD in local DB. |

### voice_call/data/services/
| File | Purpose |
|------|---------|
| `agora_call_service.dart` | **Agora SDK wrapper.** Init engine, join/leave channel, audio/video streams. |
| `call_signaling_service.dart` | **Call signaling via socket (25K).** Initiate, ring, answer, reject, busy, timeout, end — all via WebSocket. |
| `call_listener_service.dart` | Listens for incoming call socket events. |

## voice_call/presentation/pages/
| File | Purpose |
|------|---------|
| `outgoing_call_page.dart` | Outgoing: callee info, ringing, cancel. |
| `incoming_call_page.dart` | Incoming: caller info, accept/reject. |
| `active_call_page.dart` | Active audio: timer, mute/speaker/end. |
| `video_call_page.dart` | Active video: local/remote video, camera switch. |
| `call_history_page.dart` | Call history list. |
| `calling_hub_page.dart` | Call hub entry point. |

## voice_call/presentation/providers/
| File | Purpose |
|------|---------|
| `call_provider.dart` | Riverpod StateNotifier: call lifecycle (idle→ringing→active→ended), timer, audio/video toggle. |

## voice_call/presentation/widgets/
| File | Purpose |
|------|---------|
| `call_action_button.dart` | Mute, speaker, video, end buttons. |
| `call_avatar.dart` | Large profile picture on call screen. |
| `call_tile.dart` | Call history list tile. |

---

# features/profile/ — User Profile

## profile/data/datasources/
| File | Purpose |
|------|---------|
| `profile_remote_datasource.dart` | API: get/update profile, upload/delete picture. |
| `profile_local_datasource.dart` | Local DB for profile data. |
| `emoji_remote_datasource.dart` | API: CRUD for custom emoji. |
| `emoji_local_datasource.dart` | Local DB for emoji. |

## profile/data/models/
| File | Purpose |
|------|---------|
| `current_user_profile_model.dart` | Profile: name, phone, picture, status. |
| `emoji_model.dart` | Emoji data model. |
| `requests/` | Request models for profile and emoji APIs. |
| `responses/` | Response parsers for profile and emoji APIs. |

## profile/data/repositories/profile/
| File | Purpose |
|------|---------|
| `profile_repository.dart` | Abstract interface. |
| `profile_repository_impl.dart` | Implementation. |
| `helper_repos/get_profile_repository.dart` | Fetch profile. |
| `helper_repos/update_name_repository.dart` | Update name. |
| `helper_repos/update_status_repository.dart` | Update status text. |
| `helper_repos/update_profile_picture_repository.dart` | Upload picture to S3. |
| `helper_repos/delete_profile_picture_repository.dart` | Delete picture. |

## profile/data/repositories/emoji/
| File | Purpose |
|------|---------|
| `emoji_repository.dart` | Abstract interface. |
| `emoji_repository_impl.dart` | Implementation. |
| `helper_repos/create_emoji_repository.dart` | Create emoji. |
| `helper_repos/update_emoji_repository.dart` | Update emoji. |
| `helper_repos/delete_emoji_repository.dart` | Delete emoji. |
| `helper_repos/get_emoji_repository.dart` | Fetch emojis. |

## profile/presentation/pages/
| File | Purpose |
|------|---------|
| `current_user_profile_page.dart` | **Your profile screen (46K).** Picture, name, status, gallery, emoji, voice. |
| `contact_profile_page.dart` | Contact's profile view. |

## profile/presentation/providers/profile/ — Riverpod
| File | Purpose |
|------|---------|
| `profile_page_state.dart` | State: profile data, loading, error, edit flags. |
| `profile_page_notifier.dart` | StateNotifier: fetch, update name/status/picture. |
| `profile_page_providers.dart` | Providers. |

## profile/presentation/providers/emoji/ — Riverpod
| File | Purpose |
|------|---------|
| `emoji_state.dart` | State: emoji list, selected, loading, error. |
| `emoji_notifier.dart` | StateNotifier: fetch, create, update, delete emoji. |
| `emoji_providers.dart` | Providers. |

## profile/presentation/widgets/
| File | Purpose |
|------|---------|
| `gallery_widget.dart` | Profile picture gallery with upload/delete. |
| `defalut_status_page.dart` | Predefined status selection. |
| `emoji_uploader.dart` | Emoji creation widget. |
| `emoji_caption_bottom_sheet.dart` | Caption for emoji. |
| `current_user_name_widget.dart` | Editable name display. |
| `current_user_chat_picture_viewer.dart` | Picture viewer with like count. |
| `share_your_voice_widget.dart` | Voice recording widget. |

---

# features/contacts/ — Contact Management

## contacts/data/datasources/
| File | Purpose |
|------|---------|
| `device_contacts_service.dart` | Reads contacts from phone. |
| `app_users_check_service.dart` | Checks which contacts are app users (API). |
| `contacts_database_service.dart` | Contacts CRUD in local DB. |
| `contacts_delta_sync_service.dart` | Incremental sync — only changed contacts. |
| `profile_sync_storage.dart` | Tracks last sync time per contact. |

## contacts/data/models/
| File | Purpose |
|------|---------|
| `contact_local.dart` | Contact model: name, phone, picture, isAppUser. |
| `check_contacts_api_models.dart` | API models for checking app users. |
| `contact_loading_progress.dart` | Sync progress model. |

## contacts/data/repositories/
| File | Purpose |
|------|---------|
| `contacts_repository.dart` | **Main repo (21K).** Full sync: phone → server check → save DB → delta sync. |

## contacts/presentation/pages/
| File | Purpose |
|------|---------|
| `contacts_hub_page.dart` | **Contacts screen (39K).** App users, invite, search, pull-to-refresh. |

## contacts/presentation/providers/
| File | Purpose |
|------|---------|
| `contacts_management.dart` | StateNotifier: fetch, search, filter app users. |
| `search_management.dart` | Search state management. |
| `sync_management.dart` | Sync state: trigger, progress, errors. |

## contacts/utils/
| File | Purpose |
|------|---------|
| `contact_display_name_helper.dart` | Get display name (phone name or server name). |

---

# features/Express_hub/ — Express Reactions

Feed of emoji reactions from contacts.

## Express_hub/data/
| File | Purpose |
|------|---------|
| `datasources/emoji_updates_remote_datasource.dart` | API: fetch emoji feed. |
| `datasources/emoji_updates_local_datasource.dart` | Local cache for feed. |
| `models/emoji_update_model.dart` | Emoji update entry model. |
| `repositories/emoji_updates_repository.dart` | Repository for feed. |

## Express_hub/presentation/
| File | Purpose |
|------|---------|
| `pages/express_hub_page.dart` | **Express hub screen (50K).** Emoji updates feed. |

### Riverpod (emoji_updates/)
| File | Purpose |
|------|---------|
| `emoji_updates_state.dart` | State: updates list, loading, error. |
| `emoji_updates_notifier.dart` | StateNotifier: fetch, refresh, paginate. |
| `emoji_updates_providers.dart` | Providers. |

---

# features/connection_insight_hub/ — Connection Insights

## connection_insight_hub/presentation/
| File | Purpose |
|------|---------|
| `pages/connection_insight_hub_page.dart` | **Dashboard (27K).** Profile viewers, follow-ups, blocked, voice. |
| `widgets/blocked_contact_action_tile.dart` | Blocked contact with unblock. |
| `widgets/chat_profile_picture_viewer.dart` | Contact picture viewer. |
| `widgets/follow_ups_section.dart` | Follow-up reminders list. |
| `widgets/share_your_voice_tile.dart` | Voice share tile. |

---

# features/likes_hub/ — Likes Hub

| File | Purpose |
|------|---------|
| `presentation/pages/likes_hub_page.dart` | **Likes page (27K).** Who liked your picture, liked stories, received likes. |

---

# features/poll_hub/ — Polls

| File | Purpose |
|------|---------|
| `presentation/pages/poll_hub_page.dart` | Poll creation, voting, results. |

---

# features/location_sharing/ — Location

## location_sharing/data/
| File | Purpose |
|------|---------|
| `config/maps_config.dart` | Google Maps API key. |
| `models/location_model.dart` | Location: lat, lng, address. |

## location_sharing/presentation/
| File | Purpose |
|------|---------|
| `pages/location_picker_page.dart` | Map with search, current location, pin drop. |
| `widgets/location_message_bubble.dart` | Location bubble with map preview. |

---

# features/blocked_contacts/ — Block/Unblock

## blocked_contacts/data/
| File | Purpose |
|------|---------|
| `datasources/blocked_contacts_remote_datasource.dart` | API: block, unblock, get list. |
| `datasources/blocked_contacts_local_datasource.dart` | Local DB for blocked list. |
| `models/blocked_contacts_models.dart` | Blocked contact model. |
| `repositories/blocked_contacts/blocked_contacts_repository.dart` | Abstract interface. |
| `repositories/blocked_contacts/blocked_contacts_repository_impl.dart` | Implementation. |

## blocked_contacts/presentation/
| File | Purpose |
|------|---------|
| `pages/blocked_contacts_page.dart` | Blocked contacts list with unblock. |

### Riverpod
| File | Purpose |
|------|---------|
| `providers/blocked_contacts/blocked_contacts_state.dart` | State: blocked list, loading, error. |
| `providers/blocked_contacts/blocked_contacts_notifier.dart` | StateNotifier: fetch, block, unblock. |
| `providers/blocked_contacts/blocked_contacts_providers.dart` | Providers. |

---

# features/mood_emoji/ — Mood Emoji

## mood_emoji/data/
| File | Purpose |
|------|---------|
| `datasources/mood_emoji_local_datasource.dart` | Local DB for mood emoji. |
| `models/mood_emoji_model.dart` | Mood emoji model. |

## mood_emoji/presentation/
| File | Purpose |
|------|---------|
| `providers/mood_emoji_provider.dart` | Riverpod provider for mood emoji state. |
| `widgets/mood_emoji_circle.dart` | Animated emoji circle on profile. |

---

# features/draggable_emoji/ — Floating Emoji

## draggable_emoji/data/
| File | Purpose |
|------|---------|
| `datasources/draggable_emoji_local_datasource.dart` | Local DB for preferences. |
| `models/draggable_emoji_model.dart` | Model. |

## draggable_emoji/presentation/
| File | Purpose |
|------|---------|
| `pages/draggable_floating_ball.dart` | Floating draggable emoji overlay. |
| `providers/draggable_emoji_provider.dart` | Riverpod provider. |

---

# features/follow_up/ — Follow-up Reminders

| File | Purpose |
|------|---------|
| `data/follow_up_store.dart` | Local storage for follow-up data. |

---

# features/settings/ — App Settings

| File | Purpose |
|------|---------|
| `presentation/settings_page.dart` | Settings: notifications, privacy, theme, account. |
| `widgets/about_us_page.dart` | About page. |
| `widgets/bug_report_page.dart` | Bug report form. |

### Riverpod
| File | Purpose |
|------|---------|
| `providers/settings_user_state.dart` | State. |
| `providers/settings_user_notifier.dart` | StateNotifier. |
| `providers/settings_user_providers.dart` | Providers. |

---

# features/navigation/ — Bottom Navigation

| File | Purpose |
|------|---------|
| `presentation/pages/main_navigation_page.dart` | Main scaffold with bottom tabs. |
| `presentation/widgets/custom_bottom_nav_bar.dart` | Custom nav bar with badges. |

---

# features/app_gate/ — App Entry

| File | Purpose |
|------|---------|
| `presentation/app_gate_page.dart` | **First screen.** Splash → auth check → login or home. Initializes socket, sync, FCM. |

---

# features/shared/ — Reusable Widgets

| File | Purpose |
|------|---------|
| `widgets/avatars/cached_circle_avatar.dart` | Circular avatar with caching, placeholder, error fallback. Used everywhere. |

---

# features/theme/ — Theme Toggle

Dark/light mode switching.

---

# Quick Reference: Most Important Files

| File | Why |
|------|-----|
| `websocket_chat_repository.dart` | ALL real-time socket events (85K lines) |
| `chat_engine_service.dart` | Message send/receive pipeline (41K lines) |
| `chat_local_datasource.dart` | All local DB queries for chat |
| `chat_remote_datasource.dart` | All REST API calls for chat |
| `firebase_notification_handler.dart` | All push notification handling |
| `app_database.dart` | Database schema |
| `token_storage.dart` | Auth tokens and user ID |
| `api_urls.dart` | All API endpoints and socket event names |
| `socket_connection_manager.dart` | Socket connect/reconnect logic |
| `socket_event_names.dart` | All socket event constants |
| `app_router.dart` | All routes and navigation |
| `call_signaling_service.dart` | Call signaling via socket |
