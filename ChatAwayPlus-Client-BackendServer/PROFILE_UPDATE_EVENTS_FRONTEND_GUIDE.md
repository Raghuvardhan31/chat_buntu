# Profile Update Events - Frontend Integration Guide

## Overview
When a user updates their profile (chat picture, name, share your voice, emojis), the backend notifies all their contacts through:
1. **WebSocket events** (for online users)
2. **Silent FCM notifications** (for offline users)

## Event Data Structure

### Profile Update Event: `profile-updated`

**Event Name:** `profile-updated`

**Payload Structure:**
```typescript
interface ProfileUpdateData {
  userId: string;                    // ID of user who updated their profile
  updatedFields: {
    name?: string;                   // Updated name
    chat_picture?: string;           // Updated profile picture URL
    chat_picture_version?: string;   // Version UUID for cache busting
    share_your_voice?: string;       // Updated status/voice message
    emojis_update?: string;          // Updated emoji
    emojis_caption?: string;         // Caption for the emoji
  };
}
```

## Backend Implementation Details

### 1. Update Profile Endpoint
**Endpoint:** `PUT /api/users/profile`

**Request Body:**
```typescript
{
  name?: string;              // Optional: New name
  chat_picture?: File;        // Optional: New profile picture (multipart/form-data)
  share_your_voice?: string;  // Optional: Status message
  emojis_update?: string;     // Optional: Emoji update
  emojis_caption?: string;    // Optional: Emoji caption
}
```

**Response:**
```typescript
{
  success: true,
  data: {
    user: User,                    // Updated user object
    share_your_voice: Status,      // Status object (if updated)
    emoji_update: EmojiUpdate      // Emoji update object (if updated)
  }
}
```

### 2. Notification Flow

When a profile is updated:

1. **Profile is updated** in the database
2. **WebSocket emission** to all online contacts via `profile-updated` event
3. **Silent FCM notification** sent to all offline contacts
4. **Contacts receive** the update in real-time or when they open the app

### 3. Silent Notification Structure

**FCM Payload:**
```typescript
{
  token: string,                    // User's FCM token
  data: {
    userId: string,                 // ID of user who updated profile
    updatedData: string             // JSON stringified updatedFields object
  },
  android: {
    priority: "high"
  },
  apns: {
    headers: {
      "apns-priority": "10"
    },
    payload: {
      aps: {
        "content-available": 1      // Silent notification flag
      }
    }
  }
}
```

**Note:** This is a **silent notification** (no UI alert), meant for background data sync.

## Frontend Integration

### 1. Using ChatService (Recommended)

The `ChatService` class provides a clean interface for handling profile updates:

```typescript
import { ChatService, ProfileUpdateData } from './utils/ChatService';

// Initialize chat service
const chatService = new ChatService('http://your-backend-url:3200');
await chatService.initialize(authToken);

// Register profile update handler
chatService.onProfileUpdated((data: ProfileUpdateData) => {
  console.log('Profile updated:', data);
  
  const { userId, updatedFields } = data;
  
  // Update UI based on changed fields
  if (updatedFields.name) {
    updateUserName(userId, updatedFields.name);
  }
  
  if (updatedFields.chat_picture) {
    // Use chat_picture_version for cache busting
    const imageUrl = updatedFields.chat_picture_version 
      ? `${updatedFields.chat_picture}?v=${updatedFields.chat_picture_version}`
      : updatedFields.chat_picture;
    updateUserAvatar(userId, imageUrl);
  }
  
  if (updatedFields.share_your_voice) {
    updateUserStatus(userId, updatedFields.share_your_voice);
  }
  
  if (updatedFields.emojis_update) {
    updateUserEmoji(userId, {
      emoji: updatedFields.emojis_update,
      caption: updatedFields.emojis_caption
    });
  }
});

// Clean up when component unmounts
chatService.removeProfileUpdateHandler(handler);
```

### 2. Direct Socket.IO Integration

If not using ChatService:

```typescript
import io from 'socket.io-client';

const socket = io('http://your-backend-url:3200', {
  auth: { token: authToken, loadHistory: true }
});

socket.on('profile-updated', (data: ProfileUpdateData) => {
  const { userId, updatedFields } = data;
  
  // Handle profile updates
  handleProfileUpdate(userId, updatedFields);
});
```

### 3. Handling Silent FCM Notifications

**For React Native (using @react-native-firebase/messaging):**

```typescript
import messaging from '@react-native-firebase/messaging';

// Background message handler
messaging().setBackgroundMessageHandler(async (remoteMessage) => {
  if (remoteMessage.data?.userId && remoteMessage.data?.updatedData) {
    const userId = remoteMessage.data.userId;
    const updatedFields = JSON.parse(remoteMessage.data.updatedData);
    
    // Update local cache/storage
    await updateLocalUserProfile(userId, updatedFields);
  }
});

// Foreground message handler
messaging().onMessage(async (remoteMessage) => {
  if (remoteMessage.data?.userId && remoteMessage.data?.updatedData) {
    const userId = remoteMessage.data.userId;
    const updatedFields = JSON.parse(remoteMessage.data.updatedData);
    
    // Update UI in real-time
    updateUIWithProfileChanges(userId, updatedFields);
  }
});
```

**For Web (using Firebase SDK):**

```typescript
import { getMessaging, onMessage } from 'firebase/messaging';

const messaging = getMessaging();

onMessage(messaging, (payload) => {
  if (payload.data?.userId && payload.data?.updatedData) {
    const userId = payload.data.userId;
    const updatedFields = JSON.parse(payload.data.updatedData);
    
    // Update UI
    handleProfileUpdate(userId, updatedFields);
  }
});
```

## Important Notes

### 1. Chat Picture Versioning
- Each profile picture update generates a new `chat_picture_version` (UUID)
- Use this for cache busting: `${chat_picture}?v=${chat_picture_version}`
- This ensures users see the latest profile picture immediately

### 2. Image URL Format
- Profile pictures are served through: `/api/images/stream/{s3Key}`
- Full URL: `http://your-backend-url:3200/api/images/stream/profile/{userId}/{filename}`

### 3. Contact-Only Updates
- Profile updates are only sent to users in the updater's contact list
- Non-contacts will not receive these notifications

### 4. Notification Priority
- Both Android and iOS notifications are set to high priority
- iOS uses `content-available: 1` for background updates
- Android uses `priority: "high"`

## Example Implementation

```typescript
// ProfileUpdateManager.ts
class ProfileUpdateManager {
  private chatService: ChatService;
  private userCache: Map<string, UserProfile> = new Map();
  
  constructor(chatService: ChatService) {
    this.chatService = chatService;
    this.setupListeners();
  }
  
  private setupListeners() {
    // WebSocket updates
    this.chatService.onProfileUpdated((data) => {
      this.handleProfileUpdate(data);
    });
    
    // FCM updates (if using React Native)
    this.setupFCMListener();
  }
  
  private handleProfileUpdate(data: ProfileUpdateData) {
    const { userId, updatedFields } = data;
    
    // Update cache
    const cachedUser = this.userCache.get(userId) || {};
    this.userCache.set(userId, { ...cachedUser, ...updatedFields });
    
    // Notify UI components
    this.notifyUIComponents(userId, updatedFields);
    
    // Update local storage
    this.updateLocalStorage(userId, updatedFields);
  }
  
  private notifyUIComponents(userId: string, fields: any) {
    // Emit custom events or use state management
    window.dispatchEvent(new CustomEvent('profile-updated', {
      detail: { userId, fields }
    }));
  }
  
  private async updateLocalStorage(userId: string, fields: any) {
    // Persist to AsyncStorage/localStorage
    const key = `user_profile_${userId}`;
    const existing = await this.getStoredProfile(userId);
    await this.storeProfile(userId, { ...existing, ...fields });
  }
  
  private setupFCMListener() {
    // React Native FCM setup
    messaging().onMessage(async (message) => {
      if (message.data?.userId && message.data?.updatedData) {
        const data: ProfileUpdateData = {
          userId: message.data.userId,
          updatedFields: JSON.parse(message.data.updatedData)
        };
        this.handleProfileUpdate(data);
      }
    });
  }
}
```

## Testing

### Test Profile Update Flow:

1. **Update a user's profile** via the API
2. **Check WebSocket event** is received by online contacts
3. **Check FCM notification** is sent to offline contacts
4. **Verify UI updates** reflect the changes immediately

### Test Scenarios:
- ✅ Update name only
- ✅ Update chat picture only
- ✅ Update share your voice only
- ✅ Update emojis only
- ✅ Update multiple fields together
- ✅ Verify cache busting with chat_picture_version
- ✅ Verify only contacts receive updates

## Backend Code References

- **Profile Update Controller:** `src/controllers/user.controller.ts:67-181`
- **FCM Service:** `src/services/fcm.service.ts:138-176`
- **WebSocket Emission:** `src/controllers/chat.controller.ts:1952-1981`
- **ChatService Interface:** `src/utils/ChatService.ts:16-213`

## Questions?

If you need clarification on any part of this integration, refer to the backend code or reach out for support.
