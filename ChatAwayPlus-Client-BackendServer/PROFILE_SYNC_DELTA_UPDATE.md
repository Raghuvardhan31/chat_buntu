# Profile Sync - Delta Update Implementation

## ✅ Implementation Complete

Both **Option 1** (adding `updatedAt` to existing endpoints) and **Option 2** (delta sync endpoint) have been implemented.

---

## 📦 Option 1: `updatedAt` in Existing Endpoints

### Modified Endpoints

#### 1. **POST /api/users/check-contacts**

**Before:** Returns contacts without timestamp information
**After:** Now includes `updatedAt` timestamp for each contact

```json
{
  "success": true,
  "data": [
    {
      "contact_mobile_number": "+1234567890",
      "is_registered": true,
      "user_details": {
        "user_id": "uuid",
        "contact_name": "John Doe",
        "chat_picture": "/api/images/...",
        "chat_picture_version": "uuid",
        "updatedAt": "2026-01-29T10:30:00.000Z",  // ✅ NEW
        "recentStatus": { ... },
        "recentEmojiUpdate": { ... }
      }
    }
  ]
}
```

#### 2. **POST /api/users/refresh-users**

**Before:** Returns user details without timestamp
**After:** Now includes `updatedAt` timestamp

```json
{
  "success": true,
  "data": [
    {
      "id": "uuid",
      "mobileNo": "+1234567890",
      "name": "John Doe",
      "chat_picture": "/api/images/...",
      "chat_picture_version": "uuid",
      "updatedAt": "2026-01-29T10:30:00.000Z",  // ✅ NEW
      "metadata": { ... },
      "recentStatus": { ... },
      "recentEmojiUpdate": { ... }
    }
  ]
}
```

### Usage

Frontend can now:

1. Store each contact's `updatedAt` locally
2. On app launch, fetch all contacts
3. Compare `updatedAt` timestamps client-side
4. Update only contacts with newer timestamps

---

## 🚀 Option 2: Delta Sync Endpoint (NEW)

### Endpoint Details

```http
GET /api/users/contacts/updated-since?timestamp={ISO_8601_timestamp}
Authorization: Bearer {token}
```

### Request Example

```http
GET /api/users/contacts/updated-since?timestamp=2026-01-28T10:00:00.000Z
Authorization: Bearer eyJhbGciOiJIUzI1NiIs...
```

### Response Example

```json
{
  "success": true,
  "message": "Found 3 contact(s) updated since 2026-01-28T10:00:00.000Z",
  "data": [
    {
      "id": "uuid-1",
      "mobileNo": "+1234567890",
      "name": "John Doe",
      "chat_picture": "/api/images/stream/profile/...",
      "chat_picture_version": "uuid",
      "updatedAt": "2026-01-29T10:30:00.000Z",
      "metadata": { ... },
      "recentStatus": {
        "share_your_voice": "Hello world!",
        "createdAt": "2026-01-29T10:25:00.000Z"
      },
      "recentEmojiUpdate": {
        "emojis_update": "😊🎉",
        "emojis_caption": "Feeling great",
        "createdAt": "2026-01-29T09:00:00.000Z"
      }
    }
    // ... more updated contacts
  ],
  "metadata": {
    "sinceTimestamp": "2026-01-28T10:00:00.000Z",
    "resultCount": 3
  }
}
```

### Error Responses

**Missing timestamp:**

```json
{
  "success": false,
  "message": "timestamp query parameter is required (ISO 8601 format)"
}
```

**Invalid timestamp format:**

```json
{
  "success": false,
  "message": "Invalid timestamp format. Use ISO 8601 format (e.g., 2026-01-28T10:00:00.000Z)"
}
```

**Unauthorized:**

```json
{
  "success": false,
  "message": "Unauthorized"
}
```

---

## 🔧 Implementation Details

### Files Modified

| File                                                                     | Changes                                                                                                                                              |
| ------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| [src/services/user.service.ts](src/services/user.service.ts)             | • Added `updatedAt` to `checkRegisteredContacts`<br>• Added `updatedAt` to `getUserDetailsByIds`<br>• Created new `getContactsUpdatedSince` function |
| [src/controllers/user.controller.ts](src/controllers/user.controller.ts) | • Added `getUpdatedContactsSince` controller method<br>• Imported new service function                                                               |
| [src/routes/user.routes.ts](src/routes/user.routes.ts)                   | • Added route: `GET /contacts/updated-since`<br>• Protected with `authMiddleware`                                                                    |

### Database Queries

The `updatedAt` field comes from Sequelize's automatic timestamp tracking on the `users` table. No migration needed - the field already exists!

---

## 📱 Frontend Integration Guide

### Option 1: Client-Side Filtering (Simple)

```dart
// On app launch
Future<void> syncContacts() async {
  final response = await api.post('/api/users/refresh-users', {
    'userIds': allContactIds,
  });

  for (final contact in response.data) {
    final localUpdatedAt = await db.getContactUpdatedAt(contact.id);
    final remoteUpdatedAt = DateTime.parse(contact.updatedAt);

    if (remoteUpdatedAt.isAfter(localUpdatedAt)) {
      await db.updateContact(contact);
    }
  }
}
```

### Option 2: Server-Side Filtering (Efficient) ⭐ RECOMMENDED

```dart
// Store last sync timestamp
SharedPreferences prefs = await SharedPreferences.getInstance();
String? lastSync = prefs.getString('lastProfileSync');

if (lastSync != null) {
  // Delta sync - only fetch updated contacts
  final response = await api.get(
    '/api/users/contacts/updated-since',
    queryParameters: {'timestamp': lastSync},
  );

  // Update only changed contacts
  for (final contact in response.data) {
    await db.updateContact(contact);
  }
} else {
  // First launch - full sync
  await syncAllContacts();
}

// Store current timestamp for next sync
await prefs.setString('lastProfileSync', DateTime.now().toIso8601String());
```

---

## 🎯 Benefits

### Option 1 Benefits

- ✅ Works with existing endpoints
- ✅ No new endpoint to learn
- ✅ Flexible client-side filtering

### Option 2 Benefits

- ✅ **Reduced bandwidth** - only sends changed data
- ✅ **Faster sync** - no client-side filtering needed
- ✅ **Scalable** - efficient for 1000+ contacts
- ✅ **Lower battery usage** - less processing on device

---

## 🔒 Security

Both implementations:

- ✅ Require authentication via `authMiddleware`
- ✅ Only return contacts the user actually has (verified via `Contact` table)
- ✅ Cannot access other users' data

---

## 🧪 Testing

### Test Delta Sync Endpoint

```bash
# 1. Get auth token
curl -X POST http://192.168.31.165:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"mobileNo": "+1234567890", "password": "test123"}'

# 2. Test delta sync (use timestamp from 1 hour ago)
TIMESTAMP=$(date -u -d '1 hour ago' +"%Y-%m-%dT%H:%M:%S.000Z")
curl -X GET "http://192.168.31.165:3000/api/users/contacts/updated-since?timestamp=$TIMESTAMP" \
  -H "Authorization: Bearer YOUR_TOKEN_HERE"
```

### Expected Scenarios

| Scenario              | Result                                                |
| --------------------- | ----------------------------------------------------- |
| No contacts updated   | `{ "data": [], "metadata": { "resultCount": 0 } }`    |
| Some contacts updated | `{ "data": [...], "metadata": { "resultCount": 3 } }` |
| Invalid timestamp     | `400 Bad Request` with error message                  |
| Missing auth token    | `401 Unauthorized`                                    |

---

## 📊 Performance Comparison

| Scenario                     | Option 1 (Full Refresh) | Option 2 (Delta Sync)     |
| ---------------------------- | ----------------------- | ------------------------- |
| **100 contacts, 5 updated**  | Fetches 100 contacts    | Fetches 5 contacts ✅     |
| **500 contacts, 10 updated** | Fetches 500 contacts    | Fetches 10 contacts ✅    |
| **Network usage**            | ~500 KB                 | ~50 KB ✅                 |
| **Server load**              | Moderate                | Low ✅                    |
| **Client processing**        | High (compare all)      | Low (already filtered) ✅ |

---

## 🚦 Next Steps

1. **Test the implementation:**
   - Restart backend server: `npm run dev`
   - Test delta sync endpoint with Postman/curl
   - Verify `updatedAt` appears in existing endpoints

2. **Update frontend:**
   - Add timestamp storage (SharedPreferences/local DB)
   - Implement delta sync on app launch
   - Fallback to full sync if no timestamp exists

3. **Monitor performance:**
   - Track sync times
   - Monitor bandwidth usage
   - Add logging for troubleshooting

---

## 📝 Notes

- The `updatedAt` timestamp is automatically maintained by Sequelize
- It updates whenever any user field changes (name, picture, metadata, etc.)
- Status and emoji updates do NOT trigger user `updatedAt` (they have their own timestamps)
- Delta sync only checks user table changes, not status/emoji changes
- Both status and emoji are still fetched to provide complete contact data

---

**Implementation completed:** January 29, 2026
