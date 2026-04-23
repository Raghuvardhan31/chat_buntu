# WhatsApp-Style Message Reactions - Backend Implementation Spec

## Overview
This document specifies the backend requirements for implementing WhatsApp-style message reactions in ChatAway+. Users can react to messages with emojis, see who reacted, and receive real-time updates.

---

## 1. Core Features

### 1.1 Reaction Capabilities
- Users can add ONE emoji reaction per message (like WhatsApp)
- Users can change their reaction to a different emoji
- Users can remove their reaction
- Multiple users can react to the same message with different emojis
- Reactions work on both sent and received messages

### 1.2 Real-Time Updates
- Reactions must be delivered via WebSocket in real-time
- Both sender and receiver see reactions instantly
- Reaction counts update immediately in chat list

---

## 2. Database Schema

### 2.1 Reactions Table
```sql
CREATE TABLE message_reactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    message_id UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    emoji VARCHAR(10) NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    
    -- Ensure one reaction per user per message
    UNIQUE(message_id, user_id)
);

-- Indexes for performance
CREATE INDEX idx_reactions_message_id ON message_reactions(message_id);
CREATE INDEX idx_reactions_user_id ON message_reactions(user_id);
```

### 2.2 Messages Table Update
Add a JSON column to store reactions summary (optional, for performance):
```sql
ALTER TABLE messages 
ADD COLUMN reactions_json JSONB;

-- Example reactions_json structure:
-- [
--   {"userId": "uuid-1", "emoji": "❤️", "timestamp": "2026-01-05T10:30:00Z"},
--   {"userId": "uuid-2", "emoji": "👍", "timestamp": "2026-01-05T10:31:00Z"}
-- ]
```

---

## 3. REST API Endpoints

### 3.1 Add/Update Reaction
**Endpoint:** `POST /api/messages/:messageId/reactions`

**Headers:**
```
Authorization: Bearer <jwt_token>
Content-Type: application/json
```

**Request Body:**
```json
{
  "emoji": "❤️"
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "reactionId": "uuid-reaction-id",
    "messageId": "uuid-message-id",
    "userId": "uuid-user-id",
    "emoji": "❤️",
    "createdAt": "2026-01-05T10:30:00Z",
    "updatedAt": "2026-01-05T10:30:00Z"
  },
  "message": "Reaction added successfully"
}
```

**Response (400 Bad Request):**
```json
{
  "success": false,
  "message": "Invalid emoji format"
}
```

---

### 3.2 Remove Reaction
**Endpoint:** `DELETE /api/messages/:messageId/reactions`

**Headers:**
```
Authorization: Bearer <jwt_token>
```

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Reaction removed successfully"
}
```

---

### 3.3 Get Message Reactions
**Endpoint:** `GET /api/messages/:messageId/reactions`

**Headers:**
```
Authorization: Bearer <jwt_token>
```

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "messageId": "uuid-message-id",
    "reactions": [
      {
        "reactionId": "uuid-1",
        "userId": "uuid-user-1",
        "firstName": "John",
        "lastName": "Doe",
        "emoji": "❤️",
        "createdAt": "2026-01-05T10:30:00Z"
      },
      {
        "reactionId": "uuid-2",
        "userId": "uuid-user-2",
        "firstName": "Jane",
        "lastName": "Smith",
        "emoji": "👍",
        "createdAt": "2026-01-05T10:31:00Z"
      }
    ],
    "totalCount": 2
  }
}
```

---

## 4. WebSocket Events

### 4.1 Reaction Added/Updated Event
**Event Name:** `reaction:added` or `message:reaction`

**Payload sent to both sender and receiver:**
```json
{
  "type": "reaction:added",
  "data": {
    "messageId": "uuid-message-id",
    "reactionId": "uuid-reaction-id",
    "userId": "uuid-user-id",
    "firstName": "John",
    "lastName": "Doe",
    "emoji": "❤️",
    "timestamp": "2026-01-05T10:30:00Z",
    "isOwnReaction": false
  }
}
```

**Notes:**
- `isOwnReaction`: `true` if the reaction is from the current user (for UI feedback)
- Send to both participants in the conversation
- Include user details (firstName, lastName) so client can display "John reacted ❤️"

---

### 4.2 Reaction Removed Event
**Event Name:** `reaction:removed`

**Payload:**
```json
{
  "type": "reaction:removed",
  "data": {
    "messageId": "uuid-message-id",
    "reactionId": "uuid-reaction-id",
    "userId": "uuid-user-id",
    "timestamp": "2026-01-05T10:32:00Z"
  }
}
```

---

## 5. Message Object Updates

### 5.1 Include Reactions in Message Response
When sending messages via WebSocket or REST API, include reactions:

```json
{
  "chatId": "uuid-message-id",
  "senderId": "uuid-sender",
  "receiverId": "uuid-receiver",
  "messageText": "Hello!",
  "messageStatus": "delivered",
  "createdAt": "2026-01-05T10:00:00Z",
  "reactionsJson": [
    {
      "userId": "uuid-user-1",
      "firstName": "John",
      "lastName": "Doe",
      "emoji": "❤️",
      "timestamp": "2026-01-05T10:30:00Z"
    },
    {
      "userId": "uuid-user-2",
      "firstName": "Jane",
      "lastName": "Smith",
      "emoji": "👍",
      "timestamp": "2026-01-05T10:31:00Z"
    }
  ]
}
```

---

## 6. UI Text Examples (WhatsApp-Style)

### 6.1 Reaction Notifications
The app will display these messages based on reactions:

#### When you react to someone's message:
- **"You reacted ❤️ to this message"**
- **"You reacted 👍 to this message"**

#### When someone reacts to your message:
- **"John reacted ❤️ to your message"**
- **"Jane reacted 👍 to your message"**
- **"John and Jane reacted to your message"** (multiple reactions)
- **"John and 2 others reacted to your message"** (3+ reactions)

#### When viewing reaction details:
- **"John reacted ❤️"**
- **"You reacted 👍"**
- **"Jane reacted 😂"**

---

## 7. Business Rules

### 7.1 Reaction Constraints
1. **One reaction per user per message** - If user reacts again, update existing reaction
2. **Valid emojis only** - Backend should validate emoji format
3. **Message must exist** - Return 404 if message doesn't exist
4. **User must be participant** - Only sender or receiver can react
5. **No reactions on deleted messages** - Return 400 if message is deleted

### 7.2 Reaction Lifecycle
```
User taps emoji → 
  Client sends REST POST → 
    Backend saves to DB → 
      Backend emits WebSocket event → 
        Both users receive real-time update → 
          UI updates instantly
```

---

## 8. Performance Considerations

### 8.1 Caching Strategy
- Cache reactions in `messages.reactions_json` for fast retrieval
- Update cache whenever reaction is added/removed
- Use database triggers or application logic to maintain consistency

### 8.2 Pagination
For messages with many reactions (unlikely but possible):
```
GET /api/messages/:messageId/reactions?page=1&limit=20
```

---

## 9. Example Scenarios

### Scenario 1: User A reacts to User B's message
1. **User A** sends: `POST /api/messages/msg-123/reactions` with `{"emoji": "❤️"}`
2. **Backend** saves reaction to database
3. **Backend** emits WebSocket event to **both User A and User B**:
   ```json
   {
     "type": "reaction:added",
     "data": {
       "messageId": "msg-123",
       "userId": "user-a-id",
       "firstName": "Alice",
       "lastName": "Smith",
       "emoji": "❤️",
       "timestamp": "2026-01-05T10:30:00Z"
     }
   }
   ```
4. **User A's app** shows: "You reacted ❤️ to this message"
5. **User B's app** shows: "Alice reacted ❤️ to your message"

---

### Scenario 2: User changes reaction
1. **User A** already reacted ❤️ to message
2. **User A** taps 👍 emoji
3. **Client** sends: `POST /api/messages/msg-123/reactions` with `{"emoji": "👍"}`
4. **Backend** updates existing reaction (UPSERT based on UNIQUE constraint)
5. **Backend** emits WebSocket event with new emoji
6. **Both users** see updated reaction instantly

---

### Scenario 3: User removes reaction
1. **User A** taps on their existing ❤️ reaction
2. **Client** sends: `DELETE /api/messages/msg-123/reactions`
3. **Backend** deletes reaction from database
4. **Backend** emits `reaction:removed` event
5. **Both users** see reaction disappear instantly

---

## 10. Error Handling

### 10.1 Common Errors
```json
// Message not found
{
  "success": false,
  "message": "Message not found",
  "code": "MESSAGE_NOT_FOUND"
}

// User not authorized
{
  "success": false,
  "message": "You are not authorized to react to this message",
  "code": "UNAUTHORIZED"
}

// Invalid emoji
{
  "success": false,
  "message": "Invalid emoji format",
  "code": "INVALID_EMOJI"
}

// Message deleted
{
  "success": false,
  "message": "Cannot react to deleted message",
  "code": "MESSAGE_DELETED"
}
```

---

## 11. Testing Checklist

### Backend Developer Testing:
- [ ] User can add reaction to own message
- [ ] User can add reaction to received message
- [ ] User can change reaction (UPSERT works)
- [ ] User can remove reaction
- [ ] Multiple users can react to same message
- [ ] WebSocket events sent to both participants
- [ ] Reactions persist after app restart
- [ ] Reactions included in message history API
- [ ] Proper error handling for invalid cases
- [ ] Database constraints enforced (one reaction per user)
- [ ] Performance acceptable with 100+ reactions on single message

---

## 12. Frontend Integration Notes

### 12.1 Client-Side Flow
```dart
// Add reaction
await chatRepository.addReaction(messageId: "msg-123", emoji: "❤️");

// Remove reaction
await chatRepository.removeReaction(messageId: "msg-123");

// Listen for real-time updates
socketService.on('reaction:added', (data) {
  // Update UI immediately
  updateMessageReaction(data);
});

socketService.on('reaction:removed', (data) {
  // Remove reaction from UI
  removeMessageReaction(data);
});
```

### 12.2 UI Display
- Show reaction count below message bubble
- Tapping reaction count opens bottom sheet with all reactions
- Long-press message shows reaction picker (6 quick emojis)
- User's own reaction highlighted in different color

---

## 13. Summary for Backend Developer

**What you need to implement:**

1. **Database:**
   - Create `message_reactions` table with UNIQUE constraint
   - Add `reactions_json` column to `messages` table (optional)

2. **REST API:**
   - `POST /api/messages/:messageId/reactions` (add/update)
   - `DELETE /api/messages/:messageId/reactions` (remove)
   - `GET /api/messages/:messageId/reactions` (list all)

3. **WebSocket Events:**
   - Emit `reaction:added` when reaction added/updated
   - Emit `reaction:removed` when reaction removed
   - Send events to BOTH sender and receiver

4. **Message Response:**
   - Include `reactionsJson` array in all message objects
   - Include user details (firstName, lastName) in reactions

5. **Business Logic:**
   - Enforce one reaction per user per message (UPSERT)
   - Validate user is participant in conversation
   - Handle edge cases (deleted messages, invalid emojis)

**Priority:** High - This is a core messaging feature

**Timeline:** Please provide estimate for implementation

---

## Questions?
If you need clarification on any part of this spec, please ask. This document covers the complete WhatsApp-style reaction flow.
