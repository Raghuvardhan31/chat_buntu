# Call Logging System - Implementation Guide

## Overview

A complete call logging system has been added to track all voice and video calls in your application. The system automatically logs every call event and provides REST APIs to retrieve call history, statistics, and manage call logs.

---

## 🗄️ Database Schema

### Table: `call_logs`

| Column         | Type    | Description                                                                              |
| -------------- | ------- | ---------------------------------------------------------------------------------------- |
| `id`           | UUID    | Primary key                                                                              |
| `call_id`      | STRING  | Unique identifier for the call session                                                   |
| `caller_id`    | UUID    | User who initiated the call (FK to users)                                                |
| `callee_id`    | UUID    | User who received the call (FK to users)                                                 |
| `call_type`    | ENUM    | `voice` or `video`                                                                       |
| `status`       | ENUM    | `initiated`, `ringing`, `accepted`, `rejected`, `missed`, `ended`, `busy`, `unavailable` |
| `channel_name` | STRING  | Agora channel name                                                                       |
| `started_at`   | DATE    | When call was initiated                                                                  |
| `answered_at`  | DATE    | When call was answered (nullable)                                                        |
| `ended_at`     | DATE    | When call ended (nullable)                                                               |
| `duration`     | INTEGER | Call duration in seconds (nullable)                                                      |
| `ended_by`     | UUID    | User who ended the call (nullable, FK to users)                                          |
| `created_at`   | DATE    | Record creation timestamp                                                                |
| `updated_at`   | DATE    | Record update timestamp                                                                  |

### Indexes

- `idx_call_logs_caller_id` on `caller_id`
- `idx_call_logs_callee_id` on `callee_id`
- `idx_call_logs_call_id` on `call_id` (unique)
- `idx_call_logs_status` on `status`
- `idx_call_logs_started_at` on `started_at`

---

## 📡 WebSocket Integration

Call logs are automatically created and updated during WebSocket call events:

### Event Flow

1. **`call-initiate`**
   - Creates call log with status `initiated`
   - Updates to `ringing` when callee receives notification
   - Updates to `unavailable` if callee has no FCM tokens

2. **`call-accept`**
   - Updates status to `accepted`
   - Records `answered_at` timestamp

3. **`call-reject`**
   - Updates status to `rejected`
   - Records `ended_at` timestamp

4. **`call-busy`**
   - Updates status to `busy`
   - Records `ended_at` timestamp

5. **`call-end`**
   - Updates status to `ended`
   - Records `ended_at` timestamp
   - Calculates `duration` (only if call was answered)
   - Records `ended_by` user

6. **Timeout (45 seconds)**
   - Updates status to `missed`
   - Records `ended_at` timestamp

---

## 🔌 REST API Endpoints

All endpoints require authentication via the `authenticate` middleware.

### 1. Get Call History

```http
GET /api/call-logs/history/:userId
```

**Query Parameters:**

- `limit` (optional, default: 50) - Number of records to return
- `offset` (optional, default: 0) - Pagination offset
- `callType` (optional) - Filter by `voice` or `video`
- `status` (optional) - Filter by status

**Response:**

```json
{
  "success": true,
  "data": [
    {
      "id": "uuid",
      "callId": "call_123",
      "callType": "video",
      "status": "ended",
      "direction": "outgoing",
      "otherUser": {
        "id": "uuid",
        "name": "John Doe",
        "profilePicture": "url",
        "username": "johndoe"
      },
      "startedAt": "2026-02-14T10:30:00Z",
      "answeredAt": "2026-02-14T10:30:05Z",
      "endedAt": "2026-02-14T10:35:20Z",
      "duration": 315,
      "channelName": "channel_abc"
    }
  ],
  "pagination": {
    "limit": 50,
    "offset": 0,
    "total": 127
  }
}
```

### 2. Get Missed Calls Count

```http
GET /api/call-logs/missed-count/:userId
```

**Response:**

```json
{
  "success": true,
  "data": {
    "missedCallsCount": 5
  }
}
```

### 3. Get Missed Calls List

```http
GET /api/call-logs/missed/:userId
```

**Query Parameters:**

- `limit` (optional, default: 50)
- `offset` (optional, default: 0)

**Response:**

```json
{
  "success": true,
  "data": [
    {
      "id": "uuid",
      "callId": "call_456",
      "callType": "voice",
      "status": "missed",
      "caller": {
        "id": "uuid",
        "name": "Jane Smith",
        "profilePicture": "url",
        "username": "janesmith"
      },
      "startedAt": "2026-02-14T09:15:00Z",
      "channelName": "channel_xyz"
    }
  ],
  "pagination": {
    "limit": 50,
    "offset": 0,
    "total": 5
  }
}
```

### 4. Get Call Details

```http
GET /api/call-logs/details/:callId
```

**Response:**

```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "callId": "call_123",
    "callType": "video",
    "status": "ended",
    "caller": {
      "id": "uuid",
      "name": "John Doe",
      "profilePicture": "url",
      "username": "johndoe"
    },
    "callee": {
      "id": "uuid",
      "name": "Jane Smith",
      "profilePicture": "url",
      "username": "janesmith"
    },
    "ender": {
      "id": "uuid",
      "name": "John Doe"
    },
    "startedAt": "2026-02-14T10:30:00Z",
    "answeredAt": "2026-02-14T10:30:05Z",
    "endedAt": "2026-02-14T10:35:20Z",
    "duration": 315,
    "channelName": "channel_abc"
  }
}
```

### 5. Get Call Statistics

```http
GET /api/call-logs/statistics/:userId
```

**Query Parameters:**

- `startDate` (optional) - Start date for date range filter
- `endDate` (optional) - End date for date range filter

**Response:**

```json
{
  "success": true,
  "data": {
    "totalCalls": 127,
    "outgoingCalls": 65,
    "incomingCalls": 62,
    "callsByStatus": {
      "answered": 95,
      "missed": 18,
      "rejected": 14
    },
    "callsByType": {
      "voice": 72,
      "video": 55
    },
    "duration": {
      "total": 45678,
      "average": 481,
      "totalHours": "12.69"
    }
  }
}
```

### 6. Delete Call History

```http
DELETE /api/call-logs/:userId
```

**Body:**

```json
{
  "callId": "call_123" // Delete specific call
}
```

OR

```json
{
  "deleteAll": true // Delete all call history
}
```

**Response:**

```json
{
  "success": true,
  "message": "Call log deleted successfully"
}
```

---

## � WebSocket Events for Data Retrieval

In addition to REST APIs, you can retrieve call log data via WebSocket events for real-time updates.

### 1. Get Call History

**Client Emits:**

```javascript
socket.emit("get-call-history", {
  limit: 50, // optional, default: 50
  offset: 0, // optional, default: 0
  callType: "voice", // optional: 'voice' or 'video'
  status: "missed", // optional: filter by status
});
```

**Server Responds:**

```javascript
socket.on("call-history-response", (response) => {
  console.log(response);
  // {
  //   success: true,
  //   data: [
  //     {
  //       id: "uuid",
  //       callId: "call_123",
  //       callType: "voice",
  //       status: "missed",
  //       direction: "incoming",
  //       otherUser: {
  //         id: "uuid",
  //         firstName: "John",
  //         lastName: "Doe",
  //         chat_picture: "url",
  //         mobileNo: "+1234567890"
  //       },
  //       startedAt: "2026-02-14T10:30:00Z",
  //       answeredAt: null,
  //       endedAt: "2026-02-14T10:30:45Z",
  //       duration: null,
  //       createdAt: "2026-02-14T10:30:00Z"
  //     }
  //   ],
  //   total: 15
  // }
});

socket.on("call-history-error", (error) => {
  console.error(error.message);
});
```

### 2. Get Missed Calls Count

**Client Emits:**

```javascript
socket.emit("get-missed-calls-count");
```

**Server Responds:**

```javascript
socket.on("missed-calls-count-response", (response) => {
  console.log(response);
  // {
  //   success: true,
  //   count: 5
  // }
});

socket.on("missed-calls-count-error", (error) => {
  console.error(error.message);
});
```

### 3. Get Call Statistics

**Client Emits:**

```javascript
socket.emit("get-call-statistics", {
  startDate: "2026-02-01", // optional
  endDate: "2026-02-14", // optional
});
```

**Server Responds:**

```javascript
socket.on("call-statistics-response", (response) => {
  console.log(response);
  // {
  //   success: true,
  //   data: {
  //     totalCalls: 127,
  //     voiceCalls: 72,
  //     videoCalls: 55,
  //     incomingCalls: 62,
  //     outgoingCalls: 65,
  //     missedCalls: 18,
  //     answeredCalls: 95,
  //     rejectedCalls: 14,
  //     totalDuration: 45678,      // seconds
  //     averageDuration: 481       // seconds
  //   }
  // }
});

socket.on("call-statistics-error", (error) => {
  console.error(error.message);
});
```

### Complete WebSocket Integration Example

```javascript
// Initialize Socket.IO connection
const socket = io("http://192.168.1.19:3200", {
  auth: {
    token: "your-jwt-token",
  },
});

// Setup event listeners
socket.on("call-history-response", handleCallHistory);
socket.on("missed-calls-count-response", handleMissedCount);
socket.on("call-statistics-response", handleStatistics);

// Request data
function loadCallData() {
  // Get recent call history
  socket.emit("get-call-history", { limit: 20 });

  // Get missed calls badge count
  socket.emit("get-missed-calls-count");

  // Get this month's statistics
  const startOfMonth = new Date();
  startOfMonth.setDate(1);
  socket.emit("get-call-statistics", {
    startDate: startOfMonth.toISOString(),
  });
}

// Update UI when data arrives
function handleCallHistory(response) {
  if (response.success) {
    updateCallHistoryUI(response.data);
  }
}

function handleMissedCount(response) {
  if (response.success) {
    updateMissedCallsBadge(response.count);
  }
}

function handleStatistics(response) {
  if (response.success) {
    updateStatisticsUI(response.data);
  }
}
```

---

## �🚀 Running Migrations

To create the `call_logs` table in your database:

```bash
# Run migrations
npm run migrate

# Or if using npx
npx sequelize-cli db:migrate
```

To rollback the migration:

```bash
npx sequelize-cli db:migrate:undo
```

---

## 📊 Call Status Flow

```
initiated → ringing → accepted → ended
                   ↓
                rejected
                   ↓
                busy
                   ↓
                missed (timeout)
                   ↓
                unavailable (no FCM tokens)
```

---

## 💡 Usage Examples

### Frontend Integration

#### 1. Display Call History in UI

```javascript
async function fetchCallHistory(userId) {
  const response = await fetch(`/api/call-logs/history/${userId}?limit=20`, {
    headers: {
      Authorization: `Bearer ${token}`,
    },
  });
  const data = await response.json();
  // Display data.data in your call history UI
}
```

#### 2. Show Missed Calls Badge

```javascript
async function getMissedCallsBadge(userId) {
  const response = await fetch(`/api/call-logs/missed-count/${userId}`, {
    headers: {
      Authorization: `Bearer ${token}`,
    },
  });
  const data = await response.json();
  // Update badge with data.data.missedCallsCount
}
```

#### 3. Display Call Statistics Dashboard

```javascript
async function showCallStats(userId) {
  const response = await fetch(`/api/call-logs/statistics/${userId}`, {
    headers: {
      Authorization: `Bearer ${token}`,
    },
  });
  const stats = await response.json();
  // Create charts/graphs with stats.data
}
```

---

## 🔧 Files Modified/Created

### New Files

1. `src/db/models/call-log.model.ts` - Sequelize model
2. `src/db/migrations/20260214000000-create-call-logs.ts` - Database migration
3. `src/controllers/call-log.controller.ts` - REST API controller
4. `src/routes/call-log.routes.ts` - Route definitions

### Modified Files

1. `src/db/models/assosiateModel.ts` - Added CallLog associations
2. `src/controllers/chat.controller.ts` - Added call logging logic to WebSocket events
3. `src/index.ts` - Registered call-log routes

---

## 📝 Notes

- **Duration Calculation**: Duration is only calculated for calls that were answered (status: `accepted` or `ended`)
- **Timezone**: All timestamps are stored in UTC
- **Performance**: Indexes are added on frequently queried columns for optimal performance
- **Privacy**: Call logs can be deleted individually or in bulk by users
- **Error Handling**: Database errors don't interrupt call flow - calls continue even if logging fails

---

## 🎯 Features Implemented

✅ Automatic call log creation on call initiation
✅ Real-time status updates during call lifecycle
✅ Duration calculation for answered calls
✅ Separate incoming/outgoing call tracking
✅ Missed calls detection and logging
✅ Call history API with pagination
✅ Call statistics and analytics
✅ Filtering by call type (voice/video)
✅ Filtering by status
✅ Delete call history (individual or bulk)
✅ User associations with proper foreign keys
✅ Indexed for fast queries

---

## 🐛 Troubleshooting

**Issue**: Call logs not appearing in database
**Solution**: Ensure migrations have been run: `npm run migrate`

**Issue**: Duration is null for ended calls
**Solution**: Duration is only calculated if call was answered. Check if `answered_at` is set.

**Issue**: Getting 401 Unauthorized on API calls
**Solution**: All endpoints require authentication. Include valid JWT token in Authorization header.

---

## 📞 Support

For questions or issues with the call logging system, please refer to the main project documentation or contact the development team.
