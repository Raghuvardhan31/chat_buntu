# Backend Call Signaling Contract — ChatAway+

## Overview

The Flutter client has been fully built to support WhatsApp-style voice/video calling using **Agora RTC** for media and **Socket.IO** for signaling. The backend needs to implement the signaling layer described below.

## Architecture

```
Caller App                    Backend (Socket.IO)              Callee App
─────────                     ──────────────────              ──────────
1. emit 'call-initiate'  ──→  Receives call request
                               │
                               ├─ Is callee online?
                               │   NO → emit 'call-unavailable' to caller
                               │         + Send FCM push to callee (high priority)
                               │
                               │   YES → emit 'call-incoming' to callee
                               │         emit 'call-ringing' to caller
                               │                                        ←── Callee sees IncomingCallPage
                               │
2. Waiting...                  │  (45s timeout on client side)
                               │
                               ├─ Callee emits 'call-accept'  ──→  emit 'call-accepted' to caller
                               │                                        Caller joins Agora channel
                               │                                        Callee joins Agora channel
                               │
                               ├─ Callee emits 'call-reject'  ──→  emit 'call-rejected' to caller
                               │
                               ├─ Callee emits 'call-busy'    ──→  emit 'call-rejected' to caller
                               │                                    (callee already in another call)
                               │
                               ├─ 45s timeout (no response)   ──→  emit 'call-missed' to caller
                               │                                    emit 'call-missed' to callee
                               │
3. Either party emits          │
   'call-end'             ──→  emit 'call-ended' to the other party
```

---

## Socket Events — Client → Server (Emit)

### 1. `call-initiate`
Caller initiates a call to another user.

```json
{
  "callId": "call_1707834567890",
  "calleeId": "uuid-of-callee",
  "callType": "voice",          // "voice" or "video"
  "channelName": "ch_uuid-of-callee_call_1707834567890"
}
```

**Backend should:**
1. Check if callee is connected to Socket.IO
2. If YES → emit `call-incoming` to callee + emit `call-ringing` to caller
3. If NO → emit `call-unavailable` to caller + send FCM push notification to callee
4. Start a 45-second server-side timeout. If no `call-accept`/`call-reject` received → emit `call-missed` to both

### 2. `call-accept`
Callee accepts the incoming call.

```json
{
  "callId": "call_1707834567890",
  "callerId": "uuid-of-caller"
}
```

**Backend should:**
1. Cancel the 45s timeout
2. Emit `call-accepted` to the caller (with callId)
3. Both parties will then join the Agora channel independently

### 3. `call-reject`
Callee rejects the incoming call.

```json
{
  "callId": "call_1707834567890",
  "callerId": "uuid-of-caller"
}
```

**Backend should:**
1. Cancel the 45s timeout
2. Emit `call-rejected` to the caller (with callId)

### 4. `call-end`
Either party ends an active call (or caller cancels before answer).

```json
{
  "callId": "call_1707834567890",
  "otherUserId": "uuid-of-other-party"
}
```

**Backend should:**
1. Emit `call-ended` to the other party (with callId)
2. Cancel any pending timeouts for this callId

### 5. `call-busy`
Callee is already in another call.

```json
{
  "callId": "call_1707834567890",
  "callerId": "uuid-of-caller"
}
```

**Backend should:**
1. Cancel the 45s timeout
2. Emit `call-rejected` to the caller (with callId) — same as reject from caller's perspective

---

## Socket Events — Server → Client (Listen)

### 1. `call-incoming`
Sent to the callee when someone is calling them.

```json
{
  "callId": "call_1707834567890",
  "callerId": "uuid-of-caller",
  "callerName": "John Doe",
  "callerProfilePic": "https://example.com/pic.jpg",  // nullable
  "callType": "voice",          // "voice" or "video"
  "channelName": "ch_uuid-of-callee_call_1707834567890"
}
```

### 2. `call-ringing`
Sent to the caller to confirm the callee's phone is ringing.

```json
{
  "callId": "call_1707834567890"
}
```

### 3. `call-accepted`
Sent to the caller when callee accepts.

```json
{
  "callId": "call_1707834567890"
}
```

### 4. `call-rejected`
Sent to the caller when callee rejects or is busy.

```json
{
  "callId": "call_1707834567890"
}
```

### 5. `call-ended`
Sent to either party when the other ends the call.

```json
{
  "callId": "call_1707834567890"
}
```

### 6. `call-unavailable`
Sent to the caller when the callee is offline and FCM push was sent.

```json
{
  "callId": "call_1707834567890"
}
```

### 7. `call-missed`
Sent to both parties when the 45s ring timeout expires.

```json
{
  "callId": "call_1707834567890"
}
```

### 8. `call-error`
Sent to the caller when something goes wrong server-side.

```json
{
  "callId": "call_1707834567890",
  "message": "Failed to initiate call"
}
```

---

## FCM Push Notification — For App Closed / Background Scenario

When the callee is NOT connected to Socket.IO but has an FCM token, send a **high-priority data-only FCM push**:

```json
{
  "to": "<callee_fcm_token>",
  "priority": "high",
  "data": {
    "type": "incoming_call",
    "callId": "call_1707834567890",
    "callerId": "uuid-of-caller",
    "callerName": "John Doe",
    "callerProfilePic": "https://example.com/pic.jpg",
    "callType": "voice",
    "channelName": "ch_uuid-of-callee_call_1707834567890"
  }
}
```

**Important:**
- Must be `data`-only (not `notification`) so the app can handle it in background
- Must be `priority: "high"` to wake the device
- The Flutter client will handle showing the incoming call UI from the FCM handler

---

## Scenarios Summary

| Scenario | What Happens |
|----------|-------------|
| **Callee online, app open** | Socket `call-incoming` → IncomingCallPage shown |
| **Callee online, app in background** | Socket `call-incoming` → app receives via existing socket |
| **Callee offline, has FCM token** | FCM high-priority push → app wakes → IncomingCallPage shown |
| **Callee offline, no FCM token** | `call-unavailable` sent to caller immediately |
| **Callee doesn't answer (45s)** | `call-missed` sent to both parties |
| **Callee rejects** | `call-rejected` sent to caller |
| **Callee is busy (in another call)** | `call-busy` → treated as `call-rejected` for caller |
| **Caller cancels before answer** | `call-end` → `call-ended` sent to callee |
| **Either party ends active call** | `call-end` → `call-ended` sent to other party |

---

## Agora Channel Naming Convention

Channel names are generated client-side:
```
ch_{calleeUserId}_{callId}
```
Example: `ch_abc123_call_1707834567890`

Both parties join the same Agora channel after the call is accepted. The backend does NOT need to manage Agora channels — it only handles signaling.

---

## Server-Side Timeout

The server should maintain a 45-second timeout per `callId`:
1. Start when `call-initiate` is received
2. Cancel when `call-accept`, `call-reject`, `call-busy`, or `call-end` is received
3. If timeout fires → emit `call-missed` to both caller and callee
