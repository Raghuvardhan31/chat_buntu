# Call Events - Frontend Integration Guide

## Overview

Complete guide for integrating voice and video calling features using Socket.IO WebSocket events. This system supports real-time call signaling, call history, and statistics with automatic database persistence.

---

## 🔌 Socket.IO Connection Setup

### 1. Initialize Connection

```javascript
import io from "socket.io-client";

const socket = io("https://your-server-url.com", {
  auth: {
    token: "your-jwt-token", // JWT token for authentication
  },
  transports: ["websocket", "polling"],
  reconnection: true,
  reconnectionDelay: 1000,
  reconnectionAttempts: 5,
});

// Connection status
socket.on("connect", () => {
  console.log("✅ Connected to server:", socket.id);
});

socket.on("disconnect", (reason) => {
  console.log("❌ Disconnected:", reason);
});

socket.on("connect_error", (error) => {
  console.error("Connection error:", error);
});
```

---

## 📞 Call Events (Client → Server)

### 1. Initiate Call - `call-initiate`

**When to use:** User initiates a voice or video call

**Emit:**

```javascript
socket.emit("call-initiate", {
  callId: "unique-call-id", // Generate UUID
  calleeId: "receiver-user-id", // User being called
  callType: "voice", // 'voice' or 'video'
  channelName: "agora-channel-name", // Agora channel name
});
```

**Success Responses:**

```javascript
// Callee is online - phone ringing
socket.on("call-ringing", (data) => {
  console.log("📞 Phone is ringing:", data);
  // { callId: 'unique-call-id' }
  // Show "Calling..." UI
});

// Callee accepted the call
socket.on("call-accepted", (data) => {
  console.log("✅ Call accepted:", data);
  // { callId: 'unique-call-id' }
  // Join Agora channel and start call
});
```

**Error/Rejection Responses:**

```javascript
// Callee rejected or is busy
socket.on("call-rejected", (data) => {
  console.log("❌ Call rejected:", data);
  // { callId: 'unique-call-id' }
  // Show "User declined" or "User is busy"
});

// Callee is unavailable (offline, no app)
socket.on("call-unavailable", (data) => {
  console.log("❌ Call unavailable:", data);
  // { callId: 'unique-call-id' }
  // Show "User is unavailable"
});

// Call timed out (45 seconds no answer)
socket.on("call-missed", (data) => {
  console.log("❌ Call missed:", data);
  // { callId: 'unique-call-id' }
  // Show "User didn't answer"
});

// General error
socket.on("call-error", (error) => {
  console.error("❌ Call error:", error);
  // { callId: 'unique-call-id', message: 'Error description' }
});
```

---

### 2. Accept Call - `call-accept`

**When to use:** User accepts an incoming call

**Emit:**

```javascript
socket.emit("call-accept", {
  callId: "unique-call-id", // From call-incoming event
  callerId: "caller-user-id", // From call-incoming event
});
```

**Response:**
Server will emit `call-accepted` to the caller

---

### 3. Reject Call - `call-reject`

**When to use:** User rejects an incoming call

**Emit:**

```javascript
socket.emit("call-reject", {
  callId: "unique-call-id", // From call-incoming event
  callerId: "caller-user-id", // From call-incoming event
});
```

**Response:**
Server will emit `call-rejected` to the caller

---

### 4. Busy Signal - `call-busy`

**When to use:** User is already in another call

**Emit:**

```javascript
socket.emit("call-busy", {
  callId: "unique-call-id", // From call-incoming event
  callerId: "caller-user-id", // From call-incoming event
});
```

**Response:**
Server will emit `call-rejected` to the caller (treated as rejection)

---

### 5. End Call - `call-end`

**When to use:** Either party ends an active call

**Emit:**

```javascript
socket.emit("call-end", {
  callId: "unique-call-id",
  otherUserId: "other-user-id", // The other person in the call
});
```

**Response:**
Server will emit `call-ended` to the other party

---

## 📥 Call Events (Server → Client)

### 1. Incoming Call - `call-incoming`

**When:** Someone is calling you

**Listen:**

```javascript
socket.on("call-incoming", (data) => {
  console.log("📞 Incoming call:", data);

  // data = {
  //   callId: 'unique-call-id',
  //   callerId: 'caller-user-id',
  //   callerName: 'John Doe',
  //   callerProfilePic: 'https://...',
  //   callType: 'voice',  // or 'video'
  //   channelName: 'agora-channel-name'
  // }

  // Show incoming call screen
  showIncomingCallUI({
    callerName: data.callerName,
    callerPhoto: data.callerProfilePic,
    isVideo: data.callType === "video",
    onAccept: () => {
      socket.emit("call-accept", {
        callId: data.callId,
        callerId: data.callerId,
      });
      joinAgoraChannel(data.channelName);
    },
    onReject: () => {
      socket.emit("call-reject", {
        callId: data.callId,
        callerId: data.callerId,
      });
    },
  });
});
```

---

### 2. Call Accepted - `call-accepted`

**When:** Your call was accepted

**Listen:**

```javascript
socket.on("call-accepted", (data) => {
  console.log("✅ Call accepted:", data);
  // { callId: 'unique-call-id' }

  // Join Agora channel and start call
  joinAgoraChannel(channelName);
  showCallActiveUI();
});
```

---

### 3. Call Rejected - `call-rejected`

**When:** Your call was rejected or user is busy

**Listen:**

```javascript
socket.on("call-rejected", (data) => {
  console.log("❌ Call rejected:", data);
  // { callId: 'unique-call-id' }

  // Show "User declined" or "User is busy"
  showCallRejectedUI();
  cleanupCall();
});
```

---

### 4. Call Ended - `call-ended`

**When:** The other party ended the call

**Listen:**

```javascript
socket.on("call-ended", (data) => {
  console.log("📞 Call ended:", data);
  // { callId: 'unique-call-id' }

  // Leave Agora channel
  leaveAgoraChannel();
  showCallEndedUI();
  cleanupCall();
});
```

---

### 5. Call Missed - `call-missed`

**When:** Call timed out (45 seconds, no answer)

**Listen:**

```javascript
socket.on("call-missed", (data) => {
  console.log("❌ Call missed:", data);
  // { callId: 'unique-call-id' }

  // For caller: Show "No answer"
  // For callee: Dismiss incoming call screen
  showCallMissedUI();
  cleanupCall();
});
```

---

### 6. Call Unavailable - `call-unavailable`

**When:** User is completely unreachable (offline, no push tokens)

**Listen:**

```javascript
socket.on("call-unavailable", (data) => {
  console.log("❌ Call unavailable:", data);
  // { callId: 'unique-call-id' }

  showCallUnavailableUI();
  cleanupCall();
});
```

---

### 7. Call Ringing - `call-ringing`

**When:** Your call is ringing on the other end

**Listen:**

```javascript
socket.on("call-ringing", (data) => {
  console.log("📞 Ringing...:", data);
  // { callId: 'unique-call-id' }

  // Update UI to show "Ringing..."
  showRingingUI();
});
```

---

### 8. Call Error - `call-error`

**When:** Any error occurs

**Listen:**

```javascript
socket.on("call-error", (error) => {
  console.error("❌ Call error:", error);
  // { callId: 'unique-call-id', message: 'Error description' }

  showErrorUI(error.message);
  cleanupCall();
});
```

---

## 📊 Call History & Statistics Events

### 1. Get Call History - `get-call-history`

**Emit:**

```javascript
socket.emit("get-call-history", {
  limit: 50, // Optional, default: 50
  offset: 0, // Optional, default: 0
  callType: "voice", // Optional: 'voice' or 'video'
  status: "missed", // Optional: filter by status
});
```

**Response:**

```javascript
socket.on("call-history-response", (response) => {
  console.log("📞 Call history:", response);

  // response = {
  //   success: true,
  //   data: [
  //     {
  //       id: 'uuid',
  //       callId: 'call_123',
  //       callType: 'voice',
  //       status: 'ended',
  //       direction: 'outgoing',  // or 'incoming'
  //       otherUser: {
  //         id: 'uuid',
  //         firstName: 'John',
  //         lastName: 'Doe',
  //         chat_picture: 'https://...',
  //         mobileNo: '+1234567890'
  //       },
  //       startedAt: '2026-02-14T10:30:00Z',
  //       answeredAt: '2026-02-14T10:30:05Z',
  //       endedAt: '2026-02-14T10:35:20Z',
  //       duration: 315,  // seconds
  //       createdAt: '2026-02-14T10:30:00Z'
  //     }
  //   ],
  //   total: 15
  // }

  displayCallHistory(response.data);
});

socket.on("call-history-error", (error) => {
  console.error("Error:", error.message);
});
```

---

### 2. Get Missed Calls Count - `get-missed-calls-count`

**Emit:**

```javascript
socket.emit("get-missed-calls-count");
```

**Response:**

```javascript
socket.on("missed-calls-count-response", (response) => {
  console.log("📞 Missed calls:", response);

  // response = {
  //   success: true,
  //   count: 5
  // }

  updateMissedCallsBadge(response.count);
});

socket.on("missed-calls-count-error", (error) => {
  console.error("Error:", error.message);
});
```

---

### 3. Get Call Statistics - `get-call-statistics`

**Emit:**

```javascript
socket.emit("get-call-statistics", {
  startDate: "2026-02-01", // Optional
  endDate: "2026-02-14", // Optional
});
```

**Response:**

```javascript
socket.on("call-statistics-response", (response) => {
  console.log("📊 Statistics:", response);

  // response = {
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

  displayStatistics(response.data);
});

socket.on("call-statistics-error", (error) => {
  console.error("Error:", error.message);
});
```

---

## 🔄 Complete Call Flow Examples

### Example 1: Outgoing Call Flow

```javascript
// Step 1: Generate call ID and initiate
const callId = generateUUID();
const channelName = `channel_${callId}`;

socket.emit("call-initiate", {
  callId: callId,
  calleeId: receiverUserId,
  callType: "voice",
  channelName: channelName,
});

// Step 2: Wait for response
socket.on("call-ringing", (data) => {
  // Show "Calling..." UI
  updateCallUI("ringing");
});

socket.on("call-accepted", (data) => {
  // Join Agora channel
  joinAgoraChannel(channelName);
  updateCallUI("active");
});

socket.on("call-rejected", (data) => {
  // Show rejected message
  showMessage("User declined the call");
  cleanupCall();
});

socket.on("call-missed", (data) => {
  // Show missed message
  showMessage("No answer");
  cleanupCall();
});

// Step 3: End call when done
function endCall() {
  socket.emit("call-end", {
    callId: callId,
    otherUserId: receiverUserId,
  });
  leaveAgoraChannel();
  cleanupCall();
}
```

---

### Example 2: Incoming Call Flow

```javascript
// Listen for incoming calls
socket.on("call-incoming", (data) => {
  const {
    callId,
    callerId,
    callerName,
    callerProfilePic,
    callType,
    channelName,
  } = data;

  // Show incoming call screen
  showIncomingCallScreen({
    callerName: callerName,
    callerPhoto: callerProfilePic,
    isVideo: callType === "video",

    onAccept: () => {
      // Accept the call
      socket.emit("call-accept", {
        callId: callId,
        callerId: callerId,
      });

      // Join Agora channel
      joinAgoraChannel(channelName);
      showCallActiveUI();
    },

    onReject: () => {
      // Reject the call
      socket.emit("call-reject", {
        callId: callId,
        callerId: callerId,
      });
      dismissIncomingCallScreen();
    },
  });
});

// Handle call ended by caller
socket.on("call-ended", (data) => {
  leaveAgoraChannel();
  showMessage("Call ended");
  cleanupCall();
});
```

---

### Example 3: Load Call History on Screen Open

```javascript
function loadCallsTab() {
  // Get call history
  socket.emit("get-call-history", {
    limit: 20,
    offset: 0,
  });

  socket.on("call-history-response", (response) => {
    if (response.success) {
      renderCallList(response.data);
    }
  });

  // Get missed calls badge
  socket.emit("get-missed-calls-count");

  socket.on("missed-calls-count-response", (response) => {
    if (response.success) {
      updateBadge(response.count);
    }
  });
}
```

---

## 🎯 Call Status Types

| Status        | Description          | Example                  |
| ------------- | -------------------- | ------------------------ |
| `initiated`   | Call just started    | User pressed call button |
| `ringing`     | Phone is ringing     | Waiting for answer       |
| `accepted`    | Call was answered    | In active call           |
| `rejected`    | User declined        | User pressed reject      |
| `missed`      | No answer (timeout)  | 45 seconds passed        |
| `ended`       | Call completed       | Either party ended call  |
| `busy`        | User in another call | User already on call     |
| `unavailable` | User unreachable     | Offline, no push tokens  |

---

## ⚙️ Best Practices

### 1. **Generate Unique Call IDs**

```javascript
// Use UUID v4
import { v4 as uuidv4 } from "uuid";
const callId = uuidv4();
```

### 2. **Cleanup on Call End**

```javascript
function cleanupCall() {
  // Leave Agora channel
  agoraEngine.leaveChannel();

  // Remove event listeners
  socket.off("call-accepted");
  socket.off("call-rejected");
  socket.off("call-ended");

  // Clear UI state
  resetCallUI();

  // Clear local variables
  currentCallId = null;
  currentChannelName = null;
}
```

### 3. **Handle App Background/Foreground**

```javascript
// When app goes to background during call
onAppBackground(() => {
  // Keep socket connected
  // Keep Agora connection active
  // Show persistent notification
});

// When app comes to foreground
onAppForeground(() => {
  // Resume call UI
  // Refresh call state
});
```

### 4. **Handle Network Reconnection**

```javascript
socket.on("reconnect", () => {
  console.log("🔄 Reconnected to server");

  // If there was an active call, check its status
  if (currentCallId) {
    // You may need to implement a status check endpoint
    checkCallStatus(currentCallId);
  }
});
```

### 5. **Permission Handling**

```javascript
async function initiateCall(userId, callType) {
  // Request permissions first
  const micPermission = await requestMicrophonePermission();

  if (callType === "video") {
    const cameraPermission = await requestCameraPermission();
    if (!cameraPermission) {
      showError("Camera permission required");
      return;
    }
  }

  if (!micPermission) {
    showError("Microphone permission required");
    return;
  }

  // Then initiate call
  socket.emit("call-initiate", {
    callId: generateUUID(),
    calleeId: userId,
    callType: callType,
    channelName: generateChannelName(),
  });
}
```

---

## 🐛 Error Handling

### Common Error Scenarios

```javascript
// 1. Authentication Error
socket.on("connect_error", (error) => {
  if (error.message === "Authentication error") {
    // Refresh JWT token
    refreshAuthToken().then((newToken) => {
      socket.auth.token = newToken;
      socket.connect();
    });
  }
});

// 2. Call Already Active
socket.on("call-error", (error) => {
  if (error.message.includes("already in call")) {
    showError("You are already in an active call");
  }
});

// 3. User Not Found
socket.on("call-error", (error) => {
  if (error.message.includes("User not found")) {
    showError("User not available");
  }
});

// 4. Network Issues
socket.on("disconnect", (reason) => {
  if (reason === "transport close" || reason === "ping timeout") {
    showNetworkError();
    if (currentCallId) {
      // End call gracefully
      cleanupCall();
    }
  }
});
```

---

## 📱 Platform-Specific Notes

### Flutter/Dart Example

```dart
import 'package:socket_io_client/socket_io_client.dart' as IO;

class CallService {
  late IO.Socket socket;

  void initializeSocket(String token) {
    socket = IO.io('https://your-server-url.com', <String, dynamic>{
      'transports': ['websocket'],
      'auth': {'token': token}
    });

    socket.on('connect', (_) {
      print('✅ Connected: ${socket.id}');
    });

    socket.on('call-incoming', (data) {
      showIncomingCallScreen(
        callId: data['callId'],
        callerId: data['callerId'],
        callerName: data['callerName'],
        callerPhoto: data['callerProfilePic'],
        callType: data['callType'],
        channelName: data['channelName']
      );
    });

    socket.on('call-accepted', (data) {
      joinAgoraChannel(channelName);
    });
  }

  void initiateCall({
    required String calleeId,
    required String callType,
    required String channelName
  }) {
    final callId = Uuid().v4();

    socket.emit('call-initiate', {
      'callId': callId,
      'calleeId': calleeId,
      'callType': callType,
      'channelName': channelName
    });
  }

  void endCall(String callId, String otherUserId) {
    socket.emit('call-end', {
      'callId': callId,
      'otherUserId': otherUserId
    });
  }
}
```

### React Native Example

```javascript
import io from "socket.io-client";

class CallManager {
  constructor(token) {
    this.socket = io("https://your-server-url.com", {
      auth: { token },
      transports: ["websocket"],
    });

    this.setupListeners();
  }

  setupListeners() {
    this.socket.on("call-incoming", this.handleIncomingCall);
    this.socket.on("call-accepted", this.handleCallAccepted);
    this.socket.on("call-rejected", this.handleCallRejected);
    this.socket.on("call-ended", this.handleCallEnded);
  }

  initiateCall(calleeId, callType) {
    const callId = uuid.v4();
    const channelName = `channel_${callId}`;

    this.socket.emit("call-initiate", {
      callId,
      calleeId,
      callType,
      channelName,
    });

    return { callId, channelName };
  }

  handleIncomingCall = (data) => {
    // Show incoming call notification
    InCallManager.displayIncomingCall(
      data.callId,
      data.callerName,
      data.callerPhoto,
      data.callType === "video",
    );
  };
}
```

---

## 🔒 Security Notes

1. **Always authenticate with JWT token**
2. **Validate calleeId exists before initiating**
3. **Don't expose sensitive user data in call events**
4. **Implement rate limiting on frontend** (prevent call spam)
5. **Verify Agora tokens** server-side before joining channel

---

## 🎬 Testing Checklist

- [ ] Outgoing voice call - accept scenario
- [ ] Outgoing voice call - reject scenario
- [ ] Outgoing voice call - timeout scenario
- [ ] Outgoing video call - accept scenario
- [ ] Incoming call - accept scenario
- [ ] Incoming call - reject scenario
- [ ] Active call - caller ends
- [ ] Active call - callee ends
- [ ] Call while busy (both caller and callee)
- [ ] Call to offline user
- [ ] Network disconnect during call
- [ ] App background/foreground during call
- [ ] Load call history
- [ ] Load missed calls count
- [ ] Load call statistics
- [ ] Multiple rapid calls (spam prevention)

---

## 📞 Support

For issues or questions:

- Check server logs for call events
- Verify JWT token is valid
- Ensure Socket.IO connection is established
- Test Agora channel connection separately
- Check network connectivity

---

**Version:** 1.0.0
**Last Updated:** February 14, 2026
**Server:** ChatAwayPlus API
