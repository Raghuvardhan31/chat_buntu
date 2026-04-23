# Chat Picture Like - WebSocket Integration Guide

## Overview
When a user likes another user's chat picture, the backend notifies the picture owner through:
1. **WebSocket event** `notification` (for online users)
2. **FCM notification** (for offline users)

This guide covers **WebSocket-only implementation** for real-time like notifications.

---

## Event Data Structure

### WebSocket Event: `notification`

**Event Name:** `notification`

**Payload Structure:**
```typescript
interface ChatPictureLikeNotification {
  type: 'chat_picture_like';
  likeId: string;                    // Unique ID of the like record
  fromUserId: string;                // User who liked the picture
  fromUserName: string;              // Name of the liker (e.g., "John Doe")
  from_user_chat_picture: string;    // Liker's profile picture URL
  toUserId: string;                  // User whose picture was liked (receiver)
  target_chat_picture_id: string;    // Version ID of the liked picture
  message: string;                   // e.g., "John Doe liked your picture"
  timestamp: string;                 // ISO date string
}
```

---

## WebSocket Events

### 1. Receiving Like Notifications

Listen to the `notification` event and filter by `type: 'chat_picture_like'`:

```typescript
import io from 'socket.io-client';

const socket = io('http://your-backend-url:3200', {
  auth: { token: authToken, loadHistory: true }
});

// Listen for like notifications
socket.on('notification', (data) => {
  if (data.type === 'chat_picture_like') {
    handleChatPictureLike(data);
  }
});

function handleChatPictureLike(data: ChatPictureLikeNotification) {
  const { 
    fromUserId,
    fromUserName, 
    from_user_chat_picture, 
    likeId, 
    target_chat_picture_id 
  } = data;
  
  // Show in-app notification
  showNotification({
    title: 'New like',
    message: `${fromUserName} liked your picture`,
    avatar: from_user_chat_picture,
    onClick: () => navigateToLikesList(target_chat_picture_id)
  });
  
  // Update like count in UI if user is viewing their profile
  updateLikeCount(target_chat_picture_id);
  
  // Optional: Play sound or haptic feedback
  playNotificationSound();
}
```

---

### 2. Sending Likes via WebSocket

Emit the `toggle-chat-picture-like` event to like/unlike a picture:

```typescript
// Like or unlike a picture
socket.emit('toggle-chat-picture-like', {
  likedUserId: string,              // User whose picture to like
  target_chat_picture_id: string    // Picture version ID
});

// Listen for response
socket.on('chat-picture-like-toggled', (response) => {
  const { 
    action,                         // 'liked' or 'unliked'
    likeCount,                      // Updated like count
    likeId,                         // ID of the like (if action is 'liked')
    target_chat_picture_id 
  } = response;
  
  // Update UI immediately
  updateLikeButton(action === 'liked');
  updateLikeCount(likeCount);
  
  // Show feedback
  if (action === 'liked') {
    showToast('Picture liked!');
    animateLikeButton();
  } else {
    showToast('Like removed');
  }
});

// Handle errors
socket.on('chat-picture-like-error', (error) => {
  console.error('Like error:', error);
  showToast(error.message || 'Failed to like picture');
});
```

---

### 3. Getting Like Count via WebSocket

```typescript
// Request like count for a specific picture
socket.emit('get-chat-picture-like-count', {
  likedUserId: string,
  target_chat_picture_id: string
});

// Listen for response
socket.on('chat-picture-like-count', (data) => {
  const { likedUserId, target_chat_picture_id, likeCount } = data;
  
  // Update UI with like count
  updateLikeCountDisplay(target_chat_picture_id, likeCount);
});
```

---

### 4. Checking If User Liked via WebSocket

```typescript
// Check if current user has liked a picture
socket.emit('check-chat-picture-liked', {
  likedUserId: string,
  target_chat_picture_id: string
});

// Listen for response
socket.on('chat-picture-liked-status', (data) => {
  const { likedUserId, target_chat_picture_id, isLiked } = data;
  
  // Update like button state
  updateLikeButton(isLiked);
});
```

---

### 5. Getting Users Who Liked via WebSocket

```typescript
// Get list of users who liked a picture
socket.emit('get-chat-picture-likers', {
  likedUserId: string,
  target_chat_picture_id: string,
  limit: 50                         // Optional: max users to return
});

// Listen for response
socket.on('chat-picture-likers', (data) => {
  const { likedUserId, target_chat_picture_id, likeCount, users } = data;
  
  // Display users who liked
  displayLikersList(users);
});

// User object structure:
interface Liker {
  id: string;
  firstName: string;
  lastName: string;
  mobileNo: string;
  chat_picture: string;
  chat_picture_version: string;
  createdAt: string;                // When they liked (ISO date)
}
```

---

## FCM Integration (For Offline Users)

When users are offline, they receive FCM notifications instead of WebSocket events.

### FCM Data Payload Structure

```typescript
{
  type: 'chat_picture_like',
  likeId: string,
  fromUserId: string,
  fromUserName: string,
  from_user_chat_picture: string,
  toUserId: string,
  target_chat_picture_id: string,
  body: string,                      // e.g., "John Doe liked your picture"
  title: string                      // e.g., "New like"
}
```

### React Native FCM Handler

```typescript
import messaging from '@react-native-firebase/messaging';

// Foreground message handler
messaging().onMessage(async (remoteMessage) => {
  if (remoteMessage.data?.type === 'chat_picture_like') {
    const data = remoteMessage.data;
    
    // Show in-app notification
    showInAppNotification({
      title: data.title || 'New like',
      body: data.body,
      avatar: data.from_user_chat_picture,
      data: {
        likeId: data.likeId,
        fromUserId: data.fromUserId,
        target_chat_picture_id: data.target_chat_picture_id
      }
    });
    
    // Update UI if needed
    updateLikeCountInUI(data.target_chat_picture_id);
  }
});

// Background/Quit state handler
messaging().setBackgroundMessageHandler(async (remoteMessage) => {
  if (remoteMessage.data?.type === 'chat_picture_like') {
    const data = remoteMessage.data;
    
    // Build and display notification
    await notifee.displayNotification({
      title: data.title || 'New like',
      body: data.body,
      android: {
        channelId: 'chat_picture_likes',
        smallIcon: 'ic_notification',
        largeIcon: data.from_user_chat_picture,
        pressAction: {
          id: 'default',
          launchActivity: 'default'
        }
      },
      ios: {
        attachments: [{
          url: data.from_user_chat_picture
        }]
      },
      data: {
        type: 'chat_picture_like',
        likeId: data.likeId,
        fromUserId: data.fromUserId,
        target_chat_picture_id: data.target_chat_picture_id
      }
    });
  }
});

// Handle notification tap
messaging().onNotificationOpenedApp((remoteMessage) => {
  if (remoteMessage.data?.type === 'chat_picture_like') {
    // Navigate to likes list or profile
    navigation.navigate('ProfileLikes', {
      pictureId: remoteMessage.data.target_chat_picture_id
    });
  }
});
```

---

## Complete Implementation Example

```typescript
class ChatPictureLikeManager {
  private socket: Socket;
  
  constructor(socket: Socket) {
    this.socket = socket;
    this.setupListeners();
  }
  
  private setupListeners() {
    // Listen for like notifications
    this.socket.on('notification', (data) => {
      if (data.type === 'chat_picture_like') {
        this.handleLikeNotification(data);
      }
    });
    
    // Listen for toggle response
    this.socket.on('chat-picture-like-toggled', (response) => {
      this.handleToggleResponse(response);
    });
    
    // Listen for like count
    this.socket.on('chat-picture-like-count', (data) => {
      this.handleLikeCount(data);
    });
    
    // Listen for liked status
    this.socket.on('chat-picture-liked-status', (data) => {
      this.handleLikedStatus(data);
    });
    
    // Listen for likers list
    this.socket.on('chat-picture-likers', (data) => {
      this.handleLikersList(data);
    });
    
    // Listen for errors
    this.socket.on('chat-picture-like-error', (error) => {
      this.handleError(error);
    });
  }
  
  // Toggle like/unlike
  toggleLike(likedUserId: string, target_chat_picture_id: string) {
    this.socket.emit('toggle-chat-picture-like', {
      likedUserId,
      target_chat_picture_id
    });
  }
  
  // Get like count
  getLikeCount(likedUserId: string, target_chat_picture_id: string) {
    this.socket.emit('get-chat-picture-like-count', {
      likedUserId,
      target_chat_picture_id
    });
  }
  
  // Check if liked
  checkIfLiked(likedUserId: string, target_chat_picture_id: string) {
    this.socket.emit('check-chat-picture-liked', {
      likedUserId,
      target_chat_picture_id
    });
  }
  
  // Get users who liked
  getUsersWhoLiked(likedUserId: string, target_chat_picture_id: string, limit = 50) {
    this.socket.emit('get-chat-picture-likers', {
      likedUserId,
      target_chat_picture_id,
      limit
    });
  }
  
  private handleLikeNotification(data: ChatPictureLikeNotification) {
    // Show notification
    showNotification({
      title: 'New like',
      message: data.message,
      avatar: data.from_user_chat_picture
    });
    
    // Update UI
    this.updateLikeCount(data.target_chat_picture_id);
  }
  
  private handleToggleResponse(response: any) {
    const { action, likeCount, target_chat_picture_id } = response;
    
    // Update button state
    updateLikeButton(action === 'liked');
    
    // Update count
    updateLikeCountDisplay(target_chat_picture_id, likeCount);
    
    // Show feedback
    showToast(action === 'liked' ? 'Picture liked!' : 'Like removed');
  }
  
  private handleLikeCount(data: any) {
    updateLikeCountDisplay(data.target_chat_picture_id, data.likeCount);
  }
  
  private handleLikedStatus(data: any) {
    updateLikeButton(data.isLiked);
  }
  
  private handleLikersList(data: any) {
    displayLikersList(data.users);
  }
  
  private handleError(error: any) {
    console.error('Like error:', error);
    showToast(error.message || 'Failed to process like');
  }
  
  private updateLikeCount(target_chat_picture_id: string) {
    // Request updated count
    this.getLikeCount(currentUserId, target_chat_picture_id);
  }
}

// Usage
const likeManager = new ChatPictureLikeManager(socket);

// Like a picture
likeManager.toggleLike(userId, pictureVersionId);

// Get like count
likeManager.getLikeCount(userId, pictureVersionId);

// Check if liked
likeManager.checkIfLiked(userId, pictureVersionId);

// Get users who liked
likeManager.getUsersWhoLiked(userId, pictureVersionId);
```

---

## Important Notes

### 1. Picture Version Tracking
- Each profile picture has a unique `chat_picture_version` (UUID)
- Use this version ID as `target_chat_picture_id` when liking
- This ensures likes are tied to specific picture versions
- When a user updates their picture, old likes remain on the old version

### 2. Online/Offline Detection
- Backend checks if user is **explicitly online** (not just WebSocket connected)
- User must have active WebSocket AND `isOnline: true` presence
- If not explicitly online, FCM is used even if WebSocket is connected

### 3. Self-Like Prevention
- Users cannot like their own pictures
- Backend returns error via `chat-picture-like-error` event

### 4. Toggle Behavior
- First click: **Like** the picture
- Second click: **Unlike** the picture
- Only "like" action triggers notifications (unlike is silent)

### 5. Real-time Updates
- All like actions are broadcast in real-time via WebSocket
- No polling required
- Instant UI updates for all connected users

---

## WebSocket Event Summary

| Event Name | Direction | Purpose |
|------------|-----------|---------|
| `notification` | Server → Client | Receive like notification |
| `toggle-chat-picture-like` | Client → Server | Like/unlike a picture |
| `chat-picture-like-toggled` | Server → Client | Toggle response |
| `get-chat-picture-like-count` | Client → Server | Request like count |
| `chat-picture-like-count` | Server → Client | Like count response |
| `check-chat-picture-liked` | Client → Server | Check if user liked |
| `chat-picture-liked-status` | Server → Client | Liked status response |
| `get-chat-picture-likers` | Client → Server | Request likers list |
| `chat-picture-likers` | Server → Client | Likers list response |
| `chat-picture-like-error` | Server → Client | Error notification |

---

## Testing

### Test Like Flow:

1. **User A likes User B's picture** via WebSocket
2. **User B receives notification** via `notification` event (if online)
3. **User B receives FCM** (if offline)
4. **Like count updates** in real-time
5. **User A unlikes** → no notification sent to User B

### Test Scenarios:
- ✅ Like a picture (first time)
- ✅ Unlike a picture (toggle off)
- ✅ View like count via WebSocket
- ✅ View users who liked via WebSocket
- ✅ Receive notification when online (WebSocket)
- ✅ Receive notification when offline (FCM)
- ✅ Cannot like own picture (error handling)
- ✅ Multiple users liking same picture
- ✅ Real-time like count updates

---

## Backend Code References

- **Toggle Like Controller:** `src/controllers/chat-picture-like.controller.ts:15-87`
- **Like Service:** `src/services/chat-picture-like.service.ts:11-99`
- **WebSocket/FCM Notification:** `src/controllers/chat.controller.ts:1843-1950`
- **FCM Service:** `src/services/fcm.service.ts:70-110`

---

## Questions?

If you need clarification on any part of this WebSocket integration, refer to the backend code or reach out for support.
