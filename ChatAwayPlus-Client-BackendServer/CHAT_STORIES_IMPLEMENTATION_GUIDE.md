# Chat Stories Feature - Complete Implementation Guide

## 📋 Overview

This document provides a complete guide for the **Chat Stories** feature (WhatsApp/Instagram-like image stories) that has been implemented in the backend. This is separate from the existing "Share Your Voice" status feature.

Design goal:

- HTTP is used only for media upload/download (S3)
- Story metadata + actions are socket-first (to avoid frequent REST calls)

---

## 🗂️ Files Created

### **Database Models**

1. `src/db/models/story.model.ts` - Main story model
2. `src/db/models/story-view.model.ts` - Story views tracking model

### **Migrations**

1. `src/db/migrations/20260122000001-create-stories-table.ts`
2. `src/db/migrations/20260122000002-create-story-views-table.ts`

### **Service Layer**

1. `src/services/story.service.ts` - Business logic for stories

### **Controller Layer**

1. `src/controllers/story.controller.ts` - REST API endpoints

### **Routes**

1. `src/routes/story.routes.ts` - Route definitions

### **Modified Files**

1. `src/controllers/chat.controller.ts` - Added WebSocket notification methods
2. `src/index.ts` - Registered story routes

---

## 📊 Database Schema

### **Stories Table**

```sql
CREATE TABLE stories (
  id UUID PRIMARY KEY,
  userId UUID NOT NULL (FK -> users.id),
  mediaUrl TEXT NOT NULL,
  mediaType ENUM('image', 'video') DEFAULT 'image',
  caption TEXT NULL,
  duration INTEGER DEFAULT 5,
  viewsCount INTEGER DEFAULT 0,
  expiresAt TIMESTAMP NOT NULL,
  backgroundColor VARCHAR(20) NULL,
  createdAt TIMESTAMP NOT NULL,
  updatedAt TIMESTAMP NOT NULL,
  deletedAt TIMESTAMP NULL
);
```

### **Story Views Table**

```sql
CREATE TABLE story_views (
  id UUID PRIMARY KEY,
  storyId UUID NOT NULL (FK -> stories.id),
  viewerId UUID NOT NULL (FK -> users.id),
  viewedAt TIMESTAMP NOT NULL,
  UNIQUE(storyId, viewerId)
);
```

---

## 🚀 REST API Endpoints

### **Base URL:** `/api/stories`

| Method | Endpoint            | Description                            | Auth Required |
| ------ | ------------------- | -------------------------------------- | ------------- |
| POST   | `/`                 | Create new story                       | ✅            |
| GET    | `/contacts`         | Get stories from all contacts          | ✅            |
| GET    | `/my`               | Get my own stories with viewer details | ✅            |
| GET    | `/user/:userId`     | Get specific user's stories            | ✅            |
| GET    | `/:storyId`         | Get single story details               | ✅            |
| DELETE | `/:storyId`         | Delete own story                       | ✅            |
| POST   | `/:storyId/view`    | Mark story as viewed                   | ✅            |
| GET    | `/:storyId/viewers` | Get viewers list (owner only)          | ✅            |

Note:

- These REST endpoints remain available as a fallback.
- The recommended approach for the app is to use the WebSocket (Socket.IO) events below for story actions.

---

## 📡 API Request/Response Examples (cURL)

### **1. Create Story (Option A: With Pre-uploaded Media URL)**

```bash
curl -X POST http://192.168.1.2:3200/api/stories \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "mediaUrl": "/api/images/stream/stories/user-id/story-123.jpg",
    "mediaType": "image",
    "caption": "Beautiful sunset!",
    "duration": 5,
    "backgroundColor": "#FF5733"
  }'
```

**Response:**

```json
{
  "success": true,
  "message": "Story created successfully",
  "story": {
    "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
    "userId": "user-uuid-here",
    "mediaUrl": "/api/images/stream/stories/user-id/story-123.jpg",
    "mediaType": "image",
    "caption": "Beautiful sunset!",
    "duration": 5,
    "viewsCount": 0,
    "expiresAt": "2026-01-25T11:30:00.000Z",
    "backgroundColor": "#FF5733",
    "createdAt": "2026-01-24T11:30:00.000Z",
    "updatedAt": "2026-01-24T11:30:00.000Z",
    "deletedAt": null
  }
}
```

### **1. Create Story (Option B: Direct File Upload)**

```bash
curl -X POST http://192.168.1.2:3200/api/stories \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -F "media=@/path/to/your/image.jpg" \
  -F "caption=Beautiful sunset!" \
  -F "duration=5" \
  -F "backgroundColor=#FF5733"
```

**Response:**

```json
{
  "success": true,
  "message": "Story created successfully",
  "story": {
    "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
    "userId": "user-uuid-here",
    "mediaUrl": "/api/images/stream/stories/user-id/1737715800000-image.jpg",
    "mediaType": "image",
    "caption": "Beautiful sunset!",
    "duration": 5,
    "viewsCount": 0,
    "expiresAt": "2026-01-25T11:30:00.000Z",
    "backgroundColor": "#FF5733",
    "createdAt": "2026-01-24T11:30:00.000Z",
    "updatedAt": "2026-01-24T11:30:00.000Z",
    "deletedAt": null
  }
}
```

---

### **2. Get Contacts' Stories**

```bash
curl -X GET http://192.168.1.2:3200/api/stories/contacts \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

**Response:**

```json
{
  "success": true,
  "stories": [
    {
      "user": {
        "id": "user-uuid-1",
        "firstName": "John",
        "lastName": "Doe",
        "chat_picture": "/api/images/stream/profile/john-pic.jpg",
        "mobile_number": "+1234567890"
      },
      "stories": [
        {
          "id": "story-uuid-1",
          "mediaUrl": "/api/images/stream/stories/user-uuid-1/story1.jpg",
          "mediaType": "image",
          "caption": "Hello from the beach!",
          "duration": 5,
          "viewsCount": 10,
          "expiresAt": "2026-01-25T11:30:00.000Z",
          "backgroundColor": null,
          "createdAt": "2026-01-24T11:30:00.000Z",
          "isViewed": false
        },
        {
          "id": "story-uuid-2",
          "mediaUrl": "/api/images/stream/stories/user-uuid-1/story2.jpg",
          "mediaType": "image",
          "caption": "Sunset vibes",
          "duration": 7,
          "viewsCount": 15,
          "expiresAt": "2026-01-25T13:00:00.000Z",
          "backgroundColor": "#FF6B6B",
          "createdAt": "2026-01-24T13:00:00.000Z",
          "isViewed": true
        }
      ],
      "hasUnviewed": true
    },
    {
      "user": {
        "id": "user-uuid-2",
        "firstName": "Jane",
        "lastName": "Smith",
        "chat_picture": "/api/images/stream/profile/jane-pic.jpg",
        "mobile_number": "+9876543210"
      },
      "stories": [
        {
          "id": "story-uuid-3",
          "mediaUrl": "/api/images/stream/stories/user-uuid-2/video1.mp4",
          "mediaType": "video",
          "caption": "Check this out!",
          "duration": 10,
          "viewsCount": 5,
          "expiresAt": "2026-01-25T10:00:00.000Z",
          "backgroundColor": null,
          "createdAt": "2026-01-24T10:00:00.000Z",
          "isViewed": false
        }
      ],
      "hasUnviewed": true
    }
  ]
}
```

---

### **3. Get My Stories**

```bash
curl -X GET http://192.168.1.2:3200/api/stories/my \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

**Response:**

```json
{
  "success": true,
  "stories": [
    {
      "id": "my-story-uuid-1",
      "userId": "my-user-id",
      "mediaUrl": "/api/images/stream/stories/my-user-id/story1.jpg",
      "mediaType": "image",
      "caption": "My first story",
      "duration": 5,
      "viewsCount": 25,
      "expiresAt": "2026-01-25T09:00:00.000Z",
      "backgroundColor": "#4ECDC4",
      "createdAt": "2026-01-24T09:00:00.000Z",
      "updatedAt": "2026-01-24T09:00:00.000Z",
      "deletedAt": null
    },
    {
      "id": "my-story-uuid-2",
      "userId": "my-user-id",
      "mediaUrl": "/api/images/stream/stories/my-user-id/story2.jpg",
      "mediaType": "image",
      "caption": "Another one!",
      "duration": 6,
      "viewsCount": 18,
      "expiresAt": "2026-01-25T12:00:00.000Z",
      "backgroundColor": null,
      "createdAt": "2026-01-24T12:00:00.000Z",
      "updatedAt": "2026-01-24T12:00:00.000Z",
      "deletedAt": null
    }
  ]
}
```

---

### **4. Get Specific User's Stories**

```bash
curl -X GET http://192.168.1.2:3200/api/stories/user/USER_UUID_HERE \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

**Response:**

```json
{
  "success": true,
  "stories": [
    {
      "id": "story-uuid-1",
      "userId": "USER_UUID_HERE",
      "mediaUrl": "/api/images/stream/stories/USER_UUID_HERE/story1.jpg",
      "mediaType": "image",
      "caption": "Amazing view!",
      "duration": 5,
      "viewsCount": 12,
      "expiresAt": "2026-01-25T14:30:00.000Z",
      "backgroundColor": null,
      "createdAt": "2026-01-24T14:30:00.000Z",
      "isViewed": true
    }
  ]
}
```

---

### **5. Get Single Story Details**

```bash
curl -X GET http://192.168.1.2:3200/api/stories/STORY_ID_HERE \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

**Response:**

```json
{
  "success": true,
  "story": {
    "id": "STORY_ID_HERE",
    "userId": "user-uuid",
    "mediaUrl": "/api/images/stream/stories/user-uuid/story.jpg",
    "mediaType": "image",
    "caption": "Beautiful moment",
    "duration": 5,
    "viewsCount": 20,
    "expiresAt": "2026-01-25T15:00:00.000Z",
    "backgroundColor": "#95E1D3",
    "createdAt": "2026-01-24T15:00:00.000Z",
    "updatedAt": "2026-01-24T15:00:00.000Z",
    "deletedAt": null,
    "isViewed": false
  }
}
```

**Error Response (Story Not Found):**

```json
{
  "success": false,
  "message": "Story not found or expired"
}
```

---

### **6. Mark Story as Viewed**

```bash
curl -X POST http://192.168.1.2:3200/api/stories/STORY_ID_HERE/view \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

**Response (First View):**

```json
{
  "success": true,
  "message": "Story view recorded",
  "isNewView": true
}
```

**Response (Already Viewed):**

```json
{
  "success": true,
  "message": "Story view recorded",
  "isNewView": false
}
```

**Error Response:**

```json
{
  "success": false,
  "message": "Story not found or expired"
}
```

---

### **7. Get Story Viewers (Owner Only)**

```bash
curl -X GET http://192.168.1.2:3200/api/stories/STORY_ID_HERE/viewers \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

**Response:**

```json
{
  "success": true,
  "viewers": [
    {
      "id": "view-uuid-1",
      "viewedAt": "2026-01-24T12:30:00.000Z",
      "viewer": {
        "id": "viewer-uuid-1",
        "firstName": "Jane",
        "lastName": "Smith",
        "chat_picture": "/api/images/stream/profile/jane.jpg",
        "mobile_number": "+9876543210"
      }
    },
    {
      "id": "view-uuid-2",
      "viewedAt": "2026-01-24T13:15:00.000Z",
      "viewer": {
        "id": "viewer-uuid-2",
        "firstName": "Bob",
        "lastName": "Johnson",
        "chat_picture": "/api/images/stream/profile/bob.jpg",
        "mobile_number": "+5551234567"
      }
    }
  ],
  "totalViews": 15
}
```

**Error Response (Unauthorized - Not Story Owner):**

```json
{
  "success": false,
  "message": "Unauthorized"
}
```

**Error Response (Story Not Found):**

```json
{
  "success": false,
  "message": "Story not found"
}
```

---

### **8. Delete Story (Owner Only)**

```bash
curl -X DELETE http://192.168.1.2:3200/api/stories/STORY_ID_HERE \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

**Response:**

```json
{
  "success": true,
  "message": "Story deleted successfully"
}
```

**Error Response (Not Story Owner):**

```json
{
  "success": false,
  "message": "You can only delete your own stories"
}
```

**Error Response (Story Not Found):**

```json
{
  "success": false,
  "message": "Story not found"
}
```

---

## 🔌 WebSocket Events

### **Events Emitted by Server:**

#### **1. story-created**

Sent to all online contacts when a new story is posted.

```javascript
{
  type: 'new_story',
  storyId: 'uuid',
  userId: 'uuid',
  userName: 'John Doe',
  userProfilePic: 'https://...',
  mediaUrl: 'https://...',
  mediaType: 'image',
  createdAt: '2026-01-22T11:30:00.000Z',
  timestamp: '2026-01-22T11:30:00.000Z'
}
```

#### **2. story-viewed**

Sent to story owner when someone views their story.

```javascript
{
  type: 'story_view',
  storyId: 'uuid',
  viewerId: 'uuid',
  viewerName: 'Jane Smith',
  viewerProfilePic: 'https://...',
  timestamp: '2026-01-22T11:30:00.000Z'
}
```

#### **3. story-deleted**

Sent to all online contacts when a story is deleted.

```javascript
{
  type: 'story_deleted',
  storyId: 'uuid',
  userId: 'uuid',
  timestamp: '2026-01-22T11:30:00.000Z'
}
```

---

## 🔌 WebSocket (Socket-first) Story Actions

These are the recommended events for the mobile app to avoid repeated HTTP calls.

Offline behavior:

- Online contacts receive real-time Socket.IO events (`story-created`, `story-deleted`).
- Offline contacts receive a silent multi-device FCM data-only push with `type: stories_changed`.
- Mobile app should treat `stories_changed` as a trigger to refresh stories in background (no UI notification required).

All requests include:

- `requestId` (string) generated by the client for response matching.

All responses come via:

- **Event:** `stories:ack`
- Payload includes `action`, `requestId`, `success`, and action-specific fields.

### **1) Create Story (metadata) - socket-first**

Before calling this event, upload the media to S3 using the existing upload endpoint.

**Client emits:** `stories:create`

Payload:

```javascript
{
  requestId: 'uuid-or-random-string',
  mediaUrl: '<S3 key from /api/chats/upload-file>',
  mediaType: 'image' | 'video',
  caption: 'optional',
  duration: 5 // optional
}
```

Notes:

- `duration` is optional. If not provided, backend defaults to `5` seconds.
- Backend always sets `expiresAt = now + 24 hours` (future-ready; server can change expiry policy later).

FCM fallback for offline contacts:

- If a contact is offline when a story is created, backend sends `type: stories_changed` with `action: created`.

**Server replies:** `stories:ack`

```javascript
{
  action: 'create',
  requestId: '...',
  success: true,
  story: { ... }
}
```

Also server emits to contacts (online):

- `story-created`

### **2) Get Contacts Stories**

**Client emits:** `stories:get-contacts`

```javascript
{
  requestId: "...";
}
```

**Server replies:** `stories:ack`

```javascript
{
  action: 'get-contacts',
  requestId: '...',
  success: true,
  stories: [ ...groupedByUser ]
}
```

### **3) Get My Stories (owner)**

**Client emits:** `stories:get-my`

```javascript
{
  requestId: "...";
}
```

**Server replies:** `stories:ack`

```javascript
{
  action: 'get-my',
  requestId: '...',
  success: true,
  stories: [ ... ]
}
```

### **4) Get A User's Stories**

**Client emits:** `stories:get-user`

```javascript
{ requestId: '...', userId: '<targetUserId>' }
```

**Server replies:** `stories:ack`

```javascript
{
  action: 'get-user',
  requestId: '...',
  success: true,
  stories: [ ... ]
}
```

### **5) Mark Story Viewed (viewer)**

When a user watches a story, call this once per story.

**Client emits:** `stories:mark-viewed`

```javascript
{ requestId: '...', storyId: '<storyId>' }
```

**Server replies:** `stories:ack`

```javascript
{
  action: 'mark-viewed',
  requestId: '...',
  success: true,
  isNewView: true
}
```

If `isNewView === true`, server emits to the story owner (if online):

- `story-viewed`

FCM fallback for offline owner:

- If the story owner is offline when a view happens, backend sends `type: stories_changed` with `action: viewed`.

### **6) Get Story Viewers (owner)**

**Client emits:** `stories:get-viewers`

```javascript
{ requestId: '...', storyId: '<storyId>' }
```

**Server replies:** `stories:ack`

```javascript
{
  action: 'get-viewers',
  requestId: '...',
  success: true,
  viewers: [ ... ],
  totalViews: 10
}
```

### **7) Delete Story (owner)**

**Client emits:** `stories:delete`

```javascript
{ requestId: '...', storyId: '<storyId>' }
```

**Server replies:** `stories:ack`

```javascript
{
  action: 'delete',
  requestId: '...',
  success: true,
  message: 'Story deleted successfully'
}
```

Server also emits to contacts (online):

- `story-deleted`

FCM fallback for offline contacts:

- If a contact is offline when a story is deleted, backend sends `type: stories_changed` with `action: deleted`.

---

## 🔧 Setup Instructions

### **1. Run Migrations**

```bash
# Make sure you're in the project root
cd c:\ProjectAdventurers

# Run migrations to create tables
npm run migrate
# OR if using sequelize-cli directly
npx sequelize-cli db:migrate
```

### **2. Verify Database Tables**

Check that these tables were created:

- `stories`
- `story_views`

### **3. Test the API**

```bash
# Start the server
npm run dev

# Server should log:
# "Server is running in development mode on port 3200"
# "WebSocket server is running"
```

---

## 🎯 Key Features Implemented

✅ **24-Hour Auto-Expiry** - Stories automatically expire after 24 hours
✅ **View Tracking** - Track who viewed each story (unique views)
✅ **Contact-Based** - Only show stories from users in contacts list
✅ **Real-Time Notifications** - WebSocket events for new stories, views, deletions
✅ **Multiple Stories** - Users can post multiple stories
✅ **Story Grouping** - Stories grouped by user in response
✅ **View Status** - Mark stories as viewed/unviewed
✅ **Image & Video Support** - Support for both media types
✅ **Optional Captions** - Add text captions to stories
✅ **Viewer List** - Story owners can see who viewed their stories

---

## 🔐 Authentication

All story endpoints require authentication via JWT token:

```http
Authorization: Bearer <your-jwt-token>
```

The token should be obtained from the `/api/auth/login` endpoint.

---

## 📱 Frontend Integration Points

### **1. Upload Story Image**

Before creating a story, upload the image:

```javascript
// Upload image to S3 (use existing upload endpoint)
POST /api/chats/upload-file
Content-Type: multipart/form-data

// Then create story with returned mediaUrl
socket.emit('stories:create', {
  requestId: '<client-generated>',
  mediaUrl: '<returned-s3-key>',
  mediaType: 'image',
  caption: 'optional',
  duration: 5 // optional
});
```

### **2. Listen to WebSocket Events**

```javascript
socket.on("story-created", (data) => {
  // Refresh stories list or show notification
  console.log("New story from:", data.userName);
});

socket.on("story-viewed", (data) => {
  // Update viewer count for own stories
  console.log("Story viewed by:", data.viewerName);
});

socket.on("story-deleted", (data) => {
  // Remove story from UI
  console.log("Story deleted:", data.storyId);
});
```

### **3. Display Stories**

```javascript
// Fetch contacts' stories (socket-first)
socket.emit("stories:get-contacts", { requestId: "<client-generated>" });

// Group by user and show:
// - User profile picture with ring (blue if unviewed, gray if all viewed)
// - Story count badge
// - Click to view user's stories in sequence
```

---

## 🧹 Cleanup Job (Optional)

Add a cron job to clean up expired stories:

```javascript
// In your server startup or cron service
import { cleanupExpiredStories } from "./services/story.service";

// Run every hour
setInterval(
  async () => {
    await cleanupExpiredStories();
  },
  60 * 60 * 1000,
);
```

---

## 🆚 Difference from "Share Your Voice" Status

| Feature      | Share Your Voice    | Chat Stories     |
| ------------ | ------------------- | ---------------- |
| **Table**    | `statuses`          | `stories`        |
| **Model**    | `status.model.ts`   | `story.model.ts` |
| **Routes**   | `/api/status`       | `/api/stories`   |
| **Content**  | Text only           | Images/Videos    |
| **Duration** | Permanent           | 24 hours         |
| **Tracking** | Like count          | View tracking    |
| **Purpose**  | Text status updates | Visual stories   |

---

## 🐛 Testing Checklist

- [ ] Create a story with image
- [ ] Create a story with caption
- [ ] View another user's story
- [ ] Check if view count increases
- [ ] Check if viewer appears in viewers list
- [ ] Delete own story
- [ ] Try to delete someone else's story (should fail)
- [ ] Check WebSocket notifications for new stories
- [ ] Check WebSocket notifications for story views
- [ ] Verify stories expire after 24 hours
- [ ] Verify only contacts' stories are visible

---

## 📞 Support

For questions or issues, contact the backend team or refer to:

- `src/services/story.service.ts` - Business logic
- `src/controllers/story.controller.ts` - API endpoints
- `src/controllers/chat.controller.ts` - WebSocket events (lines 2874-2980)

---

## 🎉 Summary

The Chat Stories feature is now fully implemented and ready for frontend integration. All REST APIs, WebSocket events, and database structures are in place. The feature follows WhatsApp/Instagram patterns with 24-hour expiry, view tracking, and real-time notifications.

**Next Steps:**

1. Run migrations to create database tables
2. Test API endpoints using Postman/Thunder Client
3. Integrate with frontend application
4. Set up cron job for expired story cleanup (optional)
5. Configure S3 for story media uploads (if not already done)
